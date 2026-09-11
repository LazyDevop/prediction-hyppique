# Spine Pair Review — Analyseur Hippique

## Overall verdict

La paire DESIGN.md/EXPERIENCE.md est structurellement solide : ordre canonique respecté dans les deux fichiers, frontmatter `sources` complet et résolu, faible bloat, Key Flows correctement rejoués au niveau écran plutôt que dupliqués depuis le PRD. Mais un consommateur en aval buterait sur des trous réels et non documentés : la mise Kelly suggérée — la fonctionnalité différenciatrice du produit (PRD §1 Vision, FR-10) — n'a aucune spécification visuelle ni comportementale ; deux composants nommés dans DESIGN.md (`cta-ghost`, l'indicateur de régularité) n'ont aucun traitement dans EXPERIENCE.md ; et aucun état de focus n'est défini nulle part malgré un produit dense en saisie. Le contrat est utilisable pour ~80 % des écrans mais forcerait un développeur ou une story IA à improviser sur les 20 % restants.

## 1. Flow coverage — strong

Les trois UJ du PRD (§2.3 : UJ-1, UJ-2, UJ-3) ont chacun un Key Flow correspondant dans EXPERIENCE.md, avec protagoniste nommé (Marc), étapes numérotées, un climax explicite (`**Climax :**`) et un chemin d'échec (`Échec :`). Les noms d'UJ sont repris quasi verbatim (légère différence de ponctuation uniquement — point vs tiret cadratin, sans incidence). Le contenu du climax de chaque flow est cohérent avec le climax décrit dans le PRD lui-même (UJ-1 : value forte + jauge ; UJ-2 : recalcul local instantané ; UJ-3 : validation des champs importés, la spine déplaçant le climax vers l'enregistrement plutôt que la vérification — reformulation légitime au niveau écran, pas une divergence).

### Findings

Aucun manque.

## 2. Token completeness — adequate

Tous les tokens du frontmatter YAML (`colors`, `rounded`, `spacing`, `components`) sont définis avec des valeurs concrètes, et toutes les références `{path.to.token}` trouvées dans la prose (Layout & Spacing, Shapes, Components, Elevation & Depth) résolvent vers un token existant. Les couleurs ont toutes une valeur hex/rgba. Les 11 clés de `components` en frontmatter référencent uniquement des tokens définis.

### Findings

- **medium** Les quatre rôles de `typography` (`display`, `label`, `body`, `numeric`) sont spécifiés uniquement via un champ `note` générique ("police système") sans jamais nommer un rôle concret de l'échelle Material 3, alors qu'EXPERIENCE.md (Foundation, l. 18) déclare explicitement Flutter + Material 3 comme plateforme cible. L'exemple de référence `design-example-mobile.md` nomme le style exact ("iOS Title 1 · Android Headline Small") — ici aucun `TextTheme` M3 (`titleLarge`, `bodyMedium`, etc.) n'est jamais cité (DESIGN.md l. 25-33, 115-121). *Fix :* nommer le rôle M3 le plus proche pour chaque clé de typographie, comme le fait l'exemple mobile pour iOS/Android.
- **low** `typography.numeric` ne porte qu'une règle de formatage (chiffres tabulaires) sans aucune taille/graisse propre — on ne sait pas si `numeric` hérite de la taille de son contexte (body, label, cellule de carte résultat) ou constitue son propre palier (DESIGN.md l. 31-33). *Fix :* préciser explicitement que `numeric` hérite de la taille du contexte et n'ajoute que la fonctionnalité `tabular-nums`, ou lui donner sa propre taille.

## 3. Component coverage — thin

11 composants sont définis dans `DESIGN.md.components` (frontmatter + prose) : `horse-card`, `results-card`, `dossard-badge`, `value-badge`, `probability-gauge`, `status-banner-import`, `combo-block`, `cta-primary`, `cta-ghost`, `settings-row`, `import-sheet`. `EXPERIENCE.md.Component Patterns` couvre 9 de ces 11 par une ligne dédiée avec règles comportementales réelles. Deux composants DESIGN.md n'ont pas de ligne dédiée, et une donnée explicitement citée comme affichée sur la carte cheval n'a aucun composant du tout.

### Findings

- **critical** La mise Kelly fractionné suggérée ("mise suggérée", FR-10) — présentée dans le PRD §1 Vision comme le cœur de la différenciation produit — n'a de composant nulle part : absente de `DESIGN.md.components` (frontmatter et prose) et de `EXPERIENCE.md.Component Patterns`. Elle n'apparaît qu'une fois, en une phrase de narration dans un Key Flow ("il consulte la nouvelle mise suggérée avant l'heure de départ", EXPERIENCE.md l. 143), sans couleur, placement ni règle comportementale (le prototype source l'affiche pourtant comme une cellule verte en gras, `.stake`, dans chaque ligne du tableau résultats). *Fix :* ajouter un champ `stake`/`mise-suggérée` à `results-card` dans DESIGN.md, et une ligne dédiée dans Component Patterns reprenant la règle "mise masquée si Kelly brut négatif ou cote manquante" (FR-10).
- **high** `cta-ghost` est entièrement spécifié dans `DESIGN.md.Components` (utilisé pour "ajouter, importer, réinitialiser") mais n'a aucune ligne dans `EXPERIENCE.md.Component Patterns`. En aval, le bouton "+ cheval vide", l'action "importer une course" et l'action irréversible "réinitialiser" (mentionnée seulement dans la note comportementale de `settings-row`, pas rattachée à `cta-ghost`) n'ont aucune spécification comportementale propre (DESIGN.md l. 148 ; EXPERIENCE.md l. 57-68). *Fix :* ajouter une ligne `cta-ghost` couvrant ses trois sites d'usage et toute règle de confirmation/chargement.
- **high** La "régularité" (notation vert/or/rouge — "Très régulier"/"Régulier"/"Moyen"/"Irrégulier", documentée dans `imports/analyse_hippique_ia_ui_excerpt.md`) est nommée explicitement dans `DESIGN.md.Brand & Style` comme l'une des données qu'une carte cheval affiche simultanément ("ses... quatre probabilités de place et sa régularité", l. 100), mais aucun composant dans `DESIGN.md.Components` ni ligne dans `EXPERIENCE.md.Component Patterns` ne spécifie son rendu ou son comportement. *Fix :* ajouter un composant/ligne dédié, ou documenter explicitement la décision de l'exclure de la V1 (ex. dans Do's and Don'ts ou un `[OPEN QUESTION]`).
- **medium** `status-banner-import` est défini comme composant à part entière dans `DESIGN.md.Components`, mais `EXPERIENCE.md.Component Patterns` ne traite son comportement qu'à l'intérieur de la ligne `horse-card` ("Import IA marque la carte 'à vérifier' jusqu'à validation explicite d'un champ"). Aucune règle propre au bandeau lui-même (disparaît-il champ par champ ou seulement une fois toute la carte validée ? est-il tapable ?) (DESIGN.md l. 146 ; EXPERIENCE.md l. 59). *Fix :* soit lui donner sa propre ligne, soit expliciter dans la ligne `horse-card` qu'elle couvre aussi la règle de disparition du bandeau.

## 4. State coverage — adequate

EXPERIENCE.md.State Patterns couvre 13 états à travers les sept surfaces de l'Information Architecture, avec une bonne discipline (états de chargement à froid, vide, hors-ligne, permission refusée sur la feuille d'import — tous présents et rattachés à des FR précis). C'est la surface Import photo qui est la mieux couverte (chargement, échec, hors-ligne, permission refusée — les quatre).

