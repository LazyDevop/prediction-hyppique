# Accès restreint à l'API déployée (story 7.8, AD-21)

Tant que les comptes et les contrôles par palier n'existent pas, personne
d'autre que le propriétaire ne doit lire les pronostics du jour
(`GET /dashboard/data`) ni écrire anonymement (`POST /pronostics`). Deux
couches indépendantes, chacune suffisante à elle seule :

1. **Pare-feu hôte** — liste blanche d'IP sur le port 8000, dans la chaîne
   iptables `DOCKER-USER` (Docker contourne ufw). Seul le trafic entrant
   publié par Docker (DNAT) vers le port 8000 est filtré ; les connexions
   sortantes des conteneurs ne sont pas touchées. Fichiers :
   `deploy/firewall/`. Le port n'est publié qu'en IPv4 (`0.0.0.0:8000`) car
   cette couche ne filtre pas IPv6.
2. **Secret partagé** — le middleware `backend/app/api/acces_restreint.py`
   exige `ACCES_RESTREINT_SECRET` sur toutes les requêtes HTTP et WebSocket,
   en `Authorization: Bearer <secret>` ou en HTTP Basic (utilisateur
   quelconque, mot de passe = secret). Seuls `GET`/`HEAD /health` et les
   vrais pré-vols CORS (`OPTIONS` avec `Origin` et
   `Access-Control-Request-Method`) sont exemptés. Refus : `401` sans corps
   avec `WWW-Authenticate: Basic realm="prediction-hyppique"` (WebSocket :
   fermeture 1008).

Avec `APP_ENV=production` (ou `prod`, posé par `docker-compose.yml`),
l'api **refuse de démarrer** si le secret est absent, fait moins de 16
caractères ou contient des caractères non ASCII (les espaces et `\r` de fin
de ligne sont retirés). En local (`APP_ENV` absent, secret absent), le
verrou est éteint : tests et dev inchangés.

> **Attention : tant que la story 7.3 (HTTPS) n'est pas livrée, le secret
> circule EN CLAIR sur HTTP.** Ne l'utiliser que depuis le VPN ou depuis les
> IP autorisées par le pare-feu, jamais depuis un Wi-Fi public. Le pare-feu
> reste la protection principale d'ici là.

## 1. Poser le secret (VPS)

Le secret ne vit que dans `.env` sur le VPS (jamais dans le code, le compose,
le dépôt, les logs ni un build release).

```bash
cd /opt/prediction-hyppique            # adapter au chemin réel du dépôt
openssl rand -base64 32                # copier la valeur générée (>= 16 car.)
nano .env                              # ajouter : ACCES_RESTREINT_SECRET=<valeur>
chmod 600 .env                         # lisible par son seul propriétaire
docker compose up -d --build api       # l'api relit .env au démarrage
docker compose logs --tail=20 api      # pas de RuntimeError = secret bien lu
```

Garder une copie du secret dans un gestionnaire de mots de passe.

### Rotation du secret

1. Générer une nouvelle valeur (`openssl rand -base64 32`) et la remplacer
   dans `.env`.
2. `docker compose up -d api` (recrée le conteneur avec le nouveau secret ;
   l'ancien est refusé immédiatement).
3. Rebuilder l'app mobile de dev avec le nouveau `--dart-define` (section 4).
4. Dans le navigateur, fermer les onglets du tableau de bord (ou vider les
   identifiants enregistrés) et ressaisir le nouveau secret à l'invite.

## 2. Installer le pare-feu (VPS)

1. Renseigner les IP autorisées (une IPv4 ou un CIDR `/1` à `/32` par ligne,
   commentaires `#` permis), **de préférence dans le fichier local non
   versionné** :

   ```bash
   cp deploy/firewall/ips_autorisees.conf deploy/firewall/ips_autorisees.local.conf
   nano deploy/firewall/ips_autorisees.local.conf
   ```

   S'il existe, `ips_autorisees.local.conf` (ignoré par git) est lu à la
   place de `ips_autorisees.conf` (versionné, qui ne contient qu'un exemple
   commenté). Tant qu'aucune IP n'est renseignée, le script **refuse de
   s'exécuter** (il fermerait le port à tout le monde, propriétaire
   compris). Une entrée invalide fait échouer le script **avant** tout appel
   iptables : les règles en place restent intactes.

2. Installer le service systemd (le chemin `/opt/prediction-hyppique` du
   fichier unité est remplacé par le chemin réel) :

   ```bash
   sudo sed "s#/opt/prediction-hyppique#$(pwd)#g" deploy/firewall/acces-restreint.service \
     | sudo tee /etc/systemd/system/acces-restreint.service > /dev/null
   sudo systemctl daemon-reload
   sudo systemctl enable --now acces-restreint.service
   sudo systemctl status acces-restreint.service
   ```

   Le service (`Requires=`, `After=` et `PartOf=docker.service`) se relance
   au boot et à chaque redémarrage de Docker ; son arrêt retire les règles
   (`--retirer`).

