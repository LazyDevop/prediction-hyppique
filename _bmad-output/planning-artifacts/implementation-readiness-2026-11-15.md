# Contrôle de préparation à l'implémentation — Epics 7 à 11

- **Date :** 2026-11-15
- **Périmètre :** `epics.md`, Epics 7 (fondations de sécurité), 8 (comptes), 9 (licences et paiement), 10 (back-office), 11 (pronostics publiés).
- **Confronté à :** PRD (§4.12–§4.15, FR-31 à FR-53, §6.1, §8, §11 OQ 13–18), Architecture Spine (AD-9, AD-12 à AD-21, Stack, Deferred), `EXPERIENCE.md`. Code consulté là où une story décrit l'état actuel : `backend/app/main.py`, `docker-compose.yml`, `backend/Dockerfile`, `backend/app/data/repository.py`, `backend/app/data/models.py`, `backend/app/api/*`, `backend/app/jobs/pronostics_ml.py`.
- **Posture :** revue sceptique, sans modification des fichiers de planification.

## Verdict : **FAIL** (pour l'ensemble des Epics 7 à 11)

Deux constats critiques empêchent d'implémenter les Epics 7 à 11 sans inventer de décisions. L'Epic 10 n'a ni stack, ni hébergement cohérent pour `/dashboard*`, ni UX. La matrice des rôles PostgreSQL (AD-19) interdit à `api` des écritures qu'il fait aujourd'hui, et la story 7.2 casserait l'import à la demande le jour de la migration. Six autres constats sont élevés.

**L'Epic 7 est en grande partie prêt** : les stories 7.1, 7.8 et 7.5 peuvent démarrer tout de suite (voir l'ordre de démarrage recommandé, plus bas). Le verdict porte sur l'ensemble demandé, pas sur le premier epic.

### Ce qui tient

- **Traçabilité, sens aller :** FR-31 à FR-53, NFR-12 à NFR-16 et UX-DR14 à UX-DR24 ont toutes au moins une story (tableau « Couverture des exigences du lancement payant »). Il y a deux trous de contenu, pas de numéro : la fonction « course suivie » de FR-38 (É2) et le stockage qu'attend FR-51 (É1).
- **Traçabilité, sens retour :** chaque story cite son FR, son NFR ou son AD. Aucune story orpheline.
- **Dépendances vers l'avant :** la plupart sont désamorcées explicitement : `palier_actif` provisoire (8.2 → 9.1), « présent dès que l'écran Offres existe » (8.4, 8.6), « livré côté serveur seulement si 5.20 n'est pas livrée » (8.8), licence manuelle orpheline tant que 10.5 n'existe pas (9.7), restriction 7.8 jusqu'à 10.1 (9.2). C'est un bon travail.
- **État du code annoncé par les stories, vérifié :** CORS `["*"]` dans `main.py` ; `api` publié sur `8000:8000` ; `GET /dashboard/data` sans authentification ; `POST /pronostics` anonyme ; `Repository.__init__` appelle `create_all` puis `_migrate()` ; `rang_impute`, `cote_reference_le` et `cote_direct_le` sont présents ; l'index partiel est en `sqlite_where` seul ; `routes_pronostics.maintenant()` et `cotes_instantanees.pris_le` sont naïfs ; le `Dockerfile` ne copie que `app/`. Les affirmations de 7.1, 7.2, 7.3 et 7.8 sont exactes. Le seul écart est une liste incomplète (F1).
- **Bloqueurs externes déjà cités :** OQ 13 à 18 et §9.2 sont nommés aux bons endroits, et les faux clients (OTP, email, agrégateur) permettent de développer sans fournisseur.

## Constats

Chaque constat donne son niveau, son emplacement et le skill qui le corrige.

### Critique

