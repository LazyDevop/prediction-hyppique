# Contrôle de préparation à l'implémentation — Epics 7 à 11 (seconde passe)

- **Date :** 2026-11-16
- **Périmètre :** `epics.md`, Epics 7 (fondations de sécurité), 8 (comptes), 9 (licences et paiement), 10 (back-office), 11 (pronostics publiés).
- **Passe précédente :** `implementation-readiness-2026-11-15.md` (FAIL : 2 critiques, 6 élevés, 11 moyens, 10 faibles).
- **Confronté à :** PRD (§4.12–§4.15, FR-31 à FR-53, §6.1, §11 OQ 13–20, §12), Architecture Spine (AD-10, AD-12 à AD-21, Stack, Structural Seed, Deferred), `EXPERIENCE.md` et `DESIGN.md` (back-office, `followed-race`, Mes appareils en mode restreint), fichier de décisions des correctifs du 2026-11-16. Code consulté là où une story décrit l'état actuel : `backend/Dockerfile`, `docker-compose.yml`, `backend/app/main.py`, `backend/app/data/repository.py`, `backend/app/data/models.py`, `backend/app/api/*`, `backend/app/jobs/*` (dont `cotes_instantanees.py`, `pronostics_ml.py` et `bilan_pronostics.py`, non suivi, sur la branche `feat/bilan-pronostics`), `_bmad-output/implementation-artifacts/sprint-status.yaml`.
- **Posture :** revue sceptique, sans modification des fichiers de planification.

## Verdict : **CONCERNS** (pour l'ensemble des Epics 7 à 11)

Les deux constats critiques et les six constats élevés de la passe du 2026-11-15 sont résolus dans le texte. Le back-office a désormais une stack, un hébergement et une UX. La matrice des rôles PostgreSQL ne casse plus l'import à la demande. La « course suivie », la session restreinte et la topologie d'hôtes sont décidées. Les bloqueurs externes sont marqués « Bloqué par / Livrable sans ».

Les correctifs ont introduit **un constat élevé** :
- La fonction d'audit chaînée de la story 7.10 doit lire la dernière empreinte du journal.
- Or `role_api` n'a que `INSERT` sur `audit.journal_audit`.
- Toute l'Epic 8 dépend de la story 7.10.

Les correctifs ont aussi introduit **trois constats moyens**, sur les droits de `role_api` et sur l'ordre de l'Epic 10. Aucun n'empêche de démarrer l'Epic 7. Chacun se corrige en une décision courte avant la story concernée (7.2 ou 7.10).

**Recommandation :** corriger N1 à N3 dans la spine et dans les stories 7.2 et 7.10 (une mise à jour `bmad-architecture` courte), puis lancer `bmad-sprint-planning` pour régénérer le suivi. Les stories listées plus bas (« Démarrables maintenant ») peuvent démarrer sans attendre.

### Ce qui tient

- **Traçabilité, sens aller :** FR-31 à FR-53, NFR-12 à NFR-16 et UX-DR14 à UX-DR24 ont toutes au moins une story. Le tableau de couverture ajoute les écrans du back-office (10.1 à 10.7) et la barrière OQ 18 (9.0 → 9.5, 7.7). Les trous de contenu de la passe précédente (course suivie, stockage de FR-51) sont comblés par les stories 8.9 et 11.1.
- **Traçabilité, sens retour :** chaque story, y compris les nouvelles (7.9, 7.10, 8.9, 9.0, 10.7), cite son FR, son AD ou le constat qu'elle corrige. Aucune story orpheline.
- **Cohérence entre PRD, spine, UX et epics sur les décisions du 2026-11-16 :**
  - back-office Flutter Web avec un second point d'entrée FastAPI (PRD FR-47, AD-20, EXPERIENCE « Back-office », Epic 10) ;
  - topologie `api.` / `app.` / `admin.<domaine>` (PRD OQ 20, AD-21, stories 7.3, 7.6, 8.2) ;
  - session restreinte de l'appareil bloqué (PRD FR-36, AD-16, EXPERIENCE « Mes appareils — mode restreint », story 8.6) ;
  - fournisseur d'email (PRD OQ 19, Stack, stories 8.4, 8.5, 8.6, 9.7, 9.11, 10.4) ;
  - JWT EdDSA, identifiant local de l'appareil, PIN comme simple barrière locale (AD-16, stories 8.2 et 8.3) ;
  - HMAC des codes OTP (AD-16, story 8.1) ;
  - Traefik v3 (AD-21, Stack, story 7.3) ;
  - schémas `courses` / `comptes` / `audit` et `schema_translate_map` (AD-19, story 7.2) ;
  - `age` et destination hors hôte des sauvegardes (AD-19, Deferred, stories 7.2 et 10.4).

  Ces décisions concordent dans tous les documents.
