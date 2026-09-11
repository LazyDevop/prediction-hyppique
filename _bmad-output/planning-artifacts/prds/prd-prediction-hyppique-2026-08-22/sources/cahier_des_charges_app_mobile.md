# Cahier des charges — Application mobile (Flutter)

## 0. Contexte

Ce document spécifie l'application mobile qui sera l'interface finale de
l'outil d'analyse hippique. Il est le **complément** du document
`cahier_des_charges_backend_hippique.md`, qui spécifie le backend Python/
FastAPI (moteur de calcul, ingestion des données PMU, base de données,
extraction par image). **Ne pas dupliquer les formules du moteur ici** :
l'app mobile en consomme une copie portée en Dart (section 5) mais la
spécification de référence — constantes, formules, cas de test — reste le
document backend, section 7. En cas de divergence entre les deux, le document
backend fait foi.

Ce projet est l'aboutissement de deux prototypes déjà construits et validés
manuellement pendant la phase de conception :
- `analyse_hippique_v2.html` — prototype autonome (saisie manuelle, export/
  import JSON), qui a servi à valider le moteur de calcul.
- `analyse_hippique_ia.jsx` — artifact React avec import de fiche cheval et
  de programme de course complet par extraction d'image (vision IA).

L'app mobile Flutter reprend l'intégralité des fonctionnalités de ces deux
prototypes, mais consomme désormais le backend pour la donnée automatisée
(au lieu de la saisie manuelle comme seul mode) et pour l'extraction d'image
(au lieu d'appeler l'API de vision directement depuis le client — voir 6.3,
raison de sécurité).

## 1. Objectif du produit

Une application mobile personnelle (usage individuel, pas de compte
multi-utilisateur dans cette version) permettant de :
1. Consulter le programme du jour et les partants d'une course, en majorité
   déjà préremplis grâce au backend (données PMU + historique).
2. Ajuster manuellement ou compléter par photo tout ce que le backend n'a pas
   (terrain manquant, cheval non couvert, réunion étrangère).
3. Lancer le calcul du moteur d'analyse et lire le classement, les
   probabilités (1er/Top2/Top3/Top4), la value par rapport aux cotes, et les
   combinaisons de paris (couplé, tiercé, quarté, quinté — ordre et
   désordre — plus couplé placé et 2 sur 4).
4. Utiliser l'app **sur l'hippodrome, avec une connexion incertaine** — voir
   contrainte offline en section 4.

## 2. Rappel de principe (à ne jamais dériver)

L'application est un outil d'**aide à la décision**, pas un système de
pronostic présenté comme fiable ni un générateur de paris automatiques.
Aucune fonctionnalité de placement de pari automatisé n'est dans le
périmètre. Chaque écran de résultats doit conserver un rappel visible que le
jeu comporte des risques et qu'aucun modèle ne garantit un gain — cohérent
avec l'avertissement déjà présent dans les deux prototypes existants.

## 3. Périmètre

### Dans le périmètre
- Écrans : accueil/programme du jour, configuration de la course cible,
  liste des partants (préremplis ou saisis), fiche cheval éditable, import
  photo (fiche cheval unique ou programme complet), écran de résultats
  (classement, probabilités, value, combinaisons).
- Consommation de l'API backend (section 6) pour la donnée et le calcul.
- Un moteur de calcul embarqué en Dart (section 5) pour fonctionner hors
  ligne une fois les données d'une course chargées.
- Stockage local (SQLite) des courses déjà chargées, pour consultation et
  recalcul hors ligne.
- Export/partage du classement calculé (au minimum en texte ou JSON — un
  export PDF est un bonus, pas un prérequis).

### Hors périmètre (explicitement)
- Compte utilisateur, authentification, multi-appareil, synchronisation
  cloud entre appareils.
- Placement de paris, quel que soit le canal.
- Notifications push, rappels d'heure de départ (bonus futur envisageable,
  pas dans cette version).
- Couverture des courses hors France.
- Historique de presse/consensus (fonctionnalité évoquée mais non
  spécifiée à ce stade — voir le prototype pour le principe si elle est
  réintroduite plus tard : jamais intégrée au score, affichée à part).

## 4. Contrainte transverse : usage sur hippodrome, connexion incertaine

C'est la contrainte qui structure le choix d'architecture (section 5) :
l'utilisateur consultera probablement l'app depuis les tribunes ou le
pesage, où la 4G peut être saturée (affluence) ou absente. En conséquence :

