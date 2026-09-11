# Réconciliation — brief/addendum vs DESIGN.md / EXPERIENCE.md

Sources lues intégralement :
- `briefs/brief-prediction-hyppique-2026-08-17/brief.md`
- `briefs/brief-prediction-hyppique-2026-08-17/addendum.md`
- `ux-designs/ux-prediction-hyppique-2026-08-22/DESIGN.md`
- `ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md`

Méthode : chaque idée qualitative du brief/addendum (ton, nuance de positionnement, angle de différenciation démontrable) a été recherchée explicitement dans DESIGN.md §Brand & Style / §Do's and Don'ts et dans EXPERIENCE.md §Voice and Tone / §Component Patterns / §State Patterns, avec vérification par recherche de mots-clés (« réglable », « reproductible », « coefficient », « Kelly », « tactique », « driver », « expert », « calibr »…) pour éviter de rater une formulation alternative.

Verdict global : les spines couvrent très bien le **ton de sécurité/honnêteté générique** (pas de certitude, rappel de jeu responsable, transparence sur les données importées) et **excellent** sur la traduction visuelle du contraste modèle/marché (or vs bleu = « la promesse produit »). En revanche, plusieurs angles de différenciation *démontrables et spécifiques* du brief — ceux qui distinguent le produit d'un simple site de pronostics honnête — sont absents ou dilués dans le comportement/la microcopie. Ce ne sont pas des degrés de gravité produit (rien ne bloque un MVP), mais des pertes de positionnement : un lecteur qui ne connaîtrait que DESIGN.md/EXPERIENCE.md ne devinerait pas certains des arguments les plus forts du brief.

---

## Écart 1 — « Reproductible et réglable » : le différenciateur central face au jugement d'expert n'apparaît nulle part

**Gravité : Majeure**

**(1) Ce que dit la source.** C'est l'angle de différenciation n°1 de l'addendum : *« Geny n'est pas opaque par choix : son pronostiqueur explique ses choix en prose […]. C'est du jugement d'expert, pas un algorithme caché. La vraie différence : le modèle de l'Analyseur est reproductible et réglable — mêmes données, même résultat, et l'utilisateur peut recalibrer les coefficients (récence, sensibilité au poids, contraste…) et voir le classement bouger. Aucun concurrent observé ne permet à son lecteur de recalibrer le pronostic. »* Le brief reprend la même idée dans le tableau §2 : *« Modèle opaque, non réglable » → « Moteur transparent : chaque coefficient […] est visible et modifiable par l'utilisateur »*.

**(2) Ce qu'on trouve dans les spines.** Recherche des termes « réglable », « reproductible », « recalibr », « coefficient » dans DESIGN.md et EXPERIENCE.md : zéro occurrence dans les deux fichiers. L'écran Réglages existe bien (IA §Information Architecture, `settings-row` en Components) et son comportement mécanique est décrit : *« Modification appliquée immédiatement en mémoire ; persistée au blur/confirmation. Action "réinitialiser" isolée, avec confirmation. »* — mais c'est une description d'interaction générique de formulaire, qui pourrait s'appliquer à n'importe quel écran de paramètres d'app. Rien ne relie ce comportement au fait que c'est *précisément* ce qui manque chez tous les concurrents. Dans le flux UJ-2 (Key Flows), Marc « ouvre Réglages, ajuste la sensibilité au poids » puis retape « Calculer » — l'action existe, mais aucune microcopie n'accompagne ce geste pour en faire un moment de preuve du positionnement (ex. un texte d'aide sur l'écran Réglages, ou un rappel au moment du recalcul que le classement a changé *parce que* le coefficient a changé). DESIGN.md §Brand & Style ne mentionne ce concept à aucun moment — le paragraphe d'ouverture parle de densité, d'honnêteté sur le risque de jeu, mais jamais de transparence/réglabilité du moteur comme trait de personnalité de marque.

