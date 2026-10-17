---
review: rubric-walker
target: ARCHITECTURE-SPINE.md (mise à jour module Multi, 2026-10-17)
date: 2026-10-17
sources: PRD §4.11 / §6.1 / §8 / §9.5 / §11 ; cahier_des_charges_module_multi.md v2 ; code du dépôt (backend/, mobile/, fixtures/, docker-compose.yml)
---

# Revue rubric walker — spine, module Multi

## Verdict

**À réviser avant le découpage en stories.** Les AD-6 à AD-11 sont bien
ciblées et leurs règles sont pour la plupart vérifiables (catalogue hors
ligne + copies octet à octet, codes enregistrés, journal en ajout seul, accès
via le repository). L'articulation avec AD-1 à AD-5 est saine. Mais quatre
points de divergence réels restent ouverts :

1. la spine contredit le cahier Multi, qui est la référence normative, sans
   dire qu'elle le remplace ;
2. les sorties du pilote et du backtest n'ont aucun chemin vers la production
   ni vers l'appareil ;
3. les entrées dérivées du serveur dont le moteur Dart hors ligne a besoin ne
   sont pas définies ;
4. la base de temps (heure de départ naïve) casse le gel du jeu retenu, le
   « avant le départ » et l'absence de fuite temporelle.

Aucun constat n'est critique au sens « la spine fait construire une chose
fausse » : chaque constat est une absence de règle, pas une mauvaise règle.

Les diagrammes mermaid sont syntaxiquement valides. Vérification faite à la
lecture : sous-graphes à titre libre, `<br/>` dans les libellés, nœud cylindre
`[( … )]`, étiquettes d'arêtes `-.->|…|`. Seuls des défauts de contenu sont
relevés (L2).

Décompte : **0 critique, 4 élevés, 9 moyens, 6 faibles.**

---

## Constats

### H1 — La spine contredit le cahier Multi normatif sans le déclarer — **élevé**

- **Emplacement :** AD-7 et Structural Seed. Côté cahier : §5.2 (générateur
  « côté backend », table `multi_systeme_cache`), §7 (schéma
  `multi_systeme_cache`), §11.3 (`assets/multi_catalog.json`,
  `scripts/export_multi_catalog.py`), §2 (constantes dans `regles.py`).
- **Problème :** le PRD §4.11 désigne le cahier v2 comme « référence normative
  non dupliquée ». Or la spine prend le contre-pied sur plusieurs points :
  - pas de table de cache ;
  - générateur uniquement sur la machine de dev ;
  - autres noms de fichiers (`multi_catalogue.json`,
    `generer_catalogue_multi.py`) ;
  - règles canoniques dans `fixtures/multi_regles.json` et non dans
    `regles.py`.

  Un agent qui écrit une story à partir du cahier, qu'il cite et que le PRD
  rend normatif, créera `multi_systeme_cache` ou `export_multi_catalog.py`.
  C'est exactement la divergence que la spine veut empêcher. Le `.memlog.md`
  trace ces choix, mais la spine ne dit nulle part qu'elle supplante le
  cahier.
- **Correctif suggéré :**
  - ajouter dans AD-7 une ligne « **Supersedes** cahier Multi §5.2 (cache,
    exécution backend), §7 (`multi_systeme_cache`), §11.3 (noms de fichiers),
    §2 (emplacement canonique des constantes) » ;
  - en parallèle, faire corriger le cahier (ou lui ajouter un erratum pointant
    vers la spine) avant le découpage en stories.

### H2 — Les sorties du pilote et du backtest n'atteignent ni la production ni l'appareil — **élevé**

- **Emplacement :** AD-11, AD-10 (« starts only once the pilot has fixed the
  reference budgets »), AD-9 (seuils dans `shared_preferences`), Deferred
  « Backtest on a server ».
