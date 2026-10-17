# Réconciliation — spine (module Multi, 2026-10-17) vs PRD §4.11 et cahier Multi v2

Entrées : `prd.md` (§4.11 FR-22..FR-30, §6.1, §8, §9.5, §11 q. 8-12) ; `docs/cahier_des_charges_module_multi.md` (v2).
Spine : `ARCHITECTURE-SPINE.md` (AD-6 à AD-11), `.memlog.md`.

## Verdict

**Spine globalement alignée, 7 manques à combler avant de découper les stories.** Aucune contradiction non voulue avec le PRD. Les écarts avec le cahier v2 (générateur hors ligne, pas de `multi_systeme_cache`, `/multi/backtest` construit plus tard, table Dart de libellés) sont des décisions prises pendant cette mise à jour : ce sont des **documents sources à mettre à jour**, pas des manques de la spine (liste en fin de document).

Les manques ci-dessous sont des endroits où deux stories construites séparément peuvent produire des choses incompatibles. Les manques 1 à 4 sont prioritaires.

## Manques

### 1. Données serveur dont le Multi a besoin hors ligne : forme et cache non fixés

- **Source** : PRD FR-23 « La recommandation se calcule sur l'appareil, sans réseau, pour une course déjà en cache » ; FR-26 « seuil de rentabilité face au rapport historique médian (ou son absence) » ; FR-30 « le rapport "Multi en 7" historique médian quand au moins 30 courses support sont en base » ; FR-22 « course support, ≥ 14 partants déclarés », « mode exploration ». Cahier §6.7, §10 (`/courses/{id}/multi/eligibilite`).
- **Spine** : la convention « State & cross-cutting » dit que la recommandation et le verdict ne dépendent pas du réseau. Elle ne dit pas **quelles données serveur** l'appareil doit avoir en cache pour y arriver. Le R7 médian est un agrégat calculé sur la base serveur, et l'éligibilité (marqueur course support, partants déclarés) vient de `multi_course`. Aucune AD ne les met dans le contenu de course mis en cache, ni ne fixe la table sqflite qui les reçoit (AD-9 ne couvre que `jeu_retenu` et `recommandation_consultee`).
- **Risque** : la story « écran Multi » appelle `/courses/{id}/multi/eligibilite` au moment de l'affichage (donc rien ne marche hors ligne), alors que la story « cache » ne stocke que les partants. Autre cas : le verdict hors ligne affiche toujours « rapports réels inconnus » alors qu'un R7 médian existe.
- **Recommandation** : compléter AD-9 (ou ajouter une AD) avec une règle explicite. L'éligibilité (`est_course_support`, `nb_partants_declares`, mode exploration) et le R7 médian avec son effectif arrivent avec la course quand elle est importée ou rafraîchie, et sont stockés dans le cache local avec elle. Les tables locales qui en ont besoin sont créées par la même migration v2.

### 2. Qui calcule la recommandation sur mobile : l'appareil ou l'API ?

- **Source** : PRD §6.1 Incrément 1 livre `/multi/recommandation`, `/multi/systemes`, `/multi/verifier`, `/multi/evaluer`. FR-23 « se calcule sur l'appareil ». FR-23 parité : « identique sur le backend et sur l'appareil ».
- **Spine** : AD-6 met tous les modules dans les deux langages. Le diagramme du cœur indique `MOBILE_API -->|HTTP, no local calc dependency|`. Aucune AD ne dit si l'app **appelle** ces endpoints Multi, ni dans quels cas.
- **Risque** : une story mobile branche l'écran sur `/multi/recommandation` quand le réseau est là et sur le moteur Dart sinon. On a alors deux chemins pour le même écran, avec un catalogue et des seuils qui peuvent différer. Une autre story construit l'écran 100 % local. Les endpoints de l'incrément 1 risquent aussi d'être construits sans aucun consommateur identifié.
- **Recommandation** : ajouter une règle (AD-6 ou nouvelle AD). L'écran Multi calcule **toujours** avec le moteur Dart, y compris quand le réseau est disponible. Les endpoints Multi servent la journalisation, le backtest, les tests de parité et d'éventuels autres clients. L'app ne les appelle pas pour afficher une recommandation. Sinon, réduire l'incrément 1 côté API à ce qui a un consommateur (à arbitrer dans le PRD).

