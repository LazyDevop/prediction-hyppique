# Revue adversariale — module Multi (AD-6 à AD-11)

- **Cible :** `ARCHITECTURE-SPINE.md` (mise à jour du 2026-10-17), interaction AD-6..AD-11 avec AD-1..AD-5.
- **Lentille :** construire deux unités d'un niveau inférieur (epics/stories) qui respectent chaque AD à la lettre et qui pourtant se construisent de façon incompatible.
- **Sources lues :** spine ; PRD §4.11 (FR-22 à FR-30) ; `docs/cahier_des_charges_module_multi.md` v2 ; code existant (`backend/app/data/models.py`, `pmu_client.py`, `engine/scoring.py`, `mobile/lib/data/local/database_helper.dart`, `providers/params_provider.dart`, `models/course_summary.dart`).
- **Date :** 2026-10-17.

## Verdict

**À reprendre avant le découpage en epics.** Les AD Multi fixent bien *où* vivent les choses (catalogue hors ligne, règles canoniques, codes, stockage local, dépôt, harnais), mais presque jamais *la forme* des données partagées ni *l'identité* des versions et des courses. On peut construire, AD en main, un générateur et deux lecteurs de catalogue incompatibles, un moteur Python et un moteur Dart qui produisent des grilles différentes pour la même recommandation, un harnais dont les résultats n'atteignent jamais la production, et un jeu retenu qui se fige à la mauvaise heure. Quatre trous sont critiques, sept sont de sévérité haute. Aucun ne demande de changer le paradigme. Il faut resserrer AD-6, AD-7, AD-9, AD-10 et AD-11, et ajouter deux conventions (identité de course, instants).

