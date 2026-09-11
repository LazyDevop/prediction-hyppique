---
name: Analyseur Hippique
description: Outil d'aide à la décision pour courses hippiques PMU — sombre, dense, chiffré. L'esthétique d'un tableau des cotes vu de nuit, pas d'une app de paris grand public.
status: final
created: 2026-08-22
updated: 2026-08-22
sources:
  - ../../prds/prd-prediction-hyppique-2026-08-22/prd.md
  - ../../prds/prd-prediction-hyppique-2026-08-22/addendum.md
  - imports/analyse_hippique_v2.html
  - imports/analyse_hippique_ia_ui_excerpt.md
colors:
  bg: '#0B1120'
  surface: '#131C2E'
  surface-2: '#0F1728'
  line: 'rgba(255,255,255,.08)'
  line-2: 'rgba(255,255,255,.14)'
  line-card: 'rgba(255,255,255,.32)'
  gold: '#E8B33C'
  gold-dim: 'rgba(232,179,60,.12)'
  green: '#3DD68C'
  red: '#E5533D'
  blue: '#5B9BD5'
  text: '#E7E4DA'
  muted: '#8B93A7'
typography:
  display:
    note: "Titre d'écran, majuscules, letter-spacing ouvert (~0.5px). Police système — pas de police custom embarquée."
  label:
    note: "Libellés de champ et en-têtes de section — majuscules, ~11px, letter-spacing ~0.5-0.8px, {colors.muted} ou {colors.gold} selon contexte."
  body:
    note: "Texte courant, police système (Roboto sur Android)."
  numeric:
    note: "Toute valeur numérique (score, cote, probabilité, mise) — chiffres tabulaires (tabular figures) obligatoires pour l'alignement en colonne, y compris dans les cartes empilées."
rounded:
  xs: 6px
  sm: 8px
  md: 10px
  lg: 12px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 22px
  '6': 32px
components:
  horse-card:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    border-imported: '1px solid {colors.gold}'
  results-card:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-top1: '1px solid {colors.gold}'
    background-top1-tint: '{colors.gold-dim}'
    stake-text: '{colors.green}'
    stake-hidden: '{colors.muted}'
  dossard-badge:
    background: '{colors.gold}'
    text: '#14100A'
    border-radius: '{rounded.xs}'
  value-badge:
    positive: '{colors.green}'
    negative: '{colors.red}'
    unknown: '{colors.muted}'
  regularity-indicator:
    high: '{colors.green}'
    medium: '{colors.gold}'
    low: '{colors.red}'
    unknown: '{colors.muted}'
  fragile-indicator:
    text: '{colors.red}'
    icon: '⚠️'
  probability-gauge:
    track: '{colors.surface}'
    track-border: '1px solid {colors.line-card}'
    fill-model: '{colors.gold}'
    fill-market: '{colors.blue}'
  status-banner-import:
    background: '{colors.gold-dim}'
    text: '{colors.gold}'
  combo-block:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    title: '{colors.gold}'
    probability-text: '{colors.green}'
    names-text: '{colors.muted}'
  cta-primary:
    background: '{colors.gold}'
    text: '#14100A'
  cta-ghost:
    background: '{colors.surface}'
    text: '{colors.text}'
    border: '1px solid {colors.line-card}'
  settings-row:
    background: 'transparent'
    border-bottom: '1px solid {colors.line}'
    label: '{colors.muted}'
    value: '{colors.text}'
  import-sheet:
    background: '{colors.surface}'
    border-radius-top: '{rounded.lg}'
    action-icon: '{colors.gold}'
  focus-indicator:
    outline: '2px solid {colors.gold}'
    offset: '2px'
---

## Brand & Style

Analyseur Hippique n'a pas la posture d'une app de paris grand public — pas de confettis, pas de vert néon "vous avez gagné", pas de mascotte. Sa référence esthétique est le tableau des cotes d'un hippodrome vu de nuit : fond bleu-nuit presque noir, chiffres alignés au cordeau, un seul accent chromatique — l'or — réservé à ce qui mérite l'attention immédiate. C'est un outil pour quelqu'un qui regarde des chiffres avant de décider, pas pour quelqu'un qu'on cherche à exciter.

La densité d'information est assumée, pas cachée derrière des écrans successifs : un cheval porte simultanément son score, sa cote, sa value, ses quatre probabilités de place et sa régularité, et l'app les affiche ensemble plutôt que de les disperser. La lisibilité vient de l'alignement (chiffres tabulaires stricts) et de la hiérarchie chromatique (or = signal principal, bleu = marché, vert/rouge = value), pas de la simplification du contenu.

