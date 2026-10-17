# Réconciliation — décisions D0-D7 et récit UJ Multi vs PRD + addendum

*Documents sources analysés :*
- *`../../multi/reconcile-cdc-multi-prd.md` — sections A-E et surtout « D bis » (décisions D0-D7 confirmées par le porteur de projet le 2026-10-17, y compris le point i18n).*
- *`sources/uj-multi-marc-2026-10-17.md` — récit verbatim du porteur de projet pour le Multi.*

*Documents cibles : `prd.md` (§2 UJ-4, §3, §4.11 FR-22 à FR-30, §5, §6, §7, §8, §11, §12) + `addendum.md`.*
*Document consulté pour trancher « laissé au cahier » : `docs/cahier_des_charges_module_multi.md` (v2).*

**Principe rappelé** : le PRD pointe le cahier Multi v2 comme référence normative
(§4.11) ; les algorithmes, le schéma, les endpoints détaillés, l'emplacement du
module et le nommage français (D6 « code et API », D7) relèvent du cahier et de
l'architecture. Leur absence dans le PRD n'est **pas** un écart. De même, les
réécritures **voulues** du récit (le modèle recommande au lieu de la méthode 1,
pas d'import presse, ajout du verdict) ne sont pas des écarts : D0-D7 prévalent
sur le récit (arbitrage confirmé, PRD §12).

**Verdict global** : la réconciliation est bonne sur le fond. Les huit décisions
D0-D7 sont reprises sans contradiction sur la mécanique du Multi (pas de mise, le
modèle décide, M2 hors V1, verdict à trois issues avec seuils réglables et
provisoires, 3 bases candidates, taille et formule choisies sous budget). Les douze
écarts de la section B et le tableau de la section D sont couverts ou laissés au
cahier v2, qui les traite. Le récit de Marc survit pour l'essentiel : la méfiance
envers les « systèmes garantis », la sélection expliquée, la mention « modifiée »,
l'option hors budget visible, l'export en dossards et le débrief « sans rien
embellir ».
Restent **trois écarts significatifs** : (1) D6 (i18n) est reporté après le MVP
sur la base d'une hypothèse non confirmée, alors que D bis et le cahier v2
en font une exigence de toute l'application ; (2) la posture « Marc ne voit pas un
oracle » est perdue, car la mention « modèle en cours d'évaluation », présente dans
le cahier, manque dans le PRD ; (3) UJ-4 contredit FR-23 et son propre critère
d'acceptation sur l'option à 33 €, et inverse le raisonnement final de Marc. Les
autres écarts sont modérés ou mineurs.

---

## 1. Décisions D0-D7 (« D bis ») — fidélité dans le PRD

| # | Décision confirmée | Où dans le PRD | État |
|---|---|---|---|
| D0 | Aucune mise ni multiplicateur recommandé ; coût affiché ; multiplicateur = saisie utilisateur (défaut 1) | §4.11 description, §5 (non-goal Multi), FR-23 | **Fidèle**, sauf le multiplicateur comme saisie, absent (Écart 6) |
| D1 | Le modèle recommande ; M1, B0, B1 = comparateurs « hypothèse non validée » | FR-23 (« jamais d'une méthode tierce »), FR-29, glossaire « Comparateur » | **Fidèle**. B0 n'est pas cité dans FR-29, mais le cahier §11.1 ne l'affiche pas non plus (journalisé seulement) : cohérent |
| D2 | M2 reste dans le cahier comme stratégie future, non construite en V1 | §5, §6.2 | **Fidèle** |
| D3 | Verdict `jouer` / `jouable_avec_budget` / `passer` + raisons ; seuils réglables ; défauts fixés au pilote | FR-26, OQ 10, SM-C3, UJ-4 (« seuils provisoires ») | **Fidèle**. La calibration du verdict n'apparaît qu'en contre-métrique (Écart 8) |
| D4 | 3 bases candidates classées, 0 à 3 retenues, activables par l'utilisateur, avec arbitrage | FR-24 | **Fidèle** |
| D5 | Taille, bases et formule choisies sous budget + alternatives | FR-23 (« jusqu'à 3 alternatives ») | **Fidèle** |
| D6 | Code/API en français ; **affichage FR/EN au choix de l'utilisateur, pour toute l'application** ; explications en codes + paramètres | §8 NFR « Préparation à l'affichage multilingue », FR-27, §6.2, OQ 11, §12 | **Partiel, avec une contradiction** : codes + paramètres repris ; l'affichage EN est reporté après le MVP et deux zones en sont exclues (Écart 1) |
| D7 | `backend/app/engine/multi/` + miroir `mobile/lib/engine/multi/` | §4.11 NFR de parité ; rien dans l'addendum | **Fidèle sur le principe** (parité, cas de test partagés) ; l'emplacement relève de l'architecture (pointeur facultatif, Écart 9) |

## 2. Sections B et D de la note — couverture

| Élément | Couverture |
|---|---|
| B1 — Multi absent du PRD (FR-22 à FR-28, glossaire) | Couvert, et au-delà : FR-22 à FR-30, et le glossaire contient Multi, Course support, Base, Système réduit, Couverture garantie, Probabilité de couverture, Verdict et Comparateur |
| B2 — « Si je joue » : verdict + garde-fou SM-C2 | FR-26 + SM-C3 |
| B3 — Sélection du modèle (maximiser `p_couverture`) | FR-23 ; algorithme dans le cahier §4.1 |
| B4 — Bases proposées par le modèle | FR-24 |
| B5 — « Pourquoi » à partir des quantités du moteur | FR-27 (Top4, value, indicateurs FR-4, 3 écartés). Les avertissements de données manquent (Écart 7) |
| B6 — M2 contre le non-goal presse | §5, §6.2 |
| B7 — Multiplicateur = saisie | Laissé au cahier (§5.4, §11.1) ; PRD muet (Écart 6) |
| B8 — Partants virtuels, énumération de tout le champ, fixtures | FR-23 (« aucun partant virtuel ») ; l'énumération et les fixtures sont dans le cahier ; parité couverte par la NFR de §4.11 |
| B9 — Dépendances de données | Rapports et course support : OQ 9. Règles 2001 : OQ 8. Allocation de la dernière course (M1) : cahier §3, colonne à ajouter. Volume d'appels : non relié à OQ 6 côté PRD (Écart 9) |
| B10 — Calibration de `p_couverture` et du verdict | SM-4 couvre `p_couverture` ; le verdict n'est qu'en contre-métrique (Écart 8) |
| B11 — Hors ligne : recommandation, verdict et `p_couverture` sur l'appareil | FR-23 (calcul local, non-partant), §6.1 (catalogue précalculé), UJ-4 edge case |
| B12 — Trois mentions obligatoires | §4.11 NFR. La formulation varie d'une section à l'autre (Écart 5) |
| D — M2, presse, `CitationsProvider`, etc. reportés | §6.2 |
| D — M1 rétrogradé, écran de choix de méthode remplacé | FR-29 « Autres méthodes », UJ-4 |
| D — Multiplicateur comme saisie seulement | Voir Écart 6 |
| D — Indice de valeur hors verdict | FR-26, FR-30 (« hypothèse »), §6.2 |
| D — Systèmes mixtes, pondération par la valeur → V2 | §6.2 |

## 3. Récit de Marc — éléments compatibles et critères d'acceptation

| Élément du récit | Dans le PRD |
|---|---|
| Persona, budget fixe de 30 €, lit la presse sans s'y fier, **se méfie des « systèmes garantis »**, joue lui-même | UJ-4 persona, §1 Vision, §2 objectif Multi (user story reprise presque mot pour mot) |
| « 18 partants, course éligible » + « L'outil ne place aucun pari » | UJ-4, FR-22, NFR §4.11 |
| Carte « hypothèse non validée » + comparaison avec le marché « pas encore concluante » → **« Marc ne voit donc pas un oracle »** | Conservé pour les comparateurs (FR-29) ; **perdu pour la recommandation du modèle**, qui devient la vue par défaut (Écart 2) |
| Chaque cheval porte ce qui l'a fait entrer ; « Marc comprend pourquoi chaque cheval est là » | FR-27, UJ-4 climax |
| Avertissement au niveau de la sélection (« Aucun cheval 6ᵉ : créneau repris… ») | Propre à M1 (comparateur) ; l'équivalent côté modèle (avertissements de données) manque (Écart 7) |
| Retouche manuelle → « modifiée », « l'app le note » | FR-28, UJ-4 |
| Toggle « base » manuel | FR-24 (activer/désactiver), FR-28 (imposer) |
| Tableau par k : tickets, coût, niveau garanti, `p_couverture` | FR-25 |
| Formule intégrale « dépasse le budget », non cachée | FR-23, UJ-4 |
| 11 tickets, 33 €, 3 tickets physiques ; texte de garantie | UJ-4, FR-25 |
| Évaluation : `p_couverture`, distribution 0-4, indice « hypothèse », rapport médian en 7 « pour juger si 33 € est raisonnable » | FR-30 (avec un seuil de 30 courses en base, ajout cohérent) |
| Décision finale : « ne jouer que le système à 33 €, **sans rien ajouter** », justifiée par une couverture modérée et un rapport faible | Reprise, mais le sens est **inversé** (« accepte de monter à 33 € ») (Écart 3) |
| Copie des grilles en dossards, puis il va jouer lui-même | FR-25 (export texte), UJ-4 |
| Le soir : **séance** journalisée ; le lendemain, « 3 chevaux sur 4 capturés » ; le résultat s'ajoute aux statistiques « sans rien embellir » | Le débrief est repris (FR-30). La journalisation passe de la **séance** à la **recommandation du jour** (Écart 4) |
| CA1 — chaque cheval affiche ce qui l'a sélectionné | Adapté (« ce qui l'a fait sélectionner »), FR-27 ✔ |
| CA2 — trois mentions visibles aux étapes concernées | ✔ sur le fond (§4.11 NFR, FR-29) ; libellés divergents (Écart 5) |
| CA3 — option hors budget signalée, pas supprimée | ✔ FR-23, mais **UJ-4 ne l'applique pas à l'option à 33 €** (Écart 3) |
| CA4 — chaque système affiché est vérifié | ✔ FR-25 |
| CA5 — séance journalisée avec l'heure des données, avant le départ | Reformulé en « recommandation journalisée » (Écart 4) |

---

## Écart 1 — Affichage FR/EN : le PRD reporte et restreint ce que D6 a décidé

**Ce que dit la source (D bis, D6)** :
> « Langue d'affichage FR/EN au choix de l'utilisateur → explications et raisons
> transmises comme codes + paramètres […]. Portée confirmée : toute
> l'application, pas seulement le Multi — nouvelle exigence transverse
> d'internationalisation, absente du PRD. »

Le cahier Multi v2 §11.2 va dans le même sens : « réglage persisté, français par
défaut », pour toute l'application, « à ajouter au PRD ».

**Ce qu'on trouve dans le PRD** :
- §6.2 : « l'anglais, au choix de l'utilisateur, vient après le MVP », marqué
  `[ASSUMPTION: lecture de la réponse « a » du porteur de projet, à confirmer.]`
- §8 : seuls les **nouveaux** textes du moteur (Multi) sont produits en codes ; « Les
  libellés de transparence de FR-4 et l'extraction par photo restent en français ».
- Aucune FR ne décrit le choix de langue (FR-20 ne le liste pas).

**Analyse** : D bis ne fixe pas de calendrier. Le report après le MVP vient d'une
autre réponse (« a »), que le PRD lui-même signale comme non confirmée. Le PRD et
le cahier v2 sont donc aujourd'hui en contradiction : le cahier prévoit le réglage
dans l'écran Multi de V1, le PRD le met hors MVP. L'exclusion de FR-4 contredit
aussi « toute l'application ». Elle va même contre l'objectif de la NFR (« que
l'ajout de l'anglais ne demande pas de reprendre le moteur ») : les libellés FR-4
sont produits par le moteur actuel et devront être repris.

**Recommandation** : faire confirmer le calendrier par le porteur de projet
(OQ 11), puis aligner le PRD et le cahier §11.2 dans un sens ou dans l'autre. Si le
report est confirmé, retirer l'exclusion de FR-4 de la NFR, ou la justifier comme
une dette assumée, et corriger le cahier §11.2 (« après le MVP »). Si l'anglais
entre en V1, ajouter une FR transverse : réglage de langue persisté, français par
défaut, toutes les chaînes affichées issues d'un catalogue FR/EN. Ajouter aussi la
langue à la liste de FR-20.

## Écart 2 — « Marc ne voit pas un oracle » : la mention « modèle en cours d'évaluation » manque

**Ce que dit la source (récit)** :
> « La carte porte la mention "hypothèse non validée". Elle indique aussi que la
> comparaison avec le marché et avec le classement interne n'est pas encore
> concluante. Marc ne voit donc pas un oracle. »

Dans le récit, cette humilité porte sur **la sélection que Marc suit**. Après D1,
c'est la recommandation du modèle qu'il suit. Le cahier v2 l'a transposé : §8.3 et
§11.1 point 2 affichent « modèle en cours d'évaluation » sur la recommandation tant
que le protocole ne conclut pas.

**Ce qu'on trouve dans le PRD** : « hypothèse non validée » s'applique seulement aux
**comparateurs** (FR-29), repliés par défaut. La recommandation du modèle, vue par
défaut, ne porte aucune mention sur son propre état de validation. FR-26 n'affiche
que « seuils provisoires », qui concerne les seuils et non le modèle. SM-4 dit
pourtant qu'aucune conclusion n'est possible avant le pilote.

**Conséquence** : le PRD perd l'élément qualitatif central du récit, celui qui sert
la méfiance de Marc envers les promesses. Il risque aussi l'effet inverse : une
recommandation chiffrée sans réserve, plus « oracle » que la méthode 1 d'origine.

**Recommandation** : ajouter une Consequence à FR-23 (ou à la NFR de §4.11) :
« Tant que le protocole d'évaluation ne conclut pas (SM-4), la recommandation porte
la mention "modèle en cours d'évaluation" et affiche ses performances mesurées dès
qu'il y en a. » Ajouter la mention au récit UJ-4.

## Écart 3 — UJ-4 : l'option à 33 € n'est pas signalée et le choix final de Marc est inversé

**Ce que dit la source** : budget fixé par Marc, 30 €. Décision finale : « couverture
modérée, rapport en 7 le plus faible → il décide donc de ne jouer que le système à
33 €, **sans rien ajouter** ». CA3 : « Toute option dépassant le budget est signalée,
pas supprimée. »

**Ce qu'on trouve dans le PRD** :
- UJ-4 : budget saisi = 30 €, verdict « jouable avec un budget de 33 € ». L'app
  affiche l'option à 33 €, mais **seule la formule intégrale** est marquée « dépasse
  le budget ».
- Résolution : « couverture modérée, rapport en 7 le plus faible : il **accepte de
  monter à 33 €** ». Dans le récit, ces arguments retenaient Marc d'ajouter quoi que
  ce soit. Ici, ils justifient un dépassement de budget.
- FR-23 : « une option qui dépasse le budget est signalée "dépasse le budget" ».

**Conséquence** : UJ-4 contredit FR-23 et le CA3 qu'il cite. Plus profondément, le
verdict `jouable_avec_budget` peut se lire comme une incitation à dépasser un budget
que l'utilisateur s'est imposé, ce qui va contre l'esprit du §5 (jeu responsable) et
contre D0 (« le budget reste la décision de l'utilisateur »).

**Recommandation** :
- UJ-4 : marquer l'option à 33 € « dépasse le budget (+3 €) ». Reformuler la
  résolution pour garder le raisonnement d'origine, par exemple : « il juge que 3 €
  de plus pour ce seul système restent raisonnables et ne joue rien d'autre ».
- FR-26 : ajouter une Consequence : « le verdict "jouable avec X €" n'augmente
  jamais le budget saisi ; l'écart au budget est affiché en euros ».

## Écart 4 — De la « séance journalisée » à la « recommandation journalisée » : débrief de la sélection jouée non spécifié

**Ce que dit la source** : « la **séance** est journalisée pour la validation des
méthodes » ; « l'app lui montre "3 chevaux sur 4 capturés" » ; CA5 : « La **séance**
est journalisée avec l'heure des données utilisées, avant le départ. »

**Ce qu'on trouve dans le PRD** : FR-30 journalise côté backend la recommandation du
jour et les comparateurs, ce qui est la bonne réponse pour l'évaluation (D1, sans
compte). Le CA5 de UJ-4 est réécrit en « la recommandation est journalisée ». Le
débrief porte sur « la recommandation consultée ». Le cahier §7 précise que la
recommandation affichée sur l'appareil **n'est pas** journalisée côté serveur. Le
PRD ne le dit pas.

**Manques** :
1. Le changement de séance à recommandation est un vrai changement de critère
   d'acceptation du porteur de projet, sans trace au §12.
2. Rien ne dit où vit la recommandation consultée jusqu'au lendemain (stockage
   local) ni à quelle heure de données elle correspond.
3. Marc a joué une sélection **modifiée** (FR-28). Rien ne dit si le débrief porte
   sur ce qu'il a réellement joué ou seulement sur la recommandation d'origine.

**Recommandation** : FR-30, ajouter une Consequence : « l'appareil conserve
localement la recommandation consultée et, le cas échéant, la sélection modifiée,
avec l'heure des données ; le débrief les montre toutes deux ; elles n'entrent pas
dans l'évaluation des méthodes (V1 sans compte) ». Au §12, noter que le CA5 a été
adapté (séance → recommandation) en conséquence de D1.

## Écart 5 — Mentions obligatoires : trois formulations pour les mêmes chaînes

**Source** : récit CA2 : « Couverture garantie, pas un gain garanti », « Aucun pari
placé ». Mention à l'étape 1 : « L'outil ne place aucun pari ».
**PRD** : FR-25, NFR §4.11 et le cahier utilisent « Couverture garantie — pas un gain
garanti » et « L'outil ne place aucun pari ». Le CA d'UJ-4 reprend la virgule et
« Aucun pari placé ».
**Recommandation** : fixer un libellé canonique par mention (une seule clé du
catalogue de libellés, cf. D6) et aligner le CA d'UJ-4. Ces chaînes ont vocation à
être testées à l'identique.

## Écart 6 — Multiplicateur comme saisie utilisateur (application de D0)

**Source** : D bis D0 : « multiplicateur = saisie utilisateur (défaut 1) » ; note §B
Écart 7.
**PRD** : §5 dit seulement qu'aucun multiplicateur n'est *recommandé*. FR-23 ne parle
que du budget. Le cahier §5.4 et §11.1 couvrent la saisie (réglage secondaire, ≤ 200).
**Recommandation** : facultatif. Une demi-ligne dans FR-23 (« un multiplicateur saisi,
défaut 1, multiplie le coût affiché ») suffit. Sinon, laissé au cahier, ce qui est
acceptable.

## Écart 7 — Avertissements de données de la recommandation

**Source** : le récit montre un avertissement au niveau de la sélection (« Aucun cheval
6ᵉ… »). Le cahier §6.5 prévoit des codes de données (`cote_manquante`, `cotes_du`
avec l'heure des cotes, `allocation_manquante`).
**PRD** : FR-27 couvre les explications par cheval, base, système et verdict, mais
pas les avertissements sur la qualité ou l'âge des données. Or Marc consulte à 9 h 40
des cotes qui bougeront.
**Recommandation** : ajouter à FR-27 : « les avertissements de données (cote
manquante, heure des cotes utilisées) sont affichés avec la recommandation ».

## Écart 8 — Calibration du verdict : seulement en contre-métrique

**Source** : note §B Écart 10 : « Calibration du verdict : sur les courses marquées
"jouer" vs "passer", la couverture observée diffère-t-elle comme annoncé ? » comme
métrique à ajouter.
**PRD** : SM-C3 la cite comme seul juge de la qualité du verdict, mais aucune
métrique (SM-4 ou autre) ne la mesure.
**Recommandation** : ajouter une phrase à SM-4 : « et calibration du verdict
(couverture observée sur les courses "jouer" vs "passer") ».

## Écart 9 — Petits raccords (mineurs)

- **OQ 6** (volume d'appels à la source PMU) : ne mentionne pas l'ingestion des
  rapports Multi, que la note (§B Écart 9) et le cahier §7 y rattachent. Ajouter
  « y compris les rapports Multi ».
- **FR-20** : la liste des réglages n'inclut ni les seuils du verdict (pourtant
  annoncés « cohérent avec FR-20 » par FR-26) ni la langue (Écart 1). Compléter la
  liste ou ajouter un renvoi.
- **Addendum** : aucun pointeur Multi. Une ligne en section B (« fixtures partagées
  `fixtures/multi_cases.json`, module `engine/multi` — D7, cahier Multi §9 »)
  garderait la trace de D7 pour l'architecte, comme pour le moteur principal.

---

## Points vérifiés et confirmés bien réconciliés (pas des écarts)

- **Réécritures voulues d'UJ-4** : le modèle recommande, la méthode 1 est en
  « Autres méthodes », pas d'import presse, verdict ajouté. Tout cela est conforme à
  D1, D2 et D3, et tracé au §12.
- **Absence de contradiction mécanique** avec D0-D5 : aucune mise, aucun Kelly
  Multi ; M2 et la presse hors V1 ; trois issues du verdict ; 3 bases candidates ;
  sélection sous budget avec alternatives ; indice de valeur hors verdict.
- **Méfiance envers les « systèmes garantis »** : portée au niveau de la Vision (§1)
  et de l'objectif (§2), pas seulement du persona. FR-25 ajoute la vérification d'un
  système trouvé ailleurs, un prolongement fidèle du récit.
- **« Sans rien embellir »** : repris tel quel dans FR-30.
- **Hors ligne** : l'edge case d'UJ-4 (non-partant sur l'hippodrome) et FR-23
  couvrent l'Écart 11 de la note.
- **Comparateur B0** : absent de l'écran dans le PRD comme dans le cahier §11.1,
  journalisé seulement. C'est cohérent.
- **Allocation de la dernière course** (M1) : traitée par le cahier §3 (colonne à
  ajouter). Elle ne touche que le comparateur, donc rien n'est requis au PRD.

---

## Synthèse des suggestions

| # | Écart | Gravité | Action suggérée |
|---|---|---|---|
| 1 | FR/EN reporté après le MVP et restreint, contre D6 et le cahier §11.2 | Significatif | Faire confirmer le calendrier (OQ 11), puis aligner PRD et cahier ; retirer ou justifier l'exclusion de FR-4 ; FR transverse si l'anglais est en V1 |
| 2 | « Modèle en cours d'évaluation » absent ; perte du « pas un oracle » | Significatif | Consequence sur FR-23 ou la NFR §4.11 + mention dans UJ-4 |
| 3 | Option à 33 € non signalée dans UJ-4 ; raisonnement final inversé ; verdict sans garde-fou sur le budget | Significatif | Corriger UJ-4 ; Consequence FR-26 « n'augmente jamais le budget saisi » |
| 4 | Séance → recommandation ; débrief de la sélection modifiée non spécifié | Modéré | Consequence FR-30 (conservation locale, débrief des deux) + trace au §12 |
| 5 | Libellés des mentions non canoniques | Mineur | Un libellé par mention ; aligner le CA d'UJ-4 |
| 6 | Multiplicateur comme saisie absent | Mineur | Facultatif : demi-ligne dans FR-23, sinon laissé au cahier |
| 7 | Avertissements de données (heure des cotes) absents de FR-27 | Mineur | Ajouter une Consequence à FR-27 |
| 8 | Calibration du verdict non mesurée | Mineur | Compléter SM-4 |
| 9 | OQ 6, liste FR-20, pointeur addendum | Mineur | Raccords d'une ligne chacun |