**(3) Suggestion.** Ajouter une phrase dans DESIGN.md §Brand & Style qui nomme explicitement ce trait (ex. « le produit n'est pas seulement honnête sur ses limites — il est vérifiable : chaque coefficient qui produit un classement est visible et modifiable, contrairement au jugement d'expert non recalibrable des sites de pronostics »). Dans EXPERIENCE.md, enrichir la ligne `settings-row` du tableau Component Patterns avec une règle comportementale qui capture l'effet démontrable (ex. « chaque réglage modifié et validé par "Calculer" doit produire un classement visiblement différent — le produit ne recalibre jamais silencieusement, l'écran Résultats affiche toujours l'état courant des paramètres qui l'ont généré »), et ajouter une ligne Voice and Tone avec un exemple de microcopie sur l'écran Réglages qui porte cette idée (à valider contre les prototypes existants si une formulation y figure déjà).

---

## Écart 2 — Le contraste « chiffré vs prose narrative concurrente » n'est pas énoncé comme principe de voix, seulement illustré par des exemples courts

**Gravité : Modérée**

**(1) Ce que dit la source.** L'addendum cite des exemples concrets de pronostics concurrents comme repoussoir explicite : *« retrouve Benjamin Rochard à son sulky »*, *« au second échelon avec Joyeux Nonna, Joria Mesloise... »*. Le brief §1 renforce : *« Ils donnent un pronostic en prose, formulé par un expert nommé […] — un jugement qualitatif, pas une probabilité chiffrée. »* Le changement de registre (prose narrative → chiffre actionnable) est présenté comme LE positionnement produit, pas un détail de style.

