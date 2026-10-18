---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-prediction-hyppique-2026-08-22/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md
  - docs/cahier_des_charges_backend_hippique.md
  - docs/cahier_des_charges_app_mobile.md
  - _bmad-output/planning-artifacts/briefs/brief-prediction-hyppique-2026-08-17/brief.md
  - docs/cahier_des_charges_module_multi.md
  - _bmad-output/planning-artifacts/multi/reconcile-cdc-multi-prd.md
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md
  - _bmad-output/implementation-artifacts/deferred-work.md
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

*Module Multi (PRD §4.11, finalisé le 2026-10-18 — pronostic sans aucune notion d'argent) :*

FR-22: Éligibilité d'une course au Multi (course support, ≥ 14 partants déclarés) ; raison affichée si non éligible ; mode « exploration » si le marqueur course support est introuvable ; règles du pari en source unique datée (sans date de vérification, aucune grille) ; partants non analysés signalés et non sélectionnables.
FR-23: Pronostic du modèle pour la taille choisie par l'utilisateur (4 à 20, défaut : dernière taille sinon 10) — sélection qui maximise la probabilité de couverture ; aucun budget/mise/montant ; mention « modèle en cours d'évaluation » ; identique backend/appareil (égalités à 1e-9 départagées par règles) ; avertissement « données fragiles » ; calcul local hors ligne ; non-partant par rafraîchissement ou « marquer non-partant », avec requalification du pronostic retenu.
FR-24: 3 bases candidates « chevaux les plus probables », calculées sur la sélection sans base ; aucune active au premier affichage ; activer = imposer, désactiver = interdire ; chacune affiche probabilité estimée, tickets économisés et couverture perdue.
FR-25: Systèmes de tickets vérifiés pour chaque formule (4 à 7) : tickets, tickets physiques, garantie de couverture, grilles en dossards, sans aucun coût ; texte de garantie imposé ; catalogue ≤ document (sauf coquilles) ; vérification d'un système saisi ailleurs ; formule par défaut Multi en 7 ; export texte des grilles.
FR-26: Indice de confiance « élevée / moyenne / faible » avec ses raisons (couverture, ouverture de la course, fragilité des données) ; jamais « jouer / passer » ni montant ; seuils par taille, réglables et persistés, « provisoires » jusqu'au pilote ; aucune donnée de presse.
FR-27: Explications en codes + valeurs (jamais de phrases figées) : chaque cheval retenu (probabilité estimée, transparence, contribution), les 3 écartés les plus proches, bases, systèmes, indice ; limites des données dites ; probabilités présentées comme estimations ; pas de badge de value dans le Multi.
FR-28: Choix de l'utilisateur : taille, retirer/ajouter un cheval analysé, imposer, marquer non-partant, saisir sa propre sélection (évaluée, échanges suggérés) ; sélection « modifiée » ; coût d'une imposition en couverture ; « Je retiens ce pronostic » (un par course, remplaçable jusqu'au départ puis figé, seule source du débrief).
FR-29: Comparateurs à part et à taille égale (méthode 1 du document source, marché) avec « hypothèse non validée » ; performances seulement au-delà d'un effectif minimal, avec effectif et intervalle ; marché non calculé si une cote manque ; tirage au hasard journalisé seulement ; jamais par défaut.
FR-30: Évaluation (probabilité de couverture, distribution des chevaux capturés, aucun rapport) ; journalisation quotidienne avant départ aux tailles de référence, immuable, échecs journalisés ; backtest sans fuite (constantes figées et datées) ; pronostic retenu conservé 90 jours sur l'appareil ; débrief « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non » pour le pronostic retenu et celui du modèle, ex-aequo/arrivée dégradée/corrections gérés.

### NonFunctional Requirements

NFR-1: Parité fonctionnelle backend/mobile — résultats identiques à epsilon près entre Python et Dart, vérifiée par les mêmes cas de test portés dans les deux langages (cahier backend §9, cahier mobile §5.2/§9 ; mécanisme fixé par l'Architecture AD-2 : fixtures JSON partagées, avec carve-out explicite pour les paris Monte-Carlo — non reproductibles bit-à-bit entre `numpy` et `dart:math`).
NFR-2: Performance du calcul local perçue comme instantanée (recalcul complet, y compris la simulation Monte-Carlo à 20 000 tirages) — seuil chiffré non fixé (Open Question PRD §11.1).
NFR-3: Disponibilité du calcul hors ligne non négociable une fois les données d'une course en cache.
NFR-4: Reproductibilité — classement identique (à epsilon près) au prototype `analyse_hippique_v2.html` sur le même jeu d'entrée.
NFR-5: Aucune clé API tierce embarquée côté client, pour toute intégration présente ou future (vision IA aujourd'hui) — appliqué structurellement par l'Architecture AD-3 (vision_client.py isolé côté backend uniquement).
NFR-6 (feature-specific, FR-19): Les deux prompts d'extraction (fiche unique, programme complet) déjà rédigés et validés dans `analyse_hippique_ia.jsx` sont repris tels quels, jamais réécrits.
NFR-7 (Multi): Mentions obligatoires sur l'écran Multi — « L'outil ne place aucun pari », « Couverture garantie — pas un gain garanti », rappel de jeu responsable.
NFR-8 (Multi): Aucun montant en euros (mise, coût, gain, rapport, seuil de rentabilité) sur l'écran Multi ni dans l'export de ses grilles.
NFR-9 (Multi): Parité backend/mobile des fonctions Multi (règles, couverture, sélection, indice de confiance, vérification) par cas de test partagés.
NFR-10: Performance du calcul local perçue comme instantanée, y compris le pronostic Multi (sélection, bases, systèmes, indice) — seuil non chiffré (PRD §11 OQ1).
NFR-11: Préparation multilingue — MVP en français ; les textes produits par le moteur Multi sont des codes + valeurs rendus par l'app, pour ajouter l'anglais après le MVP sans reprendre le moteur.

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

*Module Multi — issues de l'Architecture Spine (AD-6 à AD-13, mise à jour 2026-10-17/18) et du cahier Multi v3 :*

- **Prérequis bloquant (PRD §9.5)** : vérifier les règles du pari Multi sur pmu.fr et les dater dans `fixtures/multi_regles.json` avant toute story de développement Multi.
- AD-6 : `engine/multi/` (Python) et `mobile/lib/engine/multi/` (Dart) consomment la sortie du moteur de scoring + un « contexte Multi » de course fourni par le backend et mis en cache ; le téléphone calcule toujours localement et n'appelle jamais `/multi/recommandation` ; comparaisons quantifiées à 1e-9 ; plafond d'itérations partagé ; B0 en Python seulement ; décodeur de musique dans la couche data ; cas partagés `fixtures/multi_cases.json`.
- AD-7 : générateur de systèmes hors ligne (`scripts/generer_catalogue_multi.py`, PEP 723, `uv`, `scipy==1.18.1` épinglé) → catalogue de référence `fixtures/multi_catalogue.json` (en-tête versionné) + copies identiques octet à octet dans `backend/app/engine/multi/` et `mobile/assets/` ; relabellement canonique indices → dossards ; revérification avant affichage ; aucune génération à l'exécution ; règles dans `fixtures/multi_regles.json` avec date de vérification obligatoire.
- AD-8 : registre `fixtures/multi_codes.json` (codes + paramètres) ; tests : moteurs n'émettent que des codes déclarés, l'app a un libellé pour chacun ; table Dart code → phrase française pour le MVP.
- AD-9 : `hippique_cache.db` passe en version 2 (`pronostic_retenu`, `recommandation_consultee`) : `onCreate` v2 direct + `onUpgrade` 1→2, les deux testés ; figé au départ (UTC) ; purge > 90 jours au démarrage ; dernière taille et seuils dans `shared_preferences`.
- AD-10 : tables serveur françaises via `repository.py`, un seul écrivain par table (`multi_course` éligibilité + arrivée, `recommandation_multi` immuable unique par taille de référence, `echec_journal_multi`, `resultat_recommandation`, `performance_strategie`) ; journalisation quotidienne dans le conteneur `ingestion`, après le pilote.
- AD-11 : harnais de backtest/pilote dans `backend/app/jobs/`, configuré par `DATABASE_URL`, d'abord sur la machine de dev (copie de la base) avec export puis import des résultats en production ; `fixtures/multi_parametres_pilote.json` (seuils de confiance par taille, tailles de référence, effectif minimal, drapeau provisoire) ; `/multi/backtest` seulement au passage sur serveur.
- AD-12 : course identifiée par sa clé PMU (date, réunion, course) ; identité de pronostic (clé de course, versions moteur/catalogue/règles, empreinte des paramètres, heure des données) via `fixtures/multi_versions.json` ; toutes les heures en UTC ISO-8601 avec décalage.
- AD-13 : migrations du schéma serveur par Alembic 1.20.0 (`backend/alembic/`), baseline tamponnée sur la base de prod, `upgrade head` au démarrage du service `api` uniquement, plus de `create_all` sur une vraie base, test de concordance modèles/migrations.
- Dette liée (deferred-work.md) : `pmu_client._epoch_ms_to_datetime` produit des heures naïves (fuseau du conteneur) — à corriger avant le gel au départ, la journalisation « avant départ » et le backtest du Multi.
- Différé (spine) : taille du catalogue à mesurer, outillage de traduction Flutter (après MVP), backtest sur serveur, exploitation des jobs Multi et sauvegarde SQLite, environnement de test local aligné sur la prod (Python 3.12 / NumPy 1.26.4).

### UX Design Requirements

Aucun contrat UX formel (bmad-ux) produit. Référence de substitution : `docs/cahier_des_charges_app_mobile.md` §7 (parcours écran par écran : accueil, configuration course, liste partants, fiche cheval, import photo, résultats, réglages) et le prototype `analyse_hippique_v2.html`/`analyse_hippique_ia.jsx` pour le rendu concret des résultats et combinaisons.

*Module Multi — contrat UX `DESIGN.md` + `EXPERIENCE.md` (final 2026-10-18), maquette `mockups/multi.html` :*

UX-DR1: Accès au Multi — CTA « Multi » en tête de Résultats pour une course éligible ; `multi-badge` sur la carte de la course support à l'Accueil (ouverture directe si le classement est à jour, sinon Liste des partants) ; badge « Multi indisponible » expliqué au tap.
UX-DR2: Écran Multi en un seul défilement, dans l'ordre : en-tête + « L'outil ne place aucun pari » → `size-stepper` → `confidence-card` → sélection (`multi-row` + 3 écartés) → chevaux les plus probables (`base-chip`) → systèmes (`formula-row`, Multi en 7 par défaut) → `evaluation-block` → `other-methods-section` (repliée) → rappel de jeu responsable ; `multi-action-bar` sous la zone défilante (jamais par-dessus), masquée clavier ouvert, CTA seul au-delà de 130 % de police.
UX-DR3: `size-stepper` 4–20 (défaut dernière taille sinon 10), recalcul après ~800 ms de pause, une seule annonce TalkBack polie si le niveau de confiance change ; bornes désactivées et expliquées.
UX-DR4: `confidence-card` élevée/moyenne/faible + raisons + étiquettes « modèle en cours d'évaluation » / « seuils provisoires » ; or seulement pour « confiance élevée », toujours doublé du texte ; emojis ignorés par TalkBack.
UX-DR5: `multi-row` (dossard, nom, top 4 estimé, contribution, étiquette « Base », sans badge de value) → `multi-actions-sheet` (retirer, imposer, base, marquer non-partant) avec retour de focus défini ; `horse-picker-sheet` pour « + Ajouter un cheval » (non analysés grisés « à analyser ») ; étiquette « Modifiée » et 1–2 échanges suggérés.
UX-DR6: `base-chip` « chevaux les plus probables » (3, aucune active au départ) : interrupteur annoncé avec son effet, tickets économisés et couverture perdue ; vocabulaire « sûr » interdit pour un cheval.
UX-DR7: `formula-row` par formule (tickets, tickets physiques, garantie imposée, probabilité de couverture, aucun coût) + `tickets-sheet` (grilles par ticket physique, base mise en évidence par texte et pas seulement par l'or, lecture TalkBack ticket par ticket, « Copier les grilles » annoncé, invitation à retenir) + `system-entry-sheet` (vérifier un système trouvé ailleurs).
UX-DR8: `evaluation-block` (probabilité de couverture, distribution des chevaux capturés) et `other-methods-section` (méthode 1, marché, « hypothèse non validée », effectif et intervalle).
UX-DR9: « JE RETIENS CE PRONOSTIC » (`cta-primary`, seul CTA plein) → « Pronostic retenu à … » puis « 🔒 Pronostic figé au départ (15 h 05) », gel annoncé et focus géré.
UX-DR10: Section « Mes pronostics Multi » de l'Accueil (`debrief-row`) : masquée si vide, 90 jours, « En attente du résultat » → « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non » (retenu et modèle) → « Arrivée corrigée » ; ouverture du Multi en état débrief (lecture seule), sans couleur de réussite/échec.
UX-DR11: États Multi couverts par `status-banner` et la carte confiance : premier affichage, calcul en cours/erreur, classement modifié, exploration, règles non vérifiées, confiance faible, données fragiles, modèle pas meilleur que le marché, cote manquante, partants non analysés, forme absente du catalogue, non-partant (avec requalification du pronostic retenu), hors ligne.
UX-DR12: Accessibilité transverse (aussi hors Multi) : `line-card` relevée à `rgba(255,255,255,.36)` (≥ 3:1), token `on-gold`, aucune information portée par la couleur seule, cibles ≥ 48dp, chiffres jamais tronqués à 200 %.
UX-DR13: Voix du Multi : tailles en chevaux, systèmes en tickets, aucun mot ni symbole d'argent ; garantie mot pour mot « … au moins un de vos tickets les contient tous » + « Couverture garantie — pas un gain garanti » ; probabilités dites « estimées ».

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
FR-22: Epic 5 — éligibilité d'une course au Multi.
FR-23: Epic 5 — pronostic du modèle pour la taille choisie.
FR-24: Epic 5 — chevaux les plus probables (bases).
FR-25: Epic 5 — systèmes de tickets vérifiés, sans coût.
FR-26: Epic 5 (indice de confiance, seuils provisoires) + Epic 6 (seuils fixés par le pilote).
FR-27: Epic 5 — explications du pronostic.
FR-28: Epic 5 — choix de l'utilisateur et pronostic retenu.
FR-29: Epic 6 — comparateurs.
FR-30: Epic 5 (évaluation affichée, pronostic retenu local, débrief) + Epic 6 (journalisation quotidienne, backtest).

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

### Epic 5: Pronostiquer le Multi d'une course
Depuis les résultats d'une course éligible, l'utilisateur ouvre le Multi, choisit son nombre de chevaux et obtient le pronostic du modèle — indice de confiance (seuils provisoires), explications, chevaux les plus probables à activer comme bases, grilles de chaque formule sans aucun coût — peut le retoucher, marquer un non-partant, vérifier un système trouvé ailleurs, retenir son pronostic et copier les grilles, hors ligne compris ; le lendemain, il voit le débrief dans « Mes pronostics Multi ». Aucune notion d'argent (recadrage du 2026-10-18).
**FRs couvertes:** FR-22, FR-23, FR-24, FR-25, FR-26 (seuils provisoires), FR-27, FR-28, FR-30 (évaluation affichée, pronostic retenu, débrief) ; NFR-7 à NFR-11 ; UX-DR1 à UX-DR13.
**Notes d'implémentation:** Première story = prérequis bloquant (vérification des règles du pari sur pmu.fr, `fixtures/multi_regles.json` daté). Inclut : correction du fuseau horaire de `pmu_client` (AD-12), Alembic avec baseline sur la base de production puis `multi_course` (AD-13, AD-10), générateur hors ligne et catalogue copié à l'identique (AD-7), moteur Multi Python + Dart avec `multi_cases.json`, `multi_codes.json`, `multi_versions.json` et table de libellés FR (AD-6, AD-8, AD-12), cache local en version 2 et purge à 90 jours (AD-9), bordure `line-card` relevée pour toute l'app (UX-DR12). Un seul epic plutôt que deux : moteur Multi et écran partagés, conception validée de bout en bout.

### Epic 6: Évaluer le pronostic Multi
L'utilisateur sait si le modèle fait mieux que le marché : les autres méthodes (méthode 1, marché) s'affichent avec leurs performances mesurées, les seuils de confiance cessent d'être provisoires, et la mention « modèle en cours d'évaluation » tombe — ou reste — selon les résultats.
**FRs couvertes:** FR-29, FR-26 (seuils fixés par le pilote), FR-30 (journalisation quotidienne, backtest).
**Notes d'implémentation:** Comparateurs (M1, B1 ; B0 journalisé seulement), harnais de backtest dans `backend/app/jobs/` d'abord sur la machine de dev avec export puis import en production (AD-11), pilote qui fixe `fixtures/multi_parametres_pilote.json` (seuils par taille, tailles de référence, effectif minimal), puis journalisation quotidienne dans le conteneur `ingestion` (AD-10), `/multi/performance`. `/multi/backtest` reste différé au passage sur serveur. S'appuie sur l'Epic 5 sans le modifier en profondeur.

## Epic 5: Pronostiquer le Multi d'une course

Depuis les résultats d'une course éligible, Marc obtient sur son téléphone, hors ligne compris, le pronostic Multi du modèle à la taille qu'il choisit — indice de confiance, explications, chevaux les plus probables, grilles vérifiées de chaque formule —, le retouche, le retient, et en voit le débrief le lendemain. Aucune notion d'argent n'existe nulle part dans le module (recadrage du 2026-10-18).

### Story 5.1: Règles du pari vérifiées et datées

En tant que porteur de projet,
je veux que les règles du pari Multi soient vérifiées sur pmu.fr, datées et rangées dans un fichier unique lu par le backend et l'application,
afin qu'aucune grille ni aucun pronostic ne repose sur des règles de 2001-2002 jamais contrôlées.

**Acceptance Criteria:**

**Given** le prérequis bloquant du PRD §9.5
**When** l'équipe planifie les epics 5 et 6
**Then** aucune autre story des epics 5 et 6 (5.2 à 5.16, 6.1 à 6.7, y compris les stories techniques 5.2 à 5.4) ne démarre avant que cette story soit terminée
**And** cette règle figure en tête de la story et dans le suivi de sprint.

**Given** le porteur de projet (ou le développeur, avec sa validation) consulte le règlement du Multi sur pmu.fr
**When** il contrôle chaque règle du cahier Multi §2 — formules 4 à 7, nombre de paris par ticket physique, choix de la course support selon les jours (Quinté+ ou 2sur4), seuil de 14 partants déclarés, requalification des non-partants, ex-aequo, ordre de l'arrivée dégradée
**Then** `fixtures/multi_regles.json` (créé) contient chaque valeur avec sa `provenance`, et à la racine `date_verification` (date ISO), `verifie_par` et `sources` (URL consultées)
**And** toutes les clés sont en français (AD-7, conventions de nommage).

**Given** une règle de pmu.fr diffère du document de 2001-2002
**When** le fichier est rempli
**Then** il porte la valeur actuelle et une entrée `ecarts_document` (ancienne valeur → nouvelle valeur, source)
**And** les notes de la story listent les sections touchées (cahier Multi §2, annexe A, chiffres de UJ-4)
**And** si le Multi n'existe plus ou si sa mécanique (formules, tickets, garantie) a changé, la story s'arrête sur ce constat et le porteur de projet décide avant toute autre story.

**Given** les constantes du document conservées pour la seule provenance (cahier Multi §2 v3 : `MISE_UNITAIRE_EUR`, `MULTIPLICATEUR_MAX`, `RAPPORT_MIN`, `COEF_R7`)
**When** elles sont écrites dans le fichier
**Then** elles sont regroupées dans un bloc `provenance_seulement`, jamais affiché
**And** seul le test de cohérence 1 du cahier Multi §9 les lit (`COEF_R7 == {4: 35, 5: 7, 6: 7/3, 7: 1}`), et un test vérifie qu'aucun module du pronostic ne les importe (NFR-8).

**Given** `backend/app/engine/multi/regles.py` (créé, avec `backend/app/engine/multi/__init__.py`)
**When** la suite `backend/tests/test_multi_regles.py` tourne
**Then** chaque constante du module est égale à celle de `fixtures/multi_regles.json`, chargé depuis la racine du dépôt comme `engine_constants.json` (AD-2), et tout écart fait échouer le test
**And** une clé dupliquée ou manquante dans le fichier fait échouer le chargement avec un message explicite
**And** `regles.py` n'importe rien de `data/`, `api/` ni d'une bibliothèque d'E/S (AD-1).

**Given** les fonctions pures `requalifier(ticket, non_partants)`, `combinaisons_payables(arrivee_avec_ex_aequo)` et `regler(tickets, arrivee, non_partants)`
**When** les tests 1 à 5 du cahier Multi §9 tournent
**Then** la table de requalification est vérifiée case par case (formules 4 à 7 × 0 à 4 non-partants et plus), un ex-aequo à la 4ᵉ place donne 2 combinaisons payables, un ex-aequo aux places 1 à 3 en donne une seule, l'arrivée dégradée suit l'ordre {1,2,3,5} → {1,2,4,5} → {1,3,4,5} → {2,3,4,5} puis « aucune combinaison »
**And** `regler` renvoie les tickets touchés avec leur formule effective et les tickets annulés (moins de 4 chevaux restants), sans aucune clé de montant.

**Given** un fichier de règles sans `date_verification` (cas de test)
**When** `regles_verifiees()` est appelée
**Then** elle renvoie `False`, ce qui servira à masquer toute grille (FR-22)
**And** les cas fixes de cette story sont écrits dans la section `regles` de `fixtures/multi_cases.json` (créé), pour être rejoués en Dart à la story 5.10 (NFR-9).

### Story 5.2: Heures de départ fiables (UTC)

En tant que turfiste,
je veux que l'heure de départ affichée et utilisée par l'application soit juste, quel que soit le fuseau du serveur,
afin que le gel de mon pronostic au départ et la journalisation « avant le départ » tombent au bon moment.

**Acceptance Criteria:**

**Given** un horodatage PMU en millisecondes epoch
**When** `pmu_client._epoch_ms_to_datetime` le convertit
**Then** il renvoie un instant conscient du fuseau en UTC (`tzinfo=timezone.utc`), identique quel que soit le fuseau du processus (AD-12)
**And** un test le vérifie avec le processus réglé sur `Europe/Paris` puis sur UTC (ex. `1642249685000` → `2022-01-15T12:28:05+00:00`).

**Given** un horodatage qui tombe à 23 h 30 UTC le 14 janvier (00 h 30 à Paris le 15)
**When** `_epoch_ms_to_date` en tire la date de la course
**Then** la date est calculée dans le fuseau `Europe/Paris` (15 janvier)
**And** si l'image Docker n'a pas de base de fuseaux, la dépendance `tzdata` est ajoutée à `backend/requirements.txt` et un test échoue si `ZoneInfo("Europe/Paris")` est introuvable.

**Given** `courses.heure_depart` lu par `/courses`
**When** `CourseOut` le sérialise
**Then** l'heure part toujours en ISO-8601 avec décalage (`+00:00`), qu'elle soit stockée naïve en UTC ou consciente
**And** une valeur déjà consciente n'est jamais décalée une seconde fois (test)
**And** les lignes déjà en production (écrites par un conteneur en UTC) ne sont pas réécrites ; un contrôle sur un échantillon contre la source PMU est consigné dans les notes de la story.

**Given** l'application reçoit `heure_depart`
**When** `CourseSummary` la lit
**Then** elle est conservée comme instant UTC, toute comparaison (« avant le départ ») se fait entre instants UTC
**And** l'affichage passe par une fonction unique `mobile/lib/utils/heure_fr.dart` qui rend l'heure locale en typographie française (« 15 h 05 », « 9 h 38 »), testée avec deux fuseaux différents.

**Given** une course sans heure de départ connue
**When** l'heure est affichée ou comparée
**Then** l'affichage dit « Heure de départ inconnue » et la comparaison renvoie « inconnue », jamais une heure inventée
**And** l'entrée correspondante de `_bmad-output/implementation-artifacts/deferred-work.md` est marquée résolue.

### Story 5.3: Cartes plus lisibles dans toute l'app (line-card 3:1, on-gold)

En tant que turfiste,
je veux que les cartes, champs et panneaux se détachent nettement du fond et que le texte posé sur l'or reste lisible,
afin de lire l'application sans effort, de nuit sur l'hippodrome comme à 200 % de taille de police.

**Acceptance Criteria:**

**Given** `mobile/lib/theme/app_colors.dart` (créé) qui déclare les jetons de `DESIGN.md` (`bg`, `surface`, `surface-2`, `gold`, `gold-dim`, `green`, `red`, `blue`, `text`, `muted`, `on-gold` `#14100A`, `line`, `line-2`, `line-card` `rgba(255,255,255,.36)`)
**When** le thème de `mobile/lib/main.dart` est construit
**Then** la bordure des cartes (`cardTheme`), des champs (`inputDecorationTheme`) et des panneaux utilise `line-card`
**And** plus aucun littéral `Color(0x…)` ne reste dans `mobile/lib/` hors de `app_colors.dart` (test qui parcourt les sources).

**Given** le jeton `line-card` composé sur `bg`, `surface` et `surface-2`
**When** un test unitaire calcule le contraste selon la formule WCAG
**Then** chaque contraste est ≥ 3:1 (UX-DR12)
**And** `on-gold` sur `gold` est ≥ 4,5:1.

**Given** les éléments sur fond or existants (badge de dossard de `horse_card.dart`, CTA « Calculer »)
**When** ils sont rendus
**Then** leur texte utilise `on-gold` (tests de widgets)
**And** `line` et `line-2` ne servent plus qu'aux séparateurs internes, jamais à la limite d'une carte.

**Given** les écrans existants Liste des partants et Résultats
**When** les tests de widgets les rendent avec un facteur de police de 2,0
**Then** aucun débordement n'est levé et aucun chiffre n'est tronqué par une ellipse
**And** les cibles interactives respectent la règle Android des 48dp (`androidTapTargetGuideline`) et le contraste du texte (`textContrastGuideline`)
**And** aucune information n'est portée par la couleur seule (le badge de value garde son signe et son libellé).

### Story 5.4: Mises à jour du serveur sans perte de données (Alembic)

En tant que porteur de projet,
je veux que toute évolution du schéma de la base serveur passe par une migration Alembic appliquée au démarrage de l'API,
afin que les tables et colonnes du Multi atteignent la base de production existante sans la recréer ni perdre ses données.

**Acceptance Criteria:**

**Given** `alembic==1.20.0` ajouté à `backend/requirements.txt`, `backend/alembic.ini` et `backend/alembic/env.py` (créés) qui lisent `DATABASE_URL` et ciblent `Base.metadata` de `backend/app/data/models.py`, en mode batch SQLite
**When** l'image Docker est construite
**Then** le `Dockerfile` copie `alembic.ini` et `alembic/` (dans le contexte de build `backend/`) (AD-13).

**Given** la révision de base (baseline)
**When** `alembic upgrade head` tourne sur une base vide
**Then** le schéma obtenu est identique à celui de la production actuelle : `courses` (avec `heure_depart`), `chevaux`, `participations`, `performances_historiques` (avec `cheval_id`, `participation_id` facultatif et l'index unique `uq_perf_hist_cheval_date_hippo`) — comparaison par inspection dans un test.

**Given** une base au format actuel de production, sans table `alembic_version`
**When** le service `api` démarre
**Then** le script de démarrage (`backend/scripts/demarrer_api.py`, appelé par le `CMD` du `Dockerfile`) copie le fichier SQLite en `hippique.db.avant-<révision>.bak`, applique une dernière fois `_migrate()` (idempotent) pour amener une vieille base à la forme de la baseline, tamponne la baseline, puis exécute `alembic upgrade head`, puis lance uvicorn
**And** un test sur une copie de base au format ancien vérifie que le nombre de lignes de chaque table est inchangé après migration.

**Given** une migration qui échoue au démarrage
**When** le script s'exécute
**Then** le processus s'arrête avec un code non nul, l'erreur est journalisée et uvicorn ne démarre pas
**And** la copie de sauvegarde reste disponible ; seules les 3 dernières sont conservées.

**Given** le service `ingestion`
**When** il démarre ou reprend un cycle
**Then** il ne migre jamais : il vérifie que la révision de la base est `head` et, sinon, journalise une erreur explicite et réessaie plus tard sans rien écrire
**And** un test couvre ce refus.

**Given** `backend/app/data/repository.py`
**When** il ouvre une vraie base
**Then** il n'appelle plus ni `create_all` ni `_migrate` ; seuls les tests sur base jetable créent le schéma, via un paramètre explicite
**And** un test de concordance vérifie que la comparaison automatique entre les modèles et la révision `head` est vide (un changement de modèle livré sans migration fait échouer la suite).

### Story 5.5: Savoir si une course est éligible au Multi

En tant que turfiste,
je veux savoir, pour chaque course, si elle est la course support du Multi et si elle a assez de partants déclarés,
afin d'ouvrir le Multi là où il a un sens et de comprendre pourquoi il est indisponible ailleurs.

**Acceptance Criteria:**

**Given** des réponses PMU réelles capturées en 2026 dans `backend/tests/fixtures/pmu/` (un jour de Quinté+ et un jour sans)
**When** `pmu_client.get_programme` lit une course
**Then** `CourseInfo.est_course_support` vaut `True` ou `False` selon la liste des paris de la course (champ exact documenté en commentaire dans `pmu_client.py`), et `None` si cette liste est absente ou illisible — jamais `False` par défaut
**And** aucun autre module ne lit ce champ brut (AD-1, FR-16).

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée la table `multi_course` (`course_id` unique, `est_course_support` facultatif, `nb_partants_declares`, `arrivee_json` facultatif, `finalisee`, `arrivee_corrigee_le` facultatif, `donnees_maj_le`, instants en UTC) et ajoute `participations.non_partant` (booléen, faux par défaut) — rien d'autre (AD-10, AD-13).

**Given** le job d'ingestion du programme et des partants
**When** il enregistre une course
**Then** il écrit, via `repository.py` et lui seul (AD-10), l'éligibilité, le nombre de partants déclarés (non-partants compris) et `donnees_maj_le` (instant UTC de la dernière mise à jour des partants et des cotes)
**And** un partant au statut non-partant de la source a `non_partant = True`.

**Given** le job de finalisation (`ingest_resultats_veille`)
**When** l'arrivée d'une course est définitive
**Then** il écrit `arrivee_json` (5 premières places avec ex-aequo, ex. `[{"rang": 4, "nums": [3, 12]}]`) ; tant que la course n'est pas finalisée, la valeur reste `NULL` et n'est jamais inventée ; deux exécutions donnent le même résultat (FR-17)
**And** pour les courses finalisées depuis moins de `MULTI_RECONTROLE_ARRIVEE_JOURS` jours (défaut 3, variable d'environnement), il relit l'arrivée : si elle a changé, il met à jour `arrivee_json` et `arrivee_corrigee_le` et journalise la correction ; sinon il ne modifie rien.

**Given** `repository.get_multi_contexte(course)`
**When** il construit le contexte Multi d'une course (AD-6)
**Then** le contexte porte `cle_course` (`AAAAMMJJ-Rn-Cn`, AD-12), `eligible`, `raison` (`pas_course_support`, `moins_de_14_partants` avec le nombre, ou rien), `mode_exploration`, `nb_partants_declares`, les dossards non-partants, `donnees_a` (UTC), `statut_modele` (`en_cours_d_evaluation`) et `seuils_provisoires` (`true`)
**And** il ne contient aucun champ d'argent ; le seuil de 14 vient de `regles.py` (story 5.1), jamais d'un littéral.

**Given** les cas d'éligibilité
**When** les tests tournent
**Then** 14 déclarés et course support → éligible ; 13 → `moins_de_14_partants` ; marqueur `False` → `pas_course_support` ; marqueur `None` et ≥ 14 → éligible en mode exploration (FR-22) ; marqueur `None` et 12 → `moins_de_14_partants`
**And** un non-partant survenu après la déclaration ne fait pas perdre l'éligibilité
**And** une course ingérée avant cette story, sans ligne `multi_course`, est traitée comme marqueur `None`.

**Given** l'API existante
**When** `/courses` et `/courses/{id}/partants` répondent
**Then** chaque `CourseOut` porte un objet `multi` typé (`MultiContexteOut`, AD-4) et chaque `ParticipationOut` porte `non_partant`
**And** côté mobile, `mobile/lib/models/multi_contexte.dart` (créé), `CourseSummary` et `Horse` lisent ces champs ; un champ absent (ancien backend) donne un contexte nul, que l'app traitera comme « contexte Multi non chargé ».

### Story 5.6: Catalogue de systèmes vérifié

En tant que développeur,
je veux un générateur hors ligne qui produit un catalogue de systèmes réduits vérifiés, copié à l'identique dans le backend et l'application, et un vérificateur de couverture,
afin que chaque grille montrée couvre réellement ce qu'elle promet, sans aucun solveur en production ni sur le téléphone.

**Acceptance Criteria:**

**Given** `scripts/generer_catalogue_multi.py` (créé), avec ses dépendances en ligne PEP 723 épinglées (`scipy==1.18.1`, une version NumPy 2.x, `requires-python`, `exclude-newer`)
**When** il est lancé par `uv run` sur la machine de développement
**Then** il applique dans l'ordre les formes closes (`t' = 1` → `⌈v'/k'⌉` ; `k' = t'` → toutes les combinaisons), le solveur exact `scipy.optimize.milp` quand il y a au plus ~5 000 blocs candidats (limite 20 s), puis glouton et recuit à plusieurs graines, et garde le meilleur résultat (cahier Multi §5.2, AD-7)
**And** ni SciPy ni le script ne sont importés par le backend ni listés dans `backend/requirements.txt` (test).

**Given** le domaine du catalogue `v' ≤ 20`, `k' ∈ [1, 7]`, `t' ∈ [1, 4]`, avec `v = v' + (4 − t') ≤ 20` et `k' ≥ t'`
**When** le générateur termine
**Then** chaque entrée est vérifiée avant écriture ; si une seule échoue, le script s'arrête en erreur et n'écrit aucun fichier
**And** une forme non résolue dans le temps imparti est absente du catalogue et listée dans le rapport, jamais approchée.

**Given** la sortie `fixtures/multi_catalogue.json`
**When** elle est écrite
**Then** l'en-tête porte `version` (sha256 des entrées), `empreinte_regles` (sha256 de `fixtures/multi_regles.json`), les versions de SciPy et HiGHS et `genere_le` (UTC), et les entrées sont indexées par `(v', k', t')` sur des indices `0..v'-1`
**And** la sérialisation est déterministe (clés et blocs triés) : deux générations au même résultat donnent les mêmes octets
**And** le script copie le fichier à l'identique dans `backend/app/engine/multi/multi_catalogue.json` et `mobile/assets/multi_catalogue.json`, et un test Python vérifie l'identité octet à octet de la copie backend.

**Given** l'annexe A du cahier Multi (systèmes non mixtes)
**When** le test 6 tourne, sans SciPy
**Then** pour chaque entrée, le catalogue contient un système vérifié de taille inférieure ou égale à celle du document, sauf coquille documentée : 3 bases + 14 chevaux (v = 17, tickets de 4) → exactement 14 (FR-25)
**And** un rapport d'écart avec l'annexe A est joint aux notes de la story, avec la taille du fichier mesurée (spine, « Deferred »).

**Given** `empreinte_regles` de l'en-tête
**When** `fixtures/multi_regles.json` a changé depuis la génération
**Then** un test échoue et demande la regénération (AD-7).

**Given** `backend/app/engine/multi/verification.py` et `backend/app/engine/multi/catalogue.py` (créés)
**When** `verifier_couverture(selection, bases, tickets)` est appelé
**Then** il renvoie une preuve (`nb_requis`, `nb_non_couverts`, premières combinaisons manquantes, multiplicités minimale et maximale, carte de couverture 1×/2×/3×)
**And** le test 7 passe : un système auquel on retire un ticket échoue ; une sélection plus petite que la formule renvoie le code `selection_plus_petite_que_formule` ; un ticket qui contient un cheval hors sélection, oublie une base ou répète un dossard est signalé par un code
**And** au chargement, un catalogue dont `version` ne correspond pas à ses entrées est refusé avec le code `catalogue_invalide`.

### Story 5.7: Moteur Multi Python : couverture, sélection pour une taille, chevaux les plus probables, systèmes par formule, relabellement

En tant que développeur,
je veux le moteur Multi en Python, branché sur la sortie du moteur de scoring,
afin que le backend produise de façon déterministe le pronostic du modèle à la taille demandée, pour l'API, la journalisation et le backtest.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/modeles.py`, `couverture.py` et `recommandation.py` (créés)
**When** ils sont importés
**Then** ils ne dépendent que de `app.engine` (AD-1)
**And** un adaptateur `depuis_analyse(...)` construit les `ChevalMulti` et le champ (chevaux réels + partants virtuels) depuis la sortie du scoring, sans recalculer score, `top4` ni value (AD-6) — test : `top4` identique au scoring.

**Given** un champ de n chevaux (réels et virtuels)
**When** `couverture.py` calcule `P_ens` sur tous les ensembles de 4 chevaux (énumération exacte Harville, cahier Multi §6.1), `p_couverture(S, B)`, la distribution du nombre de chevaux capturés (0 à 4) et `h_norm`
**Then** le test 8 passe : `Σ P_ens = 1` à 1e-9 ; `E[X] = Σ top4` ; à forces égales, loi hypergéométrique à 1e-9
**And** les partants virtuels entrent dans le champ mais jamais dans une sélection.

**Given** une taille `v`, des bases, des chevaux imposés, des chevaux retirés et des non-partants
**When** `selectionner` applique l'algorithme du cahier Multi §4.1 et l'annexe C
**Then** les comparaisons se font sur des probabilités quantifiées à la grille 1e-9 et les égalités suivent les règles du cahier (`top4` décroissant, puis `p_gagnant`, puis dossard ; échange : dossard entrant puis sortant le plus petit) (AD-6, FR-23)
**And** la recherche d'échanges est bornée par `ITERATIONS_ECHANGES_MAX`, déclarée dans la section `constantes_moteur` de `fixtures/multi_cases.json` ; une recherche tronquée ajoute l'avertissement `optimisation_tronquee`.

**Given** les cas d'erreur
**When** `v < 4`, `v > 20`, `v` supérieur au nombre de chevaux sélectionnables, plus de 3 bases, une base hors sélection, un dossard inconnu, ou imposés et bases plus nombreux que `v`
**Then** le moteur lève une erreur portant un code (`taille_hors_bornes`, `taille_superieure_aux_selectionnables`, …), jamais une phrase.

**Given** les tests 9 et 10 du cahier Multi §9
**When** ils tournent
**Then** sur des champs de 10 chevaux au plus, la sélection a la même `p_couverture` que l'optimum exhaustif, et au moins un cas montre que le tri par `top4` seul n'est pas optimal et que les échanges le corrigent
**And** la sélection compte exactement `v` chevaux pour chaque `v` de 4 à `min(20, sélectionnables)` ; `p_couverture` ne décroît pas quand `v` augmente.

**Given** la sélection sans base à la taille choisie
**When** les bases candidates sont calculées (FR-24)
**Then** il y en a 3 (moins si la sélection en compte moins), ordonnées par `top4`, `p_gagnant` puis dossard, aucune active par défaut
**And** chacune porte `top4`, les tickets économisés par formule (≥ 0) et la couverture perdue (≥ 0) — test 11.

**Given** une sélection et ses bases actives
**When** `systemes(...)` est appelé (FR-25)
**Then** il renvoie un système par formule `k ≤ v` présente au catalogue, de `k = 7` à `k = 4`, avec `nb_tickets`, `nb_tickets_physiques` (`⌈nb_tickets / 4⌉`), la garantie, la même `p_couverture` pour toutes et les grilles en dossards
**And** le relabellement est canonique (non-bases triés par `top4`, `p_gagnant`, dossard → indices `0..v'-1`) et chaque système est revérifié avant d'être renvoyé ; un système non couvrant n'est jamais renvoyé
**And** une forme absente donne l'avertissement `systeme_absent_du_catalogue` (`{k}`) ; des règles non vérifiées (story 5.1) donnent zéro système et l'avertissement `regles_non_verifiees`.

**Given** une sélection quelconque (dont celle de l'utilisateur)
**When** `evaluer(...)` est appelé (FR-28, FR-30)
**Then** il renvoie `p_couverture`, la distribution des chevaux capturés, la contribution de chaque cheval (baisse de `p_couverture` s'il est retiré), les 3 écartés de plus fort `top4`, 1 à 2 échanges suggérés qui augmentent `p_couverture` (aucun s'il n'y en a pas), et le coût en couverture des chevaux imposés par rapport au pronostic libre à taille égale
**And** `simuler_non_partant(...)` renvoie, pour chaque cheval de la sélection, la formule effective de chaque ticket (requalification de la story 5.1) et la nouvelle `p_couverture`
**And** `bilan_arrivee(selection, arrivee)` renvoie le nombre de chevaux capturés (maximum sur les combinaisons payables) et « arrivée dans la sélection » selon les ex-aequo et l'arrivée dégradée.

**Given** toutes les sorties du moteur
**When** les tests de forme tournent
**Then** deux appels identiques donnent le même résultat (test 15) ; aucune chaîne de libellé n'y figure, seulement des `Explication(code, params)`
**And** aucune clé `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` n'apparaît, à aucune profondeur (NFR-8)
**And** chaque cas fixe est écrit dans `fixtures/multi_cases.json` (sections `couverture`, `selection`, `bases`, `systemes`, `evaluation`, `non_partant`, `bilan`), entrées et sorties attendues quantifiées, dans un format lisible par Dart (NFR-9).

### Story 5.8: Indice de confiance et explications (Python), registre multi_codes.json, seuils provisoires par taille

En tant que développeur,
je veux que le moteur Python qualifie chaque pronostic par un indice de confiance avec ses raisons et explique chaque élément par des codes déclarés dans un registre,
afin que l'utilisateur sache à quel point se fier au pronostic et pourquoi, sans phrase figée dans le moteur.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/confiance.py` (créé), `p = p_couverture(S, B)`, `h_norm` et la fragilité des données
**When** l'indice est calculé (cahier Multi §6.4, FR-26)
**Then** le niveau de départ est `elevee`, `moyenne` ou `faible` selon les seuils de la taille `v` ; il baisse d'un cran si `h_norm ≥ seuil_course_ouverte`, puis d'un cran si la part de chevaux inédits ou à historique court atteint `seuil_donnees_fragiles` ou si le favori est fragile (meilleur `p_gagnant` avec `historique_court`, `inedit` ou terrain majoritairement inconnu)
**And** il ne descend jamais sous `faible`.

**Given** tout indice calculé
**When** il est renvoyé
**Then** il porte au moins les raisons `couverture` (`p_couverture`, `taille`, `bases_comprises`), `ouverture_course` (`h_norm`), `donnees` (inédits, historiques courts, cotes manquantes, partants non analysés) et, s'il y a lieu, `favori_fragile` (`num`), ainsi que l'état `seuils_provisoires` et `statut_modele`
**And** la fragilité ajoute l'avertissement fort `donnees_fragiles` (FR-23)
**And** une course non éligible n'a pas d'indice ; en mode exploration, l'indice porte la raison `course_non_support`
**And** aucune entrée de l'indice ne provient de la presse, et aucun code ne signifie « jouer » ou « passer ».

**Given** le test 12 du cahier Multi §9
**When** les cas de `fixtures/multi_cases.json` (section `confiance`) tournent
**Then** chaque niveau et chaque abaissement (course ouverte, données fragiles, favori fragile) est atteint par au moins un cas, et les seuils sont lus par taille.

**Given** `fixtures/multi_parametres_pilote.json` (créé)
**When** il est écrit avant le pilote
**Then** il contient `seuil_confiance_elevee[v]` et `seuil_confiance_moyenne[v]` pour chaque taille de 4 à 20, `seuil_course_ouverte`, `seuil_donnees_fragiles`, `tailles_reference` et `effectif_minimal` (à `null`), `provisoire: true` et une `provenance` qui décrit la règle provisoire utilisée : seuil moyen = 2 × la probabilité qu'une sélection au hasard de taille `v` contienne l'arrivée d'un champ de 16 partants, seuil élevé = 3 × cette probabilité, plafonnés à 0,90 et 0,95 ; `seuil_course_ouverte = 0,90` ; `seuil_donnees_fragiles = 0,25` — valeurs à confirmer par le porteur de projet, remplacées par le pilote (story 6.5)
**And** comme `fixtures/` est hors du contexte de build Docker, `backend/app/engine/multi/parametres.py` en porte un miroir validé par test contre le fichier (patron AD-2), et le contexte Multi de la story 5.5 lit désormais `seuils_provisoires` dans ce miroir.

**Given** des seuils fournis par l'utilisateur
**When** ils sont incohérents (seuil moyen supérieur au seuil élevé, valeur hors de [0, 1], taille absente)
**Then** le moteur lève une erreur codée ; des seuils à `null` prennent les valeurs par défaut de la taille.

**Given** `backend/app/engine/multi/explications.py` (créé)
**When** le pronostic est expliqué (FR-27)
**Then** chaque cheval retenu porte `retenu_top4` ou `retenu_par_echange` (`top4`, `rang_modele`, hausse de couverture), `contribution` et ses indicateurs de transparence ; chacun des 3 écartés porte sa raison (`ecarte_top4_faible`, `ecarte_donnees_fragiles`, `ecarte_par_vous`, `ecarte_non_partant`) ; chaque base candidate porte `base_candidate` ; chaque système porte `systeme_formule` (`k`, `nb_tickets`, `nb_tickets_physiques`) ; les limites des données portent `cotes_du` (heure UTC), `cote_manquante` (`num`) et `partants_non_analyses` (`nb`)
**And** aucun code n'exprime une value.

**Given** `fixtures/multi_codes.json` (créé)
**When** les tests du registre tournent (AD-8, NFR-11)
**Then** chaque code émis dans tous les cas de `fixtures/multi_cases.json` (stories 5.7 et 5.8) est déclaré avec exactement ses paramètres déclarés, sa famille (raison, explication, avertissement) et sa force (normale ou forte)
**And** un code non déclaré ou un paramètre en trop fait échouer la suite.

**Given** `fixtures/multi_versions.json` (créé : version du moteur Multi, du registre, des paramètres du pilote)
**When** `identite_pronostic(...)` est calculée
**Then** elle réunit la clé de course, la version du moteur, la `version` du catalogue, l'empreinte des règles, l'empreinte sha256 des paramètres canoniques et `donnees_a` (UTC) (AD-12)
**And** un cas partagé fixe l'identité attendue pour la comparer en Dart.

### Story 5.9: API du pronostic Multi (éligibilité, recommandation, systèmes, vérifier, évaluer)

En tant que développeur,
je veux exposer le moteur Multi par des routes typées,
afin que les jobs du backend et les clients autres que l'application obtiennent le pronostic, ses systèmes et ses vérifications, et que l'application lise l'arrivée d'une course pour le débrief.

**Acceptance Criteria:**

**Given** `backend/app/api/routes_multi.py` et `backend/app/schemas/multi.py` (créés), inclus dans `backend/app/main.py`
**When** une route Multi répond
**Then** la réponse est construite depuis son schéma Pydantic déclaré, jamais un `__dict__` (AD-4)
**And** les clés JSON sont en français (`selection`, `bases`, `tickets`, `p_couverture`, `confiance`, `explications`).

**Given** `GET /courses/{id}/multi/eligibilite`
**When** la course existe
**Then** la réponse porte le contexte Multi de la story 5.5, les dossards non-partants et, si la course est finalisée, l'arrivée avec ses ex-aequo et `arrivee_corrigee_le`
**And** une course inconnue renvoie 404.

**Given** `POST /multi/recommandation` avec `course_id` (clé PMU `AAAAMMJJ-Rn-Cn`, AD-12) ou une liste de chevaux saisis comme `/analyse`, `taille`, `bases_actives`, `chevaux_imposes`, `chevaux_exclus`, `non_partants` et `seuils`
**When** la course est éligible ou en mode exploration
**Then** la réponse suit le cahier Multi §10 : `taille`, `confiance` (niveau et raisons), `pronostic` (sélection avec rôles et explications, `p_couverture`, `distribution_captures`, `h_norm`), `bases_candidates`, `systemes` de toutes les formules, `ecartes`, `statut_modele`, `seuils_provisoires`, `mode_exploration` et l'identité du pronostic
**And** une course non éligible renvoie 422 avec le code `course_non_eligible` et sa raison.

**Given** `POST /multi/systemes`, `POST /multi/verifier` et `POST /multi/evaluer`
**When** ils sont appelés
**Then** `/multi/systemes` renvoie les systèmes vérifiés de toutes les formules pour une sélection et ses bases ; `/multi/verifier` renvoie la preuve de couverture d'un système saisi, ses combinaisons manquantes et, si le catalogue contient un système valide plus petit pour la même sélection, les mêmes bases et la même formule, ce système (FR-25) ; `/multi/evaluer` renvoie `p_couverture`, la distribution, les contributions et les échanges suggérés (FR-28).

**Given** une entrée invalide
**When** `taille < 4`, `taille > 20`, `taille` supérieure aux sélectionnables, bases hors sélection, plus de 3 bases, sélection de plus de 20 chevaux, dossard inconnu, `k < 4` ou `k > 7`
**Then** la route renvoie 422 avec le code d'erreur du moteur, jamais une phrase ni une trace technique.

**Given** le schéma OpenAPI de l'application
**When** un test parcourt les schémas de requête et de réponse des routes Multi
**Then** aucun champ `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` n'existe (NFR-8)
**And** chaque explication renvoyée est un code déclaré dans `fixtures/multi_codes.json`
**And** sur les cas partagés, la réponse de `/multi/recommandation` est égale à l'appel direct du moteur.

**Given** l'application mobile
**When** on inspecte `mobile/lib/data/remote/api_client.dart`
**Then** aucune méthode n'appelle `/multi/recommandation`, `/multi/systemes`, `/multi/verifier` ni `/multi/evaluer` : le téléphone calcule toujours localement (AD-6).

### Story 5.10: Moteur Multi en Dart à parité (couverture, sélection, bases, systèmes, catalogue embarqué)

En tant que développeur,
je veux le moteur Multi porté en Dart, à parité exacte avec Python,
afin que le téléphone calcule lui-même le pronostic, hors ligne compris, et donne le même résultat que le backend.

**Acceptance Criteria:**

**Given** `mobile/lib/engine/multi/` (`modeles.dart`, `regles.dart`, `couverture.dart`, `recommandation.dart`, `verification.dart`, `catalogue.dart`)
**When** ils sont compilés
**Then** ils n'importent ni `data/`, ni `providers/`, ni Flutter, ni aucune bibliothèque réseau (test qui parcourt les imports, AD-1)
**And** `regles.dart` est validé contre `fixtures/multi_regles.json` et rejoue la section `regles` de `fixtures/multi_cases.json`.

**Given** `mobile/assets/multi_catalogue.json` déclaré dans `mobile/pubspec.yaml`
**When** les tests Dart tournent
**Then** la copie est identique octet à octet à `fixtures/multi_catalogue.json` (AD-7)
**And** au chargement, une `version` qui ne correspond pas aux entrées, ou un fichier absent, donne zéro système avec l'avertissement `catalogue_invalide`, sans empêcher le reste du pronostic.

**Given** chaque cas des sections `couverture`, `selection`, `bases`, `systemes`, `evaluation`, `non_partant` et `bilan` de `fixtures/multi_cases.json`
**When** la suite `mobile/test/engine/multi/` le rejoue
**Then** la sortie Dart est égale à la sortie attendue : probabilités égales après quantification à 1e-9, mêmes égalités départagées, mêmes listes complètes de tickets après relabellement (NFR-9)
**And** `ITERATIONS_ECHANGES_MAX` est lue et validée contre la même section `constantes_moteur` que Python.

**Given** la sortie du moteur de scoring Dart pour une course (probabilités, `top4`, drapeaux de transparence, partants virtuels)
**When** l'adaptateur Dart construit les `ChevalMulti`
**Then** `top4` et `p_gagnant` sont repris tels quels, jamais recalculés (AD-6)
**And** aucune sortie ne contient de clé d'argent ni de phrase.

**Given** une course de 20 chevaux, taille 12, toutes formules
**When** le pronostic complet est calculé sur l'appareil Android cible
**Then** le temps mesuré est consigné dans les notes de la story (NFR-10, question ouverte PRD §11.1)
**And** s'il n'est pas perçu comme instantané, `ITERATIONS_ECHANGES_MAX` est abaissée dans la fixture, pour Python et Dart ensemble, et l'avertissement `optimisation_tronquee` apparaît dans les cas concernés.

### Story 5.11: Confiance et explications en Dart + table de libellés FR

En tant que développeur,
je veux l'indice de confiance et les explications en Dart, à parité avec Python, et une table qui rend chaque code en français,
afin que l'écran Multi affiche des raisons lisibles, identiques au backend, et que l'anglais puisse s'ajouter plus tard sans toucher au moteur.

**Acceptance Criteria:**

**Given** `mobile/lib/engine/multi/confiance.dart`, `explications.dart`, `parametres.dart` et `versions.dart` (créés)
**When** la suite Dart rejoue les sections `confiance` et `explications` de `fixtures/multi_cases.json`
**Then** niveau, raisons, avertissements et explications sont identiques à Python (NFR-9, FR-26, FR-27)
**And** `parametres.dart` et `versions.dart` sont validés contre `fixtures/multi_parametres_pilote.json` et `fixtures/multi_versions.json`, et l'identité du pronostic du cas partagé est la même qu'en Python (AD-12).

**Given** `mobile/lib/widgets/multi/libelles_multi.dart` (créé), table code → modèle de phrase française à paramètres nommés (AD-8)
**When** le test du registre tourne
**Then** chaque code de `fixtures/multi_codes.json` a un libellé, et les paramètres de chaque libellé sont exactement ceux déclarés
**And** un code inconnu à l'exécution donne un libellé neutre (« Information indisponible ») et une trace dans le journal, jamais le code brut à l'écran.

**Given** les libellés rendus
**When** un test parcourt toute la table
**Then** aucun ne contient « € », « budget », « coût », « mise », « gain », « rapport », « rentable », « prix », « jouer », « passer », « sûr » ni « certain » (NFR-8, UX-DR13)
**And** toute probabilité est dite estimée (« Top 4 estimé 41 % », « Arrivée dans la sélection : 31 % (estimé) »), les écarts en points (« −6 pts »), les heures en typographie française, les tailles en chevaux et les systèmes en tickets.

**Given** le texte de garantie
**When** il est rendu sans base, avec une base et avec plusieurs bases
**Then** il dit mot pour mot « Si les 4 premiers sont dans votre sélection, au moins un de vos tickets les contient tous », puis la variante « et incluent votre base » ou « et incluent vos bases », toujours suivi de « Couverture garantie — pas un gain garanti » (FR-25, UX-DR13).

**Given** une lecture par TalkBack
**When** un libellé est demandé en version parlée
**Then** les abréviations sont développées (« moins 6 points », « numéro 11 », « pour cent ») et « · » devient une pause.

### Story 5.12: Écran Multi — pronostic (accès depuis Résultats, taille, confiance, sélection, chevaux les plus probables, évaluation)

En tant que turfiste,
je veux ouvrir le Multi depuis les résultats d'une course éligible et voir, pour la taille que je choisis, la confiance, la sélection du modèle, les chevaux les plus probables et l'évaluation,
afin de savoir en un écran quels chevaux peuvent constituer l'arrivée, avec quelle confiance et pourquoi.

**Acceptance Criteria:**

**Given** l'écran Résultats d'une course dont le contexte Multi est éligible (ou en mode exploration)
**When** le classement est calculé
**Then** un `cta-ghost` « Multi » apparaît sous le titre de la course et ouvre `mobile/lib/screens/multi_screen.dart` (UX-DR1, FR-22)
**And** pour une course non éligible, un `multi-badge` « Multi indisponible » le remplace ; un tap affiche la raison (« Pas une course support » ou « Moins de 14 partants déclarés (12) ») ; sans contexte, la raison est « Contexte Multi non chargé — rafraîchissez la course ».

**Given** l'écran Multi qui s'ouvre
**When** le pronostic est calculé
**Then** il l'est par le moteur Dart via `mobile/lib/providers/multi_provider.dart`, sans aucun appel réseau (test avec un client API qui échoue à tout appel, FR-13, AD-6)
**And** l'écran se lit en un seul défilement, dans l'ordre : en-tête (course, « 18 partants · course éligible », « Cotes de 9 h 38 », « Modifiable jusqu'au départ (15 h 05) », icône Réglages, « L'outil ne place aucun pari ») → bandeaux d'état → taille → confiance → sélection et écartés → chevaux les plus probables → évaluation → rappel de jeu responsable (UX-DR2, NFR-7).

**Given** le `size-stepper` au premier affichage
**When** l'écran s'ouvre
**Then** la taille vaut 10, plafonnée au nombre de partants analysés sélectionnables avec la ligne « Plafond : 15 partants analysés » (FR-23)
**And** à une borne, le bouton concerné est désactivé, pas masqué, avec sa raison
**And** chaque tap change la valeur tout de suite ; le recalcul part après environ 800 ms sans nouveau tap ; entre-temps, l'ancien état reste affiché atténué, sans résultat intermédiaire (UX-DR3)
**And** le contrôle est un seul nœud ajustable TalkBack (« Taille de la sélection, 12 chevaux, de 4 à 20 ») et une seule annonce polie suit un recalcul, seulement si le niveau de confiance a changé.

**Given** la `confidence-card`
**When** l'indice est affiché (FR-26, UX-DR4)
**Then** elle montre « Confiance élevée », « Confiance moyenne » ou « Confiance faible », les raisons en libellés courts (arrivée dans la sélection estimée, ouverture de la course, données) et les étiquettes « modèle en cours d'évaluation » et « seuils provisoires » quand elles s'appliquent
**And** l'or n'est utilisé que pour « Confiance élevée », toujours doublé du libellé ; « Confiance faible » n'est jamais en rouge et ne bloque rien
**And** des données fragiles ajoutent sous la carte le bandeau fort « ⚠️ 4 chevaux inédits ou à historique court dans la sélection » ; les emojis sont ignorés par TalkBack.

**Given** la section Sélection
**When** elle est rendue (FR-27, UX-DR5)
**Then** chaque `multi-row` montre dossard, nom, « Top 4 estimé 41 % », « contribution −6 pts », les indicateurs de transparence existants, « Cote manquante » s'il y a lieu et l'étiquette « Base » s'il est base, en un nœud TalkBack groupé
**And** aucun badge de value n'existe dans l'écran (test sur l'arbre de widgets)
**And** les 3 écartés les plus proches suivent sous « Écartés les plus proches », dossard en contour, avec « Écarté : » et leur raison.

**Given** la section « Chevaux les plus probables · selon le modèle »
**When** elle est rendue (FR-24, UX-DR6)
**Then** 3 `base-chip` (moins si la sélection est plus petite) montrent dossard, nom, « Top 4 estimé 58 % » et l'effet en base (« −4 pts d'arrivée dans la sélection »), aucune active au premier affichage
**And** chaque puce est une seule cible ≥ 48dp, rôle interrupteur, état « Base imposée dans tous les tickets » / « Interdite comme base » ; un basculement recalcule sélection, confiance et évaluation sur l'appareil
**And** le mot « sûr » n'apparaît nulle part.

**Given** l'`evaluation-block`
**When** il est rendu (FR-30, UX-DR8)
**Then** il montre « Arrivée dans la sélection : 31 % (estimé) » (« bases comprises » s'il y a des bases) et la distribution des chevaux capturés de 0 à 4, en cinq lignes au pourcentage écrit
**And** si le contexte porte `statut_modele = pas_meilleur_que_le_marche`, un bandeau fort en tête de l'Évaluation dit « Évaluation sur N courses : le modèle ne fait pas mieux que le marché », et le pronostic ne bascule vers aucune autre méthode.

**Given** les états de l'écran (UX-DR11)
**When** ils surviennent
**Then** chacun a son traitement : calcul en cours (indicateur dans la carte confiance) ; erreur (« Calcul du Multi impossible : {raison} », taille conservée, retour possible) ; classement modifié (« Classement modifié — recalculez sur Résultats », contenu atténué) ; exploration (« Exploration — course support non confirmée ») ; partants non analysés (« 3 partants non analysés, non sélectionnables » + « Analyser » vers Liste des partants) ; cote manquante ; hors ligne identique au mode connecté.

**Given** l'écran entier
**When** un test parcourt tous ses textes
**Then** aucun mot ni symbole d'argent n'apparaît (NFR-8, UX-DR13)
**And** à un facteur de police de 2,0, aucun chiffre ni dossard n'est tronqué ; les titres de section sont des en-têtes TalkBack ; les mentions obligatoires font partie du flux de lecture (UX-DR12).

### Story 5.13: Écran Multi — grilles (formules, feuille des grilles, copie, vérifier un système)

En tant que turfiste,
je veux voir, pour ma sélection et ses bases, chaque formule avec son nombre de tickets, ouvrir et copier les grilles en dossards, et vérifier un système trouvé ailleurs,
afin de savoir exactement ce que mes tickets couvrent, sans aucun prix.

**Acceptance Criteria:**

**Given** la section Systèmes, insérée entre les chevaux les plus probables et l'Évaluation
**When** elle est rendue (FR-25, UX-DR7)
**Then** une `formula-row` par formule `k ≤ v`, de 7 à 4, montre « Multi en 7 · 11 tickets · 3 tickets physiques », sans aucun coût
**And** la formule « Affichée » par défaut est Multi en 7 (sinon la plus grande formule disponible) ; un tap en fait la formule affichée, avec l'état sémantique « sélectionné » et le texte de garantie de la story 5.11, puis « Couverture garantie — pas un gain garanti »
**And** une forme absente du catalogue affiche « Système indisponible pour cette forme », jamais un calcul à la volée.

**Given** des règles sans date de vérification
**When** la section Systèmes est rendue
**Then** elle est remplacée par « Règles du pari à vérifier — grilles indisponibles » et « Voir les grilles » est désactivé ; taille, confiance, sélection et évaluation restent consultables (FR-22, UX-DR11).

**Given** la `multi-action-bar`
**When** l'écran est affiché
**Then** elle est posée sous la zone défilante (`Scaffold.bottomNavigationBar`), jamais par-dessus, et porte le `cta-ghost` « Voir les grilles » (UX-DR2)
**And** elle est masquée quand le clavier est ouvert ; au-delà de 130 % de police, « Voir les grilles » passe dans le flux sous la formule affichée
**And** quand le classement est à recalculer, l'action est désactivée, pas masquée.

**Given** la `tickets-sheet` ouverte depuis « Voir les grilles »
**When** elle affiche la formule affichée
**Then** l'en-tête dit « 12 chevaux dont 1 base · 11 tickets · 3 tickets physiques », les tickets sont regroupés par ticket physique (4 par bulletin), les bases en gras en première colonne avec la légende « Base : n° 11 (première colonne) »
**And** TalkBack lit chaque ticket physique comme un en-tête et chaque ticket comme un nœud (« Ticket 1 : base 11 ; 2, 4, 7, 9, 13, 15 ») ; la carte de couverture (1×, 2×, 3×) est repliée par défaut
**And** à la fermeture, le focus revient sur « Voir les grilles ».

**Given** « Copier les grilles », épinglé en bas de la feuille
**When** l'utilisateur copie
**Then** le presse-papiers reçoit un texte avec la course, la date, la sélection, les bases, la formule, le texte de garantie, « Couverture garantie — pas un gain garanti » et une ligne par ticket (« T1 : 11 · 2 · 3 · 4 · 7 · 8 · 15 ») (FR-25, extension de FR-21)
**And** « 11 tickets copiés » est affiché et annoncé ; en cas d'échec, « Copie impossible — réessayez », les grilles restent lisibles
**And** un test vérifie que le texte exporté ne contient aucun mot ni symbole d'argent (NFR-8).

**Given** chaque système qui va être affiché
**When** il est relabellé sur l'appareil
**Then** il est revérifié ; un système qui échoue (test avec une entrée de catalogue corrompue) n'est pas affiché et sa formule montre « Système indisponible pour cette forme ».

**Given** « Saisir un système trouvé ailleurs » ouvre la `system-entry-sheet`
**When** l'utilisateur saisit la formule (4 à 7), la sélection, les bases et les tickets ligne à ligne, puis touche « Vérifier »
**Then** un `status-banner` dit « Ce système couvre bien ce qu'il promet » ou « Ce système ne couvre pas 6 groupes de 4 chevaux », avec les premiers groupes manquants en dossards (FR-25)
**And** si le catalogue contient un système valide plus petit pour la même sélection, les mêmes bases et la même formule, « Un système de 9 tickets couvre la même chose » et « L'afficher » le rendent formule affichée
**And** une saisie invalide (dossard hors sélection, ticket de mauvaise taille, base absente d'un ticket, plus de 3 bases) est expliquée sous le champ ; la saisie est conservée tant que l'écran Multi reste ouvert.

### Story 5.14: Retoucher sa sélection et gérer les non-partants

En tant que turfiste,
je veux retirer, ajouter ou imposer un cheval, saisir ma propre sélection et marquer un non-partant, même sans réseau,
afin d'ajuster le pronostic à mes convictions et aux nouvelles du jour en voyant ce que chaque choix change.

**Acceptance Criteria:**

**Given** un tap sur une `multi-row`
**When** la `multi-actions-sheet` s'ouvre, titrée « N° 7, Ondine Royale »
**Then** elle propose Retirer (taille −1), Imposer avec son effet (« Imposer : −3 pts d'arrivée dans la sélection par rapport au pronostic du modèle »), Base oui/non avec l'état courant, Marquer non-partant (FR-28, UX-DR5)
**And** une action ferme la feuille et recalcule sur l'appareil ; une fermeture sans action rend le focus à la ligne ; après « Retirer » ou « Marquer non-partant », le focus va au bandeau de confirmation
**And** une action impossible est désactivée avec sa raison (retirer à 4 chevaux, 4ᵉ base, imposer au-delà de la taille).

**Given** « + Ajouter un cheval » ou un écarté touché
**When** la `horse-picker-sheet` s'ouvre
**Then** elle liste les partants analysés non retenus (dossard, nom, top 4 estimé) ; un tap ajoute le cheval (taille +1, le `size-stepper` suit, plafond 20)
**And** les partants non analysés sont grisés « à analyser », non sélectionnables ; « Analyser » renvoie à Liste des partants (FR-22).

**Given** « Saisir ma propre sélection »
**When** l'utilisateur coche de 4 à 20 chevaux et touche « Évaluer ma sélection »
**Then** sa sélection remplace celle du modèle, passe en « Modifiée » et est évaluée (confiance, arrivée dans la sélection, systèmes, échanges suggérés)
**And** moins de 4 cases cochées laisse le bouton désactivé avec sa raison.

**Given** une sélection retouchée
**When** elle est recalculée
**Then** l'étiquette « Modifiée » apparaît en tête de section, avec 1 à 2 échanges suggérés (« Échanger n° 8 contre n° 3 : +2 pts d'arrivée dans la sélection » + « Appliquer ») ou aucun s'il n'en existe pas, et « Revenir au pronostic du modèle » qui annule toutes les retouches
**And** un cheval ajouté porte « Ajouté par vous »
**And** les retouches (imposés, retirés, non-partants) sont conservées comme contraintes quand la taille change ; une taille qui ne peut plus les contenir est refusée par le stepper avec sa raison.

**Given** un cheval marqué non-partant, hors ligne compris
**When** le pronostic est recalculé localement (FR-23)
**Then** le cheval sort du champ sélectionnable, le modèle le remplace pour garder la taille, et le bandeau « Non-partant : n° 7 — pronostic recalculé » s'annonce une fois puis disparaît au recalcul suivant
**And** une base marquée non-partante perd son rôle de base, et le bandeau le dit
**And** « Annuler non-partant » dans la feuille du cheval revient en arrière.

**Given** un rafraîchissement explicite de la course avec réseau
**When** le backend signale des non-partants (champ `non_partant`, story 5.5)
**Then** ils sont appliqués comme un marquage manuel, avec le même bandeau
**And** sans réseau, le rafraîchissement échoue avec un message clair et le marquage manuel reste possible (FR-15).

### Story 5.15: Retenir son pronostic, même hors ligne (sqflite v2, gel au départ, purge 90 j, dernière taille)

En tant que turfiste,
je veux retenir le pronostic que je compte suivre, le remplacer jusqu'au départ et retrouver ma taille et mes seuils habituels,
afin d'avoir sur mon téléphone, sans compte et sans réseau, la seule trace de ce que j'ai décidé.

**Acceptance Criteria:**

**Given** `mobile/lib/data/local/database_helper.dart`
**When** la base passe en version 2 (AD-9)
**Then** `onCreate` crée directement la version 2 et `onUpgrade` migre de 1 à 2 sans perdre les lignes existantes, les deux chemins testés avec `sqflite_common_ffi`
**And** la version 2 ajoute `pronostic_retenu` (clé de course unique, taille, sélection, bases, formule affichée facultative, modifié ou non, `donnees_a`, `retenu_le`, `heure_depart` en UTC, identité du pronostic, colonnes facultatives `arrivee_json` et `arrivee_corrigee_le` pour le débrief), `recommandation_consultee` (clé de course, taille, sélection, bases, niveau de confiance, identité, `consulte_le`) et une colonne facultative `multi_contexte` dans `programme_courses`, pour garder l'éligibilité hors ligne après redémarrage.

**Given** la `multi-action-bar`
**When** l'utilisateur touche « JE RETIENS CE PRONOSTIC », seul CTA plein de l'écran (UX-DR9, FR-28)
**Then** l'app enregistre le pronostic affiché (taille, sélection, bases, formule affichée, heure des données) et le pronostic du modèle à la même taille, puis affiche « Pronostic retenu à 9 h 52 » avec une annonce polie
**And** le CTA devient « Remplacer mon pronostic retenu » ; un nouveau pronostic retenu remplace l'ancien (un seul par course)
**And** avec des règles non vérifiées, le pronostic peut être retenu sans formule
**And** rien n'est envoyé au backend (test avec un client API qui enregistre les appels).

**Given** l'heure de départ (UTC, story 5.2)
**When** elle est passée
**Then** le pronostic retenu est figé : « 🔒 Pronostic figé au départ (15 h 05) » remplace le CTA, les contrôles restent visibles mais désactivés, et toute action échoue avec un message explicite
**And** si l'écran est ouvert au moment du départ, la bascule se fait en direct, avec l'annonce « Départ passé : pronostic figé, lecture seule » et le focus déplacé du CTA vers l'étiquette
**And** si l'heure de départ est inconnue, l'en-tête le dit et le pronostic reste remplaçable jusqu'à la fin du jour de la course (heure de Paris).

**Given** la `tickets-sheet` après une copie réussie (story 5.13)
**When** le pronostic affiché n'est ni retenu à l'identique ni figé
**Then** l'invitation « Retenir ce pronostic ? » (« Retenir » / « Plus tard ») apparaît, n'expire pas et ne retient jamais à la place de l'utilisateur ; « Plus tard » n'enregistre rien (UX-DR7).

**Given** un pronostic retenu qui contient un cheval devenu non-partant
**When** le non-partant est marqué ou reçu (story 5.14)
**Then** un bandeau distinct dit « Votre pronostic retenu contient le n° 7, non-partant » et montre ce que deviennent ses tickets (Multi en 7 → en 6, etc., ou ticket annulé), selon la requalification de la story 5.1 (FR-23, UX-DR11)
**And** l'entrée enregistrée n'est pas réécrite.

**Given** le démarrage de l'application
**When** des entrées ont plus de 90 jours
**Then** elles sont supprimées, sans tâche de fond (test avec horloge injectée) (FR-30).

**Given** `shared_preferences`
**When** l'utilisateur change de taille
**Then** la dernière taille est mémorisée et sert de taille par défaut à la course suivante, plafonnée au nombre de sélectionnables (FR-23, UX-DR3)
**And** l'écran Réglages gagne un groupe « Multi » : seuils élevé et moyen par taille, seuil de course ouverte, seuil de données fragiles, marqués « provisoire » tant que les paramètres du pilote le sont, réinitialisés avec les autres réglages, refusés s'ils sont incohérents (FR-26)
**And** au retour vers le Multi, le pronostic est recalculé localement, sans marquer le classement comme périmé.

### Story 5.16: Le débrief du lendemain (Mes pronostics Multi, arrivée corrigée, Multi en lecture seule)

En tant que turfiste,
je veux retrouver sur l'accueil mes pronostics Multi et voir, après la course, combien de chevaux de l'arrivée ils ont capturés,
afin de juger honnêtement mes choix et ceux du modèle, sans embellissement.

**Acceptance Criteria:**

**Given** l'Accueil et une course éligible du programme
**When** la carte de la course est affichée
**Then** elle porte un `multi-badge` « Multi » (cible ≥ 48dp) (UX-DR1)
**And** un tap ouvre le Multi directement si un classement à jour de cette course est en mémoire (retour → Accueil), sinon la Liste des partants avec « Calculez le classement pour ouvrir le Multi ».

**Given** la section « Mes pronostics Multi » sous le programme
**When** au moins un pronostic a été retenu ou un Multi consulté dans les 90 derniers jours
**Then** une `debrief-row` par course montre la course, la date, la taille, puis deux lignes qui commencent par leur sujet : « Votre pronostic : … » et « Pronostic du modèle : … » (UX-DR10)
**And** sans pronostic retenu, « Votre pronostic : aucun pronostic retenu » ; la section est masquée si elle est vide ; son pied dit « Conservés 90 jours sur ce téléphone ».

**Given** une course non finalisée
**When** l'Accueil est rafraîchi explicitement
**Then** l'app lit l'arrivée par `GET /courses/{id}/multi/eligibilite` (story 5.9) et l'enregistre dans `pronostic_retenu` ; tant qu'il n'y en a pas, la ligne dit « En attente du résultat »
**And** sans réseau, la ligne reste « En attente du résultat » et un message clair dit que le résultat sera lu au prochain rafraîchissement (FR-15).

**Given** une arrivée officielle disponible
**When** le débrief est calculé avec `bilan_arrivee` du moteur Dart (story 5.10)
**Then** chaque ligne dit « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non », pour le pronostic retenu et pour le pronostic du modèle (FR-30)
**And** seule l'arrivée officielle compte ; les ex-aequo et l'arrivée dégradée suivent les règles du pari ; une course sans arrivée exploitable affiche « Aucune arrivée exploitable »
**And** le texte n'a aucune couleur de réussite ni d'échec (ni or ni vert pour « oui »).

**Given** une arrivée corrigée après finalisation (`arrivee_corrigee_le` renvoyé par le backend)
**When** l'Accueil est rafraîchi
**Then** le débrief est recalculé et porte la mention « Arrivée corrigée » (FR-30).

**Given** un tap sur une `debrief-row`
**When** le Multi s'ouvre en état débrief
**Then** l'en-tête montre l'arrivée (4 premiers en dossards) et « 🔒 Pronostic figé au départ (15 h 05) », puis les deux lignes de débrief, puis le pronostic retenu tel qu'enregistré (taille, confiance, sélection, chevaux les plus probables, formule), sans recalcul
**And** les chevaux de l'arrivée portent le texte « Capturé » ; tout est en lecture seule ; la barre ne garde que « Voir les grilles »
**And** TalkBack lit chaque ligne en commençant par son sujet (« Votre pronostic : 3 chevaux capturés sur 4, arrivée dans la sélection : non »).

## Epic 6: Évaluer le pronostic Multi

Marc sait si le pronostic du modèle fait mieux que le marché : les autres méthodes s'affichent à taille égale avec leurs performances mesurées, l'historique est rejoué sans fuite, le pilote fixe les seuils de confiance et les tailles de référence, le modèle est journalisé chaque jour avant le départ, et la mention « modèle en cours d'évaluation » tombe — ou reste — selon les résultats.

### Story 6.1: Données de la dernière course pour la méthode 1 (allocation, rang brut, décodeur de musique, migration Alembic)

En tant que développeur,
je veux que le rang brut, le statut d'arrivée et l'allocation de la dernière course de chaque partant soient ingérés, décodés et exposés,
afin que la méthode 1 s'applique sans que le moteur lise jamais un champ PMU brut.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story (AD-13)
**When** elle est appliquée
**Then** elle ajoute `performances_historiques.rang_brut` (texte : `1`..`9`, `0`, `D`, `T`, `A`, …) et `performances_historiques.statut_arrivee` (texte), facultatifs
**And** la colonne `allocation`, déjà présente et déjà alimentée par `pmu_client.get_historique`, est conservée telle quelle (le cahier Multi §3 la croyait absente) ; les lignes anciennes gardent `NULL`, traité comme « absent ».

**Given** `pmu_client.get_historique` (et `open_pmu_client` pour le backfill, si la source porte ces champs)
**When** une performance passée est lue
**Then** `rang_brut` et `statut_arrivee` sont renseignés depuis `place` et `statusArrivee`, et seul ce module lit ces champs bruts (AD-1).

**Given** `backend/app/data/musique.py` (créé, couche data — AD-6)
**When** il décode une musique (cahier Multi annexe D)
**Then** il renvoie la liste des courses de la plus récente à la plus ancienne (année, rang brut, discipline) et gère le format réel observé, majuscules comprises (ex. `DA21DA2A1ADA1A`)
**And** il est validé sur au moins 30 musiques réelles des fixtures de `backend/tests/fixtures/pmu/` ; une chaîne ambiguë renvoie « indécidable » avec un avertissement, jamais un rang deviné ; `NR` est sauté pour remonter à la course réellement courue ; une lettre d'incident inconnue va au pool « queue » avec avertissement.

**Given** un partant d'une course
**When** le repository calcule ses entrées de méthode 1
**Then** il fournit `dernier_rang`, `derniere_allocation` et `source_rang` : le rang vient de la musique quand elle est lisible, la liste détaillée servant au recoupement ; en cas de désaccord, `source_rang = "musique"` et l'avertissement `rang_desaccord` (cahier Multi §3, piège `NON_PLACE`)
**And** un inédit a `dernier_rang = None`.

**Given** `/courses/{id}/partants`
**When** il répond
**Then** chaque `ParticipationOut` porte `dernier_rang`, `derniere_allocation` et `source_rang`, et le modèle Dart `Horse` les lit, nuls s'ils manquent.

### Story 6.2: Comparateurs méthode 1 et marché en Python et Dart (B0 Python seulement)

En tant que développeur,
je veux les comparateurs méthode 1 (M1), marché (B1) et hasard (B0) dans le moteur, à parité Python/Dart pour M1 et B1,
afin de mesurer le pronostic du modèle contre des références, sans jamais les proposer par défaut.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/comparateurs.py` (créé)
**When** M1 sélectionne (cahier Multi §4.6, annexe C)
**Then** il applique les pools `top3`, `r4`, `r5`, `r6`, `queue`, les règles 1 à 6 dans l'ordre, la variante `nota_cote_la_plus_basse` désactivée par défaut, la cote manquante traitée comme la plus délaissée, l'avertissement `allocation_manquante`, et un pool vide laissé au complément par le classement du moteur
**And** à une taille autre que 12, la sélection porte le marqueur `taille_etendue` (FR-29 : même taille que le pronostic).

**Given** le test 13 du cahier Multi §9
**When** les exemples de l'annexe B.1 et B.3 réconcilié sont rejoués
**Then** la sélection attendue est exacte créneau par créneau, et B.3 brut fait apparaître l'écart attendu.

**Given** B1 (les `v` chevaux de cote la plus basse)
**When** une cote manque dans la course
**Then** B1 n'est pas calculé et renvoie le code `comparateur_marche_indisponible` (FR-29).

**Given** B0
**When** il tire `v` chevaux avec une graine fixée par la clé de course
**Then** deux appels donnent le même résultat (test 15)
**And** B0 n'existe qu'en Python : aucun module Dart ne le contient (test).

**Given** `mobile/lib/engine/multi/comparateurs.dart` (créé)
**When** la section `comparateurs` de `fixtures/multi_cases.json` est rejouée en Python et en Dart
**Then** M1 et B1 donnent les mêmes sélections et explications (NFR-9)
**And** les codes `m1_*`, `comparateur_marche_indisponible`, `taille_etendue` et `hypothese_non_validee` sont déclarés dans `fixtures/multi_codes.json` et ont un libellé dans `libelles_multi.dart`.

**Given** `POST /multi/comparateur` (stratégie `M1`, `B0` ou `B1`, course, taille)
**When** il répond
**Then** il renvoie les choix, leurs explications et `hypothese_non_validee: true`, sous schéma typé (AD-4), sans aucun champ d'argent
**And** `/multi/recommandation` ne renvoie jamais la sélection d'un comparateur.

### Story 6.3: Section « Autres méthodes » à l'écran

En tant que turfiste,
je veux consulter à part, à la même taille que mon pronostic, la sélection de la méthode 1 et celle du marché,
afin de comparer par curiosité sans jamais confondre ces méthodes avec le pronostic du modèle.

**Acceptance Criteria:**

**Given** l'écran Multi
**When** il est rendu
**Then** l'`other-methods-section` est placée entre l'Évaluation et le rappel de jeu responsable, repliée par défaut, avec l'état déplié/replié exposé à TalkBack (UX-DR2, UX-DR8)
**And** elle n'est jamais dépliée ni appliquée par défaut (FR-29).

**Given** la section dépliée
**When** les comparateurs sont calculés sur l'appareil par le moteur Dart (story 6.2), hors ligne compris
**Then** un panneau « Méthode 1 » montre la sélection en dossards et la règle appliquée à chaque cheval, et un panneau « Marché » montre la sienne, chacun avec « hypothèse non validée », à la taille courante du pronostic
**And** la ligne de performance dit « Pas encore assez de courses pour mesurer » tant qu'aucune performance n'est disponible.

**Given** une cote manquante dans la course
**When** la section est dépliée
**Then** le panneau Marché affiche « Comparateur marché indisponible : cote manquante » (UX-DR11).

**Given** des partants sans données de dernière course
**When** la méthode 1 est calculée
**Then** le panneau dit lesquels n'entrent dans aucun critère, et l'avertissement `allocation_manquante` est rendu en libellé
**And** aucun texte de la section ne contient de mot ni de symbole d'argent, et aucun bouton ne remplace le pronostic par un comparateur.

### Story 6.4: Backtest sur la machine de dev (sans fuite, constantes figées, export)

En tant que porteur de projet,
je veux rejouer le pronostic du modèle et les comparateurs sur l'historique, sans aucune donnée postérieure à l'heure de chaque pronostic,
afin de mesurer honnêtement s'il fait mieux que le marché avant de rien afficher.

**Acceptance Criteria:**

**Given** `backend/app/jobs/backtest_multi.py` (créé), adaptateur pilotant configuré par la seule `DATABASE_URL` (AD-11)
**When** il tourne sur la machine de développement contre une copie de la base de production
**Then** il appelle le moteur Multi et `repository.py` comme tout job, en lecture seule (test : aucune écriture en base)
**And** il retient toute course de ≥ 14 partants qui a une arrivée, pas seulement les courses support (cahier Multi §8.1).

**Given** une course rejouée en mode `backfill`
**When** les entrées du moteur sont reconstruites à `donnees_a`
**Then** seules les données antérieures sont lues (historique jusqu'à la veille, cotes finales seulement si le mode les déclare disponibles, sinon B1 et le départage M1 sont marqués `degrade`)
**And** le test 14 passe : supprimer de la base toute donnée postérieure à `donnees_a` ne change pas le pronostic (FR-30).

**Given** le fichier de configuration du backtest
**When** une période de test est demandée
**Then** les constantes dérivées des données (réglages du moteur, quantiles éventuels) sont figées avec leur date `constantes_figees_le`, antérieure au début de la période ; sinon le harnais refuse de tourner
**And** les périodes développement → validation → test sont temporelles, jamais tirées au hasard.

**Given** les stratégies rejouées — `modele` aux tailles demandées, `modele` sans échanges (ablation), M1, M1-structure, B0 et B1
**When** les métriques sont calculées (cahier Multi §8.2)
**Then** le rapport contient le Brier et la courbe de calibration de `p_couverture` comparés au marché, le nombre moyen de chevaux capturés avec la différence appariée contre B1 et son intervalle bootstrap à 95 % (graine fixée), la proportion d'arrivées dans la sélection avec intervalle de Wilson comparée à la loi hypergéométrique, la proportion par niveau de confiance et par taille, l'ablation, et la correction de Holm sur toutes les comparaisons listées
**And** les exclusions sont comptées par cause (cote manquante, arrivée absente, données insuffisantes) ; l'alignement de l'heure des cotes de B1 sur celle du modèle est déclaré.

**Given** la fin d'un backtest
**When** les résultats sont exportés
**Then** un fichier JSON porte un en-tête (versions de `fixtures/multi_versions.json`, `version` du catalogue, empreinte des règles, `constantes_figees_le`, période, commit) et les métriques par stratégie, sans aucun montant ni rapport
**And** deux exécutions identiques donnent le même fichier.

### Story 6.5: Pilote et import en production (multi_parametres_pilote.json, performance_strategie, /multi/performance)

En tant que porteur de projet,
je veux un pilote qui fixe les seuils de confiance, les tailles de référence et l'effectif minimal, et une commande qui importe les résultats en production,
afin que les seuils cessent d'être provisoires et que les performances mesurées deviennent consultables.

**Acceptance Criteria:**

**Given** le harnais de la story 6.4 sur la période de développement
**When** le pilote tourne
**Then** il mesure la variance des métriques et en déduit la taille d'échantillon de la période de test
**And** il propose `seuil_confiance_elevee[v]` et `seuil_confiance_moyenne[v]` pour chaque taille, `seuil_course_ouverte`, `seuil_donnees_fragiles`, les `tailles_reference` et l'`effectif_minimal`, par une règle écrite dans le rapport et validée par le porteur de projet — jamais réglée pour produire plus de « confiance élevée » (garde-fou SM-C3).

**Given** des niveaux de confiance qui ne sont pas ordonnés (élevée > moyenne > faible) sur la période du pilote
**When** le pilote conclut
**Then** les seuils restent `provisoire: true` et le rapport le dit ; aucun réglage n'est fait pendant la période de test.

**Given** les valeurs validées
**When** elles sont écrites dans `fixtures/multi_parametres_pilote.json`
**Then** le fichier porte `provisoire: false`, `fixe_le` et la période du pilote ; la version des paramètres augmente dans `fixtures/multi_versions.json`
**And** les miroirs `parametres.py` et `parametres.dart` sont mis à jour et leurs tests passent (AD-11) ; l'étiquette « seuils provisoires » disparaît alors de l'écran.

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée seulement la table `performance_strategie` (stratégie, version, période, effectif, métriques, `constantes_figees_le`, `importe_le`).

**Given** la commande d'import du module `backend/app/jobs/backtest_multi.py`
**When** elle charge un fichier exporté en production
**Then** elle écrit `performance_strategie` via `repository.py`, seule écrivaine de cette table (AD-10)
**And** importer deux fois le même fichier ne crée pas de doublon ; un fichier sans `constantes_figees_le` ou dont l'empreinte des règles ne correspond pas aux règles en vigueur est refusé avec un message clair.

**Given** `GET /multi/performance`, filtrable par période et par stratégie
**When** il répond
**Then** il ne lit que `performance_strategie` et renvoie, sous schéma typé, l'effectif et les intervalles de chaque métrique, sans aucun champ d'argent (FR-29)
**And** `/multi/backtest` n'est pas construit (différé au passage sur serveur).

### Story 6.6: Journalisation quotidienne avant le départ (immuable, échecs, résultats à la finalisation)

En tant que porteur de projet,
je veux que le backend journalise chaque jour, avant le départ, le pronostic du modèle et les comparateurs de la course support, et en note le résultat après l'arrivée,
afin que l'évaluation prospective repose sur des pronostics impossibles à retoucher après coup.

**Acceptance Criteria:**

**Given** `fixtures/multi_parametres_pilote.json` sans `tailles_reference` ou encore provisoire
**When** le job de journalisation démarre
**Then** il refuse de journaliser et le dit dans le journal (ordre imposé : pilote → seuils et tailles de référence → journalisation, PRD §6.1).

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée `recommandation_multi` (unique par course, stratégie, version de stratégie, mode et taille de référence ; identité du pronostic, `donnees_a`, confiance pour `modele`, `seuils_provisoires`, `degrade`, `cree_le`), `echec_journal_multi` (course, raison, `survenu_le`) et `resultat_recommandation` (une ligne par entrée journalisée : `nb_captures`, `arrivee_dans_selection`, `calcule_le`) — aucune colonne d'argent (AD-10).

**Given** le job `backend/app/jobs/journal_multi.py` (créé), lancé par le scheduler du conteneur `ingestion`
**When** une course support du jour arrive à `MULTI_JOURNAL_AVANCE_MINUTES` (défaut 30) de son départ
**Then** il journalise, en mode `live`, le pronostic `modele` à chaque taille de référence et les comparateurs M1, B0 et B1, avec `donnees_a` strictement antérieur au départ (comparaison UTC, AD-12) (FR-30)
**And** une deuxième exécution ne crée pas de doublon (contrainte d'unicité).

**Given** une entrée de `recommandation_multi`
**When** n'importe quel code du backend tente de la modifier ou de la supprimer
**Then** `repository.py` n'offre aucune méthode pour le faire ; une correction crée une nouvelle `version_strategie`
**And** un non-partant survenu après la journalisation ne réécrit pas l'entrée : son résultat suit la requalification.

**Given** un échec — source indisponible, course support introuvable, départ décalé ou passé, erreur du moteur, cote manquante pour B1
**When** le job ne peut pas journaliser
**Then** il écrit `echec_journal_multi` avec un code de raison, la course est exclue de l'évaluation et l'exclusion est comptée
**And** l'échec n'arrête pas la boucle du scheduler.

**Given** le job de finalisation, une fois l'arrivée définitive dans `multi_course`
**When** il traite les entrées journalisées de la course
**Then** il écrit `resultat_recommandation` avec `bilan_arrivee` (ex-aequo et arrivée dégradée compris), de façon idempotente, en seul écrivain de cette table
**And** si l'arrivée est corrigée (story 5.5), le résultat est recalculé et `calcule_le` mis à jour, sans toucher à l'entrée journalisée.

### Story 6.7: Performances et statut du modèle affichés (seuils définitifs, mention retirée ou maintenue)

En tant que turfiste,
je veux voir les performances mesurées du modèle et des autres méthodes et savoir si le modèle fait mieux que le marché,
afin de savoir quelle confiance accorder au pronostic, sur la foi de résultats et non d'une promesse.

**Acceptance Criteria:**

**Given** `performance_strategie` et la règle de décision du cahier Multi §8.3
**When** le backend construit le contexte Multi
**Then** `statut_modele` vaut `valide` seulement si, sur la période de test gelée et au-delà de l'effectif minimal, l'intervalle à 95 % de la différence avec B1 exclut 0 du bon côté ; `pas_meilleur_que_le_marche` si la période de test est close sans que ce soit le cas, avec l'effectif ; sinon `en_cours_d_evaluation`
**And** la même règle décide, pour chaque comparateur, si « hypothèse non validée » est retirée.

**Given** l'application après un rafraîchissement explicite avec réseau
**When** elle lit `GET /multi/performance` et le contexte Multi
**Then** elle les garde en cache local pour l'usage hors ligne ; sans réseau, les dernières valeurs connues restent affichées.

**Given** la section « Autres méthodes » dépliée
**When** l'effectif d'une stratégie atteint l'effectif minimal du pilote
**Then** sa performance s'affiche avec l'effectif et l'intervalle de confiance (« sur 64 courses ») (FR-29, UX-DR8)
**And** en dessous, la ligne reste « Pas encore assez de courses pour mesurer ».

**Given** un `statut_modele`
**When** l'écran Multi est rendu
**Then** `valide` retire l'étiquette « modèle en cours d'évaluation » ; `pas_meilleur_que_le_marche` la garde et affiche en tête de l'Évaluation le bandeau fort « Évaluation sur 64 courses : le modèle ne fait pas mieux que le marché » (FR-23, UX-DR11)
**And** dans aucun cas le pronostic ne bascule vers une autre méthode (test).

**Given** des paramètres du pilote non provisoires (story 6.5)
**When** la carte confiance et les Réglages sont rendus
**Then** l'étiquette « seuils provisoires » n'apparaît plus et les seuils par défaut sont ceux du pilote (FR-26)
**And** aucun chiffre de performance n'est exprimé en argent ni en rapport.

### Couverture des exigences Multi

| Exigence | Stories |
| --- | --- |
| FR-22 | 5.1, 5.5, 5.9, 5.12, 5.13, 5.14 |
| FR-23 | 5.2, 5.7, 5.10, 5.12, 5.14, 5.15, 6.7 |
| FR-24 | 5.7, 5.10, 5.12 |
| FR-25 | 5.6, 5.7, 5.9, 5.10, 5.11, 5.13 |
| FR-26 | 5.8, 5.11, 5.12, 5.15, 6.5, 6.7 |
| FR-27 | 5.8, 5.11, 5.12 |
| FR-28 | 5.7, 5.9, 5.14, 5.15 |
| FR-29 | 6.2, 6.3, 6.5, 6.7 |
| FR-30 | 5.7, 5.12, 5.15, 5.16, 6.4, 6.6 |
| UX-DR1 | 5.12, 5.16 |
| UX-DR2 | 5.12, 5.13, 6.3 |
| UX-DR3 | 5.12, 5.15 |
| UX-DR4 | 5.12 |
| UX-DR5 | 5.12, 5.14 |
| UX-DR6 | 5.12 |
| UX-DR7 | 5.13, 5.15 |
| UX-DR8 | 5.12, 6.3, 6.7 |
| UX-DR9 | 5.15 |
| UX-DR10 | 5.16 |
| UX-DR11 | 5.12, 5.13, 5.14, 5.15, 6.3, 6.7 |
| UX-DR12 | 5.3, 5.12 |
| UX-DR13 | 5.11, 5.12, 5.13 |
