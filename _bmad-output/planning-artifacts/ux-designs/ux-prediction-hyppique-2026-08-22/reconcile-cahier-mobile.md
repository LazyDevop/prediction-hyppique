# Réconciliation — cahier des charges app mobile vs DESIGN.md / EXPERIENCE.md

Source : `sources/cahier_des_charges_app_mobile.md`
Spines : `DESIGN.md` (visuel) + `EXPERIENCE.md` (comportemental)

Rappel de périmètre de cette réconciliation : le niveau code (fichiers `.dart`,
Riverpod, `sqflite`, structure `lib/`, section 5 et section 8-9 du cahier) est
hors sujet ici par construction — ces sections restent propriété du cahier /
d'un futur document d'architecture, et leur absence dans les spines n'est
**pas** un écart.

## 1. Couverture des 7 écrans (section 7 du cahier) dans l'IA d'EXPERIENCE.md

| # | Écran cahier | Entrée IA EXPERIENCE.md | Comportement cohérent ? |
|---|---|---|---|
| 7.1 | Accueil — programme du jour | Accueil (programme du jour) | Oui — cache local, rafraîchissable, cold-start avec/sans cache traité en State Patterns |
| 7.2 | Configuration course | Configuration course | Oui pour hippodrome/distance/niveau/partants + préremplissage conditionnel ; **partiel** sur le terrain (voir écart n°2) |
| 7.3 | Liste des partants | Liste des partants | Oui — libellés de transparence, éditable, import déclenché depuis cet écran |
| 7.4 | Fiche cheval éditable | Fiche cheval éditable | Oui — édition même préremplie, bouton import, case "Cheval inédit" distincte du champ vide (Component Patterns) |
| 7.5 | Import photo (programme complet) | Import photo (feuille modale) | Oui — accessible depuis Liste des partants ou Fiche cheval, comportement bandeau "à vérifier" repris |
| 7.6 | Résultats | Résultats | Oui pour classement/value/probabilités/combinaisons ; **partiel** sur l'export/partage (voir écart n°1) |
| 7.7 | Réglages | Réglages | Oui — accessible globalement, comportement de persistance et de reset détaillé (Component Patterns) |

Les 7 écrans ont bien une entrée, avec un comportement globalement cohérent
avec le cahier. Deux écrans (7.2 et 7.6) ont une sous-exigence explicite du
cahier qui n'est pas retranscrite au niveau comportemental — détail ci-dessous.

## 2. Libellés de transparence obligatoires (section 7.3 du cahier)

Cahier : "Historique court", "Données non saisies", "🐎 Inédit", jamais
masqués silencieusement.

EXPERIENCE.md, table Voice and Tone : "Historique court (3)" / "Données non
saisies" / "🐎 Inédit" — repris **littéralement**, avec en Don't "masquer
silencieusement l'incertitude". Renforcé en State Patterns : "Badge texte
visible en permanence, jamais uniquement au survol/tap (PRD FR-4, transparence
non négociable)" et par le principe symétrique "Cheval avec historique complet
→ Aucun badge — l'absence de badge est elle-même le signal".

**Aucun écart.** C'est même plus strict que le texte du cahier (la règle
"silence = pas de problème" explicite ce qui restait implicite côté cahier).

## 3. Contrainte offline (section 4 du cahier — la plus importante)

Vérification qu'elle est traduite en règles comportementales strictes et pas
juste mentionnée :

- Foundation d'EXPERIENCE.md pose le principe general : "aucune interaction de
  cette spine ne doit introduire une dépendance réseau sur le chemin du
  calcul."
- State Patterns porte 5 lignes dédiées : cold start avec/sans cache, "Réseau
  indisponible — import photo ou rafraîchissement cotes" (dégradation propre,
  reste du produit utilisable), "Mode avion / hors ligne, course en cache"
  (fonctionnement identique au mode connecté, qualifié "non négociable"),
  "Import photo échoué" (retour à la saisie manuelle sans perte).
- Interaction Primitives interdit explicitement le rafraîchissement
  automatique en arrière-plan (le chargement anticipé + mise en cache du
  cahier ne peut être contredit par un refresh silencieux).
- Le Key Flow UJ-2 est entièrement dédié au scénario "hippodrome, connexion
  saturée" et démontre concrètement le recalcul 100% local.

**Aucun écart.** La contrainte est traduite en règles vérifiables (pas de
refresh auto, dégradation propre nommée écran par écran, flow dédié), au-delà
d'une simple mention.

## 4. Sécurité (section 6.3 — jamais de clé API côté client) vs "Feuille d'import"

Le cahier interdit tout appel direct app→fournisseur IA avec clé embarquée ;
l'extraction doit toujours transiter par le backend.

EXPERIENCE.md décrit le composant `import-sheet` (Component Patterns) avec
trois choix Caméra/Galerie/PDF, et les états "Import photo en cours"/"échoué"
qui impliquent un appel réseau vers *un* service, sans jamais mentionner de
clé, credential ou appel direct à un fournisseur tiers. DESIGN.md décrit
uniquement l'aspect visuel de la feuille (icônes, fond, coins).

