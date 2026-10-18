---
title: "Revue de préparation à l'implémentation — Module Multi (Epics 5 et 6)"
date: 2026-10-18
perimetre: "Epics 5 (stories 5.1 à 5.16) et 6 (stories 6.1 à 6.7) de epics.md, et leurs interfaces avec le code livré par les Epics 1 à 4"
verdict: CONCERNS
artefacts_lus:
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/prds/prd-prediction-hyppique-2026-08-22/prd.md (§2.3 UJ-4, §4.11, §5, §6, §7, §8, §9.5, §11, §12)
  - docs/cahier_des_charges_module_multi.md (v3)
  - _bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md (AD-1 à AD-13)
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md, DESIGN.md, mockups/multi.html
  - _bmad-output/planning-artifacts/multi/reconcile-cdc-multi-prd.md (§D ter et précisions)
  - _bmad-output/implementation-artifacts/deferred-work.md
  - code : backend/app (models, repository, pmu_client, routes_courses, schemas, jobs, Dockerfile, docker-compose) ; mobile/lib (database_helper, models, providers, widgets) ; backend/tests/fixtures/pmu
---

# Revue de préparation à l'implémentation — Module Multi (Epics 5 et 6)

## 1. Verdict

**CONCERNS** — l'implémentation peut commencer, **mais seulement par la story 5.1** (vérification des règles, tâche humaine). Plusieurs stories ne sont pas prêtes en l'état et doivent être corrigées avant d'être confiées à un agent de développement : 5.5, 5.7, 5.14, 5.15, 5.16, 6.1, 6.6, et dans une moindre mesure 5.4, 5.8, 5.12, 6.5, 6.7.

Pourquoi pas PASS : un développeur devrait inventer au moins quatre décisions de fond que rien n'enregistre (traitement d'un non-partant dans le champ de probabilités, persistance de la musique pour la méthode 1, modèle de données local du débrief, identifiant de course utilisé par le téléphone pour lire l'arrivée). Un fait déjà présent dans le dépôt contredit aussi une règle métier centrale : la « course support unique par jour » (voir F1).

Pourquoi pas FAIL : la structure est solide. La traçabilité FR → stories est presque complète, aucune dépendance en avant ne bloque, les critères d'acceptation sont précis et testables, et la story 5.1 est explicitement conçue pour arrêter le chantier si les règles ont changé. Tous les manques se corrigent dans les documents, sans refonte.

**Conditions pour lever le CONCERNS** (détail en §3) :

1. Terminer 5.1 et répercuter son résultat dans le PRD, le cahier, la spine et les stories 5.5 et 6.6 (F1).
2. Trancher et enregistrer la règle du non-partant dans le champ (F2).
3. Compléter le schéma local v2 (5.15) pour qu'il porte tout ce que 5.16 affiche (F3).
4. Fixer l'identifiant de course utilisé par le téléphone pour le débrief (F4).
5. Ajouter la persistance de la musique à 6.1 (F5).
6. Inscrire en amont les décisions du 2026-10-18 (F6, F7).

## 2. Synthèse chiffrée

| Gravité | Nombre |
| --- | --- |
| Critique (bloque tout démarrage) | 0 |
| Élevée (bloque une ou plusieurs stories) | 7 |
| Moyenne (le développeur devra deviner, ou un écart sera découvert en revue) | 13 |
| Faible (hygiène documentaire, risque limité) | 9 |

Couverture des exigences : FR-22 à FR-30, NFR-7 à NFR-11 et UX-DR1 à UX-DR13 sont tous rattachés à au moins une story. Quatre trous partiels se trouvent dans les critères d'acceptation : FR-24/UX-DR6 (tickets économisés non affichés), NFR-9 (parité du vérificateur non portée par les cas partagés), FR-30/UX-DR10 (Multi consulté sans pronostic retenu) et UX-DR11 (état « non-partant » via le rafraîchissement, que le backend ne permet pas).

## 3. Constats, par gravité

Format : **ID — gravité — emplacement** · problème · correction (artefact / skill).

### Élevée

**F1 — Élevée — epics.md 5.5, 6.6 ; PRD FR-22, §9.5 ; cahier §2 ; spine AD-10 ; UX (« Pas une course support »)**
Les données PMU réelles du dépôt contredisent le modèle de la « course support unique par jour ». Dans `backend/tests/fixtures/pmu/programme_15012022.json`, le pari `MULTI` (et `E_MULTI`) est proposé sur **19 courses le même jour**, dont des courses étrangères (CHL). Le pari `MINI_MULTI` est proposé sur les courses de 10 à 13 partants. Une course de 16 déclarés (R2C7) n'en propose aucun. La capture du 18/10/2026 (partielle, 3 courses) ne contient que `MINI_MULTI`.
Conséquences pour les stories :
- 5.5 calcule `est_course_support` « selon la liste des paris » : cette règle rendrait environ 19 courses éligibles par jour, ce qui contredit le libellé « course support » et le seuil de 14 partants comme critère.
- 6.6 journalise « la course support du jour » au singulier.
- Le volume d'appels à la source PMU (PRD OQ 6) change.
- Le Mini Multi n'est traité nulle part, ni comme cas hors périmètre.
La story 5.1 prévoit de s'arrêter si la mécanique a changé, mais elle ne contrôle que « le choix de la course support selon les jours ». Elle doit aussi vérifier si le Multi est proposé sur plusieurs courses par jour et le statut du Mini Multi.
Correction : ajouter ces deux points de contrôle à 5.1 (bmad-create-epics-and-stories / bmad-correct-course). Après 5.1, mettre à jour FR-22 (bmad-prd), le cahier §2 et §7, AD-10, puis 5.5, 5.12 (libellés de raison) et 6.6 (bmad-correct-course).

