# Réconciliation — cahier des charges module Multi (v2) vs PRD + addendum

*Document source analysé : `docs/cahier_des_charges_module_multi.md` (v2, 2026-10-17).*
*Documents cibles : `prd.md` (§0, UJ-4, §3 Glossaire, §4.11 FR-22 à FR-30, §5, §6, §7 SM-4/SM-C3, §8, §11) + `addendum.md`.*

**Principe rappelé** : le PRD est volontairement écrit au niveau produit/capacité. Les
constantes de `regles.py`, l'algorithme d'échanges de 4.1, les formules de
`p_couverture` / entropie / indice de valeur, les paliers du générateur (formes
closes, MILP, recuit), les schémas de tables, le contrat JSON de l'API, les règles
de M1/M2, les 16 tests, les annexes A-D et le plan de développement doivent rester
dans le cahier et y être pointés. Leur absence dans le PRD n'est **pas** listée
ci-dessous comme un écart.

**Verdict global** : la réconciliation est **bonne sur le fond, avec trois
contradictions à trancher**. Les décisions D0-D7 (le modèle décide, pas de mise
recommandée, M2 reportée, verdict, 3 bases candidates, choix sous budget,
explications en codes) sont toutes reprises fidèlement dans §4.11, §5, §6.2 et
l'index des hypothèses. Les mentions obligatoires principales, la vérification
systématique des systèmes, le calcul local, la journalisation avant départ,
l'absence de fuite temporelle et les métriques SM-4 / SM-C3 sont bien là. En
revanche : (1) le PRD repousse l'anglais après le MVP alors que le cahier le met
en V1 pour toute l'application ; (2) le PRD laisse entendre que la recommandation
consultée par l'utilisateur est journalisée et débriefée, ce que le cahier exclut
explicitement ; (3) le PRD affirme qu'une option hors budget n'est « jamais
supprimée » alors que l'algorithme du cahier filtre ces options. S'y ajoutent une
mention obligatoire manquante (« modèle en cours d'évaluation »), une référence de
comparaison inversée dans le glossaire, et le harnais de backtest / pilote absent
du périmètre MVP.

---

## Écart 1 — Affichage FR/EN : V1 dans le cahier, après le MVP dans le PRD (contradiction)

**Ce que dit la source (§1, §4.0 « Langue (D6) », §11.2, §12 n°8, §13 étape 5, §9 test 16)** :
> « Dans le périmètre V1 : … écran mobile ; affichage FR/EN. »
> « Les libellés de l'écran Multi — et de toute l'application — sont disponibles en
> français et en anglais, au choix de l'utilisateur (réglage persisté, français par
> défaut). » — « Exigence transverse confirmée pour toute l'application (pas
> seulement le Multi), à ajouter au PRD. »
> Test 16 : « chaque code d'explication a un libellé FR **et** EN dans le catalogue de l'app. »