Le produit n'est pas seulement honnête sur ses limites, il est **vérifiable** : chaque coefficient qui produit un classement (récence, sensibilité au poids, contraste, lissage...) est visible et modifiable par l'utilisateur sur l'écran Réglages, à l'opposé du jugement d'expert non recalibrable des sites de pronostics concurrents — c'est le trait de personnalité central du produit, pas un simple écran de paramètres technique (brief addendum, angle de différenciation n°1). L'app ne produit jamais de texte explicatif à la manière d'un pronostiqueur ("il devrait revenir en forme", "retrouve son driver habituel") — un jugement sur un cheval s'exprime toujours en chiffre ou en badge court, jamais en paragraphe narratif.

Le ton reste honnête plutôt que vendeur, sur deux plans distincts — cohérent avec le PRD (§1 Vision, limite assumée) : le risque financier du jeu (rappel systématique, aucun modèle ne garantit un gain) **et** les limites du modèle lui-même — il ne voit ni l'information tactique de dernière minute (changement de driver, intention de course rapportée par un entraîneur) ni ne prétend surpasser le jugement d'un expert humain, faute de preuve établie à ce stade. Les emojis fonctionnels (🐎 ⚠️ ✨ 🔥) servent de repères d'état rapides à l'œil sur un tableau dense, pas de décoration — cohérent avec la voix déjà établie dans les deux prototypes validés.

## Colors

- **`bg` (`#0B1120`)** — Fond de l'app, bleu-nuit quasi noir. Jamais de blanc pur nulle part dans l'interface — le produit est sombre par nature, pas par thème optionnel (EXPERIENCE.md.Foundation : pas de mode clair en V1).
- **`surface` (`#131C2E`) / `surface-2` (`#0F1728`)** — Deux tons de panneau pour la stratification (carte au-dessus du fond, champ de saisie au-dessus de la carte). La hiérarchie se lit par la teinte, jamais par une ombre portée (voir Elevation & Depth).
- **`gold` (`#E8B33C`)** — L'unique accent de marque. Réservé à : l'action principale (CTA "Calculer"), le badge de dossard, le titre d'écran, la barre "modèle" de la jauge de probabilité, le cheval classé n°1. Ne jamais l'utiliser pour de la simple décoration — s'il est or, c'est que c'est le signal le plus important de l'écran.
- **`green` (`#3DD68C`) / `red` (`#E5533D`)** — Exclusivement pour la value (positive/négative) et le malus d'incident. Jamais utilisés pour un statut générique de succès/erreur système — ce vocabulaire chromatique est réservé au jugement du modèle sur un cheval, pour ne jamais le confondre avec un état d'interface (chargement réussi, erreur réseau).
- **`blue` (`#5B9BD5`)** — Exclusivement la probabilité implicite du marché (la cote), en contrepoint de l'or (le modèle). Les deux couleurs côte à côte *sont* la promesse produit — le contraste modèle/marché rendu visuellement immédiat.
- **`text` (`#E7E4DA`) / `muted` (`#8B93A7`)** — Texte principal légèrement chaud (pas blanc pur, cohérent avec le fond navy) ; texte secondaire pour les libellés, unités, méta-informations.
- **`line-card` (`rgba(255,255,255,.32)`)** — Bordure renforcée réservée à la délimitation des cartes et panneaux (voir Elevation & Depth) : contraste vérifié ≥ 3:1 contre `surface` et `surface-2`, condition non négociable puisque le système bannit l'ombre portée comme mécanisme de séparation. `line` et `line-2` (plus discrètes) restent réservées aux séparateurs internes à faible enjeu (ex. pied de ligne d'un `settings-row`), jamais à une limite entre deux objets d'interface distincts dans un flux continu.

À éviter : tout dégradé, toute couleur d'accent supplémentaire (une seule couleur de marque), tout usage du vert/rouge en dehors du jugement value/incident, toute bordure de carte en `line`/`line-2` (réservées à l'usage interne à faible enjeu — voir `line-card`).

## Typography

Police système uniquement (Roboto sur Android via Flutter par défaut) — aucune police custom embarquée, décision confirmée pour rester proche du rendu natif et ne pas alourdir le binaire. `[ASSUMPTION: confirmé par l'utilisateur lors du cadrage UX — pas une inférence.]`

Règle non négociable, héritée des deux prototypes : **tout chiffre est en figures tabulaires** (`font-variant-numeric: tabular-nums` ou équivalent Flutter `FontFeature.tabularFigures()`), sans exception — scores, cotes, probabilités, mises, âges, poids. C'est ce qui permet à un tableau dense de rester lisible en colonnes alignées, y compris une fois transformé en cartes empilées sur mobile (voir Components).

Les libellés de champ et en-têtes de section sont en majuscules avec un `letter-spacing` ouvert (~0.5-0.8px) — signal visuel constant de "ceci est un libellé, pas une valeur".