Échelle : **Critique** (deux unités conformes produisent des résultats faux ou inconciliables sans qu'aucun test ne le voie) · **Haute** (divergence probable, détectée tard) · **Moyenne** (divergence possible, coût de reprise modéré) · **Basse** (nettoyage).

---

## Constats

### 1. Le cahier Multi v2, normatif selon le PRD, contredit le spine — **Critique**

- **Unités en conflit :** story « générateur + catalogue » écrite depuis le cahier (§5.2, §7, §11.3) **contre** story « catalogue » écrite depuis AD-7.
- **Comment les deux respectent les AD et divergent :** le PRD §4.11 déclare le cahier « référence normative non dupliquée ici ». Or le cahier prévoit encore une table `multi_systeme_cache` lue et écrite via `repository.py` (§5.2, §7), un générateur qui « tourne côté backend » (§5.2), un script `scripts/export_multi_catalog.py` et un asset `assets/multi_catalog.json` (§11.3). AD-7 dit le contraire : pas de table de cache, générateur `scripts/generer_catalogue_multi.py` exclusivement sur la machine de développement, fichier `multi_catalogue.json`. Une story qui suit le cahier passe AD-1 et AD-10 (accès au cache par le dépôt) et pose SciPy dans le backend. Une story qui suit AD-7 lit un autre nom de fichier. Le test d'identité au bit près d'AD-7 ne détecte rien, puisqu'il compare deux copies du même nom.
- **Correctif AD :** ajouter à AD-7 (ou en tête des AD Multi) une clause de préséance : « Là où le cahier Multi v2 contredit AD-6..AD-11 (§5.2 cache et générateur backend, §7 `multi_systeme_cache`, §11.3 noms de script et d'asset), le spine prévaut. » Lister ces sections dans une ligne `supersedes`, puis amender le cahier (v2.1) pour qu'aucune story ne puisse citer le texte périmé.

### 2. Personne ne possède la correspondance indices du catalogue → dossards — **Critique**

- **Unités en conflit :** moteur Multi Python (`couverture`/`recommandation`) **contre** moteur Multi Dart. Effets en aval : export texte des grilles (FR-21), jeu retenu (AD-9), journal quotidien (AD-10).
- **Comment les deux respectent les AD et divergent :** le catalogue stocke des blocs sur des indices `0..v'-1` (cahier §5.2). L'étape de relabellisation n'est spécifiée nulle part. Python peut relabelliser `S \ B` par dossard croissant, et Dart dans l'ordre de la sélection (rang `top4`). Les deux produisent un système valide de même `N` et de même `p_couverture`, puisque la couverture est totale dans les deux cas. AD-6 est donc tenu, et un fichier `multi_cases.json` qui ne compare que `nb_tickets`/`p_couverture` passe. Pourtant les **tickets** diffèrent, ainsi que `tickets_payants_moyens_si_couvert`, la carte de couverture et les grilles exportées. Le cahier §5.5 rappelle lui-même que la répartition du recouvrement compte avec des probabilités hétérogènes. Le jeu que l'utilisateur joue n'est alors pas celui que le serveur journalise ou réévalue.
- **Correctif AD :** dans AD-7, fixer la relabellisation comme une fonction canonique de `regles`, avec des fixtures. Exemple : associés `S \ B` triés par dossard croissant, l'indice `i` donne le i-ème dossard ; bases ajoutées ; chaque ticket trié ; tickets triés lexicographiquement. Dans AD-6, imposer que `multi_cases.json` compare les **listes de tickets** exactes, pas seulement leur nombre.

### 3. Forme, clé et version du fichier catalogue non fixées ; générateur non déterministe — **Haute**

- **Unités en conflit :** générateur hors ligne **contre** lecteurs Python et Dart (et entre eux).
- **Comment les deux respectent les AD et divergent :** AD-7 fixe l'emplacement, la copie au bit près et le comportement en cas d'entrée absente. Il ne fixe ni la clé (`(v', k', t')` ou `(v, b, k)` ? chaîne `"12_7_3"` ou objet ?), ni le domaine couvert (le cahier §11.3 annonce `k' ∈ [1,7]`, `t' ∈ [1,4]`, ce qui inclut des triplets absurdes `k' < t'`), ni les métadonnées (`optimal_prouve`, `solveur`, version des règles d'origine), ni le format des blocs. Le générateur peut écrire `{"v'":…}` pendant qu'un lecteur attend des listes : les deux respectent AD-7. De plus, le palier 3 (recuit, plusieurs graines, limite de temps) n'est pas déterministe. Un « régénérer à chaque changement des règles » (AD-7) produit d'autres blocs pour les mêmes clés, sans qu'aucun identifiant ne distingue l'ancien catalogue du nouveau. Les entrées journalisées avant la régénération deviennent irreproductibles (voir constat 9).
- **Correctif AD :** AD-7 renvoie à un schéma versionné (`format_version`, `catalogue_id` = sha256 du contenu canonique, `regles_sha256` des champs dont il dépend, entrées `{v_prime, k_prime, t_prime, blocs, solveur, optimal_prouve}` sur un domaine explicite `1 ≤ t' ≤ k' ≤ v' ≤ 20`). Les lecteurs refusent un `format_version` inconnu. Une régénération ne remplace une entrée que par un système strictement plus petit et vérifié ; sinon l'entrée existante est conservée octet pour octet.

### 4. La recommandation affichée sur le téléphone et celle journalisée par le serveur n'ont pas d'identité commune — **Critique**

- **Unités en conflit :** job quotidien de journalisation (AD-10) **contre** écran et fournisseurs Multi mobiles (AD-9, `recommandation_consultee`). Le harnais de backtest (AD-11) est aussi concerné.
- **Comment les deux respectent les AD et divergent :** AD-6 garantit seulement qu'à entrées identiques, les deux moteurs choisissent la même recommandation. Les entrées réelles diffèrent pourtant :
  - paramètres moteur : le serveur prend les défauts, le téléphone les réglages `shared_preferences` de l'utilisateur ;
  - seuils du verdict ;
  - heure des cotes ;
  - non-partants marqués localement ;
  - chevaux saisis à la main.
  
  Les versions de code divergent aussi : l'application publiée est en retard sur le backend. `version_strategie` est « un semver incrémenté à toute modification de règle » (cahier §4.0), sans dire **qui** le tient. Deux bases de code le déclarent chacune pour elles, et rien ne lie ce numéro au catalogue, à `multi_regles.json` ni au registre de codes. Python peut passer `modele` en 1.1.0 pendant que Dart reste en 1.0.0 avec la même logique, ou l'inverse. Les deux respectent AD-6, et le débrief compare alors des choses non comparables.
- **Correctif AD :** dans AD-6, la version d'une stratégie est une donnée partagée (par exemple `fixtures/multi_versions.json`, lue par les deux langages et validée comme AD-2). L'identité complète d'une recommandation est un tuple `{strategie, version_strategie, catalogue_id, regles_sha256, codes_sha256, parametres canoniques}`, stocké à l'identique dans `recommandation_multi` et dans `recommandation_consultee`. Énoncer aussi que **le serveur journalise toujours avec les paramètres par défaut figés**, et que l'écart avec la recommandation consultée sur l'appareil est attendu et visible.

### 5. Parité « à 1e-9 près » sur des entrées qui ne sont garanties qu'à tolérance — **Haute**

- **Unités en conflit :** moteur Multi Python **contre** moteur Multi Dart.
- **Comment les deux respectent les AD et divergent :** AD-6 départage les **options** à 1e-9. Mais :
  - (a) AD-2 ne garantit la parité du cœur de scoring qu'« à tolérance », et un `top4` ou un `p_gagnant` qui diffère au 1e-12 suffit à inverser un tri ;
  - (b) l'étape d'échanges (cahier §4.1, seuil 1e-12), l'ordre des bases candidates (§4.2, « égalité » sur `top4`) et l'alternative « à moins de 2 points » utilisent d'autres comparaisons de flottants qu'AD-6 ne couvre pas ;
  - (c) numpy (sommation par paires) et une boucle Dart séquentielle n'additionnent pas `P_ens` dans le même ordre.
  
  Les deux moteurs respectent AD-6 et AD-2 et retiennent pourtant des sélections différentes sur un quasi-ex-aequo.
- **Correctif AD :** étendre AD-6. Toute comparaison de flottants calculés (tri des candidats, gain d'échange, ordre des bases, seuils d'alternatives, verdict) passe par un epsilon déclaré dans `multi_regles.json`. Les entrées du moteur Multi sont quantifiées (par exemple arrondies à 1e-12) avant usage. L'ordre de sommation est canonique (ensembles énumérés en ordre lexicographique d'indices). `multi_cases.json` contient des cas de quasi-égalité.

### 6. Le harnais tourne sur une copie de la base : résultats et défauts du pilote n'atteignent jamais la production ni l'app — **Critique**

- **Unités en conflit :** harnais de backtest et pilote (AD-11) **contre** `/multi/performance` (AD-11), job quotidien (AD-10) et réglages mobiles (AD-9).
- **Comment les deux respectent les AD et divergent :** AD-11 dit que le harnais, configuré par `DATABASE_URL`, tourne sur la machine de développement contre une **copie** et persiste dans `performance_strategie`. Il écrit donc dans la copie. `/multi/performance` « ne lit que les résultats persistés » de la base de production, qui reste vide. Ensuite, le pilote fixe `seuil_couverture`, `facteur_budget_max`, `seuil_donnees_fragiles`, les budgets de référence et l'effectif minimal (cahier §8.4), mais aucun AD ne dit où ces valeurs vivent. Le job quotidien peut les lire d'une variable d'environnement, l'API de `performance_strategie`, et Dart les coder en dur dans ses défauts `shared_preferences`. Les trois respectent AD-9, AD-10 et AD-11, et divergent. La mention « seuils provisoires » n'a pas non plus de source de vérité.
- **Correctif AD :** dans AD-11, les sorties du pilote sont exportées dans un fichier canonique `fixtures/multi_defauts.json` (valeurs, date de gel, identifiant du pilote, drapeau `provisoire`). Le job, l'API (`seuils: null`) et les défauts Dart le lisent ou sont validés contre lui, selon le modèle d'AD-2. Les résultats de `performance_strategie` remontent en production par une commande d'import explicite (passant par `repository.py`, idempotente). Variante : déclarer que le harnais pointe directement sur la base de production en lecture/écriture. Il faut choisir l'une des deux.

### 7. Identité de la course : entier auto-incrémenté local, clé PMU textuelle ou rien — **Haute**

- **Unités en conflit :** routes Multi (cahier §10 : `"course_id": "20261016-R1-C5"`) **contre** cache mobile (`programme_courses.id INTEGER` = `courses.id` auto-incrémenté du backend). Également : le comparateur `B0` (« graine fixée par `course_id` ») et le jeu retenu (AD-9).
- **Comment les deux respectent les AD et divergent :** la convention « Data & formats » fixe l'identité stable du **cheval** (`nom_normalise`), jamais celle de la **course**. `courses.id` dépend de l'ordre d'ingestion : une base reconstruite ou un backfill `open_pmu_client.py` passé dans un autre ordre produit d'autres ids. Un jeu retenu référencé par cet entier pointe alors vers une autre course, et la graine `B0` change entre la production et la copie du harnais. Le moyen de dériver la graine n'est pas spécifié non plus : `hash()` Python est randomisé par processus. Enfin, une course saisie à la main ou importée par photo n'a aucun id.
- **Correctif AD :** nouvelle ligne de convention : « La clé de course inter-systèmes du module Multi est la clé PMU naturelle `AAAAMMJJ-Rn-Cn` ; `courses.id` reste interne au backend. » La graine `B0` est `sha256(clé)` tronquée, selon un algorithme écrit. Le jeu retenu est indexé par cette clé. Une course sans clé PMU n'est pas éligible à « Je retiens ce jeu » (ou reçoit un UUID local explicitement non réconciliable).

### 8. Fuseaux horaires : gel au départ, journalisation « avant le départ », purge à 90 jours — **Haute**

- **Unités en conflit :** ingestion (`pmu_client._epoch_ms_to_datetime`) **contre** gel du jeu retenu sur mobile (AD-9) et job quotidien (AD-10).
- **Comment les deux respectent les AD et divergent :** il s'agit d'une **violation existante**. `datetime.fromtimestamp(ms/1000)` produit une heure naïve dans le fuseau du conteneur, UTC par défaut sous Docker. Elle est stockée en `DateTime` naïf et sérialisée sans décalage. Côté mobile, `DateTime.parse` interprète cette chaîne naïve comme heure locale de l'appareil. Une course de 15 h 00 à Paris devient « 13 h 00 », et le jeu retenu se fige deux heures trop tôt. Pendant ce temps, `donnees_a` est « UTC » (cahier §7) et le job compare à une `heure_depart` naïve. La base de la purge à 90 jours (création, date de course, heure locale ou UTC) n'est pas dite. Aucun AD ne parle d'instants.
- **Correctif AD :** convention « Instants » : tout instant est en UTC avec décalage explicite (ISO 8601 `Z`) sur le fil et en base. L'affichage se fait en `Europe/Paris`. Le gel compare des instants UTC. La purge porte sur la date de la course (calendrier Paris). Consigner `_epoch_ms_to_datetime` comme correction à faire (*fix-forward*), comme pour AD-4.

### 9. `resultat_recommandation` : plusieurs écrivains, système non reproductible, correction d'arrivée sans chemin — **Haute**

- **Unités en conflit :** ingestion des rapports et de l'arrivée (finalisation) **contre** job quotidien **contre** harnais de backtest (résultats en mode `backfill`).
- **Comment les deux respectent les AD et divergent :** AD-10 dit seulement « via `repository.py` ». L'ingestion peut remplir `resultat_recommandation` à la finalisation, et le harnais le faire aussi pour ses lignes : tous deux passent par le dépôt. `couts_json` et `gains_json` sont « par k ». Or `recommandation_multi` ne stocke ni `k`, ni les tickets, ni l'identifiant du catalogue (seulement `selection_json`, `bases_json`, `taille`). L'écrivain doit donc **recalculer** le système depuis le catalogue courant, qui a pu être régénéré entre-temps (constat 3). Enfin, une correction de l'arrivée après finalisation (cahier §7) se heurte à `recommandation_id UNIQUE`. Une story fait `UPDATE` (AD-10 ne rend immuable que `recommandation_multi`), une autre insère : conflit.
- **Correctif AD :** dans AD-10, désigner un seul écrivain de `resultat_recommandation` (une étape `finaliser_multi` du job d'ingestion, que le harnais appelle pour le mode `backfill`). `recommandation_multi` stocke le système complet ou au minimum `catalogue_id` + `k` par option journalisée. Un résultat est recalculable, et une correction d'arrivée crée une nouvelle ligne versionnée (`version_arrivee`) au lieu d'écraser.

### 10. `multi_course` : deux propriétaires pour l'éligibilité et l'arrivée — **Haute**

- **Unités en conflit :** ingestion PMU (rapports, arrivée, marqueur « course support ») **contre** route `/courses/{id}/multi/eligibilite` et job quotidien (qui détermine la course support du jour).
- **Comment les deux respectent les AD et divergent :** `est_course_support`, `nb_partants_declares`, `finalisee` et `arrivee_json` peuvent être écrits par n'importe quel module passant par le dépôt. De plus, `finalisee` double `courses.finalisee`, et `arrivee_json` double `participations.rang_arrivee`. Une story « éligibilité » peut calculer et persister le drapeau à la volée, et la story d'ingestion l'écraser avec le marqueur PMU. Les deux sources peuvent se contredire sans règle de priorité.
- **Correctif AD :** dans AD-10, l'ingestion est l'unique écrivain de `multi_course`. La route d'éligibilité et le job ne font que lire. Les champs dupliqués sont soit dérivés en lecture (vues), soit déclarés comme la seule source, avec l'autre colonne obsolète.

### 11. Clé d'unicité de `recommandation_multi` contre entrées d'échec, relances et itérations du pilote — **Haute**

- **Unités en conflit :** job quotidien (relance après échec) **contre** harnais et pilote (plusieurs passes en `backfill`).
- **Comment les deux respectent les AD et divergent :** AD-10 veut qu'un échec soit « journalisé comme une entrée », et la clé `UNIQUE (course_id, strategie, version_strategie, mode, budget_eur)` vient du cahier §7. Une relance réussie après un échec occupe la même clé : violation. Avec `budget_eur` NULL pour les comparateurs, SQLite traite les NULL comme distincts, donc une relance **duplique** silencieusement M1, B0 et B1. Côté pilote, chaque nouvelle passe doit, pour ne pas violer l'immuabilité, incrémenter `version_strategie`, ce qui gonfle artificiellement la liste des variantes testées (correction de Holm, cahier §8.3).
- **Correctif AD :** dans AD-10, les exécutions et les échecs vont dans une table de journal séparée (`execution_multi` : course, date, statut, raison). `recommandation_multi` ne reçoit que des recommandations. Aucune colonne de la clé n'est nullable (budget 0 ou clé distincte pour les comparateurs). Les passes du pilote portent `mode = "pilote"` et un `run_id` dans la clé.

### 12. Schéma de `multi_regles.json` et mécanisme de chargement non fixés — **Moyenne**

- **Unités en conflit :** `regles.py` **contre** `regles.dart`.
- **Comment les deux respectent les AD et divergent :** AD-7 dit « validés contre » le fichier. Le Docker ne construit que depuis `backend/`, donc `regles.py` ne peut pas lire `fixtures/` à l'exécution : il code les valeurs en dur et un test compare. Dart, lui, peut charger un asset. Les clés JSON de `RAPPORT_MIN` sont des chaînes (`"7"`), et `COEF_R7` peut être stocké ou dérivé. Les champs de provenance et de date de vérification n'ont pas de forme. On ne sait pas non plus quels champs déclenchent la régénération du catalogue.
- **Correctif AD :** traiter `multi_regles.json` comme le catalogue (copies au bit près dans `backend/app/engine/multi/` et `mobile/assets/`, chargées à l'exécution des deux côtés), avec un schéma typé (clés numériques en chaîne explicitement converties, `COEF_R7` toujours dérivé, `verifie_le`, `source`). Lister les champs qui entrent dans `regles_sha256` du catalogue (constat 3).

### 13. Registre de codes : ni version, ni types, ni politique d'évolution — **Moyenne**

- **Unités en conflit :** routes Multi (`/multi/comparateur`, `/multi/recommandation`) **contre** table de libellés Dart d'une version d'app plus ancienne.
- **Comment les deux respectent les AD et divergent :** AD-8 vérifie au moment de la compilation que chaque code a un libellé, ce qui vaut pour le registre embarqué dans **cette** version. Un backend plus récent qui ajoute ou renomme un code respecte AD-8, et l'app publiée affiche du vide ou un code brut, précisément ce qu'AD-8 voulait empêcher. Les paramètres sont déclarés par nom, sans type ni unité : `top4` peut valoir `0.41` ou `41`, et les deux respectent le registre.
- **Correctif AD :** dans AD-8, le registre ne fait que grandir (codes jamais renommés ni supprimés, seulement dépréciés). Chaque paramètre a un type et une unité déclarés (fraction 0-1, euros, entier). Les réponses API portent `codes_version`. L'app a un rendu de repli explicite et journalisé pour un code inconnu.

### 14. Deux chemins de calcul pour l'écran Multi ; dépendances serveur non mises en cache — **Moyenne**

- **Unités en conflit :** fournisseur mobile « recommandation locale » **contre** fournisseur mobile « appel `POST /multi/recommandation` ».
- **Comment les deux respectent les AD et divergent :** AD-6 met le moteur des deux côtés, et le PRD livre `/multi/recommandation` à l'incrément 1. Une story peut appeler l'API en ligne et le moteur local hors ligne, ce qui reste conforme à FR-13. Mais l'API applique les seuils par défaut (`seuils: null`) quand le local applique ceux de l'utilisateur : le verdict change selon le réseau. Par ailleurs, le verdict et les raisons utilisent des données que seul le serveur possède (R7 médian historique sur ≥ 30 courses, `est_course_support`, drapeau « seuils provisoires »). Aucun AD ne dit qu'elles sont mises en cache sur l'appareil ni sous quelle forme.
- **Correctif AD :** dans les conventions « State & cross-cutting », l'écran Multi calcule **toujours** localement. `/multi/recommandation` sert aux autres clients et aux tests de parité, jamais à l'écran. Le contexte serveur (éligibilité, R7 médian, défauts, versions) est un DTO typé mis en cache avec son horodatage, et l'écran affiche son âge.

### 15. AD-9 contre les conventions existantes de `DatabaseHelper` — **Moyenne**

- **Unités en conflit :** migration SQLite v2 et stockage du jeu retenu **contre** le modèle existant de `database_helper.dart` (et une éventuelle story « vider le cache »).
- **Comment les deux respectent les AD et divergent :** le helper actuel pose que le cache est « un bonus, jamais une condition », que tout échoue en silence, qu'il renvoie `null` sur Web et que les écritures suppriment puis remplacent. Une story qui ajoute `jeu_retenu` dans ce style respecte AD-9 et perd le jeu retenu en silence (Web, erreur d'écriture). Une story « vider le cache » respecte aussi AD-9 et efface l'historique du débrief. La purge à 90 jours n'a pas de critère de date (constat 8), et rien n'impose une suppression en cascade de `recommandation_consultee`.
- **Correctif AD :** dans AD-9, `jeu_retenu` et `recommandation_consultee` ne sont **pas** du cache. Un échec d'écriture est montré à l'utilisateur. Ces tables sont exclues de tout vidage de cache. « Je retiens ce jeu » est déclaré indisponible sur Web. La purge porte sur la date de course (Paris) et supprime les deux tables ensemble.

### 16. Le débrief rapproche des dossards locaux d'une arrivée serveur — **Moyenne**

- **Unités en conflit :** débrief mobile (AD-9) **contre** ingestion de l'arrivée (participations, `num_pmu`).
- **Comment les deux respectent les AD et divergent :** le jeu retenu stocke des dossards. Pour une course dont la liste vient d'un import photo, d'une saisie ou d'une correction locale, le dossard local peut différer du `num_pmu` ingéré. Le débrief compte alors des « chevaux capturés » faux sans erreur visible. La convention dit que `num_pmu` n'est valide que dans une course, mais pas avec quelle clé de course ni avec quel contrôle croisé.
- **Correctif AD :** dans AD-9, chaque cheval du jeu retenu est stocké sous la forme `(clé de course, num_pmu, nom_normalise)`. Le débrief fait la jointure sur `num_pmu` et vérifie `nom_normalise`. Un désaccord produit « débrief impossible » (code AD-8), jamais un compte silencieux.

### 17. Entrées de M1 (rang et allocation de la dernière course) : un décodeur ou deux ? — **Moyenne**

- **Unités en conflit :** comparateur M1 Python (entrées « normalisées par `repository.py` », AD-6) **contre** M1 Dart affiché dans « Autres méthodes » (cahier §11.1).
- **Comment les deux respectent les AD et divergent :** le mobile n'a pas de `repository.py`. Pour afficher M1, une story Dart réimplémente le décodeur de musique (annexe D) et la règle « musique prioritaire, liste détaillée en recoupement ». Une autre attend `dernier_rang` déjà décodé dans la charge utile de la course. Avec deux décodeurs, `source_rang` et les avertissements divergent, sans fixture qui les lie.
- **Correctif AD :** dans AD-6, `dernier_rang`, `source_rang` et `derniere_allocation` sont calculés **uniquement** côté backend et livrés dans la charge utile typée de la course. Dart ne décode jamais la musique. Sinon, placer le décodeur sous `multi_cases.json`.

### 18. `empreinte_entrees` sans sérialisation canonique — **Basse**

- **Unités en conflit :** job quotidien (`live`) **contre** harnais (`backfill`), et toute vérification ultérieure.
- **Comment les deux respectent les AD et divergent :** « sha256 des entrées », sans forme canonique : ordre des clés, représentation des flottants, présence des partants virtuels. Deux écrivains produisent des empreintes différentes pour les mêmes entrées.
- **Correctif AD :** dans AD-10, définir l'empreinte sur un JSON canonique (clés triées, flottants en `repr` minimal, ordre des chevaux par dossard), avec une fixture.

### 19. Compression éventuelle du catalogue et identité au bit près — **Basse**

- **Unités en conflit :** générateur **contre** tests d'identité, si le catalogue est un jour compressé (Deferred).
- **Comment les deux respectent les AD et divergent :** gzip inscrit la date de modification et le nom de fichier dans l'en-tête. Deux compressions du même contenu ne sont pas identiques, et la règle du Deferred (« l'identité porte sur la forme compressée ») devient instable.
- **Correctif AD :** dans le Deferred, préciser une compression déterministe (`mtime=0`, sans nom), ou une identité portée par `catalogue_id` (sha256 du contenu décompressé canonique).

---

## Récapitulatif

| Sévérité | Nombre | Constats |
| --- | --- | --- |
| Critique | 4 | 1, 2, 4, 6 |
| Haute | 7 | 3, 5, 7, 8, 9, 10, 11 |
| Moyenne | 6 | 12, 13, 14, 15, 16, 17 |
| Basse | 2 | 18, 19 |
| **Total** | **19** | |

**AD à resserrer :** AD-6 (version partagée, epsilons, entrées M1), AD-7 (préséance sur le cahier, schéma et identifiant du catalogue, relabellisation canonique, copies de `multi_regles.json`), AD-8 (registre qui ne fait que grandir, typé, versionné), AD-9 (jeu retenu hors cache, clé de course, purge), AD-10 (écrivain unique de `multi_course` et `resultat_recommandation`, journal d'exécution séparé, système journalisé complet), AD-11 (pilote vers `fixtures/multi_defauts.json`, rapatriement des résultats).

**Conventions à ajouter :** clé de course PMU naturelle ; instants en UTC avec décalage explicite (avec la correction existante de `pmu_client._epoch_ms_to_datetime` à consigner).
