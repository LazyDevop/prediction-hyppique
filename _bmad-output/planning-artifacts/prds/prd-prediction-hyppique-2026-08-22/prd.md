---
title: prediction-hyppique
created: 2026-08-22
updated: 2026-08-22
status: final
---

# PRD: prediction-hyppique
*Outil d'aide à la décision pour les courses hippiques PMU — working title, confirmer le nom commercial.*

## 0. Document Purpose

Ce PRD cadre le produit dans son ensemble : backend Python/FastAPI (ingestion PMU, moteur de calcul, extraction vision) et application mobile Flutter (interface finale, usage sur hippodrome). Il s'appuie sur trois documents déjà rédigés par le porteur de projet, qui restent la référence pour tout ce qui est *comment* plutôt que *quoi* :

- `brief_projet_analyse_hippique.md` — positionnement, différenciation, périmètre, modèle économique envisagé, critères de succès, risques.
- `cahier_des_charges_backend_hippique.md` — spécification exacte du moteur de calcul (constantes, formules, cas de test), source de données, schéma BDD, endpoints API.
- `cahier_des_charges_app_mobile.md` — architecture Flutter, écrans, stratégie offline, erreurs à ne pas reproduire.

Ce PRD ne duplique pas les formules ni le code : il définit les capacités attendues, pour qui, et sous quelles contraintes. Les détails d'implémentation (constantes exactes, structure de modules, stack technique, cas de test) restent dans les cahiers des charges cités et dans `addendum.md`. En cas de divergence entre ce PRD et les cahiers techniques sur une question de *comportement produit*, ce PRD fait foi ; sur une question de *formule ou d'implémentation*, le cahier backend fait foi (principe déjà posé par le porteur de projet lui-même dans le cahier mobile, section 0).

Vocabulaire : ce PRD utilise les termes du §3 Glossaire de façon stricte — pas de synonymes ailleurs dans le document.

## 1. Vision

Un parieur qui veut analyser une course hippique avant de jouer dispose aujourd'hui de sites de pronostics (Geny, Bilto, ZEturf, CanalTurf) qui délivrent un jugement d'expert en prose. Aucun n'affiche de probabilité chiffrée par cheval, aucun ne la compare explicitement à la cote du marché pour dire *pourquoi* un cheval serait sous-coté, aucun ne classe des combinaisons de paris par probabilité, aucun ne suggère une mise. Une recherche de marché confirme ce vide côté hippisme français : le concept de "value betting" chiffré existe (EquinEdge aux États-Unis, RebelBetting/OddsJam en arbitrage multisport), mais aucun outil français n'affiche ce ratio probabilité×cote en hippisme — et aucun outil hippique identifié, français ou international, n'intègre de calculateur Kelly.

prediction-hyppique transforme l'information hippique abondante mais non exploitée en décision chiffrée, reproductible et actionnable : un moteur de scoring (Plackett-Luce / Harville) calcule une probabilité par cheval à partir de son historique de performances, la compare à la cote pour détecter la value (`probabilité × cote − 1`), classe les combinaisons de paris possibles (couplé à quinté, ordre et désordre) par probabilité décroissante, et suggère une mise par la formule de Kelly fractionné. Le moteur est transparent : chaque coefficient (récence, poids, âge, terrain, niveau) est visible et réglable par l'utilisateur, à l'opposé du pronostic opaque des sites concurrents.

Le produit reste, explicitement et durablement, un outil d'**aide à la décision** — jamais un système de paris automatisé, jamais un générateur de certitudes. Chaque écran de résultats porte le rappel que le jeu comporte des risques et qu'aucun modèle ne garantit un gain. Le moteur de calcul est déjà conçu et validé numériquement dans deux prototypes fonctionnels (`analyse_hippique_v2.html`, `analyse_hippique_ia.jsx`) — ce PRD cadre son industrialisation en un produit backend + mobile utilisable, y compris sur l'hippodrome avec une connexion incertaine.

**Limite assumée, à ne pas cacher** : le modèle est aveugle à l'information tactique et humaine que les tipsters captent (changement de driver de dernière minute, intention de course rapportée par un entraîneur) — aucune donnée chiffrée ne remplace cela aujourd'hui. De la même façon, rien ne prouve à ce stade que les probabilités du modèle sont mieux calibrées que le jugement d'expert des pronostiqueurs ; seul un backtest sur un volume significatif de courses pourra l'établir (détail : §7, portée explicite de SM-1).

## 2. Target User

### 2.1 Jobs To Be Done

- **Fonctionnel** : avant de jouer une course, savoir quels chevaux sont statistiquement sous-cotés par le marché plutôt que de me fier à un pronostic en prose que je ne peux pas vérifier.
- **Fonctionnel** : obtenir des combinaisons de paris (couplé, tiercé, quarté, quinté) déjà classées par probabilité, en dossards, sans les recalculer moi-même.
- **Fonctionnel** : savoir combien miser sur un cheval donné sans avoir à faire le calcul de Kelly moi-même, et sans dépasser ce que je peux me permettre de perdre.
- **Contextuel** : pouvoir analyser une course même sans réseau fiable, depuis les tribunes ou le pesage d'un hippodrome.
- **Émotionnel** : reprendre la main sur ma décision de pari plutôt que de suivre aveuglément le favori du marché ou l'avis d'un tipster anonyme.
- **Fonctionnel (porteur de projet)** : disposer d'un historique de courses accumulé en base propre, condition pour mesurer un jour si le modèle est réellement mieux calibré que le marché.

