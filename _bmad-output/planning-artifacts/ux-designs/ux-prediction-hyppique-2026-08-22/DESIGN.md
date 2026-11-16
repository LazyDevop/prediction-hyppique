---
name: Analyseur Hippique
description: Outil d'aide à la décision pour courses hippiques PMU — sombre, dense, chiffré. L'esthétique d'un tableau des cotes vu de nuit, pas d'une app de paris grand public.
status: final
created: 2026-08-22
updated: 2026-11-16
sources:
  - ../../../../docs/cahier_des_charges_module_multi.md
  - ../../sprint-change-proposal-2026-10-18.md
  - ../../sprint-change-proposal-2026-11-15.md
  - ../../architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md
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
  line-card: 'rgba(255,255,255,.36)'
  gold: '#E8B33C'
  gold-dim: 'rgba(232,179,60,.12)'
  green: '#3DD68C'
  red: '#E5533D'
  blue: '#5B9BD5'
  text: '#E7E4DA'
  muted: '#8B93A7'
  on-gold: '#14100A'
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
    text: '{colors.on-gold}'
    border-radius: '{rounded.xs}'
    outline-background: '{colors.surface}'
    outline-text: '{colors.muted}'
    outline-border: '1px solid {colors.line-card}'
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
    text: '{colors.on-gold}'
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
  size-stepper:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.sm}'
    value: '{colors.text}'
    button-text: '{colors.text}'
    button-disabled-text: '{colors.muted}'
  confidence-card:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    border-high: '1px solid {colors.gold}'
    background-high-tint: '{colors.gold-dim}'
    title-high: '{colors.gold}'
    title-other: '{colors.text}'
    tag: '{colors.muted}'
    tag-high: '{colors.text}'
    pending-opacity: '0.6'
  formula-row:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    displayed-tag: '{colors.text}'
    guarantee-text: '{colors.muted}'
  multi-row:
    background: 'transparent'
    border-bottom: '1px solid {colors.line}'
    excluded-text: '{colors.muted}'
    excluded-dossard: 'dossard-badge outline'
    base-tag: '{colors.gold}'
  base-chip:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.md}'
    border-active: '1px solid {colors.gold}'
  tickets-sheet:
    background: '{colors.surface}'
    border-radius-top: '{rounded.lg}'
    base-dossard: '{colors.gold}'
    pinned-action-background: '{colors.surface}'
    pinned-action-border-top: '1px solid {colors.line-card}'
  debrief-row:
    background: 'transparent'
    border-bottom: '1px solid {colors.line}'
    pending-text: '{colors.muted}'
  multi-action-bar:
    background: '{colors.bg}'
    border-top: '1px solid {colors.line-card}'
  status-banner:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.sm}'
    text: '{colors.text}'
    border-strong: '2px solid {colors.text}'
  evaluation-block:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    distribution-bar: '{colors.muted}'
    distribution-track: '{colors.surface}'
  other-methods-section:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    hypothesis-tag: '{colors.muted}'
  multi-badge:
    background: 'transparent'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.xs}'
    text: '{colors.text}'
    unavailable-text: '{colors.muted}'
  multi-actions-sheet:
    background: '{colors.surface}'
    border-radius-top: '{rounded.lg}'
  horse-picker-sheet:
    background: '{colors.surface}'
    border-radius-top: '{rounded.lg}'
    unanalysed-text: '{colors.muted}'
  system-entry-sheet:
    background: '{colors.surface}'
    border-radius-top: '{rounded.lg}'
  focus-indicator:
    outline: '2px solid {colors.gold}'
    offset: '2px'
  locked-feature:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    label: '{colors.text}'
    tier-text: '{colors.muted}'
    icon: '🔒'
    action: 'cta-ghost'
  teaser-banner:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.sm}'
    text: '{colors.text}'
    tier-text: '{colors.muted}'
  pin-pad:
    key-background: '{colors.surface}'
    key-border: '1px solid {colors.line-card}'
    key-border-radius: '{rounded.md}'
    key-text: '{colors.text}'
    key-min-size: '48dp'
    dot-filled: '{colors.text}'
    dot-empty-border: '1px solid {colors.line-card}'
    error-text: '{colors.text}'
  otp-field:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.sm}'
    digit: '{colors.text}'
    hint: '{colors.muted}'
    min-height: '48dp'
  offer-card:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    title: '{colors.text}'
    price: '{colors.text}'
    unlocks-text: '{colors.muted}'
  device-row:
    background: 'transparent'
    border-bottom: '1px solid {colors.line}'
    name: '{colors.text}'
    meta: '{colors.muted}'
  qr-pairing:
    quiet-zone-background: '{colors.text}'
    modules: '{colors.bg}'
    frame-border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    countdown-text: '{colors.muted}'
  payment-status:
    background: '{colors.surface}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.sm}'
    text: '{colors.text}'
    border-failed: '2px solid {colors.text}'
  followed-race:
    star-on: '{colors.text}'
    star-off: '{colors.muted}'
    star-min-size: '48dp'
    row-background: 'transparent'
    row-border-bottom: '1px solid {colors.line}'
    time: '{colors.text}'
    meta: '{colors.muted}'
  backoffice-shell:
    rail-background: '{colors.surface-2}'
    rail-border-right: '1px solid {colors.line-card}'
    rail-item-text: '{colors.muted}'
    rail-item-selected-text: '{colors.text}'
    rail-item-selected-background: '{colors.surface}'
    content-background: '{colors.bg}'
    table-header: '{colors.muted}'
    table-row-border: '1px solid {colors.line}'
  correction-diff:
    background: '{colors.surface-2}'
    border: '1px solid {colors.line-card}'
    border-radius: '{rounded.lg}'
    current-value: '{colors.muted}'
    proposed-value: '{colors.text}'
    meta: '{colors.muted}'