- **Problème :**
  - AD-11 fait tourner le harnais sur la machine de dev contre une **copie** de
    la base de production et persiste les résultats dans
    `performance_strategie`… de cette copie. `/multi/performance` en
    production lit la base de production, qui ne contient donc rien.
  - Le pilote fixe aussi des valeurs que trois consommateurs doivent partager :
    valeurs par défaut de `seuil_couverture`, `facteur_budget_max` et
    `seuil_donnees_fragiles`, budgets de référence du journal quotidien,
    effectif minimal d'affichage des comparateurs. Ces trois consommateurs sont
    le job `ingestion`, le backend (`seuils: null` → « valeurs par défaut en
    vigueur ») et l'app (défauts de réglages, mention « seuils provisoires »).
  - Aucun emplacement n'est fixé pour ces valeurs. Deux stories vont donc
    inventer chacune le sien : une constante Python, une constante Dart, une
    variable d'environnement, une ligne de table. Python et Dart divergeront
    exactement comme AD-2 l'a interdit pour `DEFAULT_PARAMETERS`.
- **Correctif suggéré :**
  - placer les sorties gelées du pilote dans un fichier canonique versionné
    (par ex. `fixtures/multi_parametres_pilote.json` : défauts, budgets de
    référence, effectif minimal, date de gel, `provisoire: true|false`). Les
    deux langages sont validés contre ce fichier, comme pour AD-2 et AD-7 ;
  - décrire le transfert des résultats du backtest vers la production : export
    ou import via `repository.py`, ou exécution du harnais dans le conteneur
    contre la base de production en lecture plus une écriture dédiée ;
  - à défaut, déclarer explicitement que `/multi/performance` reste vide
    jusqu'au passage du harnais sur serveur.

### H3 — Les entrées dérivées du serveur dont a besoin le moteur hors ligne ne sont pas définies — **élevé**

- **Emplacement :** AD-6 (entrées du moteur), convention « State &
  cross-cutting » (« the whole Multi recommendation and verdict » hors ligne).
  Côté sources : PRD FR-25, FR-26, FR-30 ; cahier §5.4 (`r7_seuil_eur` à côté
  du R7 historique médian), §6.4 (raisons), §6.7, §10 (`statut_modele`,
  `seuils_provisoires`).