**(2) Ce qu'on trouve dans les spines.** EXPERIENCE.md §Voice and Tone est un tableau Do/Don't de microcopie courte (badges, messages d'erreur, rappel de jeu responsable) — cohérent en pratique avec « jamais de prose narrative », mais ce principe n'est jamais énoncé comme une règle de voix explicite avec sa justification concurrentielle. Aucune ligne du type « toute évaluation d'un cheval s'exprime en chiffre/badge, jamais en phrase explicative façon pronostic de journal ». DESIGN.md §Brand & Style évoque « chiffres alignés au cordeau » mais dans un sens strictement visuel (typographie tabulaire), pas comme règle de contenu/rédaction. Le risque : un futur rédacteur de microcopie (ex. pour l'écran Réglages, actuellement sans exemples — voir Écart 1) pourrait légitimement introduire une phrase explicative en prose pensant rester dans le ton, faute de règle explicite qui l'interdise et qui rappelle pourquoi.

**(3) Suggestion.** Ajouter une ligne au tableau Do/Don't de EXPERIENCE.md §Voice and Tone qui énonce le principe au niveau du registre, pas seulement de l'exemple : ex. « Jugement sur un cheval toujours exprimé en chiffre ou badge court (value, probabilité, %) » vs « Explication en phrase de type pronostic journalistique ("il devrait revenir en forme", "sa dernière sortie était rassurante") ». Optionnellement, ajouter une phrase dans DESIGN.md §Brand & Style qui nomme le contraste concurrentiel directement (« l'app ne produit jamais de texte explicatif à la manière d'un pronostiqueur — un jugement s'exprime en chiffre, jamais en paragraphe »).

---

## Écart 3 — « Faiblesses assumées honnêtement » : couvert uniquement pour le risque de jeu, pas pour les limites épistémiques du modèle

**Gravité : Majeure**

**(1) Ce que dit la source.** Le brief §2 et l'addendum désignent deux faiblesses précises et volontairement mises en avant, distinctes du risque de jeu générique :
- *« Le modèle est aveugle à l'information tactique et humaine que les tipsters captent (changement de driver de dernière minute, intention de course rapportée par un entraîneur). Aucune donnée chiffrée ne remplace ça aujourd'hui. »*
- *« Aucune preuve à ce stade que les probabilités du modèle sont mieux calibrées que le jugement d'expert des pronostiqueurs. Seul un backtest sur un volume significatif de courses l'établira. »*

Ces deux points sont présentés comme des éléments *à ne pas taire*, donc comme un trait de ton assumé — une humilité épistémique spécifique au modèle, différente du simple avertissement légal sur le jeu responsable.

**(2) Ce qu'on trouve dans les spines.** DESIGN.md §Brand & Style couvre uniquement : *« aucune certitude n'est jamais affichée comme un fait, chaque écran de résultats porte le rappel que le jeu comporte des risques »* — et EXPERIENCE.md §Voice and Tone traduit cela par la phrase fixe *« Outil d'aide à la décision — aucun modèle ne garantit un gain. Jouez uniquement ce que vous pouvez vous permettre de perdre. »* C'est un avertissement financier/légal générique (bankroll, addiction), pas une reconnaissance des limites de perception du modèle. Recherche de « tactique », « driver », « expert » dans les deux fichiers : aucune occurrence. Aucun état, badge ou microcopie ne signale par exemple qu'un score ne tient pas compte d'une information de dernière minute (changement de driver, intention de course) — alors que le produit a par ailleurs un vocabulaire de badges bien développé pour d'autres incertitudes (« Historique court », « Données non saisies », « Inédit », terrain inconnu). Il y a donc une incohérence de traitement : le produit signale abondamment ses incertitudes *de données*, mais jamais son incertitude *de méthode* face à l'expertise humaine.

**(3) Suggestion.** Deux niveaux possibles :
- Minimal (ton) : dans DESIGN.md §Brand & Style, élargir la phrase sur l'honnêteté pour couvrir explicitement les deux registres (« le ton reste honnête sur deux plans : le risque financier du jeu, et les limites du modèle lui-même — il ne voit ni l'information tactique de dernière minute, ni ne prétend surpasser le jugement d'un expert humain, faute de preuve établie »).
- Concret (comportement) : envisager dans EXPERIENCE.md un état ou une microcopie ponctuelle (par ex. dans le détail d'un cheval en Résultats, ou en aide contextuelle sur l'écran Résultats) qui rappelle une fois, sobrement, ce que le modèle ne capte pas — cohérent avec le principe déjà établi ailleurs dans EXPERIENCE.md de « ne jamais absorber une incertitude silencieusement ». Cela reste à trancher côté produit (pourrait être jugé trop verbeux) mais mérite au moins d'être noté comme option envisagée plutôt qu'absente de la réflexion.

---

## Écart 4 — Mise suggérée (Kelly fractionné) : différenciateur cité comme « rare même chez les services payants », quasi invisible dans les spines

**Gravité : Modérée**

**(1) Ce que dit la source.** Addendum, angles additionnels : *« Mise suggérée (Kelly fractionné). Aucun des quatre sites ne dit combien miser, seulement quoi jouer. L'Analyseur relie recommandation et gestion de bankroll — rare même chez les services payants. »* Le brief le liste aussi dans le tableau différenciateur §2 et dans la coupure freemium (payant = « mise suggérée (Kelly) »).

**(2) Ce qu'on trouve dans les spines.** Recherche de « Kelly », « bankroll », « mise suggérée » : une seule occurrence dans EXPERIENCE.md, en Key Flows (UJ-2, étape 7 : *« Il consulte la nouvelle mise suggérée avant l'heure de départ »*) — mentionnée en passant dans un scénario, sans définition de composant. Ni DESIGN.md (aucun token/component `stake`/`mise`/`kelly`), ni EXPERIENCE.md §Component Patterns, ni §Voice and Tone n'ont d'entrée dédiée à cet élément — alors qu'un composant existe pour presque tout le reste (badge de value, jauge de probabilité, combo-block…). Les prototypes source (`imports/analyse_hippique_v2.html`) contiennent pourtant un panneau « Paramètres du modèle (bankroll, récence, agressivité…) » avec un sélecteur « Fraction de Kelly » explicite — donc la matière existe en amont mais n'a pas été distillée dans les spines.

**(3) Suggestion.** Ajouter une entrée composant (`stake-suggestion` ou équivalent) dans DESIGN.md §Components et une ligne correspondante dans EXPERIENCE.md §Component Patterns, avec au minimum : où elle apparaît (carte résultat détaillée ? section dédiée ?), comment le paramètre bankroll/fraction de Kelly se règle (probablement dans Réglages, à relier à l'Écart 1), et une règle de ton pour la présenter (étant un montant d'argent suggéré, elle est particulièrement sensible au principe « jamais de langage de certitude » déjà établi ailleurs — vaut la peine de le rendre explicite ici aussi, ex. « mise suggérée, jamais mise recommandée/à jouer », pour rester cohérent avec le champ lexical « aide à la décision »).

---

## Écart 5 — Amélioration par calibration continue : absente du ton produit

**Gravité : Mineure**

**(1) Ce que dit la source.** Addendum, angles additionnels : *« Amélioration par calibration continue. Une fois le backend calibré sur l'historique réel de courses, le modèle peut évoluer avec des données vérifiables. Un pronostic de journal ne se corrige jamais publiquement au vu de ses résultats passés. »* Brief §2, dernière ligne du tableau différenciateur : *« Pronostic jamais recorrigé publiquement » → « Modèle calibrable sur données réelles à mesure que l'historique s'accumule »*.

**(2) Ce qu'on trouve dans les spines.** Aucune trace : ni dans DESIGN.md, ni dans EXPERIENCE.md (recherche « calibr » : zéro occurrence dans les deux fichiers de spine — le seul hit du dépôt est dans un fichier de log interne, pas dans le contenu produit). C'est cohérent avec le fait que les spines UX se concentrent sur l'expérience immédiate (écran par écran) plutôt que sur une trajectoire produit dans le temps — mais rien n'indique non plus qu'il existe un endroit (écran « À propos », note de version, ou simplement un élément de confiance affiché quelque part) où cette idée pourrait un jour transparaître.

**(3) Suggestion.** Écart mineur et pas forcément à corriger dans cette itération (l'idée est plus une promesse de roadmap qu'un besoin d'écran V1) — mais vaut la peine d'être noté comme `[OPEN QUESTION]` dans EXPERIENCE.md si un écran « À propos du modèle » ou équivalent est envisagé plus tard, pour ne pas perdre cet angle en cours de route.

---

## Écart 6 — Profondeur d'historique (jusqu'à 2004, sans compte) comme argument de positionnement, jamais mentionnée en ton/microcopie

**Gravité : Mineure**

**(1) Ce que dit la source.** Addendum : *« Différenciateur d'accès réel, à formuler sur ce fait précis, pas sur une hypothèse de prix »* — contraste avec Geny qui limite à 5 performances sans compte. Le brief le reprend dans le tableau §2 et dans la coupure freemium (payant = historique profond).

**(2) Ce qu'on trouve dans les spines.** EXPERIENCE.md mentionne bien un badge « Historique court (3) » côté état de données manquantes pour un cheval donné (State Patterns, Voice and Tone) — mais c'est un signal d'incertitude sur un cheval précis, pas un message de positionnement produit sur la profondeur d'accès globale par rapport aux concurrents. Rien dans les deux fichiers n'exprime « accès à un historique plus profond que les sites concurrents, y compris sans compte » comme trait distinctif.

**(3) Suggestion.** Écart mineur et probablement hors-scope pour DESIGN/EXPERIENCE (c'est plus un argument de fiche produit / onboarding / paywall que de voix d'interface quotidienne) — à signaler seulement si un futur écran d'onboarding ou de comparaison freemium/premium est spécifié, pour ne pas le perdre.

---

## Ce qui est déjà bien réconcilié (pas d'écart)

- **Le changement de registre central** (« qui va bien courir » → « où marché et modèle sont en désaccord, et de combien », `value = probabilité × cote − 1`) est excellemment traduit visuellement : DESIGN.md fait de l'or (modèle) et du bleu (marché) côte à côte *« la promesse produit — le contraste modèle/marché rendu visuellement immédiat »*. C'est une transposition fidèle et même renforcée du positionnement du brief.
- **Combinaisons optimisées classées par probabilité** — décrit fidèlement en composant (`combo-block`) et en comportement (lecture seule, tap = copier les dossards), cohérent avec l'angle « le plus démontrable » de l'addendum.
- **Ton anti-certitude / jeu responsable** — très bien couvert, cohérent et répété à plusieurs niveaux (Brand & Style, Voice and Tone, Do's and Don'ts, Anti-patterns, Accessibility Floor).
- **Transparence sur les données importées par IA** (bandeau « à vérifier », jamais « confirmé ») — fidèle à l'esprit de transparence du brief, bien qu'il s'agisse d'un point qui vient surtout du cahier des charges mobile plutôt que du brief/addendum lui-même.

---

## Résumé des écarts par gravité

- Majeurs : 2 (Écart 1 — réglable/reproductible absent ; Écart 3 — faiblesses épistémiques réduites au seul rappel de jeu responsable)
- Modérés : 2 (Écart 2 — contraste chiffré/prose non énoncé comme principe ; Écart 4 — mise suggérée/Kelly quasi absente des spines)
- Mineurs : 2 (Écart 5 — calibration continue absente ; Écart 6 — profondeur d'historique absente du ton)
