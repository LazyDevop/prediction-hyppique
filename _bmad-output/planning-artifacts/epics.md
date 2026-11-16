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
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-10-18.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-11-15.md
  - _bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/brainstorm-intent.md
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/multi.html
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/connexion.html
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/offres-paiement.html
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/mes-appareils.html
  - _bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/web-compagnon.html
---

# prediction-hyppique - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for prediction-hyppique, decomposing the requirements from the PRD and the Architecture Spine into implementable stories. Epics 1 to 4 used `docs/cahier_des_charges_app_mobile.md` §7 as their UX reference; since 2026-10-18 the UX contract `DESIGN.md` + `EXPERIENCE.md` (final) governs every screen, the Multi module included. Epics 5 and 6 were revised by the course correction of 2026-10-18 (`sprint-change-proposal-2026-10-18.md`). Epics 7 to 12 were added by the course correction of 2026-11-15 (`sprint-change-proposal-2026-11-15.md`, from `brainstorm-intent.md`): the product becomes a paid, multi-user service launched in Cameroon; the Alembic story moved from Epic 5 to story 7.1, and the epics were then aligned with the PRD, the Architecture Spine and the UX contract updated the same day (published forecasts, tier access matrix, AD-9, AD-10, AD-12 to AD-21).

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

FR-22: Éligibilité d'une course au Multi : le Multi figure dans la liste des paris PMU de la course (plusieurs courses par jour ; seuil de partants seulement si les règles vérifiées le fixent ; Mini Multi hors périmètre ; ni course support unique ni mode exploration — D quater) ; raison affichée si non éligible ; courses hors ingestion sans Multi ; règles du pari en source unique datée (sans date de vérification, aucune grille) ; partants non analysés ou sans dossard signalés et non sélectionnables ; dossards en double bloquants.
FR-23: Pronostic du modèle pour la taille choisie par l'utilisateur (4 à 20, défaut : dernière taille sinon 10) — sélection qui maximise la probabilité de couverture ; aucun budget/mise/montant ; mention « modèle en cours d'évaluation » ; identique backend/appareil (égalités à 1e-9 départagées par règles) ; avertissement « données fragiles » ; calcul local hors ligne, y compris après redémarrage (partants en cache) ; non-partant par rafraîchissement (relecture à la demande) ou « marquer non-partant », retiré du champ et recalculé par le moteur de scoring (ou, sur un pronostic publié, probabilités publiées renormalisées et étiquetées « ajusté », FR-53), avec requalification du pronostic retenu.
FR-24: 3 bases candidates « chevaux les plus probables », calculées sur la sélection sans base ; aucune active au premier affichage ; activer = imposer, désactiver = interdire ; chacune affiche probabilité estimée, tickets économisés et couverture perdue.
FR-25: Systèmes de tickets vérifiés pour chaque formule (4 à 7) : tickets, tickets physiques, garantie de couverture, grilles en dossards, sans aucun coût ; texte de garantie imposé ; catalogue ≤ document (sauf coquilles) ; vérification d'un système saisi ailleurs ; formule par défaut Multi en 7 ; export texte des grilles.
FR-26: Indice de confiance « élevée / moyenne / faible » avec ses raisons (couverture, ouverture de la course, fragilité des données) ; jamais « jouer / passer » ni montant ; seuils par taille, réglables et persistés, « provisoires » jusqu'au pilote ; aucune donnée de presse.
FR-27: Explications en codes + valeurs (jamais de phrases figées) : chaque cheval retenu (probabilité estimée, transparence, contribution), les 3 écartés les plus proches, bases, systèmes, indice ; limites des données dites ; probabilités présentées comme estimations ; pas de badge de value dans le Multi.
FR-28: Choix de l'utilisateur : taille, retirer/ajouter un cheval analysé, imposer, marquer non-partant, saisir sa propre sélection (évaluée, échanges suggérés) ; sélection « modifiée » ; coût d'une imposition en couverture ; « Je retiens ce pronostic » (un par course, remplaçable jusqu'au départ puis figé, seule source du débrief).
FR-29: Comparateurs à part et à taille égale (méthode 1 du document source, marché) avec « hypothèse non validée » ; performances seulement au-delà d'un effectif minimal, avec effectif et intervalle ; marché non calculé si une cote manque ; tirage au hasard journalisé seulement ; jamais par défaut.
FR-30: Évaluation (probabilité de couverture, distribution des chevaux capturés, aucun rapport) ; journalisation quotidienne avant départ aux tailles de référence, immuable, échecs journalisés ; backtest sans fuite (constantes figées et datées) ; pronostic retenu conservé 90 jours sur l'appareil et synchronisé avec le compte (FR-38) ; débrief « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non » pour le pronostic retenu et celui du modèle, ex-aequo/arrivée dégradée/corrections gérés.

*Lancement payant (PRD §4.12 à §4.15, mise à jour du 2026-11-15) :*

FR-31: Inscription et connexion par numéro de téléphone et code à usage unique (SMS ou WhatsApp), sans mot de passe — code de 5 minutes, 5 essais, demandes limitées par numéro et par IP ; même message que le numéro ait un compte ou non ; acceptation des conditions dans leur version en vigueur à l'inscription (§6.1).
FR-32: Code PIN de 4 à 6 chiffres qui déverrouille l'app sur l'appareil — verrouillage en arrière-plan et après inactivité ; jamais transmis au serveur ; 5 codes faux effacent la session.
FR-33: Session sécurisée — jeton d'accès de 15 minutes, jeton de renouvellement lié à l'appareil et remplacé à chaque usage ; réutilisation d'un jeton remplacé = révocation des sessions de l'appareil.
FR-34: Profil et email de secours vérifié par lien ; rappel non bloquant pour un compte payant sans email vérifié.
FR-35: Récupération du compte et changement de numéro par l'email vérifié — délai de sécurité de 24 à 48 h, alertes à l'ancien numéro et à l'email avec annulation en un geste ; droits et données suivent le compte.
FR-36: Mes appareils et limite d'appareils — chaque navigateur compte ; nouvel appareil par code ou approbation (FR-37), alerte SMS et mention dans Mes appareils ; au-delà de la limite du palier, nouvel appareil bloqué sans déconnecter les autres, avec Duo ou retrait proposés.
FR-37: Appairage de la web app par QR code (2 minutes, usage unique) scanné et approuvé par le téléphone connecté ; compte dans la limite d'appareils ; connexion par code aussi possible sur le web.
FR-38: Synchronisation des courses suivies, réglages et pronostics retenus entre appareils — hors ligne préservé ; la version d'un pronostic retenu qui l'emporte est la dernière reçue par le serveur avant le départ ; aucune fonctionnalité propre au web.
FR-39: Paliers Gratuit, Turfiste, Expert et matrice d'accès par exigence — le serveur ne renvoie jamais un champ que le palier n'autorise pas (absent, pas masqué) ; droit expiré = retour au Gratuit sans perte des données synchronisées.
FR-40: Aperçu pour le palier Gratuit (et Turfiste sur H-10) — nombre de chevaux qui ont changé de rang, instantané et palier qui le débloque ; aucun nom, dossard ni probabilité transmis.
FR-41: Offres (pass journée Expert 24 h, pass semaine et mensuel Turfiste ou Expert, Duo) — prix et durées en configuration ; rappel de jeu responsable, aucune promesse de gain ; chaque offre dit ce qu'elle débloque dans les termes de l'écran d'origine.
FR-42: Paiement MTN MoMo / Orange Money via un agrégateur — droit activé seulement par la notification signée vérifiée puis confirmée par requête de statut, idempotent sur la référence ; « Paiement en attente de confirmation » ; une confirmation tardive active le droit sans redémarrage.
FR-43: Offre Duo (2 ou 3 personnes, chacune son compte) pour chaque palier payant et chaque durée — les membres bénéficient du droit du titulaire, aucun droit propre n'est créé pour eux, le plus haut palier l'emporte ; membre retiré ou droit du titulaire expiré = retour au Gratuit.
FR-44: Droits disponibles hors ligne jusqu'à la date de fin d'une preuve signée par le serveur, jamais au-delà ; après expiration, le contenu payant en cache est masqué.
FR-45: Quota d'import photo par palier et par période, en plus de la limite journalière globale — compteur visible avant l'import, quota épuisé sans appel au fournisseur de vision.
FR-46: Écrans payants protégés sur Android (Résultats, combinaisons, Multi et ses grilles : capture noire) ; web non protégé, assumé ; export texte et copie des grilles portent l'identifiant court du compte.
FR-47: Back-office sur une adresse distincte, double authentification obligatoire pour le personnel.
FR-48: Rôles agent, superviseur, administrateur — accès refusé et journalisé hors du rôle.
FR-49: Toute modification d'un agent attend la validation d'un superviseur et n'entre dans aucun calcul avant ; personne ne valide sa propre saisie.
FR-50: Licence manuelle par un administrateur avec motif et validation d'un second administrateur ; journal d'audit en ajout seul, chaîné ; rapprochement quotidien des droits (SM-5 = zéro).
FR-51: Pronostic du matin publié chaque jour pour chaque course française (probabilité et rang) — version du modèle, heure des données, « modèle en cours d'évaluation » ; publié avant la première course, journalisé, jamais réécrit ; « pronostic indisponible » sinon.
FR-52: Instantanés de cotes à H-60, H-30, H-15 et H-10 avec pronostic recalculé — l'app reçoit le plus récent autorisé par le palier à l'ouverture et au rafraîchissement explicite ; heure affichée ; instantané manquant jamais inventé ; jamais réécrit.
FR-53: Le pronostic publié est le jeu affiché par défaut ; le moteur de scoring réglable est le mode expert (Expert seulement), toujours étiqueté ; value, mise, combinaisons et Multi calculés sur l'appareil depuis le jeu actif ; course sans pronostic publié calculée par le moteur de scoring, et l'écran le dit.

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
NFR-12 (lancement payant): Le serveur seul décide des droits — chaque route vérifie la session et le droit actif ; une app modifiée ne débloque aucune donnée réservée (architecture AD-15).
NFR-13 (lancement payant): Transport chiffré — HTTPS partout ; CORS limité aux origines de la web app et du back-office ; débit limité par compte et par adresse IP (AD-21).
NFR-14 (lancement payant): Minimisation des données — aucun numéro de carte, code PIN ni code OTP en clair côté serveur ; comptes et paiements séparés des données de courses ; sauvegardes chiffrées (AD-19).
NFR-15 (lancement payant): Aucun secret dans les binaires — la règle NFR-5 couvre aussi l'agrégateur de paiement et le fournisseur de codes SMS, dans l'APK comme dans la web app (AD-21).
NFR-16 (lancement payant): Données personnelles conformes à la loi camerounaise applicable (périmètre exact : consultation juridique, PRD §9.2).

### Additional Requirements

*Issues de l'Architecture Spine (`ARCHITECTURE-SPINE.md`) :*

- Paradigme hexagonal déjà en place (AD-1) : `engine/` (Python et Dart) ne dépend jamais de `data/`, `api/`, ni d'aucune lib réseau/HTTP ; `data/*_client.py` sont les seuls modules à connaître leur format externe.
- Parité moteur backend/mobile appliquée par fixtures JSON partagées à la racine du dépôt (AD-2) : `fixtures/engine_cases.json` (cas de test + paramètres par défaut canoniques) et `fixtures/engine_constants.json` (tables terrain/niveau/incidents/récence) — chargées par les deux suites de tests et les deux objets de paramètres par défaut, jamais dupliquées à la main. Carve-out explicite : les paris Monte-Carlo ne sont comparés qu'en tolérance statistique, jamais en égalité exacte entre langages.
- `vision_client.py` (à créer) isolé comme seul module connaissant le format Anthropic Claude, avec un compteur d'appels journalier configurable (`VISION_DAILY_CALL_LIMIT`) qui bloque et log plutôt que de continuer silencieusement (AD-3). Fournisseur choisi en session, jamais sourcé du PRD/cahiers — modèle exact à revérifier avant implémentation.
- Réponses API toujours construites depuis leur schéma Pydantic déclaré, jamais un `.__dict__` brut (AD-4) — **corrige une violation déjà présente** dans `routes_analyse.py` (`/analyse` actuel), à corriger dans la story qui touche cet endpoint.
- `terrain`/`niveau` voyagent en labels français canoniques (jamais des floats pré-résolus), résolus au point d'usage via une table miroir de chaque côté ; un label non reconnu doit être un signal distinct (loggé), jamais confondu avec une valeur réellement absente (AD-5) — `niveauCoefficient()` manque actuellement côté mobile.
- Déploiement : à l'origine 2 services self-hosted (`api`, `ingestion`) partageant un volume SQLite ; depuis, `cotes`, `pronostics` et `rebuild` s'y sont ajoutés, puis (2026-11-15) `backoffice` et le processus de rapprochement, sur PostgreSQL derrière un proxy TLS (AD-19, AD-21) ; publication sur le Play Store requise pour le lancement payant (story 7.7) ; aucun CI/CD ni environnement de staging (différé, rythme bootstrap).
- Différé explicitement (ne pas construire dans ces epics) : valeur exacte de `VISION_DAILY_CALL_LIMIT`, calibration par quantiles du niveau depuis l'allocation, désambiguïsation des homonymes de chevaux. L'architecture compte/paiement/multi-utilisateur, d'abord différée ici, a été levée le 2026-11-15 : voir AD-15 à AD-21.

*Issues de `deferred-work.md` (dette connue, non liée à cette planification mais à corriger dans les epics concernés) :*

- `routes_analyse.py` : bug des outsiders virtuels dans `/analyse` déjà corrigé (résolu, pour mémoire).
- `combinatoire.py` : couverture de tests déjà ajoutée (résolu, pour mémoire).
- `analyse_course`'s `params` dict sans validation de clés (mistype silencieusement ignoré, valeurs hostiles non validées) — à traiter si une story touche la validation d'entrée API.

*Module Multi — issues de l'Architecture Spine (AD-6 à AD-13, mise à jour 2026-10-17/18) et du cahier Multi v3 :*

- **Prérequis bloquant (PRD §9.5)** : vérifier les règles du pari Multi sur pmu.fr et les dater dans `fixtures/multi_regles.json` avant toute story de développement Multi.
- AD-6 : `engine/multi/` (Python) et `mobile/lib/engine/multi/` (Dart) consomment la sortie du moteur de scoring + un « contexte Multi » de course fourni par le backend et mis en cache ; le téléphone calcule toujours localement et n'appelle jamais `/multi/recommandation` ; comparaisons quantifiées à 1e-9 ; plafond d'itérations partagé ; B0 en Python seulement ; décodeur de musique dans la couche data ; cas partagés `fixtures/multi_cases.json`.
- AD-7 : générateur de systèmes hors ligne (`scripts/generer_catalogue_multi.py`, PEP 723, `uv`, `scipy==1.18.1` épinglé) → catalogue de référence `fixtures/multi_catalogue.json` (en-tête versionné) + copies identiques octet à octet dans `backend/app/engine/multi/` et `mobile/assets/` ; relabellement canonique indices → dossards ; revérification avant affichage ; aucune génération à l'exécution ; règles dans `fixtures/multi_regles.json` avec date de vérification obligatoire.
- AD-8 : registre `fixtures/multi_codes.json` (codes + paramètres) ; tests : moteurs n'émettent que des codes déclarés, l'app a un libellé pour chacun ; table Dart code → phrase française pour le MVP.
- AD-9 : `hippique_cache.db` version 2 (cache de course : clé, contexte Multi, partants) puis version 3 (`pronostic_retenu`, `recommandation_consultee`, instantané suffisant au débrief) : `onCreate` direct en dernière version + chaque `onUpgrade` testé ; figé au départ (UTC), ou fin du jour de Paris si l'heure est inconnue ; purge > 90 jours au démarrage ; dernière taille et seuils par taille dans `shared_preferences`. Amendé le 2026-11-15 : le pronostic retenu, les courses suivies et les réglages sont ensuite synchronisés avec le compte (version gagnante = dernière reçue par le serveur avant le départ, version refusée jamais supprimée localement, `synchronise = false`) ; chaque réponse de course en cache porte `palier_recu`, lu avec la matrice `fixtures/acces_paliers.json`.
- AD-10 : tables serveur françaises via `repository.py`, un seul écrivain par table (`multi_course` éligibilité + arrivée, `recommandation_multi` immuable unique par taille de référence, `echec_journal_multi`, `resultat_recommandation`, `performance_strategie`) ; journalisation quotidienne dans le conteneur `ingestion`, après le pilote, pour chaque course éligible, sur le **jeu publié** de l'horizon le plus proche (jamais de relecture des cotes ni de recalcul des probabilités) ; rafraîchissement à la demande réservé à l'Expert ; `participations.non_partant` et `musique` ; table `correction_saisie` du back-office appliquée en surcouche par `repository.py` à la lecture, jamais lue ni écrite par l'ingestion (amendé le 2026-11-15).
- AD-11 : harnais de backtest/pilote dans `backend/app/jobs/`, configuré par `DATABASE_URL`, d'abord sur la machine de dev (copie de la base) avec export puis import des résultats en production ; `fixtures/multi_parametres_pilote.json` (seuils de confiance par taille, tailles de référence, effectif minimal, drapeau provisoire) ; `/multi/backtest` seulement au passage sur serveur.
- AD-12 : course identifiée par sa clé PMU (date, réunion, course) ; identité de pronostic (clé de course, versions moteur/catalogue/règles, empreinte des paramètres, heure des données) via `fixtures/multi_versions.json` ; toutes les heures en UTC ISO-8601 avec décalage ; l'identité porte aussi `source_probabilites` (`{type: "publie", modele_version, horizon}` ou `{type: "expert", parametres_hash}`) ; la migration PostgreSQL convertit les instants en `timestamptz` et corrige les heures naïves restantes (`cotes_instantanees.pris_le`/`cote_direct_le`, `routes_pronostics.maintenant()`) (amendé le 2026-11-15).
- AD-13 : migrations du schéma serveur par Alembic 1.20.0 (`backend/alembic/`), baseline tamponnée sur la base de prod, `upgrade head` au démarrage du service `api` uniquement, plus de `create_all` sur une vraie base, test de concordance modèles/migrations. Amendé le 2026-11-15 : story 7.1 (ex-5.4), dont la première tâche vérifie PostgreSQL, son pilote Python et le proxy TLS sur le VPS de production (SSE2 seulement) ; aucun processus autre que l'étape de démarrage de `api` ne migre (`ingestion`, `cotes`, `pronostics`, `rebuild`, `build_features`, `purge_open_pmu` compris), et cette étape seule utilise `role_migration` ; puis passage unique de SQLite à PostgreSQL avec contrôle du nombre de lignes par table (story 7.2), `pg_dump` avant chaque migration.
- Dette liée (deferred-work.md) : `pmu_client._epoch_ms_to_datetime` produit des heures naïves (fuseau du conteneur) — à corriger avant le gel au départ, la journalisation « avant départ » et le backtest du Multi.
- Différé (spine) : taille du catalogue à mesurer, outillage de traduction Flutter (après MVP), backtest sur serveur, sauvegardes régulières hors migration et supervision du journal Multi, environnement de test local aligné sur la prod (Python 3.12 / NumPy 1.26.4). Décidé le 2026-10-18 : horaire du journal (T−30 min), recontrôle de l'arrivée (3 jours), copie SQLite à chaque migration (3 conservées).

*Lancement payant — issues de l'Architecture Spine (AD-3, AD-9, AD-10, AD-12 à AD-14 amendés, AD-15 à AD-21 ajoutés le 2026-11-15) :*

- AD-3 étendu : quota d'import photo par compte et par palier, vérifié par la route d'extraction avant `vision_client`, compteur dans le schéma des comptes incrémenté dans la même transaction que le contrôle.
- AD-14 (gate A, active) : le jeu publié de l'horizon le plus récent autorisé par le palier est le jeu de probabilités actif par défaut ; le moteur de scoring Dart aux paramètres par défaut est le repli de tout palier payant ; les coefficients réglables sont le mode expert, Expert seulement ; value, Kelly, combinaisons et Multi calculés sur l'appareil depuis le jeu actif ; un non-partant marqué à la main renormalise les probabilités publiées (« ajusté »). Charge utile typée `pronostic_publie` (`horizon`, `modele_version`, `donnees_le`, `en_evaluation`, `chevaux[{num_pmu, probabilite, rang}]`) et `apercu` facultatif (`chevaux_changes`, `horizon`, `palier_requis`), jamais un tableau de tous les horizons. Stockage en ajout seul (`prediction_runs` variante `ml` + `prediction_chevaux`, seul écrivain `pronostics` ; `cotes_instantanees`, seul écrivain `cotes`), une ligne par (course, horizon, `modele_version`), index unique partiel porté avec `postgresql_where` ; H-2 et `probabilite_fondamentale` internes ; `POST /pronostics` retiré ou rattaché au compte. Gate B (retrait de « modèle en cours d'évaluation ») non atteinte.
- AD-15 : routes classées (publique ; compte + palier ; personnel seulement sur l'hôte du back-office ; interne jamais servie) ; une dépendance unique résout le palier ; réponses construites par palier depuis `fixtures/acces_paliers.json` (matrice de FR-39) et ses miroirs Python et Dart ; preuve de droit signée de façon asymétrique (Ed25519 ou ES256), liée à l'appareil, `expire_le = min(fin du droit, émission + 7 jours)`, garde contre une horloge reculée, version des droits dans chaque réponse ; `FLAG_SECURE` par un widget unique ; risque résiduel d'une APK modifiée accepté (D-5).
- AD-16 : identité par numéro vérifié via `otp_client.py` (WhatsApp préféré), emails via `email_client.py` ; `compte` porte `cgu_version_acceptee`, `cgu_acceptee_le` et `identifiant_court` ; jetons d'accès de 15 minutes, renouvellement lié à l'appareil et tourné à chaque usage ; web : cookie `httpOnly`, `Secure`, `SameSite=Strict` et en-tête anti-CSRF ; navigateur inactif retiré ; contrôle de la limite d'appareils et insertion dans une même transaction verrouillée ; nouvel appareil par code seul sur un compte payant : alerte email et délai de sécurité (SIM swap).
- AD-17 : paiements seulement par webhook signé, vérifié par requête de statut, idempotent ; `droit` en ajout seul (révocation une seule fois), au payeur seulement ; table `offre` modifiée par les administrateurs et journalisée ; rapprochement quotidien dans son propre processus sous `role_api`, avec contrôle des places Duo.
- AD-18 : organisations (personnelle, partagée : Duo puis Club), `membre`, `droit` daté ; palier actif = le plus élevé des droits valides de l'organisation personnelle et de l'organisation partagée ; aucun champ booléen « abonné ».
- AD-19 : PostgreSQL ; schémas `courses`, `comptes` et `audit` séparés (tests SQLite par `schema_translate_map` vers `None`, Alembic `include_schemas=True`) ; un rôle par écrivain — `role_ingestion` (`ingestion`, `rebuild`), `role_cotes` (`cotes`), `role_pronostics` (`pronostics`), `role_api` (lecture des courses, écritures d'ingestion pour l'import, le backfill et le rafraîchissement, `prediction_runs` variante `app` seulement par RLS, comptes, insertion d'audit), `role_backoffice` (lecture du schéma des courses, `correction_saisie`, tables du personnel), `role_migration` ; aucun `UPDATE`/`DELETE` sur `audit.journal_audit`, pronostics publiés et instantanés ; tests de droits sur un vrai PostgreSQL ; sauvegardes `pg_dump` chiffrées par `age` (amendé le 2026-11-16, correctifs du contrôle de préparation).
- AD-20 : back-office = application Flutter Web distincte (`backoffice_web/`) et point d'entrée FastAPI `backend/app/backoffice/main.py` (service `backoffice`, `role_backoffice`) sur `admin.<domaine>` ; `/dashboard*` sort de `api` ; mots de passe Argon2id, TOTP `pyotp` obligatoire, session opaque en cookie `__Host-` (inactivité 30 min, absolue 8 h, CSRF, verrouillage après N échecs) ; rôles agent / superviseur / administrateur, `personnel` séparé de `compte`, corrections `correction_saisie` (liste blanche) validées par un superviseur, licence manuelle à deux administrateurs, `audit.journal_audit` chaîné par empreinte, ajouts sérialisés, tête exportée chaque jour hors de l'hôte (amendé le 2026-11-16).
- AD-21 : proxy TLS Traefik v3 `[À VÉRIFIER sur le VPS]` devant `api` et `backoffice`, hôtes `api.<domaine>`, `app.<domaine>` (web app et `/api` de même origine) et `admin.<domaine>` lus en configuration ; origines autorisées lues en configuration (web app et back-office de même origine que leur API, donc sans CORS avec identifiants) ; limites grossières par IP au proxy, par compte et par numéro dans l'application ; uvicorn ne croit `X-Forwarded-For` que de l'IP fixe du proxy ; limite OTP par IP généreuse (CGNAT) ; restriction d'accès à deux couches jusqu'aux comptes (story 7.8) ; contrôle des binaires sans secret ; épinglage du certificat en V1.1.
- Différé (spine) : fermeture réseau de l'API déployée jusqu'à la story 9.2 — désormais story 7.8 ; sort de `POST /pronostics` (story 11.2) ; chiffrement du cache mobile (accepté non chiffré) ; conservation des données `appareil`, `session`, `journal_audit` (consultation juridique) ; remboursements et rétrofacturations (choix de l'agrégateur) ; valeurs des règles d'accès (configuration) ; référentiel de l'AD-14 (H-30 ou clôture) à trancher par le porteur de projet.

### UX Design Requirements

Epics 1 à 4 : référence `docs/cahier_des_charges_app_mobile.md` §7 et prototypes `analyse_hippique_v2.html` / `analyse_hippique_ia.jsx`. Depuis le 2026-10-18, le contrat UX `DESIGN.md` + `EXPERIENCE.md` (final) fait foi pour toute l'application.

*Module Multi — contrat UX `DESIGN.md` + `EXPERIENCE.md` (final 2026-10-18), maquette `mockups/multi.html` :*

UX-DR1: Accès au Multi — CTA « Multi » en tête de Résultats pour une course éligible ; `multi-badge` sur la carte de chaque course éligible à l'Accueil (ouverture directe si le classement est à jour, sinon Liste des partants) ; badge « Multi indisponible » expliqué au tap.
UX-DR2: Écran Multi en un seul défilement, dans l'ordre : en-tête + « L'outil ne place aucun pari » → `size-stepper` → `confidence-card` → sélection (`multi-row` + 3 écartés) → chevaux les plus probables (`base-chip`) → systèmes (`formula-row`, Multi en 7 par défaut) → `evaluation-block` → `other-methods-section` (repliée) → rappel de jeu responsable ; `multi-action-bar` sous la zone défilante (jamais par-dessus), masquée clavier ouvert, CTA seul au-delà de 130 % de police.
UX-DR3: `size-stepper` 4–20 (défaut dernière taille sinon 10), recalcul après ~800 ms de pause, une seule annonce TalkBack polie si le niveau de confiance change ; bornes désactivées et expliquées.
UX-DR4: `confidence-card` élevée/moyenne/faible + raisons + étiquettes « modèle en cours d'évaluation » / « seuils provisoires » ; or seulement pour « confiance élevée », toujours doublé du texte ; emojis ignorés par TalkBack.
UX-DR5: `multi-row` (dossard, nom, top 4 estimé, contribution, étiquette « Base », sans badge de value) → `multi-actions-sheet` (retirer, imposer, base, marquer non-partant) avec retour de focus défini ; `horse-picker-sheet` pour « + Ajouter un cheval » (non analysés grisés « à analyser ») ; étiquette « Modifiée » et 1–2 échanges suggérés.
UX-DR6: `base-chip` « chevaux les plus probables » (3, aucune active au départ) : interrupteur annoncé avec son effet, tickets économisés et couverture perdue ; vocabulaire « sûr » interdit pour un cheval.
UX-DR7: `formula-row` par formule (tickets, tickets physiques, garantie imposée, probabilité de couverture, aucun coût) + `tickets-sheet` (grilles par ticket physique, base mise en évidence par texte et pas seulement par l'or, lecture TalkBack ticket par ticket, « Copier les grilles » annoncé, invitation à retenir) + `system-entry-sheet` (vérifier un système trouvé ailleurs).
UX-DR8: `evaluation-block` (probabilité de couverture, distribution des chevaux capturés) et `other-methods-section` (méthode 1, marché, « hypothèse non validée », effectif et intervalle).
UX-DR9: « JE RETIENS CE PRONOSTIC » (`cta-primary`, seul CTA plein) → « Pronostic retenu à … » puis « 🔒 Pronostic figé au départ (15 h 05) », gel annoncé et focus géré.
UX-DR10: Section « Mes pronostics Multi » de l'Accueil (`debrief-row`) : masquée si vide, 90 jours, « En attente du résultat » → « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non » (retenu et modèle) → « Arrivée corrigée » ; ouverture du Multi en état débrief (lecture seule), sans couleur de réussite/échec.
UX-DR11: États Multi couverts par `status-banner` et la carte confiance : premier affichage, calcul en cours/erreur, classement modifié, chevaux sans dossard, dossards en double, règles non vérifiées, confiance faible, données fragiles, modèle pas meilleur que le marché, cote manquante, partants non analysés, forme absente du catalogue, non-partant (avec requalification du pronostic retenu), hors ligne.
UX-DR12: Accessibilité transverse (aussi hors Multi) : `line-card` relevée à `rgba(255,255,255,.36)` (≥ 3:1), token `on-gold`, aucune information portée par la couleur seule, cibles ≥ 48dp, chiffres jamais tronqués à 200 %.
UX-DR13: Voix du Multi : tailles en chevaux, systèmes en tickets, aucun mot ni symbole d'argent ; garantie mot pour mot « … au moins un de vos tickets les contient tous » + « Couverture garantie — pas un gain garanti » ; probabilités dites « estimées ».

*Lancement payant — contrat UX `EXPERIENCE.md` (mise à jour du 2026-11-15), maquettes `mockups/connexion.html`, `mockups/offres-paiement.html`, `mockups/mes-appareils.html`, `mockups/web-compagnon.html` (la spine l'emporte en cas d'écart) :*

UX-DR14: Connexion, porte placée avant la pile de navigation — numéro → `otp-field` (6 cases, remplissage automatique du SMS, « Renvoyer le code » avec temps restant) → `pin-pad` ; acceptation des conditions et de la politique de confidentialité à l'inscription (case non cochée) ; même message que le numéro ait un compte ou non ; états code expiré, trop d'essais, trop de demandes ; web : `qr-pairing` ou code SMS (`mockups/connexion.html`).
UX-DR15: Déverrouillage, porte avant la pile — `pin-pad` (touches ≥ 48dp, jamais le clavier système, « 3 chiffres sur 4 saisis »), 5 essais, « Code oublié ? » ; « Session effacée — reconnectez-vous par code SMS » au 5e ; pas de Déverrouillage sur le web.
UX-DR16: Profil, par l'icône compte de l'Accueil — numéro, email de secours (vérifié ou non, rappel non bloquant pour un compte payant), palier et date de fin du droit, section Duo, « Mes appareils », « Scanner un QR code », offres, conditions acceptées.
UX-DR17: Mes appareils (`device-row` : type, nom, dernière activité, « Cet appareil », « Nouveau », « Retirer » avec confirmation légère) et Appareil bloqué (« Votre palier permet N appareils, déjà utilisés », « Retirer un appareil », « Découvrir l'offre Duo », aucun appareil déconnecté) (`mockups/mes-appareils.html`).
UX-DR18: Offres (`offer-card` : nom, palier, durée, prix, ce qu'elle débloque dans les termes de l'écran d'origine, offres du verrou touché en tête) et Paiement (MTN MoMo / Orange Money, `payment-status` en trois états textuels, région live polie) ; rappel de jeu responsable sur les deux ; prix seulement sur ces deux surfaces ; aucune promesse de gain, urgence ni compte à rebours (`mockups/offres-paiement.html`).
UX-DR19: Appairage — `qr-pairing` côté web (QR à usage unique de 2 minutes, temps restant écrit, renouvelé à l'expiration, « Se connecter par code SMS ») et, côté téléphone, scan puis feuille d'approbation nommant le navigateur ; QR expiré expliqué des deux côtés.
UX-DR20: Paywall — `locked-feature` remplace en place le contenu non autorisé (libellé de ce qu'il débloque et du palier, « Voir les offres »), jamais flouté ni grisé, regroupé par section, remplacé par le contenu sans redémarrage ; `teaser-banner` (« Le classement a changé à H-10 pour 3 chevaux — palier Expert », un seul par course, tap → Offres, sans compte à rebours).
UX-DR21: Source du jeu de probabilités toujours dite — « Pronostic de 14 h 35 · H-30 », « Pronostic du matin (8 h 00) », « Mode expert — vos réglages », « · ajusté », « Moteur de scoring — pas de pronostic publié pour cette course » ; « modèle en cours d'évaluation » ; instantané manquant et pronostic indisponible dits, jamais inventés.
UX-DR22: Web compagnon — mise en page à deux colonnes (liste des courses, détail), mêmes composants, pas de mode hors ligne et la page le dit, aucune fonctionnalité propre au web (`mockups/web-compagnon.html`).
UX-DR23: Écran protégé — wrapper unique sans token visuel sur Résultats, combinaisons, Multi et `tickets-sheet` (capture noire sur Android), sans message tant que l'utilisateur ne tente rien ; export et copie des grilles portent l'identifiant court du compte.
UX-DR24: États du compte — droit expiré (retour au Gratuit, contenu payant en `locked-feature`, Profil « Droit Turfiste terminé le 22/11 »), hors ligne avec droit valide (« Droit Expert jusqu'au 22/11 (vérifié le 15/11) »), quota photo épuisé, membre retiré d'un Duo, compte payant sans email vérifié, pronostic retenu « non synchronisé ».

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
FR-30: Epic 5 (évaluation affichée, pronostic retenu local, débrief) + Epic 6 (journalisation quotidienne, backtest) + Epic 8 (synchronisation du pronostic retenu avec le compte).
FR-31: Epic 7 (textes légaux, 7.7 ; exposition de `CGU_VERSION`, 7.9) + Epic 8 — inscription et connexion par numéro.
FR-32: Epic 8 — code PIN et verrouillage.
FR-33: Epic 8 — session et jetons.
FR-34: Epic 8 — profil et email de secours.
FR-35: Epic 8 — récupération et changement de numéro.
FR-36: Epic 8 (Mes appareils, limite) + Epic 9 (nouvel appareil sur un compte payant, 9.11).
FR-37: Epic 8 — appairage par QR code.
FR-38: Epic 8 (course suivie, 8.9 ; synchronisation, 8.8) + Epic 5 (envoi du pronostic retenu, 5.20) + Epic 7 (web sans fonctionnalité propre, 7.6).
FR-39: Epic 9 (droits, filtre serveur, preuve hors ligne, verrous) + Epic 11 (filtre des instantanés publiés).
FR-40: Epic 11 — aperçu `apercu` et `teaser-banner`.
FR-41: Epic 9 (catalogue des offres) + Epic 10 (modification par les administrateurs).
FR-42: Epic 9 — paiement Mobile Money.
FR-43: Epic 9 — offre Duo.
FR-44: Epic 9 — droits hors ligne.
FR-45: Epic 9 — quota d'import photo.
FR-46: Epic 9 — écrans payants protégés.
FR-47: Epic 10 — accès séparé et double authentification.
FR-48: Epic 10 — rôles.
FR-49: Epic 10 — validation avant application.
FR-50: Epic 10 (licence manuelle, journal d'audit) + Epic 9 (rapprochement quotidien) + Epic 7 (écrivain du journal d'audit, 7.10).
FR-51: Epic 11 — pronostic du matin publié.
FR-52: Epic 11 — instantanés de cotes.
FR-53: Epic 11 — pronostic publié par défaut, mode expert, « ajusté », Multi sur le jeu actif.

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
**Notes d'implémentation:** Première story = prérequis bloquant (vérification des règles du pari sur pmu.fr, `fixtures/multi_regles.json` daté). Inclut : correction du fuseau horaire de `pmu_client` (AD-12), Alembic (story 7.1, prérequis, déplacée de l'Epic 5 le 2026-11-15) puis `multi_course` (AD-13, AD-10), générateur hors ligne et catalogue copié à l'identique (AD-7), moteur Multi Python + Dart avec `multi_cases.json`, `multi_codes.json`, `multi_versions.json` et table de libellés FR (AD-6, AD-8, AD-12), cache local en versions 2 (course) et 3 (pronostic retenu), purge à 90 jours (AD-9), relecture à la demande des partants et des cotes, bordure `line-card` relevée pour toute l'app (UX-DR12). Un seul epic plutôt que deux : moteur Multi et écran partagés, conception validée de bout en bout. Depuis le 2026-11-15 : l'epic reprend après la story 7.1 ; le Multi est réservé au palier Expert (verrou posé par la story 9.8) ; le pronostic retenu est aussi envoyé au compte (story 5.20, route de la story 8.8) ; le calcul sur le jeu publié et l'identité `source_probabilites` viennent de la story 11.5.

### Epic 6: Évaluer le pronostic Multi
L'utilisateur sait si le modèle fait mieux que le marché : les autres méthodes (méthode 1, marché) s'affichent avec leurs performances mesurées, les seuils de confiance cessent d'être provisoires, et la mention « modèle en cours d'évaluation » tombe — ou reste — selon les résultats.
**FRs couvertes:** FR-29, FR-26 (seuils fixés par le pilote), FR-30 (journalisation quotidienne, backtest).
**Notes d'implémentation:** Comparateurs (M1, B1 ; B0 journalisé seulement), harnais de backtest dans `backend/app/jobs/` d'abord sur la machine de dev avec export puis import en production (AD-11), pilote qui fixe `fixtures/multi_parametres_pilote.json` (seuils par taille, tailles de référence, effectif minimal), puis journalisation quotidienne dans le conteneur `ingestion` (AD-10), pour toutes les courses éligibles du jour, `/multi/performance`. `/multi/backtest` reste différé au passage sur serveur. S'appuie sur l'Epic 5 sans le modifier en profondeur. Depuis le 2026-11-15, la journalisation quotidienne lit le jeu publié de l'horizon le plus proche (AD-10, AD-14 gate A).

### Epic 7: Fondations de sécurité de la plateforme
Le serveur est prêt à porter des comptes et des paiements : API déployée fermée en attendant les comptes, schéma migré par Alembic, PostgreSQL à schémas et rôles séparés, HTTPS seulement, CORS restreint, débit limité, aucun secret dans les binaires, web app compagnon en production, app publiée sur le Play Store.
**FRs couvertes:** NFR-13 à NFR-15 ; amorce de NFR-12 (story 7.8) et de NFR-16 (story 7.7) ; prépare FR-31 à FR-53.
**Notes d'implémentation:** AD-13 (amendé), AD-19, AD-20 (écrivain du journal d'audit), AD-21, AD-3 étendu, AD-15 (restriction réseau différée). Premier epic à réaliser : la story 7.8 et la première tâche de la story 7.1 (vérification de PostgreSQL, du pilote et du proxy sur le VPS SSE2) démarrent tout de suite, en parallèle ; puis la suite de la story 7.1, les stories 7.2 à 7.7, 7.9 (exposition de `CGU_VERSION`, indépendante du Play Store) et 7.10 (écrivain du journal d'audit, après 7.2) ; les Epics 5 et 6 peuvent reprendre après la story 7.1.

### Epic 8: Comptes, connexion et appareils
L'utilisateur crée son compte par son numéro, protège l'app par un code PIN, retrouve son compte s'il change de numéro, gère ses appareils, rattache son ordinateur par QR code et retrouve ses courses suivies, réglages et pronostics retenus partout.
**FRs couvertes:** FR-31 à FR-38 ; UX-DR14 à UX-DR17, UX-DR19.
**Notes d'implémentation:** AD-16, AD-9 amendé, AD-12 (courses nommées par `cle_course`). `otp_client.py` et `email_client.py` suivent AD-1. Le palier est lu par une fonction unique `palier_actif` (story 8.2), remplacée par la résolution des droits à la story 9.1. **Ordre :** 8.1 (après 7.2, 7.4, 7.9 et 7.10), 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, puis 8.9 (suivre une course) avant 8.8 (synchronisation).

### Epic 9: Licences, paliers et paiement Mobile Money
L'utilisateur voit ce que son palier autorise et ce qui lui manque, paie par Mobile Money un pass ou un abonnement, partage son palier par l'offre Duo et garde ses fonctionnalités hors ligne pendant son droit ; le serveur ne renvoie jamais ce que le palier n'autorise pas.
**FRs couvertes:** FR-39, FR-41 à FR-46 ; FR-36 (SIM swap, story 9.11) ; FR-50 (rapprochement) ; NFR-12 ; UX-DR16, UX-DR18, UX-DR20, UX-DR23, UX-DR24.
**Notes d'implémentation:** AD-15, AD-17, AD-18, AD-9 (`palier_recu`), `fixtures/acces_paliers.json` et ses miroirs Python et Dart. La barrière 9.0 (règles de paiement de Google Play, OQ 18) et le catalogue des offres (9.4) précèdent le paiement (9.5). Mise en vente conditionnée aux conditions de PRD §6.1 (avis juridique, Play Store, conditions publiées).

### Epic 10: Back-office — rôles et contrôles internes
Le personnel travaille dans un back-office séparé, avec double authentification, des rôles limités, une validation avant toute modification et un journal d'audit chaîné ; une licence hors paiement exige deux administrateurs ; les offres se modifient et un droit se révoque avec une trace.
**FRs couvertes:** FR-47 à FR-50 ; FR-41 (modification des offres).
**Notes d'implémentation:** AD-20, AD-19 (`role_backoffice`), AD-10 (`correction_saisie` en surcouche, liste blanche), AD-17 (offres, révocation). Application Flutter Web distincte `backoffice_web/` et point d'entrée FastAPI `backend/app/backoffice/main.py` (service `backoffice`), sur `admin.<domaine>`. Écrans (EXPERIENCE.md, sans maquette) : Connexion + TOTP, Tableau de bord, Corrections, Licences manuelles, Offres, Personnel, Journal d'audit. Le tableau de bord (`/dashboard*`) quitte `api` à la story 10.7. **Ordre :** 10.1, 10.2, puis 10.7, 10.3, 10.4, 10.5, 10.6 ; l'écrivain du journal (7.10) est un prérequis.

### Epic 11: Pronostics publiés et instantanés dans l'app
Chaque matin puis à H-60, H-30, H-15 et H-10, le serveur publie pour chaque course un pronostic jamais réécrit ; l'app le montre par défaut avec son heure, à l'horizon le plus récent que le palier autorise, avec l'aperçu de ce qui a changé au-delà ; value, mise, combinaisons et Multi se calculent sur ce jeu ; l'Expert garde un mode expert étiqueté ; un non-partant marqué à la main donne un jeu « ajusté ».
**FRs couvertes:** FR-51, FR-52, FR-53, FR-40, FR-39 (filtre des instantanés) ; UX-DR20 (`teaser-banner`), UX-DR21.
**Notes d'implémentation:** AD-14 (gates A et B, charge utile, stockage), AD-12 (`source_probabilites`), AD-15, AD-10 (journal Multi sur le jeu publié). Epic de lancement. **Ordre :** 11.1 après la story 7.2 ; 11.2 après les sessions de l'Epic 8 (8.1, 8.2) et les stories 9.1 à 9.3 ; 11.3 après 11.2 et la story 9.4 (le `teaser-banner` ouvre Offres) ; 11.4 (partie moteur démarrable tout de suite, partie écran après 11.3) ; 11.5 après les stories 5.14, 5.15, 5.20 et 6.7.

### Epic 12: Renforcement (V1.1)
iOS, contrôle d'intégrité de l'app (attestation Play Integrity, parade du risque accepté en D-5), déverrouillage biométrique, filigrane visible, détection d'usages anormaux, preuves de récupération complémentaires, épinglage du certificat, contrôle des saisies contre la source PMU.
**FRs couvertes:** PRD §6.2 « V1.1 ». Découpage détaillé après le lancement.

## Epic 5: Pronostiquer le Multi d'une course

Depuis les résultats d'une course éligible, Marc obtient sur son téléphone, hors ligne compris, le pronostic Multi du modèle à la taille qu'il choisit — indice de confiance, explications, chevaux les plus probables, grilles vérifiées de chaque formule —, le retouche, le retient, et en voit le débrief le lendemain. Aucune notion d'argent n'existe nulle part dans le module (recadrage du 2026-10-18).

### Story 5.1: Règles du pari vérifiées et datées

En tant que porteur de projet,
je veux que les règles du pari Multi soient vérifiées sur pmu.fr, datées et rangées dans un fichier unique lu par le backend et l'application,
afin qu'aucune grille ni aucun pronostic ne repose sur des règles de 2001-2002 jamais contrôlées.

**Acceptance Criteria:**

**Given** le prérequis bloquant du PRD §9.5
**When** l'équipe planifie les epics 5 et 6
**Then** aucune autre story des epics 5 et 6 (5.2, 5.3 et 5.5 à 5.21, 6.1 à 6.8, y compris les stories techniques 5.2 et 5.3 ; la story 7.1, ex-5.4, relève de l'Epic 7 et n'attend pas cette story) ne démarre avant que cette story soit terminée
**And** cette règle figure en tête de la story et dans le suivi de sprint, où la story est marquée **tâche humaine** (porteur de projet, ou développeur avec sa validation) : un agent de développement ne peut pas l'achever seul.

**Given** le porteur de projet (ou le développeur, avec sa validation) consulte le règlement du Multi sur pmu.fr
**When** il contrôle chaque règle du cahier Multi §2 — formules 4 à 7, nombre de paris par ticket physique, **courses sur lesquelles le Multi est proposé (une seule par jour, ou plusieurs comme le montre la fixture du 15/01/2022 : 19 courses sur 48)**, seuil de partants déclarés (14 ?) et s'il conditionne encore l'offre, **différence entre `MULTI` et `E_MULTI`**, **statut et règles du Mini Multi** (pour mémoire : hors périmètre, D quater), requalification des non-partants, ex-aequo, ordre de l'arrivée dégradée
**Then** `fixtures/multi_regles.json` (créé) contient chaque valeur avec sa `provenance`, et à la racine `date_verification` (date ISO), `verifie_par` et `sources` (URL consultées)
**And** toutes les clés sont en français (AD-7, conventions de nommage).

**Given** une règle de pmu.fr diffère du document de 2001-2002
**When** le fichier est rempli
**Then** il porte la valeur actuelle et une entrée `ecarts_document` (ancienne valeur → nouvelle valeur, source)
**And** les notes de la story listent les sections touchées (cahier Multi §2, annexe A, chiffres de UJ-4)
**And** si le Multi n'existe plus ou si sa mécanique (formules, tickets, garantie) a changé, la story s'arrête sur ce constat et le porteur de projet décide avant toute autre story
**And** le résultat sur l'éligibilité (plusieurs courses par jour, seuil) est reporté dans `fixtures/multi_regles.json` (`eligibilite`: type de pari `MULTI`, `partants_declares_min` ou `null`) ; s'il contredit D quater, la story s'arrête de même.

**Given** les constantes du document conservées pour la seule provenance (cahier Multi §2 v3 : `MISE_UNITAIRE_EUR`, `MULTIPLICATEUR_MAX`, `RAPPORT_MIN`, `COEF_R7`)
**When** elles sont écrites dans le fichier
**Then** elles sont regroupées dans un bloc `provenance_seulement`, jamais affiché
**And** seul le test de cohérence 1 du cahier Multi §9 les lit (`COEF_R7 == {4: 35, 5: 7, 6: 7/3, 7: 1}`), et un test vérifie qu'aucun module du pronostic ne les importe (NFR-8).

**Given** `backend/app/engine/multi/regles.py` (créé, avec `backend/app/engine/multi/__init__.py`)
**When** la suite `backend/tests/test_multi_regles.py` tourne
**Then** chaque constante du module est égale à celle de `fixtures/multi_regles.json`, chargé depuis la racine du dépôt comme `engine_constants.json` (AD-2), et tout écart fait échouer le test
**And** `regles.py` porte `EMPREINTE_REGLES`, le sha256 du fichier canonique, vérifié par le même test (miroir d'exécution, AD-2 et AD-12)
**And** une clé dupliquée ou manquante dans le fichier fait échouer le chargement avec un message explicite
**And** `regles.py` n'importe rien de `data/`, `api/` ni d'une bibliothèque d'E/S (AD-1).

**Given** les fonctions pures `requalifier(ticket, non_partants)`, `combinaisons_payables(arrivee_avec_ex_aequo)` et `regler(tickets, arrivee, non_partants)`
**When** les tests 1 à 5 du cahier Multi §9 tournent
**Then** la table de requalification est vérifiée case par case (formules 4 à 7 × 0 à 4 non-partants et plus), un ex-aequo à la 4ᵉ place donne 2 combinaisons payables, un ex-aequo aux places 1 à 3 en donne une seule, l'arrivée dégradée suit l'ordre {1,2,3,5} → {1,2,4,5} → {1,3,4,5} → {2,3,4,5} puis « aucune combinaison »
**And** `regler` renvoie les tickets touchés avec leur formule effective et les tickets annulés (moins de 4 chevaux restants), sans aucune clé de montant.

**Given** un fichier de règles sans `date_verification` (cas de test)
**When** `regles_verifiees()` est appelée
**Then** elle renvoie `False`, ce qui servira à masquer toute grille (FR-22)
**And** les cas fixes de cette story sont écrits dans la section `regles` de `fixtures/multi_cases.json` (créé), pour être rejoués en Dart à la story 5.14 (NFR-9).

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

Story 5.4 : déplacée en Story 7.1 (prérequis)

### Story 5.5: Savoir si une course est éligible au Multi

En tant que turfiste,
je veux savoir, pour chaque course du programme, si le Multi y est proposé,
afin d'ouvrir le Multi là où il existe et de comprendre pourquoi il est indisponible ailleurs.

**Acceptance Criteria:**

**Given** la fixture `backend/tests/fixtures/pmu/programme_15012022.json` et une journée 2026 complète capturée pour cette story dans `backend/tests/fixtures/pmu/` (programme, plus les participants d'au moins une course MULTI ; si possible un jour où un partant est non-partant), avec au moins une course proposant `MULTI` et une ne proposant que `MINI_MULTI` — capture ponctuelle de moins de 10 appels, notée dans la story (PRD OQ 6)
**When** `pmu_client.get_programme` lit une course
**Then** `CourseInfo.multi_propose` vaut `True` si `paris[].typePari` contient exactement `MULTI` (`E_MULTI` seul ne suffit pas), `False` si la liste est lue et ne le contient pas, `None` si elle est absente ou illisible — jamais `False` par défaut ; `CourseInfo.mini_multi_propose` suit la même règle pour `MINI_MULTI` ; le champ est documenté en commentaire dans `pmu_client.py`
**And** sur la fixture du 15/01/2022, avec le filtre `FRA` par défaut, exactement 15 courses ont `multi_propose = True` (test)
**And** aucun autre module ne lit ce champ brut (AD-1, FR-16).

**Given** `pmu_client.get_participants`
**When** un partant porte le statut non-partant de la source (valeur exacte relevée sur une capture réelle et documentée en commentaire)
**Then** `PartantInfo.non_partant` vaut `True`
**And** les notes de la story disent si `nombreDeclaresPartants` compte les non-partants ; `nb_partants_declares` stocké est toujours le nombre de partants déclarés **non-partants compris**, recalculé si besoin.

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée la table `multi_course` (`course_id` unique, `multi_propose` facultatif, `mini_multi_propose` facultatif, `nb_partants_declares`, `arrivee_json` facultatif, `finalisee`, `arrivee_corrigee_le` facultatif, `donnees_maj_le`, instants en UTC) et ajoute `participations.non_partant` (booléen, faux par défaut) — rien d'autre (AD-10, AD-13).

**Given** le job d'ingestion du programme et des partants
**When** il enregistre une course
**Then** il écrit, via `repository.py` et lui seul (AD-10), `multi_propose`, `mini_multi_propose`, le nombre de partants déclarés et `donnees_maj_le` (instant UTC de la dernière lecture des partants et des cotes)
**And** un partant au statut non-partant de la source a `non_partant = True`.

**Given** une course dont au moins un partant a `non_partant = True`
**When** `repository.get_horses_for_course` et `/analyse` construisent l'entrée du moteur de scoring
**Then** le non-partant est exclu des chevaux et `nb_partants_course` vaut « partants déclarés − non-partants », si bien qu'aucun partant virtuel ne le remplace (AD-6, décision F2)
**And** un cas de `fixtures/engine_cases.json` (ajouté) fixe ce comportement : sur un champ de 16 déclarés dont 1 non-partant et 15 analysés, aucun partant virtuel, probabilités qui somment à 1 ; le test Dart de ce cas est écrit à la story 5.7.

**Given** le job de finalisation (`ingest_resultats_veille`)
**When** l'arrivée d'une course est définitive
**Then** il écrit `arrivee_json` (5 premières places avec ex-aequo, ex. `[{"rang": 4, "nums": [3, 12]}]`) ; tant que la course n'est pas finalisée, la valeur reste `NULL` et n'est jamais inventée ; deux exécutions donnent le même résultat (FR-17)
**And** pour les courses finalisées depuis moins de `MULTI_RECONTROLE_ARRIVEE_JOURS` jours (défaut 3, variable d'environnement), il relit l'arrivée : si elle a changé, il met à jour `arrivee_json` et `arrivee_corrigee_le` et journalise la correction ; sinon il ne modifie rien.

**Given** `repository.get_multi_contexte(course)`
**When** il construit le contexte Multi d'une course (AD-6)
**Then** le contexte porte `cle_course` (`AAAAMMJJ-Rn-Cn`, AD-12), `eligible`, `raison` (`multi_non_propose`, `mini_multi_non_pris_en_charge`, `paris_inconnus`, `moins_de_n_partants` avec `n` et le nombre — seulement si `regles.py` fixe un minimum —, ou rien), `nb_partants_declares`, les dossards non-partants, `donnees_a` (UTC), `statut_modele` (`en_cours_d_evaluation`) et `seuils_provisoires` (`true`)
**And** il n'y a ni `mode_exploration` ni `est_course_support`, ni aucun champ d'argent ; le minimum de partants éventuel vient de `regles.py` (story 5.1), jamais d'un littéral.

**Given** les cas d'éligibilité
**When** les tests tournent
**Then** `MULTI` proposé → éligible ; `MINI_MULTI` seul → `mini_multi_non_pris_en_charge` ; liste lue sans aucun des deux → `multi_non_propose` ; liste absente → `paris_inconnus` ; si `regles.py` fixe 14 et que la course en déclare 13 avec `MULTI` → `moins_de_n_partants` `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
**And** un non-partant survenu après la déclaration ne fait pas perdre l'éligibilité
**And** une course ingérée avant cette story, sans ligne `multi_course`, a la raison `paris_inconnus` jusqu'à sa prochaine ingestion.

**Given** l'API existante
**When** `/courses` et `/courses/{id}/partants` répondent
**Then** chaque `CourseOut` porte `cle_course`, `numero_reunion`, `numero_course` et un objet `multi` typé (`MultiContexteOut`, AD-4), et chaque `ParticipationOut` porte `non_partant`
**And** côté mobile, `mobile/lib/models/multi_contexte.dart` (créé), `CourseSummary` (`cleCourse`, `numeroReunion`, `numeroCourse`, `multi`) et `Horse` (`nonPartant`) lisent ces champs ; un champ absent (ancien backend) donne un contexte nul, que l'app traitera comme « contexte Multi non chargé » ; leur mise en cache locale arrive à la story 5.7.

### Story 5.6: Rafraîchir les partants et les cotes d'une course avant le départ

En tant que turfiste,
je veux pouvoir demander, avant le départ, la relecture des partants et des cotes d'une course où le Multi est proposé,
afin que les non-partants déclarés dans la journée et les cotes récentes arrivent dans mon pronostic.

**Acceptance Criteria:**

**Given** une fonction `rafraichir_partants(repository, course)` (créée dans `backend/app/jobs/ingest_daily.py`)
**When** elle est appelée
**Then** elle relit `pmu_client.get_participants` pour cette seule course et met à jour, via `repository.py`, les cotes, `non_partant` et `multi_course.donnees_maj_le` (UTC) ; elle ne relit ni le programme ni l'historique
**And** la même fonction servira au job de journalisation (story 6.7).

**Given** `POST /multi/courses/{cle_course}/rafraichir` (`backend/app/api/routes_multi.py`, créé ; schéma `RafraichissementOut`, AD-4)
**When** la course existe, est éligible, son départ n'est pas passé (heure inconnue : jusqu'à la fin du jour de la course, heure de Paris) et `donnees_maj_le` date de plus de `MULTI_RAFRAICHISSEMENT_MIN_MINUTES` (défaut 5, variable d'environnement)
**Then** la route relit la source, puis renvoie `rafraichi: true`, le contexte Multi (story 5.5) et la liste des partants au format `ParticipationOut`
**And** sinon elle renvoie l'état stocké avec `rafraichi: false` et `raison` (`donnees_recentes`, `depart_passe`) sans appeler la source (test avec un client PMU simulé : deux appels dans la fenêtre → un seul appel à la source).

**Given** une clé mal formée (`^\d{8}-R\d+-C\d+$`), une course inconnue ou non éligible
**When** la route est appelée
**Then** elle renvoie respectivement 422 `cle_course_invalide`, 404, ou 422 `course_non_eligible` avec sa raison.

**Given** une source PMU indisponible
**When** la relecture échoue
**Then** la route renvoie 503 avec le code `source_indisponible`, la base reste inchangée et l'échec est journalisé.

**Given** le scheduler du conteneur `ingestion`
**When** cette story est livrée
**Then** il ne gagne aucune relecture périodique des partants : seuls l'ingestion de 6 h, cette route et le job de journalisation (story 6.7) relisent les partants (décision du 2026-10-18, PRD OQ 6). `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

### Story 5.7: Rouvrir une course hors ligne après redémarrage (cache local v2, rafraîchir la course)

En tant que turfiste,
je veux qu'une course déjà ouverte se rouvre sans réseau même après avoir fermé l'application, et pouvoir rafraîchir ses partants à la demande,
afin de préparer mon pronostic sur l'hippodrome, où le réseau manque.

**Acceptance Criteria:**

**Given** `mobile/lib/data/local/database_helper.dart`
**When** la base passe en version 2 (AD-9)
**Then** `onCreate` crée directement la version 2 et `onUpgrade` migre de 1 à 2 sans perdre les lignes existantes, les deux chemins testés avec `sqflite_common_ffi`
**And** la version 2 ajoute à `programme_courses` les colonnes `cle_course`, `numero_reunion`, `numero_course` et `multi_contexte` (JSON, facultatif), et crée `partants_course` (`cle_course` clé primaire, `course_id`, `contenu_json` = réponse de `/courses/{id}/partants` telle que reçue, `lu_le` UTC).

**Given** `CourseRepository.partants(course)` avec réseau
**When** les partants sont reçus
**Then** ils sont enregistrés dans `partants_course` (remplacement) puis renvoyés
**And** sans réseau ou en cas d'échec, le cache est renvoyé avec sa provenance, et Liste des partants affiche « Partants du 18/10 à 9 h 38 (hors ligne) » ; sans cache, le message d'échec actuel est conservé (FR-15).

**Given** l'application redémarrée sans réseau
**When** l'utilisateur ouvre depuis l'Accueil une course déjà ouverte
**Then** la liste des partants et le contexte Multi viennent du cache, et le classement se calcule sur l'appareil (FR-13, NFR-3)
**And** les modifications manuelles de la liste (ajout, cote modifiée) ne sont pas conservées après fermeture : l'écart avec l'Epic 3 (FR-14) est noté dans les notes de la story. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** un cheval avec `nonPartant = true`
**When** l'adaptateur Dart construit l'entrée de `analyseCourse`
**Then** il l'exclut et passe `nbPartantsCourse` = déclarés − non-partants ; le cas ajouté à `fixtures/engine_cases.json` par la story 5.5 passe en Dart (AD-2).

**Given** une course éligible et le réseau
**When** l'utilisateur touche « Rafraîchir la course » (Liste des partants ; en-tête du Multi à la story 5.16)
**Then** l'app appelle `POST /multi/courses/{cle_course}/rafraichir`, met à jour le cache, les cotes et les non-partants de la liste, et le contexte Multi
**And** si au moins un nouveau non-partant arrive, le classement est recalculé automatiquement avec les mêmes réglages, et Résultats affiche « Non-partant : n° 7 — classement recalculé » au lieu de « Résultat périmé » ; si seules les cotes changent, le classement passe en « Résultat périmé » comme aujourd'hui
**And** `rafraichi: false` est dit en clair (« Données déjà à jour (9 h 38) », « Départ passé : partants figés ») ; sans réseau, « Rafraîchissement impossible hors ligne », le cache reste affiché (FR-15).

**Given** le démarrage de l'application
**When** des lignes de `partants_course` portent sur des courses de plus de 90 jours
**Then** elles sont supprimées (même purge que la story 5.20, horloge injectée en test).

### Story 5.8: Catalogue de systèmes vérifié

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
**And** au chargement, un catalogue dont `version` ne correspond pas à ses entrées est refusé avec le code `catalogue_invalide`
**And** chaque cas du vérificateur (système valide, ticket retiré, sélection trop petite, cheval hors sélection, base oubliée, dossard répété, système plus petit trouvé au catalogue) est écrit dans la section `verification` de `fixtures/multi_cases.json`, entrées et preuves attendues, pour être rejoué en Dart à la story 5.14 (NFR-9).

### Story 5.9: Moteur Multi Python : couverture et sélection pour une taille

En tant que développeur,
je veux le cœur du moteur Multi en Python — probabilités de couverture et sélection du modèle à une taille donnée —, branché sur la sortie du moteur de scoring,
afin que le backend sache, de façon déterministe, quels chevaux maximisent la probabilité que l'arrivée soit dans la sélection.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/modeles.py`, `couverture.py` et `recommandation.py` (créés)
**When** ils sont importés
**Then** ils ne dépendent que de `app.engine` (AD-1)
**And** un adaptateur `depuis_analyse(...)` construit les `ChevalMulti` et le champ (chevaux réels partants + partants virtuels) depuis la sortie du scoring, sans recalculer score, `top4` ni value (AD-6) — test : `top4` identique au scoring.

**Given** la sortie du scoring
**When** l'adaptateur calcule les drapeaux de transparence (FR-27)
**Then** il applique les définitions de la section `constantes_moteur` de `fixtures/multi_cases.json` (créée ici) : `inedit` ; `historique_court` si `0 < nb_perfs < len(RECENCE_STD)` ; `donnees_non_saisies` si `nb_perfs == 0` et non inédit ; `terrain_majoritairement_inconnu` si strictement plus de la moitié des performances utilisées par la forme ont un terrain `NULL`
**And** la longueur de la fenêtre est validée contre `fixtures/engine_constants.json` ; les cas sont écrits dans la section `drapeaux`.

**Given** un cheval sans dossard, ou des dossards en double
**When** le champ est construit
**Then** un cheval sans dossard reste dans le champ mais n'est jamais sélectionnable, et `chevaux_sans_dossard` (`nb`) est émis ; des dossards en double lèvent l'erreur `dossards_en_double` (`nums`) (FR-22). `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** un champ de n chevaux (réels et virtuels)
**When** `couverture.py` calcule `P_ens` sur tous les ensembles de 4 chevaux (énumération exacte Harville, cahier Multi §6.1), `p_couverture(S, B)`, la distribution du nombre de chevaux capturés (0 à 4) et `h_norm`
**Then** le test 8 passe : `Σ P_ens = 1` à 1e-9 ; `E[X] = Σ top4` ; à forces égales, loi hypergéométrique à 1e-9
**And** les partants virtuels entrent dans le champ mais jamais dans une sélection ; un non-partant n'est jamais dans le champ (il a été exclu avant le scoring, story 5.5) et le moteur ne retire ni ne renormalise jamais lui-même une probabilité (AD-6).

**Given** une taille `v`, des bases, des chevaux imposés et des chevaux retirés
**When** `selectionner` applique l'algorithme du cahier Multi §4.1 et l'annexe C
**Then** les comparaisons se font sur des probabilités quantifiées à la grille 1e-9 et les égalités suivent les règles du cahier (`top4` décroissant, puis `p_gagnant`, puis dossard ; échange : dossard entrant puis sortant le plus petit) (AD-6, FR-23)
**And** la recherche d'échanges est bornée par `ITERATIONS_ECHANGES_MAX` (section `constantes_moteur`) ; une recherche tronquée ajoute l'avertissement `optimisation_tronquee`.

**Given** les cas d'erreur
**When** `v < 4`, `v > 20`, `v` supérieur au nombre de sélectionnables, plus de 3 bases, une base hors sélection, un dossard inconnu, ou imposés et bases plus nombreux que `v`
**Then** le moteur lève une erreur portant un code (`taille_hors_bornes`, `taille_superieure_aux_selectionnables`, …), jamais une phrase.

**Given** les tests 9 et 10 du cahier Multi §9
**When** ils tournent
**Then** sur des champs de 10 chevaux au plus, la sélection a la même `p_couverture` que l'optimum exhaustif, et au moins un cas montre que le tri par `top4` seul n'est pas optimal et que les échanges le corrigent
**And** la sélection compte exactement `v` chevaux pour chaque `v` de 4 à `min(20, sélectionnables)` ; `p_couverture` ne décroît pas quand `v` augmente
**And** deux appels identiques donnent le même résultat ; aucune clé `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` n'apparaît (NFR-8)
**And** les cas fixes sont écrits dans les sections `drapeaux`, `couverture` et `selection` de `fixtures/multi_cases.json`, quantifiés, lisibles par Dart (NFR-9).

### Story 5.10: Moteur Multi Python : chevaux les plus probables, systèmes par formule, relabellement

En tant que développeur,
je veux que le moteur Python propose les chevaux les plus probables comme bases et renvoie, pour chaque formule, un système vérifié en dossards,
afin que le pronostic dise quelles bases activer et ce que chaque formule couvre réellement.

**Acceptance Criteria:**

**Given** la sélection sans base à la taille choisie (story 5.9)
**When** les bases candidates sont calculées (FR-24)
**Then** il y en a 3 (moins si la sélection en compte moins), ordonnées par `top4`, `p_gagnant` puis dossard, aucune active par défaut
**And** chacune porte `top4`, les tickets économisés par formule (≥ 0) et la couverture perdue (≥ 0) — test 11.

**Given** une sélection et ses bases actives
**When** `systemes(...)` est appelé (FR-25)
**Then** il renvoie un système par formule `k ≤ v` présente au catalogue (story 5.8), de `k = 7` à `k = 4`, avec `nb_tickets`, `nb_tickets_physiques` (`⌈nb_tickets / 4⌉`), la garantie, la même `p_couverture` pour toutes et les grilles en dossards
**And** le relabellement est canonique (non-bases triées par `top4`, `p_gagnant`, dossard → indices `0..v'-1`) et chaque système est revérifié avant d'être renvoyé ; un système non couvrant n'est jamais renvoyé
**And** une forme absente donne l'avertissement `systeme_absent_du_catalogue` (`{k}`) ; des règles non vérifiées (story 5.1) donnent zéro système et l'avertissement `regles_non_verifiees`.

**Given** toutes les sorties de cette story
**When** les tests de forme tournent
**Then** deux appels identiques donnent le même résultat ; seules des `Explication(code, params)` y figurent ; aucune clé d'argent (NFR-8)
**And** les cas fixes sont écrits dans les sections `bases` et `systemes` de `fixtures/multi_cases.json`, listes complètes de tickets après relabellement (NFR-9).

### Story 5.11: Moteur Multi Python : évaluation, non-partant et bilan d'arrivée

En tant que développeur,
je veux que le moteur Python évalue n'importe quelle sélection, dise ce que deviennent les tickets avec un non-partant et calcule le bilan d'une arrivée,
afin d'expliquer les retouches de l'utilisateur, de requalifier un pronostic retenu et de faire le débrief.

**Acceptance Criteria:**

**Given** une sélection quelconque (dont celle de l'utilisateur)
**When** `evaluer(...)` est appelé (FR-28, FR-30)
**Then** il renvoie `p_couverture`, la distribution des chevaux capturés, la contribution de chaque cheval (baisse de `p_couverture` s'il est retiré), les 3 écartés de plus fort `top4`, 1 à 2 échanges suggérés qui augmentent `p_couverture` (aucun s'il n'y en a pas) et le coût en couverture des chevaux imposés par rapport au pronostic libre à taille égale.

**Given** des tickets et un cheval de la sélection
**When** `simuler_non_partant(...)` est appelé
**Then** il renvoie la formule effective de chaque ticket (requalification de la story 5.1) ou « ticket annulé », sans calculer de nouvelle `p_couverture` (cahier Multi §6.6 : le non-partant réel passe par le moteur de scoring, AD-6). `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** une sélection et une arrivée avec ex-aequo
**When** `bilan_arrivee(selection, arrivee)` est appelé
**Then** il renvoie le nombre de chevaux capturés (maximum sur les combinaisons payables) et « arrivée dans la sélection » selon les ex-aequo et l'arrivée dégradée ; une arrivée inexploitable renvoie le code `arrivee_inexploitable`.

**Given** toutes les sorties de cette story
**When** les tests de forme tournent
**Then** deux appels identiques donnent le même résultat (test 15) ; seules des `Explication(code, params)` y figurent ; aucune clé `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` (NFR-8)
**And** les cas fixes sont écrits dans les sections `evaluation`, `non_partant` et `bilan` de `fixtures/multi_cases.json` (NFR-9).

### Story 5.12: Indice de confiance et explications (Python), registre multi_codes.json, règle provisoire des seuils

En tant que développeur,
je veux que le moteur Python qualifie chaque pronostic par un indice de confiance avec ses raisons et explique chaque élément par des codes déclarés dans un registre,
afin que l'utilisateur sache à quel point se fier au pronostic et pourquoi, sans phrase figée dans le moteur.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/confiance.py` (créé), `p = p_couverture(S, B)`, `h_norm`, les drapeaux de la story 5.9 et `n` = nombre de chevaux du champ (réels partants et virtuels)
**When** l'indice est calculé (cahier Multi §6.4, FR-26)
**Then** le niveau de départ suit les seuils de la taille `v` : un seuil fixé (utilisateur ou pilote) pour `v` s'applique ; sinon la règle provisoire D quater : `p_hasard(v) = C(v,4) / C(n,4)`, `moyenne` si `p ≥ min(max(2 × p_hasard ; 0,15) ; 0,90)`, `elevee` si `p ≥ min(max(3 × p_hasard ; 0,35) ; 0,95)`, sinon `faible`
**And** le niveau baisse d'**un seul** cran si `h_norm ≥ seuil_course_ouverte` **ou** si les données sont fragiles (part des chevaux de la sélection portant `inedit`, `historique_court` ou `donnees_non_saisies` ≥ `seuil_donnees_fragiles`, ou favori fragile : meilleur `p_gagnant` des chevaux réels portant l'un de ces drapeaux ou `terrain_majoritairement_inconnu`) ; il ne descend jamais sous `faible` `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
**And** si la sélection contient tous les chevaux du champ (`p_couverture = 1` par construction), aucun niveau n'est donné et le code `selection_egale_au_champ` est émis. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** tout indice calculé
**When** il est renvoyé
**Then** il porte au moins les raisons `couverture` (`p_couverture`, `taille`, `bases_comprises`), `ouverture_course` (`h_norm`), `donnees` (inédits, historiques courts, données non saisies, cotes manquantes, partants non analysés) et, s'il y a lieu, `favori_fragile` (`num`), ainsi que l'état `seuils_provisoires` et `statut_modele`
**And** la fragilité ajoute l'avertissement fort `donnees_fragiles` (FR-23)
**And** une course non éligible n'a pas d'indice ; aucun code ne dit « course non support », « jouer » ou « passer » ; aucune entrée ne vient de la presse.

**Given** le test 12 du cahier Multi §9
**When** les cas de la section `confiance` de `fixtures/multi_cases.json` tournent
**Then** chaque niveau et chaque abaissement (course ouverte, données fragiles, favori fragile, les deux à la fois = un seul cran) est atteint par au moins un cas
**And** un cas fixe les seuils de la règle provisoire pour n = 16 et n = 14, v = 4 à 16 (ex. n = 16 : v = 10 → 0,2308 / 0,35 ; v = 12 → 0,5440 / 0,8159), quantifiés à 1e-9.

**Given** `fixtures/multi_parametres_pilote.json` (créé)
**When** il est écrit avant le pilote
**Then** il contient `regle_provisoire` (`multiplicateur_moyenne: 2`, `plancher_moyenne: 0.15`, `plafond_moyenne: 0.90`, `multiplicateur_elevee: 3`, `plancher_elevee: 0.35`, `plafond_elevee: 0.95`), `seuil_confiance_elevee[v]` et `seuil_confiance_moyenne[v]` à `null` pour chaque taille de 4 à 20 (= règle provisoire), `seuil_course_ouverte: 0.90`, `seuil_donnees_fragiles: 0.25`, `tailles_reference` et `effectif_minimal` à `null`, `provisoire: true` et une `provenance` qui cite la décision D quater du 2026-10-18 — remplacé par le pilote (story 6.6)
**And** `backend/app/engine/multi/parametres.py` en porte le miroir d'exécution validé par test contre le fichier (AD-2, AD-11), et le contexte Multi de la story 5.5 lit désormais `seuils_provisoires` dans ce miroir.

**Given** des seuils fournis par l'utilisateur
**When** ils sont incohérents (seuil moyen supérieur au seuil élevé, valeur hors de [0, 1], taille absente)
**Then** le moteur lève une erreur codée ; des seuils à `null` prennent la valeur par défaut de la taille (pilote, sinon règle provisoire).

**Given** `backend/app/engine/multi/explications.py` (créé)
**When** le pronostic est expliqué (FR-27)
**Then** chaque cheval retenu porte `retenu_top4` ou `retenu_par_echange` (`top4`, `rang_modele`, hausse de couverture), `contribution` et ses drapeaux de transparence ; chacun des 3 écartés porte sa raison (`ecarte_top4_faible`, `ecarte_donnees_fragiles`, `ecarte_par_vous`) ; chaque base candidate porte `base_candidate` ; chaque système porte `systeme_formule` (`k`, `nb_tickets`, `nb_tickets_physiques`) ; les limites des données portent `cotes_du` (heure UTC), `cote_manquante` (`num`), `partants_non_analyses` (`nb`) et `chevaux_sans_dossard` (`nb`)
**And** aucun code n'exprime une value.

**Given** `fixtures/multi_codes.json` (créé)
**When** les tests du registre tournent (AD-8, NFR-11)
**Then** chaque code émis dans tous les cas de `fixtures/multi_cases.json` (stories 5.8 à 5.12) est déclaré avec exactement ses paramètres, sa famille (raison, explication, avertissement, erreur) et sa force (normale ou forte)
**And** un code non déclaré ou un paramètre en trop fait échouer la suite.

**Given** `fixtures/multi_versions.json` (créé : version du moteur Multi, du registre, des paramètres du pilote) et `backend/app/engine/multi/versions.py`, son miroir d'exécution validé par test (AD-2, AD-12)
**When** `identite_pronostic(...)` est calculée
**Then** elle réunit la clé de course, la version du moteur (lue dans `versions.py`), la `version` du catalogue, `regles.EMPREINTE_REGLES`, l'empreinte sha256 des paramètres canoniques et `donnees_a` (UTC), sans lire aucun fichier de `fixtures/` à l'exécution
**And** un cas partagé fixe l'identité attendue pour la comparer en Dart.

### Story 5.13: API du pronostic Multi (contexte, recommandation, systèmes, vérifier, évaluer)

En tant que développeur,
je veux exposer le moteur Multi par des routes typées,
afin que les jobs du backend et les clients autres que l'application obtiennent le pronostic, ses systèmes et ses vérifications, et que l'application lise l'arrivée d'une course pour le débrief.

**Acceptance Criteria:**

**Given** `backend/app/api/routes_multi.py` (créé à la story 5.6) et `backend/app/schemas/multi.py` (créé), inclus dans `backend/app/main.py`
**When** une route Multi répond
**Then** la réponse est construite depuis son schéma Pydantic déclaré, jamais un `__dict__` (AD-4)
**And** les clés JSON sont en français (`selection`, `bases`, `tickets`, `p_couverture`, `confiance`, `explications`).

**Given** `GET /multi/courses/{cle_course}` (clé PMU `AAAAMMJJ-Rn-Cn`, AD-12)
**When** la course existe
**Then** la réponse porte le contexte Multi de la story 5.5, les dossards non-partants et, si la course est finalisée, l'arrivée avec ses ex-aequo et `arrivee_corrigee_le`
**And** une course inconnue renvoie 404, une clé mal formée 422 `cle_course_invalide`.

**Given** `POST /multi/recommandation` avec `cle_course` (clé PMU `AAAAMMJJ-Rn-Cn`, AD-12 ; jamais `course_id`) ou une liste de chevaux saisis comme `/analyse`, `taille`, `bases_actives`, `chevaux_imposes`, `chevaux_exclus` et `seuils`
**When** la course est éligible
**Then** les non-partants connus du backend sont exclus de l'entrée du scoring (story 5.5) et la réponse suit le cahier Multi §10 : `taille`, `confiance` (niveau et raisons), `pronostic` (sélection avec rôles et explications, `p_couverture`, `distribution_captures`, `h_norm`), `bases_candidates`, `systemes` de toutes les formules, `ecartes`, `statut_modele`, `seuils_provisoires` et l'identité du pronostic
**And** une course non éligible renvoie 422 avec le code `course_non_eligible` et sa raison.

**Given** `POST /multi/systemes`, `POST /multi/verifier` et `POST /multi/evaluer`
**When** ils sont appelés
**Then** `/multi/systemes` renvoie les systèmes vérifiés de toutes les formules pour une sélection et ses bases ; `/multi/verifier` renvoie la preuve de couverture d'un système saisi, ses combinaisons manquantes et, si le catalogue contient un système valide plus petit pour la même sélection, les mêmes bases et la même formule, ce système (FR-25) ; `/multi/evaluer` renvoie `p_couverture`, la distribution, les contributions et les échanges suggérés (FR-28).

**Given** une entrée invalide
**When** `taille < 4`, `taille > 20`, `taille` supérieure aux sélectionnables (l'API refuse, seule l'app ramène au plafond), bases hors sélection, plus de 3 bases, sélection de plus de 20 chevaux, dossard inconnu, dossards en double, `k < 4` ou `k > 7`
**Then** la route renvoie 422 avec le code d'erreur du moteur, jamais une phrase ni une trace technique.

**Given** le schéma OpenAPI de l'application
**When** un test parcourt les schémas de requête et de réponse des routes Multi
**Then** aucun champ `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` n'existe (NFR-8)
**And** chaque explication renvoyée est un code déclaré dans `fixtures/multi_codes.json`
**And** sur les cas partagés, la réponse de `/multi/recommandation` est égale à l'appel direct du moteur.

**Given** l'application mobile
**When** on inspecte `mobile/lib/data/remote/api_client.dart`
**Then** aucune méthode n'appelle `/multi/recommandation`, `/multi/systemes`, `/multi/verifier` ni `/multi/evaluer` : le téléphone calcule toujours localement (AD-6) ; il n'appelle que `GET /multi/courses/{cle_course}` (débrief, story 5.21) et `POST /multi/courses/{cle_course}/rafraichir` (story 5.7).

### Story 5.14: Moteur Multi en Dart à parité (couverture, sélection, bases, systèmes, vérification, catalogue embarqué)

En tant que développeur,
je veux le moteur Multi porté en Dart, à parité exacte avec Python,
afin que le téléphone calcule lui-même le pronostic, hors ligne compris, et donne le même résultat que le backend.

**Acceptance Criteria:**

**Given** `mobile/lib/engine/multi/` (`modeles.dart`, `regles.dart`, `couverture.dart`, `recommandation.dart`, `verification.dart`, `catalogue.dart`)
**When** ils sont compilés
**Then** ils n'importent ni `data/`, ni `providers/`, ni Flutter, ni aucune bibliothèque réseau (test qui parcourt les imports, AD-1)
**And** `regles.dart` est validé contre `fixtures/multi_regles.json`, porte `EMPREINTE_REGLES` (validée contre le sha256 du fichier) et rejoue la section `regles` de `fixtures/multi_cases.json`.

**Given** `mobile/assets/multi_catalogue.json` déclaré dans `mobile/pubspec.yaml`
**When** les tests Dart tournent
**Then** la copie est identique octet à octet à `fixtures/multi_catalogue.json` (AD-7)
**And** au chargement, une `version` qui ne correspond pas aux entrées, ou un fichier absent, donne zéro système avec l'avertissement `catalogue_invalide`, sans empêcher le reste du pronostic.

**Given** chaque cas des sections `drapeaux`, `couverture`, `selection`, `bases`, `systemes`, `verification`, `evaluation`, `non_partant` et `bilan` de `fixtures/multi_cases.json`
**When** la suite `mobile/test/engine/multi/` le rejoue
**Then** la sortie Dart est égale à la sortie attendue : probabilités égales après quantification à 1e-9, mêmes égalités départagées, mêmes listes complètes de tickets après relabellement (NFR-9)
**And** `ITERATIONS_ECHANGES_MAX` est lue et validée contre la même section `constantes_moteur` que Python.

**Given** la sortie du moteur de scoring Dart pour une course (probabilités, `top4`, drapeaux de transparence, partants virtuels)
**When** l'adaptateur Dart construit les `ChevalMulti`
**Then** `top4` et `p_gagnant` sont repris tels quels, jamais recalculés (AD-6) ; les drapeaux suivent les définitions de `constantes_moteur` ; un cheval sans dossard n'est pas sélectionnable et des dossards en double donnent `dossards_en_double`
**And** aucune sortie ne contient de clé d'argent ni de phrase.

**Given** une course de 20 chevaux, taille 12, toutes formules
**When** le pronostic complet est calculé sur l'appareil Android cible
**Then** le temps mesuré est consigné dans les notes de la story (NFR-10, question ouverte PRD §11.1)
**And** s'il n'est pas perçu comme instantané, `ITERATIONS_ECHANGES_MAX` est abaissée dans la fixture, pour Python et Dart ensemble, et l'avertissement `optimisation_tronquee` apparaît dans les cas concernés.

### Story 5.15: Confiance et explications en Dart + table de libellés FR

En tant que développeur,
je veux l'indice de confiance et les explications en Dart, à parité avec Python, et une table qui rend chaque code en français,
afin que l'écran Multi affiche des raisons lisibles, identiques au backend, et que l'anglais puisse s'ajouter plus tard sans toucher au moteur.

**Acceptance Criteria:**

**Given** `mobile/lib/engine/multi/confiance.dart`, `explications.dart`, `parametres.dart` et `versions.dart` (créés)
**When** la suite Dart rejoue les sections `confiance` et `explications` de `fixtures/multi_cases.json`
**Then** niveau, raisons, avertissements et explications sont identiques à Python (NFR-9, FR-26, FR-27)
**And** `parametres.dart` (règle provisoire comprise) et `versions.dart` sont des miroirs d'exécution validés contre `fixtures/multi_parametres_pilote.json` et `fixtures/multi_versions.json` (AD-2) ; l'identité du pronostic du cas partagé, calculée avec `regles.EMPREINTE_REGLES`, est la même qu'en Python (AD-12).

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

### Story 5.16: Écran Multi — accès, taille et confiance

En tant que turfiste,
je veux ouvrir le Multi depuis les résultats d'une course où il est proposé, choisir mon nombre de chevaux et voir la confiance du pronostic,
afin de savoir en un coup d'œil à quel point me fier au pronostic du modèle pour la taille que je choisis.

**Acceptance Criteria:**

**Given** l'écran Résultats d'une course dont le contexte Multi est éligible
**When** le classement est calculé
**Then** un `cta-ghost` « Multi » apparaît sous le titre de la course et ouvre `mobile/lib/screens/multi_screen.dart` (UX-DR1, FR-22)
**And** pour une course non éligible, un `multi-badge` « Multi indisponible » le remplace ; un tap affiche la raison (« Multi non proposé sur cette course », « Mini Multi non pris en charge », « Liste des paris indisponible — rafraîchissez le programme », « Moins de 14 partants déclarés (12) » si les règles fixent ce seuil) ; sans contexte (course saisie à la main ou importée par photo, ancien backend), « Multi indisponible pour une course saisie à la main » ou « Contexte Multi non chargé — rafraîchissez le programme ». `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** l'écran Multi qui s'ouvre
**When** le pronostic est calculé
**Then** il l'est par le moteur Dart via `mobile/lib/providers/multi_provider.dart`, sans aucun appel réseau (test avec un client API qui échoue à tout appel, FR-13, AD-6)
**And** l'en-tête montre la course, « 18 partants · course éligible », « Cotes de 9 h 38 » (`donnees_a`), « Modifiable jusqu'au départ (15 h 05) », l'icône Réglages, « Rafraîchir la course » (story 5.7) et « L'outil ne place aucun pari », puis les bandeaux d'état, la taille, la confiance et, en fin d'écran, le rappel de jeu responsable (UX-DR2, NFR-7) ; les sections suivantes arrivent aux stories 5.17 et 5.18.

**Given** le `size-stepper` au premier affichage
**When** l'écran s'ouvre
**Then** la taille vaut 10, plafonnée au nombre de sélectionnables (analysés, partants, avec dossard unique), avec la ligne « Plafond : 15 partants analysés » (FR-23)
**And** à une borne, le bouton concerné est désactivé, pas masqué, avec sa raison
**And** chaque tap change la valeur tout de suite ; le recalcul part après environ 800 ms sans nouveau tap ; entre-temps, l'ancien état reste affiché atténué, sans résultat intermédiaire (UX-DR3)
**And** le contrôle est un seul nœud ajustable TalkBack (« Taille de la sélection, 12 chevaux, de 4 à 20 ») et une seule annonce polie suit un recalcul, seulement si le niveau de confiance a changé.

**Given** la `confidence-card`
**When** l'indice est affiché (FR-26, UX-DR4)
**Then** elle montre « Confiance élevée », « Confiance moyenne » ou « Confiance faible », les raisons en libellés courts (arrivée dans la sélection estimée, ouverture de la course, données) et les étiquettes « modèle en cours d'évaluation » et « seuils provisoires » quand elles s'appliquent ; sans niveau (`selection_egale_au_champ`), « Confiance : sans objet — la sélection contient tout le champ »
**And** l'or n'est utilisé que pour « Confiance élevée », toujours doublé du libellé ; « Confiance faible » n'est jamais en rouge et ne bloque rien
**And** des données fragiles ajoutent sous la carte le bandeau fort « ⚠️ 4 chevaux inédits ou à historique court dans la sélection » ; les emojis sont ignorés par TalkBack.

**Given** les états de cette story (UX-DR11)
**When** ils surviennent
**Then** chacun a son traitement : calcul en cours (indicateur dans la carte confiance) ; erreur (« Calcul du Multi impossible : {raison} », taille conservée, retour possible) ; classement modifié (« Classement modifié — recalculez sur Résultats », contenu atténué) ; dossards en double (« Dossards en double : n° 7 — corrigez la liste des partants » + « Analyser », aucun pronostic) ; hors ligne identique au mode connecté.

**Given** l'écran de cette story
**When** un test parcourt tous ses textes
**Then** aucun mot ni symbole d'argent n'apparaît (NFR-8, UX-DR13)
**And** à un facteur de police de 2,0, aucun chiffre n'est tronqué ; les titres de section sont des en-têtes TalkBack ; les mentions obligatoires font partie du flux de lecture (UX-DR12).

### Story 5.17: Écran Multi — sélection, chevaux les plus probables, évaluation et états

En tant que turfiste,
je veux voir, pour la taille choisie, la sélection du modèle, les chevaux les plus probables à activer comme bases et l'évaluation,
afin de savoir quels chevaux peuvent constituer l'arrivée et pourquoi.

**Acceptance Criteria:**

**Given** la section Sélection, sous la confiance
**When** elle est rendue (FR-27, UX-DR5)
**Then** chaque `multi-row` montre dossard, nom, « Top 4 estimé 41 % », « contribution −6 pts », les indicateurs de transparence existants, « Cote manquante » s'il y a lieu et l'étiquette « Base » s'il est base, en un nœud TalkBack groupé
**And** aucun badge de value n'existe dans l'écran (test sur l'arbre de widgets)
**And** les 3 écartés les plus proches suivent sous « Écartés les plus proches », dossard en contour, avec « Écarté : » et leur raison.

**Given** la section « Chevaux les plus probables · selon le modèle »
**When** elle est rendue (FR-24, UX-DR6)
**Then** 3 `base-chip` (moins si la sélection est plus petite) montrent dossard, nom, « Top 4 estimé 58 % », l'effet en base (« −4 pts d'arrivée dans la sélection ») et les tickets économisés en Multi en 7 (« 16 tickets en moins en Multi en 7 », sinon la plus grande formule disponible ; la story 5.18 fera suivre la formule affichée) ; sans système (règles non vérifiées, forme absente), la ligne des tickets est omise ; aucune puce active au premier affichage
**And** chaque puce est une seule cible ≥ 48dp, rôle interrupteur, état « Base imposée dans tous les tickets » / « Interdite comme base » ; un basculement recalcule sélection, confiance et évaluation sur l'appareil
**And** le mot « sûr » n'apparaît nulle part.

**Given** l'`evaluation-block`
**When** il est rendu (FR-30, UX-DR8)
**Then** il montre « Arrivée dans la sélection : 31 % (estimé) » (« bases comprises » s'il y a des bases) et la distribution des chevaux capturés de 0 à 4, en cinq lignes au pourcentage écrit
**And** si le contexte porte `statut_modele = pas_meilleur_que_le_marche`, un bandeau fort en tête de l'Évaluation dit « Évaluation sur N courses : le modèle ne fait pas mieux que le marché », et le pronostic ne bascule vers aucune autre méthode.

**Given** les états de cette story (UX-DR11)
**When** ils surviennent
**Then** partants non analysés : « 3 partants non analysés, non sélectionnables » + « Analyser » vers Liste des partants ; chevaux sans dossard : « 2 chevaux sans dossard, non sélectionnables » + « Analyser » ; cote manquante : « Cote manquante » sur la ligne.

**Given** les sections de cette story
**When** un test parcourt leurs textes
**Then** aucun mot ni symbole d'argent n'apparaît (NFR-8, UX-DR13)
**And** à un facteur de police de 2,0, aucun chiffre ni dossard n'est tronqué (UX-DR12).

### Story 5.18: Écran Multi — grilles (formules, feuille des grilles, copie, vérifier un système)

En tant que turfiste,
je veux voir, pour ma sélection et ses bases, chaque formule avec son nombre de tickets, ouvrir et copier les grilles en dossards, et vérifier un système trouvé ailleurs,
afin de savoir exactement ce que mes tickets couvrent, sans aucun prix.

**Acceptance Criteria:**

**Given** la section Systèmes, insérée entre les chevaux les plus probables et l'Évaluation
**When** elle est rendue (FR-25, UX-DR7)
**Then** une `formula-row` par formule `k ≤ v`, de 7 à 4, montre « Multi en 7 · 11 tickets · 3 tickets physiques », sans aucun coût
**And** la formule « Affichée » par défaut est Multi en 7 (sinon la plus grande formule disponible), sans mémoire d'une course à l'autre ; un tap en fait la formule affichée, avec l'état sémantique « sélectionné » et le texte de garantie de la story 5.15, puis « Couverture garantie — pas un gain garanti »
**And** les tickets économisés des `base-chip` (story 5.17) suivent la formule affichée. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
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

### Story 5.19: Retoucher sa sélection et gérer les non-partants

En tant que turfiste,
je veux retirer, ajouter ou imposer un cheval, saisir ma propre sélection et marquer un non-partant, même sans réseau,
afin d'ajuster le pronostic à mes convictions et aux nouvelles du jour en voyant ce que chaque choix change.

**Acceptance Criteria:**

**Given** un tap sur une `multi-row`
**When** la `multi-actions-sheet` s'ouvre, titrée « N° 7, Ondine Royale »
**Then** elle propose Retirer (taille −1), Imposer avec son effet (« Imposer : −3 pts d'arrivée dans la sélection par rapport au pronostic du modèle »), Base oui/non avec l'état courant, Marquer non-partant (FR-28, UX-DR5)
**And** une action ferme la feuille et recalcule sur l'appareil ; une fermeture sans action rend le focus à la ligne ; après « Retirer » ou « Marquer non-partant », le focus va au bandeau de confirmation
**And** une action impossible est désactivée avec sa raison (retirer à 4 chevaux, 4ᵉ base, imposer au-delà de la taille).

**Given** un tap sur un des écartés les plus proches
**When** la `multi-actions-sheet` s'ouvre
**Then** elle est réduite à « Ajouter à la sélection » (taille +1, le `size-stepper` suit, plafond 20), comme le veut EXPERIENCE.md. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** « + Ajouter un cheval »
**When** la `horse-picker-sheet` s'ouvre
**Then** elle liste les partants analysés non retenus (dossard, nom, top 4 estimé) ; un tap ajoute le cheval (taille +1, plafond 20)
**And** les partants non analysés et les chevaux sans dossard sont grisés « à analyser », non sélectionnables ; « Analyser » renvoie à Liste des partants (FR-22).

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
**When** l'action est confirmée (FR-23)
**Then** le cheval reçoit `nonPartant = true` dans la liste de la course ; le moteur de scoring est relancé sur l'appareil avec les mêmes réglages, sans lui, et `nbPartantsCourse` = déclarés − non-partants (story 5.7, AD-6) ; le pronostic est recalculé sur la nouvelle sortie, le modèle le remplace pour garder la taille, et le bandeau « Non-partant : n° 7 — pronostic recalculé » s'annonce une fois puis disparaît au recalcul suivant
**And** Résultats affiche le même champ, avec « Non-partant : n° 7 — classement recalculé »
**And** une base marquée non-partante perd son rôle de base, et le bandeau le dit
**And** « Annuler non-partant » dans la feuille du cheval revient en arrière (nouveau calcul du scoring avec le cheval).

**Given** « Rafraîchir la course » dans l'en-tête du Multi, avec réseau (story 5.7)
**When** le backend signale des non-partants
**Then** ils sont appliqués comme un marquage manuel, avec le même bandeau
**And** sans réseau, le rafraîchissement échoue avec un message clair et le marquage manuel reste possible (FR-15).

### Story 5.20: Retenir son pronostic, même hors ligne (sqflite v3, gel au départ, purge 90 j, dernière taille)

En tant que turfiste,
je veux retenir le pronostic que je compte suivre, le remplacer jusqu'au départ et retrouver ma taille et mes seuils habituels,
afin d'avoir sur mon téléphone, même sans réseau, la trace de ce que j'ai décidé, retrouvée ensuite sur mes autres appareils.

**Acceptance Criteria:**

**Given** `mobile/lib/data/local/database_helper.dart` en version 2 (story 5.7)
**When** la base passe en version 3 (AD-9)
**Then** `onCreate` crée directement la version 3 et `onUpgrade` migre de 1 à 3 et de 2 à 3 sans perdre les lignes existantes, chaque chemin testé avec `sqflite_common_ffi`
**And** la version 3 crée `pronostic_retenu` (`cle_course` unique, `taille`, `selection_json` (dossard, nom, `top4`, rôle, explications), `bases_json`, `formule_affichee` facultative, `tickets_json` facultatif (grilles de la formule affichée, telles qu'affichées), `version_catalogue` facultative, `modifie`, `confiance_niveau` facultatif, `confiance_raisons_json`, `bases_candidates_json`, `p_couverture`, `distribution_json`, `donnees_a`, `retenu_le`, `heure_depart` facultative, `identite_json`) et `recommandation_consultee` (`cle_course` unique, `libelle_course`, `date_course`, `taille`, `selection_json`, `bases_candidates_json`, `confiance_niveau` facultatif, `confiance_raisons_json`, `p_couverture`, `distribution_json`, `donnees_a`, `heure_depart` facultative, `identite_json`, `consulte_le`, `arrivee_json` facultatif, `arrivee_corrigee_le` facultatif, `arrivee_lue_le` facultatif), instants en UTC.

**Given** un calcul complet du pronostic du modèle (ouverture, taille changée après la pause, retour de Réglages), avant le départ
**When** aucun pronostic n'est encore retenu pour la course
**Then** `recommandation_consultee` est remplacée par ce pronostic (une ligne par course)
**And** dès qu'un pronostic est retenu, seule une nouvelle retenue la réécrit ; après le départ, rien ne l'écrit plus. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** la `multi-action-bar`
**When** l'utilisateur touche « JE RETIENS CE PRONOSTIC », seul CTA plein de l'écran (UX-DR9, FR-28)
**Then** l'app enregistre le pronostic affiché dans `pronostic_retenu` et le pronostic du modèle à la même taille dans `recommandation_consultee`, puis affiche « Pronostic retenu à 9 h 52 » avec une annonce polie
**And** le CTA devient « Remplacer mon pronostic retenu » ; un nouveau pronostic retenu remplace l'ancien (un seul par course)
**And** avec des règles non vérifiées, le pronostic peut être retenu sans formule ni grilles
**And** quand le classement est à recalculer, le CTA est désactivé, pas masqué, avec sa raison
**And** l'enregistrement local suffit à confirmer ; rien d'autre n'est envoyé au backend que la synchronisation du compte décrite ci-dessous (test avec un client API qui enregistre les appels).

**Given** l'heure de départ (UTC, story 5.2)
**When** elle est passée
**Then** le pronostic retenu est figé : « 🔒 Pronostic figé au départ (15 h 05) » remplace le CTA, les contrôles restent visibles mais désactivés, et toute action échoue avec un message explicite
**And** si l'écran est ouvert au moment du départ, la bascule se fait en direct, avec l'annonce « Départ passé : pronostic figé, lecture seule » et le focus déplacé du CTA vers l'étiquette
**And** si l'heure de départ est inconnue, l'en-tête le dit et le pronostic reste remplaçable jusqu'à la fin du jour de la course (heure de Paris).

**Given** la `tickets-sheet` après une copie réussie (story 5.18)
**When** le pronostic affiché n'est ni retenu à l'identique ni figé
**Then** l'invitation « Retenir ce pronostic ? » (« Retenir » / « Plus tard ») apparaît, n'expire pas et ne retient jamais à la place de l'utilisateur ; « Plus tard » n'enregistre rien (UX-DR7).

**Given** un pronostic retenu qui contient un cheval devenu non-partant
**When** le non-partant est marqué ou reçu (story 5.19)
**Then** un bandeau distinct dit « Votre pronostic retenu contient le n° 7, non-partant » et montre ce que deviennent ses tickets (Multi en 7 → en 6, etc., ou ticket annulé), selon `simuler_non_partant` (story 5.11) (FR-23, UX-DR11)
**And** l'entrée enregistrée n'est pas réécrite.

**Given** le démarrage de l'application
**When** des entrées portent sur des courses de plus de 90 jours
**Then** elles sont supprimées, sans tâche de fond (test avec horloge injectée) (FR-30).

**Given** `shared_preferences`
**When** l'utilisateur change de taille
**Then** la dernière taille est mémorisée et sert de taille par défaut à la course suivante, plafonnée au nombre de sélectionnables (FR-23, UX-DR3)
**And** l'écran Réglages gagne un groupe « Multi » conforme à EXPERIENCE.md : « Seuil de course ouverte », « Seuil de données fragiles », puis « Seuils de confiance par taille » replié, une ligne par taille de 4 à 20 avec « Moyenne à partir de » et « Élevée à partir de » en pourcentage, vides = « Auto » (règle provisoire) ; marqués « provisoire » tant que les paramètres du pilote le sont, réinitialisés avec les autres réglages, refusés et expliqués sous le champ s'ils sont incohérents (FR-26) `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
**And** au retour vers le Multi, le pronostic est recalculé localement, sans marquer le classement comme périmé.

**Given** un utilisateur connecté qui retient un pronostic
**When** le réseau est disponible
**Then** le pronostic est aussi envoyé à son compte (story 8.8, AD-9 amendé), et le gel au départ s'applique aux deux copies.

### Story 5.21: Le débrief du lendemain (Mes pronostics Multi, arrivée corrigée, Multi en lecture seule)

En tant que turfiste,
je veux retrouver sur l'accueil mes pronostics Multi et voir, après la course, combien de chevaux de l'arrivée ils ont capturés,
afin de juger honnêtement mes choix et ceux du modèle, sans embellissement.

**Acceptance Criteria:**

**Given** l'Accueil et les courses éligibles du programme (plusieurs par jour)
**When** leurs cartes sont affichées
**Then** chacune porte un `multi-badge` « Multi » (cible ≥ 48dp) (UX-DR1)
**And** un tap ouvre le Multi directement si un classement à jour de cette course est en mémoire (retour → Accueil), sinon la Liste des partants avec « Calculez le classement pour ouvrir le Multi ».

**Given** la section « Mes pronostics Multi » sous le programme
**When** `recommandation_consultee` contient au moins une course des 90 derniers jours
**Then** une `debrief-row` par course, de la plus récente à la plus ancienne, montre la course (`libelle_course`), la date, la taille, puis deux lignes qui commencent par leur sujet : « Votre pronostic : … » (depuis `pronostic_retenu`) et « Pronostic du modèle : … » (depuis `recommandation_consultee`) (UX-DR10)
**And** sans pronostic retenu, « Votre pronostic : aucun pronostic retenu » ; la section est masquée si elle est vide ; son pied dit « Conservés 90 jours, sur ce téléphone et dans votre compte » (EXPERIENCE.md, AD-9).

**Given** un rafraîchissement explicite de l'Accueil avec réseau
**When** une ligne n'a pas d'arrivée, ou porte sur une course de moins de 5 jours (fenêtre de recontrôle serveur de 3 jours, plus 2 jours de marge) `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
**Then** l'app lit `GET /multi/courses/{cle_course}` (story 5.13) et enregistre l'arrivée et `arrivee_corrigee_le` dans `recommandation_consultee` ; tant qu'il n'y en a pas, la ligne dit « En attente du résultat »
**And** sans réseau, la ligne reste « En attente du résultat » et un message clair dit que le résultat sera lu au prochain rafraîchissement (FR-15).

**Given** une arrivée officielle disponible
**When** le débrief est calculé avec `bilan_arrivee` du moteur Dart (story 5.14) sur les sélections enregistrées
**Then** chaque ligne dit « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non », pour le pronostic retenu et pour le pronostic du modèle (FR-30)
**And** seule l'arrivée officielle compte ; les ex-aequo et l'arrivée dégradée suivent les règles du pari ; une course sans arrivée exploitable affiche « Aucune arrivée exploitable »
**And** le texte n'a aucune couleur de réussite ni d'échec (ni or ni vert pour « oui »).

**Given** une arrivée corrigée après finalisation (`arrivee_corrigee_le` renvoyé par le backend)
**When** l'Accueil est rafraîchi
**Then** le débrief est recalculé et porte la mention « Arrivée corrigée » (FR-30).

**Given** un tap sur une `debrief-row`
**When** le Multi s'ouvre en état débrief
**Then** l'en-tête montre l'arrivée (4 premiers en dossards) et « 🔒 Pronostic figé au départ (15 h 05) », puis les deux lignes de débrief, puis le pronostic retenu tel qu'enregistré (à défaut, le pronostic du modèle consulté) : taille, confiance (niveau et raisons enregistrés), sélection, chevaux les plus probables, formule, sans aucun recalcul
**And** l'Évaluation est affichée depuis `p_couverture` et `distribution_json` enregistrés ; la section « Autres méthodes » est absente
**And** les chevaux de l'arrivée portent le texte « Capturé » ; tout est en lecture seule ; la barre ne garde que « Voir les grilles », qui affiche `tickets_json` tel qu'enregistré (jamais reconstruit depuis le catalogue courant) et n'existe pas sans pronostic retenu `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
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
**Then** elle ajoute `performances_historiques.rang_brut` (texte : `1`..`9`, `0`, `D`, `T`, `A`, …), `performances_historiques.statut_arrivee` (texte) et `participations.musique` (texte), facultatifs
**And** `repository.save_partants` écrit `participations.musique` depuis `PartantInfo.musique` ; une commande ponctuelle et idempotente (`python -m app.jobs.remplir_musique`) remplit les lignes anciennes en appelant `pmu_client.musique_depuis_brut(donnees_brutes)` — seul `pmu_client.py` connaît la clé brute (AD-1) ; une ligne sans `donnees_brutes` garde `NULL`, traité comme « absent » ; la commande n'est pas une migration Alembic `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
**And** la colonne `allocation`, déjà présente et déjà alimentée par `pmu_client.get_historique`, est conservée telle quelle (le cahier Multi §3 la croyait absente) ; les lignes anciennes gardent `NULL`, traité comme « absent ».

**Given** `pmu_client.get_historique` (et `open_pmu_client` pour le backfill, si la source porte ces champs)
**When** une performance passée est lue
**Then** `rang_brut` et `statut_arrivee` sont renseignés depuis `place` et `statusArrivee`, et seul ce module lit ces champs bruts (AD-1).

**Given** `backend/app/data/musique.py` (créé, couche data — AD-6)
**When** il décode une musique (cahier Multi annexe D)
**Then** il renvoie la liste des courses de la plus récente à la plus ancienne (année, rang brut, discipline) et gère le format réel observé, majuscules comprises (ex. `DA21DA2A1ADA1A`)
**And** il est validé sur au moins 30 musiques réelles : les fixtures actuelles n'en contiennent que 12, donc la story capture les participants de 2 ou 3 courses supplémentaires (moins de 5 appels, notés dans la story, PRD OQ 6) ; une chaîne ambiguë renvoie « indécidable » avec un avertissement, jamais un rang deviné ; `NR` est sauté pour remonter à la course réellement courue ; une lettre d'incident inconnue va au pool « queue » avec avertissement ; les lettres de discipline sont acceptées en majuscules et en minuscules (cahier Multi annexe D).

**Given** un partant d'une course
**When** le repository calcule ses entrées de méthode 1
**Then** il fournit `dernier_rang`, `derniere_allocation` et `source_rang` depuis les colonnes stockées (`performances_historiques`, `participations.musique`), jamais depuis `donnees_brutes` : le rang vient de la liste détaillée quand elle donne une place ou un incident ; la musique ne sert que pour `NON_PLACE` sans place ou liste absente ; en cas de désaccord, la liste l'emporte, `source_rang = "liste_detaillee"` et l'avertissement `rang_desaccord` (cahier Multi §3 et annexe D, révisés le 2026-10-18) `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
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

### Story 6.4: Backtest : harnais sans fuite et périodes figées

En tant que porteur de projet,
je veux rejouer le pronostic du modèle et les comparateurs sur l'historique, sans aucune donnée postérieure à l'heure de chaque pronostic,
afin de disposer d'une base honnête pour mesurer s'il fait mieux que le marché.

**Acceptance Criteria:**

**Given** `backend/app/jobs/backtest_multi.py` (créé), adaptateur pilotant configuré par la seule `DATABASE_URL` (AD-11)
**When** il tourne sur la machine de développement contre une copie de la base de production
**Then** il appelle le moteur Multi et `repository.py` comme tout job, en lecture seule (test : aucune écriture en base)
**And** il retient toute course de ≥ 14 partants qui a une arrivée, que le Multi y ait été proposé ou non (cahier Multi §8.1) ; les non-partants connus sont exclus de l'entrée du scoring comme en production (story 5.5).

**Given** une course rejouée en mode `backfill`
**When** les entrées du moteur sont reconstruites à `donnees_a`
**Then** seules les données antérieures sont lues (historique jusqu'à la veille, musique de la participation, cotes finales seulement si le mode les déclare disponibles, sinon B1 et le départage M1 sont marqués `degrade`)
**And** le test 14 passe : supprimer de la base toute donnée postérieure à `donnees_a` ne change pas le pronostic (FR-30).

**Given** le fichier de configuration du backtest
**When** une période est demandée
**Then** chaque période porte son `type_periode` (`developpement`, `validation`, `test`) ; les périodes sont temporelles, jamais tirées au hasard
**And** les constantes dérivées des données (réglages du moteur, quantiles éventuels) sont figées avec leur date `constantes_figees_le`, antérieure au début d'une période de test ; sinon le harnais refuse de tourner.

**Given** les stratégies rejouées — `modele` aux tailles demandées, `modele` sans échanges (ablation), M1, M1-structure, B0 et B1
**When** une course est rejouée
**Then** chaque stratégie produit sa sélection et son `bilan_arrivee` (story 5.11), et les exclusions sont comptées par cause (cote manquante, arrivée absente, données insuffisantes).

### Story 6.5: Backtest : stratégies, métriques et export

En tant que porteur de projet,
je veux les métriques du backtest par stratégie et un export reproductible,
afin de savoir, chiffres et intervalles à l'appui, si le modèle fait mieux que le marché.

**Acceptance Criteria:**

**Given** les résultats de la story 6.4 sur une période
**When** les métriques sont calculées (cahier Multi §8.2)
**Then** le rapport contient le Brier et la courbe de calibration de `p_couverture` comparés au marché, le nombre moyen de chevaux capturés avec la différence appariée contre B1 et son intervalle bootstrap à 95 % (graine fixée), la proportion d'arrivées dans la sélection avec intervalle de Wilson comparée à la loi hypergéométrique, la proportion par niveau de confiance et par taille, l'ablation, et la correction de Holm sur toutes les comparaisons listées
**And** l'alignement de l'heure des cotes de B1 sur celle du modèle est déclaré.

**Given** la fin d'un backtest
**When** les résultats sont exportés
**Then** un fichier JSON porte un en-tête (versions de `fixtures/multi_versions.json`, `version` du catalogue, empreinte des règles, `constantes_figees_le`, période et `type_periode`, commit) et les métriques par stratégie, sans aucun montant ni rapport
**And** deux exécutions identiques donnent le même fichier.

### Story 6.6: Pilote et import en production (multi_parametres_pilote.json, performance_strategie, /multi/performance)

En tant que porteur de projet,
je veux un pilote qui fixe les seuils de confiance, les tailles de référence et l'effectif minimal, et une commande qui importe les résultats en production,
afin que les seuils cessent d'être provisoires et que les performances mesurées deviennent consultables.

**Acceptance Criteria:**

**Given** le harnais des stories 6.4 et 6.5 sur la période de développement, et la règle de taille d'échantillon et de proposition des seuils décidée par le porteur de projet avant cette story (constat F15, différé ; écrite au cahier Multi §8.4)
**When** le pilote tourne
**Then** il mesure la variance des métriques et applique cette règle pour fixer la taille d'échantillon de la période de test
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
**Then** elle crée seulement la table `performance_strategie` (stratégie, version, période, `type_periode`, `gelee` (booléen : période de test gelée), `close` (booléen : période de test terminée), effectif, métriques, `constantes_figees_le`, `importe_le`). `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** la commande d'import du module `backend/app/jobs/backtest_multi.py`
**When** elle charge un fichier exporté en production
**Then** elle écrit `performance_strategie` via `repository.py`, seule écrivaine de cette table (AD-10)
**And** importer deux fois le même fichier ne crée pas de doublon ; un fichier sans `constantes_figees_le` ou dont l'empreinte des règles ne correspond pas aux règles en vigueur est refusé avec un message clair.

**Given** `GET /multi/performance`, filtrable par période et par stratégie
**When** il répond
**Then** il ne lit que `performance_strategie` et renvoie, sous schéma typé, l'effectif et les intervalles de chaque métrique, sans aucun champ d'argent (FR-29)
**And** `/multi/backtest` n'est pas construit (différé au passage sur serveur).

### Story 6.7: Journalisation quotidienne avant le départ (immuable, échecs, résultats à la finalisation)

En tant que porteur de projet,
je veux que le backend journalise, avant le départ de chaque course éligible du jour, le pronostic du modèle et les comparateurs, et en note le résultat après l'arrivée,
afin que l'évaluation prospective repose sur des pronostics impossibles à retoucher après coup.

**Acceptance Criteria:**

**Given** `fixtures/multi_parametres_pilote.json` sans `tailles_reference` ou encore provisoire (miroir `parametres.py`)
**When** le job de journalisation démarre
**Then** il refuse de journaliser et le dit dans le journal (ordre imposé : pilote → seuils et tailles de référence → journalisation, PRD §6.1).

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée `recommandation_multi` (unique par course, stratégie, version de stratégie, mode et taille de référence ; identité du pronostic, `donnees_a`, confiance pour `modele`, `seuils_provisoires`, `degrade`, `cree_le`), `echec_journal_multi` (course, raison, `survenu_le`) et `resultat_recommandation` (une ligne par entrée journalisée : `nb_captures`, `arrivee_dans_selection`, `calcule_le`) — aucune colonne d'argent (AD-10).

**Given** le job `backend/app/jobs/journal_multi.py` (créé), lancé chaque minute par le scheduler du conteneur `ingestion`
**When** une course éligible du jour (`multi_course.multi_propose` vrai et contexte éligible — environ 15 par jour) arrive à `MULTI_JOURNAL_AVANCE_MINUTES` (défaut 30) de son départ et n'a encore ni entrée ni échec
**Then** il relit ses partants par `rafraichir_partants` (story 5.6), puis journalise, en mode `live`, le pronostic `modele` à chaque taille de référence et les comparateurs M1, B0 et B1, construits sur le **jeu publié** de l'horizon le plus proche de cet instant, lu dans la table des pronostics publiés avec les cotes de `cotes_instantanees` de cet horizon — il ne relit jamais les cotes et ne recalcule jamais les probabilités (AD-10, AD-14 gate A, alignement du 2026-11-15) ; les non-partants relus en sont retirés par `renormaliser_sans_non_partants` (story 11.4, créée ici avec ses cas partagés si cette story n'est pas encore livrée) ; `donnees_a` = instant de la relecture, strictement antérieur au départ (comparaison UTC, AD-12) (FR-30)
**And** si la relecture échoue, il journalise avec les derniers partants stockés et `donnees_a` = leur `donnees_maj_le` `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
**And** une course sans jeu publié à cet instant n'est pas journalisée : c'est un échec `pronostic_publie_absent` `[ASSUMPTION: arbitrage de la mise à jour des epics du 2026-11-15, à confirmer par le porteur de projet]`
**And** une deuxième exécution ne crée pas de doublon (contrainte d'unicité) ; le volume est d'au plus un appel `participants` par course éligible et par jour (PRD OQ 6).

**Given** une entrée de `recommandation_multi`
**When** n'importe quel code du backend tente de la modifier ou de la supprimer
**Then** `repository.py` n'offre aucune méthode pour le faire ; une correction crée une nouvelle `version_strategie`
**And** un non-partant survenu après la journalisation ne réécrit pas l'entrée : son résultat suit la requalification.

**Given** un échec — heure de départ inconnue, départ passé avant que le job ait pu tourner, erreur du moteur, cote manquante pour B1
**When** le job ne peut pas journaliser une stratégie
**Then** il écrit `echec_journal_multi` avec un code de raison (`heure_depart_inconnue`, `depart_passe`, `erreur_moteur`, `cote_manquante`, `pronostic_publie_absent`), la course (ou la seule stratégie B1) est exclue de l'évaluation et l'exclusion est comptée
**And** l'échec n'arrête pas la boucle du scheduler.

**Given** le job de finalisation, une fois l'arrivée définitive dans `multi_course`
**When** il traite les entrées journalisées de la course
**Then** il écrit `resultat_recommandation` avec `bilan_arrivee` (ex-aequo et arrivée dégradée compris), de façon idempotente, en seul écrivain de cette table
**And** si l'arrivée est corrigée (story 5.5), le résultat est recalculé et `calcule_le` mis à jour, sans toucher à l'entrée journalisée.

### Story 6.8: Performances et statut du modèle affichés (seuils définitifs, mention retirée ou maintenue)

En tant que turfiste,
je veux voir les performances mesurées du modèle et des autres méthodes et savoir si le modèle fait mieux que le marché,
afin de savoir quelle confiance accorder au pronostic, sur la foi de résultats et non d'une promesse.

**Acceptance Criteria:**

**Given** `performance_strategie` et la règle de décision du cahier Multi §8.3
**When** le backend construit le contexte Multi
**Then** `statut_modele` vaut `valide` seulement si, sur une période de `type_periode = test` avec `gelee = true` et au-delà de l'effectif minimal, l'intervalle à 95 % de la différence avec B1 exclut 0 du bon côté ; `pas_meilleur_que_le_marche` si cette période a `close = true` sans que ce soit le cas, avec l'effectif ; sinon `en_cours_d_evaluation`
**And** la même règle décide, pour chaque comparateur, si « hypothèse non validée » est retirée ; le contexte Multi porte `statut_comparateurs` (`{"M1": "hypothese_non_validee" | "valide", "B1": …}`), lu par l'app. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

**Given** l'application après un rafraîchissement explicite avec réseau
**When** elle lit `GET /multi/performance` et le contexte Multi
**Then** elle garde le contexte dans `programme_courses.multi_contexte` (story 5.7) et la réponse de `/multi/performance` dans une table `performance_multi` (`cle` = filtre demandé, `contenu_json`, `lu_le`) créée par une version 4 de `hippique_cache.db` (`onCreate` v4 direct, `onUpgrade` 3→4 testé, AD-9) ; sans réseau, les dernières valeurs connues restent affichées.

**Given** la section « Autres méthodes » dépliée
**When** l'effectif d'une stratégie atteint l'effectif minimal du pilote
**Then** sa performance s'affiche avec l'effectif et l'intervalle de confiance (« sur 64 courses ») (FR-29, UX-DR8)
**And** en dessous, la ligne reste « Pas encore assez de courses pour mesurer ».

**Given** un `statut_modele`
**When** l'écran Multi est rendu
**Then** `valide` retire l'étiquette « modèle en cours d'évaluation » ; `pas_meilleur_que_le_marche` la garde et affiche en tête de l'Évaluation le bandeau fort « Évaluation sur 64 courses : le modèle ne fait pas mieux que le marché » (FR-23, UX-DR11)
**And** dans aucun cas le pronostic ne bascule vers une autre méthode (test).

**Given** des paramètres du pilote non provisoires (story 6.6)
**When** la carte confiance et les Réglages sont rendus
**Then** l'étiquette « seuils provisoires » n'apparaît plus et les seuils par défaut sont ceux du pilote (FR-26)
**And** aucun chiffre de performance n'est exprimé en argent ni en rapport.

### Couverture des exigences Multi

| Exigence | Stories |
| --- | --- |
| FR-22 | 5.1, 5.5, 5.9, 5.13, 5.16, 5.17, 5.18, 5.19 |
| FR-23 | 5.2, 5.5, 5.6, 5.7, 5.9, 5.14, 5.16, 5.17, 5.19, 5.20, 6.8 |
| FR-24 | 5.10, 5.14, 5.17, 5.18 |
| FR-25 | 5.8, 5.10, 5.13, 5.14, 5.15, 5.18 |
| FR-26 | 5.12, 5.15, 5.16, 5.20, 6.6, 6.8 |
| FR-27 | 5.9, 5.12, 5.15, 5.17 |
| FR-28 | 5.11, 5.13, 5.19, 5.20 |
| FR-29 | 6.2, 6.3, 6.6, 6.8 |
| FR-30 | 5.5, 5.11, 5.17, 5.20, 5.21, 6.4, 6.5, 6.7 |
| NFR-7 | 5.15, 5.16, 5.18 |
| NFR-8 | 5.1, 5.9, 5.10, 5.11, 5.13, 5.15, 5.16, 5.17, 5.18, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8 |
| NFR-9 | 5.1, 5.8, 5.9, 5.10, 5.11, 5.12, 5.14, 5.15, 6.2 |
| NFR-10 | 5.14 |
| NFR-11 | 5.12, 5.15 |
| UX-DR1 | 5.16, 5.21 |
| UX-DR2 | 5.16, 5.17, 5.18, 6.3 |
| UX-DR3 | 5.16, 5.20 |
| UX-DR4 | 5.16 |
| UX-DR5 | 5.17, 5.19 |
| UX-DR6 | 5.17, 5.18 |
| UX-DR7 | 5.18, 5.20 |
| UX-DR8 | 5.17, 6.3, 6.8 |
| UX-DR9 | 5.20 |
| UX-DR10 | 5.21 |
| UX-DR11 | 5.7, 5.16, 5.17, 5.18, 5.19, 5.20, 6.3, 6.8 |
| UX-DR12 | 5.3, 5.16, 5.17 |
| UX-DR13 | 5.15, 5.16, 5.17, 5.18 |

## Epic 7: Fondations de sécurité de la plateforme

Avant qu'un compte ou un paiement existe, le serveur est fermé et sûr : schéma migré par Alembic, PostgreSQL à schémas et rôles séparés, HTTPS seulement, origines restreintes, débit limité, aucun secret dans les binaires, web app compagnon et app Android prêtes à être publiées. **Ordre :** la story 7.8 et la première tâche de la story 7.1 (vérification du VPS) démarrent tout de suite, en parallèle — la 7.8 n'attend pas la vérification du VPS ; puis la suite de la story 7.1, les stories 7.2 à 7.7 dans l'ordre, la story 7.9 (indépendante, dès la story 7.1) et la story 7.10 (après la story 7.2) ; les Epics 5 et 6 peuvent reprendre après la story 7.1.

### Story 7.1: Mises à jour du serveur sans perte de données (Alembic)

*Ex-story 5.4, déplacée le 2026-11-15 (contenu inchangé, sauf la base de production et l'alignement sur AD-13 amendé).*

En tant que porteur de projet,
je veux que toute évolution du schéma de la base serveur passe par une migration Alembic appliquée au démarrage de l'API,
afin que les tables et colonnes du Multi atteignent la base de production (SQLite, puis PostgreSQL à la story 7.2) sans la recréer ni perdre ses données.

**Acceptance Criteria:**

**Given** la première tâche de la story, à faire avant toute autre story de l'Epic 7 (AD-13, AD-19, AD-21)
**When** le développeur vérifie, sur le VPS de production (processeur SSE2 seulement), PostgreSQL (version majeure stable), son pilote Python (psycopg 3 ou psycopg2), le proxy TLS (Traefik v3, AD-21 `[À VÉRIFIER]`) et `age` (chiffrement des sauvegardes, story 7.2)
**Then** les versions qui s'y installent et y tournent sont consignées dans les notes de la story et reportées dans la section Stack de l'architecture, qui les épingle
**And** si l'un d'eux ne tourne pas sur ce processeur, la story s'arrête sur ce constat et le porteur de projet décide avant les stories 7.2 et 7.3 ; la story 7.8 ne dépend pas de cette tâche et démarre sans l'attendre.

**Given** `alembic==1.20.0` ajouté à `backend/requirements.txt`, `backend/alembic.ini` et `backend/alembic/env.py` (créés) qui lisent `DATABASE_URL` et ciblent `Base.metadata` de `backend/app/data/models.py`, en mode batch SQLite
**When** l'image Docker est construite
**Then** le `Dockerfile` copie `alembic.ini`, `alembic/` et `scripts/` (dans le contexte de build `backend/`), puisque le `CMD` appelle `scripts/demarrer_api.py` (AD-13).

**Given** la révision de base (baseline)
**When** `alembic upgrade head` tourne sur une base vide
**Then** le schéma obtenu est identique à celui que `Repository._migrate()` produit au commit de cette story (référence, pas liste fermée : il comprend par exemple `performances_historiques.rang_impute`, ajouté par la branche `fix/ingestion-etat-terrain`) — comparaison par inspection dans un test entre une base créée par `create_all` + `_migrate()` et une base créée par `alembic upgrade head`
**And** la baseline comprend aussi `participations.cote_reference_le` et `cote_direct_le`, et l'index unique partiel des pronostics publiés y est déclaré avec `sqlite_where` et `postgresql_where`, pour être porté tel quel sur PostgreSQL (AD-13, AD-14).

**Given** une base au format actuel de production, sans table `alembic_version`
**When** le service `api` démarre
**Then** le script de démarrage (`backend/scripts/demarrer_api.py`, appelé par le `CMD` du `Dockerfile`) copie le fichier SQLite en `hippique.db.avant-<révision>.bak` (un `pg_dump` une fois sur PostgreSQL, story 7.2), applique une dernière fois `_migrate()` (idempotent) pour amener une vieille base à la forme de la baseline, tamponne la baseline, puis exécute `alembic upgrade head`, puis lance uvicorn
**And** un test sur une copie de base au format ancien vérifie que le nombre de lignes de chaque table est inchangé après migration
**And** à partir de la story 7.2, cette étape seule se connecte avec `role_migration` (AD-19).

**Given** une migration qui échoue au démarrage
**When** le script s'exécute
**Then** le processus s'arrête avec un code non nul, l'erreur est journalisée et uvicorn ne démarre pas
**And** la copie de sauvegarde reste disponible ; seules les 3 dernières sont conservées.

**Given** les services `ingestion`, `cotes`, `pronostics` et `rebuild`, et les jobs `build_features` et `purge_open_pmu`
**When** ils démarrent ou reprennent un cycle
**Then** aucun ne migre : chacun vérifie que la révision de la base est `head` et, sinon, journalise une erreur explicite et réessaie plus tard sans rien écrire — seul le démarrage de `api` migre (AD-13)
**And** un test couvre ce refus pour chacun.

**Given** `backend/app/data/repository.py`
**When** il ouvre une vraie base
**Then** il n'appelle plus ni `create_all` ni `_migrate` ; seuls les tests sur base jetable créent le schéma, via un paramètre explicite
**And** les instanciations de `Repository()` à l'import (`routes_analyse.py`, `routes_chevaux.py`, `routes_courses.py`, `routes_dashboard.py`, `routes_pronostics.py`) et dans les jobs (`scheduler.py`, `ingest_daily.py`, `predict.py`, `rebuild_historique.py`, `bilan_pronostics.py`, `cotes_instantanees.py`, `pronostics_ml.py`, `build_features.py` et `purge_open_pmu.py`) ne créent plus aucun schéma ; le test énumère ces sites d'appel et échoue si un nouveau `Repository()` apparaît hors de la liste (recherche dans le code)
**And** un test de concordance vérifie que la comparaison automatique entre les modèles et la révision `head` est vide (un changement de modèle livré sans migration fait échouer la suite).

### Story 7.2: Passer de SQLite à PostgreSQL

En tant que porteur de projet,
je veux que le serveur stocke ses données dans PostgreSQL, avec des schémas et des rôles séparés pour les courses et pour les comptes,
afin que plusieurs services et, demain, des données de paiement cohabitent sans risque de corruption ni de fuite.

**Bloqué par :** la vérification du VPS (première tâche de la story 7.1 : PostgreSQL, pilote, `age` sur le processeur SSE2) pour la bascule de production ; la destination hors hôte des sauvegardes (choix du porteur de projet).
**Livrable sans :** schémas, rôles, droits, `schema_translate_map`, job de migration et tests de droits, développés et testés sur un PostgreSQL local (conteneur) ; sauvegarde chiffrée écrite sur un volume local de l'hôte en attendant la destination hors hôte.

**Acceptance Criteria:**

**Given** les versions de PostgreSQL et du pilote Python vérifiées sur le VPS par la story 7.1
**When** `docker-compose.yml` est mis à jour
**Then** un service `postgres` (volume persistant, jamais exposé hors du réseau Docker) remplace le fichier SQLite partagé, et `api`, `ingestion`, `cotes`, `pronostics` et `rebuild` reçoivent chacun leur `DATABASE_URL` PostgreSQL, avec leur propre rôle, depuis `.env`, jamais commité (AD-19)
**And** le pilote épinglé est ajouté à `backend/requirements.txt`.

**Given** PostgreSQL initialisé par un script versionné
**When** les schémas sont créés
**Then** il existe trois schémas : `courses` (données de courses, pronostics publiés, cotes, Multi), `comptes` (vide à ce stade ; il recevra `compte`, `appareil`, `session`, `droit` — licences manuelles comprises, `source = 'licence_manuelle'` —, `offre`, `personnel`, `limite_debit`, `quota_photo`) et `audit` (`journal_audit`, story 7.10) (AD-19)
**And** chaque modèle SQLAlchemy déclare son schéma ; Alembic tourne avec `include_schemas=True` ; sur SQLite (tests), le moteur applique `schema_translate_map` qui envoie `courses`, `comptes` et `audit` vers `None`, si bien que la même suite tourne sur les deux bases (test).

**Given** les rôles de la matrice d'AD-19, un par écrivain
**When** le script de rôles est appliqué
**Then** il crée :
- `role_ingestion` (services `ingestion` et `rebuild`) : écriture des tables d'ingestion du schéma `courses` (courses, partants, chevaux, performances, référentiels…), lecture de tout le schéma `courses`, lecture de `correction_saisie` ; aucun accès à `comptes` ni `audit` ;
- `role_cotes` (service `cotes`) : `INSERT` sur `cotes_instantanees` seulement, lecture du schéma `courses` ;
- `role_pronostics` (service `pronostics`) : `INSERT` sur `prediction_runs` et `prediction_chevaux` seulement, lecture du schéma `courses` et de `cotes_instantanees` ;
- `role_api` (service `api`) : lecture du schéma `courses` et les mêmes droits d'écriture que `role_ingestion` sur les tables d'ingestion (`POST /courses/{id}/importer`, `POST /chevaux/{id}/backfill`, `POST /multi/courses/{cle_course}/rafraichir` qui met à jour `donnees_maj_le`) ; aucune écriture sur `cotes_instantanees` ; sur `prediction_runs` et `prediction_chevaux`, `INSERT` permis seulement pour `variante = 'app'` par une politique de sécurité de ligne (RLS ; les lignes de `prediction_chevaux` sont contrôlées par leur run parent) jusqu'à ce que la story 11.2 décide du sort de `POST /pronostics` — test : `POST /pronostics` fonctionne sous `role_api` sur PostgreSQL, et une insertion `ml` est refusée ; sur `comptes`, droits table par table (lecture et écriture de `compte`, `appareil`, `session`, `organisation`, `membre`, `paiement`, `limite_debit`, `quota_photo` ; `droit` en lecture et insertion seules, AD-17 ; `offre` en lecture seule ; aucun accès à `personnel`, `session_personnel`, `demande_licence`) ; sur `audit`, seulement `EXECUTE` de la fonction `audit.inscrire()` (story 7.10) ;
- `role_backoffice` (service `backoffice`, Epic 10) : `SELECT` sur le schéma `courses` (tableau de bord, valeur corrigée), aucun autre droit tant que ses tables n'existent pas ; ses droits sur `correction_saisie`, `personnel`, `droit`, `offre` et `audit.journal_audit` arrivent avec leurs stories ;
- `role_migration` : DDL, réservé à l'étape de migration au démarrage de `api` (story 7.1)
**And** la politique RLS de `prediction_runs` n'autorise à `role_pronostics` que `variante = 'ml'` et à `role_api` que `variante = 'app'` ; aucun rôle applicatif n'a `UPDATE` ni `DELETE` sur `prediction_runs`, `prediction_chevaux` ni `cotes_instantanees`.

**Given** les tests de droits
**When** la suite tourne contre un vrai PostgreSQL (service de CI ou conteneur local ; ces tests sont ignorés sur SQLite, avec un message explicite)
**Then** un test par rôle vérifie au moins : un rôle de service des courses (`role_ingestion`, `role_cotes`, `role_pronostics`) est refusé sur `comptes` et `audit` ; `role_cotes` ne peut insérer que dans `cotes_instantanees` ; `role_pronostics` ne peut insérer que des lignes `ml` ; `role_api` peut importer une course mais ne peut ni insérer une ligne `ml` ni écrire un instantané ; `role_backoffice` ne peut rien écrire dans `courses` ; aucun rôle applicatif ne peut exécuter de DDL
**And** un test de bout en bout `POST /courses/{id}/importer` passe sous `role_api` sur PostgreSQL (le cas que la matrice précédente aurait cassé).

**Given** la base SQLite de production, baseline tamponnée et à `head` (story 7.1)
**When** le job unique `python -m app.jobs.migrer_vers_postgresql` (créé) tourne une fois, services arrêtés
**Then** il crée le schéma par `alembic upgrade head` sur PostgreSQL, copie chaque table dans le schéma `courses`, puis compare le nombre de lignes de chaque table entre les deux bases ; un écart arrête le job en erreur sans basculer les services (AD-13)
**And** le fichier SQLite est conservé en lecture seule jusqu'à la validation du porteur de projet, consignée dans les notes de la story ; ensuite SQLite ne sert plus qu'aux tests et au cache mobile.

**Given** les colonnes d'instants
**When** elles sont migrées
**Then** chacune est en `timestamptz` ; les heures naïves écrites en UTC par les conteneurs sont lues comme UTC, et les défauts d'heure naïve restants (`cotes_instantanees.pris_le`, `cote_direct_le`, `routes_pronostics.maintenant()`) sont corrigés pour écrire des instants conscients (AD-12)
**And** un test vérifie qu'aucune colonne de date-heure du schéma `courses` n'est `timestamp without time zone`.

**Given** le script de démarrage de `api` (story 7.1) sur PostgreSQL
**When** une révision est à appliquer
**Then** il prend un `pg_dump` avant la migration et garde les 3 derniers, migre avec `role_migration`, puis lance uvicorn avec `role_api` (AD-13).

**Given** une sauvegarde planifiée quotidienne
**When** elle s'exécute
**Then** elle est faite par `pg_dump`, chiffrée par `age` avec la clé publique présente sur l'hôte (la clé privée est gardée hors ligne par le porteur de projet, jamais sur le serveur), et stockée hors du conteneur `postgres` ; une restauration de test sur une base jetable, déchiffrée avec la clé privée, est faite et documentée dans les notes de la story (AD-19, NFR-14)
**And** tâche humaine du porteur de projet : choisir la destination hors hôte des sauvegardes (la même recevra l'export quotidien de la tête du journal d'audit, story 10.4) ; tant qu'elle n'est pas choisie, la copie reste sur un volume local de l'hôte et ce manque est consigné dans le suivi de sprint.

**Given** la suite de tests backend
**When** elle tourne
**Then** elle passe sur une base SQLite jetable (par `schema_translate_map`) et sur un PostgreSQL de test, et le test de concordance modèles/migrations de la story 7.1 tourne contre PostgreSQL.

### Story 7.3: HTTPS et origines autorisées

En tant que turfiste,
je veux que l'application ne parle au serveur qu'en HTTPS et qu'aucun autre site ne puisse l'appeler depuis un navigateur,
afin que mes échanges ne soient ni lus ni détournés, même sur un Wi-Fi public.

**Bloqué par :** l'achat du nom de domaine (PRD OQ 20), ses enregistrements DNS et les certificats, pour la mise en production ; la vérification de Traefik v3 sur le VPS (story 7.1).
**Livrable sans :** proxy, routage par hôte, redirection HTTPS, HSTS, limites, `--forwarded-allow-ips` et CORS développés et testés en local sur des noms `*.localhost` (certificat auto-signé ou autorité interne du proxy).

**Acceptance Criteria:**

**Given** le proxy TLS Traefik v3 (AD-21 `[À VÉRIFIER sur le VPS]`, version vérifiée par la story 7.1), ajouté à `docker-compose.yml`
**When** il est déployé
**Then** il est le seul service publié sur Internet ; il termine le TLS (certificats ACME renouvelés automatiquement) devant `api` et, dès qu'il existera, `backoffice` (Epic 10), et `api` n'expose plus aucun port hors du réseau Docker (AD-21, NFR-13)
**And** un appel en HTTP est redirigé vers HTTPS, et l'en-tête HSTS est envoyé.

**Given** la topologie d'hôtes d'AD-21, un seul domaine enregistrable dont les noms sont lus dans l'environnement (`DOMAINE_API`, `DOMAINE_WEB`, `DOMAINE_BACKOFFICE`)
**When** le proxy route les requêtes
**Then** `api.<domaine>` va vers `api` (app Android) ; `app.<domaine>` sert la build web compagnon (story 7.6) et `app.<domaine>/api/*` est relayé vers le même service `api`, de même origine (condition du cookie `SameSite=Strict` de la story 8.2, sans CORS avec identifiants) ; `admin.<domaine>` sert la build Flutter Web du back-office et `admin.<domaine>/api/*` est relayé vers `backoffice` (Epic 10)
**And** aucun nom de domaine n'est écrit en dur dans le code ni dans les labels du proxy ; en développement, les mêmes routes tournent sur `api.localhost`, `app.localhost` et `admin.localhost` (test de fumée documenté).

**Given** le proxy, première couche de limitation
**When** une adresse IP dépasse le débit grossier configuré
**Then** le middleware de limitation natif de Traefik répond 429 sans atteindre `api` ; les limites par compte et par numéro sont celles de l'application (story 7.4).

**Given** uvicorn derrière le proxy
**When** une requête arrive
**Then** uvicorn ne fait confiance à `X-Forwarded-For` que si la connexion vient de l'adresse du proxy : le proxy a une IP fixe sur le réseau Docker (déclarée dans `docker-compose.yml`) et `--forwarded-allow-ips` est réglé sur cette seule adresse ; un en-tête `X-Forwarded-For` envoyé par un client est ignoré (test) (AD-21).

**Given** `backend/app/main.py`
**When** le middleware CORS est configuré
**Then** `allow_origins` est lu dans la configuration (`ORIGINES_AUTORISEES`) et ne liste que les origines qui en ont besoin (aucune pour la web app et le back-office, servis de même origine que leur API ; la liste peut rester vide en production) ; `["*"]` a disparu ; les origines de développement ne figurent jamais dans la configuration de production
**And** une requête de navigateur depuis une origine non listée est refusée (test).

**Given** la tâche humaine du porteur de projet « acheter le domaine, DNS, certificats »
**When** la story passe en production
**Then** le domaine est acheté (PRD OQ 20), les enregistrements DNS de `api.`, `app.` et `admin.<domaine>` pointent vers le VPS, les certificats sont émis par le proxy, et les trois noms sont reportés dans `.env` ; la story est « terminée sauf mise en production » tant que cette tâche n'est pas faite (suivi de sprint).

### Story 7.4: Limitation du débit

En tant que porteur de projet,
je veux que les routes sensibles limitent le nombre d'appels par adresse IP, par numéro et par compte,
afin qu'aucune boucle ne puisse aspirer les pronostics, épuiser les SMS ou saturer le paiement.

**Acceptance Criteria:**

**Given** une dépendance FastAPI unique de limitation (`backend/app/api/deps_limites.py`, créée), configurée par route avec les clés `ip`, `numero` et `compte`, ses seuils et fenêtres lus dans la configuration
**When** une clé dépasse son seuil
**Then** la route répond 429 avec le code `trop_de_requetes` et l'en-tête `Retry-After`, jamais une trace technique (AD-21)
**And** l'adresse IP retenue est celle que uvicorn a validée derrière le proxy (story 7.3), jamais un en-tête brut.

**Given** les familles de routes
**When** la dépendance est posée
**Then** les routes de code SMS (Epic 8), d'initiation de paiement (Epic 9), d'extraction photo et de rafraîchissement Multi ont des seuils plus stricts que les autres ; sur les routes de code SMS, la limite par numéro est la limite contraignante et la limite par IP reste généreuse, parce que de nombreux abonnés partagent une même IP derrière le NAT des opérateurs (CGNAT)
**And** la clé `compte` s'applique dès qu'une route a un appelant authentifié (Epic 8) ; d'ici là, elle est testée avec une identité simulée.

**Given** plusieurs workers uvicorn
**When** ils comptent les appels
**Then** les compteurs sont partagés dans la table `comptes.limite_debit` (révision Alembic de cette story, AD-19 ; SQLite par `schema_translate_map` dans les tests), jamais propres à un processus (test à deux workers simulés).

**Given** les seuils de production
**When** ils sont fixés
**Then** ils figurent dans `.env.example` avec leur justification, sans aucune valeur secrète.

### Story 7.5: Aucun secret dans les binaires

En tant que porteur de projet,
je veux un contrôle qui prouve qu'aucune clé de fournisseur n'est livrée dans l'APK ni dans la web app,
afin qu'une décompilation ne donne accès ni à la vision IA, ni à l'agrégateur de paiement, ni au fournisseur de SMS.

**Acceptance Criteria:**

**Given** l'APK de production et le bundle web construits
**When** le script `scripts/verifier_secrets_binaires.py` (créé) les parcourt
**Then** il ne trouve aucun motif de clé connu (Anthropic `sk-ant-`, clés privées PEM, motifs de l'agrégateur et du fournisseur de SMS déclarés dans le script dès leur choix, PRD OQ 15 et 17) ni aucune valeur du `.env` de production, et échoue sinon (NFR-15, AD-21)
**And** une clé publique est acceptée, jamais une clé privée ; la procédure de construction de production (documentée dans `docs/`) exécute le script avant toute publication.

**Given** le dépôt
**When** le même script inspecte `git ls-files`
**Then** aucun `.env` n'est suivi ; seul `.env.example`, sans valeur, l'est, et `.gitignore` exclut `.env`
**And** les clés ne vivent que dans l'environnement des services du serveur.

### Story 7.6: Web app compagnon en production

En tant que turfiste,
je veux ouvrir la web app compagnon sur mon ordinateur, en HTTPS, sur sa propre adresse,
afin de préparer mes courses sur grand écran avec les mêmes écrans que sur mon téléphone.

**Bloqué par :** l'achat du domaine et le DNS (PRD OQ 20, tâche humaine de la story 7.3), pour la mise en production.
**Livrable sans :** build servie et testée en local sur `app.localhost`.

**Acceptance Criteria:**

**Given** la build Flutter Web de production (`flutter build web --release`)
**When** elle est servie par le proxy TLS (story 7.3) sur `app.<domaine>`
**Then** toutes ses requêtes passent en HTTPS vers `app.<domaine>/api`, de même origine (relayé vers `api`, story 7.3) ; l'URL de base de l'API est relative, jamais un domaine écrit en dur.

**Given** un écran large
**When** la web app s'affiche
**Then** elle suit la mise en page à deux colonnes de `mockups/web-compagnon.html` (liste des courses, détail), avec les mêmes composants que l'app mobile (UX-DR22)
**And** une mention permanente dit que la web app exige une connexion, au mot près d'EXPERIENCE.md : « Web : connexion requise ; l'app Android fonctionne hors ligne » ; le cache local reste désactivé sur le web (`kIsWeb`), comme aujourd'hui (décision D-7).

**Given** la liste des fonctionnalités de l'app mobile
**When** la liste de contrôle de la story est remplie
**Then** chaque fonctionnalité de la web app existe dans l'app mobile, aucune n'est propre au web (PRD FR-38, §5)
**And** les fonctionnalités mobiles absentes du web (prise de photo par la caméra, protection d'écran, code PIN) sont listées avec leur raison.

### Story 7.7: Publication sur le Play Store

En tant que porteur de projet,
je veux publier l'app Android signée sur le Play Store avec ses textes légaux,
afin que les utilisateurs l'installent depuis une source sûre et que la mise en vente devienne possible.

**Bloqué par :** le compte développeur Google Play (tâche humaine du porteur de projet) ; la consultation juridique (PRD §9.2) pour les textes définitifs ; PRD OQ 18 (règles de Google Play, tranchée par la story 9.0) pour la fiche et la diffusion publique.
**Livrable sans :** build signée, contrôle de la story 7.5, textes légaux en version provisoire marquée comme telle, fiche préparée ; diffusion limitée au test interne ou fermé.

**Acceptance Criteria:**

**Given** l'app Android de production
**When** elle est construite
**Then** elle est signée par une clé d'upload conservée hors du dépôt, avec la signature d'app Play activée, et passe le contrôle de la story 7.5.

**Given** les textes légaux
**When** l'app est soumise
**Then** la politique de confidentialité, les conditions générales d'utilisation et les conditions générales de vente sont publiées sur une URL HTTPS stable, chacune avec sa version et sa date ; leur version publiée est celle que l'API expose par `CGU_VERSION` (story 7.9), mise à jour à chaque nouvelle version (PRD §6.1, NFR-16)
**And** leur contenu est validé par le porteur de projet après la consultation juridique (PRD §9.2) ; la story peut se terminer sur une version provisoire marquée comme telle, la mise en vente restant bloquée.

**Given** la fiche du Play Store
**When** elle est préparée
**Then** elle respecte les règles de Google Play pour une app liée aux paris (PRD OQ 18) : aucune promesse de gain, rappel de jeu responsable, classification d'âge adaptée ; la décision sur le paiement Mobile Money hors de la facturation Google Play est celle de la story 9.0, reprise dans les notes de la story avec sa source
**And** la première diffusion se fait en test interne ou fermé ; la diffusion publique attend les conditions de mise en vente (PRD §6.1).

### Story 7.8: Fermer l'API déployée en attendant les comptes

En tant que porteur de projet,
je veux que l'API déployée ne soit joignable que depuis mes adresses **et** avec un secret partagé, jusqu'à ce que chaque route vérifie le compte et le palier,
afin que les pronostics du jour ne soient lus par personne d'autre et que personne n'écrive anonymement dans la base.

*Démarre tout de suite : ne dépend ni de la vérification du VPS (story 7.1), ni du proxy TLS (story 7.3).*

**Acceptance Criteria:**

**Given** l'API déployée, où `GET /dashboard/data` sert aujourd'hui les pronostics du jour sans authentification et `POST /pronostics` accepte des écritures anonymes (architecture, Deferred)
**When** la première couche est posée — liste d'adresses du pare-feu de l'hôte
**Then** le port 8000 de l'hôte n'accepte que les adresses du porteur de projet (réseau personnel ou VPN, ex. WireGuard), lues dans une configuration versionnée sans valeur secrète ; la règle est posée dans la chaîne iptables `DOCKER-USER`, parce que Docker publie ses ports en contournant `ufw` (AD-21)
**And** le script qui pose la règle est idempotent, documenté dans `docs/`, et survit au redémarrage de l'hôte et de Docker (essai consigné dans les notes).

**Given** la seconde couche — un middleware de l'application `api` (`backend/app/api/acces_restreint.py`, créé)
**When** une requête arrive
**Then** elle doit porter le secret partagé `ACCES_RESTREINT_SECRET` (environnement du serveur seulement), en HTTP Basic ou en `Authorization: Bearer`, comparé en temps constant (`hmac.compare_digest`) ; sinon la réponse est 401 sans détail ; `/health` en est exempté
**And** le middleware est actif dès que `ACCES_RESTREINT_SECRET` est défini et refuse de démarrer en production s'il manque (test) ; aucun journal n'écrit le secret.

**Given** l'app mobile de développement et le navigateur du porteur de projet
**When** ils appellent l'API depuis une adresse autorisée (VPN compris)
**Then** ils fonctionnent comme avant : la build de développement reçoit le secret par `--dart-define` (jamais dans le code, jamais dans la build de production ni dans la web app publiée, contrôle de la story 7.5), et le navigateur le saisit à l'invite HTTP Basic.

**Given** un test de fumée (procédure documentée)
**When** il appelle `GET /dashboard/data`, `GET /courses` et `POST /pronostics` depuis une adresse non autorisée, puis depuis une adresse autorisée sans secret
**Then** les six appels sont refusés (la première série au pare-feu, la seconde par le middleware), `/health` répond depuis une adresse autorisée sans secret, et le résultat est consigné dans les notes de la story.

**Given** le webhook de l'agrégateur de paiement (story 9.5)
**When** la story 9.5 démarre
**Then** une exception limitée à la route webhook est ajoutée : filtrée par les plages d'adresses publiées par l'agrégateur (bac à sable compris), sans secret partagé puisque la notification est vérifiée par signature et par requête de statut ; elle est décrite dans les notes de la story 9.5, jamais élargie à d'autres routes.

**Given** la restriction en place
**When** le porteur de projet veut la lever
**Then** la levée n'a lieu qu'après la livraison des stories 9.2 (classement des routes, AD-15) et 10.7 (le tableau de bord a quitté `api`), par une décision consignée dans le suivi de sprint, jamais comme effet de bord d'un déploiement ; à partir de la story 7.3, la liste d'adresses peut passer au middleware IP du proxy, sans relâcher le secret.

### Story 7.9: Exposer la version des conditions en vigueur (`CGU_VERSION`)

En tant que turfiste,
je veux que l'app sache quelle version des conditions générales et de la politique de confidentialité est en vigueur,
afin d'accepter à l'inscription la bonne version, avec un lien vers son texte.

*Extraite de la story 7.7 le 2026-11-16 (correctifs du contrôle de préparation, M7) : indépendante de la publication sur le Play Store.*

**Acceptance Criteria:**

**Given** la configuration du serveur
**When** elle est lue au démarrage
**Then** elle porte `CGU_VERSION` (identifiant de version, ex. `2026-11-provisoire`), la date de la version et les URL HTTPS des conditions générales d'utilisation, des conditions générales de vente et de la politique de confidentialité ; une valeur absente empêche `api` de démarrer (test).

**Given** `GET /conditions` (classe *publique*, schéma typé, AD-4)
**When** l'app ou la web app l'appelle
**Then** la réponse porte `{version, date, url_cgu, url_cgv, url_confidentialite}` ; elle est lue par l'écran Connexion (story 8.1) pour la case d'acceptation et ses liens.

**Given** des textes encore provisoires (consultation juridique, PRD §9.2, story 7.7)
**When** la version est exposée
**Then** elle porte le drapeau `provisoire: true`, et un changement de version ne demande aucune nouvelle version de l'app (test : la réponse suit la configuration).

### Story 7.10: Écrivain du journal d'audit

En tant que porteur de projet,
je veux une seule fonction qui inscrit chaque action sensible dans un journal chaîné, disponible dès les premières stories de comptes,
afin que chaque story instrumente ses propres événements au moment où elle les crée, sans reprise ultérieure.

*Ajoutée le 2026-11-16 (correctifs du contrôle de préparation, F9). L'export quotidien de la tête, la commande de vérification et l'écran de lecture restent à la story 10.4.*

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `audit`
**When** elle est appliquée
**Then** elle crée `audit.journal_audit` (identifiant croissant, instant `timestamptz`, acteur — type `compte`, `personnel` ou `systeme` et identifiant —, type d'événement, cible, détail JSON, `empreinte_precedente`, `empreinte`) ; aucun rôle de service n'y écrit directement : le seul chemin est la fonction SQL `audit.inscrire(...)`, `SECURITY DEFINER`, propriété d'un rôle sans connexion, `search_path` fixé ; `role_api` et `role_backoffice` n'ont que `EXECUTE` sur cette fonction, `role_backoffice` a aussi `SELECT` sur la table ; aucun rôle n'a `INSERT` direct, `UPDATE` ni `DELETE` (test de droits sur PostgreSQL) (AD-19, AD-20).

**Given** la fonction unique `inscrire_audit(session, acteur, evenement, cible, detail)` (`backend/app/data/audit.py`, créé), seul chemin d'écriture du journal
**When** elle est appelée dans la transaction de l'action journalisée
**Then** elle appelle `audit.inscrire(...)`, qui prend un verrou consultatif PostgreSQL de transaction, lit l'empreinte de la dernière ligne, calcule `empreinte = sha256(empreinte_precedente ‖ contenu canonique de la ligne)` et insère la ligne ; l'action et sa ligne d'audit sont validées ou annulées ensemble (test)
**And** deux processus qui écrivent en même temps laissent une chaîne continue (test concurrent sur PostgreSQL) ; sur SQLite (tests), la fonction tourne sans verrou consultatif.

**Given** les types d'événements d'AD-20
**When** une story crée l'action correspondante
**Then** elle appelle `inscrire_audit` avec un type déclaré dans un registre unique (`backend/app/data/audit_evenements.py`) ; un type non déclaré est refusé (test) ; la répartition est : ajout et retrait d'appareil (8.2, 8.6, 8.7), changement de numéro et d'email (8.4, 8.5), droit créé par webhook (9.5), Duo (9.6), saisie créée, validée ou rejetée (10.3), tentative d'accès refusée du personnel et connexion du personnel (10.1, 10.2), lecture du tableau de bord (10.7), licence manuelle demandée et approuvée (10.5), modification d'une offre et révocation d'un droit (10.6).

**Given** le détail d'un événement
**When** il est écrit
**Then** il ne contient jamais de code OTP, de jeton, de mot de passe, de secret TOTP ni de numéro de carte (test sur le registre des champs autorisés) (NFR-14).

## Epic 8: Comptes, connexion et appareils

Paul crée son compte avec son numéro, protège l'app par un code PIN, retrouve son compte s'il change de numéro, voit et gère ses appareils, rattache son ordinateur par QR code et retrouve ses courses suivies, ses réglages et ses pronostics retenus sur chacun d'eux (UJ-5, UJ-6).

### Story 8.1: Créer son compte et se connecter par son numéro

En tant que turfiste,
je veux créer mon compte ou me connecter avec mon numéro de téléphone et un code reçu par SMS,
afin d'accéder au service sans retenir de mot de passe.

**Dépend de :** stories 7.2, 7.4, 7.9 (`CGU_VERSION`) et 7.10.
**Bloqué par :** PRD OQ 17 (fournisseur OTP, qui doit aussi couvrir les SMS transactionnels d'alerte) pour l'envoi réel.
**Livrable sans :** tout le parcours, serveur et écran, avec le faux `otp_client` (code lisible dans les journaux de développement seulement, jamais en production).

**Acceptance Criteria:**

**Given** `backend/app/data/otp_client.py` (créé), seul module à connaître le fournisseur choisi (PRD OQ 17 ; WhatsApp préféré quand il est disponible, sinon SMS) (AD-16, AD-1)
**When** l'API demande l'envoi d'un code
**Then** elle appelle une fonction normalisée de ce module, et aucun autre module ne connaît le format du fournisseur ; sa clé ne vit que dans l'environnement du serveur (story 7.5)
**And** un faux client sert aux tests ; aucun test n'envoie de vrai SMS.

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée `compte` (numéro vérifié au format E.164, unique ; `identifiant_court` aléatoire et unique, jamais dérivé du numéro ; `cgu_version_acceptee` ; `cgu_acceptee_le` ; `cree_le`) et `code_otp` (numéro, empreinte du code — jamais le code en clair —, `expire_le`, essais, `consomme_le`), instants en `timestamptz` (AD-16, AD-19)
**And** l'empreinte est un HMAC-SHA256 du code avec une clé serveur (`OTP_HMAC_CLE`, environnement du serveur seulement), jamais un sha256 simple qu'un attaquant ayant la base casserait hors ligne en 10⁶ essais ; la vérification compare en temps constant (test) (NFR-14).

**Given** `POST /auth/code` (classe *publique*) avec un numéro valide
**When** la demande respecte les limites de la story 7.4 (par numéro : contraignante ; par IP : généreuse, CGNAT)
**Then** un code est envoyé via `otp_client`, valable 5 minutes ; la réponse est la même que le numéro ait un compte ou non (même corps, même code HTTP) (FR-31)
**And** un numéro invalide est refusé avec un code d'erreur ; une limite dépassée renvoie 429.

**Given** `POST /auth/verifier` (classe *publique*) avec le numéro et le code
**When** le code est juste, non expiré et sous 5 essais
**Then** le code est consommé ; un numéro sans compte crée le compte seulement si la requête porte l'acceptation des conditions dans leur version en vigueur (`CGU_VERSION`, story 7.9), enregistrée dans `cgu_version_acceptee` et `cgu_acceptee_le` ; sans elle, aucun compte n'est créé (PRD §6.1)
**And** un code faux décompte un essai ; au 5e, le code est invalidé ; un code expiré ou épuisé renvoie `code_expire` ou `trop_d_essais` ; l'ouverture de la session est ajoutée par la story 8.2.

**Given** l'écran Connexion, porte placée avant la pile de navigation (UX-DR14, `mockups/connexion.html` étapes 1 et 2)
**When** l'utilisateur saisit son numéro, touche « Recevoir le code », puis saisit le code
**Then** l'`otp-field` est un seul champ de 6 cases, rempli automatiquement par le SMS quand Android le permet (SMS Retriever ou User Consent), collage accepté, avec « Renvoyer le code » désactivé et son temps restant écrit ; à l'inscription, la case d'acceptation des conditions générales et de la politique de confidentialité (liens vers leur version en vigueur) n'est pas cochée par défaut et bloque la suite tant qu'elle ne l'est pas
**And** « Code expiré — demandez un nouveau code », « Trop d'essais — demandez un nouveau code » et « Trop de demandes — réessayez dans quelques minutes » s'affichent tels quels ; TalkBack lit le numéro chiffre par chiffre et annonce le remplissage automatique du code.

### Story 8.2: Session sécurisée et renouvellement des jetons

En tant que turfiste,
je veux rester connecté sur mon appareil sans me reconnecter, avec une session que je peux révoquer,
afin d'ouvrir l'app vite au guichet sans qu'un jeton volé reste utilisable.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée `appareil` (compte, type `telephone` ou `navigateur`, nom lisible, `cree_le`, `derniere_activite_le`, `retire_le` facultatif) et `session` (appareil, empreinte du jeton de renouvellement, `remplace_par` facultatif, `revoque_le` facultatif, `expire_le`) (AD-16).

**Given** une vérification de code réussie (story 8.1)
**When** l'appareil ouvre sa session
**Then** une ligne `appareil` est créée (ou retrouvée par l'identifiant local de l'appareil), et l'API renvoie un jeton d'accès de 15 minutes et un jeton de renouvellement lié à cette ligne (FR-33) ; l'ajout de l'appareil est inscrit au journal d'audit (story 7.10).

**Given** l'identifiant local de l'appareil (AD-16, base de la preuve de droit de la story 9.3)
**When** l'app est installée
**Then** un identifiant aléatoire de 128 bits est généré au premier lancement et rangé par `flutter_secure_storage` (Android Keystore) ; il n'est dérivé d'aucun identifiant matériel ; une réinstallation en génère un nouveau, donc un nouvel appareil (test).

**Given** le jeton d'accès
**When** l'API l'émet ou le vérifie
**Then** c'est un JWT signé EdDSA (Ed25519), de 15 minutes, portant `kid`, le compte et l'appareil ; sa clé de signature est distincte de celle des preuves de droit (story 9.3), vit dans l'environnement du serveur seulement, et la rotation par `kid` est testée ; un jeton d'un autre algorithme (dont `none`) est refusé (test) (AD-16).

**Given** `POST /auth/renouveler`
**When** un jeton de renouvellement valide est présenté
**Then** il est remplacé (rotation à chaque usage) et un nouveau jeton d'accès est émis
**And** la présentation d'un jeton déjà remplacé révoque toute la chaîne de sessions de cet appareil, qui doit se reconnecter par code (test) (FR-33).

**Given** l'app Android
**When** elle reçoit ses jetons
**Then** ils sont rangés par `flutter_secure_storage` (version vérifiée et épinglée à cette story) dans l'Android Keystore, jamais dans `shared_preferences` ni dans `hippique_cache.db`.

**Given** la web app compagnon
**When** elle ouvre une session
**Then** le jeton de renouvellement est posé par l'API dans un cookie préfixé `__Host-` (`httpOnly`, `Secure`, `SameSite=Strict`, `Path=/`, sans `Domain`), sur `app.<domaine>`, dont `/api` est relayé vers `api` (même origine, story 7.3) ; le jeton d'accès ne vit qu'en mémoire ; `flutter_secure_storage` ne contient jamais le jeton de renouvellement sur le web (AD-16)
**And** toute requête qui change un état porte un en-tête anti-CSRF vérifié par le serveur ; une requête sans lui, ou avec une valeur fausse, est refusée (test) ; aucune requête avec identifiants ne traverse d'origine (pas de CORS avec identifiants, story 7.3).

**Given** une route qui exige une session
**When** elle reçoit un jeton d'accès expiré, absent ou d'un appareil retiré
**Then** elle répond 401 avec un code ; l'app tente un seul renouvellement, puis ouvre Connexion.

**Given** `palier_actif(compte)`, fonction unique créée dans `backend/app/api/deps_droits.py`
**When** elle est appelée avant la story 9.1
**Then** elle renvoie le palier de configuration `PALIER_PAR_DEFAUT` (`gratuit` en production) ; la story 9.1 la remplace par la résolution des droits sans changer ses appelants `[ASSUMPTION: arbitrage de la mise à jour des epics du 2026-11-15, à confirmer par le porteur de projet]`.

### Story 8.3: Code PIN et verrouillage

En tant que turfiste,
je veux déverrouiller l'app par un code PIN que je choisis,
afin que quelqu'un qui prend mon téléphone n'ouvre pas mon compte.

**Bloqué par :** PRD OQ 14 pour la valeur définitive de `DELAI_VERROUILLAGE`.
**Livrable sans :** toute la story, avec une valeur provisoire de configuration consignée dans `.env.example`.

**Acceptance Criteria:**

**Given** une première connexion réussie sur le téléphone (story 8.2)
**When** Connexion passe à l'étape du code PIN (`mockups/connexion.html` étape 3)
**Then** l'utilisateur choisit un code de 4 à 6 chiffres au `pin-pad` et le confirme ; le code n'est jamais transmis au serveur (test qui enregistre tout le trafic réseau pendant le choix et le déverrouillage) (FR-32)
**And** le code PIN est une barrière locale seulement (AD-16) : son empreinte Argon2id (sel aléatoire, paramètres consignés) est rangée par `flutter_secure_storage` ; les jetons restent dans le stockage sécurisé, non chiffrés par le PIN ; la saisie est comparée à l'empreinte, jamais stockée en clair (test).

**Given** l'app qui passe en arrière-plan, ou reste inactive au-delà du délai réglé (`DELAI_VERROUILLAGE`, valeur : PRD OQ 14)
**When** l'utilisateur revient
**Then** la porte Déverrouillage s'affiche avant la pile de navigation (UX-DR15), avec le `pin-pad` : dix chiffres et « Effacer », touches ≥ 48dp, points de saisie sans les chiffres, validation automatique à la longueur choisie, jamais le clavier système
**And** le déverrouillage fonctionne hors ligne.

**Given** un code PIN faux
**When** il est saisi
**Then** « Code incorrect — N essais restants » s'annonce en région live polie ; au 5e, la session locale est effacée, « Session effacée — reconnectez-vous par code SMS » s'affiche, puis Connexion (FR-32)
**And** les données en cache de l'appareil restent ; « Code oublié ? » mène à la reconnexion par code SMS.

**Given** TalkBack
**When** le `pin-pad` est utilisé
**Then** chaque touche est libellée par son chiffre, la zone de saisie annonce « 3 chiffres sur 4 saisis » sans les dire, et l'erreur n'est jamais portée par une vibration ni une couleur seule.

**Given** la web app
**When** une session y est ouverte
**Then** elle n'a ni code PIN ni Déverrouillage : la session suit le navigateur (EXPERIENCE.md).

### Story 8.4: Profil et email de secours

En tant que turfiste,
je veux voir mon profil et y enregistrer un email vérifié,
afin de pouvoir récupérer mon compte si je perds mon numéro.

**Bloqué par :** PRD OQ 19 (fournisseur d'email, domaine d'envoi, SPF/DKIM/DMARC) pour l'envoi réel du lien de vérification.
**Livrable sans :** Profil, révision Alembic, routes et parcours de vérification complets avec le faux `email_client` (lien lisible dans les journaux de développement seulement).

**Acceptance Criteria:**

**Given** `backend/app/data/email_client.py` (créé), seul module à connaître le fournisseur d'email (AD-16, AD-1)
**When** l'API envoie un lien de vérification ou une alerte
**Then** elle passe par une fonction normalisée de ce module ; sa clé ne vit que dans l'environnement du serveur ; un faux client sert aux tests.

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** `compte` gagne `email` et `email_verifie_le`, facultatifs, et la table `lien_verification_email` (compte, empreinte du jeton, `expire_le`, `consomme_le`) est créée.

**Given** l'écran Profil, ouvert par l'icône compte de l'Accueil (UX-DR16)
**When** il est rendu
**Then** il montre le numéro, l'email de secours « vérifié » ou « non vérifié », le palier et la date de fin du droit, la version et la date des conditions acceptées, et les entrées « Mes appareils », « Scanner un QR code » et offres dès que leurs stories sont livrées (absentes avant, jamais désactivées).

**Given** un email saisi dans Profil
**When** l'utilisateur l'enregistre
**Then** il reste « non vérifié » jusqu'au clic sur le lien reçu (usage unique, durée limitée) ; un nouvel email ne remplace l'ancien qu'après sa propre vérification (FR-34) ; le changement d'email est inscrit au journal d'audit (story 7.10).

**Given** un compte dont `palier_actif` (story 8.2) est payant
**When** Profil s'ouvre sans email vérifié
**Then** le rappel non bloquant « Ajoutez un email de secours pour pouvoir récupérer votre compte » s'affiche à chaque ouverture (FR-34, UX-DR24) ; ce cas est testé avec un palier simulé.

### Story 8.5: Récupérer son compte et changer de numéro

En tant que turfiste,
je veux récupérer mon compte par mon email vérifié et le rattacher à un nouveau numéro,
afin de garder mes droits et mes données quand je change de numéro.

**Bloqué par :** PRD OQ 19 (fournisseur d'email) pour l'envoi réel du lien et de l'alerte ; PRD OQ 17 (SMS transactionnels d'alerte vers l'ancien numéro) ; PRD OQ 14 pour la valeur définitive de `DELAI_CHANGEMENT_NUMERO_HEURES`.
**Livrable sans :** tout le parcours avec les faux `email_client` et `otp_client` et une valeur provisoire du délai.

**Acceptance Criteria:**

**Given** un compte avec un email vérifié (story 8.4)
**When** l'utilisateur demande, depuis Connexion (« J'ai changé de numéro ») ou depuis Profil, le rattachement d'un nouveau numéro
**Then** depuis Connexion, il désigne son compte par son email vérifié (la réponse est la même que l'email existe ou non) ; depuis Profil, le compte est celui de la session
**And** le nouveau numéro est d'abord vérifié par un code (`otp-field`), puis un lien de confirmation part vers l'email vérifié ; la demande n'existe qu'après ce clic (FR-35).

**Given** un nouveau numéro qui a déjà un compte
**When** la demande est faite
**Then** elle est refusée avec le code `numero_deja_utilise` et l'app renvoie vers le support (« Ce numéro a déjà un compte — contactez le support ») ; aucune fusion de comptes n'a lieu au lancement (test).

**Given** une demande confirmée
**When** le délai de sécurité court (`DELAI_CHANGEMENT_NUMERO_HEURES`, 24 à 48 h, valeur : PRD OQ 14)
**Then** une alerte part vers l'ancien numéro (via `otp_client`) et vers l'email, chacune avec un lien d'annulation en un geste ; une annulation clôt la demande sans rien changer
**And** à l'échéance, le numéro du compte change ; demande, annulation et changement sont inscrits au journal d'audit (story 7.10).

**Given** le compte après le changement
**When** il est lu
**Then** ses droits, ses organisations, ses appareils et ses données synchronisées sont inchangés : ils suivent le compte, pas le numéro (FR-35)
**And** l'ancien numéro peut ensuite créer un autre compte.

**Given** un compte sans email vérifié dont le titulaire a perdu son numéro
**When** il demande la récupération
**Then** l'app dit que la récupération exige un email vérifié ; aucune autre preuve n'est acceptée au lancement (preuves complémentaires : Epic 12).

### Story 8.6: Mes appareils et limite d'appareils

En tant que turfiste,
je veux voir mes appareils, en retirer un à distance, et savoir pourquoi un nouvel appareil est refusé,
afin de garder le contrôle de mon compte sans jamais être déconnecté par surprise.

**Bloqué par :** PRD OQ 14 pour les valeurs définitives de `LIMITE_APPAREILS_<PALIER>`, `WEB_APPAREIL_INACTIF_JOURS` et du plafond quotidien de jetons de gestion ; PRD OQ 17 pour l'envoi réel des alertes SMS ; PRD OQ 19 pour l'alerte email.
**Livrable sans :** toute la story avec des valeurs provisoires de configuration et les faux `otp_client` et `email_client`.

**Acceptance Criteria:**

**Given** l'écran Mes appareils, ouvert depuis Profil (UX-DR17, `mockups/mes-appareils.html`)
**When** il est rendu
**Then** une `device-row` par appareil non retiré montre type et nom (« Téléphone Android », « Chrome sur Windows »), dernière activité, « Cet appareil » pour l'appareil courant et « Nouveau » à la première ouverture après un rattachement ; chaque ligne est un nœud TalkBack groupé (FR-36).

**Given** « Retirer » sur un autre appareil
**When** l'utilisateur confirme
**Then** l'appareil reçoit `retire_le`, toutes ses sessions sont révoquées, et sa prochaine requête reçoit 401 puis ouvre Connexion ; l'appareil courant ne se retire pas d'ici
**And** le retrait est inscrit au journal d'audit (story 7.10) et une alerte part vers l'email vérifié (et par SMS quand le fournisseur le permet).

**Given** un nouvel appareil qui se connecte par code (story 8.1)
**When** sa session s'ouvre
**Then** le contrôle de la limite du palier (`LIMITE_APPAREILS_<PALIER>`, configuration, PRD OQ 14, palier donné par `palier_actif`) et l'insertion de la ligne `appareil` se font dans une seule transaction, avec un verrou de ligne sur le compte, si bien que deux connexions simultanées ne dépassent jamais la limite (test concurrent) (AD-16)
**And** chaque session de navigateur compte comme un appareil ; un appareil navigateur qui ne s'est pas renouvelé depuis `WEB_APPAREIL_INACTIF_JOURS` est retiré automatiquement et libère sa place.

**Given** la limite atteinte
**When** un nouvel appareil se connecte
**Then** il est bloqué et aucun appareil existant n'est déconnecté ; l'écran Appareil bloqué dit « Votre palier permet 2 appareils, déjà utilisés » (nombre lu dans la configuration), avec « Retirer un appareil » (→ Mes appareils en mode restreint) et « Découvrir l'offre Duo », présent dès que l'écran Offres existe (Epic 9) (FR-36, UX-DR17).

**Given** un appareil qui a réussi la vérification par code mais est refusé à la limite (AD-16, session restreinte)
**When** le serveur répond
**Then** aucune ligne `appareil` n'est créée ; la réponse porte un jeton de gestion des appareils : portée `appareils:gerer`, durée 10 minutes, usage unique pour **un seul** retrait, lié au compte et à l'identifiant local de l'appareil refusé, sans jeton de renouvellement
**And** ce jeton n'ouvre que `GET /moi/appareils` (liste) et `DELETE /moi/appareils/{id}` (retrait d'un appareil) ; toute autre route — contenu, profil, paiement, synchronisation — répond 403 (test par route) ; un jeton présenté depuis un autre identifiant local, expiré ou déjà dépensé est refusé (test).

**Given** un retrait fait avec ce jeton
**When** il réussit
**Then** le jeton est dépensé ; l'appareil bloqué doit refaire la connexion normale par code pour obtenir une session (il tient alors sous la limite) ; le retrait envoie l'alerte email (et SMS quand disponible), est inscrit au journal d'audit, et l'appareil retiré l'apprend à son prochain renouvellement
**And** sur un compte payant, un appareil entré par code seul après ce parcours relève du délai de sécurité contre le vol de carte SIM (story 9.11) comme tout nouvel appareil par code seul ; au plus `JETONS_GESTION_APPAREILS_PAR_JOUR` jetons sont émis par compte et par jour (configuration, PRD OQ 14), au-delà la réponse est 429 (test).

**Given** un appareil rattaché
**When** le rattachement réussit
**Then** une alerte SMS part vers le numéro du compte, jamais en notification push, et la ligne porte « Nouveau » à la prochaine ouverture de Mes appareils (FR-36) ; l'ajout est inscrit au journal d'audit (story 7.10).

### Story 8.7: Rattacher son ordinateur par QR code

En tant que turfiste,
je veux connecter la web app de mon ordinateur en scannant un QR code avec mon téléphone déjà connecté,
afin de préparer sur grand écran sans ressaisir de code.

**Acceptance Criteria:**

**Given** la web app non connectée (Connexion web, UX-DR19, `mockups/web-compagnon.html`)
**When** elle s'affiche
**Then** un `qr-pairing` montre un QR code portant un jeton d'appairage à usage unique valable 2 minutes, son temps restant écrit, un nouveau code à l'expiration, et « Se connecter par code SMS » (story 8.1) pour qui n'a pas son téléphone (FR-37)
**And** le jeton est stocké côté serveur par son empreinte, avec le navigateur demandeur (type, nom lisible), et ne sert qu'une fois.

**Given** le téléphone connecté, Profil → « Scanner un QR code » (paquet de scan vérifié et épinglé à cette story, ex. `mobile_scanner`)
**When** il scanne un QR valide
**Then** une feuille d'approbation dit « Connecter Chrome sur Windows à votre compte ? » (« Approuver » / « Refuser ») ; « Approuver » marque l'appairage approuvé côté serveur ; « Refuser » ou l'expiration n'ouvre rien
**And** seul un appareil de type téléphone avec une session ouverte peut approuver ; un QR expiré ou déjà utilisé affiche « QR code expiré — affichez-en un nouveau sur l'ordinateur ».

**Given** la page web qui attend l'approbation (AD-16)
**When** elle interroge `GET /appairage/{id}/statut` (classe *publique*, identifiant opaque, limite par IP de la story 7.4) toutes les 2 secondes, pendant au plus 2 minutes
**Then** tant que rien n'est décidé, la réponse dit `en_attente` ; refusé ou expiré, elle dit `refuse` ou `expire` et la page propose un nouveau QR ; approuvé, **cette réponse** ouvre la session du navigateur : elle pose le cookie `__Host-` de renouvellement de la story 8.2 (de même origine, `app.<domaine>/api`) et renvoie le jeton d'accès, une seule fois — une seconde interrogation après l'approbation ne renvoie plus de session (test)
**And** au-delà de 2 minutes, la page arrête d'interroger et affiche le QR expiré.

**Given** une approbation
**When** le navigateur rejoint le compte
**Then** il compte dans la limite d'appareils, avec le même contrôle transactionnel que la story 8.6 (écran Appareil bloqué si la limite est atteinte), et l'alerte SMS de la story 8.6 part (FR-36, FR-37)
**And** le parcours web se fait entièrement au clavier, avec le `focus-indicator`.

### Story 8.8: Retrouver ses sélections et pronostics sur tous ses appareils

En tant que turfiste,
je veux retrouver mes courses suivies, mes réglages et mes pronostics retenus sur chacun de mes appareils,
afin de préparer sur l'ordinateur et décider sur le téléphone sans rien ressaisir.

**Dépend de :** story 8.9 (la course suivie et son stockage local existent) ; story 5.20 pour l'envoi du pronostic retenu côté appareil.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée les tables de synchronisation par compte — courses suivies et réglages du moteur (clé, contenu, `recu_le` du serveur), pronostics retenus (`cle_course`, contenu, `recu_le`, `heure_depart`) —, les courses étant nommées par `cle_course` (AD-12), jamais par `course_id`.

**Given** les routes de synchronisation (`GET /synchronisation`, `PUT /synchronisation/{type}/{cle}`)
**When** un appareil envoie une course suivie ou un réglage
**Then** la dernière écriture l'emporte selon l'heure de réception du serveur, jamais selon une heure fournie par l'appareil (AD-9)
**And** les coefficients du moteur expert sont stockés mais ne sont pas renvoyés à un palier qui ne peut pas les utiliser.

**Given** un pronostic retenu envoyé par un appareil
**When** le serveur le reçoit
**Then** il est accepté s'il arrive avant l'heure de départ de la course (instant UTC du serveur) et devient la version de référence ; reçu après le départ, il est refusé avec le motif `recu_apres_depart`, et la réponse porte la version d'avant le départ si le serveur en a une (FR-38, AD-9)
**And** l'envoi côté appareil est branché par la story 5.20 ; si elle n'est pas encore livrée, cette partie est livrée et testée côté serveur seulement.

**Given** une version refusée côté appareil
**When** l'app reçoit le refus
**Then** elle ne supprime jamais sa version : elle la garde avec `synchronise = false` et `motif = 'recu_apres_depart'` (colonnes ajoutées par la version suivante de `hippique_cache.db`, numérotée à la livraison, `onCreate` direct et chaque `onUpgrade` testés, AD-9) ; si le serveur a une version d'avant le départ, l'app l'affiche et garde la sienne en note locale, sinon la version locale reste la source du débrief, étiquetée « non synchronisé ».

**Given** des changements faits hors ligne sur le téléphone
**When** le réseau revient
**Then** ils sont envoyés à l'ouverture de l'app ou au rafraîchissement explicite, sans tâche de fond ; l'app reste utilisable hors ligne pendant tout ce temps (FR-13, FR-38).

**Given** les lignes du Multi
**When** le palier actif ne permet pas le Multi
**Then** elles ne sont plus envoyées ; celles déjà sur le serveur survivent à la baisse de palier (AD-9).

**Given** la purge à 90 jours
**When** elle s'exécute (au démarrage de l'app pour l'appareil, par une commande quotidienne sous `role_api` pour le serveur)
**Then** elle s'applique aux deux copies (AD-9).

**Given** la web app
**When** elle ouvre une course suivie ou un pronostic retenu
**Then** elle lit la copie du serveur seulement, sans cache local, et écrit par les mêmes routes.

**Given** les courses suivies de la story 8.9, stockées sur l'appareil
**When** la synchronisation tourne
**Then** chaque suivi et chaque arrêt du suivi sont envoyés par `PUT /synchronisation/course_suivie/{cle_course}` (un arrêt est une écriture « non suivie », jamais une suppression silencieuse) ; les courses suivies reçues d'un autre appareil apparaissent dans « Courses suivies » de l'Accueil et dans la colonne gauche de la web app.

### Story 8.9: Suivre une course

*Ajoutée le 2026-11-16 (correctifs du contrôle de préparation, É2) ; à réaliser avant la story 8.8, qui la synchronise.*

En tant que turfiste,
je veux marquer les courses que je suis et les retrouver en tête de l'Accueil,
afin de revenir en un geste aux courses que je prépare, au guichet comme sur l'ordinateur.

**Acceptance Criteria:**

**Given** l'écran d'une course (en-tête de la Liste des partants et de Résultats)
**When** il est rendu
**Then** un `followed-race` en bascule (étoile + libellé « Suivre » / « Suivie ») suit ou arrête de suivre la course ; la cible fait au moins 48dp, l'état est dit par le texte et pas seulement par l'étoile, et TalkBack annonce « Suivre la course, bouton bascule, non activé » puis le changement d'état (FR-38, UX-DR12).

**Given** une course suivie
**When** l'utilisateur la suit
**Then** elle est enregistrée sur l'appareil dans le cache local (`hippique_cache.db`, table `course_suivie` : `cle_course`, `suivie`, `modifiee_le`, `synchronise`), ajoutée par la version suivante du cache, numérotée à la livraison, `onCreate` direct et chaque `onUpgrade` testés (AD-9) ; la course est nommée par `cle_course` (AD-12)
**And** suivre et arrêter de suivre fonctionnent hors ligne ; la ligne garde `synchronise = false` jusqu'à la story 8.8.

**Given** l'Accueil
**When** au moins une course du jour ou à venir est suivie
**Then** une section « Courses suivies » en tête liste une ligne `followed-race` par course (heure locale de l'appareil, hippodrome, numéro de course, étoile active) qui ouvre la course ; la section est masquée si elle est vide ; une course passée depuis plus de 90 jours sort de la liste avec la purge de la story 5.20.

**Given** la web app compagnon
**When** une session est ouverte
**Then** la colonne gauche montre la même section « Courses suivies » au-dessus du programme, lue depuis le serveur (story 8.8) ; avant la story 8.8, la section est absente du web, jamais vide par erreur.

**Given** les composants
**When** la story est livrée
**Then** `followed-race` (bascule et ligne de liste) suit les tokens de DESIGN.md et le parcours UJ-6 d'EXPERIENCE.md (étapes 4 et 6), sans fonctionnalité propre au web (FR-38).

## Epic 9: Licences, paliers et paiement Mobile Money

L'utilisateur voit ce que son palier autorise et ce qu'il manque, paie un pass ou un abonnement par Mobile Money, partage son palier par l'offre Duo et garde ses fonctionnalités hors ligne pendant son droit ; le serveur ne renvoie jamais ce que le palier n'autorise pas. **Ordre :** la story 9.0 est une barrière à franchir avant la story 9.5 ; elle peut se faire à tout moment avant.

### Story 9.0: Vérifier les règles de paiement Google Play (OQ 18)

*Ajoutée le 2026-11-16 (correctifs du contrôle de préparation, É5) : tâche de recherche et de décision, sans code ; barrière avant la story 9.5.*

En tant que porteur de projet,
je veux savoir, sources à l'appui, si une app Android du Play Store peut vendre un accès numérique par Mobile Money hors de la facturation Google Play, pour une app liée aux paris hippiques au Cameroun,
afin de ne pas construire un parcours de paiement que Google refuserait.

**Bloqué par :** rien (recherche : PRD OQ 18, `bmad-deep-recon`).
**Livrable sans :** sans objet ; la story se termine sur une décision écrite.

**Acceptance Criteria:**

**Given** les règles en vigueur de Google Play (règles de paiement, programme de facturation alternative ou externe et pays où il s'applique, règles sur les jeux d'argent et les apps liées aux paris, règles d'âge)
**When** la recherche est faite
**Then** un compte rendu daté (`_bmad-output/planning-artifacts/research/`) cite chaque source (URL et date de consultation) et répond : le paiement Mobile Money dans l'app est-il permis pour ce contenu, à quelles conditions (déclaration, programme, frais), ou interdit
**And** il dit ce qui reste incertain et qui peut le lever (support Google Play, avis juridique PRD §9.2).

**Given** le compte rendu
**When** le porteur de projet décide
**Then** la décision est consignée dans le PRD (OQ 18) et dans les notes de la story 7.7, parmi : paiement dans l'app tel que prévu (story 9.5 inchangée) ; paiement hors de l'app (page web, l'app ne fait que lire le droit) ; facturation Google Play ; ou autre parcours — et, si le parcours change, la story 9.5 est réécrite avant de démarrer (`bmad-correct-course`)
**And** tant que cette story n'est pas terminée, la story 9.5 ne démarre pas (suivi de sprint).

### Story 9.1: Droits datés et organisations

En tant que porteur de projet,
je veux que chaque compte appartienne à une organisation et que l'accès vienne de droits datés, insérés sans jamais être réécrits,
afin d'exprimer un pass journée, un abonnement ou un Duo sans champ « abonné », et sans réécrire le schéma quand le Club viendra.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée `organisation` (type `personnelle` ou `partagee`, places facultatives), `membre` (organisation, compte, `ajoute_le`, `retire_le` facultatif) et `droit` (organisation, palier `gratuit`/`turfiste`/`expert`, `debut`, `fin`, `source` `paiement` ou `licence_manuelle` — une licence manuelle est une ligne `droit` de `source = 'licence_manuelle'`, story 10.5 —, origine — référence de paiement ou identifiant de la demande de licence —, `revoque_le` et `motif_revocation` facultatifs, instants en `timestamptz`) ; aucun champ booléen « abonné » n'existe (test sur le schéma) (AD-18)
**And** chaque compte existant reçoit son organisation personnelle, et tout nouveau compte la reçoit à sa création.

**Given** la table `droit`
**When** le code applicatif l'utilise
**Then** `repository.py` n'offre que l'insertion et la révocation (qui pose une seule fois `revoque_le` et `motif_revocation`) ; aucun rôle n'a `DELETE` ni `UPDATE` sur les autres colonnes (test de droits sur PostgreSQL) (AD-17)
**And** un droit n'appartient qu'à l'organisation du payeur — personnelle pour un achat seul, partagée pour un titulaire Duo — et n'est jamais écrit pour un membre (AD-18).

**Given** un compte
**When** `palier_actif(compte)` (story 8.2) est appelé
**Then** il renvoie le palier le plus élevé parmi les droits valides (`debut` ≤ instant UTC du serveur < `fin`) et non révoqués de son organisation personnelle et de l'organisation partagée dont il est membre actuel, sinon `gratuit` ; le palier de configuration de la story 8.2 disparaît (FR-39, AD-18)
**And** un compte est membre actuel d'au plus une organisation partagée (contrainte en base).

**Given** les cas de résolution
**When** les tests tournent
**Then** droit expiré → `gratuit`, données synchronisées conservées ; droit révoqué ignoré ; pass journée Expert pendant un mensuel Turfiste → `expert` pendant 24 h, puis `turfiste` ; membre d'un Duo Turfiste avec son propre droit Expert → `expert` ; bornes `debut` et `fin` du bon côté (FR-39, FR-43).

**Given** toute réponse authentifiée
**When** l'API répond
**Then** elle porte `version_droits`, qui change à chaque droit inséré ou révoqué et à chaque ajout ou retrait de membre du compte, et que l'app utilisera pour renouveler sa preuve de droit (story 9.3) (AD-15).

### Story 9.2: Le serveur filtre selon le palier

En tant que porteur de projet,
je veux que chaque route soit classée et que le serveur ne renvoie que ce que le palier autorise,
afin qu'une app modifiée ou une requête fabriquée ne lise aucune donnée réservée.

**Acceptance Criteria:**

**Given** `fixtures/acces_paliers.json` (créé), qui porte la matrice d'accès de PRD FR-39 (exigence ou champ → paliers autorisés, aperçus compris)
**When** les tests tournent
**Then** ses miroirs d'exécution Python (`backend/app/api/acces_paliers.py`) et Dart (`mobile/lib/data/acces_paliers.dart`) sont validés contre le fichier dans chaque langage, et toute dérive fait échouer la suite (AD-2, motif des miroirs d'exécution ; AD-9, AD-15).

**Given** toutes les routes des deux applications FastAPI (`backend/app/main.py`, service `api` ; `backend/app/backoffice/main.py`, service `backoffice`, Epic 10)
**When** un test les énumère
**Then** chacune appartient à exactement une classe : dans `api`, *publique* (demande et vérification de code, conditions en vigueur, jeton et statut d'appairage, webhook de paiement à signature vérifiée, santé), *compte + palier* (toute route de course, de pronostic, de Multi, d'extraction, d'import et de backfill, filtrée par la matrice) ou *interne, jamais servie* ; dans `backoffice`, *personnel seulement* (tableau de bord `/dashboard*`, évaluation, saisie, licences manuelles, offres, personnel, journal d'audit), servie seulement sur `admin.<domaine>` ; une route sans classe fait échouer la suite (AD-15)
**And** tant que la story 10.7 n'est pas livrée, `/dashboard*` et l'évaluation vivent encore dans `api` sous une classe transitoire *personnel seulement — à déplacer*, que le test n'accepte que pour cette liste fermée ; elles restent fermées par la restriction de la story 7.8 et répondent 404 sur `api.<domaine>` et `app.<domaine>` dès que le proxy de la story 7.3 route par hôte ; la story 10.7 les retire de `api` et la classe transitoire disparaît.

**Given** une route *compte + palier*
**When** elle répond
**Then** une seule dépendance FastAPI (`backend/app/api/deps_droits.py`) résout le compte et son palier actif (story 9.1), et la réponse est construite pour ce palier depuis le miroir de `acces_paliers.json` : un champ que le palier n'autorise pas est **absent**, jamais `null` ni masqué par l'app (test sur la réponse brute) (FR-39, NFR-12)
**And** l'historique complet des chevaux n'est renvoyé qu'aux paliers qui l'autorisent ; `/analyse`, `/courses/{id}/importer`, `/chevaux/{id}/backfill` et les routes d'extraction refusent un palier non autorisé avec 403 `palier_insuffisant` (palier requis en paramètre) ; `POST /multi/courses/{cle_course}/rafraichir` est réservé à l'Expert et compté dans les limites par compte de la story 7.4 (AD-10).

**Given** les données internes (instantané H-2, `probabilite_fondamentale`)
**When** n'importe quelle route répond, à n'importe quel palier
**Then** elles n'apparaissent jamais (test sur le schéma OpenAPI et sur les réponses) (AD-14, AD-15).

### Story 9.3: Droits disponibles hors ligne

En tant que turfiste,
je veux que mes fonctionnalités payées restent ouvertes hors ligne jusqu'à la fin de mon droit,
afin de préparer ma course dans les tribunes, même sans réseau.

**Acceptance Criteria:**

**Given** une paire de clés asymétriques (Ed25519 ou ES256 ; bibliothèque vérifiée et épinglée dans chaque langage à cette story), la clé privée dans l'environnement du serveur seulement, la clé publique dans l'app (story 7.5)
**When** l'API émet une preuve de droit (`GET /droits/preuve`)
**Then** la preuve signée porte `{compte, appareil, palier, fin_droit, emise_le, expire_le}` avec `expire_le = min(fin_droit, emise_le + ENTITLEMENT_TOKEN_MAX_DAYS)`, 7 jours par défaut (FR-44, AD-15).

**Given** l'app qui reçoit une preuve
**When** elle la vérifie
**Then** une signature fausse, ou un `appareil` différent de l'identifiant local, fait ignorer la preuve ; l'app mémorise l'heure de serveur la plus élevée qu'elle a vue et tient la preuve pour expirée si l'horloge de l'appareil est antérieure à cette heure ou postérieure à `expire_le`, sans délai de grâce (décision D-4 ; tests avec une horloge injectée, reculée comprise).

**Given** `version_droits` dans chaque réponse authentifiée (story 9.1)
**When** elle change
**Then** l'app demande une nouvelle preuve, sans redémarrage — ce qui couvre une confirmation de paiement tardive, un appareil retiré et un membre de Duo retiré (AD-15).

**Given** les fonctionnalités calculées sur l'appareil (mise Kelly, combinaisons, mode expert, Multi)
**When** le téléphone est hors ligne
**Then** elles restent ouvertes selon le palier de la preuve valide et le miroir Dart de `acces_paliers.json`, jusqu'à `expire_le` et jamais au-delà ; Profil dit « Droit Expert jusqu'au 22/11 (vérifié le 15/11) » (UX-DR24).

**Given** la version suivante de `hippique_cache.db` (numérotée à la livraison ; `onCreate` direct et chaque `onUpgrade` testés, AD-9)
**When** une réponse de course est mise en cache
**Then** elle enregistre `palier_recu`, le palier sous lequel le serveur l'a construite ; un champ en cache n'est affiché que si la preuve courante et `palier_recu` l'autorisent tous deux ; une hausse de palier invalide les réponses en cache, relues au prochain accès réseau (AD-9).

**Given** une preuve expirée
**When** l'app affiche une course en cache
**Then** les données restent consultables au niveau Gratuit et le contenu payant en cache (instantanés, value, mise Kelly, combinaisons, Multi) est masqué jusqu'à un nouveau droit (FR-44) ; le cache n'est pas chiffré (accepté, architecture Deferred).

### Story 9.4: Catalogue des offres

En tant que turfiste,
je veux voir les offres disponibles et ce que chacune débloque,
afin de choisir celle qui répond à ce qui me manque, sans pression ni promesse de gain.

**Bloqué par :** PRD OQ 13 (prix, places du Duo, matrice d'accès à confirmer) pour l'amorce définitive.
**Livrable sans :** table, route et écran avec des prix et des places provisoires de configuration, marqués comme tels dans les notes ; aucune mise en vente avec ces valeurs.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée la table `offre` (code, nom, palier, durée, prix et devise, places pour un Duo, `active`, `cree_le`) et l'amorce avec les offres de PRD FR-41 — pass journée (Expert pendant 24 h), pass semaine et mensuel Turfiste et Expert, Duo pour chaque palier payant et chaque durée — aux prix de configuration (PRD OQ 13) ; leur modification par les administrateurs, journalisée, arrive à la story 10.6 (AD-17).

**Given** `GET /offres` (classe *compte + palier*)
**When** il répond
**Then** il renvoie les offres actives sous schéma typé (AD-4), chacune avec ce qu'elle débloque en codes de `acces_paliers.json` ; une ligne de `offre` modifiée change la réponse sans nouvelle version de l'app (FR-41).

**Given** l'écran Offres (UX-DR18, `mockups/offres-paiement.html`), ouvert depuis Profil, un `locked-feature` ou un `teaser-banner`
**When** il est rendu
**Then** une `offer-card` par offre montre nom, palier, durée, prix et ce qu'elle débloque dans les termes de l'écran d'origine (« Débloque l'instantané H-10 ») ; les offres qui répondent au verrou touché viennent en tête ; un Duo dit son nombre de personnes et que chacun garde son compte
**And** le rappel de jeu responsable fait partie du flux de lecture ; aucun « gagnez plus », « pronostics gagnants », « populaire », compte à rebours ni urgence (test sur les textes) (UX-DR18, SM-C4)
**And** chaque `offer-card` est un nœud TalkBack groupé qui annonce nom, palier, durée, prix et ce qu'elle débloque.

### Story 9.5: Payer par Mobile Money

En tant que turfiste,
je veux payer une offre par MTN MoMo ou Orange Money depuis l'app,
afin d'activer mon palier sans carte bancaire.

**Dépend de :** story 9.0 (décision sur les règles de paiement de Google Play, OQ 18) — la story ne démarre pas avant ; story 9.4.
**Bloqué par :** PRD OQ 15 (agrégateur : contrat, clés, format du webhook, plages d'adresses) pour l'intégration réelle ; consultation juridique (PRD §9.2) pour la mise en vente.
**Livrable sans :** tout le parcours avec le faux agrégateur (`paiement_client` simulé : initiation, webhook signé, statut, rejeu, confirmation tardive) ; aucun paiement réel.

**Acceptance Criteria:**

**Given** `backend/app/data/paiement_client.py` (créé), seul module à connaître le format de l'agrégateur choisi (PRD OQ 15) (AD-17, AD-1)
**When** l'API initie un paiement, vérifie une notification ou demande un statut
**Then** elle passe par les fonctions normalisées de ce module ; ses clés ne vivent que dans l'environnement du serveur ; un faux agrégateur sert aux tests.

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée `paiement` (compte, offre, opérateur, référence de transaction avec contrainte d'unicité, statut `initie`/`en_attente`/`confirme`/`echoue`, instants).

**Given** une `offer-card` touchée sur Offres (story 9.4)
**When** l'écran Paiement s'ouvre (UX-DR18, `mockups/offres-paiement.html`)
**Then** il propose MTN MoMo ou Orange Money, le numéro du compte prérempli et modifiable, et le rappel de jeu responsable ; « Payer » appelle `POST /paiements` (limite stricte par compte, story 7.4), qui initie la transaction via `paiement_client`
**And** le `payment-status` affiche « Paiement en attente de confirmation — validez sur votre téléphone » ; l'app interroge le statut sans bloquer l'écran, et l'utilisateur peut le quitter.

**Given** une notification de l'agrégateur sur la route webhook (classe *publique*)
**When** sa signature est valide **et** la requête de statut à l'agrégateur confirme le paiement
**Then** un droit est inséré pour l'organisation du payeur (personnelle, ou partagée pour un Duo, story 9.6), une seule fois pour cette référence : une notification rejouée ne crée rien (test de rejeu) (FR-42, AD-17) ; la création du droit est inscrite au journal d'audit (story 7.10)
**And** le proxy peut restreindre cette route aux plages d'adresses publiées par l'agrégateur, si elles existent ; tant que la restriction de la story 7.8 tient, cette route seule en est exceptée, filtrée par ces plages (bac à sable compris), et l'exception est décrite dans les notes de la story.

**Given** une signature invalide, un statut non confirmé ou un échec
**When** la notification ou le statut est traité
**Then** aucun droit n'est créé, l'événement est journalisé et une alerte part au porteur de projet sur tout webhook en échec ; l'écran dit « Paiement non confirmé — aucun droit activé » + « Réessayer », jamais un droit partiel.

**Given** une confirmation tardive, après que l'utilisateur a quitté Paiement
**When** le droit est créé
**Then** `version_droits` change, l'app renouvelle sa preuve à sa prochaine requête (story 9.3), et le contenu remplace les verrous sans redémarrage ; `payment-status` dit « Pass semaine actif jusqu'au 22/11 » (FR-42)
**And** l'app ne décide jamais seule qu'un paiement a réussi ; le prix n'apparaît que sur Offres et Paiement (UX-DR18) ; `payment-status` est une région live polie.

### Story 9.6: Offre Duo

En tant que titulaire d'une offre Duo,
je veux inviter une ou deux personnes qui gardent chacune leur compte,
afin de partager mon palier sans partager mon compte.

**Bloqué par :** PRD OQ 13 (nombre de places du Duo, 2 ou 3, et prix) pour les valeurs définitives.
**Livrable sans :** toute la story avec un nombre de places provisoire de configuration.

**Acceptance Criteria:**

**Given** un paiement Duo confirmé (story 9.5)
**When** son droit est créé
**Then** il appartient à une organisation partagée dont le payeur est titulaire, avec le nombre de places de l'offre (PRD OQ 13) (AD-18).

**Given** le titulaire, dans la section Duo de Profil (membres, « Inviter », « Retirer », UX-DR16)
**When** il invite un numéro
**Then** la personne invitée garde ou crée son propre compte et ses appareils, accepte l'invitation depuis son app et devient `membre` de l'organisation, dans la limite des places ; une personne déjà membre d'une autre organisation partagée doit d'abord la quitter (FR-43)
**And** aucun droit n'est écrit pour elle : son palier vient du droit du titulaire par `palier_actif` (story 9.1), avec la limite d'appareils de ce palier ; si elle a son propre droit, elle garde le plus élevé des deux (FR-43, AD-18).

**Given** le titulaire qui retire un membre, ou le droit du titulaire qui expire
**When** le changement est fait
**Then** seuls `membre.retire_le` ou la fin du `droit` changent, et l'ajout ou le retrait d'un membre est inscrit au journal d'audit (story 7.10) ; le membre revient à son propre palier (Gratuit sans droit propre), sa `version_droits` change et son app renouvelle sa preuve (story 9.3) ; son Profil dit « Vous ne faites plus partie du Duo de {titulaire} » (FR-43, UX-DR24).

**Given** le Profil d'un membre
**When** il est rendu
**Then** il dit « Membre du Duo de {titulaire} » ; un membre ne peut ni inviter ni retirer.

### Story 9.7: Rapprochement quotidien

En tant que porteur de projet,
je veux un contrôle quotidien de tout droit actif contre les paiements confirmés et les licences approuvées,
afin de détecter aussitôt un droit créé sans paiement.

**Bloqué par :** PRD OQ 19 (fournisseur d'email) pour l'envoi réel de l'alerte d'écart.
**Livrable sans :** job, rapport et alerte avec le faux `email_client` (rapport conservé et lisible).

**Acceptance Criteria:**

**Given** le job `backend/app/jobs/rapprochement.py` (créé)
**When** il est déployé
**Then** il tourne une fois par jour dans un processus planifié à lui (service dédié de `docker-compose.yml`), sous `role_api`, jamais dans le conteneur `ingestion` (AD-17, AD-19).

**Given** les droits actifs du jour
**When** le rapprochement tourne
**Then** il liste tout droit actif dont l'origine n'est ni un paiement `confirme` de même référence, ni une licence manuelle approuvée (story 10.5 ; tant qu'elle n'existe pas, toute origine de licence manuelle est orpheline), et toute organisation partagée dont le nombre de `membre` actuels dépasse les places de son offre (PRD SM-5, FR-50)
**And** un écart déclenche une alerte au porteur de projet (via `email_client`) et le rapport du jour est conservé ; zéro écart est le résultat attendu.

**Given** deux exécutions le même jour
**When** elles tournent
**Then** elles donnent le même rapport et ne modifient aucun droit : le job ne révoque jamais rien lui-même.

### Story 9.8: Fonctionnalités verrouillées dans l'app

En tant que turfiste,
je veux voir, à la place d'une fonctionnalité d'un palier supérieur, ce qu'elle débloque et comment l'obtenir,
afin de comprendre ce qui me manque, sans contenu flouté ni piège.

**Acceptance Criteria:**

**Given** le miroir Dart de `acces_paliers.json` (story 9.2) et la preuve de droit (story 9.3)
**When** un écran contient un contenu que le palier n'autorise pas — Résultats (value, mise, combinaisons, historique, export), Réglages (bankroll et fraction de Kelly, coefficients du moteur), Liste des partants et Fiche cheval (édition, import), Multi
**Then** un `locked-feature` le remplace en place, à sa taille réservée, avec ce qu'il débloque et le palier (« Combinaisons — palier Expert ») et le `cta-ghost` « Voir les offres » → Offres, ouvertes sur les offres qui le débloquent (story 9.4) ; plusieurs verrous voisins d'une même section forment un seul `locked-feature` (FR-39, UX-DR20)
**And** aucun contenu n'est flouté, grisé ni masqué par-dessus : le serveur ne l'envoie pas, et ce qui se calcule sur l'appareil n'est pas calculé.

**Given** une course éligible au Multi et un palier inférieur à Expert
**When** l'utilisateur touche le `multi-badge` ou le CTA « Multi »
**Then** le badge reste visible et le tap ouvre le `locked-feature` « Multi — palier Expert » (EXPERIENCE.md).

**Given** un droit qui devient actif ou qui expire
**When** la preuve est renouvelée (story 9.3)
**Then** les `locked-feature` laissent place au contenu, ou l'inverse, sans redémarrage ; un droit expiré : Profil dit « Droit Turfiste terminé le 22/11 » + « Voir les offres », et « Mes pronostics Multi » montre un seul `locked-feature` (UX-DR24).

**Given** TalkBack
**When** un `locked-feature` est lu
**Then** c'est un nœud groupé qui annonce ce qui manque (« Combinaisons, palier Expert, bouton Voir les offres »).

### Story 9.9: Quota d'import photo par palier

En tant que turfiste,
je veux savoir combien d'imports photo il me reste avant d'en lancer un,
afin de ne jamais perdre un import sur un quota épuisé.

**Bloqué par :** PRD OQ 14 (quotas par palier et période du quota) pour les valeurs définitives.
**Livrable sans :** toute la story avec des quotas et une période provisoires de configuration.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée le compteur d'imports `comptes.quota_photo` par compte et par période (AD-19) ; les quotas par palier sont lus dans la configuration (PRD OQ 14 ; Gratuit : 0) (AD-3).

**Given** `/extraction/fiche` ou `/extraction/programme`
**When** un compte lance un import
**Then** la route vérifie le quota et incrémente le compteur dans la même transaction, avant tout appel à `vision_client` ; un quota épuisé renvoie 429 `quota_photo_epuise` avec la date de renouvellement, sans appel au fournisseur (test avec un faux `vision_client` qui échoue s'il est appelé) (FR-45, AD-3)
**And** la limite journalière globale `VISION_DAILY_CALL_LIMIT` s'applique toujours en plus.

**Given** la feuille d'import photo
**When** elle s'ouvre
**Then** elle affiche le nombre d'imports restants avant l'import ; quota épuisé : « Quota d'import photo épuisé », la date de renouvellement et, si un palier supérieur en offre plus, « Voir les offres » ; la saisie manuelle reste possible pour Turfiste et Expert (UX-DR24).

### Story 9.10: Écrans payants protégés

En tant que porteur de projet,
je veux que les écrans qui montrent un contenu payant ne puissent pas être capturés sur Android,
afin qu'un abonné ne revende pas le pronostic par capture d'écran.

**Acceptance Criteria:**

**Given** un widget unique d'écran protégé (`mobile/lib/widgets/ecran_protege.dart`, créé), piloté par le miroir de `acces_paliers.json`
**When** un écran affichant un contenu payant est ouvert sur Android — Résultats (instantanés, value, mise Kelly), combinaisons, Multi et `tickets-sheet`
**Then** `FLAG_SECURE` est posé tant que l'écran est visible et levé à sa sortie ; une capture ou un enregistrement donne une image noire (essai sur appareil consigné dans les notes) (FR-46, AD-15)
**And** aucun message n'apparaît tant que l'utilisateur ne tente rien (UX-DR23).

**Given** l'export texte de Résultats (FR-21) et la copie des grilles (dès la story 5.18)
**When** ils sont produits
**Then** ils restent possibles, se terminent par l'identifiant court du compte (`identifiant_court`, story 8.1) et ne portent aucun montant (FR-46).

**Given** la web app
**When** elle affiche un contenu payant
**Then** elle n'a pas de protection d'écran, par décision (PRD FR-46), ce que mentionne la liste de contrôle de la story 7.6.

### Story 9.11: Nouvel appareil sur un compte payant : alerte email et délai de sécurité

En tant que turfiste abonné,
je veux être alerté par email et protégé quand un nouvel appareil rejoint mon compte payant par simple code SMS,
afin qu'un vol de ma carte SIM ne suffise pas à prendre mon compte.

**Bloqué par :** PRD OQ 19 (fournisseur d'email) pour l'envoi réel de l'alerte ; PRD OQ 14 pour la valeur définitive de `NOUVEL_APPAREIL_DELAI_HEURES`.
**Livrable sans :** alerte et délai avec le faux `email_client` et une valeur provisoire du délai.

**Acceptance Criteria:**

**Given** un compte dont le palier actif est payant (story 9.1)
**When** un nouvel appareil le rejoint par code SMS seul, sans appairage approuvé par QR code
**Then** en plus de l'alerte SMS (story 8.6), une alerte part vers l'email vérifié via `email_client` (AD-16)
**And** pendant `NOUVEL_APPAREIL_DELAI_HEURES`, cet appareil ne peut changer ni l'email, ni le numéro, ni l'appartenance à un Duo (inviter, retirer, rejoindre, quitter) : ces routes répondent 403 `delai_nouvel_appareil` avec l'heure de fin du délai (test).

**Given** un appareil rattaché par QR code approuvé depuis un téléphone déjà connecté (story 8.7), ou un compte Gratuit
**When** il rejoint le compte
**Then** ce délai ne s'applique pas ; en revanche, un appareil entré par code seul après avoir retiré un autre appareil avec un jeton de gestion (story 8.6) y est soumis (test).

**Given** Profil sur un appareil soumis au délai
**When** une action est refusée
**Then** l'app dit « Nouvel appareil : action possible à partir de 21 h 10 » `[ASSUMPTION: arbitrage de la mise à jour des epics du 2026-11-15, à confirmer par le porteur de projet]`.

## Epic 10: Back-office — rôles et contrôles internes

Le personnel travaille dans un back-office séparé — une application Flutter Web distincte (`backoffice_web/`) servie sur `admin.<domaine>`, adossée à un second point d'entrée FastAPI (`backend/app/backoffice/main.py`, service `backoffice`, `role_backoffice`) —, avec double authentification, des rôles limités, une validation avant toute modification, un journal d'audit chaîné et une licence hors paiement à deux personnes. Écrans (EXPERIENCE.md, sans maquette) : Connexion + TOTP (et enrôlement TOTP à la première connexion), Tableau de bord, Corrections, Licences manuelles, Offres, Personnel, Journal d'audit ; chacun couvre les états chargement, vide, erreur, interdit par le rôle et session expirée. **Ordre :** 10.1, 10.2, 10.7, puis 10.3 à 10.6 ; l'écrivain du journal d'audit (story 7.10) est un prérequis.

**Bloqué par (epic) :** l'achat du domaine et le DNS de `admin.<domaine>` (PRD OQ 20, story 7.3) pour la mise en production.
**Livrable sans (epic) :** tout l'epic, développé et testé sur `admin.localhost`.

### Story 10.1: Accès séparé et double authentification

En tant que membre du personnel,
je veux me connecter au back-office sur son adresse propre, avec un second facteur obligatoire,
afin qu'un mot de passe volé ne suffise jamais à toucher aux données ou aux droits.

**Acceptance Criteria:**

**Given** le projet Flutter Web `backoffice_web/` (créé à la racine du dépôt, séparé de `mobile/`)
**When** il est construit (`flutter build web --release`)
**Then** il suit une mise en page de bureau seulement, Material 3 par défaut avec les tokens de DESIGN.md, sans cache hors ligne ; il ne partage aucun paquet de widgets avec `mobile/` au lancement (ce qui sert est copié ; un paquet partagé est différé)
**And** la build est servie par le proxy (story 7.3) sur `admin.<domaine>`, et ses appels vont vers `admin.<domaine>/api/*`, relayé vers le service `backoffice` : même origine, donc sans CORS (AD-20, AD-21).

**Given** le point d'entrée `backend/app/backoffice/main.py` (créé)
**When** il est déployé comme service `backoffice` de `docker-compose.yml`, depuis la même image que `api`
**Then** il se connecte avec `role_backoffice`, réutilise le code de domaine et de données de `backend/app`, ne sert que du JSON, et n'expose aucun port hors du réseau Docker ; il ne migre pas (seul `api` migre, story 7.1) (AD-13, AD-19, AD-20).

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée `personnel` (séparé de `compte` : identifiant, empreinte du mot de passe, rôle, secret TOTP chiffré au repos par une clé de l'environnement du serveur, `actif`, compteur d'échecs, `verrouille_jusqu_a`) et `session_personnel` (empreinte du jeton, membre, `creee_le`, `derniere_activite_le`, `expire_le`, `revoquee_le`), et accorde à `role_backoffice` la lecture et l'écriture de ces tables (AD-19, AD-20).

**Given** un membre du personnel sur l'écran Connexion du back-office
**When** il se connecte
**Then** l'identifiant, le mot de passe (vérifié contre une empreinte Argon2id, `argon2-cffi`) et un code TOTP (`pyotp`, RFC 6238, pas de 30 s, tolérance ± 1 pas, code déjà utilisé refusé) sont exigés ; sans second facteur enrôlé, aucun accès hors de l'écran d'enrôlement TOTP de la première connexion (QR du secret, confirmation par un premier code) (FR-47)
**And** après `PERSONNEL_ECHECS_MAX` échecs (configuration), le compte est verrouillé pour `PERSONNEL_VERROUILLAGE_MINUTES` ; la réponse ne dit jamais lequel des trois facteurs est faux (test).

**Given** une connexion réussie
**When** la session du personnel est ouverte
**Then** c'est un jeton opaque aléatoire, stocké par son empreinte côté serveur, posé dans un cookie `__Host-` (`httpOnly`, `Secure`, `SameSite=Strict`, `Path=/`) ; elle expire après 30 minutes d'inactivité et 8 heures au plus ; toute requête qui change un état porte un en-tête anti-CSRF vérifié (test) ; elle est distincte des sessions des comptes (aucun jeton de compte n'ouvre une route du back-office, test)
**And** la connexion, l'échec et le verrouillage sont inscrits au journal d'audit (story 7.10) ; une session expirée affiche l'état « Session expirée — reconnectez-vous ».

### Story 10.2: Rôles agent, superviseur, administrateur

En tant que porteur de projet,
je veux que chaque membre du personnel n'ait que les droits de son rôle,
afin qu'un agent de saisie ne puisse ni revendre les pronostics ni créer de droits.

**Acceptance Criteria:**

**Given** les rôles `agent`, `superviseur` et `administrateur`
**When** chaque route du back-office est déclarée
**Then** elle porte les rôles autorisés, au moindre privilège ; un test d'accès par route et par rôle vérifie la matrice : l'agent ne voit que ses propres saisies et aucun pronostic ni aucun droit ; le superviseur valide les modifications et lit le tableau de bord et le journal ; l'administrateur gère les droits, les offres, les licences manuelles et le personnel (FR-48, AD-20)
**And** une tentative refusée répond 403 et est inscrite au journal d'audit (story 7.10) ; l'app affiche l'état « Accès réservé au rôle superviseur » sans révéler le contenu.

**Given** l'écran Personnel (administrateur)
**When** un administrateur crée un membre, change son rôle, le désactive ou réinitialise son TOTP
**Then** le changement prend effet à la prochaine requête de ce membre (ses sessions sont révoquées à la désactivation et à la réinitialisation) ; un administrateur ne peut pas désactiver le dernier administrateur actif ; chaque changement est inscrit au journal d'audit.

### Story 10.3: Modifications soumises à validation

En tant que superviseur,
je veux que toute modification saisie par un agent attende ma validation avant d'entrer dans un calcul,
afin qu'une saisie fausse ne change jamais un pronostic en silence.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `courses`
**When** elle est appliquée
**Then** elle crée `correction_saisie` (entité, identifiant, champ, ancienne et nouvelle valeur, agent, statut `en_attente`/`validee`/`rejetee`, validateur, instants) ; `role_backoffice` peut insérer et changer le statut ; `role_ingestion`, `role_pronostics` et `role_api` peuvent seulement la lire, pour la surcouche (AD-10, AD-19).

**Given** la liste blanche des champs corrigeables, en configuration versionnée (`backend/app/backoffice/corrections_autorisees.py`)
**When** une correction est saisie
**Then** seuls ces triplets (entité, champ, type) sont acceptés : `course` (`heure_depart` instant UTC, `distance` entier en mètres, `terrain` label canonique d'AD-5, `statut` valeur énumérée) ; `partant` (`non_partant` booléen, `numero` entier, `poids` décimal en kg, `corde` entier, `deferre` valeur énumérée) ; `cheval` (`nom` texte, `sexe` valeur énumérée, `age` entier)
**And** chaque valeur est validée selon son type et ses bornes (test par champ) ; un champ hors liste ou une valeur invalide est refusé avec un code, jamais enregistré ; l'ancienne valeur est lue en base au moment de la saisie (lecture du schéma `courses` par `role_backoffice`).

**Given** l'écran Corrections (agent)
**When** l'agent cherche une course, un partant ou un cheval et choisit un champ
**Then** il voit la valeur actuelle, saisit la nouvelle par un contrôle adapté au type (sélecteur pour une énumération, champ numérique borné, sélecteur d'heure) et soumet ; la liste « Mes saisies » montre ses corrections et leur statut, jamais celles des autres.

**Given** une modification saisie par un agent
**When** elle est enregistrée
**Then** elle est `en_attente` et n'entre dans aucun calcul (FR-49) ; sa création est inscrite au journal d'audit (story 7.10).

**Given** un superviseur sur l'écran Corrections (file « À valider »)
**When** il valide ou rejette une correction
**Then** elle passe à `validee` ou `rejetee` avec son validateur et l'instant ; personne ne valide sa propre saisie et un agent ne peut rien valider (test) (FR-49) ; la décision est inscrite au journal d'audit.

**Given** `repository.py`
**When** il lit une entité qui a des corrections `validee`
**Then** il les applique en surcouche à la lecture, si bien que le service `pronostics`, le journal Multi et l'API les voient (AD-10)
**And** l'ingestion ne lit ni n'écrit `correction_saisie` (test sur ses requêtes) et n'écrase jamais une correction : une réingestion de la même ligne ne change pas la valeur lue.

### Story 10.4: Journal d'audit : export de la tête, vérification et lecture

En tant que porteur de projet,
je veux que la tête du journal d'audit sorte chaque jour de l'hôte, que la chaîne se vérifie et que le personnel autorisé la lise,
afin de pouvoir prouver qui a fait quoi, même face à un opérateur de base de données.

*La table `audit.journal_audit` et la fonction d'écriture chaînée sont créées par la story 7.10 ; chaque story instrumente ses propres événements.*

**Bloqué par :** la destination hors hôte des sauvegardes (story 7.2, choix du porteur de projet) ; PRD OQ 19 (fournisseur d'email) pour l'envoi réel de la tête au porteur de projet.
**Livrable sans :** export vers le volume local de sauvegarde et faux `email_client`.

**Acceptance Criteria:**

**Given** la couverture des événements d'AD-20
**When** un test parcourt le registre de la story 7.10
**Then** chaque type d'événement du registre dont la story d'instrumentation est déjà livrée a au moins un appelant dans le code et un test de bout en bout qui vérifie qu'une ligne est ajoutée ; les événements des stories postérieures (10.5 licences manuelles, 10.6 offres et révocation) sont ajoutés à ce test par ces stories elles-mêmes, qui ne sont terminées qu'avec lui (FR-50).

**Given** la tête de la chaîne
**When** le job quotidien d'export tourne
**Then** l'empreinte de tête (et son identifiant de ligne) est exportée hors de la base vers la destination hors hôte des sauvegardes (story 7.2) et envoyée par email au porteur de projet via `email_client` (AD-20).

**Given** la commande de vérification (`python -m app.jobs.verifier_journal_audit`)
**When** elle tourne
**Then** elle recalcule la chaîne, la compare à la dernière tête exportée et signale toute altération (test : une ligne modifiée, supprimée ou insérée directement en base est détectée).

**Given** l'écran Journal d'audit (superviseur et administrateur)
**When** il est ouvert
**Then** il liste les lignes du plus récent au plus ancien, filtrables par période, acteur et type d'événement, en lecture seule (SELECT de `role_backoffice`) ; un agent reçoit l'état « interdit par le rôle » ; aucun détail ne montre de secret (story 7.10).

### Story 10.5: Licence manuelle à quatre yeux

En tant qu'administrateur,
je veux accorder une licence hors paiement avec un motif, validée par un second administrateur,
afin qu'aucun geste commercial ne puisse créer un droit sans contrôle.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `comptes`
**When** elle est appliquée
**Then** elle crée `demande_licence` (organisation bénéficiaire, palier, début, fin, motif, demandeur, approbateur, statut `en_attente`/`approuvee`/`refusee`, instants), lisible et inscriptible par `role_backoffice` ; la licence approuvée elle-même est une ligne `droit` de `source = 'licence_manuelle'` (story 9.1), que `role_backoffice` est autorisé à insérer par la matrice d'AD-19 (AD-17, AD-19).

**Given** un administrateur sur l'écran Licences manuelles
**When** il demande une licence hors paiement (compte bénéficiaire cherché par numéro ou identifiant court, palier, dates)
**Then** le motif est obligatoire ; la demande est `en_attente` et ne crée aucun droit (FR-50) ; elle est inscrite au journal d'audit (story 7.10).

**Given** un second administrateur, différent du demandeur, sur la file « À approuver »
**When** il approuve
**Then** un `droit` de `source = 'licence_manuelle'` est inséré, avec pour origine l'identifiant de la demande ; le demandeur ne peut pas approuver sa propre demande (test) ; l'approbation est inscrite au journal d'audit
**And** le rapprochement (story 9.7) reconnaît cette origine comme valide.

### Story 10.6: Gérer les offres et révoquer un droit

En tant qu'administrateur,
je veux modifier les offres et révoquer un droit depuis le back-office,
afin d'ajuster les prix sans nouvelle version de l'app et de corriger un droit indu, toujours avec une trace.

**Acceptance Criteria:**

**Given** un administrateur sur l'écran Offres
**When** il crée, modifie ou désactive une offre
**Then** la ligne `offre` (story 9.4) change, l'ancienne et la nouvelle valeur sont inscrites au journal d'audit (story 7.10), et `GET /offres` renvoie la nouvelle valeur sans nouvelle version de l'app (FR-41, AD-17).

**Given** un administrateur, depuis la fiche d'un compte ou la liste des droits actifs
**When** il révoque un droit avec un motif
**Then** `revoque_le` et `motif_revocation` sont posés une seule fois (une seconde révocation est refusée), une ligne est ajoutée au journal d'audit, `version_droits` change et `palier_actif` ignore ce droit (AD-17).

**Given** les droits de `role_backoffice`
**When** un test de droits tourne sur PostgreSQL
**Then** sur le schéma `comptes`, il n'a que la lecture, l'écriture de `offre`, de `personnel`, de `session_personnel` et de `demande_licence`, l'insertion dans `droit` (licence manuelle) et la mise à jour des deux seules colonnes de révocation de `droit` ; sur le schéma `audit`, l'insertion et la lecture de `journal_audit`, sans `UPDATE` ni `DELETE` ; sur le schéma `courses`, la lecture de tout le schéma et, en écriture, l'insertion et le changement de statut de `correction_saisie` seulement ; toute autre écriture est refusée (AD-19).

### Story 10.7: Le tableau de bord servi par le back-office

*Ajoutée le 2026-11-16 (correctifs du contrôle de préparation, C1) : `/dashboard*` quitte `api` pour `backoffice`.*

En tant que superviseur,
je veux lire le tableau de bord des pronostics dans le back-office, derrière ma connexion,
afin que les pronostics du jour ne soient plus servis par l'API publique de l'app.

**Acceptance Criteria:**

**Given** les routes `/dashboard*` et d'évaluation, aujourd'hui dans `backend/app/api/routes_dashboard.py` (service `api`)
**When** cette story est livrée
**Then** elles sont servies par `backend/app/backoffice/main.py` (service `backoffice`, `role_backoffice`, lecture du schéma `courses`), sous `admin.<domaine>/api/*`, et retirées de `api` : elles répondent 404 sur `api.<domaine>` et `app.<domaine>` (test) ; la classe transitoire de la story 9.2 disparaît
**And** la page HTML actuelle du tableau de bord est remplacée par l'écran Tableau de bord de `backoffice_web/`, au même contenu (mesures des pronostics publiés, comparaison au marché).

**Given** les rôles de la story 10.2
**When** un membre du personnel ouvre le Tableau de bord
**Then** seuls le superviseur et l'administrateur lisent les données de pronostic ; un agent reçoit 403 et l'état « interdit par le rôle » (test par rôle)
**And** chaque lecture du tableau de bord est inscrite au journal d'audit (story 7.10), avec le membre et la période consultée.

**Given** la restriction de la story 7.8
**When** les stories 9.2 et 10.7 sont livrées
**Then** plus aucune route de `api` ne sert de pronostic sans compte ni palier, condition de la levée de la restriction (décision consignée dans le suivi de sprint).

## Epic 11: Pronostics publiés et instantanés dans l'app

Chaque matin, puis à H-60, H-30, H-15 et H-10, le serveur publie pour chaque course un pronostic que personne ne peut réécrire ; l'app le montre par défaut avec son heure et sa source, à l'horizon le plus récent que le palier autorise, et calcule value, mise, combinaisons et Multi à partir de lui ; l'Expert garde son mode expert, toujours étiqueté (AD-14 gate A). **Ordre :** 11.1 après la story 7.2 (rôles par service) ; 11.2 après les sessions de l'Epic 8 (stories 8.1 et 8.2) et les stories 9.1 à 9.3 ; 11.3 après la story 11.2 et la story 9.4 (le `teaser-banner` ouvre Offres) ; 11.4 : partie moteur démarrable tout de suite, partie écran après la story 11.3 ; 11.5 après les stories 5.14, 5.15, 5.20 et 6.7.

### Story 11.1: Pronostics et instantanés publiés, en ajout seul

En tant que porteur de projet,
je veux que chaque pronostic publié et chaque instantané de cotes soient écrits une seule fois, par un seul service, sans jamais être réécrits,
afin que ce que vendent les paliers et ce que mesure le tableau de bord soient prouvablement ceux d'avant le départ.

**Acceptance Criteria:**

**Given** une révision Alembic de cette story, dans le schéma `courses`
**When** elle est appliquée
**Then** `prediction_runs` gagne `modele_version text not null`, `donnees_le timestamptz`, `en_evaluation boolean not null default true`, `statut text not null default 'publie'` avec la contrainte `check (statut in ('publie', 'indisponible'))` et `raison_indisponible text null` ; les lignes existantes reçoivent la version du modèle qui les a produites, lue dans les artefacts du job (ou `inconnue` si elle ne se retrouve pas, consigné dans les notes) (AD-14)
**And** l'index unique partiel `(course_id, horizon) WHERE variante = 'ml'` de la baseline (story 7.1) est remplacé par `(course_id, horizon, modele_version) WHERE variante = 'ml'`, déclaré avec `sqlite_where` et `postgresql_where` ; le test de concordance modèles/migrations reste vide.

**Given** le job `backend/app/jobs/pronostics_ml.py`
**When** il publie
**Then** il écrit `modele_version`, `donnees_le` (heure des dernières données utilisées) et `en_evaluation` sur chaque ligne ; une ligne `statut = 'indisponible'` porte sa `raison_indisponible` (code déclaré : source indisponible, partants manquants, modèle non chargé…) et **aucune** ligne `prediction_chevaux` ni probabilité (test).

**Given** les pronostics publiés (`prediction_runs` variante `ml` + `prediction_chevaux`) et les instantanés de cotes (`cotes_instantanees`)
**When** les droits PostgreSQL sont inspectés sur un vrai PostgreSQL (story 7.2)
**Then** seul `role_pronostics` (service `pronostics`) peut insérer des lignes `ml` (politique RLS) et seul `role_cotes` (service `cotes`) peut insérer des instantanés ; `role_api` ne peut insérer qu'une ligne `app` et aucun instantané ; `role_ingestion` ne peut écrire ni l'un ni l'autre ; aucun rôle applicatif n'a `UPDATE` ni `DELETE` sur ces tables (test de droits par rôle) (AD-14, AD-19)
**And** `repository.py` n'offre aucune méthode pour les modifier ou les supprimer.

**Given** un pronostic à publier pour une course, un horizon et une `modele_version` déjà présents
**When** le service `pronostics` l'insère
**Then** le nouvel index unique partiel refuse le doublon sur PostgreSQL comme sur la base de test (test)
**And** un recalcul corrigé est publié sous une nouvelle `modele_version`, jamais par mise à jour ; les deux lignes coexistent (test).

**Given** le pronostic du matin (FR-51)
**When** l'heure fixe de publication `PRONOSTICS_HEURE` passe — exprimée dans le fuseau `Europe/Paris`, celui des courses, et convertie en UTC par le planificateur, changements d'heure compris (test aux deux bascules)
**Then** chaque course française du jour a, avant la première course de la journée, soit un pronostic publié (probabilité de victoire et rang de chaque partant, `modele_version`, `donnees_le`, `en_evaluation` vrai tant que la gate B d'AD-14 n'est pas levée), soit une ligne `statut = 'indisponible'` avec sa raison — jamais une valeur inventée
**And** chaque publication est horodatée en UTC avant le départ de sa course et n'est jamais réécrite (mesure SM-1) ; l'app affiche ces heures dans le fuseau de l'appareil (Africa/Douala au lancement), jamais dans celui du serveur (story 11.3).

**Given** les instantanés H-60, H-30, H-15 et H-10 (FR-52)
**When** `cotes` relève les cotes et `pronostics` publie le pronostic recalculé
**Then** un instantané qui manque (source indisponible, cote absente) n'est pas publié et son absence est journalisée, jamais comblée
**And** l'instantané H-2 et `probabilite_fondamentale` restent internes ; aucune route ne les sert (story 9.2).

### Story 11.2: Le pronostic publié servi avec la course, selon le palier

En tant que turfiste,
je veux recevoir avec chaque course le pronostic publié le plus récent auquel mon palier donne droit,
afin de lire le bon pronostic, à la bonne heure, sur mon téléphone.

**Acceptance Criteria:**

**Given** `GET /courses/{id}/partants` (et le contexte de course de `GET /courses`)
**When** un compte demande une course
**Then** la réponse porte un objet typé `pronostic_publie` (`horizon`, `modele_version`, `donnees_le`, `en_evaluation`, `chevaux[{num_pmu, probabilite, rang}]`, AD-4) : celui de l'horizon le plus récent que le palier autorise, lu dans le miroir de `acces_paliers.json` (story 9.2), jamais un tableau de tous les horizons filtré par l'app (AD-14, FR-39)
**And** il ne porte ni value ni mise, et il est absent pour une course sans pronostic publié.

**Given** un compte Turfiste et une course qui a un instantané H-10
**When** la réponse est construite
**Then** elle ne contient **aucun** champ de l'instantané H-10 (test sur la réponse brute) et porte un objet facultatif `apercu` (`chevaux_changes`, `horizon`, `palier_requis`) : seulement le nombre de chevaux qui ont changé de rang, l'horizon et le palier qui le débloque, sans nom, dossard ni probabilité (FR-40)
**And** un compte Gratuit reçoit le seul pronostic du matin, avec l'`apercu` de l'instantané le plus récent qu'il ne peut pas voir (FR-39, FR-40).

**Given** un instantané attendu mais manquant
**When** la course est servie
**Then** le dernier instantané disponible et autorisé est renvoyé avec son horizon et son heure ; rien n'est inventé (FR-52).

**Given** `POST /pronostics` (variante `app`, clé `installation_id`, écritures anonymes)
**When** cette story est livrée
**Then** la décision du porteur de projet est appliquée et consignée : par défaut, la route est retirée (410) et le tableau de bord ne lit plus la variante `app` ; si elle est gardée, elle passe en classe *compte + palier* et ses lignes sont rattachées à `compte`, jamais à `installation_id` (architecture, Deferred) `[ASSUMPTION: arbitrage de la mise à jour des epics du 2026-11-15, à confirmer par le porteur de projet]`.

**Given** le schéma OpenAPI
**When** un test le parcourt
**Then** aucune réponse ne porte de champ d'instantané hors de `pronostic_publie` et `apercu`, ni l'instantané H-2, ni `probabilite_fondamentale`.

### Story 11.3: Voir le pronostic publié par défaut, le mode expert à part

En tant que turfiste,
je veux voir par défaut le pronostic publié avec son heure et, en Expert, pouvoir passer à mes propres réglages clairement étiquetés,
afin de toujours savoir d'où viennent les probabilités que je lis.

**Acceptance Criteria:**

**Given** une course dont le `pronostic_publie` est reçu et mis en cache avec `palier_recu` (story 9.3)
**When** Résultats est calculé
**Then** le jeu de probabilités actif est le pronostic publié ; value, mise Kelly et combinaisons se calculent sur l'appareil à partir de ce jeu, sans le recalculer (FR-53, AD-14 gate A)
**And** l'en-tête dit la source : « Pronostic de 14 h 35 · H-30 » ou « Pronostic du matin (8 h 00) », avec « modèle en cours d'évaluation » tant que `en_evaluation` est vrai (FR-51, UX-DR21).

**Given** une course sans pronostic publié (import photo, saisie manuelle, course non ingérée, course du lendemain avant la publication du matin)
**When** un palier payant la calcule
**Then** le moteur de scoring aux paramètres par défaut est le jeu actif, et l'écran dit « Moteur de scoring — pas de pronostic publié pour cette course » ; pour un compte Gratuit, l'écran indique l'heure de publication du pronostic du matin (FR-53, UX-DR21)
**And** toutes les heures affichées (publication du matin, `PRONOSTICS_HEURE` fixée à Paris, heure d'un instantané, départ) sont converties depuis l'UTC dans le fuseau de l'appareil (Africa/Douala au lancement) (test avec un fuseau injecté).

**Given** un compte Expert
**When** il active le mode expert dans Résultats
**Then** les probabilités du moteur de scoring à ses réglages deviennent le jeu actif, étiquetées « Mode expert — vos réglages », sans aucune probabilité publiée à côté ; les deux jeux ne sont jamais mélangés sans le dire ; la bascule n'existe pas sous le palier Expert (FR-53, FR-39).

**Given** un instantané manquant
**When** la course est affichée
**Then** la source dit « Pronostic de 14 h 05 · H-60 — instantané H-30 indisponible » (FR-52, UX-DR21).

**Given** l'ouverture d'une course ou un tirer-pour-rafraîchir
**When** le réseau est disponible
**Then** l'app relit le pronostic publié le plus récent autorisé ; jamais en arrière-plan (FR-52, FR-14).

**Given** une réponse qui porte un `apercu` (story 11.2)
**When** Résultats ou la carte de la course est rendu
**Then** un seul `teaser-banner` par course, le plus récent, dit « Le classement a changé à H-10 pour 3 chevaux — palier Expert » ; un tap ouvre Offres sur les offres qui débloquent cet horizon (story 9.4) ; aucun compte à rebours ; TalkBack le lit en entier (FR-40, UX-DR20).

### Story 11.4: Un non-partant sur un pronostic publié (« ajusté »)

En tant que turfiste,
je veux qu'un cheval que je marque non-partant sorte du pronostic publié et que les autres probabilités se rééquilibrent,
afin de garder un classement juste entre deux instantanés, même hors ligne.

**Acceptance Criteria:**

**Given** une fonction pure `renormaliser_sans_non_partants(probabilites, non_partants)` dans `backend/app/engine/` et son jumeau Dart dans `mobile/lib/engine/`
**When** elle est appelée
**Then** elle retire les non-partants et renormalise les probabilités de victoire restantes de façon cohérente avec Plackett-Luce (division par la somme des forces restantes), qui somment alors à 1 ; elle ne lit ni base ni réseau (AD-1, AD-14 gate A)
**And** ses cas sont écrits dans `fixtures/engine_cases.json` et rejoués par les deux suites (AD-2).

**Given** une course à pronostic publié actif
**When** l'utilisateur marque un cheval non-partant (action « Marquer non-partant » de la Liste des partants, ajoutée par cette story si elle n'existe pas, la même que celle du Multi, story 5.19), hors ligne compris
**Then** les probabilités publiées sont renormalisées sur les chevaux restants, puis value, mise et combinaisons sont recalculées sur l'appareil ; la source porte « · ajusté » (« Pronostic de 14 h 35 · H-30 · ajusté ») (FR-23, UX-DR21)
**And** « Annuler non-partant » rend le jeu publié tel que reçu.

**Given** le prochain instantané, recalculé par le serveur
**When** l'app le reçoit
**Then** il remplace le jeu ajusté et la mention « · ajusté » disparaît ; le serveur ne recalcule rien à la demande.

### Story 11.5: Le Multi sur le jeu de probabilités actif

En tant que turfiste Expert,
je veux que le Multi se calcule sur le même jeu de probabilités que Résultats et dise lequel,
afin que le Multi et le classement ne se contredisent jamais.

**Acceptance Criteria:**

**Given** le jeu de probabilités actif de la course (publié, ajusté, mode expert ou moteur de scoring, stories 11.3 et 11.4) et le moteur Multi Dart (Epic 5)
**When** le Multi est calculé sur l'appareil
**Then** l'adaptateur du moteur Multi prend les probabilités de victoire du jeu actif et en tire les `top4` par la même fonction Harville que le moteur de scoring (cas partagés), sans recalculer de score ; Résultats et Multi montrent le même champ et la même source (« Pronostic de 14 h 35 · H-30 », « Mode expert — vos réglages », « · ajusté ») (AD-6, AD-14, FR-53).

**Given** `identite_pronostic` en Python (story 5.12) et en Dart (story 5.15)
**When** elle est calculée
**Then** elle porte `source_probabilites` = `{type: "publie", modele_version, horizon}` ou `{type: "expert", parametres_hash}` (AD-12) ; un jeu ajusté ajoute `ajuste: true`, et le moteur de scoring par défaut compte comme `expert` avec l'empreinte des paramètres par défaut `[ASSUMPTION: arbitrage de la mise à jour des epics du 2026-11-15, à confirmer par le porteur de projet]`
**And** le cas partagé d'identité est mis à jour et donne la même identité dans les deux langages ; `recommandation_consultee` et `pronostic_retenu` (story 5.20) l'enregistrent dans `identite_json`, sans changement du schéma local.

**Given** le journal Multi quotidien (story 6.7)
**When** il journalise une course
**Then** chaque entrée de `recommandation_multi` porte la `source_probabilites` du jeu publié utilisé (AD-10, AD-12).

## Epic 12: Renforcement (V1.1)

Après le lancement : version iOS ; contrôle d'intégrité de l'app (attestation Play Integrity à l'émission et au renouvellement des jetons et des preuves de droit : le serveur refuse une app modifiée — parade du risque accepté en D-5, avancée si un abus est observé avant) ; déverrouillage biométrique ; filigrane visible portant l'identifiant court du compte ; détection d'usages anormaux (même compte dans deux villes à la fois, rotation d'appareils) ; preuves de récupération complémentaires (référence d'un paiement Mobile Money passé, codes de secours) ; épinglage du certificat dans l'app ; contrôle des saisies du back-office contre la source PMU. Découpage en stories après le lancement (PRD §6.2 « V1.1 »).

### Couverture des exigences du lancement payant

| Exigence | Stories |
| --- | --- |
| FR-30 (synchronisation du pronostic retenu) | 5.20, 8.8 |
| FR-31 | 7.7, 7.9, 8.1 |
| FR-32 | 8.3 |
| FR-33 | 8.2 |
| FR-34 | 8.4 |
| FR-35 | 8.5 |
| FR-36 | 8.6, 8.7, 9.11 |
| FR-37 | 8.7 |
| FR-38 | 7.6, 8.8, 8.9, 5.20 |
| FR-39 | 9.1, 9.2, 9.3, 9.8, 11.2, 11.3 |
| FR-40 | 11.2, 11.3 |
| FR-41 | 9.4, 10.6 |
| FR-42 | 9.0, 9.5 |
| FR-43 | 9.1, 9.6 |
| FR-44 | 9.3 |
| FR-45 | 9.9 |
| FR-46 | 9.10 |
| FR-47 | 7.3, 10.1, 10.7 |
| FR-48 | 10.2, 10.7 |
| FR-49 | 10.3 |
| FR-50 | 7.10, 9.7, 10.4, 10.5 |
| FR-51 | 11.1, 11.3 |
| FR-52 | 11.1, 11.2, 11.3 |
| FR-53 | 11.3, 11.4, 11.5 |
| NFR-12 | 7.8, 9.2, 9.3, 10.7 |
| NFR-13 | 7.3, 7.4, 7.6, 7.8 |
| NFR-14 | 7.2, 7.10, 8.1, 8.3, 10.1 |
| NFR-15 | 7.5, 9.3 |
| NFR-16 | 7.7, 7.9, 8.1 |
| UX-DR14 | 8.1, 8.3 |
| UX-DR15 | 8.3 |
| UX-DR16 | 8.4, 9.6 |
| UX-DR17 | 8.6 |
| UX-DR18 | 9.4, 9.5 |
| UX-DR19 | 8.7 |
| UX-DR20 | 9.8, 11.3 |
| UX-DR21 | 11.3, 11.4, 11.5 |
| UX-DR22 | 7.6, 8.9 |
| UX-DR23 | 9.10 |
| UX-DR24 | 8.4, 8.8, 9.3, 9.6, 9.8, 9.9 |
| Back-office (écrans de C1, EXPERIENCE.md) | 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7 |
| Barrière OQ 18 (règles de Google Play) | 9.0 → 9.5, 7.7 |

*Décompte au 2026-11-16 : 71 stories détaillées dans ce document (Epic 5 : 20 ; Epic 6 : 8 ; Epic 7 : 10 ; Epic 8 : 9 ; Epic 9 : 12 ; Epic 10 : 7 ; Epic 11 : 5) ; les Epics 1 à 4 sont livrés et l'Epic 12 sera découpé après le lancement. Ajoutées par les correctifs du contrôle de préparation du 2026-11-15 : 7.9, 7.10, 8.9, 9.0, 10.7.*