- **État du code annoncé par les stories, revérifié :**
  - Le `Dockerfile` ne copie que `app/`, ni `backend/scripts/` ni `alembic/`, qui n'existent pas encore.
  - `allow_origins=["*"]` est toujours là, et `api` est publié sur `8000:8000`.
  - `GET /dashboard/data` et `POST /pronostics` sont anonymes.
  - Le service `cotes` n'écrit que dans `cotes_instantanees`, par `enregistrer_instantanes` (insertion seule, `on_conflict_do_nothing`), ce qui est compatible avec `role_cotes`.
  - Le service `pronostics` n'écrit que dans `prediction_runs` et `prediction_chevaux`, par `enregistrer_pronostic_ml`, ce qui est compatible avec `role_pronostics`.
  - `prediction_runs` n'a ni `modele_version` ni `statut` : la story 11.1 les crée.
  - Les écritures de `api` sur le schéma des courses (`import_course`, `save_historique`, `save_prediction_run`) sont maintenant prévues par `role_api`, sauf `prediction_chevaux` (N2).
- **Dépendances vers l'avant :** elles restent désamorcées explicitement, et les nouvelles le sont aussi :
  - 8.8 → 8.9 (« Dépend de ») ;
  - 9.5 → 9.0 (barrière) ;
  - classe transitoire *personnel seulement — à déplacer* de la 9.2 jusqu'à la 10.7 ;
  - levée de la 7.8 conditionnée à 9.2 et 10.7 ;
  - ordre complet de l'Epic 11.

  Seule la 10.4 garde une dépendance vers l'avant non désamorcée (N4).
- **Bloqueurs externes :** chaque story concernée porte « Bloqué par / Livrable sans » (7.2, 7.3, 7.6, 7.7, 8.1, 8.3 à 8.6, 9.0, 9.4 à 9.7, 9.9, 9.11, Epic 10, 10.4), avec un faux client ou une valeur provisoire. Conformément au cadrage, ils ne font pas échouer la gate.

## Suivi des constats de la passe du 2026-11-15