---

## Brand & Style

Analyseur Hippique n'a pas la posture d'une app de paris grand public — pas de confettis, pas de vert néon "vous avez gagné", pas de mascotte. Sa référence esthétique est le tableau des cotes d'un hippodrome vu de nuit : fond bleu-nuit presque noir, chiffres alignés au cordeau, un seul accent chromatique — l'or — réservé à ce qui mérite l'attention immédiate. C'est un outil pour quelqu'un qui regarde des chiffres avant de décider, pas pour quelqu'un qu'on cherche à exciter.

La densité d'information est assumée, pas cachée derrière des écrans successifs : un cheval porte simultanément son score, sa cote, sa value, ses quatre probabilités de place et sa régularité, et l'app les affiche ensemble plutôt que de les disperser. La lisibilité vient de l'alignement (chiffres tabulaires stricts) et de la hiérarchie chromatique (or = signal principal, bleu = marché, vert/rouge = value), pas de la simplification du contenu.

Le produit n'est pas seulement honnête sur ses limites, il est **vérifiable** : chaque coefficient qui produit un classement (récence, sensibilité au poids, contraste, lissage...) est visible et modifiable par l'utilisateur sur l'écran Réglages, à l'opposé du jugement d'expert non recalibrable des sites de pronostics concurrents — c'est le trait de personnalité central du produit, pas un simple écran de paramètres technique (brief addendum, angle de différenciation n°1). L'app ne produit jamais de texte explicatif à la manière d'un pronostiqueur ("il devrait revenir en forme", "retrouve son driver habituel") — un jugement sur un cheval s'exprime toujours en chiffre ou en badge court, jamais en paragraphe narratif.

Le ton reste honnête plutôt que vendeur, sur deux plans distincts — cohérent avec le PRD (§1 Vision, limite assumée) : le risque financier du jeu (rappel systématique, aucun modèle ne garantit un gain) **et** les limites du modèle lui-même — il ne voit ni l'information tactique de dernière minute (changement de driver, intention de course rapportée par un entraîneur) ni ne prétend surpasser le jugement d'un expert humain, faute de preuve établie à ce stade. Les emojis fonctionnels (🐎 ⚠️ ✨ 🔥) servent de repères d'état rapides à l'œil sur un tableau dense, pas de décoration — cohérent avec la voix déjà établie dans les deux prototypes validés.

Le service est payant depuis le 2026-11-15 (PRD §10), sans que l'identité change : les écrans de compte, d'offres et de paiement gardent la même sobriété que le tableau des cotes. Un verrou dit ce qu'il débloque et pour quel palier, sans flou, sans compte à rebours, sans promesse de gain ; une offre se lit comme une ligne de tarif, pas comme une affiche. On paie l'outil, jamais un pari.

## Colors