**C1 — Le back-office n'a ni stack, ni hébergement cohérent de `/dashboard*`, ni UX.**
- *Emplacement :* stories 10.1 à 10.6 ; story 9.2 (2ᵉ critère) ; AD-19 (ligne `role_backoffice`) ; AD-20 ; Stack ; Structural Seed (`backoffice/`) ; `EXPERIENCE.md` (aucune surface back-office).
- *Constat :*
  - La story 10.1 crée un service distinct `backoffice/` qui se connecte avec `role_backoffice`.
  - Les stories 9.2 et 10.1 servent les routes `/dashboard*` « sur l'hôte du back-office ». Or ces routes vivent aujourd'hui dans l'application FastAPI `api` (`routes_dashboard.py`) et lisent `prediction_runs`.
  - Selon AD-19, `role_backoffice` ne lit du schéma des courses que `correction_saisie`. Servi par `backoffice`, le tableau de bord ne lit donc rien. Servi par `api` avec un routage par hôte, il tourne sous `role_api`, sans la session du personnel, qui vit dans `backoffice`.
  - Rien ne fixe le framework ni l'interface du back-office : FastAPI et gabarits ? Flutter Web ? partage de `repository.py` ? Rien ne fixe non plus le hachage des mots de passe, la bibliothèque TOTP, la forme des sessions du personnel, ni les écrans (connexion et TOTP, gestion du personnel, validation des corrections, licences, offres, révocation). Aucune maquette ni aucun motif UX n'existe pour ces écrans.
