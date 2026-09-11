---
stepsCompleted: [1, 2]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-prediction-hyppique-2026-08-22/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md
  - docs/cahier_des_charges_backend_hippique.md
  - docs/cahier_des_charges_app_mobile.md
  - _bmad-output/planning-artifacts/briefs/brief-prediction-hyppique-2026-08-17/brief.md
---

# prediction-hyppique - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for prediction-hyppique, decomposing the requirements from the PRD and the Architecture Spine into implementable stories. No formal UX design contract exists — the mobile screens are already specified in detail in `docs/cahier_des_charges_app_mobile.md` §7, treated here as the UX reference.

## Requirements Inventory

### Functional Requirements

FR-1: Consultation du programme du jour (liste réunions/courses, préremplie depuis le backend, cache local prioritaire, rafraîchissement explicite).
FR-2: Configuration manuelle ou préremplie de la course cible (hippodrome, distance, terrain, niveau, partants) — échelles terrain gazon/PSF jamais mélangées ; niveau cible effectivement utilisé dans le calcul de `c_niv`.
FR-3: Import à la demande d'une course non encore en base (`POST /courses/{id}/importer`), avec repli propre vers saisie manuelle/import photo en cas d'échec.
FR-4: Liste des partants avec indicateurs de transparence explicites ("Historique court", "Données non saisies", "🐎 Inédit") — inédit vs historique non saisi jamais confondus.
FR-5: Fiche cheval éditable — terrain "inconnu" explicite (`NULL`, neutre dans le calcul), cote/poids/âge présents dès la création du modèle, compteur de performances à terrain inconnu visible.
FR-6: Ajout et suppression manuelle d'un cheval — retirer un cheval invalide tout résultat déjà affiché (recalcul obligatoire).
FR-7: Calcul du score par cheval (forme pondérée par récence, ajustements distance/terrain/niveau/poids/âge, lissage bayésien) — récence pondère le plus fort C1 ; incident = malus différencié par type ; NR exclu du calcul et du compte de performances.
FR-8: Calcul des probabilités Plackett-Luce et des probabilités de place Harville (Top1-4) — invariants de sommation respectés ; partants non saisis modélisés en outsiders virtuels ; même format de sortie que la course vienne de la base ou de la saisie directe.
FR-9: Calcul de la value par cheval (`probabilité × cote − 1`) — jamais un seuil de score déguisé ; "Cote manquante" explicite si absente ; cote toujours portée par l'identité du cheval, jamais indexée sur le rang trié.
FR-10: Mise suggérée par Kelly fractionné (bankroll et fraction réglables) — mise nulle masquée (pas un 0 trompeur) si Kelly négatif ou cote manquante ; réglages persistés.
FR-11: Combinaisons à ordre et désordre (couplé, tiercé, quarté, quinté) — énumération exacte, dossards toujours affichés.
FR-12: Combinaisons "parmi les k premiers" (couplé placé dès 8 partants, 2 sur 4 dès 14) — estimation Monte-Carlo (≥20 000 tirages) avec marge d'erreur communiquée.
FR-13: Calcul entièrement local sur l'appareil une fois les données en cache — aucun appel réseau au changement de paramètre.
FR-14: Cache local des courses consultées (SQLite) — persistant jusqu'à suppression/rafraîchissement explicite, jamais de rafraîchissement automatique en arrière-plan.
FR-15: Échec propre des fonctionnalités réseau-dépendantes (import photo, cotes en direct) — message clair, reste de l'app utilisable.
FR-16: Ingestion quotidienne du programme/partants/historique PMU — accès isolé dans `pmu_client.py` (aucun autre module ne lit un champ JSON brut PMU), fréquence raisonnable, programme du lendemain récupéré quand disponible.
FR-17: Finalisation différée des résultats (le lendemain ou délai configurable) — jamais d'écrasement silencieux d'une correction ultérieure.
FR-18: Extraction d'une fiche cheval par photo/PDF — appel vision exclusivement backend (`/extraction/fiche`), champs "à vérifier" jamais appliqués sans validation utilisateur, PDF accepté au même titre que l'image, numéro de dossard en tête de fiche signalé comme plausible mais à vérifier.
FR-19: Extraction d'un programme complet par photo/PDF (`/extraction/programme`) — même traitement "à vérifier" que FR-18 ; les deux prompts déjà rédigés dans `analyse_hippique_ia.jsx` repris tels quels.
FR-20: Réglages du moteur exposés et persistés (récence, k, sensibilité poids, âges min/max, lissage, coef. inédit, malus incident, bankroll, fraction Kelly) — réinitialisation aux valeurs par défaut en un geste.
FR-21: Export/partage du classement calculé (texte ou JSON minimum, PDF en bonus) — sans dépendance réseau.

### NonFunctional Requirements