- Le **calcul du classement ne doit jamais dépendre du réseau** une fois les
  données d'une course chargées — il tourne intégralement sur l'appareil.
- Le **chargement des données** (programme, partants, historique) doit être
  fait en amont si possible (ex. la veille, ou le matin avec une bonne
  connexion) et mis en cache localement.
- Seul l'**import par photo** (extraction vision) et le **rafraîchissement
  des cotes en direct** nécessitent une connexion — ces fonctionnalités
  doivent échouer proprement (message clair, pas de blocage de l'app) si le
  réseau est indisponible, et permettre de continuer en saisie manuelle.

## 5. Architecture Flutter proposée

```
lib/
  main.dart
  models/
    horse.dart              — cheval + ses performances (miroir du schéma backend)
    performance.dart         — une performance passée (rang, partants, niveau,
                                distance, terrain NULLABLE, incident)
    race_config.dart         — course cible (hippodrome, distance, terrain,
                                niveau, nombre de partants)
    engine_params.dart        — paramètres réglables (récence, k, sensibilité
                                poids, âges min/max, lissage, coef inédit,
                                malus incident, bankroll, fraction Kelly)
  engine/
    constants.dart            — TABLES terrain/niveau/incidents, copiées
                                À L'IDENTIQUE de la section 7 du document
                                backend — ne pas réinventer ces valeurs
    scoring.dart               — port Dart de compute_note / lissage bayésien
                                / ajustements poids-âge (section 7.5-7.7 backend)
    harville.dart               — probabilités Top1/2/3/4 (section 7.10 backend)
    combinatoire.dart             — couplé/tiercé/quarté/quinté ordre+désordre
                                + Monte-Carlo couplé placé/2sur4 (section 7.12)
  data/
    local/
      database_helper.dart      — SQLite (sqflite), cache des courses/chevaux
      dao/                        — accès typés aux tables locales
    remote/
      api_client.dart            — client HTTP vers le backend (dio ou http)
      endpoints.dart               — routes du backend consommées (section 6)
  repository/
    course_repository.dart       — orchestre local (cache) + remote (backend),
                                  expose une API unique aux écrans indépendante
                                  de la provenance de la donnée
  providers/ (ou state Riverpod, voir 5.1)
    race_provider.dart
    horses_provider.dart
    results_provider.dart
  screens/
    home_screen.dart              — programme du jour
    race_config_screen.dart        — course cible
    horse_list_screen.dart          — partants (préremplis + ajout manuel)
    horse_edit_screen.dart           — fiche cheval éditable + bouton import photo
    import_photo_screen.dart          — capture/galerie → appel backend vision
    results_screen.dart                — classement, probabilités, value, paris
    settings_screen.dart                — paramètres du moteur (engine_params)
  widgets/
    horse_card.dart
    performance_row.dart
    probability_gauge.dart            — jauge modèle vs marché (reprise du
                                       prototype HTML/React)
    combo_block.dart                   — bloc combinaison de paris (dossards)
```

### 5.1 Gestion d'état

Riverpod est recommandé plutôt que Provider seul (l'architecture initialement
proposée par un autre outil, voir section 8, utilisait Provider — Riverpod
apporte une meilleure testabilité et évite certains pièges de cycle de vie
que Provider peut poser). Si l'équipe est déjà à l'aise avec Provider, ce
n'est pas bloquant, mais Riverpod est le choix par défaut recommandé pour un
projet neuf.

### 5.2 Pourquoi un moteur dupliqué en Dart plutôt qu'un simple appel API

Vu la contrainte de connexion incertaine (section 4), le calcul doit pouvoir
tourner localement. Le moteur étant un calcul déterministe et léger (aucun
appel à un modèle d'IA dans le calcul lui-même — seule l'extraction d'image
en a besoin), le dupliquer en Dart est raisonnable. Pour éviter la dérive
entre les deux implémentations (Python côté backend, Dart côté app), les
tests unitaires du document backend (section 9) doivent être reproduits à
l'identique côté Dart, avec les mêmes cas et les mêmes résultats attendus à
epsilon près.

## 6. Consommation du backend

### 6.1 Endpoints utilisés (voir document backend, section 8, pour le détail)

| Usage dans l'app | Endpoint backend |
|---|---|
| Charger le programme du jour | `GET /courses?date=` |
| Charger les partants + historique d'une course | `GET /courses/{course_id}/partants` |
| Forcer l'import d'une course pas encore en base | `POST /courses/{course_id}/importer` |
| Import photo d'une fiche cheval | `POST /extraction/fiche` |
| Import photo d'un programme complet | `POST /extraction/programme` |
| Calcul (repli, si l'app ne veut pas recalculer localement, ex. debug) | `POST /analyse` |

### 6.2 Stratégie de synchronisation

1. Au chargement de l'app (ou sur action explicite "rafraîchir"), appeler
   `/courses` pour le jour choisi, stocker le résultat en local (SQLite).
2. Pour chaque course consultée, appeler `/partants` une fois et mettre en
   cache — ne pas re-fetcher à chaque écran, seulement sur demande explicite
   de rafraîchissement (les cotes changent, mais l'historique des chevaux
   non).
3. Le calcul (classement, probabilités, combinaisons) se fait **localement**
   avec le moteur Dart (section 5), à partir des données en cache — pas
   d'appel réseau à chaque changement de paramètre dans les réglages.

### 6.3 Sécurité — ne jamais embarquer de clé API dans l'application

L'extraction par image (vision IA) doit **toujours** passer par le backend
(`/extraction/fiche`, `/extraction/programme`), jamais par un appel direct
depuis l'app mobile vers un fournisseur d'IA avec une clé embarquée dans le
code. Une clé API dans un binaire Flutter est extractible par
rétro-ingénierie de l'APK/IPA — c'est le backend qui doit détenir le secret.

## 7. Écrans et parcours utilisateur

### 7.1 Accueil — programme du jour
Liste des réunions et courses du jour (depuis le cache local, rafraîchi
depuis le backend). Sélection d'une course → écran configuration.

### 7.2 Configuration de la course cible
Hippodrome, distance, terrain (échelle complète section 7.1 du document
backend, avec regroupement visuel gazon / PSF), niveau (Groupe I-IV, Listed,
Catégorie A à G/H), nombre de partants. Préremplie automatiquement si la
course vient du backend ; modifiable à la main sinon.

### 7.3 Liste des partants
Chaque cheval : dossard, nom, âge, poids, cote (préremplis si disponibles),
indicateur "historique complet" / "terrain inconnu sur N performances" /
"inédit" (voir section 7.7 et 7.8 du document backend — reprendre les mêmes
libellés de transparence que le prototype HTML/React : "Historique court",
"Données non saisies", "🐎 Inédit", jamais masqués silencieusement).

### 7.4 Fiche cheval éditable
Les 5 dernières performances (rang, partants, niveau, distance, terrain,
incident) — éditable même si préremplies par le backend, avec un bouton
"Importer une photo ou un PDF" pour cette fiche précise (appelle
`/extraction/fiche`). Case à cocher "Cheval inédit" distincte du champ vide
(voir section 7.7 du document backend, ne pas les confondre).

### 7.5 Import photo (programme complet)
Capture ou galerie → `/extraction/programme` → préremplit en un seul geste
la course cible et tous les partants visibles, marqués visuellement comme
"à vérifier" (reprise du bandeau "✨ Rempli par l'IA — vérifiez les champs"
du prototype React).

### 7.6 Résultats
Classement trié par score, avec par cheval : dossard en badge, score,
régularité, jauge probabilité modèle vs marché, trio/quatuor de
probabilités (1er/Top2/Top3/Top4), cote, value, mise suggérée (Kelly
fractionné), recommandation textuelle. Sous le classement, la grille des
combinaisons de paris (couplé/tiercé/quarté/quinté ordre et désordre, couplé
placé, 2 sur 4) en dossards, triées par probabilité décroissante — reprise
exacte de l'écran équivalent du prototype React (`analyse_hippique_ia.jsx`,
section rendu des résultats).

### 7.7 Réglages
Tous les paramètres du moteur (section "engine_params" du modèle) exposés
avec leurs valeurs par défaut (voir document backend, sections 7.3 à 7.11) :
pondération de récence, contraste k, sensibilité au poids, âges min/max,
lissage bayésien, coefficient inédit, intensité du malus incident, bankroll,
fraction de Kelly.

## 8. Erreurs à ne pas reproduire (retour d'expérience)

Une précédente proposition d'architecture Flutter (générée par un autre
outil) contenait plusieurs défauts identifiés et corrigés pendant la phase
de conception du prototype — à connaître pour ne pas les réintroduire en
copiant d'anciens extraits de code :

