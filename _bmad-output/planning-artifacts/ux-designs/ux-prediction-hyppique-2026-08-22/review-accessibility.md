# Revue accessibilité — Analyseur Hippique (DESIGN.md + EXPERIENCE.md)

Relecture ciblée sur ce que les deux spines engagent réellement : contraste (valeurs calculées à partir des tokens hex documentés), daltonisme (signal produit vert/rouge/or/bleu), lecture TalkBack de cartes denses, cibles tactiles vs densité assumée, et accessibilité du rappel de jeu responsable.

Méthode pour le contraste : ratios calculés selon la formule de luminance relative WCAG (sRGB → luminance linéaire → `(L1+0.05)/(L2+0.05)`) directement à partir des valeurs hex de `DESIGN.md.colors`, y compris pour les couleurs translucides (`line`, `line-2`, `gold-dim`) après compositing sur leur fond réel.

---

## 1. Contraste

### 1.1 — [BLOQUANT] La stratification tonale sans ombre ne franchit jamais le seuil de perceptibilité UI (3:1)

`DESIGN.md` §Elevation & Depth pose comme principe non négociable (repris dans Do's and Don'ts) que la hiérarchie visuelle vient *exclusivement* de la teinte (`bg → surface → surface-2`) et de bordures fines, « jamais d'une ombre ». J'ai calculé les ratios réels entre ces tons :