- **`bg` (`#0B1120`)** — Fond de l'app, bleu-nuit quasi noir. Jamais de blanc pur nulle part dans l'interface — le produit est sombre par nature, pas par thème optionnel (EXPERIENCE.md.Foundation : pas de mode clair en V1).
- **`surface` (`#131C2E`) / `surface-2` (`#0F1728`)** — Deux tons de panneau pour la stratification (carte au-dessus du fond, champ de saisie au-dessus de la carte). La hiérarchie se lit par la teinte, jamais par une ombre portée (voir Elevation & Depth).
- **`gold` (`#E8B33C`)** — L'unique accent de marque, réservé au **signal principal**. Liste fermée de ses usages : l'action principale (`cta-primary` : "Calculer", « Je retiens ce pronostic », et sur les surfaces du compte « Recevoir le code », « Payer »), le badge de dossard, le titre d'écran et les en-têtes de section en `label`, la barre "modèle" de la jauge de probabilité, le cheval classé n°1, le bandeau d'import IA à vérifier, l'indicateur de focus — et, pour le Multi : la « confiance élevée » seulement (bordure, teinte `gold-dim`, titre de la `confidence-card`, toujours doublés du libellé « Confiance élevée »), la base (bordure de la `base-chip` activée, étiquette texte « Base » d'une `multi-row`, dossards des bases dans la `tickets-sheet`). Les confiances « moyenne » et « faible » et la formule « Affichée » ne sont jamais en or. Les surfaces du service payant n'ajoutent aucun usage de l'or : `locked-feature`, `teaser-banner`, `offer-card`, `payment-status` (y compris « actif »), palier et date de fin du droit restent en `text`/`muted`. Chacun de ces usages porte sa redondance non-couleur (voir Elevation & Depth). Aucun autre usage n'est permis : ne jamais l'utiliser pour de la simple décoration — s'il est or, c'est que c'est le signal le plus important de son contexte.
- **`green` (`#3DD68C`) / `red` (`#E5533D`)** — Exclusivement pour la value (positive/négative) et le malus d'incident. Jamais utilisés pour un statut générique de succès/erreur système — ni pour un paiement confirmé ou échoué, ni pour un code faux — — ce vocabulaire chromatique est réservé au jugement du modèle sur un cheval, pour ne jamais le confondre avec un état d'interface (chargement réussi, erreur réseau).
- **`blue` (`#5B9BD5`)** — Exclusivement la probabilité implicite du marché (la cote), en contrepoint de l'or (le modèle). Les deux couleurs côte à côte *sont* la promesse produit — le contraste modèle/marché rendu visuellement immédiat.
- **`text` (`#E7E4DA`) / `muted` (`#8B93A7`)** — Texte principal légèrement chaud (pas blanc pur, cohérent avec le fond navy) ; texte secondaire pour les libellés, unités, méta-informations.
- **`on-gold` (`#14100A`)** — Texte quasi noir posé sur un fond `gold` (badge de dossard, CTA principal) : 9,88:1. Jamais utilisé ailleurs.
- **`line-card` (`rgba(255,255,255,.36)`)** — Bordure renforcée réservée à la délimitation des cartes, panneaux et champs (voir Elevation & Depth) : contraste mesuré une fois composé sur son fond — 3,31:1 sur `bg` et `surface`, 3,32:1 sur `surface-2` (la valeur précédente, .32, plafonnait à 2,86-2,89:1 et ne passait pas) — condition non négociable puisque le système bannit l'ombre portée comme mécanisme de séparation. `line` et `line-2` (plus discrètes) restent réservées aux séparateurs internes à faible enjeu (ex. pied de ligne d'un `settings-row`), jamais à une limite entre deux objets d'interface distincts dans un flux continu.

Seule exception à la règle « fond sombre partout » : le QR code d'appairage (`qr-pairing`) est tracé en modules `bg` sur une zone calme `text`, parce que les lecteurs de QR courants lisent mal un code inversé (clair sur sombre). Aucune couleur nouvelle n'est créée pour cela, et `text` n'est pas du blanc pur.

`line`, `line-2`, `line-card` et `gold-dim` sont volontairement des valeurs rgba (et non des hex) : ce sont des voiles posés sur plusieurs fonds ; leurs contrastes sont toujours mesurés une fois composés sur le fond réel.

Paires interdites : `red` ou `green` sur la teinte `gold-dim` (3,86:1 pour le rouge — aucun `value-badge` dans une carte teintée) ; `muted` sur `gold-dim` composé sur `surface` (4,42:1). Sur la teinte de la « confiance élevée », les étiquettes passent en `text` (`confidence-card.tag-high`).

À éviter : tout dégradé, toute couleur d'accent supplémentaire (une seule couleur de marque), tout usage du vert/rouge en dehors du jugement value/incident, toute bordure de carte en `line`/`line-2` (réservées à l'usage interne à faible enjeu — voir `line-card`).

## Typography

Police système uniquement (Roboto sur Android via Flutter par défaut) — aucune police custom embarquée, décision confirmée pour rester proche du rendu natif et ne pas alourdir le binaire. `[ASSUMPTION: confirmé par l'utilisateur lors du cadrage UX — pas une inférence.]`

Règle non négociable, héritée des deux prototypes : **tout chiffre est en figures tabulaires** (`font-variant-numeric: tabular-nums` ou équivalent Flutter `FontFeature.tabularFigures()`), sans exception — scores, cotes, probabilités, mises, âges, poids. C'est ce qui permet à un tableau dense de rester lisible en colonnes alignées, y compris une fois transformé en cartes empilées sur mobile (voir Components).

Les libellés de champ et en-têtes de section sont en majuscules avec un `letter-spacing` ouvert (~0.5-0.8px) — signal visuel constant de "ceci est un libellé, pas une valeur".

