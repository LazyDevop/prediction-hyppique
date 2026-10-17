# PRD Quality Review — prediction-hyppique

*Revue du 2026-10-17, après l'ajout du module Multi (§4.11 FR-22 à FR-30, UJ-4, glossaire, §5, §6, SM-4/SM-5/SM-C3, §8, Open Questions 8-11, addendum §G).*

## Overall verdict

Le PRD tient bien : la thèse (probabilité chiffrée, transparente, comparée au marché, avec une limite assumée) est nette, les non-goals font un vrai travail, et le module Multi arrive avec ses décisions tranchées (pas de mise, presse exclue, comparateurs à part, mentions obligatoires) et des conséquences testables de bonne qualité. Ce qui est fragile : l'évaluation du Multi (SM-4/SM-5 et le débrief FR-30) repose sur une « recommandation du modèle » journalisée côté backend dont le budget et les paramètres ne sont pas fixés dans le PRD. Le vocabulaire Multi a aussi été ajouté sans discipline de glossaire complète (« sélection », « indice de valeur », « Combinaison » surchargé, « document Multi » vs « cahier Multi »). S'y ajoutent deux défauts plus anciens qui restent ouverts : SM-3 ne peut pas être mesuré, et la référence croisée de FR-3 est cassée.

## Decision-readiness — adequate

Les décisions sont énoncées comme des décisions, pas comme des « considérations ». Le §9.1 tranche le conflit brief/cahiers en faveur du mono-utilisateur, et il nomme ce qui est abandonné (le freemium, renvoyé au §10). Le §10 justifie la structuration solo par un mécanisme précis : la dépendance à la source grandit avec la traction. Côté Multi, les décisions D0-D7 sont visibles dans le texte : « Le module Multi ne recommande aucune mise ni multiplicateur » (§5), la méthode 2 est exclue (§5, §6.2), et le verdict n'utilise « ni l'indice de valeur (non calibré) ni aucune donnée de presse » (FR-26). Les Open Questions 8 à 11 sont réellement ouvertes et disent ce qu'elles conditionnent (OQ9 : « conditionne l'évaluation financière (FR-30), pas la recommandation »).

Ce qui manque, c'est le coût de l'ajout du Multi au MVP. Le §6.1 ajoute 8 endpoints, une journalisation quotidienne, l'ingestion des rapports, un harnais de backtest et un pilote d'évaluation. C'est probablement le plus gros bloc du MVP, et rien ne dit ce que cela retarde ou ce qui a été mis en balance : le Multi peut-il sortir après le cœur value/Kelly, par exemple ? Le seul arbitrage écrit est la justification du harnais (« sans eux, ni les seuils par défaut du verdict ni les performances affichées des méthodes n'existent »). Il explique pourquoi le harnais est nécessaire au Multi, pas pourquoi le Multi doit être dans le MVP.

### Findings

- **medium** Ajout du Multi au MVP sans arbitrage nommé (§6.1, §12 « Module Multi dans le MVP ») — La décision D0 est indexée comme confirmée, mais le PRD ne dit pas ce qu'elle coûte au reste du MVP : le séquencement face au cœur §4.3-4.5 et la charge du backtest et du pilote avant que les seuils existent. Un décideur qui conteste « pourquoi pas en V1.1 ? » ne trouve pas de réponse. *Fix:* ajouter une phrase au §6.1 ou au §4.11 qui nomme le compromis (ce qui est retardé, ou pourquoi le Multi ne peut pas attendre) et l'ordre de livraison attendu par rapport au moteur de base.
- **low** §8 et OQ11 se contredisent sur la portée de l'anglais (§8, §11 OQ11) — Le §8 tranche : « Les libellés de transparence de FR-4 et l'extraction par photo restent en français ». L'OQ11 rouvre pourtant « sa portée exacte (libellés de FR-4, prompts d'extraction) ». *Fix:* soit le §8 dit « restent en français dans le MVP, portée post-MVP : OQ11 », soit l'OQ11 se limite au calendrier.

## Substance over theater — strong