**F2 — Élevée — 5.7 (`simuler_non_partant`, `selectionner` avec non-partants), 5.10, 5.14, 5.5 (`non_partant`) ; spine AD-6 ; cahier §4.0, §4.1, §6.6**
Aucun document ne dit ce que devient un non-partant dans le **champ de probabilités**. Deux lectures sont possibles :
- (a) Il reste dans le champ et n'est seulement plus sélectionnable. Les probabilités `P_ens` sont alors fausses, puisqu'un cheval absent garde sa chance d'être dans les 4.
- (b) Il sort du champ. `p_gagnant`, `top4` et `P_ens` doivent alors être recalculés, ce qu'AD-6 interdit (« sans recalculer score, `top4` ni value ») et qui ferait diverger l'écran Multi de l'écran Résultats.
Le cahier crée `est_partant` dans `ChevalMulti` mais ne dit pas comment il entre dans `P_ens`. Le même trou existe pour les non-partants signalés par le backend : rien ne dit s'ils sont exclus **avant** le scoring (`/analyse`, moteur Dart), ce qui marquerait le classement comme « modifié », ou seulement dans le Multi.
Correction : décision d'architecture à enregistrer dans AD-6. Par exemple, une renormalisation de Plackett-Luce sur les partants restants (cohérente avec l'axiome de Luce), réalisée dans le moteur Multi comme opération déclarée, avec cas partagés. Ou bien l'exclusion avant scoring, accompagnée de « Classement modifié ». Puis reprendre 5.7, 5.10, 5.14 et la §6.6 du cahier (bmad-architecture, puis bmad-correct-course).