1. **Coefficient de récence potentiellement inversé** — vérifier que la
   pondération la plus forte s'applique bien à C1 (la performance la plus
   récente), pas à la plus ancienne.
2. **"Value bet" cosmétique** — une détection de value basée sur un simple
   seuil de score sans comparaison réelle à la cote (`probabilité × cote -
   1`) n'est pas de la value, c'est une étiquette. La vraie formule est
   spécifiée section 7.11 du document backend.
3. **Indexation des cotes désynchronisée du classement** — si les cotes sont
   stockées dans un tableau séparé indexé sur le classement trié plutôt que
   sur l'identité du cheval, la value calculée est attribuée au mauvais
   cheval. Toujours porter la cote comme propriété du cheval lui-même.
4. **Erreurs de compilation Dart classiques à éviter** : `(x).sqrt()`
   n'existe pas sur `double` — utiliser `sqrt(x)` de `dart:math` ;
   `Icons.horse` n'existe pas dans Material Icons ; une variable de
   `Consumer` ne doit pas être référencée hors de son `builder` (ex. dans un
   `floatingActionButton` au même niveau).
5. **Niveau de la course cible jamais utilisé dans le calcul** — le niveau
   de la course du jour doit intervenir dans `c_niv` (ratio avec le niveau de
   chaque performance passée, section 7.5 du document backend), pas
   seulement être stocké sans effet.
