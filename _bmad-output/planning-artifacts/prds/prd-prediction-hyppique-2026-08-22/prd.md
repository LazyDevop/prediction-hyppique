---
title: prediction-hyppique
created: 2026-08-22
updated: 2026-11-16
status: final
---

# PRD: prediction-hyppique
*Outil d'aide à la décision pour les courses hippiques PMU — working title, confirmer le nom commercial.*

## 0. Document Purpose

Ce PRD cadre le produit dans son ensemble : backend Python/FastAPI (ingestion PMU, moteur de calcul, pronostics publiés, extraction vision, comptes et paiement), application mobile Flutter (produit complet, usage sur hippodrome), web app compagnon et back-office. Il s'appuie sur les documents suivants déjà rédigés par le porteur de projet, qui restent la référence pour tout ce qui est *comment* plutôt que *quoi* :

- `brief_projet_analyse_hippique.md` — positionnement, différenciation, périmètre, modèle économique envisagé, critères de succès, risques.
- `cahier_des_charges_backend_hippique.md` — spécification exacte du moteur de calcul (constantes, formules, cas de test), source de données, schéma BDD, endpoints API.
- `cahier_des_charges_app_mobile.md` — architecture Flutter, écrans, stratégie offline, erreurs à ne pas reproduire.
- `cahier_des_charges_module_multi.md` (v3, 2026-10-18) — règles du pari Multi, sélection du modèle, systèmes réduits, protocole d'évaluation (§4.11) ; recadré le 2026-10-18 en pronostic sans argent (`multi/reconcile-cdc-multi-prd.md`, « D ter »), recadrage qui fait foi sur le cahier en cas d'écart.
- `brainstorm-intent.md` (2026-11-15, `_bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/`) — passage à un service payant : plateformes, comptes, licences, paiement Mobile Money, sécurité. Fait foi sur ces sujets en cas d'écart avec les cahiers techniques, qui excluaient comptes et facturation. Correction de cap : `sprint-change-proposal-2026-11-15.md`.
- `briefs/brief-prediction-hyppique-backoffice-2026-10-18/brief.md` — back-office de complétion des données (agents de saisie) ; le PRD n'en reprend que le cadre d'accès (§4.14).

Ce PRD ne duplique pas les formules ni le code : il définit les capacités attendues, pour qui, et sous quelles contraintes. Les détails d'implémentation (constantes exactes, structure de modules, stack technique, cas de test) restent dans les cahiers des charges cités et dans `addendum.md`. En cas de divergence entre ce PRD et les cahiers techniques sur une question de *comportement produit*, ce PRD fait foi ; sur une question de *formule ou d'implémentation*, le cahier backend fait foi (principe déjà posé par le porteur de projet lui-même dans le cahier mobile, section 0).

Vocabulaire : ce PRD utilise les termes du §3 Glossaire de façon stricte — pas de synonymes ailleurs dans le document.

## 1. Vision

Un parieur qui veut analyser une course hippique avant de jouer dispose aujourd'hui de sites de pronostics (Geny, Bilto, ZEturf, CanalTurf) qui délivrent un jugement d'expert en prose. Aucun n'affiche de probabilité chiffrée par cheval, aucun ne la compare explicitement à la cote du marché pour dire *pourquoi* un cheval serait sous-coté, aucun ne classe des combinaisons de paris par probabilité, aucun ne suggère une mise. Une recherche de marché confirme ce vide côté hippisme français : le concept de "value betting" chiffré existe (EquinEdge aux États-Unis, RebelBetting/OddsJam en arbitrage multisport), mais aucun outil français n'affiche ce ratio probabilité×cote en hippisme — et aucun outil hippique identifié, français ou international, n'intègre de calculateur Kelly.

prediction-hyppique transforme l'information hippique abondante mais non exploitée en décision chiffrée, reproductible et actionnable : un moteur de scoring (Plackett-Luce / Harville) calcule une probabilité par cheval à partir de son historique de performances, la compare à la cote pour détecter la value (`probabilité × cote − 1`), classe les combinaisons de paris possibles (couplé à quinté, ordre et désordre) par probabilité décroissante, et suggère une mise par la formule de Kelly fractionné. Le moteur est transparent : chaque coefficient (récence, poids, âge, terrain, niveau) est visible et réglable par l'utilisateur, à l'opposé du pronostic opaque des sites concurrents.

Pour le **Multi**, le même modèle donne un pronostic : sur chaque course où le PMU propose le Multi, et pour le nombre de chevaux que le parieur choisit, quels chevaux peuvent constituer l'arrivée, quels chevaux les plus probables retenir comme bases, avec quel degré de confiance — et pourquoi. Il dit aussi ce qu'un système de tickets couvre vraiment : une couverture garantie, jamais un gain garanti. Il ne parle jamais d'argent : ni mise, ni coût, ni gain.

Le produit reste, explicitement et durablement, un outil d'**aide à la décision** — jamais un système de paris automatisé, jamais un générateur de certitudes. Chaque écran de résultats porte le rappel que le jeu comporte des risques et qu'aucun modèle ne garantit un gain. Le moteur de calcul est déjà conçu et validé numériquement dans deux prototypes fonctionnels (`analyse_hippique_v2.html`, `analyse_hippique_ia.jsx`) — ce PRD cadre son industrialisation en un produit backend + mobile utilisable, y compris sur l'hippodrome avec une connexion incertaine. À côté de ce moteur transparent, le serveur publie chaque jour un **pronostic de référence** (§4.15), produit par un modèle entraîné sur l'historique et recalculé à chaque instantané de cotes : c'est ce que l'utilisateur voit par défaut ; le moteur réglable reste son mode expert.

**Limite assumée, à ne pas cacher** : le modèle est aveugle à l'information tactique et humaine que les tipsters captent (changement de driver de dernière minute, intention de course rapportée par un entraîneur) — aucune donnée chiffrée ne remplace cela aujourd'hui. De la même façon, rien ne prouve à ce stade que les probabilités du modèle sont mieux calibrées que le jugement d'expert des pronostiqueurs ; seul un backtest sur un volume significatif de courses pourra l'établir (détail : §7, portée explicite de SM-1).

**Modèle de service** : le produit est un **service payant**, lancé au **Cameroun** puis étendu au reste de l'Afrique et au monde. Il est utilisé sur téléphone Android en priorité — l'application mobile est le produit complet —, avec une web app compagnon pour préparer sur ordinateur. Un compte et une licence par paliers donnent accès aux fonctionnalités ; le paiement se fait par Mobile Money. Le produit ne collecte jamais de mise : on paie l'outil, jamais un pari.

## 2. Target User

### 2.1 Jobs To Be Done

- **Fonctionnel** : avant de jouer une course, savoir quels chevaux sont statistiquement sous-cotés par le marché plutôt que de me fier à un pronostic en prose que je ne peux pas vérifier.
- **Fonctionnel** : obtenir des combinaisons de paris (couplé, tiercé, quarté, quinté) déjà classées par probabilité, en dossards, sans les recalculer moi-même.
- **Fonctionnel** : savoir combien miser sur un cheval donné sans avoir à faire le calcul de Kelly moi-même, et sans dépasser ce que je peux me permettre de perdre.
- **Fonctionnel (Multi)** : pour une course où le Multi est proposé, obtenir un pronostic expliqué — les chevaux qui peuvent constituer l'arrivée, à la taille de sélection que je choisis, avec un indice de confiance — et voir ce qu'un système de tickets couvre vraiment, pour ne pas me fier à une promesse de « garantie » ; le lendemain, savoir sans embellissement combien de chevaux de l'arrivée j'avais.
- **Contextuel** : pouvoir analyser une course même sans réseau fiable, depuis les tribunes ou le pesage d'un hippodrome.
- **Émotionnel** : reprendre la main sur ma décision de pari plutôt que de suivre aveuglément le favori du marché ou l'avis d'un tipster anonyme.
- **Fonctionnel (porteur de projet)** : disposer d'un historique de courses accumulé en base propre, condition pour mesurer un jour si le modèle est réellement mieux calibré que le marché.

### 2.2 Non-Users (v1)

- Les cercles de jeu et parieurs professionnels — relation commerciale différente (vente directe), envisagée en phase 2, pas conçue dans ce PRD.
- Les parieurs sur des courses hors France (courses camerounaises du PMUC, courses internationales) — les échelles terrain/niveau et la source de données sont calibrées sur la France. Les **parieurs résidant au Cameroun qui jouent les courses françaises** (via le PMUC ou un autre opérateur) sont, eux, la cible du lancement.
- Les utilisateurs cherchant un système qui place les paris à leur place — non-goal explicite et permanent (§5).
- Le partage d'un compte entre plusieurs personnes — un compte est personnel ; le partage se fait par l'offre Duo (§10), et l'offre Club (revente par un tiers) vient plus tard.

### 2.3 Key User Journeys

- **UJ-1. Marc prépare sa réunion du dimanche depuis son salon.**
  - **Persona + contexte :** Marc, parieur individuel régulier, prépare le Quinté+ du dimanche la veille au soir, avec une bonne connexion.
  - **État d'entrée :** app ouverte, compte connecté et déverrouillé par son code PIN, palier Expert. Programme du jour pas encore chargé.
  - **Parcours :** il rafraîchit le programme du jour (accueil) → sélectionne la réunion et la course cible → les partants et leur historique sont préremplis depuis le backend (données PMU déjà en base) → il ajuste manuellement le terrain qu'il a vu annoncé et corrige la cote d'un cheval → il lance le calcul.
  - **Climax :** l'écran de résultats affiche le classement, la jauge modèle vs marché, et un cheval marqué "value forte" que le marché sous-cote clairement selon le modèle.
  - **Résolution :** il consulte la grille de combinaisons (quinté ordre/désordre) déjà classée par probabilité, note les dossards, ferme l'app. Les données de cette course restent en cache local pour consultation hors ligne le lendemain.
  - **Edge case :** si le backend n'a pas encore ingéré cette réunion, l'app déclenche l'import à la demande (`POST /courses/{id}/importer`) avant de préremplir.

- **UJ-2. Marc recalcule sur l'hippodrome avec une connexion saturée.**
  - **Persona + contexte :** Marc est dans les tribunes, la 4G est saturée par l'affluence, la course qu'il a préparée la veille est déjà en cache.
  - **État d'entrée :** app ouverte hors ligne ou en connexion très dégradée, course déjà chargée la veille (UJ-1), droit Expert encore valide (FR-44).
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