Il n'y a pas de théâtre de persona : Marc est le seul protagoniste, et chaque UJ pilote des FR précises. UJ-2 pilote §4.6, UJ-3 pilote §4.8 et UJ-4 pilote §4.11. La différenciation (§1) s'appuie sur une recherche de marché nommée (EquinEdge, RebelBetting/OddsJam, l'absence de Kelly en hippisme), et la Vision avoue sa limite (« le modèle est aveugle à l'information tactique et humaine »). Le paragraphe Multi de la Vision a un angle propre et vérifiable : « une couverture garantie, jamais un gain garanti ». Il reprend la même posture d'honnêteté que la thèse principale, au lieu d'être une feature collée.

Le seul résidu d'adjectif est l'NFR de performance (« perçu comme instantané », §8). Il est honnêtement renvoyé à l'OQ1, et il est traité sous Done-ness.

### Findings

- **low** Gap concurrentiel du Multi affirmé, pas sourcé (§1, 3e paragraphe) — « la question que les "systèmes garantis" du commerce évitent » : contrairement au paragraphe 1, qui cite une recherche de marché, cette affirmation ne renvoie à aucune source. *Fix:* citer la source (brainstorming, cahier Multi §1, ou observation du porteur de projet), ou marquer `[ASSUMPTION]`.

## Strategic coherence — adequate