### 2.2 Non-Users (v1)

- Les cercles de jeu et parieurs professionnels — relation commerciale différente (vente directe), envisagée en phase 2, pas conçue dans ce PRD.
- Les parieurs sur courses hors France (pas de PMUC camerounais, pas de courses internationales) — les échelles terrain/niveau et la source de données sont calibrées sur la France uniquement.
- Les utilisateurs cherchant un système qui place les paris à leur place — non-goal explicite et permanent (§5).
- Les équipes multi-utilisateurs partageant un compte — V1 est mono-utilisateur, sans notion de compte (§9 Constraints, décision de périmètre).

### 2.3 Key User Journeys

- **UJ-1. Marc prépare sa réunion du dimanche depuis son salon.**
  - **Persona + contexte :** Marc, parieur individuel régulier, prépare le Quinté+ du dimanche la veille au soir, avec une bonne connexion.
  - **État d'entrée :** app ouverte, pas de compte à créer (V1 mono-utilisateur). Programme du jour pas encore chargé.
  - **Parcours :** il rafraîchit le programme du jour (accueil) → sélectionne la réunion et la course cible → les partants et leur historique sont préremplis depuis le backend (données PMU déjà en base) → il ajuste manuellement le terrain qu'il a vu annoncé et corrige la cote d'un cheval → il lance le calcul.
  - **Climax :** l'écran de résultats affiche le classement, la jauge modèle vs marché, et un cheval marqué "value forte" que le marché sous-cote clairement selon le modèle.
  - **Résolution :** il consulte la grille de combinaisons (quinté ordre/désordre) déjà classée par probabilité, note les dossards, ferme l'app. Les données de cette course restent en cache local pour consultation hors ligne le lendemain.
  - **Edge case :** si le backend n'a pas encore ingéré cette réunion, l'app déclenche l'import à la demande (`POST /courses/{id}/importer`) avant de préremplir.

- **UJ-2. Marc recalcule sur l'hippodrome avec une connexion saturée.**
  - **Persona + contexte :** Marc est dans les tribunes, la 4G est saturée par l'affluence, la course qu'il a préparée la veille est déjà en cache.
  - **État d'entrée :** app ouverte hors ligne ou en connexion très dégradée, course déjà chargée la veille (UJ-1).
  - **Parcours :** il ouvre la course en cache → aucune tentative de rafraîchissement réseau ne bloque l'écran → il ajuste un paramètre du moteur (ex. sensibilité au poids) dans les réglages → il relance le calcul.
  - **Climax :** le classement se recalcule instantanément, entièrement sur l'appareil, sans dépendre du réseau.
  - **Résolution :** il consulte la nouvelle recommandation et la mise suggérée avant l'heure de départ.
  - **Edge case :** s'il tente un rafraîchissement des cotes en direct ou un import photo sans réseau, l'app échoue proprement avec un message clair, sans bloquer la consultation des données déjà en cache.

- **UJ-3. Marc importe une fiche cheval par photo quand le backend ne couvre pas la course.**
  - **Persona + contexte :** une réunion étrangère ou une fiche d'un cheval inédit non couverte par l'ingestion automatisée.
  - **État d'entrée :** écran fiche cheval éditable, réseau disponible.
  - **Parcours :** il appuie sur "Importer une photo ou un PDF" → capture ou sélectionne une fiche → l'app envoie l'image au backend (`/extraction/fiche`), jamais directement à un fournisseur d'IA → le formulaire se préremplit avec un bandeau "Rempli par l'IA — vérifiez les champs".
  - **Climax :** il vérifie et corrige les champs extraits (l'extraction n'est jamais appliquée en confiance aveugle).
  - **Résolution :** la fiche corrigée entre dans le calcul comme n'importe quelle autre.
  - **Edge case :** extraction échouée (image floue, réseau coupé) → message d'erreur explicite, retour à la saisie manuelle sans perte du reste du formulaire.

## 3. Glossary