**F3 — Élevée — 5.15 (schéma `pronostic_retenu` / `recommandation_consultee`) contre 5.16 et UX (états « Multi consulté sans pronostic retenu », « Multi en état débrief »)**
Le schéma local v2 ne porte pas ce que 5.16 doit afficher « sans recalcul » :
- 5.15 n'écrit `recommandation_consultee` qu'au moment où l'utilisateur retient. Or 5.16 et l'UX affichent aussi les courses où le Multi a été **seulement consulté**. Il faut donc dire quand on écrit (à l'ouverture ? à chaque changement de taille ? quelle taille garder ?).
- L'arrivée (`arrivee_json`, `arrivee_corrigee_le`) n'est stockée que dans `pronostic_retenu`. Une course consultée sans pronostic retenu n'a nulle part où ranger son arrivée ni son débrief.
- Le débrief en lecture seule montre la confiance, les chevaux les plus probables et, selon l'UX, l'évaluation du pronostic retenu. `pronostic_retenu` ne contient ni le niveau de confiance, ni les bases candidates, ni `p_couverture` ou la distribution. Après un redémarrage, le classement n'est plus en mémoire, donc rien ne peut être recalculé.
- Les grilles réaffichées par « Voir les grilles » seraient reconstruites depuis le catalogue courant. Après une mise à jour de l'app (nouvelle `version` du catalogue), elles pourraient différer de celles que l'utilisateur a copiées.
Correction : compléter les colonnes de 5.15 (confiance, raisons, bases candidates, `p_couverture`, distribution, tickets ou version du catalogue, arrivée côté `recommandation_consultee`) et la règle d'écriture de `recommandation_consultee`. Reporter la liste dans AD-9 (bmad-create-epics-and-stories, bmad-architecture).

**F4 — Élevée — 5.16 (« `GET /courses/{id}/multi/eligibilite` ») ; 5.9 (`course_id` = clé `AAAAMMJJ-Rn-Cn`) ; spine AD-12 ; code `CourseOut`**
Le téléphone identifie le pronostic retenu par la **clé PMU** (AD-12), mais la route d'éligibilité prend l'**id auto-incrémenté** (`/courses/{course_id}` avec `course_id: int`). `pronostic_retenu` ne stocke pas cet id, et `CourseOut` n'expose pas `numero_reunion` ni `numero_course`. 5.16 ne dit pas comment l'app retrouve l'id d'une course vieille de plusieurs jours : le cache `programme_courses` n'est rempli que pour les jours consultés. AD-12 interdit justement d'identifier une course entre systèmes par l'id auto-incrémenté. Par ailleurs, `POST /multi/recommandation` prend `course_id` comme chaîne de clé PMU alors que `/analyse` prend `course_id` comme entier : même nom, deux types.
Correction : choisir une route par clé PMU (par exemple `GET /multi/courses/{cle}/eligibilite`), ou stocker l'id serveur dans `pronostic_retenu`. Renommer `course_id` en `cle_course` dans 5.9. Mettre à jour le cahier §10 et le PRD §6.1 (bmad-correct-course).

**F5 — Élevée — 6.1 (méthode 1) ; code `models.py`, `repository.save_partants`**
La musique n'est **pas persistée** en colonne : `PartantInfo.musique` n'est conservée que dans le JSON brut `participations.donnees_brutes`. 6.1 demande que le repository calcule `dernier_rang` « depuis la musique quand elle est lisible ». Lire `donnees_brutes` violerait AD-1, puisque seul `pmu_client.py` lit un champ brut. La révision Alembic de 6.1 n'ajoute que `rang_brut` et `statut_arrivee`. Le backtest (6.4) a le même besoin pour les courses passées.
Correction : ajouter `participations.musique` (texte, facultatif) à la révision de 6.1, l'alimentation par `save_partants`, et dire quoi faire des lignes anciennes (décodage depuis `donnees_brutes` par une migration de données qui appelle le décodeur de la couche data, ou `NULL` traité comme « absent ») (bmad-create-epics-and-stories).

**F6 — Élevée (traçabilité, conflit normatif) — 5.8 (seuils provisoires) contre cahier §0.3 et §6.4, reconcile D3, PRD FR-26 et OQ 10**
Le cahier v3 dit, parmi ses « Principes (à ne jamais dériver) » : « Rien n'est inventé : aucun seuil de l'indice de confiance n'est codé « à l'estime ». Les valeurs par défaut des seuils sont fixées par le pilote ». 5.8 code pourtant une règle provisoire (2× et 3× la probabilité d'une sélection au hasard sur 16 partants, plafonds 0,90 et 0,95, course ouverte 0,90, données fragiles 0,25). La décision du porteur de projet du 2026-10-18 n'est consignée **ni** dans le reconcile (§D ter), **ni** dans le PRD (§12 Assumptions Index, OQ 10), **ni** dans le cahier. Un agent qui lit le cahier, référence normative, refuserait la story ou la contesterait en revue.
Risque produit à signaler au porteur de projet en même temps (calcul sur C(16,4) = 1 820) :
- v = 4 : seuil moyen 0,0011, seuil élevé 0,0016. Presque tout pronostic en 4 chevaux serait « Confiance élevée » pour un événement à 1–5 % de chances.
- v = 10 : 0,23 et 0,35.
- v = 12 : 0,54 et 0,82.
- v ≥ 13 : 0,79 (puis 0,90) et 0,95.
- La règle est fixée à 16 partants : dans un champ de 14, une sélection de 12 chevaux tirée **au hasard** atteint déjà 0,49, juste sous le seuil « moyenne ».
Correction : consigner la décision dans le reconcile (§D ter, précision datée), dans le PRD (§12, OQ 10 marquée « provisoire décidé ») et dans le cahier (§0.3 et §6.4 : exception explicite « provisoire, étiqueté, remplacé par le pilote »). Faire confirmer le comportement à v petit (bmad-prd, puis bmad-correct-course).

**F7 — Élevée (traçabilité) — décisions du 2026-10-18 absentes des documents amont**
Les décisions suivantes ne sont écrites que dans les stories. Aucun document amont ne les enregistre, et plusieurs **contredisent** le texte amont.

| Décision approuvée | Story | Document qui dit autre chose ou rien | À mettre à jour |
| --- | --- | --- | --- |
| Contexte Multi dans un objet `multi` de chaque course de `/courses` | 5.5 | AD-6 : « delivered with the race's runners » ; cahier §11.3 : « reçu du backend avec les partants » | spine AD-6, cahier §11.3 |
| Cache local v2 avec colonne `multi_contexte` dans `programme_courses` et colonnes de débrief dans `pronostic_retenu` | 5.15 | AD-9 n'énumère que deux tables nouvelles ; cahier §7 et §11.3 aussi | spine AD-9, cahier §7 |
| Copies backend testées de `multi_regles` (`regles.py`), `multi_parametres_pilote` (`parametres.py`), et implicitement `multi_versions` | 5.1, 5.8 | AD-7 ne parle de copie que pour le catalogue ; AD-11 dit « validated by both languages' tests » sans dire que la copie Python est un miroir à l'exécution | spine AD-2, AD-7, AD-11 |
| Migration de prod : sauvegarde du fichier SQLite, `_migrate()` hérité, puis tampon de la baseline ; 3 sauvegardes gardées | 5.4 | AD-13 ne dit rien de la sauvegarde ; Deferred : « backup of the production SQLite file — decide when increment 2 starts » | spine AD-13 et Deferred |
| Journalisation 30 min avant le départ ; arrivée re-contrôlée pendant 3 jours | 5.5, 6.6 | Deferred : « Schedule of the daily Multi log relative to departure times — decide when increment 2 starts » ; cahier §7 muet | spine Deferred → AD-10, cahier §7 |
| Heure de départ inconnue : pronostic remplaçable jusqu'à la fin du jour de course (Paris) | 5.15 | AD-9 et AD-12 : figé « au départ » sans cas « inconnu » | spine AD-9, PRD FR-28 |
| Taille supérieure aux sélectionnables : 422 à l'API, ramenée par l'app | 5.9, 5.12 | cohérent avec le cahier §10 et le PRD FR-23, mais la double règle n'est écrite nulle part | cahier §10 (une ligne) |
| Allocation déjà stockée ; 6.1 n'ajoute que le rang brut et le statut | 6.1 | cahier §3 : « Existant dans l'API mais absent du schéma 6.3 → ajouter la colonne » | cahier §3 |
| Musiques réelles en lettres de discipline majuscules | 6.1 | cahier annexe D : « suivi d'**une lettre minuscule** de discipline » | cahier annexe D |

Correction : une passe bmad-correct-course qui reporte chaque décision dans le reconcile (§D ter, précisions), puis dans la spine (bmad-architecture, mise à jour) et dans le cahier.

### Moyenne

**F8 — Moyenne — 5.12 (`base-chip`) contre FR-24 et UX-DR6**
FR-24 exige que chaque base candidate affiche **les tickets économisés**, et UX-DR6 les reprend. Les critères de 5.12 n'affichent que « Top 4 estimé » et « −4 pts », et la maquette `multi.html` non plus. 5.7 calcule bien `tickets_economises`, mais aucune story ne l'affiche. Correction : ajouter l'affichage, par formule ou pour la formule affichée, aux critères de 5.12 ; aligner la maquette (bmad-create-epics-and-stories, bmad-ux).

**F9 — Moyenne — 5.14 (« rafraîchissement explicite… le backend signale des non-partants ») ; 6.6 (journal à T−30 min) ; code `scheduler.py`, `routes_courses.py`**
Le backend ne relit les partants (statut non-partant, cotes) qu'une fois par jour, à `INGEST_HOUR` = 6 h. Le rafraîchissement horaire ne relit que le programme, pour le terrain. `GET /courses/{id}/partants` ne relit PMU que pour compléter un historique manquant. Le « rafraîchissement explicite » de l'app renverra donc l'état de 6 h, et un non-partant déclaré dans la journée n'arrivera jamais par ce chemin. De même, 6.6 journalisera à T−30 min avec des données de 6 h (et B1 avec les cotes de 6 h). Correction : ajouter à 5.5 ou 5.14 une relecture des partants et des cotes de la course (à la demande ou périodique), avec mise à jour de `donnees_maj_le`. Dire si le job de 6.6 rafraîchit avant de journaliser. Arbitrer le volume d'appels (PRD OQ 6) (bmad-create-epics-and-stories).

**F10 — Moyenne — 5.12, 5.15, 5.16 contre l'Epic 3 livré (FR-13, FR-14, NFR-3) ; code `course_repository.partants()`, `horsesProvider`, `resultsProvider`**
Les partants et le classement ne sont **jamais persistés** sur l'appareil : `partants()` appelle toujours le réseau, et `horsesProvider` et `resultsProvider` vivent en mémoire, pour une seule course. Après un redémarrage hors ligne, impossible de rouvrir une course ni de calculer son Multi. UJ-4 (hippodrome sans réseau) ne fonctionne donc que si l'app n'a pas été fermée. 5.15 ajoute `multi_contexte` « pour garder l'éligibilité hors ligne après redémarrage », mais sans les partants l'éligibilité ne sert à rien. Correction : soit une story (dans l'Epic 3 ou en 5.x) de cache local des partants de la course, soit l'écriture explicite de cette limite dans FR-23 et l'UX. Dans tous les cas, signaler l'écart à l'Epic 3 (bmad-correct-course).

**F11 — Moyenne — 5.7, 5.10, 5.12 (chevaux sans dossard) ; code `Horse.numPmu` nullable**
Un cheval saisi à la main (FR-6) ou importé par photo (Epic 4) peut n'avoir **aucun dossard**, ou un dossard en double (cas déjà relevé dans deferred-work, Story 4.4). Or le Multi identifie tout par dossard. Aucune story ne dit si ce cheval est « non analysé », exclu ou bloquant. De plus, une course saisie à la main n'a pas de contexte Multi : 5.12 affiche alors « Contexte Multi non chargé », ce qui revient à exclure du Multi toute course hors ingestion, sans que ce soit dit comme une décision. Correction : ajouter un critère à 5.7 et 5.12 ; écrire la décision dans le PRD FR-22 (bmad-create-epics-and-stories, bmad-prd).

**F12 — Moyenne — 5.8 (« favori fragile », « données fragiles ») ; code `transparency_label.dart`, `scoring.py`**
Les définitions nécessaires à la parité ne sont partagées nulle part :
- « historique court » n'existe que dans un widget Dart (`nbPerfs < recenceStd.length`) ; le moteur Python n'a pas ce drapeau ;
- « terrain majoritairement inconnu » n'a aucune définition chiffrée ;
- on ne sait pas si « Données non saisies » (`nbPerfs == 0`) compte comme fragile.
Correction : définir ces drapeaux dans la section `constantes_moteur` de `fixtures/multi_cases.json` (ou dans `engine_constants.json`), les calculer dans l'adaptateur `depuis_analyse` des deux langages, et l'écrire dans 5.7 et 5.8 (bmad-create-epics-and-stories).

**F13 — Moyenne — 5.8 (`identite_pronostic`), 5.9, 6.5 (« empreinte des règles en vigueur »), 6.6 ; Docker (contexte `backend/`)**
L'identité du pronostic exige, **à l'exécution**, la version du moteur (`fixtures/multi_versions.json`) et l'empreinte sha256 de `fixtures/multi_regles.json`. Or `fixtures/` n'est pas dans l'image Docker, ni dans l'APK pour les règles. 5.11 crée `versions.dart`, mais aucun `versions.py` n'est prévu, et on ne sait pas comment l'empreinte des règles est connue en production ni sur l'appareil (constante validée par test ? reprise de l'en-tête du catalogue ?). Correction : nommer les miroirs (`versions.py`, empreinte des règles portée par `regles.py` et `regles.dart`) et leurs tests (bmad-create-epics-and-stories ; spine AD-12).