| Paire | Ratio calculé |
|---|---|
| `surface` (#131C2E) vs `bg` (#0B1120) | **1.11:1** |
| `surface-2` (#0F1728) vs `bg` (#0B1120) | **1.05:1** |
| `surface-2` (#0F1728) vs `surface` (#131C2E) | **1.05:1** |
| `line` (rgba(255,255,255,.08)) sur `surface` | **1.25:1** (composité ≈ rgb(38,46,63)) |
| `line-2` (rgba(255,255,255,.14)) sur `surface` | **1.53:1** (composité ≈ rgb(52,60,75)) |

Ce sont exactement les paires utilisées pour distinguer une `horse-card` (`surface`) du fond d'écran (`bg`), ou un `combo-block`/`results-card` (`surface-2`) de son conteneur. Tous ces ratios sont très en dessous du seuil WCAG 1.4.11 (3:1) attendu pour qu'une limite de composant UI reste perceptible — et le système n'a *aucun* mécanisme de secours (pas d'ombre, bordure quasi invisible) pour compenser. Concrètement : un utilisateur avec une vision basse ou un écran mal calibré en plein soleil (contexte hippodrome, cf. UJ-2 « tribunes, connexion dégradée ») risque de ne pas distinguer où une carte empilée se termine et où la suivante commence, dans un flux qui est justement fait de cartes empilées continues (`DESIGN.md` §Components, `results-card`).

C'est un problème structurel, pas un détail : la contrainte « pas d'ombre » est présentée comme un choix esthétique définitif (Do's and Don'ts : « Ombres portées, élévation Material par défaut » est explicitement dans la colonne *Don't*), alors que le seul substitut (variation de teinte + bordure ~8-14% d'opacité) ne remplit pas la fonction qu'il est censé remplir en accessibilité.

### 1.2 — [MAJEUR] `probability-gauge.track` est littéralement la même couleur que son conteneur

`DESIGN.md` §Components : `probability-gauge.track = {colors.surface-2}`. Or la jauge de probabilité est utilisée dans `results-card`, dont le fond est *aussi* `{colors.surface-2}` (§Components, `results-card.background`). Le ratio de contraste entre les deux est donc **1:1** — la piste de la jauge (la partie non remplie, qui représente l'échelle 0-100%) est invisible sur sa propre carte. Seules les portions remplies (`fill-model` or, `fill-market` bleu) seront visibles, flottant sans repère de bord de piste. Cela n'empêche pas la lecture (le texte redondant « Modèle X % / Marché Y % » est bien prévu, cf. §2), mais visuellement, un utilisateur voyant ne peut pas juger d'un coup d'œil la proportion réelle d'une barre sans échelle visible — ce qui va à l'encontre de l'intérêt même d'une jauge. Aucun des deux documents ne mentionne ce conflit de token ; il est probable qu'il s'agisse d'un oubli (le track a sans doute été pensé pour un fond `surface`, pas `surface-2`).

### 1.3 — [MINEUR] `red` (#E5533D) en texte sur `surface`/`surface-2` : marge de conformité AA très fine

`green` sur `surface-2` : 9.54:1 (large marge). `red` sur `surface-2` : **4.80:1**, et `red` sur `surface` : **4.57:1** — tout juste au-dessus du seuil AA texte normal (4.5:1), sans marge de sécurité. Étant donné que `typography.numeric`/`label` vise des tailles très compactes (libellés ~11px, valeurs en colonnes serrées, `DESIGN.md` §Typography), toute variation de rendu (anti-aliasing, graisse de police système, sous-exposition d'écran) fait courir un risque réel de repasser sous 4.5:1 pour le texte négatif de `value-badge`. Ce n'est pas un échec avéré (le ratio calculé passe), mais une marge insuffisante pour un usage aussi dense en petits caractères — à vérifier avec la police système réelle avant gel.

### 1.4 — [POSITIF] Le reste de la palette est solide

`text` sur les trois fonds (13.4–14.8:1), `muted` (5.5–6.1:1), `gold` (8.9–9.8:1), `green` (9.1–10:1), `blue` (5.75–6.36:1), et `dossard-badge` (texte #14100A sur fond `gold`, 9.88:1) passent tous largement AA, y compris à la taille de libellé la plus compacte (~11px). Aucun souci de contraste texte-sur-fond en dehors des deux points ci-dessus.

---

## 2. Daltonisme — la couleur seule porte-t-elle jamais un signal ?

`EXPERIENCE.md` §Accessibility Floor affirme : « Aucune information n'est portée par la couleur seule » et donne deux exemples concrets bien traités :
- **Value positive/négative** (`Component Patterns`, ligne `value-badge`) : « Signe (+/−) et libellé texte toujours présents avec la couleur — jamais la couleur seule ». Confirmé cohérent avec `DESIGN.md` (le badge n'est pas « plein-couleur », contrairement au `dossard-badge` qui est explicitement désigné comme « seul badge plein-couleur du système »).
- **Jauge modèle/marché** : toujours accompagnée du texte « Modèle X % / Marché Y % ». Bien traité.
- **Badges d'état** (Inédit, Historique court) : « toujours du texte, jamais une pastille de couleur nue ». Bien traité.

Mais l'affirmation « jamais la couleur seule » n'est **pas vérifiée partout** où une couleur sémantique or apparaît :

### 2.1 — [MAJEUR] « Cheval sélectionné » : signal 100% couleur, sans aucune redondance

`DESIGN.md` §Elevation & Depth (ligne « Exception unique ») : la bordure devient `{colors.gold}` pour trois états distincts — *cheval classé n°1*, *cheval importé par IA à vérifier*, et *cheval sélectionné*. Les deux premiers ont une redondance ailleurs dans le document (tinte de fond + position de liste pour le n°1 ; bandeau texte « à vérifier » pour l'import IA, `status-banner-import`). L'état **« cheval sélectionné »** n'est mentionné nulle part ailleurs dans `DESIGN.md` ni `EXPERIENCE.md` — aucun composant, aucune ligne du tableau State Patterns, aucune note TalkBack ne le reprend. Tel que spécifié, c'est un signal couleur seule, en contradiction directe avec la règle que `EXPERIENCE.md` s'impose elle-même dans §Accessibility Floor.

### 2.2 — [MINEUR] « Cheval classé n°1 » : la redondance existe mais n'est pas explicite

`results-card` (n°1) combine bordure or + fond `gold-dim` en tinte (`DESIGN.md` §Components), et la position en tête de liste triée (`EXPERIENCE.md` §Component Patterns : « Empilées, triées par score décroissant ») constitue une redondance non-couleur *de fait*. Mais aucun texte/chiffre de rang explicite (« 1er », médaille, etc.) n'est spécifié — seul le `dossard-badge` (numéro de dossard, pas de rang) est mentionné comme contenu de l'en-tête. Pour un utilisateur qui scrolle et atterrit au milieu de la liste sans repartir du haut, la position seule est un indice faible ; combinée à une éventuelle confusion daltonienne sur la tinte `gold-dim` (très subtile, cf. 1.1), le signal « c'est le n°1 » repose in fine presque entièrement sur la couleur. `EXPERIENCE.md` §Accessibility Floor ne couvre pas explicitement ce cas dans son inventaire des signaux non-couleur, alors qu'il prétend une couverture générale.

### 2.3 — [POSITIF] Le choix or/bleu pour modèle/marché est un bon choix daltonien, indépendamment du filet de sécurité texte

`gold` et `blue` se situent sur l'axe jaune-bleu plutôt que rouge-vert — l'axe le moins affecté par les formes courantes de daltonisme (proto/deutéranopie). Bon choix, même si le filet de texte obligatoire (§1 ci-dessus) rend la question secondaire.

---

## 3. Lecteur d'écran sur données denses — ordre de lecture non spécifié

`EXPERIENCE.md` §Accessibility Floor ne couvre que deux choses côté TalkBack : (a) rôle/état sur les éléments interactifs, et (b) l'annonce texte de la jauge de probabilité (« Modèle 12,4 pour cent, Marché 8,3 pour cent »).

**Rien n'indique l'ordre ou le regroupement de lecture** pour une `horse-card` ou une `results-card`, alors que `DESIGN.md` §Brand & Style décrit explicitement la densité de cette carte : « un cheval porte simultanément son score, sa cote, sa value, ses quatre probabilités de place et sa régularité ». Sur une carte résultat, on ajoute âge, poids, mise suggérée. C'est facilement 10+ valeurs numériques empilées par carte.

Aucun des deux documents ne précise :
- si ces champs doivent être annoncés comme un seul nœud sémantique groupé (« Cheval 4, Untel, 5 ans, 58kg, cote 3,5, score 82, value +12 %... ») ou comme des nœuds séparés navigables un par un ;
- un ordre de priorité de lecture (ex. : nom → statut/badge → score → value → détail sur demande) qui éviterait à un utilisateur TalkBack de devoir swiper à travers 10+ valeurs plates avant d'atteindre l'information décisive (value, incident) ;
- si le libellé de chaque valeur doit être répété à chaque champ (« score : 82. cote : 3,5. » — verbeux mais explicite) ou porté par un seul en-tête de carte.

C'est une lacune réelle et concrète : un développeur consommant cette spine n'a aucune base pour décider entre « tout aplatir » (résultat probablement inutilisable — traversée de 10 champs muets par navigation par swipe) et un regroupement structuré. Vu que `EXPERIENCE.md` prend déjà la peine de spécifier le pattern d'annonce pour la jauge (un cas relativement simple), l'absence du même traitement pour la carte entière — le cas le plus dense et le plus critique de tout le produit — est l'angle mort le plus net du document sur ce plan.

---

## 4. Cibles tactiles vs densité assumée — contradiction non résolue

`DESIGN.md` §Brand & Style revendique la densité comme un parti pris : « La densité d'information est assumée, pas cachée derrière des écrans successifs ». L'échelle d'espacement va de 4px à 32px (`spacing.1`–`spacing.6`), avec un padding interne de carte de 12–16px (`spacing.3`–`spacing.4`) — cohérent avec l'esthétique « tableau de cotes », mais serré.

`EXPERIENCE.md` §Accessibility Floor exige en parallèle : « Cibles tactiles ≥ 48dp (Android), y compris dans les cartes denses (carte partant, ligne de performance) ».

Le point de friction concret : `EXPERIENCE.md` §Component Patterns décrit la **ligne de performance** (partie de `horse-card`, dans la Fiche cheval éditable) comme éditable — « Ligne vide = ignorée du calcul » — ce qui implique plusieurs champs distincts et modifiables par ligne (date, terrain, position, cote, au minimum). Avec :
- un espacement inter-éléments de 4-12px (`spacing.1`-`spacing.3`),
- une exigence de 48dp *par cible* dans cette même ligne,
- et l'exigence indépendante (même section) que la police honore « l'échelle d'accessibilité la plus large sans troncature ni chevauchement »,

rien dans les deux documents ne précise comment une ligne de performance à 5-6 champs éditables tient dans une carte empilée en largeur téléphone (~360-400dp) une fois chaque champ élargi à 48dp de cible tactile — a fortiori à l'échelle de police maximale, où le §Accessibility Floor reconnaît lui-même le risque de troncature/chevauchement *typographique*, mais ne traite jamais l'équivalent en collision de *cibles tactiles*. Aucune stratégie de repli n'est spécifiée (passage en édition plein écran par champ, empilement vertical des champs de la ligne au lieu d'un alignement horizontal, etc.). C'est une contradiction de fait entre deux exigences non négociables du document, laissée à l'implémentation sans arbitrage.

À noter en soutien : les séparateurs (`settings-row` : bordure `line` en pied de ligne, ratio ≈1.2:1 vs fond, cf. §1.1) sont eux aussi trop peu contrastés pour aider visuellement à délimiter où une cible tactile commence et finit dans une liste dense — ce qui aggrave légèrement le risque ci-dessus pour les utilisateurs à vision basse spécifiquement.

---

## 5. Rappel de jeu responsable — bien traité, aucune lacune trouvée

`EXPERIENCE.md` §Accessibility Floor, dernière puce : « Le rappel de jeu responsable n'est jamais dans un élément décoratif ignoré par le lecteur d'écran — il fait partie du flux de lecture normal de l'écran de résultats. » C'est explicite, actionnable, et directement adressé à l'inquiétude (pas de div `aria-hidden`/décoratif implicite).

Renforcé par deux autres endroits cohérents entre eux :
- `EXPERIENCE.md` §Voice and Tone : le rappel doit apparaître « sur chaque écran de résultats » et la colonne *Don't* interdit explicitement de l'omettre « même une fois, même sur un écran secondaire ».
- `DESIGN.md` §Do's and Don'ts : « Rappel de jeu responsable visible sur chaque écran de résultats » en *Do*.
- `EXPERIENCE.md` §State Patterns, ligne « Calcul terminé » : classement + grille de combinaisons + rappel de jeu responsable sont explicitement listés comme « toujours les trois ensemble » — le rappel n'est donc pas conditionnel à un état particulier.

Aucun point faible identifié ici : le contenu est protégé à la fois structurellement (jamais optionnel) et pour le lecteur d'écran (jamais décoratif).

---

## Résumé des findings

| # | Sévérité | Sujet | Section source |
|---|---|---|---|
| 1.1 | Bloquant | Stratification tonale (surface/bg ≈1.05-1.11:1) sans ombre ni bordure suffisante — limites de carte quasi invisibles | DESIGN.md §Elevation & Depth, §Colors |
| 1.2 | Majeur | `probability-gauge.track` = même token que le fond de `results-card` → contraste 1:1, piste invisible | DESIGN.md §Components (probability-gauge, results-card) |
| 2.1 | Majeur | État « cheval sélectionné » : bordure or seule, aucune redondance non-couleur nulle part dans les 2 docs | DESIGN.md §Elevation & Depth |
| 3 | Majeur | Aucun ordre/regroupement de lecture TalkBack spécifié pour les cartes denses (10+ valeurs numériques) | EXPERIENCE.md §Accessibility Floor |
| 4 | Majeur | Contradiction non résolue : densité assumée (spacing 4-12px) vs cibles 48dp dans la « ligne de performance » éditable, aggravée à l'échelle de police max | EXPERIENCE.md §Accessibility Floor, §Component Patterns ; DESIGN.md §Brand & Style, §Layout & Spacing |
| 1.3 | Mineur | `red` en texte sur `surface`/`surface-2` : 4.57-4.80:1, marge de conformité AA très fine pour du texte petit/dense | DESIGN.md §Colors, §Components (value-badge) |
| 2.2 | Mineur | « Cheval n°1 » : redondance de fait (position/tri) mais non explicitée, tinte `gold-dim` subtile | DESIGN.md §Components (results-card) ; EXPERIENCE.md §Component Patterns |
| 1.4 | Positif | Contrastes texte-sur-fond (text, muted, gold, green, blue, dossard-badge) tous largement conformes AA | DESIGN.md §Colors |
| 2.3 | Positif | Value-badge, jauge, badges d'état : couleur toujours doublée d'un signal texte, conforme à la règle affichée | EXPERIENCE.md §Accessibility Floor, §Component Patterns |
| 5 | Positif | Rappel de jeu responsable : jamais décoratif, jamais omis, explicite dans le flux de lecture | EXPERIENCE.md §Accessibility Floor, §Voice and Tone, §State Patterns ; DESIGN.md §Do's and Don'ts |

**Total : 8 findings actionnables (2 bloquant/majeur sur le contraste, 1 majeur sur le daltonisme + 1 mineur, 1 majeur sur le lecteur d'écran, 1 majeur sur les cibles tactiles) + 3 points positifs confirmés.**