### Findings

- **high** Aucun état "Focus" n'est défini nulle part dans `EXPERIENCE.md.State Patterns`, et `DESIGN.md` ne définit aucun token de focus (couleur/bordure) — alors que le produit est dense en saisie sur trois surfaces (Configuration course, Fiche cheval éditable, Réglages, toutes pleines de champs numériques). Les deux exemples de référence (Quill, Drift) définissent explicitement le focus. *Fix :* ajouter une ligne Focus (et un token de focus dans DESIGN.md, cohérent avec la règle "or = signal exceptionnel").
- **medium** Résultats n'a aucun état "calcul en cours" ni "erreur de calcul", malgré la simulation Monte-Carlo de FR-12 (≥20 000 tirages) et la question ouverte du PRD sur le seuil de perception "instantané" (§8, §11 Open Question 1). *Fix :* ajouter une ligne de calcul en cours (même brève) et une ligne d'erreur/calcul impossible.
- **low** Liste des partants n'a pas d'état "liste vide" explicite (zéro cheval saisi) — seul le CTA désactivé (Component Patterns) le couvre implicitement. *Fix :* ajouter une ligne d'état vide courte, sur le modèle du message "Aucune course chargée" de l'Accueil.
- **low** L'échec du pull-to-refresh sur l'Accueil (programme du jour, `GET /courses`) n'est pas couvert — seul l'échec du rafraîchissement des cotes sur Liste des partants l'est (via l'edge case d'UJ-2). *Fix :* ajouter une ligne, ou étendre la ligne "Réseau indisponible" existante à l'Accueil.

## 5. Visual reference coverage — adequate

