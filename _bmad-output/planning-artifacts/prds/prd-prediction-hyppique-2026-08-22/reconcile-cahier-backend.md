# Réconciliation — cahier des charges backend vs PRD + addendum

*Document source analysé : `sources/cahier_des_charges_backend_hippique.md`.*
*Documents cibles : `prd.md` + `addendum.md`.*

**Principe rappelé** : le PRD est volontairement écrit au niveau produit/capacité. Les
constantes et formules exactes du moteur (terrain, niveau, incidents, lissage
bayésien, Plackett-Luce, Harville, Kelly, combinatoire, structure de dossiers,
tests unitaires détaillés) sont censées rester uniquement dans le cahier backend
et être pointées, pas dupliquées. Leur absence dans le PRD n'est **pas** listée
ci-dessous comme un écart.

**Verdict global** : la réconciliation est bonne. Les 3 pièges de la section 6.2
(numPmu instable, finalisation différée, terrain absent) sont tous repris. Les
4 questions ouvertes de la section 10 sont toutes reprises dans le PRD §11 (ou
tranchées explicitement comme "décision prise" et donc à raison absentes des
questions ouvertes). Les 6 endpoints de la section 8 sont tous couverts par au
moins une FR ou listés au MVP Scope. Les 5 écarts trouvés ci-dessous sont des
détails produit non repris, aucun ne remet en cause la cohérence d'ensemble.

---

## Écart 1 — Fiabilité du numéro de dossard sur une fiche extraite par vision (Genybet)

**Ce que dit la source (§4.4)** :
> "Prudence sur le numéro affiché en tête de fiche : sur certains sites
> (observé sur Genybet), ce numéro peut être élevé (ex. 604) sans certitude
> qu'il corresponde au numéro de dossard PMU réel de la course du jour — le
> prompt d'extraction le signale comme plausible mais à vérifier, ne pas le
> traiter comme fiable à 100 % sans recoupement."

C'est un piège de données distinct de celui sur `numPmu` côté API (celui-là est
bien repris). Celui-ci concerne spécifiquement l'extraction vision : le numéro
lu sur une fiche tierce peut être un identifiant interne au site source, pas le
dossard PMU réel.

**Ce qu'on trouve dans le PRD/addendum** : rien. FR-18 et FR-19 (extraction
fiche/programme par photo) exigent un bandeau "à vérifier" générique sur tous
les champs extraits, ce qui couvre partiellement le risque, mais aucune mention
spécifique du risque que le **dossard** en particulier soit un numéro interne
au site plutôt que le numéro PMU réel — c'est le champ le plus critique pour la
suite du calcul (rapprochement avec les cotes, affichage des combinaisons "en
dossards" au §4.5). Le glossaire et l'addendum C (qui reprend d'autres pièges
de la section 4 : `numPmu` instable, `handicapPoids`, `handicapValeur`,
`NON_PLACE`) ne mentionnent pas ce point-là.

**Suggestion** : ajouter à l'addendum (section C, aux côtés des autres pièges
de source de données) une ligne reprenant ce piège, et envisager une
Consequence testable sur FR-18/FR-19 du type "le dossard extrait par vision est
présenté comme à recouper manuellement, pas comme fiable par défaut" —
gravité **significative** dans la mesure où une confusion silencieuse sur le
dossard fausserait tout le résultat affiché à l'utilisateur sans qu'il s'en
rende compte.

---

## Écart 2 — Indicateur de transparence sur le terrain manquant (compteur explicite)

**Ce que dit la source (§7.5)** :
> "Prévoir un indicateur de transparence dans la sortie de l'API (ex.
> `terrain_connu: bool` par performance, ou un compteur "X/6 performances avec
> terrain inconnu" sur le cheval) plutôt que de masquer silencieusement cette
> incertitude — cohérent avec l'affichage déjà existant du prototype pour les
> historiques courts ou les chevaux inédits."

**Ce qu'on trouve dans le PRD/addendum** : FR-5 couvre bien le *comportement de
calcul* (terrain inconnu → `NULL`, neutre, jamais deviné) et FR-4 pose un
principe général d'indicateurs de qualité de donnée ("Historique court",
"Données non saisies", "🐎 Inédit", "jamais masqué silencieusement"). Mais
aucune Consequence ne reprend spécifiquement l'exigence d'un indicateur/compteur
dédié au terrain manquant (ex. "X/6 performances avec terrain inconnu"), alors
que la source le formule comme une exigence de sortie API explicite, au même
niveau que les autres indicateurs déjà repris dans FR-4. C'est cohérent avec le
principe déjà posé dans le PRD, mais l'instance concrète n'y est pas.

**Suggestion** : écart **mineur à modéré** — ajouter une Consequence à FR-4 ou
FR-5 du type "le nombre de performances à terrain inconnu est visible pour
chaque cheval (ex. compteur X/6), jamais uniquement déductible en creusant
chaque ligne". Peut aller directement dans le PRD puisque c'est un comportement
observable, pas une formule.

---

## Écart 3 — Ingestion anticipée du programme du lendemain

**Ce que dit la source (§6.1, point 1)** :
> "Récupère le programme du jour (**et éventuellement du lendemain**, pour
> préparer l'analyse à l'avance)."

**Ce qu'on trouve dans le PRD/addendum** : FR-16 dit seulement "Un job planifié
récupère chaque jour le programme, les partants et leur historique des courses
françaises, et les stocke en base." Aucune mention de la préparation à l'avance
du programme du lendemain, alors que ce comportement a une justification
produit directe : UJ-1 décrit Marc qui prépare son Quinté+ "la veille au soir"
— ce qui suppose justement que les données du lendemain soient déjà en base au
moment où il ouvre l'app.

