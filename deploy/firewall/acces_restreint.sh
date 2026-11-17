#!/usr/bin/env bash
# Story 7.8 (AD-21, couche 1) : liste blanche hôte sur le port 8000 de l'api.
#
# Docker publie ses ports via DNAT et contourne ufw : le filtrage se fait
# donc dans la chaîne DOCKER-USER. Le saut ne vise que le trafic entrant
# publié (`--ctstate DNAT`) sur le port d'ORIGINE 8000 (après le DNAT, le
# port vu par FORWARD est celui du conteneur) : les connexions sortantes des
# conteneurs vers un :8000 distant ne sont pas touchées.
#
# Chaîne ACCES_RESTREINT : RETURN pour les connexions établies, RETURN par
# source autorisée (les règles de Docker continuent ensuite), DROP le reste.
#
# Idempotent et fermé en cas d'échec : la liste entière est validée AVANT
# tout appel iptables ; la nouvelle chaîne est construite à côté
# (ACCES_RESTREINT_NEW), son saut inséré, puis l'ancien saut et l'ancienne
# chaîne retirés et la nouvelle renommée. Le port n'est donc jamais ouvert
# pendant la reconstruction.
#
# Usage :
#   sudo ./acces_restreint.sh [fichier_ips]   applique la liste
#   sudo ./acces_restreint.sh --retirer       retire saut et chaînes (levée)
# Fichier par défaut : ips_autorisees.local.conf à côté du script s'il existe
# (non versionné), sinon ips_autorisees.conf. Aucun secret lu ni écrit ici.

set -euo pipefail

PORT=8000
CHAINE=ACCES_RESTREINT
NOUVELLE="${CHAINE}_NEW"
DOSSIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPT="${IPTABLES:-iptables}"

saut() {
  # Arguments de la règle de saut de DOCKER-USER vers la chaîne $1.
  echo "-p tcp -m conntrack --ctstate DNAT --ctorigdstport $PORT --ctdir ORIGINAL -j $1"
}

retirer_sauts() {
  local cible="$1" regle
  # shellcheck disable=SC2207
  regle=($(saut "$cible"))
  while "$IPT" -w -C DOCKER-USER "${regle[@]}" 2>/dev/null; do
    "$IPT" -w -D DOCKER-USER "${regle[@]}"
  done
}

supprimer_chaine() {
  local chaine="$1"
  retirer_sauts "$chaine"
  "$IPT" -w -F "$chaine" 2>/dev/null || true
  "$IPT" -w -X "$chaine" 2>/dev/null || true
}

if [[ "${1:-}" == "--retirer" ]]; then
  supprimer_chaine "$NOUVELLE"
  supprimer_chaine "$CHAINE"
  echo "acces_restreint: saut et chaîne $CHAINE retirés (port $PORT non filtré par cette couche)."
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  FICHIER="$1"
elif [[ -f "$DOSSIER/ips_autorisees.local.conf" ]]; then
  FICHIER="$DOSSIER/ips_autorisees.local.conf"
else
  FICHIER="$DOSSIER/ips_autorisees.conf"
fi

if [[ ! -r "$FICHIER" ]]; then
  echo "acces_restreint: fichier introuvable ou illisible: $FICHIER" >&2
  exit 1
fi

ipv4_valide() {
  # IPv4 a.b.c.d (octets 0-255) avec préfixe optionnel /1 à /32 (/0 refusé).
  local entree="$1" adresse prefixe="" octet
  adresse="${entree%%/*}"
  if [[ "$entree" == */* ]]; then
    prefixe="${entree#*/}"
    [[ "$prefixe" =~ ^[0-9]{1,2}$ ]] || return 1
    (( 10#$prefixe >= 1 && 10#$prefixe <= 32 )) || return 1
  fi
  [[ "$adresse" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$adresse"
  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || return 1
  done
}

# 1. Validation complète de la liste, sans aucun appel iptables.
IPS=()
while IFS= read -r ligne || [[ -n "$ligne" ]]; do
  ligne="${ligne%%#*}"
  ligne="$(printf '%s' "$ligne" | tr -d '[:space:]')"
  [[ -z "$ligne" ]] && continue
  if ! ipv4_valide "$ligne"; then
    echo "acces_restreint: entrée invalide (IPv4 ou CIDR /1-/32 attendu): $ligne" >&2
    exit 1
  fi
  IPS+=("$ligne")
done < "$FICHIER"

if [[ ${#IPS[@]} -eq 0 ]]; then
  echo "acces_restreint: liste d'IP vide dans $FICHIER — refus (le port $PORT serait fermé à tous, propriétaire compris)." >&2
  exit 1
fi

# 2. DOCKER-USER est créée par Docker ; on la crée si elle manque (Docker la
# réutilise sans la vider).
"$IPT" -w -N DOCKER-USER 2>/dev/null || true

# 3. Nouvelle chaîne construite à côté (reste d'un échec précédent nettoyé).
supprimer_chaine "$NOUVELLE"
"$IPT" -w -N "$NOUVELLE"
"$IPT" -w -A "$NOUVELLE" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
for ip in "${IPS[@]}"; do
  "$IPT" -w -A "$NOUVELLE" -s "$ip" -j RETURN
done
"$IPT" -w -A "$NOUVELLE" -j DROP

# 4. Bascule : saut vers la nouvelle chaîne d'abord, puis retrait de
# l'ancienne, puis renommage. À tout instant au moins un saut filtre le port.
# shellcheck disable=SC2207
REGLE_NOUVELLE=($(saut "$NOUVELLE"))
"$IPT" -w -I DOCKER-USER 1 "${REGLE_NOUVELLE[@]}"
supprimer_chaine "$CHAINE"
"$IPT" -w -E "$NOUVELLE" "$CHAINE"

echo "acces_restreint: ${#IPS[@]} source(s) autorisée(s) sur le port $PORT (fichier $FICHIER)."