3. Vérifier :

   ```bash
   sudo iptables -S DOCKER-USER       # une seule ligne "... --ctstate DNAT ... -j ACCES_RESTREINT"
   sudo iptables -S ACCES_RESTREINT   # RETURN établies, RETURN par IP, DROP
   ```

   Le script est idempotent et fermé en cas d'échec : il construit
   `ACCES_RESTREINT_NEW`, insère son saut, retire l'ancien saut et l'ancienne
   chaîne puis renomme la nouvelle ; le relancer deux fois laisse un seul
   saut, et le port n'est jamais ouvert pendant la reconstruction.

4. **Après chaque redémarrage du VPS**, vérifier que le service est actif :

   ```bash
   systemctl is-active acces-restreint   # doit répondre "active"
   sudo iptables -S DOCKER-USER
   ```

## 3. Modifier les IP autorisées

```bash
nano deploy/firewall/ips_autorisees.local.conf
sudo systemctl restart acces-restreint.service
sudo iptables -S ACCES_RESTREINT
```

Toujours garder l'IP depuis laquelle on travaille dans la liste (sinon le
port 8000 se ferme pour soi ; SSH sur le port 22 n'est pas concerné).

Une IP retirée garde ses connexions **déjà établies** jusqu'à leur
fermeture (règle `ESTABLISHED,RELATED`). Pour les couper tout de suite :

```bash
sudo conntrack -D -s <ip_retiree>      # paquet conntrack
```

## 4. Build mobile de dev

Le secret n'est passé qu'au build de **dev**, par `--dart-define`. Il ne doit
jamais apparaître dans un build release ni dans le bundle web. Garde-fou :
en mode release (`kReleaseMode`), `ApiClient` ignore le secret même s'il a
été passé par erreur (aucun en-tête, rien de journalisé) — ne pas s'y fier
pour autant, ne jamais builder une release avec ce `--dart-define`.

```bash
cd mobile
flutter run --dart-define=ACCES_RESTREINT_SECRET=<secret>
# vers un backend local :
flutter run --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=ACCES_RESTREINT_SECRET=<secret>
```

`ApiClient` envoie alors `Authorization: Bearer <secret>` sur chaque requête ;
sans `--dart-define`, aucun en-tête n'est envoyé.

## 5. Navigateur (tableau de bord)

Ouvrir `http://<vps>:8000/dashboard` (depuis une IP autorisée, voir
l'avertissement HTTP ci-dessus) : le navigateur affiche une invite
d'identification. Saisir n'importe quel nom d'utilisateur et le secret
comme mot de passe. Les appels de la page vers `/dashboard/data` (même
origine) réutilisent ces identifiants.

## 6. Test de fumée (VPS, depuis une IP autorisée)

```bash
URL=http://<vps>:8000
S='<secret>'
# 6 appels refusés -> 401 attendu à chaque fois
curl -s -o /dev/null -w '%{http_code}\n' $URL/dashboard/data
curl -s -o /dev/null -w '%{http_code}\n' -X POST $URL/pronostics -H 'Content-Type: application/json' -d '{}'
curl -s -o /dev/null -w '%{http_code}\n' -H 'Authorization: Bearer mauvais' $URL/dashboard/data
curl -s -o /dev/null -w '%{http_code}\n' -u x:mauvais $URL/dashboard/data
curl -s -o /dev/null -w '%{http_code}\n' -H 'Authorization: Basic !!!' $URL/dashboard/data
curl -s -o /dev/null -w '%{http_code}\n' $URL/docs
# sonde de vie -> 200 {"status":"ok"}
curl -s $URL/health
# accès légitime -> 200
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $S" $URL/dashboard/data
curl -s -o /dev/null -w '%{http_code}\n' -u "x:$S" $URL/dashboard/data
```

Depuis une IP **non** autorisée (ex. données mobiles) :
`curl -m 5 $URL/health` doit expirer (paquets jetés par le pare-feu).

Puis redémarrer le VPS, vérifier `systemctl is-active acces-restreint` et
`sudo iptables -S DOCKER-USER`, et rejouer le test ci-dessus. Consigner le
résultat dans les notes de
`_bmad-output/implementation-artifacts/spec-7-8-fermer-api-deployee.md`.

## 7. Levée de la restriction

Le verrou n'est levé qu'**après les stories 9.2 et 10.7**, et uniquement par
une **décision consignée** (date, auteur, justification). Lever la couche
pare-feu :

```bash
sudo systemctl disable --now acces-restreint   # ExecStop lance le script avec --retirer
sudo iptables -S DOCKER-USER                   # plus aucun saut vers ACCES_RESTREINT
```

La couche secret est remplacée par les contrôles par compte et palier
(retrait du middleware dans le même changement). D'ici là, ne jamais
ajouter de route à l'exemption au-delà de `/health` sans décision explicite
(l'exception webhook de paiement relève de la story 9.5).