**Aucune incohérence** : rien dans les spines ne suggère ou ne nécessite un
appel direct depuis le client vers un fournisseur d'IA — le sujet est
simplement silencieux sur *qui* héberge le secret, ce qui est correct pour une
spine UX (c'est un sujet d'architecture backend, hors périmètre de
DESIGN/EXPERIENCE par la consigne de la tâche). Rien à corriger ici.

## 5. Écarts trouvés

### Écart 1 — Export/partage du classement, en périmètre mais non détaillé (gravité : modérée)

1. **Cahier** (§3, "Dans le périmètre") : "Export/partage du classement
   calculé (au minimum en texte ou JSON — un export PDF est un bonus, pas un
   prérequis)." C'est une fonctionnalité explicitement listée comme dans le
   périmètre du produit.
2. **Spines** : le mot "export" apparaît une seule fois, dans la colonne
   Objectif de la ligne "Résultats" de l'IA d'EXPERIENCE.md ("Classement,
   value, probabilités, combinaisons, export"). Aucune ligne de Component
   Patterns, State Patterns ou Interaction Primitives ne décrit le
   déclenchement (bouton ? action dans un menu ?), le choix de format
   (texte/JSON/PDF), la confirmation de succès, ni le comportement en cas
   d'échec (partage impossible, permissions fichier). DESIGN.md n'a aucun
   composant associé (pas de "export-button", pas de feuille de partage).
   Note : le cahier lui-même ne détaille pas ce comportement dans sa
   description de l'écran Résultats (§7.6) — l'écart vient donc surtout de la
   sous-spécification partagée par les deux documents, mais la mention
   explicite en §3 "dans le périmètre" justifie qu'au moins une ligne de
   comportement existe dans EXPERIENCE.md.
3. **Suggestion** : ajouter une ligne Component Patterns ("Action export/
   partage — CTA secondaire sur Résultats, ouvre le partage natif Android
   avec le classement en texte ou JSON") et une ligne State Patterns pour
   l'échec du partage (permissions, aucune app cible disponible), cohérente
   avec le ton "message clair, jamais un blocage" déjà appliqué ailleurs dans
   le document.

### Écart 2 — Regroupement visuel terrain gazon/PSF non repris (gravité : mineure)

1. **Cahier** (§7.2, Configuration de la course cible) : "terrain (échelle
   complète section 7.1 du document backend, **avec regroupement visuel
   gazon / PSF**), niveau (...)". C'est une instruction d'interaction/
   présentation spécifique pour le sélecteur de terrain sur cet écran
   précis.
2. **Spines** : l'IA d'EXPERIENCE.md pour "Configuration course" dit
   seulement "Définir hippodrome/distance/terrain/niveau/partants", sans
   détail sur le sélecteur de terrain. DESIGN.md ne contient aucun composant
   de type "sélecteur de terrain" ni mention de regroupement gazon/PSF (les
   seules occurrences de "terrain" dans DESIGN.md concernent les badges de
   transparence sur les performances passées, pas le champ de configuration
   de la course cible).
3. **Suggestion** : ajouter dans EXPERIENCE.md (Component Patterns ou une
   note sous l'entrée IA "Configuration course") une règle du type "Sélecteur
   de terrain groupé visuellement en deux familles (Gazon / PSF) plutôt qu'en
   liste plate des variantes", et dans DESIGN.md un composant correspondant
   (ex. `terrain-selector` avec deux groupes visuels) si un mockup de cet
   écran est produit ultérieurement.

### Écart 3 — Nombre de performances éditées : "5" (cahier) vs "5-6" (EXPERIENCE) (gravité : négligeable)

1. **Cahier** (§7.4) : "Les 5 dernières performances (rang, partants, niveau,
   distance, terrain, incident)".
2. **Spines** : EXPERIENCE.md, IA, ligne "Fiche cheval éditable" : "Éditer
   les **5-6** dernières performances d'un cheval." Cette variation est
   probablement héritée du document backend (référencé mais non lu dans
   cette réconciliation) ou des deux prototypes, qui pourraient différer sur
   ce nombre — et elle est interne-cohérente avec le compteur "X/6
   performances avec terrain inconnu" du State Patterns. Ce n'est pas
   contradictoire au sens fonctionnel (juste une divergence de chiffre exact),
   mais vaut une clarification pour éviter toute ambiguïté d'implémentation.
3. **Suggestion** : aligner sur la valeur de référence du document backend
   (section 7.x) lors de la prochaine passe de relecture, et uniformiser
   "5" ou "6" dans EXPERIENCE.md.

## 6. Synthèse

Aucun écart bloquant ou majeur. La contrainte offline (section 4) et les
libellés de transparence obligatoires (section 7.3) — les deux points jugés
les plus sensibles dans la consigne — sont intégralement et strictement
retranscrits, au-delà d'une simple mention. La sécurité (6.3) est cohérente
par silence correct (aucun élément des spines n'implique ou ne contredit la
règle "jamais de clé API côté client"). Les 7 écrans de la section 7 ont tous
une entrée IA cohérente.

Deux écarts modéré/mineur à combler dans une prochaine itération des spines :
l'export/partage du classement (mentionné mais non détaillé) et le
regroupement visuel gazon/PSF du sélecteur de terrain (absent). Un troisième
écart est une simple divergence de chiffre (5 vs 5-6 performances) à
clarifier, sans impact fonctionnel.