**F14 — Moyenne — cahier §3 contre annexe D (contradiction interne) ; 6.1**
Le §3 dit que le rang vient de la **musique** quand elle est lisible, la liste détaillée servant au recoupement. L'annexe D dit l'inverse : priorité à `performances-detaillees` tant que la segmentation est ambiguë. 6.1 suit le §3. Avec des lettres de discipline majuscules, `A` désigne à la fois « attelé » et l'incident « arrêté » (`DA21DA2A1ADA1A`), ce qui rend l'ambiguïté structurelle. Correction : trancher dans le cahier (bmad-correct-course) ; 6.1 garde son repli « indécidable ».

**F15 — Moyenne — 6.4, 6.5 (pilote) contre cahier §8.3 (« aucun seuil d'effet inventé »)**
6.5 demande au pilote d'en « déduire la taille d'échantillon de la période de test » et de « proposer » des seuils « par une règle écrite dans le rapport ». Un calcul de taille d'échantillon exige un effet minimal, un α et une puissance, que le cahier interdit d'inventer. La règle de proposition des seuils n'est pas décrite non plus. Le développeur devra inventer les deux. Correction : décider, avec le porteur de projet, de la règle de taille d'échantillon (ou d'une règle de précision : largeur d'intervalle visée) et de la règle de proposition des seuils (par exemple des quantiles de `p_couverture` par taille sur la période de développement), puis l'écrire au cahier §8.4 (bmad-prd ou bmad-correct-course).

**F16 — Moyenne — 6.7 (`statut_modele`, « période de test gelée ») ; schéma `performance_strategie` (6.5)**
La règle de 6.7 dépend d'une « période de test gelée » et « close ». Or `performance_strategie` ne porte ni le type de période (développement, validation, test) ni l'état gelé ou clos. Rien ne dit non plus comment le statut « hypothèse non validée » de **chaque comparateur** arrive à l'app : le contexte de 5.5 ne porte que `statut_modele`. Enfin, 6.7 met en cache local la réponse de `/multi/performance`, sans table ni clé définies (AD-9 ne le prévoit pas). Correction : ajouter `type_periode` et `gelee` à 6.5, un champ par comparateur dans le contexte, et le stockage local dans 6.7 et AD-9 (bmad-create-epics-and-stories).

**F17 — Moyenne — NFR-9 contre 5.6, 5.10 (parité du vérificateur)**
NFR-9 cite explicitement « vérification ». 5.6 teste le vérificateur Python sans écrire de cas dans `fixtures/multi_cases.json`, et 5.10 ne rejoue aucune section `verification`. La parité du vérificateur (et de `/multi/verifier`, avec le système plus petit proposé) n'est donc pas garantie entre les deux langages. Correction : ajouter une section `verification` écrite par 5.6 et rejouée par 5.10 (bmad-create-epics-and-stories).

**F18 — Moyenne — taille des stories 5.7, 5.12, 6.4**
- 5.7 regroupe couverture exacte, sélection avec échanges, cas d'erreur, bases, systèmes et relabellement, évaluation et contributions, simulation de non-partant, bilan d'arrivée et 7 sections de fixtures.
- 5.12 regroupe accès, en-tête, stepper avec temporisation, carte de confiance, sélection, bases, évaluation et 7 états, avec l'accessibilité.
- 6.4 regroupe harnais sans fuite, configuration de périodes, 6 stratégies et 7 familles de métriques (Brier, calibration, bootstrap, Wilson, Holm, ablation), plus l'export.

Chacune dépasse ce qu'un agent fait proprement en une passe. Correction : découper, par exemple 5.7a (couverture et sélection), 5.7b (bases, systèmes, relabellement), 5.7c (évaluation, non-partant, bilan) ; 5.12a (écran et stepper), 5.12b (confiance, sélection, bases, évaluation, états) ; 6.4a (harnais et fuite), 6.4b (métriques et export) (bmad-create-epics-and-stories).

**F19 — Moyenne — 5.15 (Réglages « seuils élevé et moyen par taille ») ; UX EXPERIENCE (Réglages)**
Deux seuils pour chacune des 17 tailles donnent 34 champs, et aucune mise en page n'est spécifiée : l'UX ne décrit qu'un « groupe Multi » sans forme. Le développeur inventera l'écran (liste ? tableau ? édition de la seule taille courante ?). Correction : spécifier la forme dans EXPERIENCE.md (bmad-ux).

**F20 — Moyenne — 5.4 (baseline et Dockerfile) ; code en cours (branche `fix/ingestion-etat-terrain`)**
1. La baseline doit être « identique à la production actuelle ». La liste de la story omet `performances_historiques.rang_impute`, ajouté depuis par `_migrate()` dans la branche en cours (non commitée). La « production actuelle » change donc pendant la planification.
2. Le `CMD` appelle `backend/scripts/demarrer_api.py`, mais le critère ne demande de copier que `alembic.ini` et `alembic/` : `scripts/` manque.
3. `Repository()` est instancié à l'import de `routes_courses.py` (ce qui déclenche `create_all`) ; il faut le dire pour que le retrait de `create_all` n'oublie pas ce point.

Correction : définir la baseline par référence au schéma produit par `_migrate()` au commit de 5.4, plutôt qu'en liste fermée ; ajouter `COPY scripts` ; mentionner l'instanciation à l'import (bmad-create-epics-and-stories).

### Faible

**F21 — Faible — epics.md §« Couverture des exigences Multi »** : la table ne contient aucune ligne NFR-7 à NFR-11. Leur couverture est réelle (NFR-7 : 5.11, 5.12, 5.13 ; NFR-8 : 5.1, 5.7, 5.9, 5.11 à 5.13, 6.2 à 6.7 ; NFR-9 : 5.1, 5.7, 5.8, 5.10, 5.11, 6.2 ; NFR-10 : 5.10 ; NFR-11 : 5.8, 5.11), mais elle n'est pas tracée. Ajouter les lignes (bmad-create-epics-and-stories).

**F22 — Faible — epics.md, Overview (ligne 20) et §UX Design Requirements (ligne 108)** : ces deux passages disent encore qu'« aucun contrat UX formel » n'existe, alors que DESIGN.md et EXPERIENCE.md sont finaux depuis le 2026-10-18. Mettre à jour.

**F23 — Faible — PRD §4.11** : la référence normative cite « `cahier_des_charges_module_multi.md` (v2) » alors que le cahier est en v3 (bmad-prd).

**F24 — Faible — cahier §5.4 (texte de garantie)** : « … (bases comprises), au moins un ticket de **k** chevaux les contient tous les quatre » diffère du texte imposé par le PRD FR-25, l'UX et 5.11 (« … et incluent votre base / vos bases, au moins un de vos tickets les contient tous »). Aligner le cahier.

**F25 — Faible — 5.13 contre UX `formula-row`** : l'UX propose comme défaut « Multi en 7, puis la dernière formule utilisée » `[ASSUMPTION]`, alors que 5.13 dit « Multi en 7, sinon la plus grande disponible », sans mémoire. De même, l'UX ouvre sur un écarté touché la `multi-actions-sheet` réduite à « Ajouter à la sélection », alors que 5.14 ouvre la `horse-picker-sheet`. Trancher dans l'UX ou dans la story.

**F26 — Faible — 5.15 contre UX `multi-action-bar`** : l'UX désactive « Je retiens ce pronostic » quand le classement est à recalculer. 5.13 traite « Voir les grilles », mais 5.15 ne reprend pas cette règle pour le CTA. Ajouter le critère.

**F27 — Faible — 5.16 contre UX « Multi en état débrief »** : l'UX montre aussi l'Évaluation et les Autres méthodes en lecture seule ; 5.16 les omet. À trancher en même temps que F3.

**F28 — Faible — 5.5 / 5.1 (fixtures PMU)** : 5.5 demande une capture 2026 « un jour de Quinté+ et un jour sans », mais une seule capture 2026 existe (le 18/10, partielle). 6.1 exige au moins 30 musiques réelles, alors que les fixtures n'en contiennent que 12. Il faut capturer de nouvelles réponses, ce que les stories devraient dire (avec le volume d'appels, PRD OQ 6).