Les deux fichiers de `imports/` (`analyse_hippique_v2.html`, `analyse_hippique_ia_ui_excerpt.md`) sont cités dans le frontmatter `sources` des deux spines et résolvent vers des fichiers réels. EXPERIENCE.md les cite explicitement par nom au point d'usage pertinent et nomme ce qu'ils illustrent (Voice and Tone → vocabulaire de l'excerpt IA ; Inspiration & Anti-patterns → transformation mobile du prototype HTML). DESIGN.md ne recite jamais les noms de fichiers dans le corps (seulement en frontmatter), parlant génériquement de "les deux prototypes" / "le prototype HTML" — acceptable puisqu'un seul fichier HTML existe, mais moins explicite que ce que demande la consigne.

### Findings

- **medium** Deux éléments de vocabulaire/langage visuel documentés dans `imports/analyse_hippique_ia_ui_excerpt.md` sont absents des deux spines sans trace de décision : la notation régularité (voir aussi finding §3) et l'indicateur de fragilité au saut "Sauteur fragile"/"N chute(s)" pour les courses d'obstacle (imports l. 53-55). *Fix :* soit les intégrer comme composants/lignes d'état, soit noter explicitement la décision de les exclure de la V1 (ex. `[OPEN QUESTION]` ou ligne Do's/Don'ts).

## 6. Bloat & overspecification — strong

Longueur et registre comparables aux exemples de référence. Pas de specs pixel là où les tokens suffisent (les rares valeurs px approximatives vivent dans des champs `note` de plateforme, cohérent avec la convention). Pas de duplication du contenu source : personas, FR et périmètre sont référencés par numéro de section (§1, §4.6, FR-13...) plutôt que recopiés. Les Key Flows sont correctement reformulés au niveau écran plutôt que de répéter la prose du PRD. Aucune narration décorative non reliée à une décision de design repérée.

### Findings

Aucun manque.

## 7. Inheritance discipline — adequate

Le frontmatter `sources` résout dans les deux fichiers (PRD, addendum, et pour EXPERIENCE.md également le cahier mobile, plus les deux imports). Les noms d'UJ sont verbatim (à la ponctuation près). Les noms de composants utilisés dans les deux fichiers sont identiques et entre backticks des deux côtés. Aucune référence `{path.to.token}` cassée trouvée.

### Findings

- **medium** La ligne `results-card` de `EXPERIENCE.md.Component Patterns` référence une destination de navigation — "Tap → détail (probabilités étendues, historique du cheval)" — absente de la table `Information Architecture` (seulement 7 surfaces listées, aucune "Détail cheval / Résultats"). Un architecte en aval ne peut pas dire s'il s'agit d'un nouvel écran, d'une modale ou d'une expansion en place (EXPERIENCE.md l. 61 vs l. 26-34). *Fix :* ajouter la surface à la table IA, ou préciser explicitement qu'il s'agit d'une expansion en place plutôt que d'une navigation.

## 8. Shape fit — strong

DESIGN.md respecte l'ordre canonique exact (Brand & Style → Colors → Typography → Layout & Spacing → Elevation & Depth → Shapes → Components → Do's and Don'ts). EXPERIENCE.md contient toutes les sections par défaut requises (Foundation, IA, Voice and Tone, Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor, Key Flows) et les deux sections déclenchées sont pertinentes et non gratuites : Inspiration & Anti-patterns porte un contenu réel (position anti-gamification, anti-certitude) et Responsive & Platform documente une vraie décision (portrait uniquement, pas de tablette) malgré une surface unique.

### Findings

- **low** Les deux sections déclenchées apparaissent dans l'ordre Inspiration & Anti-patterns → Responsive & Platform, alors que l'exemple de référence Drift les ordonne dans le sens inverse (Responsive & Platform → Inspiration & Anti-patterns). Aucun document de spec ne fixe un ordre verrouillé pour les sections déclenchées, donc ceci se lit comme une incohérence mineure plutôt qu'une violation. *Fix :* aligner sur l'ordre de l'exemple Drift par cohérence, si une convention maison est souhaitée.

## Mechanical notes

- Frontmatter `sources` complet et résolu dans les deux fichiers ; les chemins relatifs (`../../prds/...`, `imports/...`) pointent tous vers des fichiers existants.
- Aucune référence `{path.to.token}` cassée trouvée dans DESIGN.md ; EXPERIENCE.md n'utilise pas la syntaxe `{}` (conforme à la convention observée dans les deux exemples de référence — les specs visuelles restent dans DESIGN.md).
- Noms de composants cohérents (backticks identiques) partout où ils sont réellement utilisés dans les deux fichiers — le problème n'est pas une incohérence de nom, mais une absence pure et simple de ligne côté EXPERIENCE.md pour `cta-ghost`, l'indicateur de régularité, et le composant de mise Kelly qui n'existe même pas côté DESIGN.md (voir §3).
- Incohérence structurelle relevée en §7 : `results-card` référence une destination "détail" absente de la table Information Architecture — à corriger avant que l'architecture ne fige le nombre d'écrans.
- `status: draft` cohérent dans les deux fichiers ; dates `created`/`updated` identiques (2026-08-22) et cohérentes entre les deux spines.