### 3. Valeurs par défaut du verdict et budgets de référence : pas de fichier canonique

- **Source** : cahier §6.4 « Valeurs par défaut fixées par le pilote (8.4), affichées "provisoires" jusque-là » ; §10 `"seuils": null → valeurs par défaut en vigueur` ; FR-26 ; PRD q. 10. Cahier §8.4 : le pilote fixe aussi `seuil_donnees_fragiles`, les budgets de référence de la journalisation `live` et l'effectif minimal d'affichage des comparateurs.
- **Spine** : AD-9 place les seuils **de l'utilisateur** dans `shared_preferences`. Rien ne dit où vivent les **valeurs par défaut** partagées, ni le drapeau « provisoires ». C'est pourtant le même problème qu'AD-2 a réglé pour `DEFAULT_PARAMETERS`.
- **Risque** : la valeur par défaut est écrite en dur dans le code Dart d'un côté et dans le code Python de l'autre. Le pilote met à jour un seul côté, et le verdict du job quotidien ne correspond plus à celui de l'appareil. Le job quotidien lit les budgets de référence d'un endroit non spécifié, par exemple une variable d'environnement ou `performance_strategie`.
- **Recommandation** : un fichier canonique, par exemple `fixtures/multi_parametres.json` (ou une section de `multi_cases.json` comme pour AD-2), qui contient `seuil_couverture`, `facteur_budget_max`, `seuil_donnees_fragiles`, `effectif_min_comparateurs`, `budgets_reference`, `provisoire: true|false` et la date du pilote. Python et Dart sont validés contre ce fichier. « Réinitialiser » dans les réglages revient à ces valeurs.

### 4. Évolution du schéma serveur sur une base SQLite déjà en production

- **Source** : cahier §3 « Schéma : champs à ajouter » (`Performance_historique` + `allocation`, `rang_brut`, `statut_arrivee` ; `Participation` + `cote_reference_decimale`) ; §7 nouvelles tables ; AD-10.
- **Spine** : AD-10 nomme les quatre tables. Aucune AD ne dit **comment** le schéma évolue. Le code actuel n'utilise que `Base.metadata.create_all` (`backend/app/data/repository.py:21`), qui crée les tables manquantes mais **n'ajoute pas de colonne** à une table existante. Côté mobile, la spine a fixé une migration testée (AD-9). Côté serveur, rien.
- **Risque** : la story « ingestion des rapports / M1 » ajoute les colonnes au modèle SQLAlchemy. Ça passe en test (base neuve) mais ça casse en production (`no such column`). Une autre story corrige en écrivant un `ALTER TABLE` à la main, une troisième en introduisant Alembic.
- **Recommandation** : décider du mécanisme maintenant, par exemple Alembic, ou une fonction de migration idempotente unique dans `repository.py` avec une version de schéma stockée en base. Exiger qu'une story qui modifie `models.py` livre sa migration et un test sur une base au schéma précédent.

### 5. Comparateur B0 : tirage reproductible entre langages, et présence côté Dart