**Ce qu'on trouve dans le PRD/addendum** : §6.2 place « l'affichage de
l'application en anglais » hors MVP, avec `[ASSUMPTION: lecture de la réponse « a »
du porteur de projet, à confirmer]` ; §8 précise que « les libellés de
transparence de FR-4 et l'extraction par photo restent en français » ; FR-27 parle
de codes « pour permettre leur traduction **ultérieure** » ; Open Question 11 porte
sur le calendrier de l'anglais. Le PRD et le cahier, datés du même jour, divergent
donc frontalement : le cahier v2 dit « réalignée sur le PRD » mais exige l'anglais
en V1 (test 16 bloquant), le PRD le repousse.

**Recommandation** : gravité **majeure** (impact sur le chiffrage, les tests et
l'architecture mobile). Faire trancher le porteur de projet sur la réponse « a »,
puis aligner l'un des deux documents : soit le PRD remonte l'anglais en MVP (§6.1,
§8, suppression de l'hypothèse et de l'OQ 11), soit le cahier v2 est corrigé (§1,
§11.2, §13 étape 5, et test 16 réduit à « chaque code a un libellé FR ; le
catalogue est structuré pour accueillir EN »). Le point commun — explications en
codes + paramètres dès le MVP — est déjà aligné.

---

## Écart 2 — Journalisation et débrief : la recommandation consultée n'est pas journalisée côté serveur (contradiction)

**Ce que dit la source (§7, dernière règle ; §8.4)** :
> « Mode `live` : le job quotidien journalise, pour la course support, la
> recommandation `modele` (à des **budgets de référence fixés au pilote**) et les
> comparateurs `M1`, `B0`, `B1`, avant le départ. **La recommandation affichée à
> l'utilisateur sur son appareil n'est pas journalisée côté serveur** (V1
> mono-utilisateur, sans compte). »

Le cahier ne spécifie par ailleurs **aucun** débrief côté application (11.1 ne
contient pas d'écran ou de bloc « résultat ») : `resultat_recommandation` n'est
rempli que pour les lignes journalisées par le serveur.

**Ce qu'on trouve dans le PRD/addendum** :
- UJ-4, critère d'acceptation : « la recommandation est journalisée avec l'heure
  des données utilisées, avant le départ » — lu au premier degré, c'est la
  recommandation de Marc (budget 30 €/33 €, base qu'il a retenue, cheval retiré).
- UJ-4, résolution : « Le lendemain, l'app lui montre « 3 chevaux sur 4 capturés » ».
- FR-30 : « Après finalisation de la course (FR-17), l'app affiche « X chevaux sur
  4 capturés » pour **la recommandation consultée** ».

FR-30 (2ᵉ consequence) est, lui, conforme au cahier (journalisation quotidienne
par le backend). Le reste suppose un stockage de la recommandation consultée
(locale ou serveur) et un écran de débrief que le cahier ne prévoit pas, à un
budget qui n'est généralement pas un budget de référence.

**Recommandation** : gravité **significative**. Préciser dans le PRD que
(a) la journalisation serveur porte sur la recommandation du modèle aux budgets de
référence et sur les comparateurs, pas sur la recommandation personnalisée ;
(b) le débrief « X chevaux sur 4 » de la recommandation consultée repose sur une
sauvegarde **locale** sur l'appareil + l'arrivée finalisée récupérée au prochain
rafraîchissement. Reformuler le critère d'acceptation d'UJ-4 en conséquence, et
ajouter au cahier §11.1 le bloc « débrief » et la sauvegarde locale (aujourd'hui
absents).

---

## Écart 3 — Options hors budget : « jamais supprimées » (PRD) vs filtrées (cahier)

**Ce que dit la source (§4.3)** :
> « 2. Garder les options de coût ≤ `budget_eur`. 3. Recommandée : l'option de
> `p_couverture` maximale … 4. Alternatives : jusqu'à 3 options affichées en plus
> — la meilleure avec un autre nombre de bases, la meilleure avec une autre
> formule, et la moins chère à moins de 2 points … »

Les options au-delà du budget n'apparaissent que via le verdict
`jouable_avec_budget` (« on affiche ce budget minimal »). Seul `/multi/systemes`
(5.4) renvoie « toutes les formules valides » pour une sélection donnée, sans
notion de budget.

**Ce qu'on trouve dans le PRD/addendum** : FR-23 : « une option qui dépasse le
budget est signalée « dépasse le budget », **jamais supprimée** » ; UJ-4 : « la
formule intégrale, bien plus chère, reste visible et marquée « dépasse le budget » »
et « l'app affiche la meilleure option à 30 € **et** l'option à 33 € » (le cahier
n'affiche que le montant minimal, pas l'option correspondante détaillée) ; critère
d'acceptation d'UJ-4 identique.

**Recommandation** : gravité **significative** (comportement visible et testable
divergent). Le comportement PRD est défendable (transparence), mais il faut
l'écrire dans le cahier : soit §4.3 ajoute un bloc « options hors budget »
(lesquelles : toutes les formules de la sélection recommandée ? l'option qui
atteint le seuil du verdict ?), soit le PRD précise que la liste « dépasse le
budget » est celle de la section Système (5.4, toutes les formules pour la
sélection affichée) et que l'option du verdict `jouable_avec_budget` est
présentée en détail. Ajouter le test correspondant au cahier §9 test 10.

---

## Écart 4 — Mention obligatoire « modèle en cours d'évaluation » absente du PRD

**Ce que dit la source (§8.3, §11.1 point 2, §10 `statut_modele`)** :
> « Le libellé « hypothèse non validée » d'un comparateur, **et la mention « modèle
> en cours d'évaluation » de la recommandation**, ne sont levés que si, sur la
> période de test gelée, l'intervalle de confiance à 95 % concerné exclut 0 du bon
> côté. »
> 11.1 : « Mention « seuils provisoires » … et « modèle en cours d'évaluation »
> tant que la section 8 ne conclut pas. »

**Ce qu'on trouve dans le PRD/addendum** : « seuils provisoires » est bien repris
(FR-26, UJ-4, OQ 10) et « hypothèse non validée » pour les comparateurs (FR-29).
Mais **aucune** FR, NFR de §4.11 ni étape d'UJ-4 ne mentionne « modèle en cours
d'évaluation » sur la recommandation elle-même — c'est pourtant la mention qui
empêche de présenter la sortie du modèle comme validée, symétrique de celle des
comparateurs. Par ailleurs, le critère d'acceptation d'UJ-4 écrit « Aucun pari
placé » alors que la mention obligatoire (FR-30 NFR, cahier 11.1) est « L'outil
ne place aucun pari ».

**Recommandation** : gravité **significative** (garantie utilisateur, honnêteté
du produit). Ajouter une consequence à FR-26 ou FR-30 : « Tant que le protocole
d'évaluation ne conclut pas, la recommandation porte « modèle en cours
d'évaluation » » ; l'ajouter à la liste des mentions obligatoires (NFR de §4.11)
et à UJ-4. Harmoniser le libellé « L'outil ne place aucun pari » dans le critère
d'acceptation d'UJ-4.

---

## Écart 5 — Référence de comparaison : le marché (B1), pas le modèle ; B0 absent

**Ce que dit la source (§0.3, §4.5, §8.3 garde-fou 4)** :
> « Le critère de réussite de `modele` se mesure **contre B1** (le marché) ; M1 et
> B0 sont des repères. » — « Le hasard n'est pas la référence : `B1` (le marché)
> l'est. »
> Comparateurs V1 : `B0` (hasard reproductible), `B1` (cotes les plus basses), `M1`.

**Ce qu'on trouve dans le PRD/addendum** :
- Glossaire, **Comparateur** : « … affichée à part comme « hypothèse non validée »
  et **mesurée contre le modèle** » — référence inversée : c'est le modèle qui est
  mesuré contre le marché (SM-4 le dit d'ailleurs correctement).
- Le glossaire et FR-29 ne citent que « méthode 1 » et « marché » ; `B0` (sélection
  aléatoire reproductible, journalisée et mesurée) n'apparaît nulle part dans le
  PRD, ni dans FR-30 (« les comparateurs »). C'est conforme à l'écran (11.1 point 7
  : M1, B1), mais B0 est bien un comparateur V1 journalisé.

**Recommandation** : gravité **modérée**. Corriger le glossaire : « … mesurée,
comme le modèle, contre la référence marché ». Préciser dans FR-30 (journalisation)
que les comparateurs journalisés incluent une sélection aléatoire de référence
(repère, non affichée par défaut).

---

## Écart 6 — Harnais de backtest, pilote et endpoint de performance hors du périmètre MVP du PRD

**Ce que dit la source (§1, §8.1, §8.4, §10, §13 étapes 9-10)** : le périmètre V1
inclut « protocole de backtest et de test prospectif » ; le **pilote** en mode
`backfill` fixe les valeurs par défaut des seuils et les budgets de référence ;
les routes `GET /multi/performance` et `POST /multi/backtest` font partie de l'API ;
étape 10 : « Rapport d'évaluation ».

**Ce qu'on trouve dans le PRD/addendum** : §6.1 liste six endpoints Multi mais
**omet** `/multi/performance` et `/multi/backtest`, et ne mentionne ni le harnais
de backtest ni le pilote. Or plusieurs exigences en dépendent : FR-26 et OQ 10
(seuils fixés « par le pilote »), FR-29 (« affiche ses performances mesurées dès
qu'il y en a » — nécessite un service de performance), FR-30 (backtest sans fuite),
SM-4. Le pilote est donc un prérequis implicite non planifié.

**Recommandation** : gravité **significative** pour la planification. Ajouter au
§6.1 le harnais de backtest, le pilote et les deux endpoints (ou, si le choix est
de les reporter, le dire explicitement en §6.2 et expliquer d'où viennent alors
les seuils par défaut et les performances affichées par FR-29).

---

## Écart 7 — Fonctions d'évaluation visibles non reprises : simulation de non-partant, carte de couverture, indicateurs par option

**Ce que dit la source** :
- §6.6 : « Pour chaque cheval de la sélection : ce que devient chaque ticket s'il
  est déclaré non-partant (requalification), et la nouvelle `p_couverture`. »
  (simulation **préventive**, distincte du recalcul sur non-partant réel).
- §6.5 et §11.1 point 5 : « Une **carte de couverture** (combinaisons couvertes
  1×, 2×, 3×) est disponible pour le système retenu. »
- §5.4, §6.7, §11.1 : par option, « prix du point de couverture »,
  `r7_seuil_eur` (rapport en 7 nécessaire pour ne pas perdre),
  `tickets_payants_moyens_si_couvert` ; entropie affichée « course fermée /
  ouverte » (6.2).

**Ce qu'on trouve dans le PRD/addendum** : FR-23 ne couvre que le recalcul sur
non-partant **déclaré** ; FR-25 liste nombre de tickets, tickets physiques, coût,
niveau garanti, probabilité de couverture, grilles — sans prix du point, seuil de
rentabilité ni carte de couverture ; UJ-4 cite « course ouverte » parmi les
raisons (l'entropie est donc implicitement là).

**Recommandation** : gravité **modérée**. Le détail des champs reste au cahier,
mais deux capacités méritent une consequence : (a) FR-30 ou FR-23 — « l'utilisateur
peut simuler le retrait de chaque cheval de la sélection et voir l'effet sur ses
tickets et sa probabilité de couverture » ; (b) FR-25 — « chaque option affiche le
rapport « Multi en 7 » nécessaire pour ne pas perdre et le coût d'un point de
couverture ; une carte de couverture est disponible pour le système retenu ». Le
seuil de rentabilité est particulièrement utile au récit d'UJ-4 (« rapport en 7
le plus faible des quatre formules »).

---

## Écart 8 — Principes d'honnêteté sur les systèmes réduits : pas d'avantage moyen, système à jouer en entier

**Ce que dit la source** :
- §0.3 et §5.5 : « **La structure du ticket ne crée pas d'avantage moyen.** …
  une réduction ne change que le budget et la variance. Tout avantage doit venir
  de la **sélection**. »
- Annexe A : « il faut jouer le système **dans son intégralité** pour que la
  couverture soit effective. »

**Ce qu'on trouve dans le PRD/addendum** : la Vision dit que le modèle « dit ce
qu'un système couvre vraiment : une couverture garantie, jamais un gain garanti »,
ce qui est fidèle. Mais aucune FR ne porte le message « un système réduit ne
change pas l'espérance de gain, seulement le coût et la variance », ni l'avertissement
qu'une garantie ne tient que si **tous** les tickets sont joués (risque réel avec
3 tickets physiques à remplir manuellement chez l'opérateur, cf. UJ-4).

**Recommandation** : gravité **modérée**. Ajouter à FR-25 deux consequences :
« la garantie affichée précise qu'elle ne tient que si tous les tickets du système
sont joués » ; « l'écran indique qu'un système réduit réduit le coût, pas
l'espérance de gain ». Ce sont des garanties d'honnêteté directement dans l'esprit
du produit (§1, §5).

---

## Écart 9 — Course non éligible : verdict « passer » et mode exploration (≥ 14 partants)

**Ce que dit la source (§2 éligibilité, §6.4)** :
> « Le backend détecte la course support par la liste `paris` de la course (champ
> exact à confirmer) ; **à défaut, il propose « courses de ≥ 14 partants » en mode
> exploration (sans rapport Multi disponible).** »
> Verdict `passer` : « aucune des deux conditions, **ou course non éligible** ».

**Ce qu'on trouve dans le PRD/addendum** : FR-22 : « Une course non éligible
affiche la raison … **au lieu d'une recommandation** ». Le mode exploration
(recommandation possible sur toute course ≥ 14 partants, sans rapport Multi, tant
que le marqueur « course support » n'est pas découvert — OQ 9) n'apparaît pas ;
et le comportement diffère (cahier : verdict `passer` + raison ; PRD : pas de
recommandation).

**Recommandation** : gravité **modérée**. Décider si le mode exploration est un
comportement produit V1 (probable, puisque OQ 9 est ouverte et que SM-4 évalue
toutes les courses ≥ 14 partants) et l'ajouter à FR-22 avec son libellé
(« exploration — pas une course support »). Aligner ensuite l'un ou l'autre
document sur « passer + raison » vs « pas de recommandation ».

---

## Écart 10 — « Retirer » un cheval : capacité du PRD absente du cahier

**Ce que dit la source (§4.3, §10)** : l'utilisateur peut **imposer** des chevaux
(`chevaux_imposes`), imposer des bases, ou saisir sa propre sélection (évaluée,
1 à 2 échanges suggérés). Il n'existe ni paramètre `chevaux_exclus` dans
`POST /multi/recommandation`, ni règle « exclure un cheval et laisser le modèle
recompléter ».

**Ce qu'on trouve dans le PRD/addendum** : FR-28 : « L'utilisateur peut **retirer**
ou ajouter des chevaux … » ; UJ-4 : « Marc retire un cheval qu'il sait forfait de
cœur : la sélection passe en « modifiée », se réévalue, et le modèle propose
l'échange qui coûte le moins de couverture ». C'est une variante de la sélection
personnelle (6.1 + échanges), mais la formulation d'UJ-4 (« l'échange qui coûte le
moins ») diffère de celle du cahier (« les échanges qui **augmentent le plus** »).

**Recommandation** : gravité **mineure à modérée** — écart côté cahier. Ajouter
au cahier §4.3 la notion de cheval exclu (forfait de cœur) et le paramètre API
correspondant, ou préciser que « retirer » = passer en sélection personnelle.
Harmoniser la formulation des échanges suggérés dans UJ-4.

---

## Écart 11 — Questions ouvertes et risques du cahier non repris dans le PRD

**Ce que dit la source (§12, §6.1, §5.2, annexe D, §7)** :
- n°4 : source des **cotes historiques** pour le backtest inconnue → B1 et le
  départage M1 « dégradés » en backfill (affecte directement la référence de SM-4).
- n°6 : notion « long champ / Longchamp » citée par l'utilisateur, **à définir**.
- n°10 : **licence** du dépôt de couvertures (La Jolla) à vérifier avant
  d'embarquer des fichiers tiers.
- §6.1 : Harville connu pour **surestimer les favoris aux places 2-4** → risque
  direct sur `p_couverture`.
- Annexe D : décodeur de musique à valider sur chaînes réelles (« non négociable »),
  segmentation ambiguë — conditionne M1.
- §7 : les appels supplémentaires à la source PMU pour les rapports Multi entrent
  dans l'arbitrage de fréquence d'ingestion (PRD OQ 6).

**Ce qu'on trouve dans le PRD/addendum** : seuls les n°1, 3 et 7 du cahier sont
repris (OQ 8, 9, 10) et le Flexi (n°2) en §6.2. Les autres sont absents ; l'OQ 6
du PRD ne mentionne pas les appels Multi.

**Recommandation** : gravité **modérée** pour n°4 (il fragilise la métrique SM-4
contre le marché) et le biais Harville (à citer comme risque de SM-4), **mineure**
pour les autres. Ajouter une OQ « cotes historiques pour la référence marché en
backtest », une OQ « long champ », étendre l'OQ 6 aux rapports Multi, et porter
licence + décodeur de musique dans l'addendum.

---

## Écart 12 — FR-25 et le catalogue du document : les systèmes mixtes sont hors V1

**Ce que dit la source (§5.3, §5.6, annexe A)** : le critère « taille ≤ document »
s'applique aux entrées de l'annexe A ; les entrées « mixte 5+6 » relèvent de §5.6,
**hors V1** ; l'entrée « 3 bases + 14 (v = 17) » est une coquille (13 annoncé,
14 nécessaires — test 6 attend exactement 14).

**Ce qu'on trouve dans le PRD/addendum** : FR-25 : « Pour **chaque entrée** du
catalogue du document source, le système produit a au plus autant de tickets que
le document. » Pris littéralement, ce critère inclut les mixtes (hors MVP selon
§6.2) et l'entrée coquille (impossible à satisfaire à 13).

**Recommandation** : gravité **mineure**. Reformuler : « pour chaque entrée non
mixte du catalogue de référence (cahier Multi annexe A, coquilles corrigées) ».

---

## Écart 13 — Repli et limites de calcul sur l'appareil non exposés

**Ce que dit la source (§4.1, §11.3)** :
- Si la recommandation n'est pas instantanée sur l'appareil cible, l'optimisation
  est bornée et l'avertissement `optimisation_tronquee` est affiché.
- Hors ligne, une combinaison `(v', k', t')` absente du catalogue précalculé est
  **exclue des options** (pas calculée à la volée) avec l'avertissement
  `systeme_absent_du_catalogue`.

**Ce qu'on trouve dans le PRD/addendum** : FR-23 exige le calcul sur l'appareil ;
§6.1 cite le catalogue précalculé ; la NFR de performance de §8 et l'OQ 1 ne
visent que la chaîne score → probabilités → combinaisons, pas la recommandation
Multi (énumération ≤ 4 845 ensembles × échanges × jusqu'à 4 × 17 × 4 options). Les
deux dégradations visibles par l'utilisateur ne sont pas mentionnées.

**Recommandation** : gravité **mineure à modérée**. Étendre la NFR de performance
§8 et l'OQ 1 au calcul de la recommandation Multi ; ajouter à FR-23 / FR-25 que
toute dégradation (optimisation bornée, système absent du catalogue) est signalée
à l'utilisateur, jamais silencieuse.

---

## Écart 14 — Addendum et §0 : pas de pointeur « comment » pour le module Multi

**Ce que dit la source** : décisions techniques structurantes — générateur lourd
**uniquement côté backend / hors ligne**, jamais sur l'appareil ni dans le chemin
d'une requête sans cache (§5.2) ; vérificateur jamais contourné et ré-exécuté sur
l'appareil après relabelling (§11.3) ; fixtures partagées
`fixtures/multi_cases.json` pour la parité Python/Dart (§9, AD-2) ; accès aux
tables uniquement via `data/repository.py` (AD-1) ; immuabilité par
`version_strategie` (§7).

**Ce qu'on trouve dans le PRD/addendum** : l'addendum (sections B, E, F) ne parle
que des cahiers backend et mobile ; aucune section ne pointe le cahier Multi ni
ces décisions. Le PRD §0 dit « sur une question de formule ou d'implémentation, le
cahier **backend** fait foi » sans étendre cette règle au cahier Multi (seul §4.11
le qualifie de « référence normative »). Le plan de développement du cahier (§13)
n'est pas cité en addendum F.

**Recommandation** : gravité **mineure**. Ajouter à l'addendum une section
« G. Module Multi — pointeur » (générateur backend-only + catalogue, vérificateur
obligatoire, fixtures partagées, plan §13), et étendre la phrase de §0 : « … le
cahier backend, ou le cahier Multi pour le module Multi, fait foi ».

---

## Écart 15 — Petites imprécisions de vocabulaire et de saisie

- **Glossaire « Couverture garantie »** : « si les 4 premiers sont dans la
  sélection, au moins un ticket paie » — omet « et incluent les bases » et « au
  moins le rapport Multi en k », pourtant présents dans FR-25 et dans
  « Probabilité de couverture ». Incohérence interne au PRD (le texte de FR-25,
  qui ajoute les bases, est d'ailleurs plus exact que celui du cahier §5.4, à
  reporter dans le cahier).
- **Multiplicateur** : le cahier (§4.3, §5.4, §11.1) en fait une saisie de
  l'utilisateur (défaut 1, ≤ 200) qui entre dans le coût ; FR-23 ne mentionne que
  le budget. Le non-goal §5 (« ni multiplicateur ») est cohérent, mais la saisie
  elle-même n'apparaît dans aucune FR.
- **Glossaire « Base »** : le cahier note le synonyme « banco » du document
  source ; utile en glossaire pour la recherche, sans l'employer ailleurs.
- **Contenus propriétaires** (Paris Turf, Geny) : le cahier les exclut
  explicitement de toute collecte automatisée (§1, §12 n°5) ; le PRD ne le dit
  qu'indirectement via le non-goal presse.

**Recommandation** : gravité **mineure** — corrections de glossaire et une
mention du multiplicateur saisi dans FR-23 ou FR-25.

---

## Points vérifiés et confirmés bien réconciliés (pas des écarts)

- **Décisions D0-D7** : le modèle décide (FR-23), aucune mise recommandée (§5,
  §4.11), M2 reportée (§5, §6.2), verdict à trois issues (FR-26), 3 bases
  candidates avec coût économisé et couverture perdue (FR-24), choix taille/bases/
  formule sous budget avec ≤ 3 alternatives (FR-23), explications en codes (FR-27,
  §8). Toutes tracées en §12.
- **Mentions** « Couverture garantie — pas un gain garanti », « L'outil ne place
  aucun pari », rappel de jeu responsable : NFR de §4.11, conforme à 11.1 point 8.
- **Vérification systématique** des systèmes et vérification d'un système saisi
  ailleurs avec proposition d'un système plus petit : FR-25, conforme à 5.2.
- **Propriétés de la recommandation** : déterministe, sans partant virtuel ni
  non-partant, calculée sur l'appareil, recalcul sur non-partant réel : FR-23,
  conforme à 4.0, 4.1, 6.6, 11.3.
- **Seuils du verdict** réglables, persistés, réinitialisables, « provisoires »
  jusqu'au pilote ; verdict sans indice de valeur ni presse : FR-26, conforme à 6.4
  et 4.4. Garde-fou SM-C2 étendu au verdict : SM-C3.
- **Explications** : cheval retenu (top4, value, drapeaux, contribution), 3 écartés
  les plus proches : FR-27, conforme à 6.5.
- **Chevaux imposés** avec leur coût en couverture, sélection personnelle évaluée
  avec 1-2 échanges : FR-28, conforme à 4.3.
- **Comparateurs** à part, jamais par défaut, « hypothèse non validée »,
  performances affichées : FR-29, conforme à 4.5 et 11.1 point 7.
- **Évaluation** : probabilité de couverture, distribution 0-4, indice de valeur
  « hypothèse », R7 médian si ≥ 30 courses : FR-30, conforme à 6.3 et 6.7.
- **Journalisation serveur** immuable, avant départ, avec heure des données ;
  backtest sans fuite : FR-30, conforme à §7 (hors réserve de l'écart 2).
- **Métriques** : SM-4 (calibration Brier vs marché, différence appariée de
  captures avec IC, pas de seuil avant pilote) conforme à 8.2-8.3 ; SM-C3 conforme
  au garde-fou 6.4.
- **Parité Python/Dart** des fonctions Multi par cas de test partagés : NFR de
  §4.11, conforme à §9 et 11.3.
- **Règles du pari à vérifier sur pmu.fr** (OQ 8), **endpoint des rapports et
  marqueur course support** (OQ 9), **seuils par défaut** (OQ 10), **Flexi** hors
  V1 (§6.2) : conformes à §12 n°1, 2, 3, 7.
- **Hors V1** : systèmes mixtes, choix du système selon la valeur, indice de
  valeur dans le verdict (§6.2) : conformes à §1 et §12 n°9.
- **UJ-4** : chiffres cohérents avec l'exemple illustratif du cahier §10
  (1 base + 11 chevaux, tickets de 7, 11 tickets, 3 physiques, 33 €).

---

## Synthèse des suggestions

| # | Écart | Gravité | Action suggérée |
|---|---|---|---|
| 1 | Anglais : V1 (cahier) vs après MVP (PRD) | Majeur | Faire trancher le porteur ; aligner PRD §6.2/§8/OQ 11 ou cahier §1/§11.2/test 16 |
| 2 | Journalisation/débrief de la recommandation consultée | Significatif | Préciser PRD (budgets de référence, sauvegarde locale) ; ajouter débrief au cahier §11.1 |
| 3 | Options hors budget : « jamais supprimées » vs filtrées | Significatif | Décrire le bloc hors budget dans le cahier §4.3 ou restreindre FR-23 |
| 4 | « Modèle en cours d'évaluation » absent ; libellé « Aucun pari placé » | Significatif | Consequence FR-26/FR-30 + liste des mentions + UJ-4 |
| 5 | Comparateur « mesuré contre le modèle » ; B0 absent | Modéré | Corriger le glossaire ; citer la référence aléatoire en FR-30 |
| 6 | Backtest, pilote, `/multi/performance`, `/multi/backtest` hors §6.1 | Significatif | Ajouter au MVP scope ou reporter explicitement |
| 7 | Simulation de non-partant, carte de couverture, seuil de rentabilité | Modéré | Consequences FR-23/FR-25/FR-30 |
| 8 | Réduction sans avantage moyen ; système à jouer en entier | Modéré | Deux consequences sur FR-25 |
| 9 | Course non éligible : `passer` + mode exploration | Modéré | Compléter FR-22 et aligner le comportement |
| 10 | « Retirer » un cheval absent du cahier ; sens des échanges | Mineur/modéré | Compléter cahier §4.3/§10 ; harmoniser UJ-4 |
| 11 | OQ/risques non repris (cotes historiques, Harville, Longchamp, licence, musique, fréquence) | Modéré/mineur | Nouvelles OQ + addendum |
| 12 | FR-25 « chaque entrée » inclut mixtes et coquille | Mineur | Reformuler FR-25 |
| 13 | Dégradations sur l'appareil (optimisation bornée, catalogue absent) ; NFR perf | Mineur/modéré | Étendre §8/OQ 1 ; consequence de signalement |
| 14 | Addendum sans section Multi ; §0 « cahier backend fait foi » | Mineur | Section G addendum ; étendre §0 |
| 15 | Glossaire couverture garantie, multiplicateur saisi, banco, contenus propriétaires | Mineur | Corrections ponctuelles |