Mapping vers l'échelle Material 3 (Flutter `TextTheme`), pour éviter toute improvisation en aval : `display` → `titleLarge` ; `label` → `labelSmall` (en majuscules via transformation, pas une variante de police séparée) ; `body` → `bodyMedium` ; `numeric` hérite systématiquement de la taille de son contexte d'usage (`bodyMedium` dans une carte, `labelSmall` dans une jauge) et n'ajoute que la fonctionnalité `FontFeature.tabularFigures()` — ce n'est jamais un palier de taille propre.

## Layout & Spacing

Échelle : `{spacing.1}` 4px à `{spacing.6}` 32px. Les plus grands espacements séparent les sections majeures (entre panneaux) ; les plus petits séparent les éléments d'un même groupe logique (une ligne de performance, une paire libellé/valeur). Padding interne des cartes et panneaux : `{spacing.4}` (16px) à `{spacing.3}` (12px) selon la densité de la carte.

Colonne unique, verticale — pas de grille multi-colonnes sur mobile natif. Les grilles `auto-fit` du prototype web (course cible, grille de combinaisons) se traduisent en `Wrap`/`GridView` adaptatif à 1-2 colonnes selon la largeur d'écran réelle, jamais en défilement horizontal forcé pour du contenu qui peut s'empiler.

## Elevation & Depth

Design plat, sans ombre portée — hérité à l'identique des deux prototypes (aucun `box-shadow` n'y apparaît). La hiérarchie visuelle vient de la stratification tonale (`bg` → `surface` → `surface-2`) combinée à une bordure de carte en `{colors.line-card}` — jamais d'une ombre. Une carte ne "flotte" pas au-dessus du fond ; elle se distingue par sa teinte et par un contour effectivement perceptible : la stratification tonale seule (`surface`/`surface-2` contre `bg`) ne franchit pas le seuil de contraste UI et ne doit jamais porter la délimitation d'une carte à elle seule — c'est `line-card` qui porte cette responsabilité, à dessein plus marquée que les séparateurs internes `line`/`line-2`.