- **Cote** — Rapport offert par le marché sur un cheval (ex. 6.5). Sert à calculer la **probabilité implicite** du marché (`1/cote`) et la **value**.
- **Value** — `probabilité du modèle × cote − 1`. Positive si le modèle estime le cheval sous-coté par le marché.
- **Score** — Note composite d'un cheval issue du moteur (forme pondérée × ajustements poids/âge, lissée). Sert de base au calcul de probabilité.
- **Forme** — Moyenne pondérée par récence des notes de performance d'un cheval sur son historique.
- **Partant** — Cheval effectivement engagé dans la course cible.
- **Partant virtuel (outsider virtuel)** — Cheval déclaré partant de la course cible mais non saisi/analysé par l'utilisateur ; modélisé avec un score réduit pour que les probabilités restent réalistes.
- **Cheval inédit** — Cheval n'ayant jamais couru (fait connu, distinct d'un historique simplement non saisi).
- **Terrain** — État du sol, deux échelles distinctes selon le type de piste (valeurs exactes : cahier backend §7). Ne jamais mélanger les deux échelles.
- **Niveau (de course)** — Catégorie de la course cible ou d'une performance passée : Groupe I à IV, Listed, puis Catégorie A à G/H.
- **Incident** — Événement anormal dans une performance passée (chute, disqualification, non-partant...), appliquant un malus à la note plutôt qu'un simple dernier rang. Toutefois, Non Partant (NR) exclut la ligne du calcul.
- **Musique** — Chaîne codée résumant l'historique récent d'un cheval (ex. "1h5s2h1s2s"), telle que fournie par la source PMU ou lue sur une fiche.
- **Combinaison (ordre / désordre)** — Pari portant sur plusieurs chevaux à une position précise (ordre) ou dans un ensemble sans ordre (désordre) : couplé, tiercé (trio), quarté, quinté.
- **Couplé placé / 2 sur 4** — Paris "parmi les k premiers", estimés par simulation Monte-Carlo (non calculables exactement).
- **Mise Kelly (fractionné)** — Mise suggérée dérivée de la formule de Kelly, réduite par une fraction réglable (ex. 25 %) pour limiter la variance.
- **Overround** — Marge du marché intégrée dans les cotes (`Σ(1/cote) − 1`), calculable seulement si toutes les cotes des chevaux analysés sont connues.
- **Calibration** — Mesure de la qualité du modèle : quand il annonce X % de chances à un ensemble de chevaux, gagnent-ils environ X fois sur cent ? Mesurée par score de Brier ou courbe de calibration.
- **PMU** — Pari Mutuel Urbain (France), source des données de courses et opérateur de référence pour ce produit. À ne pas confondre avec le **PMUC** (Pari Mutuel Urbain Camerounais), hors périmètre.
- **Réunion** — Ensemble des courses organisées sur un même hippodrome le même jour.

## 4. Features

*Index : FR-1 à FR-3 (§4.1 Programme et configuration), FR-4 à FR-6 (§4.2 Partants et historique), FR-7 à FR-8 (§4.3 Moteur de scoring), FR-9 à FR-10 (§4.4 Value et mise), FR-11 à FR-12 (§4.5 Combinaisons), FR-13 à FR-15 (§4.6 Hors ligne), FR-16 à FR-17 (§4.7 Ingestion PMU), FR-18 à FR-19 (§4.8 Extraction vision), FR-20 (§4.9 Réglages), FR-21 (§4.10 Export).*

### 4.1 Programme et configuration de la course cible

**Description :** Le point d'entrée de chaque session — consulter le programme du jour et définir les paramètres de la course à analyser (hippodrome, distance, terrain, niveau, nombre de partants). Réalise UJ-1.

#### FR-1: Consultation du programme du jour
L'utilisateur peut consulter la liste des réunions et courses du jour, préremplie depuis le backend quand disponible.

**Consequences (testable):**
- La liste est servie depuis le cache local si déjà chargée, sans appel réseau bloquant.
- Une action explicite "rafraîchir" déclenche un nouvel appel backend (`GET /courses`).

#### FR-2: Configuration manuelle ou préremplie de la course cible
L'utilisateur peut définir hippodrome, distance, terrain, niveau et nombre de partants — préremplis si la course vient du backend, éditables dans tous les cas.

**Consequences (testable):**
- Les échelles terrain (gazon / PSF) sont visuellement distinguées, jamais mélangées dans un même sélecteur.
- Le niveau de course cible est effectivement utilisé dans le calcul du coefficient de niveau relatif (`c_niv`) de chaque performance passée — pas seulement stocké sans effet (erreur documentée à ne pas reproduire, cahier mobile §8).

#### FR-3: Import à la demande d'une course non encore en base
Si une course sélectionnée n'a pas encore été ingérée par le backend, l'utilisateur peut déclencher son import.

**Consequences (testable):**
- `POST /courses/{course_id}/importer` déclenche l'ingestion et retourne les partants dès qu'elle aboutit.
- En cas d'échec (source indisponible), l'utilisateur bascule sans friction vers la saisie manuelle ou l'import photo (FR-9, FR-10).

### 4.2 Partants et historique

**Description :** Chaque cheval engagé, avec son historique de performances, préremplis quand disponibles et toujours éditables. Réalise UJ-1, UJ-3.

#### FR-4: Liste des partants avec indicateurs de transparence
L'utilisateur voit, pour chaque partant, dossard, nom, âge, poids, cote, et un indicateur explicite de la qualité de la donnée disponible.

**Consequences (testable):**
- Les libellés "Historique court", "Données non saisies", "🐎 Inédit" sont affichés tels quels, jamais masqués silencieusement — cohérent avec les deux prototypes.
- Un cheval inédit (case cochée) et un cheval à historique simplement non saisi produisent des scores différents (§7.7 cahier backend) et ne sont jamais confondus dans l'UI.

#### FR-5: Fiche cheval éditable
L'utilisateur peut éditer les performances d'un cheval (rang, partants, niveau, distance, terrain, incident) même si préremplies par le backend.