**F29 — Faible — 5.1 (exécutant)** : la vérification sur pmu.fr est une tâche **humaine** (« le porteur de projet, ou le développeur avec sa validation »), qu'un agent de développement ne peut pas achever seul. Le suivi de sprint doit la marquer comme telle, puisque 5.1 bloque tout le reste.

## 4. Traçabilité

### 4.1 Exigences → stories (vérification des critères d'acceptation)

| Exigence | Stories | Critères qui la satisfont réellement | Écart |
| --- | --- | --- | --- |
| FR-22 | 5.1, 5.5, 5.9, 5.12, 5.13, 5.14 | raison affichée, exploration, règles datées, grilles masquées, non analysés signalés | F1 (modèle « course support » douteux), F11 |
| FR-23 | 5.2, 5.7, 5.10, 5.12, 5.14, 5.15, 6.7 | taille 4–20, défaut, plafond dit, égalités 1e-9, « en cours d'évaluation », données fragiles, hors ligne, non-partant et requalification | F2, F9, F10 |
| FR-24 | 5.7, 5.10, 5.12 | 3 candidates, aucune active, activer = imposer | **F8** : tickets économisés non affichés |
| FR-25 | 5.6, 5.7, 5.9, 5.10, 5.11, 5.13 | vérification systématique, texte imposé, catalogue ≤ document, système saisi, Multi en 7, export | F17 (parité du vérificateur) |
| FR-26 | 5.8, 5.11, 5.12, 5.15, 6.5, 6.7 | niveaux, raisons, aucun « jouer », seuils par taille réglables, « provisoires » | F6 (seuils provisoires non tracés), F15, F19 |
| FR-27 | 5.8, 5.11, 5.12 | codes et valeurs, 3 écartés, limites des données, « estimé », pas de value | F12 (drapeaux) |
| FR-28 | 5.7, 5.9, 5.14, 5.15 | « Modifiée », 1–2 échanges, coût d'une imposition, retenu unique, figé, invitation après copie | F3 |
| FR-29 | 6.2, 6.3, 6.5, 6.7 | à part, même taille, « hypothèse non validée », marché sans cote manquante, B0 journalisé | F16 |
| FR-30 | 5.7, 5.12, 5.15, 5.16, 6.4, 6.6 | évaluation, journalisation immuable et échecs, backtest sans fuite, 90 jours, débrief | F3, F4, F9 |
| NFR-7 | 5.11, 5.12, 5.13 | trois mentions présentes dans le flux | absent de la table (F21) |
| NFR-8 | 5.1, 5.7, 5.9, 5.11, 5.12, 5.13, 6.2–6.7 | tests de clés et de libellés interdits | absent de la table (F21) |
| NFR-9 | 5.1, 5.7, 5.8, 5.10, 5.11, 6.2 | cas partagés | F17 ; absent de la table (F21) |
| NFR-10 | 5.10 | mesure sur l'appareil, plafond d'itérations | seuil non chiffré (PRD OQ 1, accepté) |
| NFR-11 | 5.8, 5.11 | registre, table de libellés, code inconnu → libellé neutre | — |
| UX-DR1 | 5.12, 5.16 | CTA, badge, raison au tap | — |
| UX-DR2 | 5.12, 5.13, 6.3 | ordre, barre sous la zone défilante, 130 % | — |
| UX-DR3 | 5.12, 5.15 | stepper, 800 ms, annonce unique, bornes | — |
| UX-DR4 | 5.12 | carte, or seulement pour « élevée », emojis ignorés | — |
| UX-DR5 | 5.12, 5.14 | ligne, feuilles, focus, « Modifiée » | F25 |
| UX-DR6 | 5.12 | puce interrupteur, « sûr » interdit | **F8** |
| UX-DR7 | 5.13, 5.15 | formules, feuille des grilles, copie, saisie | — |
| UX-DR8 | 5.12, 6.3, 6.7 | évaluation, autres méthodes | — |
| UX-DR9 | 5.15 | CTA, « retenu à », gel, focus | F26 |
| UX-DR10 | 5.16 | section, 90 jours, débrief, « Arrivée corrigée » | F3, F4, F27 |
| UX-DR11 | 5.12, 5.13, 5.14, 5.15, 6.3, 6.7 | tous les états listés | F9 (non-partant par rafraîchissement inopérant) |
| UX-DR12 | 5.3, 5.12 | line-card ≥ 3:1, on-gold, 48dp, 200 % | — |
| UX-DR13 | 5.11, 5.12, 5.13 | vocabulaire, garantie mot pour mot | — |