**Suggestion** : écart **mineur** — cohérence utile à corriger pour que FR-16
explique explicitement pourquoi UJ-1 fonctionne (ingestion en avance d'un jour).
À ajouter au PRD (Consequence de FR-16) plutôt qu'à l'addendum, car c'est un
comportement observable côté produit (courses visibles la veille).

---

## Écart 4 — Contexte du coût de l'accès légitime (infocentre PMU)

**Ce que dit la source (§3)** :
> "L'accès légitime et documenté aux données PMU en direct existe, mais passe
> par l'infocentre du PMU sous forme de contrat payant, à plusieurs dizaines de
> milliers d'euros par an — réservé aux professionnels, hors de portée d'un
> projet personnel."

**Ce qu'on trouve dans le PRD/addendum** : le PRD §9.3 explique bien que l'API
utilisée est non officielle, non documentée, sans accord écrit, et situe le
risque (durcissement anti-bot, zone grise tolérée). Mais il ne mentionne jamais
qu'une alternative légitime existe et pourquoi elle est écartée (coût
prohibitif). Ce n'est pas un comportement produit, mais c'est un élément de
justification/risque qui aide à comprendre pourquoi le projet accepte le risque
juridique documenté en §9.3 plutôt que de le résoudre autrement.

**Suggestion** : écart **mineur**, à ignorer ou, si on veut être complet,
ajouter une phrase à l'addendum section C ("une alternative légitime existe via
l'infocentre PMU mais à un coût — plusieurs dizaines de milliers d'euros/an —
hors de portée d'un projet personnel, d'où le choix assumé de l'API non
officielle"). Pas nécessaire dans le PRD lui-même.

---

## Écart 5 — Double mode explicite de l'endpoint `/analyse`

**Ce que dit la source (§8)** :
> "Le endpoint `/analyse` doit accepter soit des chevaux fournis directement
> dans la requête (mode "je saisis/j'importe moi-même"), soit une référence à
> une course déjà en base (mode "utilise ce qu'on a déjà collecté") — les deux
> doivent produire un résultat dans le même format."

**Ce qu'on trouve dans le PRD/addendum** : l'endpoint `/analyse` est bien listé
au MVP Scope (§6.1) et réalisé par les FR-7 à FR-12. Les deux parcours existent
bien dans les user journeys (UJ-1 utilise les données déjà en base, UJ-3 importe
manuellement/par photo un cheval), et FR-6 permet l'ajout manuel d'un cheval à
une liste préremplie. Mais l'exigence précise — que les deux modes de saisie
produisent un résultat **dans le même format de sortie**, et que l'endpoint
accepte un mode "aucune course en base, tout saisi à la main" — n'est énoncée
nulle part noir sur blanc comme contrat d'API/produit. C'est implicite via les
parcours mais jamais affirmé comme garantie.

**Suggestion** : écart **mineur** — plutôt une clarification de contrat d'API
qu'un manque de couverture fonctionnelle (les deux modes sont bien couverts
séparément par des FR distinctes). Peut être ignoré, ou ajouté comme
Consequence courte à FR-7 si on veut être exhaustif ("le résultat du calcul a
le même format, que la course provienne de la base ou d'une saisie 100%
manuelle").

---

## Points vérifiés et confirmés bien réconciliés (pas des écarts)

- **Endpoints §8** : les 6 endpoints (`/courses`, `/courses/{id}/partants`,
  `/courses/{id}/importer`, `/analyse`, `/extraction/fiche`,
  `/extraction/programme`) sont tous couverts par une FR et listés au MVP
  Scope §6.1.
- **Pièges §6.2** : `numPmu` instable → PRD Open Question 7 + addendum C ;
  finalisation différée → FR-17 ; terrain absent de l'historique → FR-5 +
  addendum C. Les trois sont repris fidèlement.
- **Questions ouvertes §10** : terrain absent (décision prise, correctement
  absente des questions ouvertes du PRD) ; dérivation du niveau par allocation
  → PRD Open Question 5 ; fréquence/volume d'ingestion → PRD Open Question 6 ;
  homonymes de chevaux → PRD Open Question 7. Les 4 points sont repris.
- **`NON_PLACE` vs incident réel**, **`handicapPoids`/`handicapValeur`** :
  repris dans l'addendum C.
- **Pattern adaptateur (§5.1)** : élevé au rang de contrainte produit au PRD
  §9.3 et FR-16, conformément à l'esprit de la source.
- **Plan de développement (§11)** : correctement pointé (pas dupliqué) via
  addendum F, laissé pour le découpage epics/stories.
- **Mode de repli vision, formats image/PDF, prompts repris tels quels** :
  couverts par FR-18/FR-19.

---

## Synthèse des suggestions

| # | Écart | Gravité | Action suggérée |
|---|---|---|---|
| 1 | Fiabilité du dossard sur fiche extraite (Genybet) | Significatif | Ajouter à l'addendum C + Consequence testable sur FR-18/FR-19 |
| 2 | Indicateur de transparence terrain manquant (compteur explicite) | Modéré/mineur | Ajouter une Consequence à FR-4 ou FR-5 dans le PRD |
| 3 | Ingestion anticipée du programme du lendemain | Mineur | Ajouter une Consequence à FR-16 dans le PRD |
| 4 | Coût de l'accès légitime infocentre PMU | Mineur | Optionnel — addendum C si on veut être complet |
| 5 | Double mode explicite de `/analyse` (même format de sortie) | Mineur | Optionnel — Consequence courte à FR-7 |