Mapping vers l'échelle Material 3 (Flutter `TextTheme`), pour éviter toute improvisation en aval : `display` → `titleLarge` ; `label` → `labelSmall` (en majuscules via transformation, pas une variante de police séparée) ; `body` → `bodyMedium` ; `numeric` hérite systématiquement de la taille de son contexte d'usage (`bodyMedium` dans une carte, `labelSmall` dans une jauge) et n'ajoute que la fonctionnalité `FontFeature.tabularFigures()` — ce n'est jamais un palier de taille propre. Deux tailles nommées du Multi, pour ne pas improviser : la valeur du `size-stepper` (« 12 chevaux ») → `headlineSmall` (+ chiffres tabulaires) ; le titre de la `confidence-card` → `titleLarge`. Surfaces du compte : chiffres du `pin-pad` et de l'`otp-field` → `headlineSmall` (+ chiffres tabulaires) ; nom d'une `offer-card` → `titleMedium` `[ASSUMPTION]`, prix et dates en `numeric`. Taille minimale de `label` : 11sp — aucune étiquette (y compris « seuils provisoires », « modèle en cours d'évaluation », « Affichée », « hypothèse non validée ») ne descend en dessous.

## Layout & Spacing

Échelle : `{spacing.1}` 4px à `{spacing.6}` 32px. Les plus grands espacements séparent les sections majeures (entre panneaux) ; les plus petits séparent les éléments d'un même groupe logique (une ligne de performance, une paire libellé/valeur). Padding interne des cartes et panneaux : `{spacing.4}` (16px) à `{spacing.3}` (12px) selon la densité de la carte.

Colonne unique, verticale — pas de grille multi-colonnes sur mobile natif. Les grilles `auto-fit` du prototype web (course cible, grille de combinaisons) se traduisent en `Wrap`/`GridView` adaptatif à 1-2 colonnes selon la largeur d'écran réelle, jamais en défilement horizontal forcé pour du contenu qui peut s'empiler.

**Web app compagnon — layout large** (EXPERIENCE.md Responsive & Platform). Sur un écran d'ordinateur, deux colonnes : à gauche la liste des courses (programme, courses suivies), largeur fixe d'environ un écran de téléphone `[ASSUMPTION]`, à droite le détail de la course (partants, Résultats, Multi), mêmes composants, mêmes tokens. Gouttière `{spacing.6}` entre colonnes, séparation par une bordure `{colors.line-card}`, jamais par une ombre. Les cartes de la colonne de droite gardent leur largeur de lecture (pas d'étirement plein écran) `[ASSUMPTION]` ; les feuilles modales s'ancrent sur la colonne de droite. Sous la largeur d'un téléphone, retour à la colonne unique. Le QR d'appairage se centre sur l'écran de connexion, avec l'alternative « Se connecter par code SMS » à côté.

**Back-office — largeur d'ordinateur seulement** (EXPERIENCE.md, Back-office). Rail de navigation à gauche (`backoffice-shell`), contenu à droite en largeur de lecture ; formulaires sur une colonne, tables sur toute la largeur du contenu. Mêmes tokens, même thème sombre, mêmes règles (pas d'ombre, or réservé à sa liste fermée, `focus-indicator`). Aucun layout téléphone. Pas de maquette : spec seulement.

## Elevation & Depth

Design plat, sans ombre portée — hérité à l'identique des deux prototypes (aucun `box-shadow` n'y apparaît). La hiérarchie visuelle vient de la stratification tonale (`bg` → `surface` → `surface-2`) combinée à une bordure de carte en `{colors.line-card}` — jamais d'une ombre. Une carte ne "flotte" pas au-dessus du fond ; elle se distingue par sa teinte et par un contour effectivement perceptible : la stratification tonale seule (`surface`/`surface-2` contre `bg`) ne franchit pas le seuil de contraste UI et ne doit jamais porter la délimitation d'une carte à elle seule — c'est `line-card` qui porte cette responsabilité, à dessein plus marquée que les séparateurs internes `line`/`line-2`.

Mécanisme unique de mise en avant : la bordure devient `{colors.gold}` (au lieu de `{colors.line-card}`) pour signaler l'élément principal de son contexte. Liste fermée des cas, chacun avec sa redondance non-couleur obligatoire :

- cheval classé n°1 (`results-card`) — position en tête de liste triée ;
- cheval importé par IA à vérifier (`horse-card`) — bandeau texte "à vérifier" ;
- confiance élevée (`confidence-card`) — libellé « Confiance élevée » ;
- base activée (`base-chip`) — état de l'interrupteur et description « Base imposée dans tous les tickets ».

La bordure or n'est jamais le seul signal. Aucun autre état (sélection, survol, formule « Affichée », confiance moyenne ou faible, fonction verrouillée, offre mise en tête, paiement actif — focus excepté, voir `focus-indicator`) ne reçoit de bordure or ; tout ajout à cette liste exige la même redondance non-couleur et une mise à jour de Colors.

## Shapes