- **Source** : cahier §4.5 « `B0` : tirage au hasard (graine fixée par `course_id` → reproductible) » ; test 15 « Déterminisme (y compris `B0`) ». PRD FR-29 : « Un tirage au hasard est journalisé comme repère d'évaluation, **sans être affiché** ».
- **Spine** : AD-6 met « les comparateurs M1/B0/B1 » dans les deux langages, avec cas partagés dans `multi_cases.json`. Or le carve-out d'AD-2 constate lui-même que `numpy.random` et `dart:math Random` ne donnent pas les mêmes tirages avec la même graine. Un cas de fixture B0 partagé ne pourra donc pas passer.
- **Risque** : la story Dart de B0 échoue sur la fixture partagée, ou le contourne avec un générateur ad hoc. Ou B0 est construit en Dart pour rien, puisqu'il n'est jamais affiché.
- **Recommandation** : B0 en Python seulement (il ne sert qu'à la journalisation et au backtest), et l'écrire dans AD-6 comme deuxième exception après le générateur. Si B0 doit exister des deux côtés, définir un tirage portable : ordre par `sha256(course_id + dossard)`, sans PRNG du langage.

### 6. Format et version du catalogue ; vérification à l'exécution ; emplacement des tests du générateur

- **Source** : cahier §5.2 « calculé une fois sur les indices `0..v'-1`, puis relabellé sur les dossards » ; « Vérificateur (obligatoire, jamais contourné) » ; §11.3 « L'application relabelle et revérifie localement », plage `v' ≤ 20, k' ∈ [1,7], t' ∈ [1,4]`, avertissement `systeme_absent_du_catalogue` ; §9 test 6 (« Générateur : pour chaque entrée de l'annexe A… »). PRD FR-25.
- **Spine** : AD-7 fixe l'emplacement, les copies et l'identité octet à octet. Elle ne fixe ni la **clé** des entrées (`(v', k', t')` réduit ou `(v, b, k)`), ni l'obligation de revérifier après relabelling dans les deux moteurs, ni un lien de version entre le catalogue et `multi_regles.json` (« regénéré quand les règles changent » n'a aucun contrôle). Elle ne dit pas non plus où vivent les tests du générateur, alors que celui-ci tourne dans un environnement à part (scipy, numpy ≥ 2) que les suites backend ne peuvent pas charger.
- **Risque** : le script de génération et les deux lecteurs choisissent des clés différentes. Un moteur saute la vérification « puisque le catalogue est vérifié ». Le catalogue reste périmé après un changement de règles sans qu'aucun test ne le voie. Le test 6 n'a pas d'endroit où tourner.
- **Recommandation** : compléter AD-7. Le catalogue est indexé par `(v', k', t')` sur les indices `0..v'-1`. Il porte un en-tête avec la version du format et l'empreinte de `multi_regles.json` qui a servi à le générer, et un test vérifie que cette empreinte correspond. Les deux moteurs repassent toujours le vérificateur après relabelling. Le test 6 devient un test **sur le catalogue** (taille ≤ annexe A, couverture complète), exécuté par pytest et Dart sans scipy. Seul le comportement interne du solveur est testé à côté du script, dans son environnement `uv`.

### 7. Pas de fuite temporelle, version de stratégie et empreinte des entrées : qui les garantit ?

- **Source** : cahier §7 « toute recommandation en mode `backfill` ne lit que les données antérieures à `donnees_a` » ; test 14 ; `version_strategie` (semver), `empreinte_entrees` (sha256 des entrées), contrainte UNIQUE ; PRD FR-30 (backtest sans donnée postérieure).
- **Spine** : AD-10 et AD-11 font passer le job quotidien et le harnais par `repository.py`. Elles ne disent pas que **le repository** fournit des lectures « à la date `donnees_a` », ni où sont définies la version de stratégie et la mise en forme canonique des entrées à hacher.
- **Risque** : le harnais filtre les dates lui-même, tandis que le job quotidien lit l'état courant. Les deux calculent `empreinte_entrees` sur des sérialisations différentes, si bien que la même recommandation journalisée deux fois ne déclenche pas la contrainte d'unicité. `version_strategie` est incrémentée dans un langage seulement, et `recommandation_consultee` sur l'appareil ne peut pas être rapprochée d'une version.
- **Recommandation** : ajouter à AD-10/AD-11 que le repository expose des lectures paramétrées par `donnees_a`, seule voie de lecture du harnais et du job. La version de la stratégie `modele` vient d'un seul endroit, partagé avec Dart (par exemple dans `multi_regles.json` ou le fichier de paramètres du manque 3), et elle est enregistrée dans `recommandation_consultee`. `empreinte_entrees` est calculée par une seule fonction du moteur, sur une sérialisation canonique (clés triées, flottants à précision fixe).

### Points mineurs (pas de nouvelle AD nécessaire)

- **Date de vérification des règles** (FR-22 « sans cette date, aucun coût n'est affiché » ; §9.5) : à citer dans AD-7 comme champ obligatoire de `multi_regles.json` (`verifie_le`, `source`). Les deux moteurs refusent d'afficher un coût s'il manque.
- **Décodeur de musique** (cahier annexe D, utilisé pour le rang M1 et pour l'affichage) : AD-6 dit que le rang arrive « already normalized by `repository.py` », donc il est décodé côté serveur. Préciser si un décodeur Dart est attendu pour l'affichage. Sinon, le rang décodé voyage dans le format des données (manque 1).

## Documents sources à mettre à jour

Écarts voulus (décisions de cette mise à jour) que les documents sources ne reflètent pas encore :

1. **Cahier Multi §5.2** : « Le générateur est lourd : il tourne côté backend (et hors ligne…) ». À remplacer par : générateur uniquement hors ligne, script de développement `scripts/generer_catalogue_multi.py` (uv, Python 3.12, dépendances inline), jamais déployé.
2. **Cahier Multi §5.2 « Cache »** et **§7 (schéma)** : supprimer la table `multi_systeme_cache`. À l'exécution, aucun système n'est calculé : une forme absente du catalogue ne reçoit pas de système (`systeme_absent_du_catalogue`).
3. **Cahier Multi §11.3** : renommer `assets/multi_catalog.json` en `fixtures/multi_catalogue.json` (canonique), avec ses copies `backend/app/engine/multi/multi_catalogue.json` et `mobile/assets/multi_catalogue.json` identiques octet à octet. Remplacer `scripts/export_multi_catalog.py` par `scripts/generer_catalogue_multi.py`. Supprimer « le backend exporte ».
4. **Cahier Multi §2** (« Toutes ces constantes vivent dans un seul module `engine/multi/regles.py` ») et **PRD FR-22 / §9.5** (« regroupées dans un seul module », « datées dans le module de règles ») : la source unique est `fixtures/multi_regles.json`. `regles.py` et `regles.dart` sont validés contre ce fichier.
5. **Cahier Multi §10** (ligne `POST /multi/backtest`), **§13 étape 9**, et **PRD §6.1 Incrément 2** (endpoints `/multi/backtest`) : le harnais tourne d'abord sur la machine de développement, sur une copie de la base de production, via un job `backend/app/jobs/`. `/multi/backtest` n'est construit qu'au passage du harnais sur un serveur. L'incrément 2 livre `/multi/comparateur` et `/multi/performance`.
6. **Cahier Multi §4.0, §6.5, §11.2** (« catalogue de libellés de l'app », « rendues en FR ou EN ») : préciser que, pour le MVP, c'est une simple table Dart code → modèle de phrase français, et que la migration vers l'outillage de localisation Flutter se fait quand l'anglais arrive.
7. **Cahier Multi §9 test 6** : à reformuler en test sur le catalogue généré, exécutable sans scipy (voir manque 6).
8. **Cahier Multi §7 « Sur l'appareil »** et **PRD FR-30** : ajouter la rétention de 90 jours du jeu retenu et de la recommandation consultée, purgés au démarrage de l'app. Ajouter le stockage dans `hippique_cache.db` v2 (tables `jeu_retenu` et `recommandation_consultee`).
9. **Cahier Multi §13 étape 2** (« catalogue exporté ») : remplacer par « catalogue généré hors ligne, versionné dans le dépôt, puis copié vers le backend et le mobile ».
