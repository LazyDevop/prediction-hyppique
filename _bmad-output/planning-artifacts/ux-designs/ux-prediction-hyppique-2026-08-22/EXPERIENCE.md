---
name: Analyseur Hippique
status: final
created: 2026-08-22
updated: 2026-08-22
sources:
  - ../../prds/prd-prediction-hyppique-2026-08-22/prd.md
  - ../../prds/prd-prediction-hyppique-2026-08-22/addendum.md
  - ../../prds/prd-prediction-hyppique-2026-08-22/sources/cahier_des_charges_app_mobile.md
  - imports/analyse_hippique_v2.html
  - imports/analyse_hippique_ia_ui_excerpt.md
---

# Analyseur Hippique — Experience Spine

## Foundation

Mobile natif, **Android uniquement en V1** (PRD §6.2 — iOS différé). Surface unique (téléphone), pas de tablette ni de multi-surface envisagée V1 (`[OPEN QUESTION]` : layout tablette non défini si jamais demandé). Flutter + widgets Material 3, thème entièrement personnalisé sur les tokens de `DESIGN.md` (pas les couleurs Material par défaut) — `[ASSUMPTION: le cahier mobile ne nomme pas explicitement un système d'UI ; déduit du fait que les deux prototypes définissent une palette et des composants entièrement custom, jamais de bleu Material stock.]`