- **Problème :**
  - Les raisons du verdict et l'affichage du système dépendent de valeurs
    calculées sur l'historique serveur :
    - le R7 historique médian et ses quartiles (≥ 30 courses support en base) ;
    - le statut d'évaluation du modèle (« en cours d'évaluation » / « ne fait
      pas mieux que le marché », avec effectif) ;
    - le drapeau « seuils provisoires ».
  - AD-6 limite les entrées du moteur à la sortie du scoring (plus les données
    M1). Rien ne dit comment ces valeurs entrent dans le moteur, ni comment
    elles arrivent et sont mises en cache sur l'appareil.
  - Résultat probable : le backend calcule la médiane depuis sa base, et le
    mobile n'a rien ou la recalcule sur son cache partiel. À données égales,
    `/multi/recommandation` et le moteur Dart rendent des raisons différentes.
    Cela viole FR-23 (« identique sur le backend et sur l'appareil ») et casse
    `fixtures/multi_cases.json`.
- **Correctif suggéré :** étendre la règle d'AD-6.
  - Ces valeurs sont des **entrées explicites** du moteur (un objet
    `ContexteMarcheMulti` / `contexte_evaluation` : `r7_mediane`,
    `r7_quartiles`, `nb_courses_support`, `statut_modele`,
    `seuils_provisoires`).
  - Elles sont calculées une seule fois côté backend (via `repository.py`) et
    livrées à l'app avec les données de course, puis mises en cache avec elle.
  - Le moteur ne les calcule jamais.
  - Les cas partagés incluent les variantes « médiane absente » et « médiane
    présente ».

### H4 — Base de temps non fixée : heure de départ naïve, gel, « avant le départ », fuite temporelle — **élevé**

- **Emplacement :** AD-9 (« replaceable until the race's departure time »),
  AD-10 (journal « avant le départ »), AD-11 (backtest sans données
  postérieures). Constat dans le code :
  - `pmu_client.py:48-51` utilise `datetime.fromtimestamp(value / 1000)`,
    c'est-à-dire l'heure **locale naïve** de l'hôte ;
  - `models.py:18` déclare `heure_depart DateTime` sans fuseau ;
  - `course_summary.dart:37` fait `DateTime.parse` d'une chaîne sans décalage,
    donc interprétée comme heure locale de l'appareil.
- **Problème :** chaque environnement place l'heure de départ dans un fuseau
  différent, sans que rien ne le signale :
  - le conteneur (UTC) ;
  - la machine de dev qui exécute le backtest (fuseau local) ;
  - le téléphone (Cameroun, UTC+1, alors que les courses suivent l'heure de
    Paris avec changement d'heure).

  Les conséquences :
  - le jeu retenu se fige une heure trop tôt ou trop tard selon la saison ;
  - le « avant le départ » du journal et le contrôle `donnees_a < départ`
    (cahier §7 : `donnees_a` en **UTC**) deviennent faux selon la machine ;
  - le test 14 (absence de fuite) peut passer en dev et échouer en production.

  C'est un point de divergence transverse que ni AD-5 ni les conventions ne
  couvrent.
- **Correctif suggéré :** ajouter une convention « Temps ».
  - Tous les instants (`heure_depart`, `donnees_a`, `cree_le`, heure des
    cotes, gel du jeu retenu) sont stockés et transmis en UTC avec décalage
    explicite (ISO 8601 `Z`).
  - Seul l'adaptateur PMU convertit l'epoch ms, en UTC conscient du fuseau.
  - L'affichage convertit en heure locale.
  - Consigner le correctif de `_epoch_ms_to_datetime` dans `deferred-work.md`
    comme dette existante, au même titre que l'ex-violation d'AD-4.

### M1 — B0 (tirage au hasard) imposé en Dart sans PRNG portable — **moyen**

- **Emplacement :** AD-6 (« the M1/B0/B1 comparators » dans les deux
  langages ; cas partagés dans `multi_cases.json`). Cahier §4.5 (« graine fixée
  par `course_id` »), §9 test 15, §11.1 (l'écran montre M1 et B1, **pas** B0).
- **Problème :** AD-2 a établi que `numpy.random` et `dart:math Random` ne
  produisent pas les mêmes tirages à graine égale. Un B0 en Dart ne peut donc
  pas partager un cas exact avec Python. Il sera soit absent des fixtures, soit
  implémenté avec deux générateurs différents. De plus, B0 n'est que journalisé
  (backend) : le porter en Dart ne sert à rien.
- **Correctif suggéré :** deux options.
  - (a) B0 existe uniquement en Python (journal et backtest), et la spine le
    dit.
  - (b) Si un portage est voulu, B0 est défini sans PRNG : ordre par
    `sha256(course_id + ":" + num)` puis prise des `taille` premiers. C'est
    déterministe et identique dans les deux langages, donc testable par
    fixture.

### M2 — Entrées de M1 (dernier rang, allocation, décodeur de musique) préparées uniquement par `repository.py` — **moyen**

- **Emplacement :** AD-6 (« last-race rank and allocation already normalized
  by `repository.py` »). Cahier §3 (piège sur le rang, `source_rang`), annexe D
  (décodeur de musique).
- **Problème :** M1 doit exister en Dart (AD-6) et être consultable hors ligne
  (§11.1, « Autres méthodes »). Or son entrée est fabriquée côté backend. Rien
  ne dit si l'app reçoit `dernier_rang` et `derniere_allocation` tout faits
  dans le payload de course, ou si elle doit décoder la musique depuis son
  cache `historique_performances`. Dans le second cas, il faut un second
  décodeur, non couvert par les fixtures.
- **Correctif suggéré :**
  - fixer que `dernier_rang`, `derniere_allocation` et `source_rang` voyagent
    dans le payload de participation (champs nullables, comme pour AD-5) et
    sont mis en cache tels quels ;
  - le décodeur de musique n'existe qu'à un seul endroit, l'adaptateur backend.
    Sinon, l'ajouter à la liste des modules en double avec cas partagés.

### M3 — Rôle des endpoints Multi et données Multi côté appareil non tranchés — **moyen**

- **Emplacement :** AD-6, AD-9, diagramme Multi. Côté sources : PRD §6.1
  (`/courses/{id}/multi/eligibilite`, `/multi/recommandation`, `/systemes`,
  `/verifier`, `/evaluer`), FR-22 (partants déclarés non analysés), FR-23
  (non-partants par rafraîchissement), FR-30 (arrivée, correction d'arrivée,
  débrief).
- **Problème :**
  - (a) Rien ne dit si l'app appelle `/multi/recommandation` et les autres
    endpoints quand elle est en ligne, ou si elle calcule toujours en local.
    Les deux chemins coexistant, une story pourra afficher le résultat serveur
    en ligne et le résultat local hors ligne, ce qui crée deux sources de
    vérité.
  - (b) Le débrief et l'éligibilité ont besoin sur l'appareil de plusieurs
    données : `est_course_support`, `nb_partants_declares`, non-partants,
    `arrivee_json` avec ex-aequo, et le marqueur de correction d'arrivée. Or la
    migration v2 d'AD-9 n'ajoute que `jeu_retenu` et
    `recommandation_consultee`. Une story suivante devra créer une v3 non
    planifiée ou glisser ces champs dans `programme_courses`.
  - Le diagramme Multi n'a d'ailleurs aucune arête mobile → backend.
- **Correctif suggéré :**
  - ajouter à AD-6 : « l'app calcule toujours en local ; les endpoints de
    calcul servent les clients sans moteur (Postman, journal, futur web) et la
    parité, jamais l'écran » ;
  - ajouter à AD-9 la liste des données de course Multi mises en cache
    (éligibilité, non-partants, arrivée et version de correction), incluses
    dans la même migration v2 ;
  - ajouter l'arête `api_client.dart` → `routes_*` au diagramme.

### M4 — Règles du pari : provenance, date de vérification et chargement à l'exécution non fixés — **moyen**

- **Emplacement :** AD-7 (« `regles.py` and `regles.dart` are validated
  against it »). PRD FR-22 : « provenance et date de dernière vérification ;
  sans cette date, aucun coût n'est affiché ».
- **Problème :**
  - `fixtures/` n'est ni dans le contexte Docker (`build: ./backend`) ni dans
    les assets Flutter. Les règles sont donc forcément recopiées en dur dans
    `regles.py` et `regles.dart`, puis validées par test. C'est acceptable,
    mais rien n'impose que `multi_regles.json` porte `source` et
    `date_verification`.
  - Rien n'impose non plus que les deux moteurs refusent d'afficher un coût
    quand la date est absente. Une langue peut l'implémenter et l'autre non.
- **Correctif suggéré :**
  - exiger dans AD-7 que `multi_regles.json` contienne `provenance` et
    `date_verification` (null tant que §9.5 n'est pas fait) ;
  - ces deux champs sont recopiés et validés comme les autres constantes ;
  - un cas partagé vérifie que, avec `date_verification = null`, aucune option
    ne porte de `cout_eur` et que l'avertissement codé correspondant est émis.

### M5 — Relabellisation du catalogue et revérification à l'exécution non fixées — **moyen**

- **Emplacement :** AD-7. Cahier §5.2 (« calculé sur les indices `0..v'-1`,
  puis relabellé »), §11.3 (« l'application relabelle et revérifie
  localement »), PRD FR-25 (« vérification systématique, jamais contournée »).
- **Problème :**
  - L'ordre de correspondance entre indices du catalogue et dossards de
    `S \ B` n'est pas fixé (dossard croissant ? `top4` décroissant ?). Python
    et Dart peuvent produire des grilles différentes de même taille. Les
    `tickets` divergent, ainsi que la carte de couverture et
    `tickets_payants_moyens_si_couvert`, puisque la multiplicité dépend du
    relabelling (cahier §5.5).
  - AD-7 laisse croire que la vérification à la génération suffit, alors que
    le cahier exige une revérification à l'exécution.
- **Correctif suggéré :**
  - fixer la règle de relabellisation (par ex. `S \ B` trié par dossard
    croissant → indices `0..v'-1`) et la couvrir par un cas partagé portant
    sur `tickets` ;
  - ajouter : « tout système relabellé passe par `verifier_couverture` avant
    d'être renvoyé ou affiché, des deux côtés ».

### M6 — Troncature de l'optimisation sur téléphone : une branche réservée à un seul côté — **moyen**

- **Emplacement :** AD-6. Cahier §4.1 (« s'il ne paraît pas instantané,
  l'étape 3 est limitée en nombre d'itérations et l'avertissement
  `optimisation_tronquee` est ajouté »), PRD §11 Q1.
- **Problème :** si la limite d'itérations n'est appliquée qu'en Dart, ou si
  elle est réglée sur un temps écoulé, l'appareil et le backend rendent des
  recommandations différentes à données identiques. C'est une violation
  directe de FR-23, et le cas n'est ni décidé, ni différé, ni en question
  ouverte dans la spine.
- **Correctif suggéré :**
  - la limite, si elle existe, est un **nombre d'itérations** identique dans
    les deux langages, présent dans les paramètres partagés (fixture) ;
  - jamais une limite de temps.
  - Sinon, ajouter un élément différé explicite : « troncature : décision après
    mesure sur l'appareil cible ; si adoptée, en itérations, symétrique ».

### M7 — Égalité à 1e-9 non transitive et seuil d'échange à 1e-12 — **moyen**

- **Emplacement :** AD-6 (« Options whose coverage probabilities differ by
  less than 1e-9 are tied »). Cahier §4.1 étape 3 (gain > 1e-12), §4.3.
- **Problème :**
  - Une égalité à epsilon n'est pas transitive (A≈B, B≈C, A≉C). Le résultat
    d'un tri ou d'un `max` dépend donc de l'ordre de parcours, qui diffère
    entre une version numpy vectorisée et des boucles Dart.
  - Par ailleurs, le seuil de 1e-12 sur les échanges est assez proche des
    écarts d'arrondi d'une somme de 4 845 termes calculée dans un ordre
    différent pour qu'un échange soit accepté d'un côté et refusé de l'autre.
- **Correctif suggéré :**
  - imposer dans AD-6 un **ordre de parcours canonique** (b, v, k croissants)
    et une règle de mise à jour « remplacer la meilleure option seulement si
    gain > 1e-9, ou si égalité à 1e-9 et règle de départage favorable » ;
  - imposer un ordre de sommation canonique pour `p_couverture` (ensembles
    énumérés en ordre lexicographique de dossards) ;
  - ajouter à `multi_cases.json` un cas construit pour tomber près des seuils.

### M8 — Enveloppe opérationnelle du journal quotidien et de la base SQLite — **moyen**

- **Emplacement :** AD-10, Deferred « Deployment/environments ».
  `docker-compose.yml`, `backend/app/jobs/scheduler.py`.
- **Problème :**
  - Planification : le scheduler actuel lance une passe par jour à
    `INGEST_HOUR=6`. Le journal Multi doit tourner « avant le départ » de la
    course support, avec des cotes horodatées, gérer un « départ décalé », puis
    déclencher l'ingestion des rapports après finalisation. Rien ne fixe quand
    il tourne par rapport au départ ni comment un échec est rattrapé.
  - Persistance : le journal en ajout seul est **la** preuve d'évaluation
    (SM-4) et vit sur un unique volume SQLite partagé par deux conteneurs. Il
    n'y a ni sauvegarde, ni politique d'écriture concurrente (WAL, timeouts),
    ni plan de restauration.
  - Fréquence PMU : les appels supplémentaires (rapports, rafraîchissement
    avant départ) relèvent de la Q6 du PRD, absente du Deferred.
- **Correctif suggéré :**
  - ajouter à AD-10 la règle de planification : passe Multi à H-x du départ,
    calculé en UTC (voir H4), et ligne `non_journalise` si le départ est
    dépassé ;
  - ajouter au Deferred ou décider : sauvegarde du volume `hippique_data`
    (au minimum une copie quotidienne de `recommandation_multi`), mode WAL
    SQLite, et la Q6 du PRD pour les appels Multi.

### M9 — Le harnais AD-11 « même code » tourne sur une pile numérique différente de la production — **moyen**

- **Emplacement :** AD-11, Stack. Constat : `backend/.venv` utilise
  Python 3.15.0 et NumPy 2.5.4, alors que la production utilise Python 3.12 et
  NumPy 1.26.4 (`requirements.txt`, Dockerfile).
- **Problème :** le backtest et le pilote, qui fixent les seuils gelés de la
  période de test, sont produits par une autre version de l'interpréteur et de
  NumPy que le journal `live`. Les écarts numériques sont minimes, mais
  `version_strategie` et `empreinte_entrees` laissent croire à une identité
  qui n'existe pas. Une story pourrait aussi introduire une API NumPy 2
  absente en 1.26.4 sans que les tests locaux le voient.
- **Correctif suggéré :**
  - fixer dans AD-11 que le harnais s'exécute dans l'image Docker du backend
    (`docker compose run --rm -e DATABASE_URL=… api python -m
    app.jobs.backtest_multi`) contre la copie de la base, y compris sur la
    machine de dev ;
  - ajouter au Stack : « tests backend exécutés sous la version épinglée de
    production ».

### L1 — Mentions obsolètes dans AD-3 et AD-4 — **faible**

- **Emplacement :** AD-3 Binds (« `vision_client.py` (not yet created) »),
  AD-4 (« Existing violation… `routes_analyse.py` … `horse.__dict__` »).
- **Problème :** `backend/app/data/vision_client.py` existe (stories 4.1 et
  4.2), et `__dict__` n'apparaît plus dans `backend/app/api/`. La spine décrit
  un état du code dépassé. Un lecteur pourrait refaire ou « corriger » ce qui
  l'est déjà.
- **Correctif suggéré :** retirer « not yet created » et passer la violation
  d'AD-4 au passé (« corrigée par la story 1.3 »).

### L2 — Diagrammes : contenu incomplet ou inexact (syntaxe valide) — **faible**

- **Emplacement :** diagramme 1 (`MOBILE_API[mobile: data/remote/api_client.py]`)
  et diagramme 2.
- **Problème :**
  - le fichier réel est `mobile/lib/data/remote/api_client.dart` ;
  - le diagramme Multi omet `pmu_client.py` (rapports Multi, marqueur course
    support), le lien mobile → backend (éligibilité, arrivée) et l'écran ou les
    providers Multi ;
  - `CATB`/`CATM` sont reliés au moteur, mais rien ne montre le test d'identité
    octet à octet.
- **Correctif suggéré :**
  - corriger l'extension en `.dart` ;
  - ajouter `PMU[data/pmu_client.py] --> JOBLOG` (ou `REPO`),
    `MOBILE_API --> ROUTES` et `MULTI_UI[screens/providers Multi] --> MULTID` ;
  - optionnellement, ajouter `CATB -.->|byte-identity test| CAT`.

### L3 — Identité octet à octet et conversion des fins de ligne Git — **faible**

- **Emplacement :** AD-7. Constat : `core.autocrlf=true` et aucun
  `.gitattributes` dans le dépôt.
- **Problème :** les trois fichiers sont convertis de la même façon, donc le
  test d'identité passe sur une même extraction. En revanche, l'asset APK
  construit sous Windows (CRLF) et l'image Docker construite sur le VPS (LF)
  n'ont pas les mêmes octets. Toute empreinte du catalogue (par exemple dans
  `empreinte_entrees`) différera entre backend et mobile.
- **Correctif suggéré :** ajouter un `.gitattributes` avec `fixtures/*.json`,
  `backend/app/engine/multi/*.json` et `mobile/assets/*.json` en `-text` (ou
  `eol=lf`).

### L4 — Structural Seed incomplet pour le Multi — **faible**

- **Emplacement :** Structural Seed.
- **Problème :**
  - manquent `backend/app/api/routes_multi.py`, les modules de `jobs/` (journal
    Multi, backtest), `backend/tests/` (chargement des `multi_*.json` côté
    Python), `mobile/lib/data/local/database_helper.dart` (v2) et le
    `screens/`/`providers/` Multi ;
  - le nom du fichier de routes est flou (« `api/routes_multi` » sans
    extension dans AD-10 et le diagramme).
- **Correctif suggéré :** compléter l'arbre et écrire `routes_multi.py` partout.

### L5 — Reproductibilité du générateur (dépendances inline non verrouillées) — **faible**

- **Emplacement :** AD-7, Stack (SciPy 1.18.0, uv 0.13.1).
- **Problème :**
  - des dépendances PEP 723 non épinglées (ni `==`, ni `[tool.uv]
    exclude-newer`) font qu'une régénération future, déclenchée par un
    changement de règles, prendra une autre version de SciPy/HiGHS ;
  - de plus, le recuit et la limite de temps MILP ne sont pas déterministes ;
  - les diffs du catalogue seront donc bruités, et un système peut grossir
    sans changement de règles.

  Ce n'est pas une divergence entre unités, puisque les copies restent
  identiques, mais c'est une dérive silencieuse.
- **Correctif suggéré :**
  - épingler `scipy==1.18.0` (et numpy) dans le bloc PEP 723, ou utiliser
    `exclude-newer` ;
  - fixer les graines du recuit ;
  - ajouter une règle « une régénération ne peut pas augmenter le
    `nb_tickets` d'une entrée sans justification consignée ».

### L6 — Deferred : quelques dimensions de la source non listées — **faible**

- **Emplacement :** Deferred.
- **Problème :** plusieurs éléments des sources ne sont ni décidés, ni
  différés, ni en question ouverte :
  - Flexi (cahier §12 Q2) ;
  - systèmes mixtes et choix du système parmi les équivalents (V1.5/V2,
    cahier §5.5-5.6) ;
  - licence du dépôt La Jolla si le générateur s'en sert pour l'amorçage
    (cahier §12 Q10) ;
  - seuil « instantané » (PRD Q1), qui conditionne M6.

  Aucun ne crée de divergence aujourd'hui, mais la rubrique demande que chaque
  dimension soit classée.
- **Correctif suggéré :** une ligne par élément dans le Deferred, avec renvoi
  à la source.

---

## Points conformes (pour mémoire)

- **AD-6 et AD-1/AD-2 :** cohérents. Le moteur Multi est pur, en aval du
  scoring et testé par fixtures partagées. Le calcul exact de `p_couverture`
  (énumération, sans Monte-Carlo) échappe bien au carve-out Monte-Carlo
  d'AD-2.
- **AD-7 et le code :** compatible. `Dockerfile` (`COPY app ./app`) embarque la
  copie placée dans `backend/app/engine/multi/`. `pubspec.yaml` n'a encore
  aucun `assets:`, ce qu'AD-7 lie explicitement. Les tests Dart lisent déjà
  `../fixtures/` (`scoring_test.dart:26`), ce qui confirme le modèle.
- **AD-8 :** règle vérifiable des deux côtés, et le report de gen-l10n est
  correctement différé.
- **AD-10 :** l'immuabilité, la ligne `non_journalise` et l'accès via
  `repository.py` correspondent au cahier §7 et au PRD FR-30.
- **Stack :** le confinement SciPy (NumPy ≥ 2) / NumPy 1.26.4 (VPS SSE2) via uv
  et PEP 723 est justifié et cohérent avec `requirements.txt`. Python 3.15 sur
  la machine de dev est confirmé (`C:\Python315`).