La thèse est claire et tenue : le §7 en fait le critère primaire (calibration plutôt que ROI, avec une portée explicite de SM-1 contre l'expertise humaine), et les contre-métriques SM-C1/SM-C2/SM-C3 bloquent l'optimisation des signaux pour eux-mêmes. Le Multi s'inscrit dans cet arc : SM-4 calibre la probabilité de couverture contre le marché, SM-5 calibre le verdict, et SM-C3 empêche de régler les seuils pour produire plus de « jouer ». C'est cohérent avec la logique de SM-1/SM-C2.

Deux failles. D'abord, SM-3 est inmesurable dans le produit tel qu'il est cadré : aucune FR ne capture les paris effectivement placés, l'app est mono-utilisateur sans envoi serveur, et FR-30 ne conserve que la *sélection retenue* du Multi, pas une mise jouée. Ensuite, la mesure du Multi dépend d'une recommandation journalisée côté backend (FR-30), alors que la recommandation est par construction fonction du budget (FR-23), des seuils du verdict réglés par l'utilisateur (FR-26) et des coefficients du moteur réglés par l'utilisateur (FR-20). Le PRD ne dit pas à quels budget et paramètres le backend journalise. Le cahier Multi (§ journalisation, « à des budgets de référence fixés au pilote ») le dit, mais SM-4/SM-5 et le débrief de FR-30 n'ont pas de sens sans ce point.

### Findings

- **high** La recommandation journalisée n'est pas définie au niveau du PRD (FR-30, SM-4, SM-5, UJ-4 Résolution) — FR-30 : « le backend journalise la recommandation du modèle […] avant le départ ». Or FR-23 rend la recommandation dépendante du budget, et FR-20/FR-26 rendent seuils et coefficients modifiables par l'utilisateur. Conséquences : (1) on ne sait pas ce que SM-4/SM-5 mesurent ; (2) le débrief « X chevaux sur 4 capturés […] pour la recommandation du modèle » peut porter sur une recommandation différente de celle que l'utilisateur a vue. Dans UJ-4, Marc a joué 33 € avec une base qu'il a choisie. *Fix:* ajouter à FR-30 que la journalisation se fait aux paramètres par défaut et aux budgets de référence fixés par le pilote (cahier Multi §8), gelés pour la période de test. Préciser que le débrief « recommandation du modèle » montre la recommandation journalisée, et que la sélection retenue sur l'appareil porte, elle, les paramètres de l'utilisateur.
- **high** SM-3 n'a aucun moyen de mesure (§7 SM-3) — « Proportion des mises que l'utilisateur place effectivement sur des chevaux signalés "value" » : aucune FR ne saisit les mises placées, le §5 exclut toute connexion à un compte de jeu, et le §9.1 exclut compte et télémétrie. SM-3 est le seul indicateur de changement de comportement (sa contrepartie SM-C1 en dépend). *Fix:* soit ajouter une FR de journal de paris déclaratif local (« j'ai joué ce cheval, cette mise »), soit requalifier SM-3 comme mesure manuelle du porteur de projet en V1, soit le reporter en V2 avec le compte.
- **low** Rang des métriques Multi ambigu (§7) — SM-4 et SM-5 sont rangés sous « Secondary » après une ligne vide, sans intertitre. Or SM-4 est l'équivalent Multi de SM-1 (primaire) et conditionne la levée de « modèle en cours d'évaluation » (FR-23). *Fix:* intertitre « Multi » ou mention explicite « SM-4 est le critère primaire du module Multi ».
- **low** SM-C3 est rattaché à une FR, pas à une SM (§7 SM-C3) — « Contrepartie de FR-26 », alors que SM-5 se dit « Contrepartie positive de SM-C3 ». *Fix:* « Contrepartie de SM-5 », pour l'homogénéité avec SM-C1/SM-C2.

## Done-ness clarity — adequate

Les FR Multi sont dans l'ensemble les mieux spécifiées du document. Elles sont déterministes (FR-23 « À données et budget identiques, la recommandation est identique »), vérifiables par construction (FR-25 « Aucun système n'est affiché si une combinaison exigée par sa garantie n'est pas couverte »), comparées à une référence (FR-25 « au plus autant de tickets que le document ») et contraintes contre la fuite d'information (FR-30 « aucune donnée postérieure à l'heure de ses données »). Les mentions obligatoires sont citées mot pour mot.

Il reste des zones floues. Le déclencheur « non-partant déclaré » hors ligne n'est pas précisé (qui le déclare ?). L'NFR de performance du §8 ne couvre pas le calcul Multi sur l'appareil. FR-3 contient une référence croisée fausse. Côté existant, FR-16 garde « fréquence d'appel raisonnable » (adossée à l'OQ6) et FR-1 garde « quand disponible ».

### Findings

- **medium** Source du non-partant hors ligne non définie (FR-23 dernière conséquence, UJ-4 Edge case) — FR-23 : « un non-partant déclaré relance le calcul localement ». UJ-4 : « sur l'hippodrome sans réseau, un non-partant est annoncé à la dernière minute → la recommandation se recalcule ». Sans réseau, l'app ne peut pas recevoir l'annonce. Est-ce l'utilisateur qui marque le cheval (via FR-6, FR-28) ? Et en quoi cela diffère-t-il d'un retrait qui fait passer la sélection en « modifiée » (FR-28) ? *Fix:* préciser que l'utilisateur marque le non-partant (geste distinct du retrait volontaire), que la recommandation est alors recalculée sans passer en « modifiée », et définir le comportement en ligne (rafraîchissement explicite, cohérent avec FR-14).
- **medium** NFR de performance non étendue au Multi (§8 « Performance du calcul local ») — Le périmètre listé est « score → probabilités → combinaisons, y compris la simulation Monte-Carlo ». La recherche de sélection, de bases et de formule sous budget sur 14 à 20 partants (FR-23), relancée à chaque bascule de base (FR-24) ou retouche (FR-28), n'y figure pas, alors qu'elle s'exécute sur l'appareil. *Fix:* étendre la puce du §8 au calcul Multi (et à l'OQ1).
- **medium** Référence croisée fausse dans FR-3 (§4.1 FR-3) — « bascule sans friction vers la saisie manuelle ou l'import photo (FR-9, FR-10) » : FR-9 et FR-10 sont la value et Kelly. Les cibles sont FR-5/FR-6 (saisie) et FR-18/FR-19 (import). Le défaut existait avant la mise à jour, mais une story générée depuis FR-3 pointerait au mauvais endroit. *Fix:* remplacer par « (FR-5, FR-6, FR-18, FR-19) ».
- **low** FR-28 et UJ-4 décrivent l'échange proposé différemment (FR-28, UJ-4 Parcours) — FR-28 : « les 1 à 2 échanges qui l'améliorent le plus ». UJ-4 : « l'échange qui coûte le moins de couverture ». *Fix:* aligner la formulation de l'UJ sur FR-28.

## Scope honesty — adequate

Les non-goals font un vrai travail. Ils ont été étendus proprement au Multi, et la méthode 2 est explicitement raccrochée au non-goal presse existant (§5 : « conformément au non-goal presse ci-dessus »). Le §6.2 liste les exclusions Multi précises (systèmes mixtes, Flexi, indice de valeur dans le verdict) et la décision sur l'anglais, datée. La densité d'éléments ouverts (11 OQ, 1 `[ASSUMPTION]` inline, 1 `[NOTE FOR PM]`) est raisonnable pour un MVP personnel sans date de lancement.

Une omission reste implicite. FR-29 n'expose à l'utilisateur que la méthode 1 et le marché, alors que le glossaire inclut le tirage au hasard dans les comparateurs. On ne sait pas si le tirage au hasard est volontairement absent de l'écran ou seulement journalisé.

### Findings

- **medium** Liste des comparateurs incohérente (§3 Comparateur, FR-29, FR-30) — Glossaire : « méthode 1 du document Multi, marché, tirage au hasard ». FR-29 : « méthode 1 […] et marché ». FR-30 journalise « les comparateurs » sans les lister. *Fix:* dire dans FR-29 que le tirage au hasard est journalisé et mesuré mais non affiché (ou l'afficher), et lister les trois comparateurs dans FR-30.
- **low** Les chiffres de UJ-4 dépendent d'une règle non vérifiée (UJ-4, OQ8) — « 11 tickets, 3 tickets physiques », pour 33 €, suppose une mise unitaire de 3 € par ticket de 7, issue de la source 2001-2002 que l'OQ8 demande justement de revérifier. *Fix:* une note d'une ligne dans UJ-4 (« montants illustratifs, prix unitaire à confirmer — OQ8 »).

## Downstream usability — adequate

Les IDs sont propres : FR-1 à FR-30 sont contigus et l'index du §4 est exact, UJ-1 à UJ-4 aussi, ainsi que SM-1 à SM-5 et SM-C1 à SM-C3. Les sections Multi renvoient au glossaire (« course support », « base », « verdict », « comparateur »), et le §4.11 se lit seul. Mais la mise à jour a introduit des termes clés sans les définir, et elle a surchargé un terme existant, alors que le §0 promet que « ce PRD utilise les termes du §3 Glossaire de façon stricte ». Pour la génération de stories et l'architecture, ce sont exactement les noms qui deviendront des entités.

### Findings

- **medium** « Combinaison » est surchargé (§3 Combinaison, §3 Système réduit, FR-25) — Le glossaire définit une Combinaison comme un *type de pari* (couplé, tiercé, quarté, quinté). Le Multi l'emploie au sens d'*ensemble de 4 chevaux à couvrir* : « couvre toutes les combinaisons de 4 chevaux », « une combinaison exigée par sa garantie ». Le §4.5 « Combinaisons de paris » et FR-21 (« exporter […] les combinaisons ») deviennent ambigus. *Fix:* introduire un terme distinct (« quadruplet » ou « combinaison de 4 (Multi) ») dans le glossaire et l'utiliser dans §3 Système réduit et FR-25.
- **medium** Termes Multi clés absents du glossaire (FR-23 à FR-30, UJ-4) — « sélection » (le nom central du module), « indice de valeur » (FR-26, FR-30, §6.2, distinct de **Value** mais non défini, donc risque de confusion), « formule » / « formule intégrale », « ticket » / « ticket physique », « chevaux capturés », « rapport Multi en k », « protocole d'évaluation » / « pilote d'évaluation », « période gelée » (SM-5). *Fix:* ajouter au §3 au minimum Sélection, Indice de valeur (avec sa différence avec Value), Formule (Multi en k), Ticket / ticket physique, Capturé.
- **medium** « document Multi » et « cahier Multi » ressemblent à des synonymes (FR-25, FR-29, §3 Comparateur, §5, §7 SM-4, §11 OQ8) — « méthode 1 du document Multi », « catalogue du document source », « document de 2001 » (addendum §G) désignent la source de 2001. « cahier Multi §8 » désigne `cahier_des_charges_module_multi.md`. Un lecteur extérieur ne peut pas les distinguer. *Fix:* nommer la source une fois au §0 (par ex. « le document Multi de 2001 ») et l'ajouter au glossaire.
- **low** Préfixe des endpoints Multi ambigu (§6.1) — La liste commence par `/courses/{id}/multi/eligibilite`, puis passe à `/multi/recommandation`, `/multi/systemes`… On ne sait pas si ces derniers sont sous `/courses/{id}`. *Fix:* écrire les chemins complets ou préciser « tous sous `/courses/{id}` ».

## Shape fit — strong

Le format convient : il s'agit d'un produit grand public (même si V1 est personnel), avec une UX trackside contrainte et une chaîne aval (UX → architecture → stories). Les UJ avec un protagoniste nommé portent du poids et ne sont pas surformalisées. UJ-4 est plus dense que les autres et embarque ses propres « Critères d'acceptation ». C'est un choix défendable vu l'importance des mentions obligatoires, et chaque critère se retrouve dans une FR (FR-23, FR-25, FR-27, FR-29, FR-30). La réécriture du récit d'origine pour suivre D0-D7 est tracée (§12, addendum §G). La spécification normative est déléguée aux cahiers, avec une règle de préséance claire au §0.

### Findings

- **low** Le Marc de UJ-4 diverge légèrement du Marc de UJ-1 à UJ-3 (UJ-4 Persona) — UJ-1 : « parieur individuel régulier » qui prépare le Quinté+ la veille. UJ-4 : « 38 ans, joue au Multi le week-end par plaisir, avec un budget fixe ». Ce n'est pas contradictoire, mais le budget fixe de UJ-4 cohabite avec la bankroll/Kelly de FR-10 sans que le lien soit dit (le budget Multi est-il pris sur la bankroll ?). *Fix:* une phrase dans §4.11 ou FR-23 : le budget Multi est indépendant de la bankroll Kelly (ou en dérive).

## Mechanical notes

- **Assumptions Index roundtrip** : un seul `[ASSUMPTION]` inline (§9.1), contre 9 entrées au §12. Les 8 autres, dont les 4 nouvelles du 2026-10-17 (§4.11 D0-D7, UJ-4, §6.2/§8 langue, FR-30 débrief), n'ont pas de balise inline à l'endroit cité. Ce sont des décisions confirmées plutôt que des hypothèses : soit les baliser inline, soit renommer le §12 « Décisions et hypothèses confirmées ».
- **Référence croisée** : FR-3 renvoie à « FR-9, FR-10 » au lieu des FR de saisie et d'import (voir Done-ness).
- **Citation inexacte** : §4.9 cite le §1 comme « chaque coefficient est visible et modifiable par l'utilisateur », alors que le §1 dit « visible et réglable par l'utilisateur ».
- **Termes non glossairés préexistants** : « course cible » (omniprésent), « value forte » (UJ-1), « bankroll » (FR-10, FR-20).
- **Incident / non-partant** : le glossaire range le Non Partant (NR) sous **Incident**, alors que le Multi (FR-23, FR-22) emploie « non-partant » au sens d'un retrait du jour de la course. Il faudrait une entrée « Non-partant » distincte de NR-dans-l'historique.
- **UJ-4** : « un cheval qu'il sait forfait de cœur » est ambigu (forfait = non-partant, ou choix personnel ?), ce qui touche la distinction non-partant / sélection « modifiée » de FR-28.
- **§4.9 titre** : « Réglages du moteur » inclut désormais les seuils du verdict Multi (FR-20), ce qui est cohérent avec FR-26. Ajouter « Réalise UJ-4 » à la description du §4.9.
- **IDs** : FR, UJ et SM sont contigus, uniques, et l'index du §4 est à jour. Aucun doublon.