**Consequences (testable):**
- Le champ terrain d'une performance passée accepte une valeur "inconnu" explicite (`NULL`), jamais une valeur par défaut silencieuse — un terrain inconnu est neutre dans le calcul (`c_terr = 1.0`), pas ignoré ni deviné.
- La cote, le poids et l'âge sont des champs de premier ordre du modèle de données du cheval, présents dès la création — pas ajoutables après coup (erreur documentée à ne pas reproduire).
- L'incertitude sur le terrain est exposée à l'utilisateur, pas seulement absorbée silencieusement par le calcul : un compteur du type "X/6 performances avec terrain inconnu" est visible sur la fiche du cheval concerné.

#### FR-6: Ajout et suppression manuelle d'un cheval
L'utilisateur peut ajouter un cheval vide ou retirer un partant de la liste analysée à tout moment avant calcul.

**Consequences (testable):**
- Retirer un cheval force l'invalidation de tout résultat déjà affiché (recalcul obligatoire) plutôt que de laisser un résultat obsolète visible.

### 4.3 Moteur de scoring et probabilités

**Description :** Le cœur du produit — transforme l'historique de chaque cheval en score, puis en probabilité de victoire et de place, selon la spécification exacte du cahier des charges backend §7 (formules, constantes, cas de test — référence normative, non dupliquée ici). Réalise UJ-1, UJ-2.

#### FR-7: Calcul du score par cheval
Le système calcule un score par cheval à partir de son historique pondéré par récence, ajusté par distance, terrain, niveau, poids et âge, avec lissage bayésien pour les historiques courts.

**Consequences (testable):**
- Un cheval avec une seule performance à note parfaite est ramené vers la moyenne du lot par le lissage, pas laissé à sa note brute (cas de test §9.3 du cahier backend).
- Le coefficient de récence pondère le plus fortement la performance la plus récente (C1), jamais l'inverse (erreur documentée à ne pas reproduire).
- Un incident (chute, disqualification...) applique un malus soustractif différencié par type d'incident à la note de la ligne concernée, jamais un simple "traiter comme dernière place".
- Une ligne marquée Non Partant (NR) est exclue du calcul de `forme` et du compte de performances, quelle que soit sa position.

#### FR-8: Calcul des probabilités (Plackett-Luce) et des probabilités de place (Harville)
Le système convertit les scores en probabilité de victoire par cheval, puis en probabilités Top1/Top2/Top3/Top4.

**Consequences (testable):**
- Les probabilités produites respectent les invariants de sommation exacts spécifiés au cahier backend §9 (référence normative des cas de test, non dupliquée ici).
- Les partants déclarés mais non saisis par l'utilisateur sont modélisés comme partants virtuels et absorbent leur part de probabilité plutôt que d'être ignorés (ce qui surestimerait les chevaux saisis).
- Le calcul produit un résultat de même format que les chevaux proviennent d'une course déjà en base (mode "utilise ce qu'on a déjà collecté") ou soient saisis/importés directement par l'utilisateur (mode "je saisis moi-même") — les deux chemins convergent vers le même contrat de sortie.

### 4.4 Détection de value et mise suggérée

**Description :** Compare la probabilité du modèle à la cote du marché pour chaque cheval, et suggère une mise. C'est le cœur de la différenciation produit (§1 Vision). Réalise UJ-1, UJ-2.

#### FR-9: Calcul de la value par cheval
Pour tout cheval dont la cote est connue, le système calcule `value = probabilité × cote − 1` et l'affiche explicitement en regard de la probabilité implicite du marché.

**Consequences (testable):**
- La value n'est jamais dérivée d'un simple seuil de score sans comparaison réelle à la cote ("value bet cosmétique" — erreur documentée à ne pas reproduire).
- Un cheval sans cote saisie affiche "Cote manquante", jamais une value calculée par défaut.
- La cote est portée comme propriété de l'identité du cheval, jamais indexée séparément sur le rang du classement trié (bug de désynchronisation documenté à ne pas reproduire).

#### FR-10: Mise suggérée par Kelly fractionné
Le système suggère une mise par cheval selon Kelly fractionné, sur une bankroll et une fraction réglables par l'utilisateur.

**Consequences (testable):**
- La mise est nulle (masquée, pas à zéro trompeur) quand le Kelly brut est négatif ou la cote manquante.
- La fraction de Kelly et la bankroll sont des réglages persistés, pas resaisis à chaque calcul.

### 4.5 Combinaisons de paris

**Description :** Classement des combinaisons de paris multi-chevaux par probabilité, en dossards. Réalise UJ-1.

#### FR-11: Combinaisons à ordre et désordre (couplé à quinté)
Le système énumère et classe par probabilité décroissante les combinaisons couplé, tiercé (trio), quarté, quinté, en versions ordre et désordre.

**Consequences (testable):**
- Le calcul est exact (énumération Plackett-Luce sur le pool des meilleurs chevaux), pas une approximation, pour ces quatre types de paris.
- Chaque combinaison affiche les numéros de dossard, jamais uniquement les noms.

#### FR-12: Combinaisons "parmi les k premiers" (couplé placé, 2 sur 4)
Le système estime par simulation les paris couplé placé et 2 sur 4.

**Consequences (testable):**
- L'estimation est produite par simulation Monte-Carlo (≥20 000 tirages), avec une marge d'erreur communiquée à l'utilisateur plutôt que présentée comme exacte.
- Le couplé placé n'est proposé qu'à partir de 8 partants, le 2 sur 4 qu'à partir de 14 (cohérent avec les règles réelles Quinté+).