Thème sombre uniquement — pas de mode clair en V1 (décision de cadrage UX, confirmée par l'utilisateur). `DESIGN.md` est la référence d'identité visuelle ; cette spine couvre le comportement.

Le moteur de calcul tourne intégralement sur l'appareil (PRD §4.6, FR-13) — aucune interaction de cette spine ne doit introduire une dépendance réseau sur le chemin du calcul.

`[OPEN QUESTION]` Deux arguments de positionnement du brief (addendum) restent hors périmètre de cette spine faute de surface qui les porterait aujourd'hui : la calibration continue du modèle sur données réelles, et la profondeur d'historique accessible sans compte (jusqu'à 2004). Les deux sont plus des arguments de fiche produit/onboarding que des micro-décisions d'écran quotidien — à ne pas perdre si un écran "À propos du modèle" ou un onboarding est spécifié plus tard.

## Information Architecture

| Surface | Atteinte depuis | Objectif |
|---|---|---|
| Accueil (programme du jour) | Ouverture de l'app (cold start) | Liste des réunions/courses du jour, depuis le cache, rafraîchissable |
| Configuration course | Accueil (tap sur une course) ou action "course manuelle" | Définir hippodrome/distance/terrain/niveau/partants |
| Liste des partants | Confirmation configuration, ou reprise d'une course en cache | Voir/éditer les chevaux engagés avant calcul |
| Fiche cheval éditable | Liste des partants (tap sur une ligne, ou "+ cheval vide") | Éditer les 6 dernières performances d'un cheval |
| Import photo (feuille modale) | Liste des partants ("importer une course") ou Fiche cheval ("importer une photo/PDF") | Capture/galerie/PDF → extraction vision backend |
| Résultats | Liste des partants (CTA "Calculer") | Classement, value, probabilités, combinaisons, export |
| Réglages | Icône globale (accessible depuis Liste des partants et Résultats) | Paramètres du moteur (FR-20), persistés |

Navigation en pile simple (pas d'onglets — le parcours est linéaire : accueil → config → partants → résultats), avec un raccourci direct vers une course déjà en cache depuis l'accueil. Import photo se présente en feuille modale (bottom sheet), jamais en écran plein empilé sur un autre écran plein — un seul niveau de modal à la fois.

Le détail étendu d'un cheval sur Résultats (probabilités complètes, historique) n'est **pas une surface de navigation distincte** : c'est une expansion en place (accordéon) de la carte résultat elle-même, cohérente avec la densité assumée du produit (DESIGN.md Brand & Style) plutôt qu'une prolifération d'écrans — voir Component Patterns, `results-card`.

→ Référence de composition : `mockups/accueil.html` (programme en cache + cold start à froid), `mockups/configuration-course.html` (course préremplie + sélecteur de terrain groupé Gazon/PSF), `mockups/liste-partants.html` (états de transparence mixtes + liste vide), `mockups/fiche-cheval.html` (import IA à vérifier + feuille d'édition de performance), `mockups/import-photo.html` (choix à froid + lecture en cours + permission refusée), `mockups/resultats.html` (climax UJ-1 + carte développée en accordéon). Seule la surface Réglages reste spine-only (tables Component/State Patterns suffisantes, pas de décision de mise en page délicate). La spine gagne en cas de conflit avec une maquette.

## Voice and Tone

Microcopie. La voix de marque vit dans `DESIGN.md.Brand & Style`. Vocabulaire figé, hérité des deux prototypes (`imports/analyse_hippique_ia_ui_excerpt.md`) — à reprendre tel quel, jamais reformulé à la légère.

| Do | Don't |
|---|---|
| "Historique court (3)" / "Données non saisies" / "🐎 Inédit" | "Pas assez de données !" / masquer silencieusement l'incertitude |
| "🔥 Value forte — jouable" / "📈 Léger avantage" / "— Pas d'avantage" | "Coup sûr" / "Gagnant garanti" / tout langage de certitude |
| "✨ Rempli par l'IA depuis votre image — vérifiez les champs avant de calculer" | "Importé avec succès" (sans inviter à la vérification) |
| "Extraction échouée : {message}. Réessayez avec une capture plus nette." | "Erreur" / message technique brut (code HTTP, stack trace) |
| "Outil d'aide à la décision — aucun modèle ne garantit un gain. Jouez uniquement ce que vous pouvez vous permettre de perdre." (sur chaque écran de résultats, PRD Non-Goals) | Omettre le rappel, même une fois, même sur un écran secondaire |
| Emojis fonctionnels comme repère d'état (⚠️ 🐎 ✨) | Emojis décoratifs sans valeur de signal |
| Jugement sur un cheval exprimé en chiffre ou badge court (value, probabilité, %) | Explication en phrase de type pronostic journalistique ("il devrait revenir en forme", "sa dernière sortie était rassurante") — jamais de prose narrative, même courte |
| "Mise suggérée" (Réglages → bankroll + fraction de Kelly) | "Mise recommandée" / "à jouer" — le champ lexical reste celui de l'aide à la décision, jamais de la prescription |

## Component Patterns

Comportemental. Les spécifications visuelles vivent dans `DESIGN.md.Components`.

| Composant (clé DESIGN.md) | Usage | Règles comportementales |
|---|---|---|
| Carte partant (`horse-card`) | Liste des partants | Tap → Fiche cheval éditable. Import IA marque la carte "à vérifier" ; le bandeau disparaît au niveau de la carte entière dès que l'utilisateur a édité ou confirmé au moins un champ de cette carte — pas de gating champ par champ (PRD FR-18/19). Ordre de lecture TalkBack (nœud groupé, un seul balayage) : nom + dossard → badge de statut/transparence → score → value → cote → détail sur demande. |
| Ligne de performance (partie de `horse-card`) | Fiche cheval | Ligne vide = ignorée du calcul (pas d'erreur bloquante). Case "Cheval inédit" désactive visuellement les lignes de performance plutôt que de les masquer. **Édition en feuille dédiée, pas inline** : le tap sur une ligne ouvre un éditeur plein-largeur pour cette performance (rang, partants, niveau, distance, terrain, incident) — la ligne affichée dans la carte reste en lecture seule et compacte, ce qui évite de faire tenir 5-6 cibles tactiles de 48dp dans une seule rangée dense. |
| Carte résultat (`results-card`) | Résultats | Empilées, triées par score décroissant. Tap → développe la carte en place (accordéon : probabilités étendues, historique du cheval) — pas une nouvelle surface de navigation (voir Information Architecture). Bordure or + fond `gold-dim` réservés au n°1, redondants avec sa position en tête de liste. Ordre de lecture TalkBack : nom + dossard → badge de statut → score → value → mise suggérée → cote → probabilités → détail sur demande. |
| Mise suggérée (partie de `results-card`, token `stake-text`/`stake-hidden`) | Carte résultat | Texte vert gras si positive ; texte "—" en `muted` (jamais un "0" trompeur) si Kelly brut négatif ou cote manquante (PRD FR-10). Annoncée par TalkBack avec son libellé complet ("Mise suggérée : 4,2 unités" / "Mise suggérée : aucune"). |
| Indicateur de régularité (`regularity-indicator`) | Carte partant, Carte résultat | Texte seul, jamais une pastille de couleur nue. Un des cinq libellés fixes ("Très régulier", "Régulier", "Moyen", "Irrégulier", ou l'un des trois libellés de transparence "Historique court (N)"/"Données non saisies"/"🐎 Inédit") — jamais reformulé. |
| Indicateur de fragilité au saut (`fragile-indicator`) | Carte partant, Carte résultat — courses d'obstacle uniquement | Affiché seulement si ≥ 2 chutes et taux de chute ≥ 34 % ("⚠️ Sauteur fragile (N chutes/N perfs)"). En dessous du seuil, mention neutre "N chute(s)" sans icône d'alerte. Absent des courses de plat/trot. |
| Jauge de probabilité (`probability-gauge`) | Carte résultat | Toujours accompagnée du texte "Modèle X % / Marché Y %" — jamais la barre seule (accessibilité). Piste (`track`) rendue en `{colors.surface}` bordée, jamais dans la même teinte que le fond de la carte qui l'héberge (voir DESIGN.md, bug de token corrigé). |
| Bloc combinaison (`combo-block`) | Résultats, section paris combinés | Lecture seule. Tap = copier les dossards (pas d'action de pari — PRD Non-Goals, aucun placement automatisé). |
| Ligne de réglage (`settings-row`) | Réglages | Modification appliquée immédiatement en mémoire ; persistée au blur/confirmation. Action "réinitialiser" isolée, avec confirmation (irréversible pour la session). **Effet démontrable, non cosmétique** : tout réglage modifié puis validé par "Calculer" doit produire un classement visiblement différent — le produit ne recalibre jamais silencieusement, l'écran Résultats reflète toujours l'état courant des paramètres qui l'ont généré. C'est la traduction comportementale du positionnement "moteur transparent et réglable" face au jugement d'expert non recalibrable des concurrents (brief addendum). |
| Export/partage (partie de `results-card` ou CTA dédié, pas de token DESIGN.md distinct — `cta-ghost`) | Résultats | Déclenché par une action explicite (pas automatique) ; ouvre le partage natif Android avec le classement en texte ou JSON (PRD §6.1, export PDF en bonus non requis). Échec (permissions, aucune app cible) : message clair, jamais un blocage — même ton que le reste du produit. |
| Sélecteur de terrain (partie de Configuration course, pas de token DESIGN.md distinct) | Configuration course | Groupé visuellement en deux familles — Gazon (10 niveaux) et PSF (3 niveaux) — jamais en liste plate mélangée, pour éviter la confusion entre deux échelles de coefficients non comparables (PRD Glossaire : Terrain). |
| CTA "Calculer" (`cta-primary`) | Liste des partants | Désactivé (pas masqué) tant qu'aucun cheval n'est saisi. Toujours visible en bas d'écran, jamais caché derrière un scroll. |
| CTA secondaire (`cta-ghost`) | Liste des partants ("+ cheval vide", "importer une course"), Réglages ("réinitialiser") | Jamais de confirmation modale pour ajouter/importer. "Réinitialiser" seul exige une confirmation légère (irréversible pour la session en cours — voir `settings-row`). |
| Feuille d'import (`import-sheet`) | Modale, depuis Liste des partants ou Fiche cheval | Trois choix explicites : Caméra / Galerie / Fichier PDF. Fermeture sans perte de saisie déjà présente sur l'écran d'origine. |
| Badge de dossard (`dossard-badge`) | Carte partant, Carte résultat | Purement identificatif, aucune interaction propre — hérite du tap sur son conteneur. |
| Badge de value (`value-badge`) | Carte résultat | Signe (+/−) et libellé texte toujours présents avec la couleur — jamais la couleur seule (accessibilité). |

## State Patterns

| État | Surface | Traitement |
|---|---|---|
| Cold start, programme en cache | Accueil | Affiche le cache immédiatement, pas d'écran de chargement bloquant. |
| Cold start, aucun cache | Accueil | "Aucune course chargée — rafraîchissez ou ajoutez une course manuellement." + CTA rafraîchir. |
| Échec du rafraîchissement du programme | Accueil | Message clair ("Impossible de rafraîchir — dernières données du {date} affichées"), le cache existant reste affiché et utilisable (même traitement que l'échec de rafraîchissement des cotes sur Liste des partants). |
| Course sélectionnée non encore en base | Configuration course | Déclenche l'import à la demande (PRD FR-3) ; message d'attente court, jamais un écran bloquant plein. |
| Aucun cheval saisi | Liste des partants | "Ajoutez au moins un cheval pour calculer." — cohérent avec le CTA "Calculer" désactivé (Component Patterns), jamais un écran vide muet. |
| Cheval avec historique complet | Fiche cheval / carte partant | Aucun badge — l'absence de badge est elle-même le signal (silence = pas de problème). |
| Cheval "Historique court" / "Données non saisies" / "Inédit" | Fiche cheval / carte partant | Badge texte visible en permanence, jamais uniquement au survol/tap (PRD FR-4, transparence non négociable). |
| Terrain inconnu sur N performances | Fiche cheval | Compteur "X/6 performances avec terrain inconnu" visible (PRD FR-5), pas seulement absorbé silencieusement par le calcul. |
| Import photo en cours | Feuille d'import | "📸 Lecture en cours…" — bouton désactivé, pas d'annulation à mi-vol (extraction déjà lancée côté backend). |
| Import photo échoué | Feuille d'import | Message d'erreur explicite + retour immédiat à la saisie manuelle, sans perte du reste du formulaire (PRD FR-18/19). |
| Réseau indisponible — import photo ou rafraîchissement cotes | Feuille d'import / Liste des partants | Message clair, fonctionnalité désactivée proprement ; le reste de l'app (données en cache, calcul local) reste pleinement utilisable (PRD FR-15). |
| Résultat périmé après édition d'un partant | Résultats | Le résultat affiché est invalidé visuellement (bandeau "recalcul nécessaire") plutôt que silencieusement obsolète (PRD FR-6). |
| Calcul en cours | Résultats | Court indicateur de progression (le calcul inclut une simulation Monte-Carlo à 20 000 tirages, PRD FR-12) — jamais un écran blanc sans retour, même si la durée perçue reste sous la seconde sur la plupart des appareils (seuil "instantané" non encore chiffré, PRD §11 Open Question 1). |
| Erreur de calcul | Résultats | Cas limite (ex. paramètres du moteur incohérents) : message explicite + retour à Liste des partants sans perte de saisie, jamais un état bloqué silencieusement. |
| Calcul terminé | Résultats | Classement + grille de combinaisons + rappel de jeu responsable, toujours les trois ensemble. |
| Mode avion / hors ligne, course en cache | Toute surface sauf import/rafraîchissement | Fonctionnement identique au mode connecté (PRD FR-13, non négociable). |
| Permission caméra/galerie refusée | Feuille d'import photo | Message explicite ("Autorisez l'accès à la caméra pour importer une photo") + lien vers les réglages système ; retour possible à la saisie manuelle sans blocage. |
| Focus clavier/accessoire externe | Toute surface avec champs (Configuration course, Fiche cheval, Réglages) | `focus-indicator` (DESIGN.md : contour or 2px) sur l'élément actif ; ordre de tabulation suit l'ordre de lecture visuel de haut en bas. |

## Interaction Primitives

- Tap pour éditer un champ ou développer une carte résultat en place (accordéon, pas une navigation).
- Tap sur une ligne de performance → feuille d'édition dédiée plutôt qu'édition inline multi-champs (résout la tension entre densité visuelle et cibles tactiles ≥ 48dp — voir Component Patterns, Accessibility Floor).
- Swipe-to-delete sur une carte partant (retirer un cheval de la liste analysée), avec confirmation légère (pattern natif Android, pas de dialogue modal bloquant).
- Pull-to-refresh sur l'accueil (programme du jour) et sur la liste des partants (cotes en direct) — jamais de rafraîchissement automatique en arrière-plan (PRD FR-14).
- Édition inline dans les champs de réglage moteur (peu nombreux, un par ligne — pas de contrainte de densité comparable à la ligne de performance).
- **Banni :** tout geste ou raccourci menant à un placement de pari, quel qu'il soit (PRD Non-Goals, absolu et permanent). Notifications push (hors périmètre V1). Auto-refresh silencieux des données en arrière-plan.

## Accessibility Floor

Comportemental. Le contraste visuel vit dans `DESIGN.md`.

- TalkBack : chaque élément interactif porte un rôle et un état explicites. La jauge de probabilité est annoncée en texte ("Modèle 12,4 pour cent, Marché 8,3 pour cent"), jamais comme deux barres muettes.
- **Regroupement de lecture sur les cartes denses** : `horse-card` et `results-card` s'annoncent comme un nœud sémantique groupé unique (nom + dossard en tête), pas comme 10+ champs plats à traverser un par un au swipe. Ordre de priorité fixe : identité (nom, dossard) → statut/transparence → score → value → mise suggérée (résultats uniquement) → cote → probabilités détaillées, disponibles sur demande plutôt qu'annoncées d'office (voir Component Patterns pour le détail par composant).
- Aucune information n'est portée par la couleur seule : value positive/négative porte toujours un signe (+/−) et un libellé texte en plus de la couleur verte/rouge ; les badges d'état (Inédit, Historique court) sont toujours du texte, jamais une pastille de couleur nue ; la bordure or (n°1, import IA à vérifier) est toujours doublée d'une redondance non-couleur (position en tête de liste, bandeau texte — voir DESIGN.md Elevation & Depth).
- Cibles tactiles ≥ 48dp (Android). Sur la ligne de performance (5-6 champs par performance passée), ce seuil est garanti en évitant l'édition inline multi-champs : le tap ouvre une feuille d'édition dédiée plutôt que de faire tenir plusieurs cibles de 48dp côte à côte dans une rangée dense (voir Interaction Primitives) — la ligne affichée reste compacte et non interactive dans son état de lecture.
- Police système honorée à l'échelle d'accessibilité la plus large sans troncature ni chevauchement — particulièrement critique sur les cartes résultat (beaucoup de valeurs numériques par ligne).
- Focus clavier/accessoire externe visible sur tout élément interactif (`focus-indicator`, DESIGN.md) — voir State Patterns.
- Le rappel de jeu responsable n'est jamais dans un élément décoratif ignoré par le lecteur d'écran — il fait partie du flux de lecture normal de l'écran de résultats.

## Responsive & Platform

Android uniquement en V1, formats de téléphone courants (portrait principal — les tableaux denses de courses à beaucoup de partants restent verticaux via les cartes empilées, jamais de rotation forcée en paysage). Pas de layout tablette envisagé (`[OPEN QUESTION]`, à trancher si la demande se présente). Conventions de navigation Android natives honorées (retour système, pas de geste custom qui les court-circuite).

## Inspiration & Anti-patterns

- **Repris des tableaux de cotes / terminaux de trading** : densité assumée, chiffres tabulaires stricts, une seule couleur d'accent pour le signal principal.
- **Repris du prototype HTML (`analyse_hippique_v2.html`), transformation mobile déjà validée** : le tableau de résultats devient une liste de cartes empilées avec libellé préfixé par valeur sur petit écran — pattern directement porté en natif plutôt que réinventé.
- **Rejeté — mécaniques de gamification (streaks, badges de progression, notifications de relance)** : cohérent avec le PRD (Non-Goals, SM-C1) — la fréquence d'usage n'est explicitement pas un objectif produit ; rien dans l'UX ne doit pousser à l'usage compulsif.
- **Rejeté — vocabulaire de certitude ("coup sûr", "gagnant garanti")** : le produit est un outil d'aide à la décision, jamais un générateur de certitudes (PRD §1 Vision) — non négociable, y compris dans une future itération marketing de la microcopie.
- **Rejeté — action de pari en un tap depuis les résultats** : aucune fonctionnalité de placement de pari automatisé, à aucune version (PRD Non-Goals, absolu).

## Key Flows

*Mêmes protagoniste et numérotation que le PRD (§2.3) — UJ-1, UJ-2, UJ-3 — cette section les rejoue au niveau des écrans plutôt que des capacités.*

### UJ-1 — Marc prépare sa réunion du dimanche depuis son salon

1. Marc ouvre l'app (Accueil), bonne connexion, programme pas encore chargé aujourd'hui.
2. Il tire pour rafraîchir (pull-to-refresh) → le programme du jour apparaît (`mockups/accueil.html`).
3. Il tape une réunion puis une course → Configuration course, préremplie (`mockups/configuration-course.html`).
4. Il confirme → Liste des partants, préremplie depuis le backend, historique inclus.
5. Il ajuste le terrain (annoncé plus tard que prévu) et corrige une cote sur une carte partant.
6. Il tape "Calculer".
7. **Climax :** Résultats — un cheval porte le badge "🔥 Value forte — jouable", la jauge modèle/marché rend l'écart visible d'un coup d'œil.
8. Il consulte la grille de combinaisons, note les dossards, ferme l'app. La course reste en cache.

Échec : à l'étape 3, si la course n'est pas encore en base, la Configuration course déclenche l'import à la demande avant de prérempiler (état "Course sélectionnée non encore en base").

→ Étapes 4-5 : `mockups/liste-partants.html`. Étape 7 (climax) : `mockups/resultats.html`.

### UJ-2 — Marc recalcule sur l'hippodrome avec une connexion saturée

1. Marc ouvre l'app dans les tribunes, réseau dégradé, course déjà en cache depuis la veille (UJ-1).
2. Accueil → tap direct sur la course en cache (pas de tentative de rafraîchissement bloquante).
3. Liste des partants s'affiche instantanément depuis le cache local.
4. Il ouvre Réglages, ajuste la sensibilité au poids.
5. Retour, tape "Calculer".
6. **Climax :** Résultats se recalcule intégralement sur l'appareil, sans aucun appel réseau, aussi vite qu'en connexion pleine.
7. Il consulte la nouvelle mise suggérée avant l'heure de départ.

Échec : s'il tape "rafraîchir les cotes" sans réseau exploitable, message d'erreur clair sur la Liste des partants ; le reste de l'écran (cache existant) reste pleinement consultable.

### UJ-3 — Marc importe une fiche cheval par photo quand le backend ne couvre pas la course

1. Sur la Fiche cheval éditable d'un cheval non couvert (réunion étrangère), Marc tape "Importer une photo ou un PDF".
2. Feuille d'import photo s'ouvre (`mockups/import-photo.html`) → il choisit Galerie.
3. "📸 Lecture en cours…" — bouton désactivé, il attend (même fichier, état "lecture en cours").
4. La fiche se préremplit, bandeau "✨ Rempli par l'IA — vérifiez les champs" visible, feuille fermée automatiquement.
5. Il vérifie et corrige un champ (numéro de dossard signalé "à vérifier" — voir PRD FR-18).
6. **Climax :** il enregistre — la fiche corrigée rejoint le calcul comme n'importe quelle autre, aucune distinction résiduelle une fois validée.

Échec : extraction échouée (image floue) → message d'erreur explicite sur la feuille, retour à la Fiche cheval en saisie manuelle sans perte des champs déjà remplis.

→ Étapes 4-5 : `mockups/fiche-cheval.html`.