Exception unique : la bordure devient `{colors.gold}` (au lieu de `{colors.line-card}`) pour signaler un état exceptionnel — cheval classé n°1 ou cheval importé par IA à vérifier. Les deux cas portent une redondance non-couleur propre (position en tête de liste triée pour le n°1 ; bandeau texte "à vérifier" pour l'import IA — voir Components) : la bordure or n'est jamais le seul signal. C'est le seul mécanisme de mise en avant utilisé dans tout le produit — aucun autre état (sélection, focus excepté, survol) ne doit lui être ajouté sans la même redondance non-couleur.

## Shapes

`{rounded.xs}` (6px) pour les petits éléments denses (badge de dossard, tags d'incident). `{rounded.sm}` (8px) pour les champs de saisie. `{rounded.md}` (10px) pour les boutons. `{rounded.lg}` (12px) pour les cartes et panneaux (carte cheval, carte résultat, panneau de section). Rien en coin totalement arrondi — pas de pilule, pas de cercle plein, cohérent avec l'esthétique "tableau de bord dense" plutôt que "app ludique".

## Components

- **Carte partant (horse-card)** — `{colors.surface}`, bordure `{colors.line-card}` (ou `{colors.gold}` si importé par IA et non vérifié). En-tête : dossard, nom, âge, poids, cote. Corps : tableau des performances passées, indicateur de régularité, indicateur de fragilité au saut si course d'obstacle. Bandeau `status-banner-import` visible tant que les champs importés par IA n'ont pas été vérifiés par l'utilisateur.
- **Carte résultat (results-card)** — Sur mobile, chaque cheval du classement est une carte empilée (jamais un tableau à défilement horizontal — pattern déjà validé dans la version mobile du prototype HTML, où `table.res` devient une liste de cartes avec libellé préfixé par ligne). Bordure `{colors.line-card}`, ou `{colors.gold}` + fond `{colors.gold-dim}` en tinte légère pour le cheval n°1 uniquement. Porte, entre autres valeurs : score, cote, value, jauge de probabilité, indicateur de régularité, **mise suggérée** (`stake-text` en `{colors.green}`, gras — masquée, texte `stake-hidden` en `{colors.muted}`, jamais un simple zéro, quand le Kelly brut est négatif ou la cote manquante).
- **Badge de dossard (dossard-badge)** — Fond `{colors.gold}`, texte quasi noir (`#14100A`), coin `{rounded.xs}`. Seul badge plein-couleur du système — réservé à l'identification du cheval, jamais réutilisé pour autre chose.
- **Indicateur de régularité (regularity-indicator)** — Texte seul (jamais une pastille de couleur nue), sur l'échelle `high` (vert, "Très régulier"/"Régulier"), `medium` (or, "Moyen"), `low` (rouge, "Irrégulier"), `unknown` (muted, "Historique court"/"Données non saisies"/"🐎 Inédit" — ces trois derniers libellés partagent le token `unknown` mais restent des libellés distincts, jamais fusionnés en un seul texte générique).
- **Indicateur de fragilité au saut (fragile-indicator)** — Courses d'obstacle uniquement. Texte `{colors.red}` + icône ⚠️, affiché seulement si ≥ 2 chutes et taux de chute ≥ 34 % ("⚠️ Sauteur fragile (N chutes/N perfs)") ; en dessous de ce seuil, mention neutre en `muted` ("N chute(s)") sans icône d'alerte.
- **Jauge de probabilité (probability-gauge)** — Deux barres horizontales superposées : `fill-model` en or, `fill-market` en bleu, sur une piste `track` en `{colors.surface}` bordée de `track-border` (`{colors.line-card}`) — jamais `{colors.surface-2}` comme piste quand la jauge vit dans une `results-card` (même fond que son conteneur, piste invisible sinon). Toujours accompagnée d'un libellé texte des deux valeurs (jamais la barre seule — voir Accessibility Floor côté EXPERIENCE.md).
- **Bloc combinaison (combo-block)** — `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`, titre en `label`. Numéros de dossard en gras, probabilité en `{colors.green}`, noms des chevaux en `muted` tronqués.
- **Bandeau d'import IA (status-banner-import)** — Fond `{colors.gold-dim}`, texte `{colors.gold}` — signale "à vérifier", jamais "confirmé" tant que l'utilisateur n'a pas interagi avec la carte. Non tapable en lui-même (informatif seulement) ; disparaît au niveau de la carte entière, pas champ par champ (voir EXPERIENCE.md.Component Patterns pour la règle de disparition).
- **CTA principal (cta-primary)** — Fond plein `{colors.gold}`, texte `#14100A`, coin `{rounded.md}`, toujours en majuscules. Un seul CTA plein par écran ("Calculer le classement").
- **CTA secondaire (cta-ghost)** — Fond `{colors.surface}`, bordure `{colors.line-card}`, texte `{colors.text}`. Utilisé pour toutes les actions non primaires (ajouter, importer, réinitialiser).
- **Ligne de réglage (settings-row)** — Libellé à gauche en `muted`, valeur/contrôle à droite en `text`, séparateur `{colors.line}` en pied de ligne (séparateur interne à faible enjeu, pas une limite de carte — voir Colors). Pas de carte englobante — liste simple, cohérent avec la densité assumée du produit.
- **Feuille d'import (import-sheet)** — Fond `{colors.surface}`, coins arrondis en haut uniquement (`{rounded.lg}`), icônes d'action (caméra/galerie/PDF) en `{colors.gold}`.
- **Indicateur de focus (focus-indicator)** — Contour `{colors.gold}` 2px, décalage 2px — cohérent avec le principe "or = signal exceptionnel". S'applique à tout élément interactif au clavier/navigation externe (rare sur mobile tactile, mais requis pour la conformité et les claviers externes/accessoires).

→ Référence de composition : `mockups/resultats.html` (results-card, probability-gauge, combo-block, stake), `mockups/liste-partants.html` (horse-card, status-banner-import, cta-primary, cta-ghost), `mockups/fiche-cheval.html` (horse-card en édition, feuille de performance), `mockups/accueil.html` (listes de courses, état vide), `mockups/configuration-course.html` (champs de configuration, sélecteur de terrain groupé), `mockups/import-photo.html` (import-sheet et ses états). La spine gagne en cas de conflit avec une maquette.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Un seul accent chromatique (l'or), réservé au signal principal | Multiplier les couleurs de marque ou les dégradés |
| Vert/rouge réservés à la value et aux incidents | Réutiliser vert/rouge pour des états système génériques (succès réseau, erreur de saisie) |
| Chiffres tabulaires partout, sans exception | Laisser des colonnes de chiffres se désaligner |
| Hiérarchie par teinte et bordure `line-card` renforcée | Ombres portées, élévation Material par défaut, bordure de carte en `line`/`line-2` (trop discrète) |
| Cartes empilées sur mobile pour les données denses | Tableaux à défilement horizontal forcé sur téléphone |
| Rappel de jeu responsable visible sur chaque écran de résultats | Tout langage de certitude ("gagnant garanti", "coup sûr") |
| Tout signal d'état doublé d'un texte ou d'une position, même quand une bordure or est présente | Un signal porté par la couleur (ou la bordure or) seule, sans redondance |