- **UJ-4. Marc prépare son pronostic Multi du samedi.**
  - **Persona + contexte :** Marc, 38 ans, joue au Multi le week-end par plaisir. Il lit un peu la presse sans s'y fier aveuglément, se méfie des « systèmes garantis », et joue lui-même auprès de son opérateur habituel ; ce qu'il mise ne regarde que lui, l'app ne lui en parle pas. C'est le même parieur individuel qu'en UJ-1 à UJ-3, côté Multi. Samedi, 9 h 40, chez lui, connecté. *(Récit d'origine : `sources/uj-multi-marc-2026-10-17.md` ; réécrit pour suivre les décisions D0-D7 du module Multi, puis le recadrage du 2026-10-18 qui en fait un pronostic sans argent.)*
  - **État d'entrée :** programme du jour chargé ; une course où le Multi est proposé a 18 partants.
  - **Parcours :** il ouvre l'écran Multi depuis la course → l'app confirme « 18 partants, course éligible » et affiche « L'outil ne place aucun pari » → il choisit la taille de sa sélection : 12 chevaux → le modèle propose les 12 chevaux qui ont, ensemble, la plus forte probabilité de contenir l'arrivée, et l'indice de confiance du pronostic : « confiance moyenne », avec ses raisons (probabilité de couverture, course ouverte, deux chevaux à historique court), et les mentions « seuils provisoires » et « modèle en cours d'évaluation » — Marc ne voit pas un oracle → chaque cheval de la sélection porte son explication (« estimé à 41 % d'être dans les 4 premiers »), et les chevaux écartés les plus proches disent pourquoi → Marc sait qu'un cheval ne partira pas : il le marque non-partant et le pronostic se recalcule ; il ajoute ensuite un cheval auquel il croit : la sélection passe en « modifiée », se réévalue, et le modèle propose les échanges qui améliorent le plus la probabilité de couverture → parmi les 3 « chevaux les plus probables » proposés, chacun avec sa probabilité estimée, il active le premier comme base, après avoir lu les tickets qu'il économise et ce qu'il coûte en probabilité de couverture → il parcourt les systèmes : pour chaque formule (tickets de 4 à 7), le nombre de tickets, de tickets physiques et les grilles en dossards, sans aucun montant (chiffres indicatifs tant que les règles du pari ne sont pas vérifiées, §9.5) → il lit la garantie : « Si les 4 premiers sont dans votre sélection et incluent votre base, au moins un de vos tickets les contient tous », suivie de « Couverture garantie — pas un gain garanti » → il regarde l'évaluation : probabilité de couverture, distribution du nombre de chevaux capturés (0 à 4) → par curiosité, il ouvre « Autres méthodes » : la méthode 1 du document source Multi y figure, règle par règle, avec « hypothèse non validée ».
  - **Climax :** il voit en un écran quels chevaux peuvent constituer l'arrivée selon le modèle, avec quel degré de confiance, ce que ses tickets couvrent réellement et pourquoi le modèle propose ce pronostic.
  - **Résolution :** confiance moyenne : Marc s'en tient à ce pronostic et n'ajoute rien. Il appuie sur « Je retiens ce pronostic », copie les grilles en dossards (export texte), ferme l'app et va jouer lui-même. Le lendemain, l'app lui montre « 3 chevaux capturés sur 4 · arrivée dans la sélection : non », sans rien embellir, et la même ligne pour le pronostic du modèle ; ce dernier et les comparateurs, journalisés avant le départ, alimentent l'évaluation des méthodes.
  - **Edge case :** sur l'hippodrome sans réseau, un non-partant est annoncé au micro à la dernière minute → Marc le marque non-partant, le pronostic se recalcule sur l'appareil et l'écran montre ce qui change dans ses tickets.
  - **Critères d'acceptation (porteur de projet) :** chaque cheval affiche ce qui l'a fait sélectionner ; « hypothèse non validée » (comparateurs), « modèle en cours d'évaluation » (pronostic du modèle), « Couverture garantie — pas un gain garanti » et « L'outil ne place aucun pari » sont visibles aux étapes concernées ; chaque système affiché est vérifié (aucun groupe de 4 chevaux non couvert) ; le pronostic du modèle est journalisé avant le départ, et le pronostic retenu par Marc est conservé sur son téléphone, tous deux avec l'heure des données utilisées.

- **UJ-5. Paul s'abonne par Mobile Money depuis son téléphone.**
  - **Persona + contexte :** Paul, Douala, turfiste du week-end, un seul appareil : un Android d'entrée de gamme. Pas d'ordinateur, pas de carte bancaire, un compte MTN MoMo.
  - **État d'entrée :** app installée depuis le Play Store, aucun compte.
  - **Parcours :** il saisit son numéro → reçoit un code par SMS → choisit un code PIN → voit le pronostic du matin (palier Gratuit) → sur la course de 15 h, un aperçu indique « Le classement a changé à H-30 pour 3 chevaux — palier Turfiste » → il ouvre les offres → choisit le pass semaine Turfiste → paie par MTN MoMo et valide sur son téléphone → l'app affiche « Paiement en attente de confirmation » puis « Pass semaine actif jusqu'au … ».
  - **Climax :** les instantanés H-60, H-30 et H-15 se débloquent sur la course en cours, sans redémarrer l'app.
  - **Résolution :** il prépare ses courses du dimanche sur son téléphone, hors ligne compris une fois les courses chargées.
  - **Edge case :** le paiement échoue ou n'est pas confirmé par l'agrégateur → aucun droit n'est activé, l'écran le dit et propose de réessayer ; un paiement confirmé plus tard active le droit sans action de Paul.

- **UJ-6. Marc prépare sur son ordinateur et décide sur son téléphone.**
  - **Persona + contexte :** Marc, palier Expert, prépare le Quinté+ sur son PC le samedi soir.
  - **État d'entrée :** compte Expert actif sur le téléphone ; aucune session sur le PC.
  - **Parcours :** il ouvre la web app → elle affiche un QR code → il le scanne avec l'app de son téléphone, déjà connectée, et approuve → le PC rejoint son compte et apparaît dans « Mes appareils » → il prépare ses courses suivies et retient un pronostic Multi.
  - **Climax :** le dimanche, au guichet, il ouvre l'app de son téléphone : ses courses suivies et son pronostic retenu y sont, et l'instantané H-10 recalcule le classement.
  - **Edge case :** un appareil de plus que la limite de son palier tente de se connecter → il est bloqué, l'écran propose l'offre Duo ou de retirer un appareil depuis « Mes appareils ».

## 3. Glossary

- **Cote** — Rapport offert par le marché sur un cheval (ex. 6.5). Sert à calculer la **probabilité implicite** du marché (`1/cote`) et la **value**.
- **Value** — `probabilité du modèle × cote − 1`. Positive si le modèle estime le cheval sous-coté par le marché.
- **Score** — Note composite d'un cheval issue du moteur (forme pondérée × ajustements poids/âge, lissée). Sert de base au calcul de probabilité.
- **Forme** — Moyenne pondérée par récence des notes de performance d'un cheval sur son historique.
- **Course cible** — La course que l'utilisateur analyse.
- **Partant** — Cheval effectivement engagé dans la course cible.
- **Partant virtuel (outsider virtuel)** — Cheval déclaré partant de la course cible mais non saisi/analysé par l'utilisateur ; modélisé avec un score réduit pour que les probabilités restent réalistes.
- **Cheval inédit** — Cheval n'ayant jamais couru (fait connu, distinct d'un historique simplement non saisi).
- **Terrain** — État du sol, deux échelles distinctes selon le type de piste (valeurs exactes : cahier backend §7). Ne jamais mélanger les deux échelles.
- **Niveau (de course)** — Catégorie de la course cible ou d'une performance passée : Groupe I à IV, Listed, puis Catégorie A à G/H.
- **Incident** — Événement anormal dans une performance passée (chute, disqualification, non-partant...), appliquant un malus à la note plutôt qu'un simple dernier rang. Toutefois, Non Partant (NR) exclut la ligne du calcul.
- **Musique** — Chaîne codée résumant l'historique récent d'un cheval (ex. "1h5s2h1s2s"), telle que fournie par la source PMU ou lue sur une fiche.
- **Combinaison (ordre / désordre)** — Pari portant sur plusieurs chevaux à une position précise (ordre) ou dans un ensemble sans ordre (désordre) : couplé, tiercé (trio), quarté, quinté.
- **Couplé placé / 2 sur 4** — Paris "parmi les k premiers", estimés par simulation Monte-Carlo (non calculables exactement).
- **Bankroll** — Capital que l'utilisateur consacre au jeu, base du calcul de la mise Kelly.
- **Mise Kelly (fractionné)** — Mise suggérée dérivée de la formule de Kelly, réduite par une fraction réglable (ex. 25 %) pour limiter la variance.
- **Overround** — Marge du marché intégrée dans les cotes (`Σ(1/cote) − 1`), calculable seulement si toutes les cotes des chevaux analysés sont connues.
- **Calibration** — Mesure de la qualité du modèle : quand il annonce X % de chances à un ensemble de chevaux, gagnent-ils environ X fois sur cent ? Mesurée par score de Brier ou courbe de calibration.
- **PMU** — Pari Mutuel Urbain (France), source des données de courses et opérateur de référence pour ce produit. À ne pas confondre avec le **PMUC** (Pari Mutuel Urbain Camerounais), hors périmètre.
- **Réunion** — Ensemble des courses organisées sur un même hippodrome le même jour.
- **Multi** — Pari PMU sans ordre sur les 4 premiers, joué avec des tickets de 4, 5, 6 ou 7 chevaux ; un ticket paie si les 4 premiers y figurent. Règles détaillées : cahier Multi §2.
- **Document source Multi** — Brochure PMU « Multi-Systèmes » de 2001-2002 dont viennent les règles du pari, la méthode 1 et le catalogue de systèmes ; à distinguer du **cahier Multi** (`cahier_des_charges_module_multi.md`), qui spécifie le module.
- **Course éligible (Multi)** — Course française ingérée depuis la source PMU dont la liste des paris contient le Multi. Plusieurs courses le sont chaque jour (19 sur 48 le 15/01/2022, dont 15 françaises). Le Mini Multi est hors périmètre. Remplace la notion de « course support » (décision D quater du 2026-10-18).
- **Base** — Cheval imposé dans tous les tickets d'un système Multi (0 à 3 bases), présenté à l'utilisateur comme « cheval le plus probable », toujours avec sa probabilité estimée d'être dans les 4 premiers.
- **Sélection (Multi)** — Ensemble des chevaux retenus pour un Multi, bases comprises, de la taille choisie par l'utilisateur (4 à 20 chevaux). Recommandée par le modèle, ou « modifiée » quand l'utilisateur la retouche.
- **Pronostic (Multi)** — Ce que le module propose pour une course éligible : une sélection, ses bases, les systèmes qui la couvrent, l'évaluation et l'indice de confiance. Ne comporte jamais de mise, de coût, de gain ni de rapport.
- **Groupe de 4 chevaux** — Ensemble sans ordre de 4 chevaux ; un système Multi doit couvrir chaque groupe de 4 de la sélection, dès lors qu'il contient les bases. À ne pas confondre avec une **Combinaison**, qui désigne un type de pari.
- **Système réduit** — Ensemble de tickets qui couvre tous les groupes de 4 chevaux d'une sélection qui contiennent les bases, avec moins de tickets que la formule intégrale.
- **Formule intégrale** — Jeu de tous les groupes de 4 chevaux d'une sélection en tickets de 4 : la référence, celle qui compte le plus de tickets, dont un système réduit économise des tickets.
- **Ticket physique** — Bulletin de jeu ; il porte jusqu'à 4 tickets Multi.
- **Couverture garantie** — Promesse qu'un système tient : si les 4 premiers sont dans la sélection et incluent les bases, au moins un ticket les contient tous. Jamais une garantie de gain.
- **Probabilité de couverture** — Probabilité, selon le modèle, que les 4 premiers soient tous dans la sélection (et incluent les bases).
- **Chevaux capturés** — Nombre des 4 premiers de l'arrivée présents dans la sélection (0 à 4).
- **Non-partant (du jour)** — Cheval retiré de la course cible avant le départ. Distinct du Non Partant (NR) d'une performance passée, traité sous **Incident**.
- **Indice de confiance** — Niveau de confiance du modèle dans son pronostic Multi pour une course — « confiance élevée », « moyenne » ou « faible » —, déduit de la probabilité de couverture, de l'ouverture de la course et de la fragilité des données. Ne dit jamais s'il faut jouer ni combien.
- **Pronostic retenu** — Pronostic Multi que l'utilisateur déclare suivre (« Je retiens ce pronostic ») : une sélection par course, avec bases et système, conservée sur l'appareil et figée au départ ; seule source de son débrief.
- **Comparateur** — Méthode de sélection autre que le modèle : méthode 1 du document source Multi et marché (affichées à part comme « hypothèse non validée »), et tirage au hasard (journalisé seulement). Le modèle et la méthode 1 sont mesurés contre le **marché**, la référence à battre ; le tirage au hasard sert de simple repère.