- *Effet :* aucune story de l'Epic 10 ne se code sans inventer la moitié de l'architecture.
- *Correction :* `bmad-architecture` (mise à jour d'AD-19 et AD-20, Stack) ; `bmad-ux` (surfaces minimales du back-office) ; puis `bmad-create-epics-and-stories` (reprise de 10.1 et 9.2).

**C2 — AD-19 interdit à `api` des écritures qu'il fait aujourd'hui sur le schéma des courses.**
- *Emplacement :* AD-19 (`role_api` : « race schema read ») ; story 7.2 (3ᵉ et 4ᵉ critères) ; AD-10 (« the on-demand runner refresh updates `donnees_maj_le` ») ; story 9.2 (2ᵉ critère).
- *Constat :* `api` écrit dans les données de courses par :
  - `POST /courses/{id}/importer` (`repository.import_course`, FR-3) ;
  - `POST /chevaux/{id}/backfill` ;
  - `POST /pronostics` (`save_prediction_run`, variante `app`, jusqu'à la story 11.2) ;
  - demain, `POST /multi/courses/{cle_course}/rafraichir` (AD-10).

  Appliquée à la lettre, la story 7.2 casse l'import à la demande et le backfill en production le jour de la bascule. Le développeur doit alors inventer soit un nouveau rôle, soit des droits supplémentaires pour `role_api`, soit la délégation de ces écritures à un autre service.
- *Correction :* `bmad-architecture` (décider qui écrit pour les routes d'import, de backfill et de rafraîchissement, puis amender AD-19) ; ensuite `bmad-create-epics-and-stories` (story 7.2).

### Élevé

**É1 — Les stories 11.1 et 11.2 s'appuient sur des champs et un index qui n'existent pas, et aucune story ne les crée.**
- *Emplacement :* stories 11.1 et 11.2 ; AD-14 (Storage, Payload) ; `models.py` (`PredictionRun`) ; `jobs/pronostics_ml.py`.
- *Constat :*
  - `prediction_runs` n'a pas de colonne `modele_version`. Le job `pronostics_ml.py` n'écrit aucune version.
  - L'index unique porte sur `(course_id, horizon) WHERE variante = 'ml'`, et la baseline de la story 7.1 doit le reprendre tel quel. Or la story 11.1 exige « une ligne par (course, horizon, `modele_version`) » et « un recalcul corrigé publié sous une nouvelle `modele_version` », ce que cet index refuse.
  - `donnees_le`, `en_evaluation` et la ligne « pronostic indisponible » avec sa raison (FR-51) n'ont aucun stockage.
  - Le test de la story 11.1 « seul `pronostics` écrit les pronostics, seul `cotes` écrit les instantanés (test de droits) » ne peut pas passer : AD-19 donne le même `role_courses` à `ingestion`, `cotes`, `pronostics` et `rebuild`.
- *Correction :* `bmad-create-epics-and-stories` (une révision Alembic dans 11.1 : colonne, nouvel index, ligne d'indisponibilité) ; `bmad-architecture` (rôle par service, ou écrivain unique contrôlé autrement qu'en base).

**É2 — Aucune story ne crée la « course suivie ».**
- *Emplacement :* FR-38 ; glossaire du PRD ; `EXPERIENCE.md` (UJ-6 étapes 4 et 6, colonne gauche de la web app) ; story 8.8.
- *Constat :* la story 8.8 synchronise les courses suivies, mais aucune story ne crée l'action « suivre une course », son affichage à l'Accueil et dans la colonne gauche de la web app, ni son stockage local. Le code mobile n'a rien de tel. Aucun composant UX n'est spécifié non plus.
- *Correction :* `bmad-ux` (composant et emplacement) ; `bmad-create-epics-and-stories` (story dédiée, avant la 8.8).

**É3 — L'« appareil bloqué » qui ouvre Mes appareils suppose une session restreinte qu'aucune décision ne décrit.**
- *Emplacement :* story 8.6 (4ᵉ critère) ; `EXPERIENCE.md` (Appareil bloqué, `[ASSUMPTION]`) ; AD-16 (Devices).
- *Constat :* selon AD-16, un appareil refusé à la limite ne reçoit pas de ligne `appareil`, donc pas de session. Pourtant il doit ouvrir Mes appareils et en retirer un autre. Il faut un jeton limité : portée, durée, routes autorisées, ce qui se passe après le retrait. C'est une décision de sécurité, absente d'AD-16.
- *Correction :* `bmad-architecture` (amender AD-16) ; puis `bmad-create-epics-and-stories` (story 8.6).

**É4 — Aucun fournisseur d'email n'est choisi, et aucune question ouverte du PRD ne le mentionne.**
- *Emplacement :* stories 8.4, 8.5, 9.7 et 9.11 ; AD-16 (`email_client.py`) ; PRD §11 (OQ 13 à 18 ne citent que l'OTP et l'agrégateur).
- *Constat :* `email_client.py` sert à vérifier l'email, à récupérer le compte, à alerter sur un changement de numéro, au rapprochement et à la parade contre le vol de carte SIM. Le fournisseur (délivrabilité au Cameroun, coût, domaine d'envoi, SPF et DKIM) n'est décidé nulle part, et les stories qui en dépendent ne sont pas marquées comme bloquées.
- *Correction :* `bmad-prd` (ajouter une question ouverte) ; `bmad-deep-recon` (choix du fournisseur).

**É5 — Les bloqueurs externes sont cités au fil du texte, mais aucune story n'est marquée « bloquée » ni n'a de définition de terminé partielle.**
- *Emplacement :*
  - story 8.1 (OQ 17) ;
  - story 9.5 (OQ 15 et OQ 18) ;
  - stories 9.4 et 9.6 (OQ 13) ;
  - stories 8.3, 8.5, 8.6 et 9.9 (OQ 14) ;
  - story 7.7 (compte développeur Google Play, §9.2) ;
  - `sprint-status.yaml`.
- *Constat :* aucune story ne dit ce qui est livrable avec un faux client, ni ce qui reste bloqué jusqu'à la décision. Le suivi de sprint ne peut donc pas distinguer « terminé » de « terminé sauf intégration ». Le cas le plus lourd est l'OQ 18 : les règles de paiement de Google Play sur la vente d'un accès numérique hors de la facturation Play peuvent invalider le parcours de paiement dans l'app de la story 9.5. Or cette question n'est qu'une note de la story 7.7, sans barrière explicite avant la story 9.5.
- *Correction :* `bmad-create-epics-and-stories` (ajouter « Bloqué par / Livrable sans » à chaque story concernée et une barrière OQ 18 avant la 9.5) ; `bmad-sprint-planning` (statut « bloqué ») ; `bmad-deep-recon` (OQ 18, OQ 15, OQ 17).

**É6 — Aucune décision ne fixe les domaines ni les hôtes, alors que trois stories en dépendent.**
- *Emplacement :* stories 7.3, 7.6, 8.2 et 10.1 ; AD-16 (cookie `SameSite=Strict`) ; AD-21.
- *Constat :* trois hôtes sont nécessaires (API, web app, back-office), et aucun domaine n'est acheté ni nommé. Cette tâche humaine ne figure nulle part. Le choix n'est pas qu'administratif : un cookie `SameSite=Strict` n'est envoyé par `fetch` que si la web app et l'API sont sur le même site (même domaine enregistrable). Des domaines distincts cassent le renouvellement de session web de la story 8.2.
- *Correction :* `bmad-architecture` (topologie d'hôtes dans AD-21 et AD-16) ; tâche humaine du porteur de projet (achat et DNS).

### Moyen

| # | Constat | Emplacement | Skill |
|---|---|---|---|
| M1 | Les schémas PostgreSQL `courses` et `comptes` n'ont pas d'équivalent décrit pour la base de test SQLite, que la 7.2 exige (`schema_translate_map` ou `ATTACH` ? `include_schemas` dans Alembic ?). Le diagramme de la spine nomme aussi le schéma `races`, la story `courses`. | 7.2 ; AD-19 ; diagramme de la spine | `bmad-architecture` |
| M2 | Rien ne fixe l'outil de chiffrement des sauvegardes, la garde de la clé, la destination hors hôte, ni la destination du « journal hors de l'hôte » de la tête d'audit. | 7.2 (6ᵉ critère) ; 10.4 (4ᵉ critère) ; AD-19 ; AD-20 | `bmad-architecture` + tâche humaine |
| M3 | Trois choix de sécurité restent ouverts : le format et la signature du jeton d'accès (JWT ? algorithme ? clé ?), la génération de l'« identifiant local de l'appareil » (sur lequel repose la preuve de la 9.3), et le rôle du code PIN (simple barrière comparée à une empreinte, ou clé qui chiffre les jetons). | 8.2 ; 8.3 ; 9.3 ; AD-16 | `bmad-architecture` |
| M4 | Rien ne dit comment la web app apprend l'approbation du téléphone et reçoit son cookie (interrogation d'un statut ? durée ? route ?). | 8.7 ; AD-16 | `bmad-architecture` puis `bmad-create-epics-and-stories` |
| M5 | Récupération de compte : rien ne dit quel identifiant l'utilisateur saisit pour désigner son compte, ni ce qui se passe si le nouveau numéro a déjà un compte. `otp_client` sert aussi à des SMS d'alerte (8.5, 8.6), ce qu'un fournisseur limité à l'OTP peut ne pas offrir. | 8.5 ; 8.6 ; AD-16 | `bmad-create-epics-and-stories` + `bmad-architecture` |
| M6 | Le schéma et les droits de `personnel`, `licence_manuelle`, `journal_audit`, du compteur de débit (7.4) et du compteur de quota (9.9) ne sont pas fixés. Le test de la 10.6 (« sur `comptes`, aucune autre écriture ») contredit l'insertion dans `journal_audit` si cette table est dans `comptes`. Les `[ASSUMPTION]` de la 10.5 et de la 10.6 (« la matrice d'AD-19 ne prévoit pas cet accès ») sont périmés : AD-19 accorde désormais l'insertion dans `droit`, les colonnes de révocation et `offre`. | 10.1 ; 10.4 à 10.6 ; 7.4 ; 9.9 ; AD-19 | `bmad-architecture` + `bmad-create-epics-and-stories` |
| M7 | `CGU_VERSION`, dont la 8.1 a besoin, est exposée par la 7.7, une story de publication en partie bloquée par Google et par l'avis juridique. Il faut l'extraire dans une petite story ou une tâche indépendante. | 7.7 (2ᵉ critère) ; 8.1 (4ᵉ critère) | `bmad-create-epics-and-stories` |
| M8 | La 7.8 attend la vérification du VPS, alors qu'elle n'en dépend pas (pare-feu ou mot de passe de proxy). Aujourd'hui, l'API est publique, sert les pronostics sans authentification et accepte des écritures anonymes (vérifié). La 7.8 doit démarrer sans attendre. | Epic 7 (Ordre) ; 7.1 (1er critère) ; 7.8 | `bmad-correct-course` |
| M9 | L'ordre de l'Epic 11 est incomplet : le `teaser-banner` de la 11.3 ouvre Offres (9.4), la 11.2 suppose les sessions de l'Epic 8, et la 11.5 suppose les stories 5.14, 5.15, 5.20 et 6.7. « Après les stories 9.1 à 9.3 » ne suffit pas. | En-tête de l'Epic 11 ; 11.3 ; 11.5 | `bmad-sprint-planning` |
| M10 | Des arbitrages attendent la confirmation du porteur de projet. Dans le PRD : la matrice de FR-39, qui alimente directement `acces_paliers.json` (9.2), FR-43 et FR-46. Dans les stories : `[ASSUMPTION]` des stories 7.6, 8.2, 9.11, 10.5, 10.6, 11.2 et 11.5. Il faut les confirmer en un seul lot avant les stories 9.2 et 11.2. | PRD §4.13 et §12 ; stories citées | `bmad-correct-course` (revue par le porteur de projet) |
| M11 | La surcouche `correction_saisie` est générique (entité, champ), sans liste des entités et champs corrigeables, sans typage, et sans écran de saisie (« découpés à part »). La 10.3 ne se vérifie que par l'API. | 10.3 ; AD-10 | `bmad-create-epics-and-stories` |

### Faible

| # | Constat | Emplacement | Skill |
|---|---|---|---|
| F1 | La liste des `Repository()` instanciés à l'import oublie `routes_dashboard.py`, `routes_pronostics.py`, `jobs/predict.py` et `jobs/rebuild_historique.py` (vérifié dans le code). Le correctif au constructeur les couvre, mais le test ne les liste pas. | 7.1 (dernier critère) | `bmad-create-epics-and-stories` |
| F2 | La 7.6 écrit « Web : pas de mode hors ligne », alors que `EXPERIENCE.md` écrit « Web : connexion requise — l'app Android fonctionne hors ligne ». | 7.6 ; EXPERIENCE (Responsive & Platform) | `bmad-create-epics-and-stories` |
| F3 | Le tableau de couverture d'UX-DR24 oublie la 8.8 (pronostic « non synchronisé »). | Tableau de couverture | `bmad-create-epics-and-stories` |
| F4 | Plusieurs valeurs n'ont ni propriétaire ni question ouverte : `WEB_APPAREIL_INACTIF_JOURS`, `NOUVEL_APPAREIL_DELAI_HEURES`, seuils de débit, période du quota photo. | 7.4 ; 8.6 ; 9.9 ; 9.11 | `bmad-prd` (étendre OQ 14) |
| F5 | Une empreinte sha256 d'un code OTP à 6 chiffres se casse hors ligne. Il faut préciser un HMAC à clé serveur. | 8.1 ; NFR-14 | `bmad-architecture` |
| F6 | Le webhook de l'agrégateur, y compris en bac à sable, reste injoignable tant que la restriction de la 7.8 tient. Il faut prévoir une exception filtrée par IP. | 7.8 ; 9.5 | `bmad-create-epics-and-stories` |
| F7 | Caddy n'a pas de limitation de débit native (module tiers, image sur mesure), contrairement à Traefik. `--forwarded-allow-ips` exige une IP fixe du proxy dans le réseau Docker. | 7.3 | `bmad-architecture` |
| F8 | Le fuseau de `PRONOSTICS_HEURE` et de « l'heure de publication du matin » montrée au palier Gratuit n'est pas fixé (utilisateurs au Cameroun, courses à Paris). | 11.1 ; 11.3 | `bmad-create-epics-and-stories` |
| F9 | La 10.4 doit journaliser des événements émis par des stories antérieures (Epics 8 et 9) et postérieures (10.6, offres) sans dire qui instrumente quoi. | 10.4 (3ᵉ critère) | `bmad-create-epics-and-stories` |
| F10 | Le référentiel d'AD-14 (cotes H-30 ou cotes de clôture) reste ouvert. Il ne touche que la gate B : `en_evaluation` reste vrai. Ce n'est pas un blocage, juste un point à noter. | AD-14 ; Deferred | Décision du porteur de projet |

**Décompte :** 2 critiques, 6 élevés, 11 moyens, 10 faibles.

## Bloqueurs externes : stories bloquées et marquage

| Bloqueur | Stories bloquées (intégration réelle ou mise en vente) | Marqué « bloqué » ? |
|---|---|---|
| Vérification du VPS (SSE2) | 7.2, 7.3 (et 7.8 selon l'ordre écrit, à tort : M8) | **Oui**, première tâche de 7.1, avec arrêt explicite |
| OQ 17, fournisseur OTP | 8.1 (envoi réel), 8.5 et 8.6 (SMS d'alerte), 7.5 (motifs de clé) | Non : cité en ligne, faux client prévu |
| Fournisseur d'email (sans OQ) | 8.4, 8.5, 9.7, 9.11 | **Non**, et absent du PRD (É4) |
| OQ 15, agrégateur | 9.5 (et 9.6, 9.7 en aval), 7.5 (motifs) | Non : cité en ligne, faux agrégateur prévu |
| OQ 18, règles Google Play | 7.7 (diffusion), **9.5 (parcours de paiement dans l'app)** | Non : simple note de la 7.7 (É5) |
| OQ 13, prix, places du Duo, matrice | 9.4 (amorce), 9.6 (places), 9.2 (matrice à confirmer) | Non : valeurs « de configuration » |
| OQ 14, limites et délais | 8.3, 8.5, 8.6, 9.9 | Non : valeurs « de configuration » ; la story reste réalisable avec une valeur provisoire |
| §9.2, avis juridique | 7.7 (textes définitifs, diffusion publique), mise en vente (9.5 en production) | **Oui** pour la 7.7 (version provisoire acceptée) ; implicite pour la mise en vente (en-tête de l'Epic 9) |
| Domaines et DNS (non listé) | 7.3, 7.6, 8.2 (cookie web), 10.1 | **Non** (É6) |
| Compte développeur Google Play | 7.7 | Non : implicite |

## Ordre de démarrage recommandé

### Démarrables maintenant, sans aucune décision externe

1. **Story 7.1, première tâche** : vérifier PostgreSQL, son pilote et le proxy sur le VPS. Tâche humaine, avec accès au VPS.
2. **Story 7.8**, en parallèle et sans attendre la tâche 1 (M8). Le porteur de projet choisit entre liste d'adresses et mot de passe de proxy ; c'est sa décision, pas un bloqueur externe.
3. **Story 7.1, suite** : Alembic sur SQLite, baseline, script de démarrage, refus de migrer dans les autres services.
4. **Story 7.5** : script de contrôle des secrets. Les motifs de l'agrégateur et du fournisseur OTP s'ajouteront à leur choix.
5. **Story 11.4, partie moteur seulement** : la fonction pure `renormaliser_sans_non_partants`, en Python et en Dart, et ses cas dans `engine_cases.json`. Elle ne dépend de rien.

### Ensuite, sans décision externe mais après correction de la planification

6. **7.2**, après le feu vert du VPS et la correction de C2 (et de M1 et M2).
7. **7.3**, après É6 (domaines), puis **7.4**.
8. **7.6**, après 7.3 et É6.
9. **8.2, 8.3, 8.7**, après la 8.1 côté serveur avec un faux OTP. La 8.1 elle-même attend 7.2, 7.4 et l'exposition de `CGU_VERSION` (M7) ; l'envoi réel attend l'OQ 17.
10. **8.6**, après É3 ; **8.8**, après É2.
11. **9.1, puis 9.2** (après confirmation de la matrice, M10), **9.3, 9.8, 9.10**.
12. **11.1**, après É1, puis **11.2** (après confirmation du sort de `POST /pronostics`), **11.3** (après 9.4), puis **11.4** (partie écran) et **11.5** (après les stories 5.14, 5.15, 5.20 et 6.7).

### Bloquées par une décision externe ou de planification

- 8.4, 8.5, 9.7, 9.11 : fournisseur d'email (É4).
- 9.4 et 9.6 : OQ 13 (développement possible avec des valeurs provisoires).
- 9.5 : OQ 15 et **OQ 18**.
- 9.9 : OQ 14 (valeur provisoire possible).
- 7.7 : Google Play, §9.2 et OQ 18.
- Tout l'Epic 10 : C1.

## Actions prioritaires

1. **`bmad-architecture`** (mise à jour) : C1, C2, É1 (rôles par service), É3, É6, puis M1 à M4, M6, F5 et F7.
2. **`bmad-prd`** (mise à jour) : ajouter la question ouverte du fournisseur d'email (É4) et étendre l'OQ 14 (F4).
3. **`bmad-ux`** : surfaces minimales du back-office (C1) et composant « course suivie » (É2).
4. **`bmad-create-epics-and-stories`** : nouvelle story « course suivie », révision Alembic de la 11.1, marquage « Bloqué par / Livrable sans » (É5), extraction de `CGU_VERSION` (M7), M5, M11, F1 à F3, F6, F8 et F9.
5. **`bmad-correct-course`** : 7.8 démarrée tout de suite (M8) et lot de confirmations du porteur de projet (M10).
6. **`bmad-deep-recon`** : OQ 18 (règles de paiement de Google Play) avant la 9.5, puis OQ 15, OQ 17 et le fournisseur d'email.
7. **`bmad-sprint-planning`** : statut « bloqué » et ordre complet de l'Epic 11 (M9).