### 4.2 Orphelins

- **Exigences sans story** : aucune.
- **Stories sans intention amont** : aucune story entière. En revanche, plusieurs **critères** ne remontent qu'à la décision orale du 2026-10-18 (F6, F7) : seuils provisoires, `MULTI_RECONTROLE_ARRIVEE_JOURS`, `MULTI_JOURNAL_AVANCE_MINUTES`, sauvegarde SQLite et rétention de 3 sauvegardes, fin du jour de Paris pour une heure inconnue, colonne `multi_contexte`, miroirs Python, `tzdata`. La story 5.3 (line-card dans toute l'app) remonte bien à UX-DR12.

## 5. Dépendances

- **À l'intérieur de l'Epic 5** : l'ordre 5.1 → 5.2/5.3/5.4 → 5.5 → 5.6 → 5.7 → 5.8 → 5.9 → 5.10 → 5.11 → 5.12 → 5.13 → 5.14 → 5.15 → 5.16 est cohérent. Les seules mentions « en avant » sont descriptives et ne créent pas de dépendance d'exécution : 5.1 annonce que 5.10 rejouera ses cas ; 5.5 fixe `seuils_provisoires = true` en attendant 5.8 ; 5.12 affiche « Modifiable jusqu'au départ » avant que 5.15 n'implémente le gel ; 5.12 traite `pas_meilleur_que_le_marche`, que seule 6.7 produit. 5.3 (accessibilité dans toute l'app) n'a pas besoin de 5.1 : le verrou de 5.1 sur 5.2–5.4 est plus strict que le PRD §9.5 (« stories de développement du module Multi »), sans être faux.
- **À l'intérieur de l'Epic 6** : 6.1 → 6.2 → 6.3 ; 6.2 → 6.4 → 6.5 → 6.6 → 6.7. Cohérent, et l'ordre pilote → seuils → journalisation est respecté.
- **Entre epics** : l'Epic 6 dépend de 5.5 (arrivée, `multi_course`), 5.7 (`bilan_arrivee`), 5.8 (paramètres), 5.11 (libellés) et 5.12 (écran) ; aucune story de l'Epic 5 ne dépend de l'Epic 6. **Dépendance cachée sur l'Epic 3** : pas de cache local des partants (F10).
- **Une story par agent** : non vérifié pour 5.7, 5.12 et 6.4 (F18) ; 5.1 n'est pas une tâche d'agent (F29).

## 6. Conflits entre artefacts

| # | Conflit | Emplacements | Document qui fait foi selon les règles | Document à corriger |
| --- | --- | --- | --- | --- |
| C1 | Contexte livré « avec les partants » contre objet `multi` dans `/courses` | AD-6 ; cahier §11.3 ; 5.5 | décision du 2026-10-18 (story) | spine AD-6, cahier §11.3 |
| C2 | Deux tables locales contre colonnes supplémentaires | AD-9 ; cahier §7 et §11.3 ; 5.15 | décision du 2026-10-18 | spine AD-9, cahier §7 (après F3) |
| C3 | Copie du seul catalogue contre miroirs backend des autres fixtures | AD-7 ; AD-11 ; 5.1, 5.8 | décision du 2026-10-18 | spine AD-2, AD-7, AD-11 |
| C4 | « Rien n'est inventé » contre seuils provisoires | cahier §0.3 et §6.4 ; reconcile D3 ; 5.8 | décision du 2026-10-18, **non consignée** | reconcile §D ter, PRD §12 et OQ 10, cahier §0.3 et §6.4 |
| C5 | Rang depuis la musique contre depuis la liste détaillée | cahier §3 contre annexe D ; 6.1 | aucun (contradiction interne) | cahier |
| C6 | Lettre de discipline minuscule contre majuscule | cahier annexe D ; 6.1 | décision du 2026-10-18 (données réelles) | cahier annexe D |
| C7 | Allocation « absente du schéma » contre déjà présente | cahier §3 ; 6.1 ; code `models.py` | le code | cahier §3 |
| C8 | Texte de garantie | cahier §5.4 contre PRD FR-25, UX, 5.11 | PRD et UX | cahier §5.4 |
| C9 | Course support unique par jour contre Multi proposé sur environ 19 courses | PRD FR-22 ; cahier §2 ; AD-10 ; 6.6 ; fixture 2022 | la vérification de 5.1 | tous, après 5.1 (F1) |
| C10 | Sauvegarde SQLite « différée » contre décidée | spine Deferred ; 5.4 | décision du 2026-10-18 | spine |
| C11 | Horaire de journalisation « différé » contre 30 min | spine Deferred ; 6.6 | décision du 2026-10-18 | spine, cahier §7 |
| C12 | Recalcul de `top4` interdit contre non-partant à retirer du champ | AD-6 ; cahier §6.6 ; 5.7, 5.14 | aucun | spine AD-6 (F2) |
| C13 | Identité par clé PMU contre route par id auto-incrémenté | AD-12 ; 5.9, 5.16 ; cahier §10 | AD-12 | cahier §10, PRD §6.1, stories (F4) |
| C14 | Référence au cahier v2 | PRD §4.11 | cahier v3 | PRD |
| C15 | « Aucun contrat UX formel » | epics.md, lignes 20 et 108 | UX final | epics.md |

## 7. Décisions que le développeur devrait inventer aujourd'hui

1. Ce que devient un non-partant dans `P_ens` et s'il est exclu avant le scoring (F2).
2. Quand écrire `recommandation_consultee`, et où ranger l'arrivée et l'affichage du débrief d'une course seulement consultée (F3).
3. Comment l'app retrouve l'id serveur d'une course passée, ou quelle route par clé utiliser (F4).
4. Où lire la musique pour la méthode 1 (F5).
5. Comment le backend et l'appareil connaissent, à l'exécution, la version du moteur et l'empreinte des règles (F13).
6. La définition chiffrée de « historique court » (côté Python), de « terrain majoritairement inconnu » et de la fragilité (F12).
7. Le traitement d'un cheval sans dossard ou à dossard en double (F11).
8. La relecture intrajournalière des partants, cotes et non-partants (F9).
9. La règle de taille d'échantillon et la règle de proposition des seuils au pilote (F15).
10. Le type de période et l'état gelé dans `performance_strategie`, le statut par comparateur et le cache local des performances (F16).
11. La mise en page des 34 seuils dans Réglages (F19).
12. Ce que la baseline Alembic doit contenir au moment de 5.4 (F20).

## 8. Points solides (à conserver)

- 5.1 est un vrai verrou, avec une condition d'arrêt explicite si la mécanique du pari a changé.
- Absence d'argent vérifiée mécaniquement à chaque couche : moteur, OpenAPI, libellés, export.
- Parité par cas partagés, quantification à 1e-9, plafond d'itérations commun, catalogue identique octet à octet.
- Immuabilité et unicité de la journalisation, un seul écrivain par table, refus de journaliser avant le pilote.
- Accessibilité précise et testable (nœuds groupés, annonces uniques, retours de focus, 200 %).
- Prise en compte du code réel : allocation déjà stockée, `CourseOut` qui marque déjà l'UTC, `_migrate()` hérité, `markStale()`.

## 9. Prochaines étapes recommandées

1. Lancer 5.1 (tâche humaine) en y ajoutant les contrôles de F1.
2. Faire une passe **bmad-correct-course** qui :
   - reporte les décisions du 2026-10-18 dans le reconcile, la spine, le cahier et le PRD (F6, F7, C1 à C15) ;
   - tranche F2 ;
   - corrige 5.4, 5.5, 5.7, 5.8, 5.12, 5.14, 5.15, 5.16, 6.1, 6.5, 6.6 et 6.7 ;
   - découpe 5.7, 5.12 et 6.4.
3. Faire préciser par **bmad-ux** les Réglages Multi, l'écarté touché, la formule mémorisée et le débrief en lecture seule.
4. Relancer cette revue avant le démarrage de 5.5.
