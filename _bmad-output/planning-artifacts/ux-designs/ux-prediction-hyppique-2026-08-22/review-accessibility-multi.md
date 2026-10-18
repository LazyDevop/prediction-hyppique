# Revue accessibilité — écran Multi (ajout du 2026-10-17)

Périmètre : `DESIGN.md` (tokens et composants `budget-field`, `verdict-card`, `system-summary`, `multi-row`, `base-chip`, `option-row`, `tickets-sheet`, `debrief-row`), `EXPERIENCE.md` (Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor, UJ-4) et la maquette `.working/key-multi.html`. Référentiel : WCAG 2.2 AA et pratiques Android/TalkBack (Flutter Material 3). La revue précédente (`review-accessibility.md`) a été relue : les correctifs déjà intégrés (regroupement TalkBack des cartes denses, redondance non-couleur de la bordure or, piste de jauge, feuille d'édition dédiée pour les cibles 48dp) ne sont pas rediscutés, sauf quand le Multi s'en écarte.

Méthode pour le contraste : luminance relative WCAG calculée à partir des hex de `DESIGN.md.colors` ; couleurs translucides (`line-card`, `gold-dim`) composées sur leur fond réel.

## Verdict

**À corriger avant gel du Multi.** La palette texte tient (aucun échec de contraste texte sur les paires réellement utilisées), et le Multi applique bien la règle « jamais la couleur seule » pour le verdict, « Base », « Modifiée », « Dépasse le budget » et « Jeu figé ». Mais la spine ne dit rien de ce qui rend cet écran difficile pour un lecteur d'écran : il **change tout seul** (recalcul à chaque modification du budget, des bases, des non-partants, gel à l'heure du départ) et il **empile des surfaces modales** (feuille d'actions, feuille des grilles). Aucune annonce, aucune gestion du focus et aucun comportement de la barre basse fixe aux grandes tailles de police ne sont spécifiés. Un point bloquant, dix majeurs, six mineurs.

## Contrastes calculés (paires utilisées par le Multi)

| Paire (composant) | Ratio | Seuil | Statut |
|---|---|---|---|
| `text` sur `surface` / `surface-2` (valeurs, noms) | 13,39 / 14,07 | 4,5 | OK |
| `muted` sur `surface` (budget, base-chip, tickets-sheet) | 5,54 | 4,5 | OK |
| `muted` sur `surface-2` (verdict, system-summary, option-row) | 5,82 | 4,5 | OK |
| `muted` sur `bg` (multi-row, debrief-row, sans carte) | 6,12 | 4,5 | OK |
| `muted` sur `gold-dim` composé sur `surface-2` (étiquettes du verdict « jouer ») | **4,68** | 4,5 | OK, marge faible |
| `muted` sur `gold-dim` composé sur `surface` | **4,42** | 4,5 | **Échec si utilisé** |
| `gold` sur `gold-dim` composé sur `surface-2` (titre du verdict « jouer ») | 7,50 | 4,5 | OK |
| `gold` sur `surface` / `surface-2` / `bg` (Base, dossards des bases, étiquette « Recommandée ») | 8,87 / 9,33 / 9,81 | 4,5 | OK |
| `#14100A` sur `gold` (CTA, dossard) | 9,88 | 4,5 | OK |
| `green` / `red` sur `bg` (value-badge dans multi-row) | 10,04 / 5,05 | 4,5 | OK |
| `red` sur `gold-dim` composé sur `surface-2` | **3,86** | 4,5 | **Échec si utilisé** |
| `line-card` (rgba 255,255,255,.32) sur `bg` / `surface` / `surface-2` | **2,86 / 2,89 / 2,89** | 3,0 | **Échec** |
| Bordure `gold` sur `surface-2` (option recommandée, base active) | 9,33 | 3,0 | OK |
| Fond `gold-dim` vs `surface-2` (teinte du verdict « jouer ») | 1,24 | — | Décoratif, ne peut rien porter seul |

## Findings

### 1. [BLOQUANT] Recalcul en direct jamais annoncé — et potentiellement annoncé à chaque frappe

- **Emplacement** : `EXPERIENCE.md` Component Patterns `budget-field` (« toute modification relance le calcul local (pas de bouton) »), Interaction Primitives (« saisir ou modifier le budget recalcule immédiatement »), `base-chip` (interrupteur), `multi-row` (feuille d'actions) ; Accessibility Floor (aucune mention).
- **Problème** : quand le budget change, le verdict, le système recommandé et les options changent hors du focus (le focus reste dans le champ). Un utilisateur TalkBack ne sait pas que le verdict est passé de « 💶 Jouable avec 33 € » à « ✅ Jouable » — c'est pourtant la réponse à la seule question de l'écran (UJ-4). À l'inverse, une région live naïve annoncerait des états intermédiaires à chaque frappe (taper « 30 » passe par « 3 € » → « ⏸️ Passer »). Même chose après un basculement de base ou un retrait de cheval : le résumé du système change plus haut dans la page, sans retour.
- **Critères** : WCAG 4.1.3 Messages d'état ; 3.2.2 Saisie (changement de contexte inattendu) ; Android : `announceForAccessibility` / `liveRegion` polie.
- **Correctif (ligne à ajouter à l'Accessibility Floor)** : « Multi : le recalcul déclenché par le budget part à la validation (touche OK du clavier ou perte du focus) ou après 800 ms sans frappe — jamais à chaque caractère. Après un recalcul, une seule annonce polie résume ce qui a changé : "Verdict : jouable avec 33 euros. Système : 30 euros, couverture estimée 26 pour cent." Rien n'est annoncé si le verdict et le coût n'ont pas changé. Même annonce après un basculement de base, un retrait, un ajout ou un non-partant. Le focus ne bouge pas. » Visuellement, ne pas rendre de verdict intermédiaire pendant la frappe (garder l'ancien, atténué, jusqu'au recalcul).

### 2. [MAJEUR] `line-card` n'atteint pas 3:1, contrairement à ce qu'affirme `DESIGN.md`

- **Emplacement** : `DESIGN.md` Colors (« contraste vérifié ≥ 3:1 contre `surface` et `surface-2` ») ; tous les composants Multi bordés (`budget-field`, `verdict-card`, `system-summary`, `option-row`, `base-chip`, piste de l'interrupteur dans la maquette, cadres `.phys` de la feuille des grilles).
- **Problème** : rgba(255,255,255,.32) composé donne 2,86:1 sur `bg` et 2,89:1 sur `surface`/`surface-2`. Le correctif du finding 1.1 de la revue précédente ne passe pas le seuil qu'il revendique. Pour le Multi, c'est la seule limite visible du champ budget (champ éditable : sa limite est requise par 1.4.11) et de la piste de l'interrupteur désactivé.
- **Critère** : WCAG 1.4.11 Contraste du contenu non textuel.
- **Correctif (token)** : `line-card: 'rgba(255,255,255,.36)'` (3,31 / 3,31 / 3,32:1 ; .34 passe à 3,08-3,10 mais sans marge). Mettre à jour le texte de Colors avec les valeurs mesurées.

### 3. [MAJEUR] Les emojis des verdicts sont lus comme des boutons

- **Emplacement** : `EXPERIENCE.md` Voice and Tone (« ✅ Jouable » / « 💶 Jouable avec 33 € » / « ⏸️ Passer »), Component Patterns CTA (« 🔒 Jeu figé au départ (15:05) ») ; maquette (« Modifier ✎ », « Multiplicateur ×1 ▾ », « ▸ », « ⧉ Copier les grilles »).
- **Problème** : TalkBack lit le nom CLDR des emojis. En français : ✅ « bouton coché », ⏸️ « bouton pause », 💶 « billet en euros », 🔒 « cadenas fermé », ✎ « crayon », ⧉ souvent épelé ou ignoré. Le verdict devient « bouton pause Passer » : on croit à un contrôle, alors que la carte n'est pas tapable. L'Accessibility Floor donne bien l'annonce attendue (« Verdict : jouable avec 33 euros… »), mais pas la règle qui la garantit.
- **Critères** : WCAG 1.1.1 Contenu non textuel, 4.1.2 Nom, rôle, valeur ; Android : `contentDescription`.
- **Correctif (spine)** : « Les emojis et glyphes fonctionnels (✅ 💶 ⏸️ 🔒 ✎ ▾ ▸ ⧉) sont exclus de la sémantique (`ExcludeSemantics`) ; le libellé lu est le texte seul ("Verdict : passer", "Jeu figé au départ, 15 heures 05, lecture seule"). L'état d'un repli (▾ ▸) est porté par la sémantique déplié/replié, pas par le glyphe. » À appliquer aussi aux emojis existants (🔥 ⚠️ 🐎 ✨) par cohérence.

### 4. [MAJEUR] La barre basse fixe masque le focus et le contenu en grande taille de police

- **Emplacement** : `EXPERIENCE.md` CTA « Je retiens ce jeu » (« barre basse fixe ») ; maquette `.bar` (CTA plein + « Voir les grilles » superposés en `position:absolute`, réserve fixe `padding-bottom:130px`).
- **Problème** : à 200 % (Android 14), la barre (deux boutons de 48dp minimum, libellés qui passent sur deux lignes, marges) dépasse 180-200dp, soit près d'un tiers de l'écran, plus encore avec le clavier ouvert sur le budget. Une réserve fixe de 130px laisse le rappel de jeu responsable et la section « Autres méthodes » sous la barre. Un élément focalisé près du bas (dernière base, repli) peut se retrouver entièrement sous la barre : Flutter ne fait défiler pour garder le focus visible que si la barre réduit la zone du `body`, pas si elle est posée par-dessus.
- **Critères** : WCAG 2.4.11 Focus non masqué (minimum) ; 1.4.4 Redimensionnement du texte ; 1.4.10 Redistribution.
- **Correctif (spine)** : « La barre basse est portée par `Scaffold.bottomNavigationBar` (le contenu se termine au-dessus d'elle, jamais dessous). Elle se masque quand le clavier est ouvert. Au-delà de 130 % d'échelle de police, elle ne garde que le CTA plein, et "Voir les grilles" passe dans le flux, sous le résumé du système. Le rappel de jeu responsable reste atteignable et visible en fin de défilement. »

### 5. [MAJEUR] Feuille d'actions de `multi-row` : focus à l'ouverture, à la fermeture et après l'action non spécifié

- **Emplacement** : `EXPERIENCE.md` `multi-row` (« Tap → feuille d'actions : retirer, imposer, base oui/non, marquer non-partant ») ; Interaction Primitives.
- **Problème** : rien ne dit où va le focus. Pire, les actions « Retirer » et « Marquer non-partant » **suppriment ou déplacent la ligne d'origine** : le retour de focus habituel n'a plus de cible, et TalkBack retombe en haut de l'écran (sur le budget), loin de la sélection. Les options exclusives « base oui/non » et « imposer » doivent annoncer leur état courant.
- **Critères** : WCAG 2.4.3 Ordre de focus, 4.1.2 ; Android : modal bottom sheet (contenu sous-jacent masqué pour TalkBack, bouton retour système = fermer).
- **Correctif (spine)** : « Feuille d'actions : titre = "N° 7, Ondine Royale", focus initial sur ce titre ; le contenu dessous est inerte pour TalkBack ; fermeture par le retour système, le voile ou un bouton "Fermer" visible (la poignée seule ne suffit pas). Fermeture sans action → focus rendu à la ligne d'origine. Après "Retirer" ou "Marquer non-partant" → focus sur le bandeau de confirmation ("Non-partant : n° 7 — recommandation recalculée"), ou à défaut sur la ligne suivante. Les actions d'état ("Base : oui") s'annoncent avec leur état actuel. »

### 6. [MAJEUR] Feuille des grilles : 88 cellules lues une par une, focus et défilement non spécifiés

- **Emplacement** : `EXPERIENCE.md` `tickets-sheet` ; `DESIGN.md` `tickets-sheet` ; maquette colonne 2 (grille de 8 colonnes × 11 tickets).
- **Problème** : en grille, TalkBack traverse 11 × 8 cellules au balayage, sans dire à quel ticket appartient un « 13 ». La base n'est signalée que par la couleur or et la graisse (légende « Base en or : 11 »). Il manque aussi : le focus à l'ouverture et au retour vers « Voir les grilles », le défilement interne (à grande taille de police, la feuille dépasse l'écran et « Copier les grilles » sort de la vue) et l'état déplié/replié de la carte de couverture.
- **Critères** : WCAG 1.3.1 Information et relations, 1.4.1 Utilisation de la couleur, 2.4.3, 1.4.10.
- **Correctif (spine)** : « Chaque ticket est un nœud groupé : "Ticket 1 : base 11 ; 2, 4, 7, 9, 13, 15". Chaque ticket physique est un en-tête ("Ticket physique 1, tickets 1 à 4"). La base est aussi repérée sans couleur : première colonne, gras, et légende "Base : n° 11 (première colonne)". La feuille défile et peut s'ouvrir en plein écran ; "Copier les grilles" reste épinglé en bas de la feuille. Focus initial sur le titre, rendu à "Voir les grilles" à la fermeture. » Dans `DESIGN.md`, remplacer « Dossards des bases en or et gras » par « Dossards des bases en or, en gras et en première colonne ».

### 7. [MAJEUR] Confirmation de copie et invitation « Retenir ce jeu ? » : ni annonce ni durée

- **Emplacement** : `EXPERIENCE.md` `tickets-sheet` (« "Copier les grilles" propose ensuite "Retenir ce jeu ?" ») ; `combo-block` (« Tap = copier les dossards », même lacune).
- **Problème** : depuis Android 13, la confirmation système de presse-papiers n'est pas toujours annoncée par TalkBack et ne dit pas ce qui a été copié. Si « Retenir ce jeu ? » prend la forme d'un snackbar temporisé, un utilisateur TalkBack ou lent peut le perdre avant de l'atteindre.
- **Critères** : WCAG 4.1.3 Messages d'état ; 2.2.1 Réglage du délai.
- **Correctif (spine)** : « Après la copie, une annonce polie et un message visible "11 tickets copiés". "Retenir ce jeu ?" n'expire pas : un message avec action reste affiché jusqu'à ce que l'utilisateur le ferme ou agisse, et il est atteignable au balayage. »

### 8. [MAJEUR] Gel au départ : bascule en temps réel non annoncée, focus perdu, contrôles inertes muets

- **Emplacement** : `EXPERIENCE.md` State Patterns « Jeu figé (départ passé) » (« Lecture seule ; 🔒 Jeu figé au départ (15:05) ») ; CTA « Je retiens ce jeu ».
- **Problème** : si l'écran est ouvert à 15:05, le CTA est remplacé sous le doigt. Si TalkBack avait le focus dessus, ce focus disparaît sans explication. Ensuite, « lecture seule » ne dit pas si les contrôles (budget, interrupteurs, lignes) sont désactivés avec leur sémantique (« désactivé », lu par TalkBack) ou s'ils ignorent les taps en silence. Une action en cours dans une feuille (« Retenir ce jeu ? ») au moment du gel n'a pas de comportement défini. Aucun avertissement non visuel n'annonce l'échéance avant le départ.
- **Critères** : WCAG 4.1.3, 2.4.3, 4.1.2 (état désactivé) ; 2.2.1 (l'exception « événement en temps réel » couvre la limite, pas l'absence d'information).
- **Correctif (spine)** : « Avant le départ, une mention textuelle "Modifiable jusqu'au départ (15 h 05)" fait partie du flux de lecture. Au départ, annonce polie "Départ passé : jeu figé, lecture seule" ; si le focus était sur le CTA, il passe à l'étiquette "Jeu figé au départ, 15 heures 05". Les contrôles passent en état désactivé et TalkBack le lit ; ils ne disparaissent pas. Une action lancée après le départ échoue avec un message explicite, jamais en silence. » Harmoniser aussi le format d'heure (« 9 h 52 » et « 15:05 » coexistent dans la spine).

### 9. [MAJEUR] Option « affichée » : l'état sélectionné n'est spécifié nulle part, et « Recommandée » n'est pas exigée en texte

- **Emplacement** : `EXPERIENCE.md` `option-row` (« L'option recommandée est en tête avec bordure or… Tap → la retient comme système affiché (la recommandée reste marquée) ») ; `DESIGN.md` `option-row` (`border-recommended` seulement).
- **Problème** : c'est la répétition du finding 2.1 de la revue précédente (« cheval sélectionné », signal couleur seule). Après un tap (UJ-4 étape 9 : l'option à 33 € est choisie), deux états coexistent, « recommandée » et « affichée », et seul le premier a un traitement, porté par la bordure or. L'étiquette texte « Recommandée » existe dans la maquette mais pas dans la spine, qui gagne en cas de conflit.
- **Critères** : WCAG 1.4.1, 4.1.2 (état sélectionné, Android `selected`).
- **Correctif (spine)** : dans `option-row`, ajouter « Étiquette texte "Recommandée" obligatoire sur l'option recommandée. L'option affichée porte l'étiquette "Affichée" et l'état sémantique sélectionné (lu "sélectionné" par TalkBack). Aucun des deux états n'est porté par la seule bordure. » Dans `DESIGN.md` Elevation & Depth, mettre à jour l'« Exception unique » : elle cite seulement le n° 1 et l'import IA, alors que le Multi ajoute le verdict « jouer », l'option recommandée et la base active.

### 10. [MAJEUR] Troncature des chiffres en grande taille de police : lignes sans règle de repli

- **Emplacement** : maquette `.kv` (libellé et valeur sur une ligne, `space-between`), `.opt-nums` (« 10 tickets · 3 tickets physiques · couverture 26 % · 1,15 € le point » sur une ligne), `.mrow` (value-badge en `nowrap` à droite du nom et de « Base »), `.tk` (colonne fixe de 30px pour « T10 ») ; `DESIGN.md` `combo-block` (« noms… tronqués ») ; Accessibility Floor (la règle « sans troncature » ne cite que les cartes résultat).
- **Problème** : à 200 %, « Multi en 7 · 11 chevaux dont 1 base » ne tient plus à côté de « Formule » ; la ligne d'option déborde ; la colonne de 30px coupe « T10 ». Une coupure (ellipse) sur un coût, une couverture ou un dossard change le sens du chiffre.
- **Critères** : WCAG 1.4.4, 1.4.10 ; Android : `fontScale` jusqu'à 2,0.
- **Correctif (spine, Accessibility Floor)** : « Multi : aucune valeur chiffrée ni aucun dossard n'est jamais coupé par une ellipse. Aux grandes tailles, les paires libellé/valeur passent en pile (libellé au-dessus), les lignes d'option s'enroulent, le value-badge d'une ligne cheval passe sous le nom, et les tickets se lisent en ligne de texte ("T10 : 11 · 2 · 3 · 4 · 7 · 8 · 15") plutôt qu'en grille à colonnes fixes. Seuls les noms de chevaux peuvent s'enrouler, pas être coupés. »

### 11. [MAJEUR] Bandeaux d'état du Multi non annoncés

- **Emplacement** : `EXPERIENCE.md` State Patterns : « Non-partant : n° 7 — recommandation recalculée », encart « Votre jeu retenu : 2 tickets requalifiés… », « Exploration — rapports Multi indisponibles », « Règles du pari à vérifier — coûts indisponibles », « Budget ≤ 0 refusé avec message inline ».
- **Problème** : ces messages apparaissent après une action ou un rafraîchissement, sans changement de focus. Seule la phrase de l'Accessibility Floor sur le verdict « annoncé en premier » existe, et elle ne vaut qu'à l'ouverture. Le message d'erreur du budget n'est pas relié au champ.
- **Critères** : WCAG 4.1.3 ; 3.3.1 Identification des erreurs.
- **Correctif (spine)** : « Les bandeaux qui apparaissent sans ouverture d'écran (non-partant, requalification, règles à vérifier) sont des régions live polies, annoncées une fois. L'erreur du budget est le texte d'erreur du champ (`errorText`, lu avec le champ) et elle est annoncée à la validation. »

### 12. [MINEUR] Interrupteur de base : état dit deux fois, et un binaire qui cache peut-être un troisième état

- **Emplacement** : `EXPERIENCE.md` `base-chip` (« activé = imposée comme base, désactivé = interdite comme base ») ; Accessibility Floor (« Base n° 11, activée : imposée dans tous les tickets ») ; maquette (interrupteur visuel de 36×20, à droite de la puce).
- **Problème** : (a) avec un `Switch`, TalkBack lit déjà « activé ». Mettre « activée » dans le libellé donne « …activée : imposée…, activé, interrupteur ». (b) Dans la maquette, les candidates 4 et 7 affichent « Interdite comme base » par défaut : le désactivé signifie donc « interdite » et non « laissée au modèle ». Si un état neutre existe, un interrupteur binaire ne peut pas l'exprimer. (c) La cible doit être la puce entière, pas l'interrupteur visuel de 36×20.
- **Critères** : WCAG 4.1.2, 2.5.8 Taille de la cible ; Android : `SwitchListTile` / `MergeSemantics`.
- **Correctif (spine)** : « Chaque base candidate est une seule cible (la puce entière, ≥ 48dp de haut), avec le rôle interrupteur. Libellé : "Base n° 11, top 4 estimé 58 pour cent, moins 9 euros, moins 4 points". Description d'état : "imposée dans tous les tickets" ou "interdite comme base", à la place de activé/désactivé. » Si un état « laissé au modèle » existe, passer à un sélecteur à trois choix (segmented button) plutôt qu'à un interrupteur.

### 13. [MINEUR] Pas de titres de section pour naviguer dans un écran long

- **Emplacement** : maquette `.section-label` (« Système recommandé », « Autres options », « Sélection · 11 chevaux », « Bases candidates ») ; Accessibility Floor.
- **Problème** : l'écran compte plus de 25 nœuds. Sans sémantique d'en-tête, un utilisateur TalkBack ne peut pas sauter de section en section et doit tout parcourir au balayage pour atteindre les bases.
- **Critères** : WCAG 1.3.1, 2.4.6 ; Android : `Semantics(header: true)`.
- **Correctif (spine)** : « Les libellés de section du Multi, "Verdict" et le titre de la feuille des grilles sont des en-têtes pour TalkBack. »

### 14. [MINEUR] Symboles et abréviations lus de travers

- **Emplacement** : libellés de la spine et de la maquette : « −6 pts », « n° 11 », « ×1 », « · », « 1,15 € le point », « 3 sur 4 · arrivée payable : non ».
- **Problème** : selon la voix de synthèse, « pts » est épelé, « × » lu « multiplié par » ou ignoré, « · » ignoré (les nombres collés se fondent alors : « 41 % contribution −6 »). Dans `debrief-row`, deux lignes identiques (jeu retenu et modèle) ne se distinguent que par leur position.
- **Critère** : WCAG 1.3.1 ; Android : `contentDescription` / `semanticsLabel`.
- **Correctif (spine)** : « Le texte lu développe les abréviations ("moins 6 points", "numéro 11", "multiplicateur 1") et remplace "·" par une pause (virgule). Chaque `debrief-row` commence par son sujet : "Votre jeu : 3 sur 4, arrivée payable : non" et "Recommandation du modèle : …". »

### 15. [MINEUR] Contrôles secondaires sous 48dp dans la maquette

- **Emplacement** : maquette « Multiplicateur ×1 ▾ » (texte de 10,5px, sans zone de tap), « Modifier ✎ », repli « Carte de couverture », poignée de la feuille.
- **Problème** : le multiplicateur est un repli tapable rendu comme un libellé d'environ 15px de haut. La règle ≥ 48dp de l'Accessibility Floor vaut en principe, mais la maquette la contredit, et les développeurs s'en serviront comme référence.
- **Critères** : WCAG 2.5.8 ; Android ≥ 48 × 48dp.
- **Correctif (spine)** : dans `budget-field`, préciser : « Le champ entier est la cible d'édition. Le multiplicateur est un repli de 48dp minimum de haut, avec un état déplié/replié. » Corriger la maquette.

### 16. [MINEUR] Petits libellés `muted` sur la teinte `gold-dim` : marge faible, échec possible

- **Emplacement** : `DESIGN.md` `verdict-card` (étiquettes « modèle en cours d'évaluation » / « seuils provisoires » en `label` `muted` sur la teinte « jouer ») ; maquette `.tag` à 9,5px.
- **Problème** : `muted` sur `gold-dim` composé sur `surface-2` donne 4,68:1 (conforme mais juste, à 9,5-11px). Si la teinte est un jour posée sur `surface`, on tombe à 4,42:1, en échec. Ces étiquettes portent l'honnêteté du verdict (modèle non évalué, seuils provisoires) : elles ne doivent pas être le texte le moins lisible de la carte. Le `red` sur cette teinte (3,86:1) interdit d'y placer un value-badge.
- **Critère** : WCAG 1.4.3.
- **Correctif (token/spine)** : sur la variante « jouer », passer ces étiquettes en `text`, ou ajouter un token `muted-on-tint: '#9AA1B3'` (5,26:1 sur `gold-dim`/`surface`, 5,57:1 sur `gold-dim`/`surface-2`). Interdire `red`/`green` sur `gold-dim`. Taille minimale du `label` : 11sp (la maquette descend à 9,5px).

### 17. [MINEUR] Points conformes à noter (pas d'action)

- La redondance non-couleur est respectée pour le verdict « jouer » (libellé), « Base » (texte), les écartés (sous-titre « Écartés les plus proches » et préfixe « Écarté : »), « Dépasse le budget » (texte, en `muted` et non en rouge), « Modifiée » et `debrief-row` (aucune couleur de réussite).
- Le value-badge des lignes Multi garde son signe et le mot « Value ».
- Les mentions « L'outil ne place aucun pari », « Couverture garantie — pas un gain garanti » et le rappel de jeu responsable font partie du flux de lecture (Accessibility Floor).
- `multi-row` est un nœud groupé et `min-height: 48px` est respecté dans la maquette.

## Récapitulatif

| # | Sévérité | Sujet |
|---|---|---|
| 1 | Bloquant | Recalcul en direct (budget, bases, retouches) sans annonce ni anti-rebond |
| 2 | Majeur | `line-card` à 2,86-2,89:1, sous le 3:1 revendiqué |
| 3 | Majeur | Emojis des verdicts lus comme des boutons (« bouton pause Passer ») |
| 4 | Majeur | Barre basse fixe : focus et contenu masqués en grande taille de police |
| 5 | Majeur | Feuille d'actions : focus non géré, ligne d'origine supprimée |
| 6 | Majeur | Feuille des grilles : lecture cellule par cellule, base signalée par la couleur, focus et défilement |
| 7 | Majeur | Copie non annoncée, « Retenir ce jeu ? » possiblement temporisé |
| 8 | Majeur | Gel au départ : bascule non annoncée, focus perdu, état désactivé muet |
| 9 | Majeur | Option affichée et option recommandée : états non textuels |
| 10 | Majeur | Troncature des chiffres à 200 % (paires, options, tickets) |
| 11 | Majeur | Bandeaux d'état et erreur du budget non annoncés |
| 12 | Mineur | Sémantique de l'interrupteur de base (double état, troisième état, cible) |
| 13 | Mineur | Pas d'en-têtes de section |
| 14 | Mineur | Prononciation des symboles et abréviations ; débrief ambigu |
| 15 | Mineur | Cibles secondaires sous 48dp dans la maquette |
| 16 | Mineur | `muted` sur `gold-dim` : marge faible, échec possible |
| 17 | Mineur (constat) | Points conformes |

**Total : 1 bloquant, 10 majeurs, 6 mineurs (dont un simple constat de conformité).**