### 4.6 Fonctionnement hors ligne sur hippodrome

**Description :** La contrainte transverse qui structure l'architecture mobile (cahier mobile §4) — le calcul ne doit jamais dépendre du réseau une fois les données chargées. Réalise UJ-2.

#### FR-13: Calcul entièrement local sur l'appareil
Une fois les données d'une course en cache, le classement, les probabilités, la value et les combinaisons se recalculent sans aucun appel réseau, à chaque changement de paramètre.

**Consequences (testable):**
- Modifier un réglage du moteur (ex. sensibilité au poids) et relancer le calcul ne déclenche aucune requête HTTP.
- L'app reste utilisable (consultation + recalcul) en mode avion, pour une course déjà chargée.

#### FR-14: Cache local des courses consultées
Les courses déjà chargées (programme, partants, historique) sont stockées localement (SQLite) pour consultation et recalcul hors ligne.

**Consequences (testable):**
- Une course consultée une fois reste accessible hors ligne indéfiniment, jusqu'à suppression explicite ou rafraîchissement manuel.
- Le rafraîchissement des données (cotes, partants) n'est jamais automatique en arrière-plan sur écran de consultation — seulement sur demande explicite.

#### FR-15: Échec propre des fonctionnalités réseau-dépendantes
L'import photo et le rafraîchissement des cotes en direct, seules fonctionnalités nécessitant le réseau, échouent proprement si le réseau est indisponible.

**Consequences (testable):**
- Un échec réseau sur ces deux fonctionnalités affiche un message clair et laisse l'utilisateur poursuivre en saisie manuelle, sans bloquer le reste de l'app.

### 4.7 Ingestion automatisée des données PMU (backend)

**Description :** Alimente le backend en données de courses françaises pour préremplir l'app sans saisie manuelle. Réalise UJ-1 (en le rendant possible).

#### FR-16: Ingestion quotidienne du programme et des partants
Un job planifié récupère chaque jour le programme, les partants et leur historique des courses françaises, et les stocke en base.

**Consequences (testable):**
- Le code d'accès à la source de données (PMU) est isolé dans un unique module adaptateur (`pmu_client.py`) — aucun autre module ne lit un champ JSON brut du PMU directement (pattern déjà posé au cahier backend §5.1, condition de résilience si la source change ou est remplacée).
- La fréquence d'appel reste raisonnable (pas de parallélisation agressive, identifiant honnête, espacement entre requêtes) — cohérent avec la position de prudence du porteur de projet vis-à-vis d'une source non autorisée (§9 Constraints).
- Le job récupère, quand disponible, également le programme du lendemain pour permettre une préparation à l'avance (réalise UJ-1 : préparer la réunion du dimanche la veille au soir).

#### FR-17: Finalisation différée des résultats
Une course n'est marquée "finalisée" (résultat définitif) que le lendemain ou après un délai configurable, pour absorber une éventuelle disqualification prononcée après enquête.

**Consequences (testable):**
- Un résultat provisoire n'écrase jamais silencieusement une correction ultérieure de classement.

### 4.8 Extraction par image ou PDF (repli vision)

**Description :** Complète les données manquantes (réunions étrangères, historique ancien, source PMU indisponible) par extraction vision IA côté backend uniquement. Réalise UJ-3.

#### FR-18: Extraction d'une fiche cheval par photo ou PDF
L'utilisateur peut importer une fiche cheval individuelle par photo ou PDF ; le backend extrait les champs structurés.

**Consequences (testable):**
- L'appel au fournisseur de vision IA se fait exclusivement côté backend (`/extraction/fiche`) — aucune clé API de service tiers n'apparaît dans le code source ni le binaire de l'application mobile (critère d'acceptation explicite du cahier mobile §11).
- Les champs extraits sont présentés comme "à vérifier" (bandeau visuel), jamais appliqués sans passage par la validation de l'utilisateur.
- Le format PDF est accepté au même titre que l'image (certaines fiches sont exportées en PDF).
- Le numéro de dossard affiché en tête de certaines fiches (observé sur des sites tiers) est signalé comme plausible mais à vérifier, jamais traité comme fiable à 100 % sans recoupement — il peut correspondre à un identifiant interne au site plutôt qu'au vrai numéro PMU du jour.

#### FR-19: Extraction d'un programme de course complet par photo ou PDF
L'utilisateur peut importer une capture du programme complet d'une course ; le backend extrait la course cible et tous les partants visibles en un seul geste.

**Consequences (testable):**
- Le préremplissage résultant marque visuellement chaque cheval importé comme "à vérifier", identique au traitement de FR-18.

**Feature-specific NFRs:**
- Les deux prompts d'extraction (fiche unique, programme complet) déjà rédigés et validés dans `analyse_hippique_ia.jsx` sont repris tels quels — ils encodent déjà les règles de conversion terrain/niveau et la reconnaissance des incidents en colonne rang.

### 4.9 Réglages du moteur