| # | Statut | Preuve dans le texte (et résidu éventuel) |
|---|---|---|
| C1 | **Résolu** | AD-20 « Shape » et « Staff auth », AD-21 (hôte `admin.`), Stack (Flutter Web, `argon2-cffi`, `pyotp`), Seed (`backend/app/backoffice/`, `backoffice_web/`), EXPERIENCE « Back-office (application distincte) », DESIGN `backoffice-shell` et `correction-diff`, stories 10.1 et 10.7, 9.2 (classe transitoire). Résidus mineurs UX ↔ stories : N5, N6. |
| C2 | **Résolu** | AD-19 (un rôle par écrivain ; `role_api` avec les écritures d'ingestion) ; story 7.2 (test de bout en bout `POST /courses/{id}/importer` sous `role_api`). Résidu : `prediction_chevaux` (N2). |
| É1 | **Résolu** | AD-14 « `prediction_runs` columns », révision Alembic de la 11.1, index `(course_id, horizon, modele_version)`, ligne `indisponible`, rôles `role_pronostics` et `role_cotes` distincts. Résidu : la ligne `indisponible` occupe l'index (N9). |
| É2 | **Résolu** | Story 8.9, composant `followed-race` (EXPERIENCE, DESIGN), 8.8 « Dépend de 8.9 ». Résidus : N12. |
| É3 | **Résolu** | AD-16 « Blocked device — restricted session », PRD FR-36 (4ᵉ conséquence), EXPERIENCE (mode restreint), story 8.6. Résidus : N7. |
| É4 | **Résolu** | PRD OQ 19, Stack « Email provider », « Bloqué par » des stories 8.4, 8.5, 8.6, 9.7, 9.11 et 10.4. |
| É5 | **Résolu dans `epics.md`** ; suivi non régénéré | Lignes « Bloqué par / Livrable sans » partout où il le faut ; story 9.0, barrière avant la 9.5. `sprint-status.yaml` n'a pas été mis à jour (N13). |
| É6 | **Résolu** | AD-21 « Host topology », AD-16 (cookie `__Host-`, même origine), PRD OQ 20, stories 7.3 (tâche humaine DNS), 7.6 et 8.2. |
| M1 | **Résolu** | AD-19 et diagramme : `courses` ; `schema_translate_map`, `include_schemas=True` (7.2). Résidu : SQL brut et code propre à SQLite (N10). |
| M2 | **Résolu** | `age`, clé privée hors ligne, destination hors hôte en tâche humaine (AD-19, Deferred, 7.2, 10.4). |
| M3 | **Résolu** | AD-16 « Tokens », stories 8.2 et 8.3. |
| M4 | **Résolu** | AD-16 (interrogation de `GET /appairage/{id}/statut`), story 8.7. |
| M5 | **Résolu** | AD-16 « Number change and recovery », PRD OQ 17 (SMS transactionnels), story 8.5. |
| M6 | **Partiellement résolu** | Emplacement des tables fixé (AD-19, 7.2, 7.4, 9.9, 10.1, 10.5) ; le test de la 10.6 est corrigé ; les `[ASSUMPTION]` périmés de 10.5 et 10.6 sont retirés. Restent : `role_api` en « lecture et écriture » sur tout `comptes` (N3) ; ligne `role_backoffice` d'AD-19 incomplète (N11). |
| M7 | **Résolu** | Story 7.9, que 7.7 et 8.1 citent. |
| M8 | **Résolu** | En-tête de l'Epic 7, story 7.8 (« Démarre tout de suite »), AD-21. |
| M9 | **Résolu** | En-tête de l'Epic 11. |
| M10 | **Ouvert — point du porteur de projet** (hors défaut de planification) | `[ASSUMPTION]` toujours présents : PRD FR-39 (matrice), FR-43, FR-46 ; stories 8.2, 9.11, 11.2, 11.5 ; plusieurs dans EXPERIENCE (back-office). L'action « lot de confirmations » n'est pas encore inscrite dans `sprint-status.yaml` (N13). À faire avant les stories 9.2 et 11.2. |
| M11 | **Résolu** | Liste blanche typée (10.3, EXPERIENCE), écran Corrections. Résidu : motif obligatoire (N5). |
| F1 | **Partiellement résolu** | La liste de la 7.1 contient maintenant `routes_dashboard.py`, `routes_pronostics.py`, `predict.py` et `rebuild_historique.py`. Elle cite aussi un `backfill_historique.py` qui n'existe pas et omet `bilan_pronostics.py` (N10). Le test « échoue si un nouveau `Repository()` apparaît » se corrige seul. |
| F2 | **Résolu** | Story 7.6, au mot près d'EXPERIENCE. |
| F3 | **Résolu** | Tableau de couverture : UX-DR24 → 8.8. |
| F4 | **Résolu** | PRD OQ 14 étendue. |
| F5 | **Résolu** | AD-16, story 8.1 (`OTP_HMAC_CLE`). |
| F6 | **Résolu** | Stories 7.8 (dernier critère) et 9.5. |
| F7 | **Résolu** | AD-21, Stack, story 7.3. |
| F8 | **Résolu** | Stories 11.1 (`Europe/Paris`, test aux deux bascules) et 11.3. |
| F9 | **Résolu** | Story 7.10 (écrivain unique et registre), répartition par story. A introduit N1 et N4. |
| F10 | **Ouvert — décision du porteur de projet** (hors défaut) | AD-14 Gate B, Deferred. Sans effet sur la gate A : `en_evaluation` reste vrai. |

## Nouveaux constats

Chaque constat donne son niveau, son emplacement et le skill qui le corrige.

### Critique

Aucun.

### Élevé

**N1 — L'écrivain chaîné de la story 7.10 doit lire le journal, mais `role_api` n'a que `INSERT` sur `audit.journal_audit`.**
- *Emplacement :* story 7.10 (1ᵉʳ et 2ᵉ critères) ; AD-19 (ligne `role_api` : « `audit.journal_audit` INSERT only ») ; story 7.2 (ligne `role_api`) ; AD-20 (chaînage, verrou consultatif).
- *Constat :* `inscrire_audit` « lit l'empreinte de la dernière ligne » puis insère. C'est une fonction Python (`backend/app/data/audit.py`) appelée sous le rôle du service. Sous `role_api`, qui n'a ni `SELECT` ni droit sur une fonction SQL, cette lecture échoue. Or la story 7.10 exige précisément ce test de droits : « `role_api` et `role_backoffice` n'y ont que `INSERT` ». Toutes les écritures d'audit de l'Epic 8 (8.2, 8.4 à 8.7) et de l'Epic 9 (9.5, 9.6) passent par `api`. Le développeur doit donc inventer l'une de ces solutions :
  - accorder à `role_api` un `SELECT` sur la seule empreinte de tête (colonnes `id` et `empreinte`) ;
  - créer une fonction SQL `SECURITY DEFINER`, propriété d'un rôle dédié, qui calcule l'empreinte et insère la ligne (le chaînage reste alors en base) ;
  - confier l'écriture à un autre service.

  C'est une décision de sécurité, puisque le « INSERT seul » visait à empêcher `api` de lire le journal.
- *Effet :* la story 7.10, prérequis de la 8.1, ne peut pas passer ses propres tests tels qu'écrits.
- *Correction :* `bmad-architecture` (amender AD-19 et AD-20 : mécanisme d'écriture chaînée sous un rôle sans lecture), puis `bmad-create-epics-and-stories` (story 7.10 et ligne `role_api` de la story 7.2).

### Moyen

| # | Constat | Emplacement | Skill |
|---|---|---|---|
| N2 | `role_api` peut insérer une ligne `prediction_runs` de variante `app` (RLS), mais n'a aucun droit sur `prediction_chevaux`. Or `save_prediction_run` (`POST /pronostics`) insère aussi des `PredictionCheval` (vérifié dans `repository.py`). La route casse donc sur PostgreSQL dès la 7.2, alors que la 7.2 dit qu'elle reste permise « jusqu'à ce que la story 11.2 décide ». À l'inverse, accorder `INSERT` sur `prediction_chevaux` sans politique RLS permettrait à `api` d'ajouter des chevaux à un pronostic `ml` publié, ce que contredit la 11.1 (« seul `role_pronostics` peut insérer des lignes `ml` »). Il faut décider : une RLS sur `prediction_chevaux` par la variante du run parent, ou le retrait de `POST /pronostics` avancé à la 7.2 (la route est de toute façon fermée par la 7.8, et 11.2 la retire par défaut). | AD-19 (lignes `role_api`, `role_pronostics`) ; AD-14 « Storage » ; stories 7.2 (rôles et tests), 11.1, 11.2 | `bmad-architecture` puis `bmad-create-epics-and-stories` |
| N3 | `role_api` reçoit « `comptes` read/write » (AD-19, story 7.2), donc l'écriture de `personnel`, `session_personnel`, `demande_licence` et `offre`, et l'`UPDATE` de `droit`. Cela contredit : AD-17 (« `droit` is insert-only ») ; la story 9.1 (« aucun rôle n'a `DELETE` ni `UPDATE` sur les autres colonnes », test de droits) ; AD-20 (« staff routes reachable through the public `api` » est ce qu'AD-20 empêche). Le test de la 9.1 échouerait sur `role_api`. Il faut une matrice par table pour `role_api` dans `comptes`, symétrique de celle de `role_backoffice` dans la 10.6 : écriture des tables de compte, d'appareil, de session, de synchronisation, de paiement, de `limite_debit` et de `quota_photo` ; insertion seule dans `droit` ; aucune écriture sur `personnel`, `session_personnel`, `demande_licence` ni `offre`. | AD-19 ; stories 7.2, 9.1, 10.6 | `bmad-architecture` puis `bmad-create-epics-and-stories` |
| N4 | La story 10.4 exige que *chaque* type d'événement d'AD-20 ait un appelant dans le code et un test de bout en bout, y compris « demande et approbation d'une licence manuelle » (10.5) et « modification d'une offre, révocation » (10.6). Or l'ordre de l'Epic 10 place 10.4 avant 10.5 et 10.6 (« 10.1, 10.2, 10.7, puis 10.3 à 10.6 »). C'est une dépendance vers l'avant : la 10.4 ne peut pas être terminée à son rang. Il faut placer la 10.4 après la 10.6, ou limiter son test aux types déjà livrés et laisser chaque story ajouter son cas. | En-tête de l'Epic 10 ; story 10.4 (1ᵉʳ critère) | `bmad-create-epics-and-stories` |

### Faible

| # | Constat | Emplacement | Skill |
|---|---|---|---|
| N5 | EXPERIENCE (Corrections) exige un motif obligatoire à la saisie et au rejet. Ni `correction_saisie` (10.3 : colonnes énumérées) ni les critères de la 10.3 ne portent de motif. | 10.3 ; EXPERIENCE « Back-office » | `bmad-create-epics-and-stories` |
| N6 | Écarts entre UX et stories pour le back-office : **(a)** Tableau de bord : EXPERIENCE donne à l'agent une vue de ses seules saisies, la 10.7 lui renvoie 403 ; **(b)** Personnel : « un administrateur ne désactive pas son propre accès » (EXPERIENCE) contre « pas le dernier administrateur actif » (10.2) ; **(c)** verrouillage : « contactez un administrateur » (EXPERIENCE) contre un déverrouillage automatique après `PERSONNEL_VERROUILLAGE_MINUTES` (10.1) ; **(d)** Offres : « Créer / Désactiver » (EXPERIENCE) contre « crée, modifie ou désactive » (10.6, FR-41) ; **(e)** l'en-tête d'état de la chaîne du Journal d'audit (« Chaîne vérifiée jusqu'à l'entrée n° … ») n'est pas dans la 10.4. | 10.1, 10.2, 10.4, 10.6, 10.7 ; EXPERIENCE « Back-office » | `bmad-ux` ou `bmad-create-epics-and-stories` (aligner l'un sur l'autre) |
| N7 | Session restreinte : **(a)** la 8.6 présente « Découvrir l'offre Duo » comme une entrée vers l'écran Offres (Epic 9). Or `GET /offres` est de classe *compte + palier*, et le jeton de gestion renvoie 403 sur tout le reste. EXPERIENCE tranche : texte seul, « Souscrivez depuis un appareil déjà connecté ». **(b)** Le jeton est lié à « l'identifiant local de l'appareil refusé », que seule l'app Android possède (8.2). Le cas d'un navigateur refusé à la limite (8.7 renvoie à l'écran Appareil bloqué) n'a pas d'identifiant défini. | 8.6 (4ᵉ et 5ᵉ critères), 8.7 ; AD-16 | `bmad-create-epics-and-stories` (+ `bmad-architecture` pour b) |
| N8 | Lecture de `correction_saisie` par l'ingestion : AD-10 et la 10.3 disent que l'ingestion ne la lit jamais (test « l'ingestion ne lit ni n'écrit `correction_saisie` »). AD-19, la 7.2 et la même 10.3 accordent à `role_ingestion` sa lecture « pour la surcouche ». Il faut préciser que le droit sert à `rebuild` (lecture par la surcouche de `repository.py`) et que le test vise les jobs d'ingestion. | AD-10, AD-19 ; 7.2, 10.3 | `bmad-architecture` |
| N9 | Une ligne `statut = 'indisponible'` occupe l'index unique `(course_id, horizon, modele_version) WHERE variante = 'ml'`. Si les données arrivent plus tard dans la matinée, le pronostic du matin ne peut plus être publié sous la même version. Il faut décider si l'index se restreint à `statut = 'publie'`, ou si « indisponible » est définitif pour cet horizon. | AD-14 ; 11.1 | `bmad-architecture` |
| N10 | Passage à PostgreSQL : **(a)** la 7.1 cite `jobs/backfill_historique.py`, qui n'existe pas ; **(b)** `jobs/bilan_pronostics.py` (en cours sur la branche, importé par `pronostics_ml.py`) instancie `Repository()`, interroge en SQL brut (`text("... FROM prediction_runs ...")`), que `schema_translate_map` ne traduit pas, et écrit dans `/app/data/bilans`, sur le volume SQLite partagé ; **(c)** la 7.2 ne cite pas le code propre à SQLite à porter (`sqlite_insert` dans `enregistrer_instantanes` et pour `PerformanceHistorique`, `PRAGMA` à la connexion). Les tests de la 7.1 et de la 7.2 le révéleront, mais il faut décider pour le SQL brut : `search_path` par rôle, ou interdiction. | 7.1 (dernier critère) ; 7.2 ; code | `bmad-create-epics-and-stories` |
| N11 | La spine est en retard sur les stories : la classe *publique* d'AD-15 n'inclut pas `GET /conditions` (7.9), que la 9.2 classe pourtant *publique*. La ligne `role_backoffice` d'AD-19 omet l'écriture de `session_personnel` et de `demande_licence` (10.1, 10.5, 10.6). | AD-15, AD-19 | `bmad-architecture` |
| N12 | Story 8.9 : **(a)** elle dépend de la purge à 90 jours de la 5.20 sans la citer dans une ligne « Dépend de » ; **(b)** sur le web, le comportement de l'étoile avant la 8.8 n'est pas dit (EXPERIENCE : sur le web, suivre exige le réseau, donc les routes de la 8.8). Le libellé TalkBack diffère légèrement d'EXPERIENCE. | 8.9 ; EXPERIENCE `followed-race` | `bmad-create-epics-and-stories` |
| N13 | `sprint-status.yaml` est périmé : il manque 7.8, 7.9, 7.10, 8.9, 9.0, 9.11, 10.6, 10.7 et toutes les stories 11.1 à 11.5 ; 9-4 et 9-5 sont inversées par rapport à `epics.md` (« payer » contre « catalogue ») ; 9-8 et 10-4 portent d'anciens titres. Il n'y a ni statut « bloqué » ni action pour le lot de confirmations M10. À régénérer après la gate (étape normale de la planification). | `implementation-artifacts/sprint-status.yaml` | `bmad-sprint-planning` |
| N14 | Lignes de blocage manquantes, mineures : la 7.4 n'a pas de « Bloqué par » sur l'OQ 14 (seuils de débit, ajoutés à l'OQ 14) ; la 7.5 ne prévoit pas le motif de clé du fournisseur d'email (OQ 19) à côté de ceux de l'agrégateur et du fournisseur de SMS. | 7.4 ; 7.5 | `bmad-create-epics-and-stories` |

**Décompte des nouveaux constats :** 0 critique, 1 élevé, 3 moyens, 10 faibles.
**Points du porteur de projet encore ouverts (hors décompte) :** M10 (lot de confirmations) et F10 (référentiel d'AD-14).

## Bloqueurs externes : stories bloquées et marquage

| Bloqueur | Stories (intégration réelle ou mise en vente) | Marqué « Bloqué par / Livrable sans » ? |
|---|---|---|
| Vérification du VPS (SSE2) | 7.2 et 7.3 (production) | **Oui** (7.1, 1ʳᵉ tâche ; 7.2, 7.3). La 7.8 n'en dépend plus. |
| OQ 17, fournisseur OTP et SMS d'alerte | 8.1, 8.5, 8.6 | **Oui** |
| OQ 19, fournisseur d'email | 8.4, 8.5, 8.6, 9.7, 9.11, 10.4 | **Oui** (7.5 : motif de clé absent, N14) |
| OQ 15, agrégateur | 9.5 | **Oui** |
| OQ 18, règles de Google Play | 7.7 (diffusion), 9.5 (barrière 9.0) | **Oui** |
| OQ 13, prix, places du Duo, matrice | 9.4, 9.6 (et 9.2 via M10) | **Oui** |
| OQ 14, limites et délais | 8.3, 8.5, 8.6, 9.9, 9.11 | **Oui** (7.4 : N14) |
| OQ 20, domaine et DNS | 7.3, 7.6, Epic 10 | **Oui** |
| §9.2, avis juridique | 7.7 (textes définitifs), 9.5 (mise en vente) | **Oui** |
| Compte développeur Google Play | 7.7 | **Oui** |
| Destination hors hôte des sauvegardes | 7.2, 10.4 | **Oui** |

## Ordre de démarrage recommandé

### Démarrables maintenant, sans aucune décision externe ni correction

1. **Story 7.8** : liste d'adresses dans `DOCKER-USER` et middleware `ACCES_RESTREINT_SECRET`. Elle ne dépend de rien, et l'API est publique aujourd'hui (vérifié).
2. **Story 7.1, première tâche** : vérifier PostgreSQL, son pilote, Traefik v3 et `age` sur le VPS. Tâche humaine, avec accès au VPS.
3. **Story 7.1, suite** : Alembic sur SQLite, baseline, `backend/scripts/demarrer_api.py`, refus de migrer dans les autres services. La liste des `Repository()` est à ajuster au passage (N10 a et b).
4. **Story 7.5** : script de contrôle des secrets. Les motifs des fournisseurs s'ajouteront à leur choix.
5. **Story 7.9** : `CGU_VERSION` et `GET /conditions`, indépendante.
6. **Story 9.0** : recherche sur les règles de Google Play (OQ 18), sans code, à tout moment.
7. **Story 11.4, partie moteur seulement** : `renormaliser_sans_non_partants`, en Python et en Dart, avec ses cas dans `engine_cases.json`.

### Ensuite, après une correction courte de la planification

8. **Story 7.2**, après la 7.1 et la correction de N2 et N3 (matrice de `role_api`). Développement sur un PostgreSQL local ; bascule de production après le feu vert du VPS.
9. **Story 7.10**, après la 7.2 et la correction de N1.
10. **Stories 7.3, 7.4, 7.6** dans l'ordre (en local sur `*.localhost` tant que le domaine n'est pas acheté), puis **7.7** (diffusion en test interne).
11. **Epic 8** : 8.1 (après 7.2, 7.4, 7.9 et 7.10), puis 8.2, 8.3, 8.7, 8.4, 8.5, 8.6, puis **8.9** et **8.8**, avec les faux clients.
12. **Epic 9** : 9.1, puis 9.2 (après confirmation de la matrice, M10), 9.3, 9.4, 9.6, 9.8, 9.9, 9.10, 9.11, 9.7. La **9.5** ne démarre qu'après la 9.0.
13. **Epic 10** : 10.1, 10.2, 10.7, 10.3, 10.5, 10.6, puis 10.4 en dernier (N4).
14. **Epic 11** : 11.1 après la 7.2 (et N9) ; 11.2 après les stories 8.1, 8.2 et 9.1 à 9.3 (et la décision sur `POST /pronostics`) ; 11.3 après 11.2 et 9.4 ; 11.4 (partie écran) ; 11.5 après 5.14, 5.15, 5.20 et 6.7.

## Actions prioritaires

1. **`bmad-architecture`** (mise à jour courte) : N1 (écriture chaînée sous un rôle sans lecture), N2 (`prediction_chevaux`), N3 (matrice de `role_api` sur `comptes`), puis N8, N9 et N11.
2. **`bmad-create-epics-and-stories`** : répercuter N1 à N3 dans les stories 7.2, 7.10, 9.1 et 11.1 ; réordonner la 10.4 (N4) ; N5, N7, N10, N12 et N14.
3. **`bmad-ux`** ou **`bmad-create-epics-and-stories`** : aligner l'UX et les stories du back-office (N6).
4. **`bmad-sprint-planning`** : régénérer `sprint-status.yaml` (N13), avec le statut « bloqué », l'action M10 et la destination hors hôte des sauvegardes.
5. **Porteur de projet** : le lot de confirmations M10 avant les stories 9.2 et 11.2 ; F10 quand il le souhaite ; les tâches humaines (vérification du VPS, compte Google Play, domaine, destination des sauvegardes).

## Suite donnée (2026-11-16)

- **N1** corrigé : le journal d'audit ne s'écrit que par la fonction SQL `audit.inscrire()` (`SECURITY DEFINER`) ; les rôles de service n'ont que `EXECUTE` (AD-19, story 7.10).
- **N2** corrigé : RLS sur `prediction_chevaux` par la variante du run parent ; `role_api` insère `app`, `role_pronostics` insère `ml` (AD-19, story 7.2).
- **N3** corrigé : droits de `role_api` sur `comptes` table par table, `droit` en insertion seule, aucun accès aux tables du personnel (AD-19, story 7.2).
- **N4** corrigé : la 10.4 teste les événements déjà instrumentés ; les 10.5 et 10.6 complètent le test elles-mêmes.
- **F1** corrigé : liste des sites d'appel de `Repository()` alignée sur `backend/app/jobs/`.
- Les constats faibles restent pour mémoire ; ils se traitent dans les stories concernées.