`{rounded.xs}` (6px) pour les petits éléments denses (badge de dossard, tags d'incident). `{rounded.sm}` (8px) pour les champs de saisie (dont `size-stepper`) et les bandeaux (`status-banner`). `{rounded.md}` (10px) pour les boutons (dont les touches du `pin-pad`) ; `{rounded.sm}` aussi pour l'`otp-field` et le `payment-status`. `{rounded.lg}` (12px) pour les cartes et panneaux (carte cheval, carte résultat, panneau de section). Rien en coin totalement arrondi — pas de pilule, pas de cercle plein, cohérent avec l'esthétique "tableau de bord dense" plutôt que "app ludique".

## Components

- **Carte partant (horse-card)** — `{colors.surface}`, bordure `{colors.line-card}` (ou `{colors.gold}` si importé par IA et non vérifié). En-tête : dossard, nom, âge, poids, cote. Corps : tableau des performances passées, indicateur de régularité, indicateur de fragilité au saut si course d'obstacle. Bandeau `status-banner-import` visible tant que les champs importés par IA n'ont pas été vérifiés par l'utilisateur.
- **Carte résultat (results-card)** — Sur mobile, chaque cheval du classement est une carte empilée (jamais un tableau à défilement horizontal — pattern déjà validé dans la version mobile du prototype HTML, où `table.res` devient une liste de cartes avec libellé préfixé par ligne). Bordure `{colors.line-card}`, ou `{colors.gold}` + fond `{colors.gold-dim}` en tinte légère pour le cheval n°1 uniquement. Porte, entre autres valeurs : score, cote, value, jauge de probabilité, indicateur de régularité, **mise suggérée** (`stake-text` en `{colors.green}`, gras — masquée, texte `stake-hidden` en `{colors.muted}`, jamais un simple zéro, quand le Kelly brut est négatif ou la cote manquante).
- **Badge de dossard (dossard-badge)** — Fond `{colors.gold}`, texte `{colors.on-gold}`, coin `{rounded.xs}`. Seul badge plein-couleur du système — réservé à l'identification du cheval, jamais réutilisé pour autre chose. Variante contour (`outline-*` : fond `surface`, texte `muted`, bordure `line-card`) réservée aux chevaux écartés du Multi, toujours doublée du sous-titre « Écartés les plus proches » et du préfixe « Écarté : ».
- **Badge de value (value-badge)** — Texte en gras, `positive` `{colors.green}`, `negative` `{colors.red}`, `unknown` `{colors.muted}` ; toujours avec le mot « Value », le signe (+/−) et le pourcentage. Jamais posé sur la teinte `gold-dim` (voir Colors). Écran Résultats uniquement : jamais dans le Multi, qui ne parle que de la probabilité d'être dans les 4 premiers.
- **Indicateur de régularité (regularity-indicator)** — Texte seul (jamais une pastille de couleur nue), sur l'échelle `high` (vert, "Très régulier"/"Régulier"), `medium` (or, "Moyen"), `low` (rouge, "Irrégulier"), `unknown` (muted, "Historique court"/"Données non saisies"/"🐎 Inédit" — ces trois derniers libellés partagent le token `unknown` mais restent des libellés distincts, jamais fusionnés en un seul texte générique).
- **Indicateur de fragilité au saut (fragile-indicator)** — Courses d'obstacle uniquement. Texte `{colors.red}` + icône ⚠️, affiché seulement si ≥ 2 chutes et taux de chute ≥ 34 % ("⚠️ Sauteur fragile (N chutes/N perfs)") ; en dessous de ce seuil, mention neutre en `muted` ("N chute(s)") sans icône d'alerte.
- **Jauge de probabilité (probability-gauge)** — Deux barres horizontales superposées : `fill-model` en or, `fill-market` en bleu, sur une piste `track` en `{colors.surface}` bordée de `track-border` (`{colors.line-card}`) — jamais `{colors.surface-2}` comme piste quand la jauge vit dans une `results-card` (même fond que son conteneur, piste invisible sinon). Toujours accompagnée d'un libellé texte des deux valeurs (jamais la barre seule — voir Accessibility Floor côté EXPERIENCE.md).
- **Bloc combinaison (combo-block)** — `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`, titre en `label`. Numéros de dossard en gras, probabilité en `{colors.green}`, noms des chevaux en `muted` tronqués.
- **Bandeau d'import IA (status-banner-import)** — Fond `{colors.gold-dim}`, texte `{colors.gold}` — signale "à vérifier", jamais "confirmé" tant que l'utilisateur n'a pas interagi avec la carte. Non tapable en lui-même (informatif seulement) ; disparaît au niveau de la carte entière, pas champ par champ (voir EXPERIENCE.md.Component Patterns pour la règle de disparition).
- **CTA principal (cta-primary)** — Fond plein `{colors.gold}`, texte `{colors.on-gold}`, coin `{rounded.md}`, toujours en majuscules. Un seul CTA plein par écran ("Calculer le classement" ; « Je retiens ce pronostic » sur le Multi).
- **CTA secondaire (cta-ghost)** — Fond `{colors.surface}`, bordure `{colors.line-card}`, texte `{colors.text}`. Utilisé pour toutes les actions non primaires (ajouter, importer, réinitialiser).
- **Ligne de réglage (settings-row)** — Libellé à gauche en `muted`, valeur/contrôle à droite en `text`, séparateur `{colors.line}` en pied de ligne (séparateur interne à faible enjeu, pas une limite de carte — voir Colors). Pas de carte englobante — liste simple, cohérent avec la densité assumée du produit.
- **Feuille d'import (import-sheet)** — Fond `{colors.surface}`, coins arrondis en haut uniquement (`{rounded.lg}`), icônes d'action (caméra/galerie/PDF) en `{colors.gold}`.
- **Taille de la sélection (size-stepper)** — Contrôle à pas, jamais un champ libre : `{colors.surface}`, bordure `{colors.line-card}`, coin `{rounded.sm}` (règle des champs, voir Shapes). Libellé « Taille de la sélection » en `label` ; valeur « 12 chevaux » au centre en `headlineSmall` + chiffres tabulaires ; boutons « − » et « + » de 48dp × 48dp minimum de part et d'autre, en `button-text` (`text`) ; à une borne (4, ou 20 / nombre de partants analysés), le bouton concerné passe en `button-disabled-text` (`muted`) et en état désactivé, jamais masqué. Aucun symbole « € », aucun montant.
- **Carte confiance (confidence-card)** — Signal principal du Multi. `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`, titre en `titleLarge` : « Confiance élevée », « Confiance moyenne » ou « Confiance faible ». Confiance élevée seulement : bordure `border-high` (`{colors.gold}`) + teinte `background-high-tint` (`{colors.gold-dim}`), titre en `title-high` (or) — toujours redondant avec le libellé texte — et étiquettes en `tag-high` (`text`). Confiances moyenne et faible : titre en `title-other` (`text`), sans or ni teinte, étiquettes en `tag` (`muted`) — jamais de rouge pour « faible » (rouge réservé aux incidents et à la value négative). Corps : trois paires libellé/valeur en `numeric` — « Arrivée dans la sélection » (pourcentage estimé), « Ouverture de la course », « Données » — puis étiquettes « modèle en cours d'évaluation » / « seuils provisoires » en `label` (11sp minimum). Pendant la pause qui suit un changement de taille, l'ancien contenu reste affiché à `pending-opacity` jusqu'au recalcul. Aucun vert/rouge sur la teinte.
- **Ligne de formule (formula-row)** — Une ligne par formule (tickets de 4 à 7) dans la section Systèmes : `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`. Formule en gras, puis « N tickets · N tickets physiques » en `numeric`. Formule affichée (celle dont « Voir les grilles » ouvre les tickets) : étiquette texte « Affichée » en `displayed-tag` (`text`), sans bordure or, et texte de garantie dépliée sous la ligne en `guarantee-text` (`muted`) — jamais en vert ni en or. Aucun coût, prix ni rapport. Aux grandes tailles de police, les chiffres s'enroulent sur plusieurs lignes, jamais coupés.
- **Ligne cheval Multi (multi-row)** — Liste sans carte englobante, séparateur `{colors.line}`, hauteur ≥ 48dp. `dossard-badge` plein en tête pour les chevaux retenus, variante contour pour les écartés (`excluded-dossard`) ; étiquette « Base » en texte or (`base-tag`) ; nom et explication des écartés en `muted`. Aucun `value-badge` : la value reste sur Résultats. Les échanges suggérés et les actions « + Ajouter un cheval » / « Saisir ma propre sélection » suivent la liste en `cta-ghost`.
- **Cheval le plus probable — base candidate (base-chip)** — Section « Chevaux les plus probables ». `{colors.surface}`, bordure `{colors.line-card}`, coin `{rounded.md}`, `{colors.gold}` quand activée (doublée par l'état de l'interrupteur et la description « Base imposée dans tous les tickets » / « Interdite comme base »). Porte toujours son top 4 estimé en chiffres, son effet en points et les tickets économisés pour la formule affichée (texte `muted`). La puce entière est la cible (≥ 48dp de haut).
- **Feuille des grilles (tickets-sheet)** — Comme `import-sheet` : `{colors.surface}`, coins hauts `{rounded.lg}`. Dossards des bases en or, en gras et en première colonne ; tickets en `numeric`, regroupés par ticket physique dans des cadres `surface-2` bordés `line-card`. Colonne de numéro de ticket à largeur automatique (« T10 » jamais coupé) ; aux grandes tailles, chaque ticket devient une ligne de texte (« T10 : 11 · 2 · 3 · 4 · 7 · 8 · 15 »). « Copier les grilles » (`cta-ghost`) reste épinglé en bas de la feuille sur `pinned-action-background`, bordure haute `pinned-action-border-top`.
- **Ligne de pronostic retenu (debrief-row)** — Liste simple, séparateur `{colors.line}` ; « En attente du résultat » en `muted` ; résultat en `text` (aucune couleur de réussite ou d'échec — pas de gamification, ni or ni vert pour « oui »). Chaque ligne commence par son sujet en `label` (« Votre pronostic », « Pronostic du modèle »).
- **Barre d'action Multi (multi-action-bar)** — Fond `{colors.bg}`, bordure haute `{colors.line-card}`, padding `{spacing.3}`. Porte le `cta-primary` « Je retiens ce pronostic » et le `cta-ghost` « Voir les grilles ». Posée **sous** la zone défilante, jamais par-dessus le contenu.
- **Bandeau d'état Multi (status-banner)** — Neutre : fond `{colors.surface}`, bordure `{colors.line-card}`, coin `{rounded.sm}`, texte `{colors.text}`, préfixe emoji fonctionnel (ℹ️, ⚠️). Variante « avertissement fort » (données fragiles, modèle pas meilleur que le marché) : bordure `border-strong` (2px `text`) et titre en gras — jamais vert, rouge ni or (le rouge reste aux incidents, l'or au signal principal ; `status-banner-import` reste propre à l'import IA).
- **Bloc évaluation (evaluation-block)** — `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`. Paires libellé/valeur en `numeric` ; distribution des chevaux capturés (0 à 4) en cinq lignes texte « N capturé(s) : X % », chacune avec une barre `distribution-bar` (`muted`) sur piste `distribution-track` (`surface`) — la barre ne porte rien seule, le pourcentage est toujours écrit. Aucun montant, rapport ni indice de valeur.
- **Section Autres méthodes (other-methods-section)** — En-tête repliable en `cta-ghost` ; déplié : un panneau `{colors.surface-2}` bordé `line-card`, coin `{rounded.lg}`, par comparateur (méthode 1, marché), dossards en `dossard-badge`, règle appliquée en `muted`, étiquette « hypothèse non validée » en `hypothesis-tag` ; performances (effectif, intervalle) en `numeric` seulement au-delà de l'effectif minimal.
- **Badge Multi (multi-badge)** — Texte `label` « Multi » en `text` sur fond transparent, bordure `line-card`, coin `{rounded.xs}` (carte de course de l'Accueil). Variante « Multi indisponible » en `unavailable-text` (`muted`) sur Résultats. Jamais plein-couleur (le plein reste au dossard).
- **Feuille d'actions cheval (multi-actions-sheet)** — Comme `import-sheet` : `{colors.surface}`, coins hauts `{rounded.lg}`. Titre = dossard + nom ; une rangée de 48dp par action ; bouton « Fermer » visible.
- **Sélecteur de chevaux (horse-picker-sheet)** — Comme `import-sheet`. Liste des partants analysés non retenus (dossard, nom, top 4 estimé) ; partants non analysés grisés en `unanalysed-text` (`muted`) avec la mention texte « à analyser ».
- **Saisie d'un système (system-entry-sheet)** — Comme `import-sheet`. Formule, sélection et bases en champs `{rounded.sm}`, tickets saisis ligne à ligne en `numeric` ; résultat de la vérification en `status-banner`.
- **Étiquettes d'état du Multi (sans token distinct)** — « Modifiée », « Ajouté par vous », « Pronostic retenu à 9 h 52 », « 🔒 Pronostic figé au départ (15 h 05) », « Modifiable jusqu'au départ (15 h 05) », « Cotes de 9 h 38 » : `label` en `muted`, jamais une couleur seule.
- **Indicateur de focus (focus-indicator)** — Contour `{colors.gold}` 2px, décalage 2px — cohérent avec le principe "or = signal exceptionnel". S'applique à tout élément interactif au clavier/navigation externe (rare sur mobile tactile, mais requis pour la conformité et les claviers externes/accessoires) — et en permanence au clavier sur la web app.
- **Fonction verrouillée (locked-feature)** — Occupe la place du contenu verrouillé, à sa taille réservée : panneau `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`. Glyphe 🔒 (décoratif), libellé de ce qui est débloqué en `label` (`text`), palier en `tier-text` (`muted`), puis `cta-ghost` « Voir les offres ». Jamais de flou, de voile ou de contenu grisé dessous (le contenu n'est pas reçu) ; jamais d'or. Variante compacte dans une `results-card` : une ligne de 48dp de haut minimum.
- **Aperçu d'instantané (teaser-banner)** — Comme un `status-banner` neutre : `{colors.surface}`, bordure `{colors.line-card}`, coin `{rounded.sm}`, texte `text` (« Le classement a changé à H-10 pour 3 chevaux »), palier qui le débloque en `tier-text` (`muted`). Chiffres en `numeric`. Ni or, ni vert, ni rouge, ni animation.
- **Pavé de code PIN (pin-pad)** — Grille 3 × 4 (chiffres, « Effacer »), touches `key-background` (`surface`) bordées `line-card`, coin `{rounded.md}`, 48dp × 48dp minimum (plus grandes si la largeur le permet), chiffres en `headlineSmall` tabulaires. Au-dessus, 4 à 6 points : pleins en `text` une fois saisis, vides en contour `line-card`. Erreur dite en texte `text` sous les points, jamais en rouge.
- **Champ de code SMS (otp-field)** — Une rangée de cases (une par chiffre) formant un seul champ : `{colors.surface}`, bordure `{colors.line-card}`, coin `{rounded.sm}`, 48dp de haut minimum, chiffres en `headlineSmall` tabulaires, aide en `hint` (`muted`). Case active signalée par le `focus-indicator`, pas par une autre couleur.
- **Carte d'offre (offer-card)** — `{colors.surface-2}`, bordure `{colors.line-card}`, coin `{rounded.lg}`. Nom de l'offre en `title`, palier et durée en `label`, prix en `numeric` (`price`, `text`), ce qu'elle débloque en `unlocks-text` (`muted`). Tap sur toute la carte → Paiement. Aucune mise en avant colorée (ni or, ni badge « populaire ») ; l'offre qui répond au verrou touché est simplement en tête.
- **Ligne d'appareil (device-row)** — Liste simple comme `settings-row` : séparateur `{colors.line}`, hauteur ≥ 48dp, nom en `name` (`text`), dernière activité et « Cet appareil » / « Nouveau » en `meta` (`label`, `muted`), « Retirer » en `cta-ghost` à droite.
- **QR d'appairage (qr-pairing)** — Cadre bordé `line-card`, coin `{rounded.lg}` ; QR en modules `bg` sur zone calme `text` (exception justifiée en Colors), assez grand pour être lu à 30 cm environ d'un écran d'ordinateur `[ASSUMPTION]`. Temps restant en `countdown-text` (`muted`, `numeric`), texte et non anneau seul.
- **Statut de paiement (payment-status)** — Comme un `status-banner` : `{colors.surface}`, bordure `{colors.line-card}`, coin `{rounded.sm}`, texte `text`. « En attente de confirmation » accompagné d'un indicateur de progression discret en `muted` ; « actif jusqu'au … » sans couleur de succès ; « échec » en variante forte (`border-failed`, 2px `text`, titre en gras) — jamais vert ni rouge.
- **Course suivie (followed-race)** — Étoile ★ (pleine si suivie, contour si non suivie) en `star-on` (`text`) / `star-off` (`muted`), jamais en or : suivre une course n'est pas le signal principal de l'écran (liste fermée de l'or : Colors). Cible de 48dp × 48dp minimum, état doublé par la sémantique de l'interrupteur. Ligne de la section « Courses suivies » : liste simple comme `device-row`, séparateur `{colors.line}`, heure de départ en `time` (`text`, `numeric`), réunion, course et hippodrome en `meta` (`muted`), `multi-badge` si éligible, étoile à droite.
- **Coquille du back-office (backoffice-shell)** — Back-office seulement (largeur d'ordinateur). Rail de navigation à gauche sur `rail-background` (`surface-2`), séparé du contenu par une bordure `line-card`, jamais une ombre ; élément actif en `rail-item-selected-text` (`text`) sur `rail-item-selected-background` (`surface`), toujours doublé de l'état « sélectionné » ; autres éléments en `muted`. Contenu sur `bg`. Tables Material 3 : en-têtes en `label` (`muted`), lignes séparées par `{colors.line}`, chiffres et dates en `numeric`. Actions en `cta-primary` (une seule par écran : « Soumettre », « Approuver », « Créer ») et `cta-ghost` ; « Rejeter », « Révoquer », « Désactiver » en `cta-ghost`, jamais en rouge (le rouge reste à la value et aux incidents). Champs en `{rounded.sm}`, panneaux en `{rounded.lg}`. Pas de vert ni de rouge pour les statuts (en attente, approuvée, rejetée) : texte en `label`.
- **Écart de correction (correction-diff)** — Panneau `surface-2`, bordure `line-card`, coin `{rounded.lg}`. Entité et champ en `label` ; « valeur actuelle → valeur proposée » sur une ligne, valeur actuelle en `current-value` (`muted`), valeur proposée en `proposed-value` (`text`, gras), chiffres en `numeric` ; auteur, heure et motif en `meta` (`muted`). Aucune couleur de succès ou d'erreur ; aucun barré seul pour l'ancienne valeur (elle reste lisible).
- **Étiquettes du compte (sans token distinct)** — « Palier Expert · actif jusqu'au 22/11 », « Pronostic de 14 h 35 · H-30 », « ajusté », « Mode expert — vos réglages », « modèle en cours d'évaluation », « Compte K7QD2M » : `label` en `muted`, comme les étiquettes d'état du Multi.

→ Référence de composition : `mockups/resultats.html` (results-card, probability-gauge, combo-block, stake), `mockups/liste-partants.html` (horse-card, status-banner-import, cta-primary, cta-ghost), `mockups/fiche-cheval.html` (horse-card en édition, feuille de performance), `mockups/accueil.html` (listes de courses, état vide), `mockups/configuration-course.html` (champs de configuration, sélecteur de terrain groupé), `mockups/import-photo.html` (import-sheet et ses états). `mockups/multi.html` (size-stepper, confidence-card, multi-row, base-chip, formula-row, evaluation-block, other-methods-section, multi-action-bar, tickets-sheet — pronostic sans argent, recadrage du 2026-10-18). À produire (sprint-change-proposal-2026-11-15 U-6) : `mockups/connexion.html` (otp-field, pin-pad), `mockups/offres-paiement.html` (offer-card, payment-status, locked-feature, teaser-banner), `mockups/mes-appareils.html` (device-row, approbation d'appairage), `mockups/web-compagnon.html` (layout large en deux colonnes, qr-pairing). Sans maquette (spec seulement) : `followed-race`, `backoffice-shell`, `correction-diff`. La spine gagne en cas de conflit avec une maquette.

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
| Multi : l'or pour la « confiance élevée » et la base seulement (liste fermée : Colors) | Or ou vert pour « garantie », la formule « Affichée », une confiance moyenne ou un débrief « oui » ; rouge pour « confiance faible » |
| Multi : un pronostic sans argent — tailles en chevaux, systèmes en tickets | Tout symbole « € », coût, mise, gain, rapport ou prix dans le Multi |
| Bandeaux d'état Multi en `status-banner` neutre | Rouge pour un état système ; `status-banner-import` hors de l'import IA |
| Contenu verrouillé remplacé en place par un `locked-feature` qui dit ce qu'il débloque et pour quel palier | Flouter, griser ou voiler un contenu pour le vendre ; or sur un verrou ou une offre |
| Paiement et codes dits en texte neutre (`payment-status`, variante forte pour l'échec) | Vert pour « paiement confirmé », rouge pour « échec » ou « code incorrect » |
| Offres sobres : nom, palier, durée, prix, ce qu'elle débloque, rappel de jeu responsable | Compte à rebours, badge « populaire », « gagnez plus », toute promesse de gain |
| Web app en deux colonnes avec les mêmes composants et tokens | Composants ou couleurs propres au web ; ombres pour séparer les colonnes |
