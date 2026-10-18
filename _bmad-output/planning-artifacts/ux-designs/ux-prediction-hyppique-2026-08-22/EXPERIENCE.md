---
name: Analyseur Hippique
status: final
created: 2026-08-22
updated: 2026-10-18
sources:
  - ../../../../docs/cahier_des_charges_module_multi.md
  - ../../architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md
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

Le moteur de calcul tourne intégralement sur l'appareil (PRD §4.6, FR-13) — aucune interaction de cette spine ne doit introduire une dépendance réseau sur le chemin du calcul. Cela vaut pour le Multi : sélection, indice de confiance, systèmes et explications sont toujours calculés sur l'appareil (architecture AD-6).

Le Multi est un **pronostic, sans argent** (recadrage du porteur de projet du 2026-10-18, `multi/reconcile-cdc-multi-prd.md` §D ter, qui fait foi sur PRD §4.11 et cahier Multi v2) : il dit quels chevaux peuvent constituer l'arrivée, avec quelle confiance — jamais de budget, coût, mise, gain, rapport, seuil de rentabilité ni indice de valeur.

L'application est en français dans le MVP ; l'anglais viendra après (PRD §8). Les explications du Multi arrivent du moteur sous forme de codes, rendus en libellés courts par l'application (architecture AD-8) — cette spine fixe la forme de ces libellés, pas leur traduction.

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
| Réglages | Icône globale (accessible depuis Liste des partants, Résultats et Multi) | Paramètres du moteur (FR-20), persistés — y compris un groupe « Multi » : seuils de l'indice de confiance (probabilité que l'arrivée soit dans la sélection, ouverture de la course) et seuil de données fragiles, libellés « provisoire » tant que le pilote ne les a pas fixés. Retour vers le Multi → recalcul local |
| Multi | Résultats (`cta-ghost` « Multi » en tête de l'écran, sous le titre de la course, visible seulement si la course est éligible) ; badge « Multi » (`multi-badge`) de la carte de course à l'Accueil ; « Mes pronostics Multi » sur l'Accueil (état débrief) | Pour la course support : pronostic des chevaux qui peuvent constituer l'arrivée, à la taille choisie par l'utilisateur, avec son indice de confiance, ses chevaux les plus probables, ses systèmes en tickets et pourquoi — sans argent (§D ter) `[ASSUMPTION]` |
| Grilles (feuille modale) | Multi (« Voir les grilles ») | Tickets de la formule affichée en dossards, par ticket physique, copiables ; carte de couverture |
| Feuilles du Multi (modales) | Multi : ligne cheval (`multi-actions-sheet`), « + Ajouter un cheval » et « Saisir ma propre sélection » (`horse-picker-sheet`), « Saisir un système trouvé ailleurs » (`system-entry-sheet`) | Retouches de l'utilisateur (PRD FR-25, FR-28) `[ASSUMPTION]` |
| Mes pronostics Multi (section de l'Accueil) | Accueil, sous le programme du jour | Pronostics retenus des 90 derniers jours et leur débrief (PRD FR-30) `[ASSUMPTION]` |

Navigation en pile simple (pas d'onglets — le parcours est linéaire : accueil → config → partants → résultats → Multi), avec un raccourci direct vers une course déjà en cache depuis l'accueil. Le Multi s'ouvre depuis Résultats parce qu'il a besoin du classement calculé ; la carte de la course support porte un badge « Multi » à l'Accueil pour qu'on la repère. Tap sur ce badge : si un classement calculé et à jour est en cache, le Multi s'ouvre directement (retour → Accueil) ; sinon, la course s'ouvre sur Liste des partants avec le message « Calculez le classement pour ouvrir le Multi », et le CTA « Multi » apparaît sur Résultats après « Calculer » `[ASSUMPTION]`. Import photo se présente en feuille modale (bottom sheet), jamais en écran plein empilé sur un autre écran plein — un seul niveau de modal à la fois.

**Ordre de l'écran Multi (un seul défilement, de haut en bas)** — recadrage du porteur de projet du 2026-10-18 (§D ter), qui **remplace l'ordre du cahier Multi §11.1** et l'ancien ordre budget → verdict → système de cette spine :

1. En-tête : course et heure de départ, « 18 partants · course éligible », « Cotes de 9 h 38 », « Modifiable jusqu'au départ (15 h 05) », icône Réglages, puis « L'outil ne place aucun pari ». Les `status-banner` d'état (exploration, règles à vérifier, non-partant, pronostic retenu touché par un non-partant, classement modifié) s'insèrent sous l'en-tête.
2. Taille de la sélection (`size-stepper`).
3. Confiance (`confidence-card`), suivie le cas échéant de l'avertissement fort « données fragiles ».
4. Sélection (`multi-row`), puis les 3 écartés les plus proches, les échanges suggérés, « + Ajouter un cheval » et « Saisir ma propre sélection ».
5. Chevaux les plus probables — bases candidates (`base-chip`).
6. Systèmes : une `formula-row` par formule (tickets de 4 à 7), la formule « Affichée » avec sa garantie, puis « Saisir un système trouvé ailleurs ». Les grilles s'ouvrent depuis la barre basse.
7. Évaluation (`evaluation-block`).
8. Autres méthodes (`other-methods-section`, repliée).
9. Rappel de jeu responsable.

Sous la zone défilante, la `multi-action-bar` porte le seul CTA plein (« Je retiens ce pronostic ») et « Voir les grilles ». La section « Mes choix » du cahier disparaît : ses actions vivent là où elles agissent (retouches dans la Sélection, système saisi dans Systèmes, « Je retiens ce pronostic » dans la barre).

Le détail étendu d'un cheval sur Résultats (probabilités complètes, historique) n'est **pas une surface de navigation distincte** : c'est une expansion en place (accordéon) de la carte résultat elle-même, cohérente avec la densité assumée du produit (DESIGN.md Brand & Style) plutôt qu'une prolifération d'écrans — voir Component Patterns, `results-card`.

→ Référence de composition : `mockups/accueil.html` (programme en cache + cold start à froid), `mockups/configuration-course.html` (course préremplie + sélecteur de terrain groupé Gazon/PSF), `mockups/liste-partants.html` (états de transparence mixtes + liste vide), `mockups/fiche-cheval.html` (import IA à vérifier + feuille d'édition de performance), `mockups/import-photo.html` (choix à froid + lecture en cours + permission refusée), `mockups/resultats.html` (climax UJ-1 + carte développée en accordéon). `mockups/multi.html` (écran Multi après retouches, 13 chevaux dont 1 base, et feuille des grilles — pronostic sans argent). Réglages, les feuilles du Multi (hors grilles) et Mes pronostics Multi restent spine-only. `mockups/accueil.html` est antérieure au Multi : elle ne montre ni la section « Mes pronostics Multi » ni le badge « Multi » — la spine fait foi. La spine gagne en cas de conflit avec une maquette.

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
| Multi sans argent : la taille se dit en chevaux ("12 chevaux"), un système en tickets ("11 tickets · 3 tickets physiques") | Tout mot ou symbole d'argent dans le Multi : "€", "budget", "coût", "mise", "gain", "rapport", "rentable", "jouable avec", "prix du point" (§D ter). "Mise" reste réservé à la mise suggérée (Kelly) de Résultats |
| Confiance Multi : "Confiance élevée" / "Confiance moyenne" / "Confiance faible" (confirmé par le porteur de projet le 2026-10-18), suivis de leurs raisons en libellés courts ("Arrivée dans la sélection : 31 % (estimé) · course ouverte · données : 1 cheval à historique court") | "Jouer", "Passer", "Foncez", "Coup à jouer", "Pronostic gagnant" — aucun verdict de jeu, aucun ton d'incitation |
| Bases candidates : section "Chevaux les plus probables", chaque cheval toujours avec son chiffre ("Top 4 estimé 58 %") et l'en-tête "selon le modèle" | "Sûr" pour un cheval ("cheval sûr", "chevaux sûrs", "coup sûr"), "certain" — vocabulaire de certitude interdit ; un cheval proposé sans son chiffre |
| Explication Multi : chiffre + libellé court — "Top 4 estimé 41 % · contribution −6 pts", "Écarté : top 4 estimé 6 % · historique court" | Phrase de pronostic ("devrait finir dans les quatre") — la règle « pas de prose narrative » s'applique au Multi |
| Texte de garantie, mot pour mot (PRD FR-25) : "Si les 4 premiers sont dans votre sélection [et incluent vos bases], au moins un de vos tickets les contient tous" — "et incluent votre base" avec une seule base, segment omis sans base — suivi de "Couverture garantie — pas un gain garanti" | Toute formulation qui parle de paiement ou de rapport ("au moins un ticket paie"), "Système garanti", "gain assuré" |
| Termes du recadrage : "arrivée dans la sélection" (libellé "Arrivée dans la sélection : 31 % (estimé)" ; avec des bases : "Arrivée dans la sélection, bases comprises"), "chevaux capturés" ("3 chevaux capturés sur 4"), "pronostic retenu", "Couverture garantie" | "Chances de gagner", "Couverture 31 %", "3 bons", "mon pari", "jeu retenu" |
| Heures en typographie française : "15 h 05", "9 h 52" | "15:05", "15h05" |
| Limites des données dites : "Cotes de 9 h 38" ; "Cote manquante" à la place de la value | Cacher l'heure des cotes |
| Évaluation défavorable dite avec son effectif : "Évaluation sur 64 courses : le modèle ne fait pas mieux que le marché" | Taire le résultat, ou basculer silencieusement vers une autre méthode (PRD FR-23) |
| Estimations toujours dites comme telles : "estimé", "selon le modèle" | "Dans 41 % des cas" (présente une estimation comme une fréquence observée) |

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
| CTA secondaire (`cta-ghost`) | Liste des partants ("+ cheval vide", "importer une course"), Réglages ("réinitialiser"), Résultats (« Multi »), Multi (« Voir les grilles », « + Ajouter un cheval », « Saisir ma propre sélection », « Saisir un système trouvé ailleurs », « Appliquer », « Revenir au pronostic du modèle », « Analyser ») | Jamais de confirmation modale pour ajouter/importer. "Réinitialiser" seul exige une confirmation légère (irréversible pour la session en cours — voir `settings-row`). |
| Feuille d'import (`import-sheet`) | Modale, depuis Liste des partants ou Fiche cheval | Trois choix explicites : Caméra / Galerie / Fichier PDF. Fermeture sans perte de saisie déjà présente sur l'écran d'origine. |
| Badge de dossard (`dossard-badge`) | Carte partant, Carte résultat | Purement identificatif, aucune interaction propre — hérite du tap sur son conteneur. |
| Badge de value (`value-badge`) | Carte résultat (jamais dans le Multi) | Signe (+/−) et libellé texte toujours présents avec la couleur — jamais la couleur seule (accessibilité). Cote absente : « Cote manquante » en texte à la place du badge. |
| Bandeau d'import IA (`status-banner-import`) | Carte partant, Fiche cheval | Informatif, non tapable. Disparaît au niveau de la carte entière dès qu'un champ de cette carte a été édité ou confirmé (voir `horse-card`). Lu dans le nœud groupé de la carte, juste après nom + dossard. |
| Indicateur de focus (`focus-indicator`) | Toute surface interactive | Visible en navigation clavier/accessoire externe uniquement, jamais au simple toucher. Suit l'ordre de lecture visuel. Jamais masqué par la `multi-action-bar` ni laissé sous une feuille fermée : le focus revient à l'élément d'origine. |
| Taille de la sélection (`size-stepper`) | Multi, sous l'en-tête | Contrôle à pas « − 12 chevaux + », de 4 à 20 chevaux, plafonné au nombre de partants analysés (§D ter). **Premier affichage** : la dernière taille utilisée (mémorisée avec les réglages), sinon 10 (confirmé par le porteur de projet le 2026-10-18) ; calcul immédiat. **Changement** : chaque tap sur « − » ou « + » change la valeur affichée tout de suite ; le recalcul part après une courte pause (environ 800 ms sans nouveau tap), jamais à chaque tap, sans bouton « calculer ». Pendant la pause, confiance, sélection, systèmes et évaluation gardent l'état précédent, atténués ; jamais de résultat intermédiaire. À une borne, le bouton concerné est désactivé, pas masqué. Les retouches de l'utilisateur (chevaux imposés, retirés, non-partants) sont conservées comme contraintes au changement de taille `[ASSUMPTION]`. Chaque taille utilisée est mémorisée pour la course suivante. Aucun montant. |
| Carte confiance (`confidence-card`) | Multi, sous la taille | Signal principal de l'écran : niveau « Confiance élevée », « Confiance moyenne » ou « Confiance faible » (confirmé par le porteur de projet le 2026-10-18), puis ses trois raisons en libellés courts — « Arrivée dans la sélection : 31 % (estimé) » (bases comprises si des bases sont actives), « Ouverture de la course : course ouverte », « Données : 1 cheval à historique court » — et les étiquettes « modèle en cours d'évaluation » et « seuils provisoires » tant qu'elles s'appliquent (seuils propres à chaque taille de sélection, réglables dans Réglages, provisoires jusqu'au pilote). Non tapable ; tout se lit sans dépli. Ne dit jamais « jouer » ni « passer » : c'est la confiance dans le pronostic, pas un conseil de jeu. |
| Ligne de formule (`formula-row`) | Multi, section Systèmes (sous les chevaux les plus probables) | Une ligne par formule possible pour la sélection et ses bases — tickets de 4 à 7, seulement celles qui ne dépassent pas la taille — chacune avec « N tickets · N tickets physiques », jamais de coût. Une seule est « Affichée » : par défaut Multi en 7 (confirmé par le porteur de projet le 2026-10-18), puis la dernière formule utilisée `[ASSUMPTION]`. Tap → elle devient la formule affichée : étiquette « Affichée » et état sémantique « sélectionné », garantie dépliée sous elle : texte de garantie mot pour mot (Voice and Tone), puis « Couverture garantie — pas un gain garanti ». « Voir les grilles » ouvre les tickets de la formule affichée ; il vit dans la `multi-action-bar` — sauf au-delà de 130 % d'échelle de police, où il passe dans le flux juste sous la formule affichée. En fin de section : « Saisir un système trouvé ailleurs » (`cta-ghost` → `system-entry-sheet`). |
| Saisie d'un système (`system-entry-sheet`) | Modale depuis « Saisir un système trouvé ailleurs » | L'utilisateur saisit la formule (tickets de 4 à 7), la sélection, les bases et les tickets (dossards, ligne à ligne). « Vérifier » → `status-banner` : « Ce système couvre bien ce qu'il promet » ou « Ce système ne couvre pas 6 groupes de 4 chevaux » (premiers groupes manquants listés en dossards). Si le catalogue contient un système valide plus petit pour la même sélection, les mêmes bases et la même formule : « Un système de 9 tickets couvre la même chose » + `cta-ghost` « L'afficher » (il devient la formule affichée). La saisie est conservée tant que l'écran Multi reste ouvert. `[ASSUMPTION]` sur la forme ; capacité : PRD FR-25. |
| Ligne cheval Multi (`multi-row`) | Multi, section Sélection | Dossard, nom, top 4 estimé, contribution, « Cote manquante » si la cote manque, indicateurs de transparence (FR-4), jamais de badge de value (la value reste sur Résultats), étiquette « Base » si base, étiquette « Ajouté par vous » sur un cheval ajouté par l'utilisateur. Tap → `multi-actions-sheet`. Les 3 écartés les plus proches suivent la sélection sous le sous-titre « Écartés les plus proches », avec leur raison ; tap → même feuille, réduite à « Ajouter à la sélection ». Toute retouche fait passer la sélection en « Modifiée » (étiquette en tête de section) et affiche sous la liste 1 à 2 échanges suggérés, chacun en une ligne texte « Échanger n° 8 contre n° 3 : +2 pts d'arrivée dans la sélection » avec un `cta-ghost` « Appliquer » (un tap, retouche comme une autre, taille inchangée) `[ASSUMPTION]`. « Revenir au pronostic du modèle » annule toutes les retouches. En fin de section : « + Ajouter un cheval » et « Saisir ma propre sélection » (`horse-picker-sheet`). |
| Feuille d'actions cheval (`multi-actions-sheet`) | Modale depuis une `multi-row` | Titre « N° 7, Ondine Royale ». Actions : Retirer (taille −1) ; Imposer, avec son effet affiché (« Imposer : −3 pts d'arrivée dans la sélection par rapport au pronostic du modèle ») ; Base : oui/non, avec l'état courant ; Marquer non-partant (hors ligne compris ; le modèle le remplace pour garder la taille choisie) `[ASSUMPTION]`. Une action = fermeture de la feuille + recalcul local. Fermeture sans action par le retour système, le voile ou le bouton « Fermer ». `[ASSUMPTION]` sur la forme ; actions : PRD FR-28. |
| Sélecteur de chevaux (`horse-picker-sheet`) | Modale depuis « + Ajouter un cheval » ou « Saisir ma propre sélection » | **Ajout** : partants analysés non retenus (dossard, nom, top 4 estimé) ; tap = ajout (taille +1, le `size-stepper` suit), feuille fermée, recalcul `[ASSUMPTION]`. Partants non analysés grisés « à analyser », non sélectionnables ; tap → « Analyser » renvoie à Liste des partants (FR-22). **Sélection personnelle** : même liste à cases à cocher, partant d'une sélection vide ; « Évaluer ma sélection » remplace la sélection par la sienne (la taille devient le nombre de cases cochées, 4 à 20), passée en « Modifiée » et évaluée (confiance, arrivée dans la sélection, échanges suggérés, systèmes). `[ASSUMPTION]` ; capacité : PRD FR-28. |
| Cheval le plus probable — base candidate (`base-chip`) | Multi, section Chevaux les plus probables (sous la Sélection) | Toujours 3 (moins si la sélection est plus petite), classés par plus forte probabilité estimée d'être dans les 4 — en-tête « Chevaux les plus probables · selon le modèle ». Chacun : dossard, nom, « Top 4 estimé 58 % », effet en base « −4 pts d'arrivée dans la sélection » ; jamais de montant. Désactivés au premier affichage ; l'utilisateur les active (confirmé par le porteur de projet le 2026-10-18). Une seule cible (la puce entière, ≥ 48dp), rôle interrupteur, binaire comme le veut PRD FR-24 — pas d'état neutre : activé = « Base imposée dans tous les tickets », désactivé = « Interdite comme base ». Chaque basculement relance le calcul (confiance, systèmes, grilles). |
| Bloc évaluation (`evaluation-block`) | Multi, section Évaluation (sous les systèmes) | Lecture seule, pour la sélection et ses bases : « Arrivée dans la sélection : 31 % (estimé) » ; distribution du nombre de chevaux capturés (0 à 4, cinq lignes). Aucun rapport, montant ni indice de valeur (§D ter). Évaluation défavorable : voir State Patterns. `[ASSUMPTION]` sur la forme ; contenu : PRD FR-30 recadré. |
| Section Autres méthodes (`other-methods-section`) | Multi, avant le rappel de jeu responsable | Repliée par défaut, en-tête avec état déplié/replié. Dépliée : méthode 1 (règle par règle) et marché, chacun avec sa sélection en dossards et « hypothèse non validée » ; performances seulement au-delà de l'effectif minimal, avec effectif et intervalle, sinon « Pas encore assez de courses pour mesurer ». Comparateur marché absent si une cote manque (« Comparateur marché indisponible : cote manquante »). Lecture seule, jamais proposée par défaut (PRD FR-29). |
| Barre d'action Multi (`multi-action-bar`) | Multi, sous la zone défilante | Porte `cta-primary` « Je retiens ce pronostic » et `cta-ghost` « Voir les grilles ». Posée sous le contenu, jamais par-dessus : le défilement se termine au-dessus d'elle (`Scaffold.bottomNavigationBar`). Masquée quand le clavier est ouvert (feuilles de saisie). Au-delà de 130 % d'échelle de police, elle ne garde que le CTA plein ; « Voir les grilles » passe dans le flux, sous la `formula-row` affichée. Classement à recalculer : les deux actions sont désactivées, pas masquées ; règles non vérifiées : seul « Voir les grilles » est désactivé. |
| CTA « Je retiens ce pronostic » (`cta-primary`) | Multi, `multi-action-bar` | Seul CTA plein de l'écran, libellé en majuscules « JE RETIENS CE PRONOSTIC ». Enregistre sur l'appareil, 90 jours, le pronostic affiché (taille, sélection, bases, formule affichée, heure des données) et le pronostic du modèle à la même taille — un pronostic retenu par course, remplaçable jusqu'au départ, figé au départ. Confirmation par l'étiquette « Pronostic retenu à 9 h 52 » et une annonce polie. Après le départ : remplacé par l'étiquette « 🔒 Pronostic figé au départ (15 h 05) » (voir State Patterns). |
| Feuille des grilles (`tickets-sheet`) | Modale depuis « Voir les grilles » | Tickets de la formule affichée en dossards, regroupés par ticket physique (4 par bulletin), bases en gras en première colonne, légende « Base : n° 11 (première colonne) ». En-tête « 12 chevaux dont 1 base · 11 tickets · 3 tickets physiques » — jamais de coût. La feuille défile et peut s'ouvrir en plein écran ; « Copier les grilles » (texte) reste épinglé en bas. Après la copie : message visible « 11 tickets copiés », puis invitation « Retenir ce pronostic ? » (actions « Retenir » / « Plus tard ») qui n'expire pas et ne retient jamais à la place de l'utilisateur. Carte de couverture repliée (combinaisons couvertes 1×, 2×, 3×), avec état déplié/replié. Fermeture par le retour système, le voile ou « Fermer ». |
| Ligne de pronostic retenu (`debrief-row`) | Accueil, « Mes pronostics Multi » | Une entrée par course : course, date, taille du pronostic retenu (« 12 chevaux ») ; deux lignes, chacune commençant par son sujet : « Votre pronostic : en attente du résultat » puis « Votre pronostic : 3 chevaux capturés sur 4 · arrivée dans la sélection : non », et la même chose pour « Pronostic du modèle ». Seule l'arrivée officielle (ex-aequo compris) sert au débrief. Mention « Arrivée corrigée » si l'arrivée change après finalisation. Tap → écran Multi de la course en état débrief (lecture seule). |
| Badge Multi (`multi-badge`) | Accueil (carte de course), Résultats | Accueil : « Multi » sur la carte d'une course éligible ; zone de tap ≥ 48dp ; tap → chemin décrit en Information Architecture. Résultats d'une course non éligible : « Multi indisponible » à la place du CTA « Multi » ; tap → la raison (« Pas une course support » ou « Moins de 14 partants déclarés (12) »). |
| Bandeau d'état Multi (`status-banner`) | Multi (sous l'en-tête ; avertissement fort sous la carte confiance ou en tête de l'Évaluation), feuilles du Multi | Informatif, non tapable sauf action explicite (« Analyser »). Porte : exploration, règles à vérifier, non-partant recalculé, pronostic retenu touché par un non-partant, classement modifié, partants non analysés, résultat de vérification d'un système ; variante forte : données fragiles, modèle pas meilleur que le marché. Reste visible tant que l'état dure ; le bandeau non-partant disparaît au recalcul suivant. |

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
| Course non éligible | Résultats | Le CTA « Multi » est remplacé par un `multi-badge` « Multi indisponible » ; tap → la raison (« Pas une course support » ou « Moins de 14 partants déclarés »). L'écran Multi ne s'ouvre pas. |
| Badge « Multi » touché sans classement à jour | Accueil → Liste des partants | Message « Calculez le classement pour ouvrir le Multi » ; après « Calculer », Résultats propose le CTA « Multi ». `[ASSUMPTION]` |
| Premier affichage, aucune taille mémorisée | Multi | Taille 10, aucune base active ; calcul immédiat, écran complet. (confirmé par le porteur de projet le 2026-10-18) |
| Premier affichage, taille mémorisée | Multi | Taille = la dernière utilisée (plafonnée au nombre de partants analysés), aucune base active ; calcul immédiat, écran complet. (confirmé par le porteur de projet le 2026-10-18) |
| Changement de taille en cours | Multi | La valeur du `size-stepper` change à chaque tap ; confiance, sélection, chevaux les plus probables, systèmes et évaluation gardent l'état précédent, atténués ; aucun résultat intermédiaire ; recalcul après une courte pause (environ 800 ms sans nouveau tap). |
| Taille à une borne | Multi | 4 chevaux : « − » désactivé ; 20 chevaux ou tous les partants analysés : « + » désactivé, avec la ligne « Plafond : 15 partants analysés » quand c'est le nombre de partants qui limite. Jamais masqués. `[ASSUMPTION]` |
| Calcul Multi en cours | Multi | Court indicateur de progression dans la carte confiance ; le reste garde l'état précédent atténué ; jamais d'écran blanc. `[ASSUMPTION]` |
| Erreur de calcul Multi | Multi | `status-banner` « Calcul du Multi impossible : {raison courte} » ; taille conservée ; retour possible à Résultats ; jamais un état bloqué silencieux (même traitement que l'erreur de calcul de Résultats). `[ASSUMPTION]` |
| Classement modifié (partant édité, cotes rafraîchies, réglage moteur changé) | Multi | Aligné sur « Résultat périmé » de Résultats : `status-banner` « Classement modifié — recalculez sur Résultats » ; confiance, sélection et systèmes atténués ; actions de la barre désactivées jusqu'au recalcul. Un seuil Multi changé dans Réglages ne périme pas le classement : recalcul local direct au retour. `[ASSUMPTION]` |
| Mode exploration (marqueur course support introuvable) | Multi | `status-banner` « Exploration — course support non confirmée » ; pronostic, confiance et systèmes calculés normalement. `[ASSUMPTION]` |
| Règles non vérifiées | Multi | `status-banner` « Règles du pari à vérifier — grilles indisponibles » (PRD §9.5 ; la vérification sur pmu.fr reste un prérequis des grilles, §D ter). Taille, confiance, sélection, chevaux les plus probables et évaluation restent consultables ; la section Systèmes est remplacée par la même ligne ; « Voir les grilles » désactivé ; « Je retiens ce pronostic » reste possible (sans formule). `[ASSUMPTION]` |
| Confiance faible | Multi | Titre « Confiance faible » en `text`, sans or ni rouge, avec ses raisons ; le pronostic, les systèmes et le CTA restent disponibles — la confiance informe, elle ne bloque rien. |
| Données fragiles | Multi | Raison « Données : 4 chevaux inédits ou à historique court » dans la carte confiance, et avertissement fort (`status-banner`, variante forte) sous la carte : « ⚠️ 4 chevaux inédits ou à historique court dans la sélection ». |
| Modèle pas meilleur que le marché | Multi (Évaluation, confiance) | « modèle en cours d'évaluation » reste affiché ; `status-banner` variante forte en tête de l'Évaluation : « Évaluation sur 64 courses : le modèle ne fait pas mieux que le marché ». Le pronostic ne bascule jamais vers une autre méthode (PRD FR-23). |
| Cote manquante | Multi | « Cotes de 9 h 38 » reste dans l'en-tête ; la ligne cheval porte « Cote manquante » en texte (aucun badge de value dans le Multi) ; comparateur marché indisponible dans Autres méthodes (PRD FR-27, FR-29). |
| Partants non analysés | Multi | `status-banner` « 3 partants non analysés, non sélectionnables » + action « Analyser » qui renvoie à Liste des partants. |
| Forme absente du catalogue | Multi | La formule disparaît de la section Systèmes avec une ligne « Système indisponible pour cette forme » ; jamais de calcul à la volée. |
| Non-partant déclaré (rafraîchissement ou marqué à la main) | Multi | Recalcul local immédiat, taille conservée ; `status-banner` « Non-partant : n° 7 — pronostic recalculé » ; si un pronostic est déjà retenu, `status-banner` séparé « Votre pronostic retenu contient le n° 7, non-partant » `[ASSUMPTION]`. |
| Sélection modifiée | Multi | Étiquette « Modifiée » en tête de la Sélection ; échanges suggérés et « Revenir au pronostic du modèle » sous la liste ; confiance, chevaux les plus probables et systèmes recalculés pour la sélection modifiée. |
| Pronostic retenu, avant le départ | Multi | Étiquette « Pronostic retenu à 9 h 52 » ; « Je retiens ce pronostic » devient « Remplacer mon pronostic retenu » ; « Modifiable jusqu'au départ (15 h 05) » dans l'en-tête. |
| Pronostic figé (départ passé) | Multi | Lecture seule ; « 🔒 Pronostic figé au départ (15 h 05) » remplace le CTA. Les contrôles (taille, interrupteurs, lignes, formules) passent en état désactivé et restent visibles ; une action lancée après le départ échoue avec un message explicite, jamais en silence. Bascule en direct si l'écran est ouvert à l'heure du départ (comportement d'accessibilité : Accessibility Floor). |
| Grilles — copie réussie | Feuille des grilles | « 11 tickets copiés » visible et annoncé ; puis « Retenir ce pronostic ? » (« Retenir » / « Plus tard »), persistant jusqu'à une action ou la fermeture. « Plus tard » : rien n'est enregistré, l'invitation ne revient qu'à la copie suivante. Pas d'invitation si ce pronostic est déjà le pronostic retenu ou s'il est figé. `[ASSUMPTION]` |
| Grilles — copie impossible | Feuille des grilles | « Copie impossible — réessayez » ; les grilles restent lisibles à l'écran. `[ASSUMPTION]` |
| Grilles — pronostic figé | Feuille des grilles | Lecture et copie possibles ; aucune invitation à retenir. |
| Grilles — carte de couverture dépliée | Feuille des grilles | Trois lignes texte « Couvertes 1 fois : N combinaisons », « 2 fois », « 3 fois » ; repli par le même en-tête. `[ASSUMPTION]` |
| Mes pronostics Multi — vide | Accueil | Section masquée tant qu'aucun pronostic n'a été retenu et qu'aucun Multi n'a été consulté dans les 90 derniers jours. `[ASSUMPTION]` |
| Multi consulté sans pronostic retenu | Accueil (« Mes pronostics Multi ») | Entrée avec la seule ligne « Pronostic du modèle : … » et « Votre pronostic : aucun pronostic retenu ». `[ASSUMPTION]` |
| Purge à 90 jours | Accueil (« Mes pronostics Multi ») | Les entrées de plus de 90 jours disparaissent sans message ; pied de section « Conservés 90 jours sur ce téléphone ». `[ASSUMPTION]` |
| Débrief en attente / disponible / corrigé | Accueil (« Mes pronostics Multi ») et Multi | « En attente du résultat » → « 3 chevaux capturés sur 4 · arrivée dans la sélection : non » (votre pronostic et pronostic du modèle) → « Arrivée corrigée » le cas échéant. |
| Multi en état débrief (lecture seule) | Multi, ouvert depuis « Mes pronostics Multi » | En-tête avec l'arrivée (4 premiers en dossards) et « 🔒 Pronostic figé au départ (15 h 05) » ; les deux `debrief-row` sous l'en-tête ; puis le pronostic retenu tel qu'enregistré (taille, confiance, sélection, chevaux les plus probables, formule) en lecture seule, chevaux de l'arrivée marqués « Capturé » en texte ; Évaluation, Autres méthodes et rappel visibles ; la barre ne garde que « Voir les grilles ». `[ASSUMPTION]` |
| Hors ligne | Multi | Fonctionnement identique (calcul local) ; seuls le rafraîchissement des non-partants et le débrief attendent le réseau, avec message clair. |
| Focus clavier/accessoire externe | Toute surface avec champs (Configuration course, Fiche cheval, Réglages, Multi et ses feuilles) | `focus-indicator` (DESIGN.md : contour or 2px) sur l'élément actif ; ordre de tabulation suit l'ordre de lecture visuel de haut en bas. |

## Interaction Primitives

- Tap pour éditer un champ ou développer une carte résultat en place (accordéon, pas une navigation).
- Tap sur une ligne de performance → feuille d'édition dédiée plutôt qu'édition inline multi-champs (résout la tension entre densité visuelle et cibles tactiles ≥ 48dp — voir Component Patterns, Accessibility Floor).
- Swipe-to-delete sur une carte partant (retirer un cheval de la liste analysée), avec confirmation légère (pattern natif Android, pas de dialogue modal bloquant).
- Pull-to-refresh sur l'accueil (programme du jour) et sur la liste des partants (cotes en direct) — jamais de rafraîchissement automatique en arrière-plan (PRD FR-14).
- Édition inline dans les champs de réglage moteur (peu nombreux, un par ligne — pas de contrainte de densité comparable à la ligne de performance).
- Multi : la taille se règle au `size-stepper` (« − » / « + », 4 à 20) ; le recalcul part après une courte pause (environ 800 ms sans nouveau tap), jamais à chaque tap, sans bouton. Tap sur une ligne cheval → `multi-actions-sheet` ; tap sur un cheval le plus probable (puce entière) → bascule de la base ; tap sur une formule → elle devient la formule affichée ; « Voir les grilles » en feuille modale ; « Autres méthodes » en section repliable. Un seul niveau de modal à la fois.
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
- Emojis et glyphes (🔒 ✎ ▾ ▸ ⧉ − +, et aussi 🔥 ⚠️ 🐎 ✨ ℹ️) sont décoratifs pour TalkBack (`ExcludeSemantics`) : le lecteur d'écran lit le texte seul (« Confiance moyenne », « Pronostic figé au départ, 15 heures 05, lecture seule »). L'état d'un repli est porté par la sémantique déplié/replié, jamais par le glyphe.
- Multi — taille : le `size-stepper` est un seul nœud ajustable (« Taille de la sélection, 12 chevaux, de 4 à 20 »), réglable par les gestes d'ajustement TalkBack (balayage haut/bas) en plus des deux boutons ; chaque bouton porte un libellé (« Un cheval de moins », « Un cheval de plus ») et son état désactivé à une borne.
- Multi — lecture : la confiance est annoncée en premier après la taille, raisons comprises (« Confiance moyenne. Arrivée dans la sélection : 31 pour cent, estimé. Course ouverte. Données : 1 cheval à historique court »). Les libellés de section (« Taille de la sélection », « Confiance », « Sélection », « Chevaux les plus probables », « Systèmes », « Évaluation », « Autres méthodes ») et les titres des feuilles sont des en-têtes TalkBack. Une ligne cheval est un nœud groupé (dossard, nom, top 4 estimé, contribution, base ou non). Une ligne de formule est un nœud groupé (« Multi en 7 : 11 tickets, 3 tickets physiques, affichée »). Les mentions « L'outil ne place aucun pari », « Couverture garantie — pas un gain garanti » et le rappel de jeu responsable font partie du flux de lecture.
- Multi — recalcul : après un changement de taille, déclenché après une courte pause (environ 800 ms sans nouveau tap), jamais à chaque tap. Après tout recalcul (taille, base, retrait, ajout, échange, non-partant, retour de Réglages), une seule annonce polie, seulement si le niveau de confiance a changé : « Confiance élevée. Arrivée dans la sélection : 52 pour cent, estimé. » Niveau inchangé : aucune annonce. Le focus ne bouge pas.
- Multi — messages : les `status-banner` qui apparaissent sans ouverture d'écran (non-partant, pronostic retenu touché par un non-partant, règles à vérifier, classement modifié) sont des régions live polies, annoncées une fois. La copie des grilles est annoncée (« 11 tickets copiés ») ; « Retenir ce pronostic ? » n'expire pas et reste atteignable au balayage.
- Multi — feuilles (`multi-actions-sheet`, `horse-picker-sheet`, `system-entry-sheet`, `tickets-sheet`) : focus initial sur le titre (« N° 7, Ondine Royale ») ; le contenu dessous est inerte pour TalkBack ; fermeture par le retour système, le voile ou un bouton « Fermer » visible (la poignée seule ne suffit pas). Fermeture sans action → focus rendu à l'élément d'origine (« Voir les grilles », la ligne). Après « Retirer » ou « Marquer non-partant » → focus sur le bandeau de confirmation, à défaut sur la ligne suivante. Les actions d'état s'annoncent avec leur état (« Base : oui »).
- Multi — grilles : chaque ticket est un nœud groupé (« Ticket 1 : base 11 ; 2, 4, 7, 9, 13, 15 ») ; chaque ticket physique est un en-tête (« Ticket physique 1, tickets 1 à 4 ») ; la base est repérée sans couleur (première colonne, gras, légende).
- Multi — états : niveau de confiance (« Confiance élevée / moyenne / faible »), « Affichée » (avec l'état sémantique « sélectionné »), « Modifiée », « Base », « Écarté » et « Pronostic figé » sont toujours du texte, jamais une couleur ou une bordure seules — l'or de la confiance élevée est toujours doublé de son libellé. Un cheval le plus probable est une seule cible, rôle interrupteur, libellé « Cheval le plus probable numéro 11, top 4 estimé 58 pour cent, en base moins 4 points », avec la description d'état « base imposée dans tous les tickets » ou « interdite comme base » à la place de activé/désactivé.
- Multi — départ : « Modifiable jusqu'au départ (15 h 05) » fait partie du flux de lecture. Au départ, annonce polie « Départ passé : pronostic figé, lecture seule » ; si le focus était sur le CTA, il passe à l'étiquette « Pronostic figé au départ, 15 heures 05 » ; les contrôles passent en état désactivé, lu par TalkBack.
- Multi — grandes tailles de police : la `multi-action-bar` est sous le contenu, jamais par-dessus, masquée clavier ouvert, réduite au CTA plein au-delà de 130 % ; le focus n'est jamais masqué par elle. Aucune valeur chiffrée ni aucun dossard n'est coupé par une ellipse : les paires libellé/valeur passent en pile, les lignes de formule s'enroulent, le `size-stepper` garde ses deux boutons de 48dp et passe sa valeur sous le libellé, les tickets se lisent en ligne de texte. Seuls les noms de chevaux s'enroulent, jamais coupés.
- Multi — texte lu : les abréviations sont développées (« moins 6 points », « numéro 11 ») et « · » devient une pause (virgule). Chaque `debrief-row` commence par son sujet (« Votre pronostic : 3 chevaux capturés sur 4, arrivée dans la sélection : non » ; « Pronostic du modèle : … »).

## Responsive & Platform

Android uniquement en V1, formats de téléphone courants (portrait principal — les tableaux denses de courses à beaucoup de partants restent verticaux via les cartes empilées, jamais de rotation forcée en paysage). Pas de layout tablette envisagé (`[OPEN QUESTION]`, à trancher si la demande se présente). Conventions de navigation Android natives honorées (retour système, pas de geste custom qui les court-circuite).

## Inspiration & Anti-patterns

- **Repris des tableaux de cotes / terminaux de trading** : densité assumée, chiffres tabulaires stricts, une seule couleur d'accent pour le signal principal.
- **Repris du prototype HTML (`analyse_hippique_v2.html`), transformation mobile déjà validée** : le tableau de résultats devient une liste de cartes empilées avec libellé préfixé par valeur sur petit écran — pattern directement porté en natif plutôt que réinventé.
- **Rejeté — mécaniques de gamification (streaks, badges de progression, notifications de relance)** : cohérent avec le PRD (Non-Goals, SM-C1) — la fréquence d'usage n'est explicitement pas un objectif produit ; rien dans l'UX ne doit pousser à l'usage compulsif.
- **Rejeté — vocabulaire de certitude ("coup sûr", "gagnant garanti")** : le produit est un outil d'aide à la décision, jamais un générateur de certitudes (PRD §1 Vision) — non négociable, y compris dans une future itération marketing de la microcopie.
- **Rejeté — action de pari en un tap depuis les résultats** : aucune fonctionnalité de placement de pari automatisé, à aucune version (PRD Non-Goals, absolu).

## Key Flows

*Mêmes protagoniste et numérotation que le PRD (§2.3) — UJ-1, UJ-2, UJ-3, UJ-4 — cette section les rejoue au niveau des écrans plutôt que des capacités.*

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

### UJ-4 — Marc établit son pronostic Multi du samedi

→ Maquette des étapes 5 à 9 : `mockups/multi.html` (écran Multi après retouches, 13 chevaux dont 1 base, et feuille des grilles). La spine gagne en cas de conflit.

*Récit du porteur de projet réécrit selon le recadrage du 2026-10-18 (§D ter) : un pronostic, sans argent.* Samedi, 9 h 40, chez lui, connecté.

1. Résultats de la course support calculés → il touche « Multi », en tête de Résultats. L'écran s'ouvre sur « 18 partants · course éligible », « Cotes de 9 h 38 » et « L'outil ne place aucun pari » ; premier passage, la taille est à 10 chevaux et tout est déjà calculé sur le téléphone.
2. Il veut un pronostic plus large : deux taps sur « + » → « 12 chevaux ». Après une courte pause, la sélection se recalcule, sans bouton.
3. Carte confiance : « Confiance moyenne », « Arrivée dans la sélection : 34 % (estimé) · course ouverte · données : 1 cheval à historique court », étiquettes « modèle en cours d'évaluation » et « seuils provisoires ». Le niveau n'a pas changé depuis 10 chevaux : rien n'est annoncé.
4. Sélection : chaque ligne dit « Top 4 estimé 41 % · contribution −6 pts » ; les trois écartés les plus proches disent pourquoi.
5. Il sait qu'un cheval ne partira pas : tap sur la ligne → « Marquer non-partant ». Bandeau « Non-partant : n° 7 — pronostic recalculé » ; le modèle le remplace, la taille reste 12. Il touche « + Ajouter un cheval » et choisit un cheval auquel il croit : 13 chevaux, la section passe en « Modifiée » et propose un échange qu'il ignore.
6. Chevaux les plus probables (aucun n'est actif au départ) : il lit « Top 4 estimé 58 % · en base −4 pts » et active le premier comme base ; la carte confiance se met à jour (« Arrivée dans la sélection, bases comprises : 31 % (estimé) »), toujours « Confiance moyenne ».
7. **Climax** — Systèmes : pour ses 13 chevaux dont 1 base, chaque formule dit son nombre de tickets et de tickets physiques, sans aucun prix ; Multi en 7 est « Affichée », avec « Si les 4 premiers sont dans votre sélection et incluent votre base, au moins un de vos tickets les contient tous » et « Couverture garantie — pas un gain garanti ». Il voit en un écran quels chevaux peuvent faire l'arrivée, avec quelle confiance, et ce que ses grilles couvrent.
8. Évaluation : arrivée dans la sélection 38 % (estimé), 31 % bases comprises, distribution des chevaux capturés de 0 à 4. Par curiosité, il déplie « Autres méthodes » : la méthode 1, règle par règle, porte « hypothèse non validée ».
9. Il touche « JE RETIENS CE PRONOSTIC » (« Pronostic retenu à 9 h 52 »), ouvre « Voir les grilles », copie les grilles en dossards (« 15 tickets copiés ») et ferme l'app.
10. Le lendemain, « Mes pronostics Multi » sur l'Accueil affiche « Votre pronostic : 3 chevaux capturés sur 4 · arrivée dans la sélection : non », et la ligne correspondante pour le pronostic du modèle.

Échec : sur l'hippodrome sans réseau, un non-partant est annoncé au micro → il le marque à la main ; le recalcul est local et un bandeau signale que son pronostic retenu contient ce non-partant (état « Non-partant déclaré »).