6. **Champs cote / poids / âge absents du modèle de données** — ces trois
   champs sont au cœur du moteur (value, ajustement poids, ajustement âge) et
   doivent être présents dès le modèle `Horse`/`Performance`, pas ajoutés
   après coup.

## 9. Stack technique recommandée

- **Flutter** (cross-platform Android/iOS — le projet initial visait Android
  seul, mais rien dans le moteur ni les écrans n'est spécifique à une
  plateforme ; iOS peut être ajouté sans coût de conception supplémentaire).
- `sqflite` + `path` — stockage local.
- `riverpod` — gestion d'état (voir 5.1).
- `dio` — client HTTP vers le backend (gestion des timeouts et retries plus
  confortable que `http` pour un usage en connexion incertaine).
- `image_picker` (galerie) et `camera` ou `image_picker` en mode caméra —
  capture photo pour l'import. Prévoir aussi la sélection d'un fichier PDF
  (`file_picker`) — certaines fiches de courses sont exportées ou partagées
  en PDF plutôt qu'en image, l'extraction doit accepter les deux (voir
  document backend, section 4.4).
- `freezed` + `json_serializable` — modèles immuables et sérialisation JSON
  cohérente avec les schémas du backend.

## 10. Plan de développement suggéré

1. **Modèles + moteur Dart** (sections 5, 8), avec les tests portés
   directement depuis la section 9 du document backend — aucune donnée
   réseau nécessaire à ce stade, développable et vérifiable en isolation.
2. **Stockage local** (SQLite) et écrans de saisie manuelle (7.2 à 7.4),
   fonctionnels sans aucune dépendance au backend — équivalent Flutter du
   prototype HTML, pour avoir un produit utilisable même si le backend
   n'est pas encore prêt.
3. **Client API et synchronisation** (section 6) une fois le backend
   disponible, en remplaçant progressivement la saisie manuelle par le
   préremplissage automatique.
4. **Import photo** (7.5), en dernier — dépend à la fois du backend et
   d'une connexion réseau, c'est la fonctionnalité la plus "optionnelle" en
   usage trackside.
5. **Réglages et calibration** (7.7) — une fois un historique réel accumulé
   côté backend, revisiter les valeurs par défaut des paramètres du moteur
   à la lumière des résultats observés (même logique de calibration que
   section 11 du document backend).

## 11. Critères d'acceptation

- L'app calcule un classement identique (à epsilon près) à celui produit par
  `analyse_hippique_v2.html` sur le même jeu de données d'entrée — vérifié en
  rejouant l'exemple à 12 partants du prototype HTML.
- L'app reste utilisable (consultation d'une course déjà chargée + recalcul
  après changement de paramètre) en mode avion.
- Aucune clé API de service tiers n'apparaît dans le code source ni le
  binaire de l'application.
- Chaque écran de résultats affiche l'avertissement de jeu responsable.