- **Compte** — Identité d'un utilisateur, rattachée à un numéro de téléphone vérifié par code (OTP). Personnel, jamais partagé.
- **Palier** — Niveau d'accès aux fonctionnalités : Gratuit, Turfiste, Expert (§10). Duo et Club sont des offres de partage, pas des paliers.
- **Droit (d'accès)** — Autorisation datée d'utiliser un palier : palier, date de début, date de fin, origine (paiement ou geste commercial). Il n'existe pas de simple statut « abonné ».
- **Pass** — Droit de courte durée acheté d'avance : pass journée (Expert pendant 24 h), pass semaine (Turfiste ou Expert).
- **Offre** — Ce que l'utilisateur achète : un pass, un abonnement mensuel ou l'offre Duo, pour un palier donné. Ne pas confondre avec une **Formule** du Multi.
- **Licence manuelle** — Droit créé par un administrateur hors paiement (geste commercial), avec motif et seconde approbation (FR-50). « Licence » seul n'est pas employé : on dit **Droit**.
- **Course suivie** — Course que l'utilisateur a retenue pour la préparer ; synchronisée entre ses appareils (FR-38).
- **Appareil** — Téléphone ou navigateur rattaché à un compte. Chaque session de navigateur compte comme un appareil.
- **Agrégateur Mobile Money** — Prestataire qui encaisse les paiements MTN MoMo et Orange Money et confirme chaque transaction au serveur.
- **Code PIN** — Code local de 4 à 6 chiffres qui déverrouille l'app sur l'appareil ; il n'est jamais envoyé au serveur.
- **Instantané de cotes** — Cotes relevées à H-60, H-30, H-15 ou H-10 avant le départ, et pronostic recalculé sur ces cotes.
- **Pronostic publié** — Probabilités de victoire et classement de chaque partant, calculés par le serveur avec le modèle de référence, publiés le matin puis à chaque instantané de cotes (§4.15). Distinct du **Pronostic (Multi)**.
- **Modèle de référence** — Modèle qui produit le pronostic publié : le **modèle combiné** (modèle entraîné sur l'historique, combiné aux cotes H-30, méthode de Benter) tant qu'il bat le marché sur les pronostics en direct, sinon le moteur de scoring §4.3 (architecture AD-14).

## 4. Features

*Index : FR-1 à FR-3 (§4.1 Programme et configuration), FR-4 à FR-6 (§4.2 Partants et historique), FR-7 à FR-8 (§4.3 Moteur de scoring), FR-9 à FR-10 (§4.4 Value et mise), FR-11 à FR-12 (§4.5 Combinaisons), FR-13 à FR-15 (§4.6 Hors ligne), FR-16 à FR-17 (§4.7 Ingestion PMU), FR-18 à FR-19 (§4.8 Extraction vision), FR-20 (§4.9 Réglages), FR-21 (§4.10 Export), FR-22 à FR-30 (§4.11 Multi), FR-31 à FR-38 (§4.12 Comptes et appareils), FR-39 à FR-46 (§4.13 Licences et paiement), FR-47 à FR-50 (§4.14 Back-office), FR-51 à FR-53 (§4.15 Pronostics publiés).*

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
- En cas d'échec (source indisponible), l'utilisateur bascule sans friction vers la saisie manuelle ou l'import photo (FR-5, FR-6, FR-18, FR-19).

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
- Une course consultée une fois reste accessible hors ligne indéfiniment, jusqu'à suppression explicite ou rafraîchissement manuel ; son contenu payant n'est affiché que pendant un droit valide (FR-44).
- Le rafraîchissement des données (cotes, partants) n'est jamais automatique en arrière-plan sur écran de consultation — seulement sur demande explicite.
- La web app compagnon (§6.1) n'a pas de cache local : elle demande le réseau, et l'écran le dit.

#### FR-15: Échec propre des fonctionnalités réseau-dépendantes
Les fonctionnalités qui demandent le réseau — import photo, rafraîchissement des données de course (cotes, non-partants, arrivées), réception des pronostics publiés et des instantanés (§4.15), connexion par code, rattachement d'un appareil, paiement, synchronisation, et toute la web app — échouent proprement si le réseau est indisponible.

**Consequences (testable):**
- Un échec réseau affiche un message clair et laisse l'utilisateur poursuivre avec ce qui est déjà sur l'appareil (saisie manuelle, données en cache), sans bloquer le reste de l'app.
- Le déverrouillage par code PIN et le calcul local ne demandent jamais le réseau.
- Un paiement lancé puis interrompu par une coupure reste « en attente de confirmation » ; au retour du réseau, l'app relit son statut, sans jamais déclencher un second débit.

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

**Description :** Un écran dédié expose tous les coefficients réglables du moteur, condition de la promesse de transparence du produit (§1 Vision : "chaque coefficient est visible et réglable par l'utilisateur", à l'opposé du modèle opaque des concurrents). Réalise UJ-2, UJ-4.

#### FR-20: Réglages exposés et persistés
L'utilisateur peut consulter et modifier tous les paramètres du moteur — pondération de récence, contraste (k), sensibilité au poids, âges min/max, lissage bayésien, coefficient inédit, intensité du malus incident, bankroll, fraction de Kelly, seuils de l'indice de confiance Multi (FR-26) — chacun avec sa valeur par défaut visible.

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

### 4.11 Module Multi

**Description :** Pour une course éligible (FR-22), le modèle propose un pronostic : les chevaux qui peuvent constituer l'arrivée du Multi, pour la taille de sélection que l'utilisateur a choisie, avec ses chevaux les plus probables (bases), les systèmes de tickets qui couvrent cette sélection et un indice de confiance — et dit pourquoi. Le module ne parle jamais d'argent : ni mise, ni coût, ni gain, ni rapport (§5). La spécification exacte (règles du pari, algorithme de sélection, générateur et vérificateur de systèmes, protocole d'évaluation) est dans `cahier_des_charges_module_multi.md` (v3), référence normative non dupliquée ici, **recadrée par les décisions du porteur de projet du 2026-10-18** (`multi/reconcile-cdc-multi-prd.md`, sections « D ter » et « D quater »), qui font foi en cas d'écart. Réalise UJ-4.

#### FR-22: Éligibilité d'une course au Multi
L'utilisateur voit, pour chaque course du programme, si le Multi y est proposé, et peut ouvrir l'écran Multi depuis une course éligible.

**Consequences (testable):**
- Une course est éligible si la liste des paris que la source PMU publie pour elle contient le Multi. Plusieurs courses peuvent l'être le même jour (décision D quater du 2026-10-18). Si les règles vérifiées sur pmu.fr (§9.5) fixent un nombre minimal de partants déclarés, cette condition s'ajoute ; un non-partant survenu après la déclaration ne fait pas perdre l'éligibilité.
- Le Mini Multi est hors périmètre : une course qui ne propose que le Mini Multi est non éligible, et l'écran le dit.
- Une course non éligible affiche sa raison (Multi non proposé, Mini Multi seulement, liste des paris indisponible) au lieu d'un pronostic. Il n'existe pas de mode « exploration ».
- Seules les courses issues de l'ingestion PMU (courses françaises, §5) portent un contexte Multi. Une course saisie à la main ou importée par photo n'ouvre pas le Multi. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
- Les règles du pari (formules, tickets, non-partants, ex-aequo, arrivée dégradée) ont une seule source de référence, partagée par le backend et l'application, avec leur provenance et une date de dernière vérification sur pmu.fr ; sans cette date, aucune grille n'est affichée (§9.5).
- Les partants déclarés mais non analysés sont signalés (« N partants non analysés, non sélectionnables ») ; l'utilisateur peut les analyser (FR-6) pour les rendre sélectionnables. Un cheval sans dossard reste dans le calcul des probabilités mais n'est pas sélectionnable ; des dossards en double bloquent le Multi jusqu'à correction de la liste des partants. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

#### FR-23: Pronostic du modèle pour la taille choisie
L'utilisateur choisit la taille de sa sélection, de 4 à 20 chevaux ; par défaut, la dernière taille utilisée, sinon 10. Pour cette taille, le modèle retient la sélection qui maximise la probabilité de couverture.

**Consequences (testable):**
- La sélection recommandée vient des probabilités du moteur (§4.3), jamais d'une méthode tierce ; aucun partant virtuel ni non-partant n'y figure. Une taille supérieure au nombre de chevaux sélectionnables est ramenée à ce nombre, et l'écran le dit.
- Aucun champ de budget, de mise ou de multiplicateur n'existe ; aucun montant n'est affiché.
- Le pronostic porte la mention « modèle en cours d'évaluation » tant que le protocole d'évaluation (SM-4) ne conclut pas. Si l'évaluation conclut que le modèle ne fait pas mieux que le marché, la mention reste et l'écran le dit, avec l'effectif de courses ; le pronostic ne bascule jamais silencieusement vers une autre méthode.
- À données, taille et paramètres identiques, le pronostic est identique sur le backend et sur l'appareil : deux sélections dont les probabilités de couverture diffèrent de moins de 10⁻⁹ sont départagées par les règles d'égalité du cahier Multi, jamais par l'arrondi du calcul.
- Au-delà d'une proportion réglable de partants inédits ou à historique court, un avertissement fort accompagne le pronostic et devient une raison de l'indice de confiance (FR-26).
- Le pronostic se calcule sur l'appareil, sans réseau, pour une course déjà en cache (cohérent avec FR-13).
- L'information de non-partant parvient à l'appareil par le rafraîchissement explicite de la course (réseau : le backend relit alors les partants et les cotes de cette course à la source) ou, sans réseau, par l'action « marquer non-partant » de l'utilisateur. Un non-partant sort du champ : le moteur de scoring recalcule les probabilités sans lui (aucun partant virtuel ne le remplace) — ou, si la course a un pronostic publié (§4.15), l'appareil renormalise les probabilités publiées sur le champ restant et les étiquette « ajusté » jusqu'à l'instantané suivant (architecture AD-14) —, puis le pronostic est recalculé localement ; Résultats et Multi montrent le même champ. L'écran montre à part ce que deviennent les tickets du pronostic retenu (requalification selon les règles du pari).
- Une course déjà ouverte se rouvre sans réseau après fermeture de l'application, avec les partants tels que reçus lors du dernier chargement réussi ; les modifications manuelles de la liste des partants ne sont pas conservées après fermeture. `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`

#### FR-24: Bases proposées par le modèle (« chevaux les plus probables »)
Le modèle propose 3 bases candidates, présentées comme « chevaux les plus probables » (moins si la sélection compte moins de 3 chevaux), classées par probabilité estimée d'être dans les 4 premiers ; l'utilisateur active ou désactive chacune. Aucune base n'est active au premier affichage ; l'utilisateur les active.

**Consequences (testable):**
- Les candidates sont calculées sur la sélection recommandée sans base, à la taille choisie.
- Chaque base candidate affiche sa probabilité estimée d'être dans les 4 premiers, les tickets économisés et la probabilité de couverture perdue si elle est retenue, à formule égale.
- Activer une base l'impose dans tous les tickets ; la désactiver l'interdit comme base. Chaque changement recalcule les systèmes, l'évaluation et l'indice de confiance.

#### FR-25: Systèmes de tickets vérifiés
Pour une sélection et ses bases, l'utilisateur voit chaque formule possible (tickets de 4 à 7) : nombre de tickets, nombre de tickets physiques, garantie de couverture et grilles en dossards. Aucun coût n'est affiché.

**Consequences (testable):**
- Aucun système n'est affiché si un groupe de 4 chevaux exigé par sa garantie n'est pas couvert (vérification systématique, jamais contournée).
- Le texte de garantie dit : « Si les 4 premiers sont dans votre sélection [et incluent vos bases], au moins un de vos tickets les contient tous », suivi de « Couverture garantie — pas un gain garanti ».
- Pour chaque entrée du catalogue du document source Multi, le système généré compte au plus autant de tickets que celui du document, sauf coquilles documentées dans le cahier Multi. Le catalogue précalculé reste disponible hors ligne.
- L'utilisateur peut saisir un système trouvé ailleurs : l'app dit s'il couvre réellement ce qu'il promet et, si le catalogue contient un système valide plus petit pour la même sélection, les mêmes bases et la même formule, le propose.
- Par défaut, la formule affichée est le Multi en 7.
- Les grilles s'exportent en texte copiable (extension de FR-21).

#### FR-26: Indice de confiance du pronostic
Pour une course et une sélection, le modèle donne un indice de confiance — « confiance élevée », « confiance moyenne » ou « confiance faible » — toujours accompagné de ses raisons.

**Consequences (testable):**
- Les raisons couvrent au minimum : probabilité de couverture, ouverture de la course, fragilité des données (inédits, historiques courts, cotes manquantes, partants non analysés).
- L'indice ne dit jamais s'il faut jouer ni combien : aucun « jouer », « passer » ou montant n'est affiché.
- Les seuils de l'indice dépendent de la taille de la sélection ; ce sont des réglages de l'utilisateur, persistés et réinitialisables (cohérent avec FR-20).
- Leurs valeurs par défaut sont fixées par le pilote d'évaluation, qui tourne sur l'historique (backtest) et ne dépend pas de la journalisation quotidienne. Jusque-là, une règle provisoire décidée par le porteur de projet le 2026-10-18 (D quater) s'applique et l'écran affiche « seuils provisoires ». Avec `p_hasard(v) = C(v,4) / C(n,4)` (n = chevaux du champ, non-partants exclus) : « confiance moyenne » si la probabilité de couverture ≥ min(max(2 × p_hasard ; 0,15) ; 0,90), « confiance élevée » si ≥ min(max(3 × p_hasard ; 0,35) ; 0,95), un cran de moins si la course est très ouverte ou les données fragiles. Une valeur saisie par l'utilisateur pour une taille remplace la règle pour cette taille.
- L'indice n'utilise aucune donnée de presse.

#### FR-27: Explications du pronostic
Chaque élément du pronostic dit pourquoi : cheval retenu, cheval écarté, base, système, indice de confiance.

**Consequences (testable):**
- Chaque cheval retenu affiche ce qui l'a fait sélectionner (probabilité estimée par le modèle d'être dans les 4 premiers, indicateurs de transparence de FR-4) et sa contribution à la probabilité de couverture. Aucun badge de value n'est affiché dans le Multi : la value reste sur l'écran Résultats (FR-9).
- Les 3 chevaux non retenus de plus forte probabilité estimée d'être dans les 4 premiers affichent la raison de leur exclusion.
- Les limites des données sont dites : heure des cotes utilisées, cote manquante, données fragiles (historique court, inédit), partants non analysés.
- Toute probabilité affichée est présentée comme une estimation du modèle (« estimé à 41 % »), jamais comme une fréquence observée.
- Les explications sont produites par le moteur sous forme de codes et de valeurs, jamais de phrases figées, pour permettre leur traduction ultérieure (§8).

#### FR-28: Choix de l'utilisateur
L'utilisateur choisit la taille de la sélection, peut retirer ou ajouter des chevaux analysés, imposer des chevaux, marquer un non-partant, ou saisir sa propre sélection, que le modèle évalue. L'utilisateur retient le pronostic qu'il compte suivre.

**Consequences (testable):**
- Une sélection retouchée passe en « modifiée » ; sa probabilité de couverture est recalculée et le modèle propose les 1 à 2 échanges qui l'améliorent le plus.
- Imposer un cheval affiche ce qu'il coûte en probabilité de couverture par rapport au pronostic libre, à taille égale.
- L'action « Je retiens ce pronostic » enregistre une seule sélection par course (avec bases et système), remplaçable jusqu'à l'heure de départ, figée ensuite ; si l'heure de départ est inconnue, le pronostic reste remplaçable jusqu'à la fin du jour de la course (heure de Paris). C'est la seule source du débrief de l'utilisateur (FR-30). L'export des grilles propose de retenir le pronostic, sans le faire à la place de l'utilisateur.

#### FR-29: Comparateurs
L'utilisateur peut consulter, à part et à la même taille de sélection, la sélection de deux comparateurs : la méthode 1 du document source Multi (règle par règle) et le marché (cotes les plus basses). Un tirage au hasard est journalisé comme repère d'évaluation, sans être affiché.

**Consequences (testable):**
- Chaque comparateur porte « hypothèse non validée » tant que le protocole d'évaluation ne conclut pas.
- Les performances d'un comparateur ne s'affichent qu'au-delà d'un effectif minimal fixé par le pilote, toujours avec l'effectif et l'intervalle de confiance.
- Le comparateur marché n'est pas calculé pour une course où une cote manque ; la course est exclue de sa mesure et de SM-4, et l'exclusion est comptée.
- Les comparateurs ne sont jamais proposés par défaut.

#### FR-30: Évaluation, journalisation et débrief
L'utilisateur voit l'évaluation de la sélection ; les pronostics du modèle sont journalisés avant le départ ; après la course, l'app montre ce qui a été capturé.

**Consequences (testable):**
- L'évaluation affiche la probabilité de couverture et la distribution du nombre de chevaux capturés (0 à 4). Aucun rapport Multi, réel ou historique, n'est affiché.
- Chaque jour, avant le départ, le backend journalise le pronostic du modèle aux tailles de référence fixées par le pilote, et les comparateurs, avec l'heure des données utilisées ; une entrée journalisée n'est jamais modifiée. Un échec de journalisation est lui-même journalisé (« non journalisé », avec la raison) et la course est exclue de l'évaluation ; l'exclusion est comptée. Un non-partant survenu après la journalisation est traité par les règles de requalification, sans réécrire l'entrée.
- Un pronostic reconstitué sur l'historique (backtest) n'utilise aucune donnée postérieure à l'heure de ses données ; toute constante dérivée des données (quantiles de niveau, réglages) est figée avant la période de test, et sa date figure dans le rapport d'évaluation. L'heure des cotes du comparateur marché est alignée sur celle du modèle, ou l'écart est déclaré.
- Le pronostic retenu par l'utilisateur (FR-28) est conservé sur l'appareil avec l'heure des données utilisées, pendant 90 jours, et synchronisé avec son compte (FR-38), où la même durée s'applique ; il reste consultable hors ligne.
- Après finalisation de la course (FR-17), l'app affiche, pour le pronostic retenu et pour le pronostic du modèle, « N chevaux capturés sur 4 » et « arrivée dans la sélection : oui / non », sans embellissement. Seule l'arrivée officielle sert au débrief et à l'évaluation ; les ex-aequo et l'arrivée dégradée suivent les règles du pari, et une correction de l'arrivée après finalisation met le débrief à jour avec une mention.

**Feature-specific NFRs:**
- Mentions obligatoires sur l'écran Multi : « L'outil ne place aucun pari », « Couverture garantie — pas un gain garanti », et le rappel de jeu responsable (§5).
- Aucun montant en euros (mise, coût, gain, rapport, seuil de rentabilité) n'apparaît sur l'écran Multi ni dans l'export de ses grilles.
- Les fonctions de calcul du Multi (règles, couverture, sélection, indice de confiance, vérification) ont la même parité backend/mobile que le reste du moteur (§8), vérifiée par des cas de test partagés.

### 4.12 Comptes, connexion et appareils

**Description :** Chaque utilisateur a un compte personnel, rattaché à son numéro de téléphone, utilisable sur son téléphone et, s'il le veut, sur un ordinateur. Réalise UJ-5, UJ-6.

#### FR-31: Inscription et connexion par numéro de téléphone
L'utilisateur crée son compte ou se connecte avec son numéro de téléphone et un code à usage unique reçu par SMS (ou WhatsApp), sans mot de passe.

**Consequences (testable):**
- Le code expire après 5 minutes et accepte au plus 5 essais ; les demandes de code sont limitées par numéro et par adresse IP.
- Aucune information ne permet de savoir si un numéro a déjà un compte (même message dans les deux cas).

#### FR-32: Code PIN et verrouillage
Après la première connexion, l'utilisateur choisit un code PIN de 4 à 6 chiffres qui déverrouille l'app sur cet appareil.

**Consequences (testable):**
- L'app se verrouille quand elle passe en arrière-plan et après une durée d'inactivité réglable (valeur par défaut : Open Question 14).
- Le code PIN n'est jamais transmis au serveur ; il déverrouille une session gardée dans le stockage sécurisé de l'appareil.
- Après 5 codes PIN faux, la session est effacée de l'appareil et une nouvelle connexion par code (FR-31) est exigée.

#### FR-33: Session sécurisée
Une session reste ouverte sur un appareil sans reconnexion, tant qu'elle n'est pas révoquée.

**Consequences (testable):**
- Un jeton d'accès vit 15 minutes ; un jeton de renouvellement, lié à l'appareil, est remplacé à chaque usage.
- La réutilisation d'un jeton de renouvellement déjà remplacé révoque toutes les sessions de cet appareil.

#### FR-34: Profil et email de secours
L'utilisateur renseigne une adresse email, vérifiée par un lien, qui sert à récupérer son compte.

**Consequences (testable):**
- Un compte payant sans email vérifié voit un rappel non bloquant à chaque ouverture de « Profil ».

#### FR-35: Récupération du compte et changement de numéro
L'utilisateur qui a perdu son numéro récupère son compte par son email vérifié et le rattache à un nouveau numéro.

**Consequences (testable):**
- Le changement de numéro prend effet après un délai de sécurité de 24 à 48 heures (valeur : Open Question 14) ; pendant ce délai, une alerte part vers l'ancien numéro et vers l'email, avec un lien d'annulation en un geste.
- Les droits actifs et les données synchronisées suivent le compte, pas le numéro.

#### FR-36: Mes appareils et limite d'appareils
L'utilisateur voit la liste des appareils rattachés à son compte et peut en retirer un à distance.

**Consequences (testable):**
- Chaque session de navigateur compte comme un appareil.
- Le rattachement d'un nouvel appareil exige un code envoyé au numéro du compte, ou l'approbation d'un appareil déjà connecté (FR-37). Il déclenche une alerte par SMS au numéro du compte et une mention dans « Mes appareils » à la prochaine ouverture (pas de notification push, §6.2).
- Au-delà de la limite du palier (Open Question 14), le nouvel appareil est **bloqué** — aucun appareil existant n'est déconnecté — et l'écran propose l'offre Duo ou de retirer un appareil.
- Après la vérification du code, l'appareil bloqué peut ouvrir « Mes appareils » dans un mode restreint : il voit la liste et retire **un seul** appareil, sans accès à aucun autre écran ni contenu, pendant une durée courte. Il doit ensuite se connecter à nouveau pour ouvrir une session. Le retrait déclenche les mêmes alertes qu'un retrait ordinaire.

#### FR-37: Appairage par QR code
Depuis la web app, l'utilisateur rattache son ordinateur à son compte en scannant un QR code avec l'app de son téléphone, déjà connectée.

**Consequences (testable):**
- Le QR code expire après 2 minutes et ne sert qu'une fois ; le téléphone affiche le navigateur concerné et demande une approbation explicite.
- L'appareil rattaché compte dans la limite d'appareils (FR-36).
- La web app accepte aussi la connexion par code (FR-31), pour un utilisateur qui n'a pas son téléphone en main.

#### FR-38: Synchronisation entre appareils
Les courses suivies, les réglages du moteur et les pronostics retenus d'un utilisateur se retrouvent sur tous ses appareils.

**Consequences (testable):**
- L'application mobile reste utilisable hors ligne (FR-13) ; les changements faits hors ligne sont envoyés au retour du réseau.
- Un pronostic retenu figé au départ (FR-28) n'est plus modifiable sur aucun appareil. La version qui l'emporte est la dernière reçue par le serveur avant l'heure de départ ; une version reçue après le départ est refusée et l'appareil affiche la version figée.
- Aucune fonctionnalité n'existe seulement dans la web app.

### 4.13 Licences, paliers et paiement

**Description :** Le palier de l'utilisateur détermine ce qu'il voit ; il l'achète par Mobile Money, en pass ou en abonnement. Réalise UJ-5.

#### FR-39: Paliers et contenu
Le contenu accessible dépend du palier actif (§10) : Gratuit, Turfiste, Expert.

**Consequences (testable):**
- Le serveur ne renvoie jamais une donnée que le palier n'autorise pas (ex. instantané H-10 pour un compte Turfiste) : un champ interdit est absent de la réponse, pas masqué par l'app.
- Un droit expiré ramène le compte au palier Gratuit sans perte de ses données synchronisées.
- L'accès aux exigences suit cette matrice `[ASSUMPTION: arbitrage du PM à la mise à jour du 2026-11-15, à confirmer par le porteur de projet]` :

| Exigences | Gratuit | Turfiste | Expert |
|---|---|---|---|
| FR-1, FR-4 (programme, partants) ; FR-51 (pronostic du matin, consultation) | oui | oui | oui |
| FR-2, FR-3, FR-5, FR-6 (configurer, importer, éditer) ; FR-7, FR-8 (calcul local) ; FR-13 à FR-15 (hors ligne) | non | oui | oui |
| FR-9, FR-10 (value, mise Kelly) ; historique complet des chevaux | non | oui | oui |
| FR-52 : instantanés H-60, H-30, H-15 | aperçu (FR-40) | oui | oui |
| FR-52 : instantané H-10 | aperçu (FR-40) | aperçu (FR-40) | oui |
| FR-11, FR-12 (les 10 types de combinaisons) | non | non | oui |
| FR-20 : bankroll et fraction de Kelly | non | oui | oui |
| FR-20 : autres coefficients du moteur (moteur expert) ; FR-53 mode expert | non | non | oui |
| FR-18, FR-19 (import photo) | non (quota 0) | quota | quota plus élevé |
| FR-21 (export) | non | oui | oui |
| FR-22 à FR-30 (Multi) | non | non | oui |
| §4.12 (compte, appareils), FR-41 à FR-43 (offres) | oui | oui | oui |

#### FR-40: Aperçu pour le palier Gratuit
Un compte Gratuit voit, sur une course, qu'un instantané plus récent a changé le classement, sans voir le classement lui-même.

**Consequences (testable):**
- L'aperçu dit seulement combien de chevaux ont changé de rang, à quel instantané, et quel palier débloque cet instantané ; aucun nom, dossard ni probabilité de l'instantané n'est transmis.
- L'aperçu existe aussi pour un compte Turfiste, sur l'instantané H-10.

#### FR-41: Offres
L'utilisateur choisit une offre : pass journée (Expert pendant 24 h), pass semaine (Turfiste ou Expert), abonnement mensuel (Turfiste ou Expert), offre Duo.

**Consequences (testable):**
- Les prix et durées sont des données de configuration, modifiables sans nouvelle version de l'app.
- L'écran des offres porte le rappel de jeu responsable et ne promet aucun gain.
- Chaque offre dit ce qu'elle débloque, en termes de l'écran où l'utilisateur l'a découverte (ex. « débloque l'instantané H-10 »).

#### FR-42: Paiement par Mobile Money
L'utilisateur paie par MTN MoMo ou Orange Money depuis l'app, via un agrégateur.

**Consequences (testable):**
- Un droit n'est activé que par la notification signée de l'agrégateur, vérifiée par le serveur puis confirmée par une requête de statut ; jamais par l'app.
- Une même transaction n'active jamais deux droits (traitement idempotent sur sa référence).
- Tant que le paiement n'est pas confirmé, l'écran affiche « Paiement en attente de confirmation » ; un échec n'active rien et le dit.
- Une confirmation tardive active le droit ; l'app l'affiche à sa prochaine requête, sans redémarrage.

#### FR-43: Offre Duo
Le titulaire d'une offre Duo invite 1 ou 2 personnes (nombre : Open Question 13), qui ont chacune leur propre compte et leurs propres appareils.

**Consequences (testable):**
- Le Duo existe pour chaque palier payant et chaque durée d'offre ; chaque membre bénéficie du droit du titulaire (palier et dates), avec la limite d'appareils de ce palier ; aucun droit propre n'est créé pour un membre (architecture AD-18). Un membre qui a aussi son propre droit garde le palier le plus élevé des deux. `[ASSUMPTION: arbitrage du PM à la mise à jour du 2026-11-15, à confirmer par le porteur de projet]`
- Le titulaire peut retirer un membre ; le membre retiré revient au palier Gratuit.
- À l'expiration du droit du titulaire, tous les membres reviennent au palier Gratuit.

#### FR-44: Droits disponibles hors ligne
Sur l'application mobile, les fonctionnalités calculées sur l'appareil restent accessibles hors ligne pendant la durée du droit déjà acquis.

**Consequences (testable):**
- L'app conserve une preuve de droit signée par le serveur, avec sa date de fin ; hors ligne, elle s'y fie jusqu'à cette date, jamais au-delà.
- Après la date de fin, les données en cache restent consultables au niveau du palier Gratuit ; le contenu payant en cache (instantanés, value, mise Kelly, combinaisons, Multi) est masqué jusqu'à un nouveau droit.

#### FR-45: Quota d'import photo par palier
Chaque palier dispose d'un quota d'imports photo par période (valeurs : Open Question 14), en plus de la limite journalière globale (§9.4).

**Consequences (testable):**
- Le compteur restant est visible avant l'import ; un quota épuisé est dit clairement, sans appel au fournisseur de vision.

#### FR-46: Protection des écrans payants
Les captures et enregistrements d'écran sont bloqués sur les écrans qui affichent un contenu payant (Android).

**Consequences (testable):**
- Écrans protégés : Résultats (instantanés, value, mise Kelly), combinaisons, Multi et ses grilles.
- Sur un écran protégé, une capture ou un enregistrement produit une image noire.
- La web app ne peut pas bénéficier de cette protection ; c'est assumé (défense par le temps et la personnalisation, §10). Sur iOS, la détection de capture vient en V1.1.
- L'export texte (FR-21) et la copie des grilles (FR-25) restent possibles : ils portent l'identifiant court du compte. `[ASSUMPTION: arbitrage du PM à la mise à jour du 2026-11-15, à confirmer par le porteur de projet]`

### 4.14 Back-office — contrôle des accès internes

**Description :** Les agents de saisie, superviseurs et administrateurs travaillent dans un back-office séparé de l'application, avec des droits limités et tracés. Les fonctionnalités de saisie elles-mêmes relèvent du brief back-office du 2026-10-18 ; cette section fixe le cadre d'accès.

#### FR-47: Accès séparé et double authentification
Le back-office est servi sur une adresse distincte de l'application ; chaque membre du personnel s'y connecte avec une double authentification obligatoire.

**Consequences (testable):**
- Sans second facteur configuré, aucun accès.
- Le back-office est une application web distincte, réservée au personnel (Flutter Web, sur ordinateur) : aucun écran du back-office n'existe dans l'application mobile ni dans la web app compagnon. Il permet de se connecter avec le second facteur, de consulter le tableau de bord, de saisir, soumettre et valider des corrections (FR-49), de créer et révoquer des licences manuelles (FR-50), de gérer les offres et le personnel (administrateur) et de lire le journal d'audit.

#### FR-48: Rôles
Trois rôles : **agent** (saisie, ne voit que ses propres saisies, aucun accès aux pronostics ni aux droits), **superviseur** (valide les modifications), **administrateur** (gère les droits et les licences manuelles).

**Consequences (testable):**
- Une tentative d'accès d'un agent aux pronostics ou aux droits est refusée et journalisée.

#### FR-49: Validation avant application
Toute modification saisie par un agent reste en attente jusqu'à la validation d'un superviseur ; elle n'entre dans aucun calcul avant.

**Consequences (testable):**
- Un agent ne peut rien valider, et personne ne valide sa propre saisie.

#### FR-50: Licence manuelle et journal d'audit
Seul un administrateur crée une licence hors paiement (geste commercial), avec un motif obligatoire et la validation d'un second administrateur. Chaque création, modification, validation et licence manuelle est inscrite dans un journal en ajout seul, dont toute altération est détectable (chaînage), y compris par un administrateur.

**Consequences (testable):**
- Chaque jour, un rapprochement liste tout droit actif sans paiement confirmé ni licence manuelle validée ; l'objectif est zéro (SM-5).

### 4.15 Pronostics publiés et instantanés de cotes

**Description :** Le contenu que les paliers vendent : chaque jour, le serveur publie pour chaque course un pronostic de référence, puis le recalcule à chaque instantané de cotes. Réalise UJ-1, UJ-5, UJ-6.

#### FR-51: Pronostic du matin
Chaque matin, à heure fixe, le serveur publie pour chaque course française du jour le pronostic du modèle de référence : probabilité de victoire et rang de chaque partant.

**Consequences (testable):**
- Le pronostic porte la version du modèle, l'heure des données utilisées et la mention « modèle en cours d'évaluation » tant que le modèle de référence n'est pas confirmé sur pronostics en direct (AD-14).
- Il est publié avant la première course de la journée ; une course pour laquelle il n'a pas pu être calculé l'indique (« pronostic indisponible »), sans valeur inventée.
- Il est journalisé avant le départ et n'est jamais réécrit (mesure SM-1).

#### FR-52: Instantanés de cotes
À H-60, H-30, H-15 et H-10 avant le départ, le serveur relève les cotes et publie le pronostic recalculé sur ces cotes.

**Consequences (testable):**
- L'app reçoit l'instantané le plus récent autorisé par le palier à l'ouverture de la course et à chaque rafraîchissement explicite ; il n'y a pas d'envoi automatique en arrière-plan (FR-14).
- Chaque instantané affiche son heure ; s'il manque (source indisponible, cote absente), l'écran montre le dernier instantané disponible avec son heure, jamais une valeur inventée.
- Un instantané publié n'est jamais réécrit.

#### FR-53: Pronostic publié et calcul local
Le pronostic publié est ce que l'utilisateur voit par défaut ; le moteur de scoring réglable (§4.3) reste disponible comme mode expert.

**Consequences (testable):**
- Les probabilités du mode expert sont toujours étiquetées comme telles ; les deux ne sont jamais mélangées sans le dire.
- Value, mise Kelly, combinaisons et Multi se calculent sur l'appareil à partir du jeu de probabilités actif (publié ou expert).
- Une course sans pronostic publié (import photo, saisie manuelle, course non ingérée, ou course du lendemain consultée avant la publication du matin) se calcule avec le moteur de scoring, et l'écran le dit. Pour le palier Gratuit, qui n'a pas de calcul local, l'écran indique l'heure de publication du pronostic du matin.

## 5. Non-Goals (Explicit)

- Aucune fonctionnalité de placement de pari automatisé, sur aucun canal (PMU, Genybet...), à aucune version future. Le produit calcule et informe, il n'agit jamais sur un compte de jeu.
- Pas de couverture des courses hors France (pas de courses camerounaises du PMUC, pas de courses internationales) — le moteur et les échelles terrain/niveau sont calibrés sur les conventions françaises. Les utilisateurs, eux, sont au Cameroun au lancement (§2.2).
- Pas d'historique de presse/consensus intégré au score — si réintroduit un jour, affiché à part, jamais mélangé au calcul.
- Le produit ne prétend jamais à une fiabilité garantie : aucun écran de résultats sans le rappel que le jeu comporte des risques.
- Le module Multi est un pronostic : il n'affiche ni mise, ni coût, ni gain, ni rapport, ne demande aucun budget et ne dit jamais s'il faut jouer. Ce que l'utilisateur mise reste hors de l'outil.
- La méthode 2 du document source Multi (citations de presse) n'entre ni dans la recommandation ni dans le MVP ; si elle est réintroduite un jour, ce sera comme comparateur affiché à part, conformément au non-goal presse ci-dessus.
- L'application n'encaisse, ne transmet ni ne conserve aucune mise. Le paiement porte uniquement sur l'accès à l'outil (§10).
- Aucune fonctionnalité réservée à la web app : l'application mobile est le produit complet.
- Exclusions différées (notifications push, iOS, offre Club…) : voir §6.2 pour le détail.

## 6. MVP Scope

### 6.1 In Scope

- Backend FastAPI : ingestion quotidienne PMU (plat, trot, obstacle, France), moteur de calcul complet (§4.3-4.5), endpoints `/courses`, `/courses/{id}/partants`, `/courses/{id}/importer`, `/analyse`, `/extraction/fiche`, `/extraction/programme`.
- App mobile Flutter, Android : tous les écrans du cahier mobile §7 (accueil, configuration course, liste partants, fiche cheval, import photo, résultats, réglages) et ceux de §4.12-§4.13 (connexion, code PIN, profil, Mes appareils, offres, paiement), moteur dupliqué en Dart, cache SQLite, fonctionnement hors ligne pour le calcul (§4.6).
- Web app Flutter compagnon, sans cache hors ligne, sans fonctionnalité propre (§4.12, FR-38).
- Export/partage du classement calculé (texte ou JSON au minimum ; export PDF en bonus, pas requis).
- Module Multi (§4.11), livré **après le cœur du MVP déjà construit** (§4.1 à §4.10), en deux incréments. Arbitrage assumé : le module Multi pèse à lui seul autant que le reste du MVP ; il ne retarde pas ce qui est livré, et le premier incrément rend le module utile avant que l'évaluation existe.
  - **Incrément Multi 1 — pronostiquer** : vérification des règles du pari (§9.5), écran Multi, pronostic du modèle à la taille choisie, bases (« chevaux les plus probables »), systèmes vérifiés et catalogue précalculé, indice de confiance en « seuils provisoires », explications, choix de l'utilisateur, calcul hors ligne, pronostic retenu et débrief sur l'appareil ; endpoints `GET /multi/courses/{cle_course}` (contexte Multi, non-partants et arrivée d'une course désignée par sa clé PMU `AAAAMMJJ-Rn-Cn`), `POST /multi/courses/{cle_course}/rafraichir` (relecture des partants et des cotes, avant le départ seulement), `/multi/recommandation`, `/multi/systemes`, `/multi/verifier`, `/multi/evaluer` (noms de routes indicatifs, l'architecture fait foi, AD-12).
  - **Incrément Multi 2 — évaluer** : comparateurs, harnais de backtest et pilote (qui fixe les seuils par défaut de l'indice de confiance, les tailles de référence et l'effectif minimal d'affichage), exécutés d'abord sur la machine de développement avec import des résultats en production, puis journalisation quotidienne avant départ ; endpoints `/multi/comparateur`, `/multi/performance`. L'endpoint `/multi/backtest` n'est construit que lorsque le harnais passe sur un serveur. Ordre imposé : backtest et pilote → seuils et tailles de référence → journalisation quotidienne. Seule l'arrivée officielle (avec ex-aequo) est nécessaire ; aucun rapport Multi n'est ingéré.
- Rappel de jeu responsable visible sur chaque écran de résultats.
- Lancement payant au Cameroun : comptes et appareils (§4.12), licences, paliers et paiement Mobile Money (§4.13), contrôle d'accès du back-office (§4.14), pronostics publiés (§4.15), fondations de sécurité (§8).
- **Conditions de mise en vente** : avis juridique favorable (§9.2) ; exigences de lancement de §4.12 à §4.15 livrées ; application acceptée par le Play Store (OQ 18) ; conditions générales d'utilisation et de vente et politique de confidentialité publiées. L'inscription (FR-31) exige leur acceptation, dans leur version en vigueur.

### 6.2 Out of Scope for MVP

- **V1.1** : version iOS ; contrôle d'intégrité de l'app (Play Integrity : le serveur refuse les sessions d'une app modifiée) ; déverrouillage biométrique ; filigrane visible portant l'identifiant du compte ; détection d'usages anormaux (même compte simultanément dans deux villes, rotation d'appareils) ; preuves de récupération complémentaires (référence d'un paiement Mobile Money passé, codes de secours) ; épinglage du certificat dans l'app ; contrôle des saisies du back-office contre la source PMU.
- **Plus tard** : offre Club (revente par un tiers, comptes organisation à sièges — le modèle de données accueille les organisations dès le lancement, voir l'architecture) ; programme d'affiliation pour les administrateurs de groupes WhatsApp ; filigrane invisible ; paiement intégré aux stores pour l'international ; ouverture à d'autres pays d'Afrique.
- **Exclu** : applications de bureau (Windows, macOS, Linux) ; édition ou validation de tickets de pari.
- Segment cercles/professionnels avec relation commerciale dédiée — phase 2 explicite, hors réflexion produit de ce PRD.
- Notifications push, rappels d'heure de départ.
- Historique de presse/consensus intégré au produit (affiché à part si réintroduit un jour, jamais mélangé au calcul — voir aussi §5).
- Backfill historique antérieur à 2004 au-delà de ce que `open-pmu-api` fournit déjà — pas un chantier V1 dédié.
- Module Multi : méthode 2 et import du consensus presse ; systèmes mixtes (tickets de 5 et 6) ; choix du système parmi les systèmes équivalents selon la valeur ; Flexi ; **Mini Multi** (à réétudier après la vérification de ses règles, story 5.1 — décision D quater du 2026-10-18).
- Module Multi — tout ce qui touche à l'argent, retiré par le recadrage du 2026-10-18 : budget, coût, multiplicateur, mise, gain, seuil de rentabilité, indice de valeur ; ingestion et affichage des rapports Multi ; évaluation financière du Multi.
- Affichage de l'application en anglais : le MVP est en français ; l'anglais, au choix de l'utilisateur, vient après le MVP pour toute l'application (§8). Décision du porteur de projet (2026-10-17).

## 7. Success Metrics

*Le critère primaire mesure la qualité du modèle, pas le succès commercial — cohérent avec un choix explicite du porteur de projet (brief §5) : un ROI positif sur peu de courses est peu fiable (variance élevée), la calibration est mesurable plus tôt et plus honnêtement.*

**Primary**
- **SM-1** : Calibration du modèle — sur un échantillon d'au moins quelques centaines de courses avec résultat connu, la calibration (les chevaux annoncés à X % de chances gagnent-ils environ X fois sur cent ?) doit être mesurablement meilleure que celle de la probabilité implicite du marché (`1/cote`), mesurée par score de Brier ou courbe de calibration par tranches. Valide FR-7, FR-8. En dessous de quelques centaines de courses, aucune conclusion n'est tirée dans un sens ou dans l'autre — pas de seuil chiffré fixé avant d'avoir ce volume. **Portée explicite** : SM-1 compare le modèle au marché (1/cote), pas au jugement des pronostiqueurs experts des sites concurrents — un SM-1 positif ne doit jamais être présenté comme une preuve de supériorité sur l'expertise humaine, question qui reste et restera non mesurée (§1 Vision, limite assumée).
- **SM-4** (module Multi) : Calibration de la probabilité de couverture du Multi (FR-23, FR-30) — même logique que SM-1 : score de Brier et courbe par tranches sur les courses de ≥ 14 partants, comparée à la même quantité calculée à partir des cotes du marché. Complétée par la différence appariée, **à taille de sélection égale**, du nombre de chevaux capturés entre la recommandation du modèle et le comparateur marché, avec son intervalle de confiance. Aucun seuil chiffré fixé avant le pilote (cahier Multi §8). Conditionne le retrait de la mention « modèle en cours d'évaluation ». La qualité de l'indice de confiance (FR-26) découle directement de cette calibration et n'a pas de métrique propre. Aucune métrique financière n'existe pour le Multi.

**Secondary**
- **SM-2** : ROI simulé sur les paris à value détectée (FR-9) — présenté uniquement couplé à sa taille d'échantillon, jamais comme preuve isolée. Directionnel seulement, pas un objectif à optimiser en soi.
- **SM-3** : Proportion des mises que l'utilisateur place effectivement sur des chevaux signalés "value" par le modèle (FR-9), suivie dans le temps — un changement de comportement mesurable, pas une simple fréquence d'usage. Un utilisateur qui continue à jouer ses habitudes malgré le signal de l'outil n'est pas un succès, même s'il revient chaque dimanche.
- **SM-6** : Conversion du palier Gratuit vers un palier payant, par offre — directionnel. Contrepartie : SM-C4.

**Garde-fou d'exploitation**
- **SM-5** : Droits actifs sans paiement confirmé ni licence manuelle validée, mesurés chaque jour par le rapprochement (FR-50) — cible : zéro. Tout écart est une anomalie à expliquer.

**Counter-metrics (do not optimize)**
- **SM-C1** : Fréquence d'usage / rétention brute (revient chaque semaine) — explicitement écartée comme indicateur de succès à elle seule (contrepartie de SM-3, brief §5) : un usage fréquent sans changement de comportement de mise n'est pas un signal positif.
- **SM-C2** : Volume de mises suggérées ou de value détectée — ne doit jamais être optimisé pour lui-même. Un modèle qui signale de la "value" plus souvent n'est pas meilleur ; seule la calibration (SM-1) juge la qualité réelle. Contrepartie de SM-1 et SM-2 : empêche d'ajuster le moteur pour produire plus de signaux plutôt que des signaux plus justes.
- **SM-C3** : Fréquence des pronostics Multi en « confiance élevée » — ne jamais régler les seuils de l'indice de confiance pour en produire davantage. Seule la calibration de la probabilité de couverture (SM-4), qui fonde l'indice, juge la qualité de celui-ci. Contrepartie de SM-4.
- **SM-C4** : Agressivité de l'aperçu et des relances — ne jamais augmenter la conversion par une promesse de gain, une urgence artificielle ou un message contraire au rappel de jeu responsable (§5). Contrepartie de SM-6.

## 8. Cross-Cutting NFRs

- **Parité fonctionnelle backend/mobile** : le moteur de calcul (scoring, probabilités, value, combinaisons) produit des résultats identiques à epsilon près entre l'implémentation Python (backend) et Dart (mobile), vérifié par les mêmes cas de test portés dans les deux langages (cahier backend §9, cahier mobile §5.2/§9).
- **Performance du calcul local** : le recalcul complet (score → probabilités → combinaisons, y compris la simulation Monte-Carlo à 20 000 tirages) et le pronostic Multi (sélection, bases, systèmes, indice de confiance) s'exécutent sur l'appareil mobile en un temps perçu comme instantané par l'utilisateur (pas de seuil chiffré fixé à ce stade — `[OPEN QUESTION]`, voir §11).
- **Disponibilité du calcul hors ligne** : non négociable une fois les données d'une course en cache (§4.6) — c'est une contrainte transverse, pas une fonctionnalité optionnelle.
- **Reproductibilité** : à jeu de données et paramètres identiques, le classement produit est identique à celui du prototype `analyse_hippique_v2.html` sur le même jeu d'entrée (critère d'acceptation explicite, cahier mobile §11).
- **Préparation à l'affichage multilingue** : l'application du MVP est en français ; l'anglais vient après le MVP (§6.2). Dès le MVP, le moteur produit ses nouveaux textes (explications et raisons du Multi, FR-27) sous forme de codes et de valeurs que l'application met en forme, jamais sous forme de phrases figées dans le moteur ou l'API, pour que l'ajout de l'anglais n'oblige pas à reprendre le moteur. Les libellés de transparence de FR-4 et l'extraction par photo restent en français.
- **Aucune clé API tierce embarquée côté client** : le principe s'applique à toute intégration future d'un fournisseur externe (vision IA aujourd'hui, tout autre service demain), pas seulement à l'extraction actuelle.
- **Le serveur seul décide des droits** : chaque route vérifie la session et le droit actif ; une application modifiée ne débloque aucune donnée réservée.
- **Transport chiffré** : HTTPS partout ; CORS limité au domaine de la web app et du back-office ; débit limité par compte et par adresse IP.
- **Minimisation des données** : aucun numéro de carte ni code PIN côté serveur ; comptes et paiements séparés des données de courses ; sauvegardes chiffrées.
- **Aucun secret dans les binaires** : la règle ci-dessus couvre aussi l'agrégateur de paiement et le fournisseur de codes SMS, dans l'APK comme dans la web app.
- **Données personnelles** : conformité à la loi camerounaise applicable (périmètre exact : §9.2).

## 9. Constraints and Guardrails

### 9.1 Périmètre V1 — décision de cadrage (révisée le 2026-11-15)

**V1 est un service payant, avec comptes, authentification et paiement.** Décision du porteur de projet du 2026-11-15 (`brainstorm-intent.md`) : le service n'est pas gratuit, il faut une licence d'utilisation, donc des comptes. Elle remplace la décision précédente (« mono-utilisateur, sans compte, sans authentification et sans paiement »), qui avait tranché en faveur des cahiers techniques contre le modèle freemium du brief ; le brief l'emporte désormais sur ce point. Les cahiers techniques restent la référence pour le moteur, l'ingestion et l'application, hors comptes et facturation. `[ASSUMPTION: confirmé explicitement par le porteur de projet le 2026-11-15.]`

### 9.2 Réglementaire — jeux d'argent (Cameroun)

Le porteur de projet est basé au Cameroun, régi par la loi n°2015/012 du 16 juillet 2015 et son décret d'application n°2019/2300/PM du 18 juillet 2019 (licences délivrées par le MINAT). Cette lecture cible structurellement les *opérateurs* qui collectent des mises ou détiennent une concession — mais **aucune source primaire ou juridique trouvée, ni par le porteur de projet ni par la recherche de marché menée pour ce PRD, ne confirme explicitement si un outil d'analyse qui ne collecte jamais de mise entre dans le champ d'application.** Le produit pointe en outre vers des courses françaises (PMU) plutôt que camerounaises (PMUC), une situation inédite dont aucun précédent directement transposable n'a été trouvé.

**Prérequis bloquant pour la mise en vente** (pas pour le développement) : une consultation juridique locale doit confirmer, avant toute vente, (1) si un outil d'analyse payant qui ne collecte aucune mise entre dans le champ de la loi n°2015/012, et la position du PMUC ; (2) les obligations de la loi camerounaise sur les données personnelles (déclaration, consentement, conservation) ; (3) le risque lié à la revente d'un service fondé sur des données PMU non autorisées (§9.3). Elle est à refaire pour chaque nouveau pays.

### 9.3 Dépendance à une source de données non autorisée

Aucune des deux sources de données identifiées n'est autorisée par le PMU :
- L'API technique `turfinfo.api.pmu.fr` est non officielle, non documentée, sans accord écrit (une demande d'autorisation posée sur le forum officiel du PMU n'a jamais reçu de réponse claire). Un accès légitime et documenté existe via l'infocentre du PMU, mais sous forme de contrat payant à plusieurs dizaines de milliers d'euros par an — réservé aux professionnels, hors de portée d'un projet bootstrap, ce qui explique le recours à la source non officielle plutôt qu'un simple choix de facilité.
- `open-pmu-api`, utilisée pour le backfill historique, est elle-même construite sur les mêmes données non officielles.

La recherche de marché confirme un durcissement des mécanismes anti-bot du PMU depuis fin 2024 (blocages IP temporaires signalés en cas de requêtes trop fréquentes) et l'absence de précédent de poursuite légale documenté contre un projet tiers — une zone grise tolérée, pas une garantie de non-poursuite.

**Conséquence produit directe** : le pattern adaptateur isolant l'accès PMU (FR-16) n'est pas une préférence d'architecture, c'est une exigence de résilience produit — en cas de coupure, seul ce module doit changer, et le repli par extraction d'image (§4.8) doit rester pleinement fonctionnel en continuité de service, même s'il est nettement plus lent (saisie manuelle par course plutôt que préremplissage automatique).

**Effet de la monétisation (2026-11-15)** : vendre un service construit sur une source non autorisée aggrave le risque décrit ici — un usage commercial est plus visible et plus difficile à défendre qu'un usage personnel. Le volet (2) du jalon de bascule (§10), une source de données légitime, n'est pas atteint. Le porteur de projet décide de lancer quand même, sous réserve d'un avis juridique favorable (§9.2) — décision D-1 du 2026-11-15.

### 9.4 Coût du repli vision

L'extraction par image (§4.8) appelle un fournisseur de vision IA payant à l'usage. Une limite journalière globale d'appels protège ce budget (architecture AD-3) ; sa valeur, comme le budget lui-même, reste ouverte — `[OPEN QUESTION]`, voir §11 (OQ 4).

### 9.5 Règles du Multi — prérequis bloquant

Les règles du pari Multi (formules, tickets, tickets physiques, courses sur lesquelles le Multi est proposé, seuil éventuel de partants déclarés, non-partants, ex-aequo, arrivée dégradée, statut du Mini Multi) viennent d'un document PMU de 2001-2002. Elles restent nécessaires même sans argent : elles déterminent les formules, les grilles, la requalification des tickets et le débrief. **Aucune story de développement du module Multi ne démarre avant que ces règles aient été vérifiées sur pmu.fr et datées** dans le module de règles (FR-22) ; sans cette date, aucune grille n'est affichée. Si elles ont changé, le catalogue de systèmes, les grilles et les chiffres de UJ-4 changent aussi. Le prix unitaire n'est plus affiché ; il n'est conservé dans le module de règles que comme provenance.

## 10. Monétisation (décidée le 2026-11-15)

| Palier | Contenu |
|---|---|
| **Gratuit** | Pronostic du matin, consultation seule ; aperçu « le classement a changé à H-10 » (FR-40) |
| **Turfiste** | + instantanés H-60, H-30 et H-15, value, mise Kelly, historique complet, quota d'import photo |
| **Expert** | + instantané H-10, combinaisons sur les 10 types de paris, moteur expert réglable, Multi (dès qu'il est livré : le lancement ne l'attend pas, décision D-2), quota d'import photo plus élevé |

- **Offres** : pass journée (Expert pendant 24 h), pass semaine (Turfiste ou Expert), abonnement mensuel (Turfiste ou Expert), offre Duo (2 ou 3 personnes, pour chaque palier payant). Offre Club : plus tard (§6.2). Détail par exigence : matrice de FR-39.
- **Paiement** : Mobile Money (MTN MoMo, Orange Money) via un seul agrégateur, en dehors du système de paiement des stores. Paiement intégré aux stores : plus tard, pour l'international.
- **Principe conservé** : la coupure porte sur l'actionnable et sur la fraîcheur des cotes ; l'instantané H-10, le plus proche du départ, est réservé à l'Expert. C'est aussi la défense contre la revente : une copie du pronostic perd sa valeur quand les cotes bougent.
- **Fonctionnalités calculées sur l'appareil** (mise Kelly, combinaisons, moteur expert, Multi) : verrouillées sur l'appareil par une preuve de droit signée par le serveur ; le risque d'une application modifiée qui les débloquerait est jugé faible et accepté (décision D-5), avec un contrôle d'intégrité de l'app en V1.1 (§6.2). Les données produites par le serveur (instantanés, probabilités de référence) restent filtrées par le serveur (§8).
- **Jalon de bascule revu** : (1) la calibration — le modèle combiné bat le marché (cotes H-30) hors échantillon : écart de log-loss −0,016, intervalle de confiance à 95 % [−0,020 ; −0,012] (`ml/runs/2026-11-10-combine-r1/report.md`). Ce critère porte sur le modèle de référence (FR-51), pas sur le moteur §4.3 mesuré par SM-1 ; la confirmation sur pronostics en direct est en cours (architecture AD-14). **Face aux cotes de clôture, le marché reste meilleur** (log-loss 1,924 contre 1,983, sur des ensembles de courses proches mais non identiques) ; or le critère d'activation d'AD-14 est la clôture : il n'est donc pas atteint, et l'argument commercial ne peut pas dire « bat le marché » sans préciser « à H-30 » (SM-C4) ; (2) la source de données légitime — **non atteinte** ; le porteur de projet décide de lancer en assumant ce risque, après un avis juridique favorable (§9.2, décision D-1).
- **Comparables identifiés** (conservé) : EquinEdge (US, IA de handicapping, probabilité par cheval, 39,95 $/mois) est le positionnement le plus proche ; aucun comparable identifié n'intègre de calculateur Kelly en hippisme.
- **Structuration** (conservé) : la dépendance à une source de données non autorisée (§9.3) grandit avec la traction du produit — plus d'utilisateurs signifie mécaniquement plus de requêtes, plus de visibilité, plus de probabilité d'être bloqué. Ce raisonnement s'applique désormais au lancement payant : développement solo ou très petite équipe, pas de levée de fonds avant que ce risque soit réduit.

## 11. Open Questions

1. Seuil de performance perçu comme "instantané" pour le recalcul local sur mobile (§8) — à définir une fois un premier appareil cible identifié.
2. ~~Format tarifaire.~~ **Close le 2026-11-15** : structure décidée (§10) ; prix ouverts (OQ 13).
3. Consultation juridique camerounaise (§9.2, trois volets : champ de la loi n°2015/012 et position du PMUC, données personnelles, revente d'un service fondé sur des données PMU non autorisées) — prérequis de mise en vente.
4. Budget/seuil de coût acceptable pour les appels au fournisseur de vision IA (§9.4).
5. Méthode de dérivation du niveau de course depuis l'allocation PMU (cahier backend §7.2) — calibration par quantiles proposée mais à valider sur un premier jeu de données réel, avant d'être considérée fiable.
6. Fréquence et volume d'ingestion quotidienne raisonnables pour ne pas solliciter excessivement une source non officielle (§9.3) — à décider avant d'automatiser le job d'ingestion. *Volet Multi décidé le 2026-10-18 : pas de relecture périodique des partants ; au plus une relecture par course éligible et par jour avant la journalisation, et des relectures à la demande limitées à une toutes les 5 minutes par course, avant le départ seulement.* `[ASSUMPTION: défaut de la correction de cap du 2026-10-18, approuvé le 2026-11-15]`
7. Gestion des homonymes de chevaux (le nom normalisé est la seule clé de rapprochement inter-courses, `numPmu` n'étant pas stable) — accepter le risque documenté ou ajouter un critère de désambiguïsation si un cas réel se présente.
8. Règles du Multi (formules, tickets, courses où le Multi est proposé, seuil éventuel de partants, non-partants, ex-aequo, arrivée dégradée, statut du Mini Multi) : la source date de 2001-2002 — **prérequis bloquant** pour le développement du module Multi (§9.5). Les coefficients de rapport et rapports minimums ne sont plus nécessaires (recadrage du 2026-10-18).
9. ~~Emplacement du marqueur « course support » dans la source PMU.~~ **Close le 2026-10-18** : l'éligibilité se lit dans la liste des paris de la course (`paris[].typePari` contient `MULTI`), plus de course support unique ni de mode « exploration » (D quater). *Volet « rapports Multi définitifs » clos le 2026-10-18 : rapports hors périmètre, seule l'arrivée officielle sert.*
10. Valeurs par défaut des seuils de l'indice de confiance Multi (FR-26), qui dépendent de la taille de la sélection — fixées par le pilote d'évaluation (cahier Multi §8.4), affichées « provisoires » jusque-là. **Provisoire décidé le 2026-10-18 (D quater)** : règle « hasard + plancher » de FR-26, remplacée par le pilote. *Libellés « élevée / moyenne / faible » et seuils par taille confirmés par le porteur de projet le 2026-10-18.*
11. Calendrier de l'affichage en anglais après le MVP (§8).
12. Mesure de SM-3 (mises effectivement placées sur des chevaux « value ») : aucune exigence ne capte aujourd'hui les paris placés (aucun lien avec un compte de jeu). Un journal déclaratif, s'il est synchronisé (FR-38), devra respecter §5 (aucune mise conservée côté serveur) et §9.2 (données personnelles). Piste : un journal déclaratif local, sur le modèle du pronostic retenu du Multi (FR-28) — qui, lui, ne capte aucune mise. À trancher avant de pouvoir mesurer SM-3 ; pas un blocage pour le MVP.
13. Prix de chaque offre et du Duo ; nombre de places du Duo (2 ou 3) ; confirmation de la matrice d'accès de FR-39 et des règles du Duo (FR-43).
14. Limite d'appareils par palier, délai d'inactivité avant verrouillage, délai de sécurité du changement de numéro (24 ou 48 h), quotas d'import photo par palier et période de ces quotas (jour, semaine ou mois), délai d'inactivité au bout duquel un navigateur est retiré de « Mes appareils » (`WEB_APPAREIL_INACTIF_JOURS`), délai de sécurité après le rattachement d'un nouvel appareil (`NOUVEL_APPAREIL_DELAI_HEURES`), seuils de limitation de débit (demandes de code, tentatives de connexion, jetons de gestion des appareils par jour : `JETONS_GESTION_APPAREILS_PAR_JOUR`), verrouillage des comptes du personnel (`PERSONNEL_ECHECS_MAX`, `PERSONNEL_VERROUILLAGE_MINUTES`). Valeurs de configuration : les stories avancent avec une valeur provisoire. Responsable : porteur de projet.
15. Choix de l'agrégateur Mobile Money (CinetPay, Campay, Notch Pay, Flutterwave…) : signature des notifications, requête de statut, remontée des remboursements et contestations.
16. Contestation d'un paiement Mobile Money après activation du droit (rétrofacturation) : parade à définir avec l'agrégateur retenu.
17. Fournisseur des codes de connexion (SMS ou WhatsApp) : coût et délivrabilité au Cameroun. Le fournisseur retenu doit aussi envoyer les SMS d'alerte transactionnels (nouvel appareil rattaché, appareil retiré, changement de numéro — FR-35, FR-36), pas seulement les codes ; sinon, un second fournisseur est nécessaire.
18. Règles du Google Play pour une app liée aux paris hippiques et pour un paiement Mobile Money hors de la facturation Google Play.
19. Fournisseur d'email : délivrabilité au Cameroun (boîtes courantes des utilisateurs), coût, domaine d'envoi, configuration SPF, DKIM et DMARC. Il bloque l'envoi réel des exigences qui passent par l'email : vérification de l'email de secours (FR-34), récupération du compte et changement de numéro (FR-35), alertes de sécurité (nouvel appareil, appareil retiré), envoi quotidien de la tête du journal d'audit au porteur de projet (FR-50). Le développement avance avec un faux client d'email ; seul l'envoi réel attend la décision. Le domaine d'envoi dépend de l'OQ 20. Responsable : porteur de projet.
20. Nom de domaine : à acheter plus tard par le porteur de projet, avant la mise en production. Un seul domaine porte trois adresses : `api.<domaine>` (application Android), `app.<domaine>` (web app compagnon) et `admin.<domaine>` (back-office, FR-47). La web app et son API partagent la même origine (`app.<domaine>`), condition du renouvellement de session web (FR-33). Les noms restent configurables ; l'enregistrement DNS et les certificats sont une tâche du porteur de projet. Responsable : porteur de projet.

## 12. Assumptions Index

- ~~§9.1 — V1 mono-utilisateur sans compte ni paiement~~ : remplacé le 2026-11-15 (voir ci-dessous).
- §6.2 — Android d'abord, iOS en V1.1 (révisé le 2026-11-15) : confirmé explicitement par le porteur de projet.
- Calendrier — pas de date de lancement fixe, rythme bootstrap : confirmé explicitement par le porteur de projet.
- §9.2 — La réglementation camerounaise cible structurellement les opérateurs de mise, pas les outils d'analyse : lecture du brief, non confirmée par une source juridique primaire (voir Open Question 3).
- ~~§10 — Modèle à l'usage/crédits pressenti~~ : remplacé le 2026-11-15 par les paliers, passes et abonnement (§10).
- §4.11 — Module Multi dans le MVP ; le modèle décide la sélection ; méthode 2 hors MVP ; 3 bases candidates : décisions D0-D7 confirmées par le porteur de projet le 2026-10-17 (`multi/reconcile-cdc-multi-prd.md`).
- §1, §4.11, §5, §6, §7 — **Recadrage du 2026-10-18 (« D ter »)** : le Multi devient un pronostic sans argent (ni budget, coût, multiplicateur, mise, gain, rapport, seuil de rentabilité ni indice de valeur) ; taille de sélection choisie par l'utilisateur ; verdict remplacé par l'indice de confiance ; rapports Multi et évaluation financière hors périmètre. Remplace D0, D3 et D5, précise D4 : décision du porteur de projet.
- FR-23 — Taille par défaut de la sélection : dernière taille utilisée, sinon 10 : confirmé par le porteur de projet le 2026-10-18.
- FR-24 — Aucune base active au premier affichage, l'utilisateur active les « chevaux les plus probables » qu'il veut : confirmé par le porteur de projet le 2026-10-18.
- FR-26 — Libellés « confiance élevée / moyenne / faible », seuils qui dépendent de la taille de la sélection, provisoires jusqu'au pilote : confirmé par le porteur de projet le 2026-10-18 (valeurs des seuils : Open Question 10).
- FR-24, FR-25, FR-27 — Bases nommées « chevaux les plus probables » ; formule affichée par défaut : Multi en 7 ; aucun badge de value dans le Multi (la value reste sur l'écran Résultats) : confirmé par le porteur de projet le 2026-10-18.
- UJ-4 — Récit du porteur de projet réécrit pour suivre D0-D7 (le récit d'origine choisissait la méthode 1 et importait la presse), puis le recadrage du 2026-10-18 (budget et coûts retirés) : arbitrage confirmé par le porteur de projet.
- §6.1 — Module Multi livré en deux incréments (décider, puis évaluer), après le cœur du MVP ; vérification des règles du pari comme prérequis bloquant (§9.5) : recommandations de la revue de finalisation, approuvées par le porteur de projet le 2026-10-17.
- §6.2, §8 — Application en français dans le MVP, anglais après : confirmé par le porteur de projet le 2026-10-17 (calendrier : Open Question 11).
- FR-30 — Débrief sur le pronostic du modèle et sur le pronostic retenu par l'utilisateur (conservé sur l'appareil) : confirmé par le porteur de projet le 2026-10-17, maintenu par le recadrage du 2026-10-18.
- FR-22, §6.2 — Éligibilité par la liste des paris PMU (plusieurs courses par jour), abandon de la course support unique et du mode exploration, Mini Multi hors périmètre : décision du porteur de projet du 2026-10-18 (D quater), après le constat F1 de la revue de préparation.
- FR-26 — Règle provisoire « hasard + plancher » des seuils de confiance : décision du porteur de projet du 2026-10-18 (D quater), en exception au principe « rien n'est inventé » du cahier Multi, jusqu'au pilote.
- FR-23, FR-28 — Non-partant retiré du champ et recalculé par le moteur de scoring ; heure de départ inconnue → pronostic remplaçable jusqu'à la fin du jour de la course (Paris) : correction de cap du 2026-10-18 (`sprint-change-proposal-2026-10-18.md`), approuvée le 2026-11-15 avec ses choix par défaut.
- §9.1, §10 — Service payant, comptes obligatoires, paliers, formules et paiement Mobile Money : décisions du porteur de projet le 2026-11-15 (`brainstorm-intent.md`, `sprint-change-proposal-2026-11-15.md`).
- §4.12 — Numéro de téléphone + code comme identité, code PIN local, email de secours, appareil bloqué au-delà de la limite avec proposition Duo, appairage par QR code affiché par la web app et approuvé depuis le téléphone : décisions du porteur de projet le 2026-11-15 (D-6).
- §1, §6.1 — Application mobile = produit complet, web app compagnon sans fonctionnalité propre ni cache hors ligne : décisions du porteur de projet le 2026-11-15 (D-7).
- §10, FR-44 — Pass journée = Expert pendant 24 h ; droit hors ligne valable jusqu'à sa date de fin, sans délai de grâce ; lancement payant sans attendre le Multi : décisions D-2, D-3, D-4 du 2026-11-15.
- §9.3, §10 — Lancement payant malgré le jalon « source de données légitime » non atteint, sous réserve d'un avis juridique favorable : décision D-1 du 2026-11-15.
- §10 — Verrouillage sur l'appareil des fonctionnalités calculées localement, risque d'app modifiée jugé faible et accepté, contrôle d'intégrité en V1.1 : décision D-5 du 2026-11-15.
- FR-39, FR-43, FR-46 — Matrice d'accès par palier, Duo pour chaque palier payant avec les dates du titulaire, export texte conservé avec l'identifiant du compte : arbitrages du PM à la mise à jour du 2026-11-15, à confirmer par le porteur de projet (OQ 13).
- FR-36, FR-47, OQ 19, OQ 20 — Appareil bloqué autorisé à ouvrir « Mes appareils » en mode restreint pour retirer un seul appareil ; back-office = application Flutter Web distincte ; fournisseur d'email laissé ouvert ; domaine acheté plus tard, topologie d'hôtes fixée dès maintenant : décisions du porteur de projet le 2026-11-16 (correctifs du contrôle de préparation du 2026-11-15).
- §4.15 — Pronostic publié par le modèle de référence (modèle combiné tant qu'il bat le marché, sinon moteur §4.3), affiché par défaut, moteur réglable en mode expert : reprend l'architecture AD-14 (2026-10-22) et le service de pronostics publiés déjà en place (commit `9c4bc6b`).