NFR-1: Parité fonctionnelle backend/mobile — résultats identiques à epsilon près entre Python et Dart, vérifiée par les mêmes cas de test portés dans les deux langages (cahier backend §9, cahier mobile §5.2/§9 ; mécanisme fixé par l'Architecture AD-2 : fixtures JSON partagées, avec carve-out explicite pour les paris Monte-Carlo — non reproductibles bit-à-bit entre `numpy` et `dart:math`).
NFR-2: Performance du calcul local perçue comme instantanée (recalcul complet, y compris la simulation Monte-Carlo à 20 000 tirages) — seuil chiffré non fixé (Open Question PRD §11.1).
NFR-3: Disponibilité du calcul hors ligne non négociable une fois les données d'une course en cache.
NFR-4: Reproductibilité — classement identique (à epsilon près) au prototype `analyse_hippique_v2.html` sur le même jeu d'entrée.
NFR-5: Aucune clé API tierce embarquée côté client, pour toute intégration présente ou future (vision IA aujourd'hui) — appliqué structurellement par l'Architecture AD-3 (vision_client.py isolé côté backend uniquement).
NFR-6 (feature-specific, FR-19): Les deux prompts d'extraction (fiche unique, programme complet) déjà rédigés et validés dans `analyse_hippique_ia.jsx` sont repris tels quels, jamais réécrits.

### Additional Requirements

*Issues de l'Architecture Spine (`ARCHITECTURE-SPINE.md`) :*

- Paradigme hexagonal déjà en place (AD-1) : `engine/` (Python et Dart) ne dépend jamais de `data/`, `api/`, ni d'aucune lib réseau/HTTP ; `data/*_client.py` sont les seuls modules à connaître leur format externe.
- Parité moteur backend/mobile appliquée par fixtures JSON partagées à la racine du dépôt (AD-2) : `fixtures/engine_cases.json` (cas de test + paramètres par défaut canoniques) et `fixtures/engine_constants.json` (tables terrain/niveau/incidents/récence) — chargées par les deux suites de tests et les deux objets de paramètres par défaut, jamais dupliquées à la main. Carve-out explicite : les paris Monte-Carlo ne sont comparés qu'en tolérance statistique, jamais en égalité exacte entre langages.
- `vision_client.py` (à créer) isolé comme seul module connaissant le format Anthropic Claude, avec un compteur d'appels journalier configurable (`VISION_DAILY_CALL_LIMIT`) qui bloque et log plutôt que de continuer silencieusement (AD-3). Fournisseur choisi en session, jamais sourcé du PRD/cahiers — modèle exact à revérifier avant implémentation.
- Réponses API toujours construites depuis leur schéma Pydantic déclaré, jamais un `.__dict__` brut (AD-4) — **corrige une violation déjà présente** dans `routes_analyse.py` (`/analyse` actuel), à corriger dans la story qui touche cet endpoint.
- `terrain`/`niveau` voyagent en labels français canoniques (jamais des floats pré-résolus), résolus au point d'usage via une table miroir de chaque côté ; un label non reconnu doit être un signal distinct (loggé), jamais confondu avec une valeur réellement absente (AD-5) — `niveauCoefficient()` manque actuellement côté mobile.
- Déploiement : 2 services self-hosted (`api`, `ingestion`) partageant un volume SQLite, déjà fixé par `docker-compose.yml` — aucun CI/CD, pas d'environnement de staging, pas de distribution store mobile à ce stade (différé, rythme bootstrap).
- Différé explicitement (ne pas construire dans ces epics) : valeur exacte de `VISION_DAILY_CALL_LIMIT`, calibration par quantiles du niveau depuis l'allocation, désambiguïsation des homonymes de chevaux, toute architecture compte/paiement/multi-utilisateur.

*Issues de `deferred-work.md` (dette connue, non liée à cette planification mais à corriger dans les epics concernés) :*

- `routes_analyse.py` : bug des outsiders virtuels dans `/analyse` déjà corrigé (résolu, pour mémoire).
- `combinatoire.py` : couverture de tests déjà ajoutée (résolu, pour mémoire).
- `analyse_course`'s `params` dict sans validation de clés (mistype silencieusement ignoré, valeurs hostiles non validées) — à traiter si une story touche la validation d'entrée API.

### UX Design Requirements

Aucun contrat UX formel (bmad-ux) produit. Référence de substitution : `docs/cahier_des_charges_app_mobile.md` §7 (parcours écran par écran : accueil, configuration course, liste partants, fiche cheval, import photo, résultats, réglages) et le prototype `analyse_hippique_v2.html`/`analyse_hippique_ia.jsx` pour le rendu concret des résultats et combinaisons.

### FR Coverage Map

FR-1: Epic 2 (disponibilité backend) + Epic 3 (consultation mobile) — programme du jour.
FR-2: Epic 3 — configuration de la course cible.
FR-3: Epic 2 — import à la demande d'une course non en base.
FR-4: Epic 3 — liste des partants avec indicateurs de transparence.
FR-5: Epic 3 — fiche cheval éditable.
FR-6: Epic 3 — ajout/suppression manuelle d'un cheval.
FR-7: Epic 1 (moteur backend) + Epic 3 (port Dart) — calcul du score.
FR-8: Epic 1 + Epic 3 — probabilités Plackett-Luce/Harville.
FR-9: Epic 1 + Epic 3 — value par cheval.
FR-10: Epic 1 + Epic 3 — mise Kelly fractionné.
FR-11: Epic 1 + Epic 3 — combinaisons ordre/désordre.
FR-12: Epic 1 + Epic 3 — combinaisons Monte-Carlo.
FR-13: Epic 3 — calcul entièrement local.
FR-14: Epic 3 — cache local SQLite.
FR-15: Epic 3 (mobile) + Epic 4 (import photo/cotes en direct) — échec réseau propre.
FR-16: Epic 2 — ingestion quotidienne PMU.
FR-17: Epic 2 — finalisation différée des résultats.
FR-18: Epic 4 — extraction fiche cheval par photo/PDF.
FR-19: Epic 4 — extraction programme complet par photo/PDF.
FR-20: Epic 3 — réglages du moteur.
FR-21: Epic 3 — export/partage du classement.

## Epic List

### Epic 1: Analyser une course — moteur et API
Étant donné une course cible et un lot de chevaux, produire score, probabilités (Plackett-Luce/Harville), value, mise suggérée (Kelly) et combinaisons de paris classées — consommable via l'API backend.
**FRs couvertes:** FR-7, FR-8, FR-9, FR-10, FR-11, FR-12
**Notes d'implémentation:** Moteur (`scoring.py`, `combinatoire.py`) et endpoint `/analyse` déjà construits et testés (53 tests backend passants). Stories restantes : fixtures de parité partagées (AD-2, `fixtures/engine_cases.json` + `engine_constants.json`), réponse API typée via `HorseOut` (AD-4 — corrige une violation déjà présente dans `routes_analyse.py`), validation des clés de `params` (dette connue, `deferred-work.md`).

### Epic 2: Alimenter la base sans saisie manuelle — ingestion PMU
Le programme du jour, les partants et leur historique de performances sont disponibles en base sans que l'utilisateur les saisisse, avec finalisation différée des résultats pour absorber une disqualification tardive.
**FRs couvertes:** FR-1 (moitié backend), FR-3, FR-16, FR-17
**Notes d'implémentation:** `pmu_client.py`, `open_pmu_client.py`, `repository.py`, `jobs/ingest_daily.py`, `jobs/backfill_historique.py` déjà construits et intacts. Stories restantes : couverture de tests manquante sur ces modules (aucun test aujourd'hui sur `repository.py`, `ingest_daily.py`, `backfill_historique.py`).

### Epic 3: Consulter et analyser une course sur mobile, hors-ligne y compris
Depuis son téléphone, l'utilisateur consulte le programme, configure et ajuste une course, voit le classement/probabilités/value/mise/combinaisons, et peut recalculer sans réseau une fois la course en cache — y compris depuis les tribunes d'un hippodrome.
**FRs couvertes:** FR-1 (moitié mobile), FR-2, FR-4, FR-5, FR-6, FR-7 à FR-12 (port Dart du moteur), FR-13, FR-14, FR-20, FR-21
**Notes d'implémentation:** Quasiment rien de fonctionnel n'existe encore côté mobile (moteur Dart et 2 écrans corrompus, reste de l'app non vérifié). Regroupé en un seul epic large plutôt que fragmenté : l'app n'a de valeur que si config + moteur + résultats + hors-ligne fonctionnent ensemble, et les deux prototypes (`analyse_hippique_v2.html`, `analyse_hippique_ia.jsx`) ont déjà validé cette UX numériquement — peu de risque de direction entre stories. S'appuie sur les fixtures de parité de l'Epic 1 (AD-2) et les données de l'Epic 2, mais reste utilisable en saisie 100% manuelle sans eux.

### Epic 4: Importer une fiche ou un programme par photo
Quand une course n'est pas couverte par l'ingestion automatisée (réunion étrangère, historique ancien, source indisponible), l'utilisateur importe une photo ou un PDF et les champs se préremplissent, marqués "à vérifier".
**FRs couvertes:** FR-18, FR-19
**Notes d'implémentation:** Regroupe volontairement le backend (`vision_client.py` à créer, `/extraction/fiche`, `/extraction/programme`) et le mobile (écran d'import photo) — une seule capacité utilisateur, pas un découpage par couche. Risque distinct et réel : première intégration à un fournisseur externe payant (Anthropic Claude, choisi en session), avec garde-fou de coût à construire (AD-3, `VISION_DAILY_CALL_LIMIT`).