**Description :** Un écran dédié expose tous les coefficients réglables du moteur, condition de la promesse de transparence du produit (§1 Vision : "chaque coefficient est visible et modifiable par l'utilisateur", à l'opposé du modèle opaque des concurrents). Réalise UJ-2.

#### FR-20: Réglages exposés et persistés
L'utilisateur peut consulter et modifier tous les paramètres du moteur — pondération de récence, contraste (k), sensibilité au poids, âges min/max, lissage bayésien, coefficient inédit, intensité du malus incident, bankroll, fraction de Kelly — chacun avec sa valeur par défaut visible.

**Consequences (testable):**
- Chaque paramètre modifié est persisté localement et réappliqué au calcul suivant, sans ressaisie à chaque session (cohérent avec FR-10 pour bankroll/Kelly, étendu ici à l'ensemble des paramètres du moteur).
- Une action "réinitialiser aux valeurs par défaut" restaure l'ensemble des paramètres en un geste.

### 4.10 Export et partage des résultats

**Description :** Permet à l'utilisateur d'emporter un classement calculé hors de l'app (message, impression, archivage personnel).

#### FR-21: Export du classement calculé
L'utilisateur peut exporter ou partager le classement, les probabilités, la value et les combinaisons d'une course déjà calculée.

**Consequences (testable):**
- L'export est disponible au minimum en texte ou JSON, sans dépendance réseau (les données sont déjà en cache local, §4.6).
- Un export PDF est un bonus optionnel, jamais un prérequis de cette exigence.

## 5. Non-Goals (Explicit)

- Aucune fonctionnalité de placement de pari automatisé, sur aucun canal (PMU, Genybet...), à aucune version future. Le produit calcule et informe, il n'agit jamais sur un compte de jeu.
- Pas de couverture des courses hors France (pas de PMUC camerounais, pas de courses internationales) — le moteur et les échelles terrain/niveau sont calibrés sur les conventions françaises.
- Pas d'historique de presse/consensus intégré au score — si réintroduit un jour, affiché à part, jamais mélangé au calcul.
- Le produit ne prétend jamais à une fiabilité garantie : aucun écran de résultats sans le rappel que le jeu comporte des risques.
- Exclusions V1 différées à V2 (compte/authentification, paywall/facturation, notifications) : voir §6.2 pour le détail.

## 6. MVP Scope

### 6.1 In Scope

- Backend FastAPI : ingestion quotidienne PMU (plat, trot, obstacle, France), moteur de calcul complet (§4.3-4.5), endpoints `/courses`, `/courses/{id}/partants`, `/courses/{id}/importer`, `/analyse`, `/extraction/fiche`, `/extraction/programme`.
- App mobile Flutter, Android uniquement : tous les écrans du cahier mobile §7 (accueil, configuration course, liste partants, fiche cheval, import photo, résultats, réglages), moteur dupliqué en Dart, cache SQLite, fonctionnement hors ligne pour le calcul (§4.6).
- Export/partage du classement calculé (texte ou JSON au minimum ; export PDF en bonus, pas requis).
- Rappel de jeu responsable visible sur chaque écran de résultats.
- Usage mono-utilisateur, sans compte ni authentification.

### 6.2 Out of Scope for MVP

- Compte utilisateur, authentification, multi-appareil, synchronisation cloud — différé, condition : introduction d'un modèle payant (§10).
- Paywall / facturation / gestion d'abonnement ou de crédits — différé à V2, cette PRD documente l'intention (§10) sans la construire.
- Version iOS — différée à V2, une fois Android validé en usage réel. `[NOTE FOR PM]` Flutter permet le portage sans coût de conception supplémentaire quand la décision sera prise.
- Segment cercles/professionnels avec relation commerciale dédiée — phase 2 explicite, hors réflexion produit de ce PRD.
- Notifications push, rappels d'heure de départ.
- Historique de presse/consensus intégré au produit (affiché à part si réintroduit un jour, jamais mélangé au calcul — voir aussi §5).
- Backfill historique antérieur à 2004 au-delà de ce que `open-pmu-api` fournit déjà — pas un chantier V1 dédié.

## 7. Success Metrics

*Le critère primaire mesure la qualité du modèle, pas le succès commercial — cohérent avec un choix explicite du porteur de projet (brief §5) : un ROI positif sur peu de courses est peu fiable (variance élevée), la calibration est mesurable plus tôt et plus honnêtement.*

**Primary**
- **SM-1** : Calibration du modèle — sur un échantillon d'au moins quelques centaines de courses avec résultat connu, la calibration (les chevaux annoncés à X % de chances gagnent-ils environ X fois sur cent ?) doit être mesurablement meilleure que celle de la probabilité implicite du marché (`1/cote`), mesurée par score de Brier ou courbe de calibration par tranches. Valide FR-7, FR-8. En dessous de quelques centaines de courses, aucune conclusion n'est tirée dans un sens ou dans l'autre — pas de seuil chiffré fixé avant d'avoir ce volume. **Portée explicite** : SM-1 compare le modèle au marché (1/cote), pas au jugement des pronostiqueurs experts des sites concurrents — un SM-1 positif ne doit jamais être présenté comme une preuve de supériorité sur l'expertise humaine, question qui reste et restera non mesurée (§1 Vision, limite assumée).

**Secondary**
- **SM-2** : ROI simulé sur les paris à value détectée (FR-9) — présenté uniquement couplé à sa taille d'échantillon, jamais comme preuve isolée. Directionnel seulement, pas un objectif à optimiser en soi.
- **SM-3** : Proportion des mises que l'utilisateur place effectivement sur des chevaux signalés "value" par le modèle (FR-9), suivie dans le temps — un changement de comportement mesurable, pas une simple fréquence d'usage. Un utilisateur qui continue à jouer ses habitudes malgré le signal de l'outil n'est pas un succès, même s'il revient chaque dimanche.

**Counter-metrics (do not optimize)**
- **SM-C1** : Fréquence d'usage / rétention brute (revient chaque semaine) — explicitement écartée comme indicateur de succès à elle seule (contrepartie de SM-3, brief §5) : un usage fréquent sans changement de comportement de mise n'est pas un signal positif.
- **SM-C2** : Volume de mises suggérées ou de value détectée — ne doit jamais être optimisé pour lui-même. Un modèle qui signale de la "value" plus souvent n'est pas meilleur ; seule la calibration (SM-1) juge la qualité réelle. Contrepartie de SM-1 et SM-2 : empêche d'ajuster le moteur pour produire plus de signaux plutôt que des signaux plus justes.

## 8. Cross-Cutting NFRs

- **Parité fonctionnelle backend/mobile** : le moteur de calcul (scoring, probabilités, value, combinaisons) produit des résultats identiques à epsilon près entre l'implémentation Python (backend) et Dart (mobile), vérifié par les mêmes cas de test portés dans les deux langages (cahier backend §9, cahier mobile §5.2/§9).
- **Performance du calcul local** : le recalcul complet (score → probabilités → combinaisons, y compris la simulation Monte-Carlo à 20 000 tirages) s'exécute sur l'appareil mobile en un temps perçu comme instantané par l'utilisateur (pas de seuil chiffré fixé à ce stade — `[OPEN QUESTION]`, voir §11).
- **Disponibilité du calcul hors ligne** : non négociable une fois les données d'une course en cache (§4.6) — c'est une contrainte transverse, pas une fonctionnalité optionnelle.
- **Reproductibilité** : à jeu de données et paramètres identiques, le classement produit est identique à celui du prototype `analyse_hippique_v2.html` sur le même jeu d'entrée (critère d'acceptation explicite, cahier mobile §11).
- **Aucune clé API tierce embarquée côté client** : le principe s'applique à toute intégration future d'un fournisseur externe (vision IA aujourd'hui, tout autre service demain), pas seulement à l'extraction actuelle.

## 9. Constraints and Guardrails

### 9.1 Périmètre V1 — décision de cadrage

**V1 est mono-utilisateur, sans compte, sans authentification et sans paiement.** Cette décision réconcilie une tension identifiée entre les documents sources : le brief propose un modèle freemium (coupure gratuit/payant sur l'actionnable), mais les deux cahiers des charges techniques excluent explicitement compte utilisateur, authentification et facturation du périmètre ("service interne à usage personnel dans un premier temps"). Ce PRD tranche en faveur des cahiers techniques : le modèle économique du brief devient un objectif documenté pour une V2 (§10), pas une exigence de ce PRD. `[ASSUMPTION: confirmé explicitement par le porteur de projet lors du cadrage — pas une inférence.]`

### 9.2 Réglementaire — jeux d'argent (Cameroun)

Le porteur de projet est basé au Cameroun, régi par la loi n°2015/012 du 16 juillet 2015 et son décret d'application n°2019/2300/PM du 18 juillet 2019 (licences délivrées par le MINAT). Cette lecture cible structurellement les *opérateurs* qui collectent des mises ou détiennent une concession — mais **aucune source primaire ou juridique trouvée, ni par le porteur de projet ni par la recherche de marché menée pour ce PRD, ne confirme explicitement si un outil d'analyse qui ne collecte jamais de mise entre dans le champ d'application.** Le produit pointe en outre vers des courses françaises (PMU) plutôt que camerounaises (PMUC), une situation inédite dont aucun précédent directement transposable n'a été trouvé.

**Point de vigilance bloquant pour toute monétisation** (pas pour l'usage gratuit V1) : une consultation juridique locale spécifique à cette question doit être obtenue avant tout modèle payant (§10). Ce n'est pas un blocage pour le lancement V1 gratuit et mono-utilisateur, qui ne collecte aucune mise et ne facture rien.

### 9.3 Dépendance à une source de données non autorisée

Aucune des deux sources de données identifiées n'est autorisée par le PMU :
- L'API technique `turfinfo.api.pmu.fr` est non officielle, non documentée, sans accord écrit (une demande d'autorisation posée sur le forum officiel du PMU n'a jamais reçu de réponse claire). Un accès légitime et documenté existe via l'infocentre du PMU, mais sous forme de contrat payant à plusieurs dizaines de milliers d'euros par an — réservé aux professionnels, hors de portée d'un projet bootstrap, ce qui explique le recours à la source non officielle plutôt qu'un simple choix de facilité.
- `open-pmu-api`, utilisée pour le backfill historique, est elle-même construite sur les mêmes données non officielles.

La recherche de marché confirme un durcissement des mécanismes anti-bot du PMU depuis fin 2024 (blocages IP temporaires signalés en cas de requêtes trop fréquentes) et l'absence de précédent de poursuite légale documenté contre un projet tiers — une zone grise tolérée, pas une garantie de non-poursuite.

**Conséquence produit directe** : le pattern adaptateur isolant l'accès PMU (FR-16) n'est pas une préférence d'architecture, c'est une exigence de résilience produit — en cas de coupure, seul ce module doit changer, et le repli par extraction d'image (§4.8) doit rester pleinement fonctionnel en continuité de service, même s'il est nettement plus lent (saisie manuelle par course plutôt que préremplissage automatique).

### 9.4 Coût du repli vision

L'extraction par image (§4.8) appelle un fournisseur de vision IA payant à l'usage. Aucun budget ni seuil de coût n'est fixé à ce stade — `[OPEN QUESTION]`, voir §11.

## 10. Monetization (Roadmap V2 — non construit en V1)

*Cette section documente l'intention économique du brief pour qu'elle ne se perde pas, sans créer d'exigence V1. Elle conditionne le passage à une V2 avec compte utilisateur (§6.2 Out of Scope).*

- **Principe retenu** : la coupure ne se situe pas entre le scoring de base (gratuit) et les combinaisons (payant) — le scoring est le vrai différenciateur face aux sites de pronostics, le donner gratuitement le diluerait. La coupure envisagée porte sur l'**actionnable** : gratuit = classement et value par cheval ; payant = mise Kelly, combinaisons précises en dossards, historique profond.
- **Format tarifaire** : encore ouvert (§11, Open Question 2). Un modèle à l'usage ou par crédits est pressenti plutôt qu'un abonnement mensuel fixe, la consommation de courses hippiques se faisant par pics (Quinté+ du dimanche) plutôt qu'au quotidien. La recherche de marché montre que le modèle dominant chez les comparables français (Geny) est un abonnement freemium façon presse (à l'unité, hebdomadaire, mensuel) plutôt qu'un SaaS à paliers — à considérer comme référence, pas comme décision. `[OPEN QUESTION]`, voir §11.
- **Comparables identifiés** : EquinEdge (US, IA de handicapping, probabilité par cheval, 39,95 $/mois) est le positionnement le plus proche ; aucun comparable identifié n'intègre de calculateur Kelly en hippisme — angle de différenciation supplémentaire pour une future offre payante.
- **Jalon de bascule vers une V2 monétisée**, conditionné aux deux éléments suivants réunis : (1) la calibration (SM-1) démontre un avantage prédictif réel et mesuré, pas supposé ; (2) une source de données légitime est sécurisée, ou au minimum un plan crédible existe (accord commercial, ou dépendance réduite grâce à l'historique déjà accumulé en base propre).
- **Structuration** : développement solo ou très petite équipe recommandé tant que ces deux conditions ne sont pas réunies, pour une raison précise plutôt que par prudence générale : la dépendance à une source de données non autorisée (§9.3) grandit avec la traction du produit — plus d'utilisateurs signifie mécaniquement plus de requêtes, plus de visibilité, plus de probabilité d'être bloqué. Lever des fonds avant que ce risque soit résolu reviendrait à vendre une promesse construite sur une fondation encore fragile.

## 11. Open Questions

1. Seuil de performance perçu comme "instantané" pour le recalcul local sur mobile (§8) — à définir une fois un premier appareil cible identifié.
2. Format tarifaire final pour la V2 monétisée (abonnement, crédits, ou hybride) — à trancher une fois la calibration (SM-1) disponible, pas avant (§10).
3. Portée exacte du champ d'application de la loi camerounaise sur les jeux d'argent pour un outil d'analyse sans collecte de mise (§9.2) — nécessite une consultation juridique locale spécifique, pas résolue par la recherche documentaire.
4. Budget/seuil de coût acceptable pour les appels au fournisseur de vision IA (§9.4).
5. Méthode de dérivation du niveau de course depuis l'allocation PMU (cahier backend §7.2) — calibration par quantiles proposée mais à valider sur un premier jeu de données réel, avant d'être considérée fiable.
6. Fréquence et volume d'ingestion quotidienne raisonnables pour ne pas solliciter excessivement une source non officielle (§9.3) — à décider avant d'automatiser le job d'ingestion.
7. Gestion des homonymes de chevaux (le nom normalisé est la seule clé de rapprochement inter-courses, `numPmu` n'étant pas stable) — accepter le risque documenté ou ajouter un critère de désambiguïsation si un cas réel se présente.

## 12. Assumptions Index

- §9.1 — V1 mono-utilisateur sans compte ni paiement : confirmé explicitement par le porteur de projet lors du cadrage de ce PRD, pas une inférence du PM.
- §6.2 — Android d'abord, iOS en V2 : confirmé explicitement par le porteur de projet.
- Calendrier — pas de date de lancement fixe, rythme bootstrap : confirmé explicitement par le porteur de projet.
- §9.2 — La réglementation camerounaise cible structurellement les opérateurs de mise, pas les outils d'analyse : lecture du brief, non confirmée par une source juridique primaire (voir Open Question 3).
- §10 — Modèle à l'usage/crédits pressenti plutôt qu'abonnement fixe : préférence exprimée dans le brief, pas encore décidée (voir Open Question 2).
