# Cahier des charges — Backend d'analyse hippique

## 0. Contexte

Ce document spécifie un backend Python destiné à remplacer et industrialiser un
prototype existant (fichier HTML autonome + artifact React) qui implémente un
moteur d'aide à la décision pour les courses hippiques françaises (plat, trot,
obstacle). Le moteur de calcul du prototype est **déjà conçu, testé et validé
numériquement** — ce cahier des charges sert à le porter fidèlement en Python,
à l'adosser à une source de données automatisée, et à l'exposer via une API.

**Ce projet N'EST PAS** un système de paris automatisé, ni un générateur de
pronostics présentés comme des certitudes. C'est un outil d'aide à la décision :
il calcule des probabilités et les compare à des cotes, il ne garantit aucun
gain. Toute interface utilisateur construite sur ce backend doit conserver un
message rappelant que le jeu comporte des risques.

## 1. Objectif du backend

1. Ingérer quotidiennement les données de courses hippiques françaises
   (programme, partants, résultats) dans une base de données propre.
2. Exposer une API (FastAPI) permettant de récupérer courses/partants/historique
   et de lancer le calcul du moteur d'analyse sur un jeu de partants donné.
3. Conserver un mode de repli par extraction d'image (vision IA) pour les cas
   où la source de données automatisée est indisponible ou ne couvre pas une
   course (ex. réunions à l'étranger, historique antérieur à la mise en place
   de l'ingestion).

## 2. Périmètre

### Dans le périmètre
- Le moteur de calcul (scoring, probabilités, value, combinaisons de paris).
- L'ingestion automatisée depuis la source de données identifiée (section 4).
- Le stockage en base de données pour réutiliser l'historique déjà collecté
  plutôt que de le redemander à chaque analyse.
- Une API HTTP consommable par un futur client (app mobile Flutter, le
  prototype web existant, ou tout autre client).
- Un mode de repli par extraction d'image pour compléter les données absentes.

### Hors périmètre (explicitement)
- Le placement automatique de paris, quel que soit le canal (PMU, Genybet…).
  Le backend ne doit jamais soumettre de pari — il ne fait que calculer et
  informer.
- Un compte utilisateur, une authentification multi-utilisateurs, une
  facturation. Ce backend est un service interne à usage personnel dans un
  premier temps.
- La couverture des courses hors France (le moteur et les échelles terrain/
  niveau sont calibrés sur les conventions françaises).
- Le front-end final (app Flutter). Ce cahier de charges couvre uniquement le
  backend et son API.

## 3. Avertissement légal et technique — à lire avant de coder

La source de données décrite en section 4 est une **API non officiellement
publiée** par le PMU. Elle est largement utilisée par des amateurs depuis des
années (forums Excel/VBA, projets personnels), mais :

- Elle n'est couverte par **aucune autorisation écrite**. Un développeur ayant
  posé la question sur le forum officiel du PMU n'a pas obtenu de réponse claire.
- L'accès **légitime et documenté** aux données PMU en direct existe, mais passe
  par l'infocentre du PMU sous forme de contrat payant, à plusieurs dizaines de
  milliers d'euros par an — réservé aux professionnels, hors de portée d'un
  projet personnel.
- L'API peut changer de format ou être bloquée sans préavis : le code
  d'ingestion doit être écrit de façon isolée (voir section 5, pattern
  adaptateur) pour qu'un changement de source n'oblige pas à réécrire le
  moteur de calcul ni le schéma de base de données.
- Le projet doit rester raisonnable dans sa fréquence d'appel (pas de
  parallélisation agressive, un identifiant `User-Agent` honnête, un
  espacement entre requêtes) — l'objectif est de constituer un historique
  personnel, pas de aspirer l'intégralité des archives PMU en une nuit.

## 4. Source de données

### 4.1 Endpoints identifiés et vérifiés

Base : `https://offline.turfinfo.api.pmu.fr/rest/client/{id}/programme/...`
(un miroir `online.turfinfo.api.pmu.fr` existe aussi et répond aux mêmes
chemins). `{id}` est un numéro de version de client (7 et 61 ont été observés
fonctionnels ; à re-tester si un endpoint cesse de répondre).

| Endpoint | Retourne |
|---|---|
| `/programme/{DDMMYYYY}` | Programme complet du jour : réunions → courses, avec hippodrome, distance, discipline, allocation, corde, etc. |
| `/programme/{DDMMYYYY}/R{n}/` | Détail d'une réunion |
| `/programme/{DDMMYYYY}/R{n}/C{n}/` | Détail d'une course |
| `/programme/{DDMMYYYY}/R{n}/C{n}/participants` | Liste des partants (voir 4.2). Fonctionne aussi bien sur une date future (avant course) que passée (résultat inclus). |
| `/programme/{DDMMYYYY}/R{n}/C{n}/performances-detaillees/pretty` | Historique des **5 dernières courses** de chaque partant (voir 4.3). Le suffixe `/pretty` retourne un JSON indenté ; il fonctionne aussi sans. |

Ces quatre endpoints ont été testés manuellement en session et répondent avec
des données réelles et cohérentes (testé sur des dates de 2018 et 2022 ; le
programme du jour même n'a pas été testé mais suit vraisemblablement le même
format).

### 4.2 Schéma observé — `participants`

Champs par cheval (liste non exhaustive, garder le JSON brut en base pour ne
rien perdre) :

```
numPmu            — numéro de dossard DANS CETTE COURSE (voir piège 6.2)
nom                — nom du cheval
age, sexe, race
statut             — "PARTANT", etc.
oeilleres
proprietaire, entraineur, driver (jockey/driver)
robe               — {code, libelleCourt, libelleLong}
musique            — chaîne brute type "1h5s2h1s2s1s2s0p161h"
nombreCourses, nombreVictoires, nombrePlaces, nombrePlacesSecond, nombrePlacesTroisieme
gainsParticipant   — {gainsCarriere, gainsVictoires, gainsPlace, gainsAnneeEnCours, gainsAnneePrecedente}
handicapValeur     — valeur de handicap si applicable. À traiter avec prudence :
                       observé fréquemment à 0.0 sur des fiches réelles où la
                       valeur n'est probablement pas calculée plutôt que
                       réellement nulle — ne pas interpréter 0.0 comme un
                       signal, le traiter comme une valeur manquante.
handicapPoids      — poids porté (dixièmes de kg, ex. 720 = 72,0 kg — À VÉRIFIER l'unité exacte avant usage)
nomPere, nomMere, nomPereMere
ordreArrivee       — position finale, PRÉSENT UNIQUEMENT une fois la course courue
incident           — ex. "ARRETE" ; absent si pas d'incident
distanceChevalPrecedent — écart avec le cheval précédent à l'arrivée
dernierRapportDirect / dernierRapportReference — cote : {typePari, rapport, dateRapport, favoris, ...}
urlCasaque         — image de la casaque
eleveur, allure    — "GALOP" ou "TROT" selon la discipline
```

`incident` (top-level) et `ordreArrivee` absent sont la façon dont l'API signale
qu'un cheval n'a pas terminé normalement — à faire correspondre à la colonne
Incident du moteur de calcul (section 7.4).

### 4.3 Schéma observé — `performances-detaillees`

Par partant (`numPmu`, `nomCheval`), une liste `coursesCourues` (5 éléments
observés) avec pour chaque course passée :

```
date               — timestamp en millisecondes
hippodrome, nomPrix
discipline         — "ATTELE" ou "MONTE"
allocation         — montant du prix (proxy de niveau de course, voir 7.2)
distance, nbParticipants
tempsDuPremier
participants[]     — les ~5-6 premiers de CETTE course passée, chacun avec :
  place: {place, statusArrivee}   — statusArrivee ∈ {"PLACE","NON_PLACE","DISQUALIFIE", ...}
  nomCheval, nomJockey, reductionKilometrique, distanceParcourue
  itsHim             — true sur l'entrée correspondant au cheval qu'on analyse
```

**Manque constaté** : aucun champ d'état du terrain (pénétrométrie) n'apparaît
dans cette réponse. À traiter comme limitation connue (voir Questions
ouvertes, section 10) plutôt qu'ignorée silencieusement.

**Attention sur `NON_PLACE`** : ce statut signifie vraisemblablement que le
cheval a terminé hors de la liste des ~5-6 premiers affichés, pas
nécessairement qu'il a subi un incident. Ne pas le mapper automatiquement sur
un incident de type A/RO/RR du moteur (section 7.4) sans vérification
supplémentaire — seul `DISQUALIFIE` correspond avec certitude à un incident
réel (code `D`).

### 4.4 Mode de repli — extraction par image ou PDF

Quand l'API ne couvre pas une course (réunion étrangère, historique ancien) ou
n'est plus accessible, réutiliser le pipeline d'extraction déjà conçu dans le
prototype React : un appel à un modèle de vision avec un prompt structuré,
renvoyant un JSON strict (nom, dossard, âge, poids, cote, dernières
performances avec rang/partants/niveau/distance/terrain/incident). Les fiches
peuvent être fournies en image (PNG/JPEG) **ou en PDF** (export de page
courant sur certains sites de courses) — l'endpoint `/extraction/*` doit
accepter les deux formats, avec `document`/`application/pdf` comme type de
contenu côté appel au modèle de vision plutôt que `image` lorsque le fichier
est un PDF. Les deux prompts exacts (fiche cheval individuelle et programme de
course complet) sont disponibles dans le fichier `analyse_hippique_ia.jsx` du
prototype et doivent être repris tels quels — ils encodent déjà les règles de
conversion terrain et niveau ci-dessous, ainsi que la reconnaissance des
incidents apparaissant directement comme une lettre dans la colonne rang
(ex. "A" pour Arrêté) plutôt que dans la seule musique.

**Prudence sur le numéro affiché en tête de fiche** : sur certains sites
(observé sur Genybet), ce numéro peut être élevé (ex. 604) sans certitude
qu'il corresponde au numéro de dossard PMU réel de la course du jour — le
prompt d'extraction le signale comme plausible mais à vérifier, ne pas le
traiter comme fiable à 100 % sans recoupement.

## 5. Architecture proposée

```
backend/
  app/
    main.py                 — point d'entrée FastAPI
    api/
      routes_courses.py     — endpoints programme/partants/historique
      routes_analyse.py     — endpoint de calcul (moteur)
    engine/
      scoring.py            — port Python du moteur (section 7)
      combinatoire.py        — tiercé/quarté/quinté ordre/désordre + Monte Carlo
      constants.py           — tables terrain/niveau/incidents (section 7)
    data/
      pmu_client.py          — adaptateur HTTP vers l'API PMU (isolé, voir 5.1)
      vision_client.py        — adaptateur d'extraction par image (repli)
      models.py               — modèles ORM (SQLAlchemy)
      repository.py           — accès BDD (indépendant de la source)
    jobs/
      ingest_daily.py          — job d'ingestion quotidien (section 6)
    schemas/
      *.py                     — schémas Pydantic (validation des entrées/sorties)
  tests/
    test_scoring.py            — cas de test portés depuis le prototype JS (section 9)
    test_combinatoire.py
    test_pmu_client.py          — tests contre des réponses PMU enregistrées (fixtures), pas contre l'API en direct
  requirements.txt
  README.md
```

### 5.1 Pattern adaptateur (important)

`pmu_client.py` doit être la **seule** partie du code qui connaît le format de
réponse du PMU. Il expose des fonctions qui retournent des objets internes déjà
normalisés (ex. `get_programme(date) -> Programme`, `get_partants(date, r, c)
-> list[Partant]`, `get_historique(date, r, c) -> dict[numPmu, list[Performance]]`).
Le reste du code (moteur, API, base de données) ne doit jamais lire un champ
JSON brut du PMU directement. Objectif : si l'API change de format ou est
remplacée par l'extraction vision, seul ce fichier change.

## 6. Ingestion et base de données

### 6.1 Job quotidien

Un job planifié (cron, ou tâche périodique de l'application) qui, chaque jour :
1. Récupère le programme du jour (et éventuellement du lendemain, pour
   préparer l'analyse à l'avance).
2. Pour chaque course, récupère les partants et leur historique
   `performances-detaillees`.
3. Stocke le tout en base (voir schéma 6.3).
4. Repasse sur les courses de la **veille** pour en récupérer le résultat
   définitif (voir piège 6.2) et marquer la course comme `finalisee`.

### 6.2 Pièges à anticiper dans le schéma

- **`numPmu` n'est pas un identifiant stable de cheval** — c'est un numéro de
  dossard valable uniquement pour une course donnée. Pour relier les
  performances d'un même cheval à travers ses courses, la clé doit être le
  **nom du cheval normalisé** (majuscules, espaces normalisés). Documenter le
  risque résiduel d'homonymes plutôt que de le considérer comme résolu.
- **Un résultat n'est pas toujours définitif immédiatement** — une
  disqualification peut être prononcée après enquête, plusieurs heures après
  l'arrivée. Ne marquer une course `finalisee` que le lendemain (ou après un
  délai configurable), et prévoir une re-vérification ponctuelle plus tard si
  possible.
- **Pas de terrain dans l'historique** (section 4.3) — prévoir un champ
  nullable plutôt que de forcer une valeur par défaut silencieuse qui
  fausserait le calcul de coefficient terrain.

### 6.3 Schéma de données (proposition de départ)

```
Course
  id, date, hippodrome, discipline (plat/trot/obstacle), distance,
  allocation, nb_partants, corde, terrain (nullable), niveau_estime (dérivé de
  l'allocation, voir 7.2), finalisee (bool), source ("pmu" | "vision")

Cheval
  id, nom_normalise, sexe, date_naissance_ou_age_connu, robe

Participation
  id, course_id (FK), cheval_id (FK), num_pmu (numéro de dossard ce jour-là),
  age_a_la_course, poids, cote_reference, cote_direct, rang_arrivee (nullable
  tant que non finalisée), incident (nullable), driver, entraineur

Performance_historique (une ligne par course passée d'un cheval, alimentée
  par performances-detaillees — distincte de Participation qui décrit la
  course du jour analysée)
  id, cheval_id (FK), date, hippodrome, discipline, distance, niveau_estime,
  terrain (NULLABLE — voir 7.5, ne jamais stocker de valeur par défaut ici),
  rang, partants, incident (nullable)

Cote_historique (optionnel, si on veut suivre l'évolution des cotes)
  participation_id (FK), horodatage, valeur
```

### 6.4 Base de données recommandée

SQLite pour démarrer (zéro configuration, fichier unique, largement
suffisant pour un usage personnel avec quelques milliers de courses par an) ;
prévoir la migration vers PostgreSQL uniquement si le volume ou un besoin
d'accès concurrent l'impose. Utiliser SQLAlchemy pour ne pas coupler le code
au moteur de base choisi.

## 7. Le moteur de calcul — spécification exacte

Cette section doit être portée **fidèlement**, constante par constante et
formule par formule. Les valeurs ci-dessous ont déjà été vérifiées
numériquement dans le prototype JavaScript (sommes de probabilités égales à 1,
comportement des cas limites testé). Toute modification de ces constantes doit
être un choix explicite, pas une divergence accidentelle de portage.

### 7.1 Terrain (gazon — 10 niveaux officiels, France Galop)

| Terrain | Coefficient |
|---|---|
| Très léger | 1.08 |
| Léger | 1.05 |
| Bon léger | 1.02 |
| Bon | 1.00 |
| Bon souple | 0.97 |
| Souple | 0.93 |
| Très souple | 0.88 |
| Collant | 0.83 |
| Lourd | 0.77 |
| Très lourd | 0.70 |

Terrain (sable fibré / PSF — échelle séparée, ne pas mélanger avec le gazon) :

| Terrain PSF | Coefficient |
|---|---|
| Rapide | 1.00 |
| Standard | 0.99 |
| Lent | 0.95 |

### 7.2 Niveau de course

| Niveau | Coefficient |
|---|---|
| Groupe I | 5.0 |
| Groupe II | 4.5 |
| Groupe III | 4.0 |
| Groupe IV | 3.5 |
| Listed | 3.0 |
| Catégorie A | 2.6 |
| Catégorie B | 2.3 |
| Catégorie C | 2.0 |
| Catégorie D | 1.7 |
| Catégorie E | 1.4 |
| Catégorie F | 1.1 |
| Catégorie G/H | 1.0 |

Valable à la fois pour le galop (courses à conditions) et le trot (courses de
séries) — même échelle par lettre pour les deux disciplines en dessous de
Listed.

**Dérivation depuis l'allocation (source PMU) — PRIORITÉ HAUTE, pas un cas
rare.** La source de données ne fournit pas directement ce niveau catégoriel,
seulement l'`allocation` (montant du prix) et un libellé générique de type de
course (ex. "Cond." pour course à conditions). Ce n'est pas une limitation
occasionnelle : l'examen manuel de fiches réelles (Geny, Genybet) montre que
la case catégorie/lettre est **le plus souvent vide**, avec seulement un
libellé générique et l'allocation renseignés — ce cas doit donc être traité
comme le chemin normal, pas comme un repli exceptionnel. Prévoir une fonction
qui déduit un niveau approximatif à partir de l'allocation (par exemple par
quantiles observés sur l'ensemble des courses ingérées), à défendre comme
approximation plutôt que comme classification officielle tant qu'une source
donnant le niveau exact n'est pas trouvée. Traiter spécifiquement le libellé
**"Réclamer" / "À Réc."** (course où les chevaux sont achetables après
course) comme un signal de niveau modeste distinct du générique "Cond." —
mapper vers une catégorie basse (~1.4) plutôt que vers le niveau par défaut
(~2.0) utilisé quand le libellé est vraiment inconnu.

### 7.3 Pondération de récence (C1 = course la plus récente)

```
std   = [1.00, 0.85, 0.70, 0.55, 0.42, 0.30]
forme = [1.00, 0.65, 0.42, 0.28, 0.18, 0.12]
flat  = [1.00, 1.00, 1.00, 1.00, 1.00, 1.00]
```

### 7.4 Incidents

Un incident applique un **malus soustractif** à la note de la ligne (pas un
simple "traiter comme dernier"), sauf NR qui exclut la ligne du calcul.

| Code | Signification | Malus | Compte comme "chute" |
|---|---|---|---|
| T | Tombé | 1.2 | oui |
| F | Fell | 1.2 | oui |
| BD | Brought Down (chute non imputable) | 1.0 | oui |
| U | Désarçonné | 1.0 | oui |
| A | Arrêté | 0.7 | non |
| RO | Sorti de piste | 0.7 | oui |
| RR | Refus de départ | 0.7 | non |
| D | Disqualifié | 0.8 | non |
| R | Rétrogradé | 0.5 | non |
| NR | Non partant | — | exclu du calcul (ignore=true) |

Le malus est multiplié par un paramètre global réglable `malus_incident`
(défaut 1.0).

### 7.5 Formule de note par performance

Le terrain d'une performance passée peut être **inconnu** (absent de la source
PMU — voir 4.3). Dans ce cas, ne jamais deviner une valeur par défaut : traiter
l'ajustement terrain comme **neutre** (`c_terr = 1.0`, ni bonus ni malus),
exactement comme un cheval inédit ou sans historique n'est ni avantagé ni
pénalisé arbitrairement (section 7.7). Stocker le champ terrain comme
`NULL` en base plutôt que comme une valeur par défaut arbitraire (ex. "Bon"),
pour ne pas fabriquer une fausse certitude et pouvoir le compléter plus tard
sans ambiguïté (saisie manuelle ponctuelle, extraction d'image, ou une future
source).

```python
def compute_note(perf, course_cible, malus_incident=1.0):
    sb = max(0, (perf.partants - perf.rang + 1) / perf.partants)

    dd = abs(perf.distance - course_cible.distance)
    c_dist = 1.0 if dd <= 200 else 0.9 if dd <= 500 else 0.8

    if perf.terrain is None:
        c_terr = 1.0                         # terrain inconnu — neutre
    else:
        dt = abs(perf.terrain - course_cible.terrain)
        c_terr = 1.0 if dt < 0.05 else 0.95 if dt <= 0.10 else 0.9

    ratio = perf.niveau / course_cible.niveau
    c_niv = min(1.5, max(0.55, sqrt(ratio)))

    malus = INCIDENTS[perf.incident].malus * malus_incident

    return max(0, sb * c_niv * c_dist * c_terr - malus)
```

Prévoir un indicateur de transparence dans la sortie de l'API (ex.
`terrain_connu: bool` par performance, ou un compteur "X/6 performances avec
terrain inconnu" sur le cheval) plutôt que de masquer silencieusement cette
incertitude — cohérent avec l'affichage déjà existant du prototype pour les
historiques courts ou les chevaux inédits.

### 7.6 Ajustements poids et âge (calculés même sans historique)

```python
c_poids = 1.0
if cheval.poids > 0 and moyenne_poids_lot > 0:
    c_poids = clamp(1 - (sensibilite_poids/100) * (cheval.poids - moyenne_poids_lot),
                     0.85, 1.15)

c_age = 1.0
if cheval.age < age_min:
    c_age = clamp(1 - 0.05 * (age_min - cheval.age), 0.8, 1.0)
elif cheval.age > age_max:
    c_age = clamp(1 - 0.05 * (cheval.age - age_max), 0.8, 1.0)
```

Défauts : `sensibilite_poids=1` (%/kg), `age_min=4`, `age_max=7`.

### 7.7 Score final — lissage bayésien et cas particuliers

```python
moyenne_forme = moyenne(forme_i pour tout cheval i avec nb_perfs > 0)
base = moyenne_forme if moyenne_forme > 0 else 1.0   # course de débutants

for cheval in lot:
    if cheval.nb_perfs > 0:
        forme_ajustee = (cheval.nb_perfs * cheval.forme + shrink * moyenne_forme) \
                         / (cheval.nb_perfs + shrink)
        score = forme_ajustee * cheval.c_poids * cheval.c_age
    elif cheval.inedit:          # fait connu : n'a jamais couru
        score = base * coef_inedit * cheval.c_poids * cheval.c_age
    else:                         # donnée simplement non saisie/non trouvée
        score = base * 0.6        # aucun ajustement poids/âge : on ne sait rien
```

Défauts : `shrink=2`, `coef_inedit=0.75`.

`forme` d'un cheval = moyenne pondérée de ses notes de performance par les
poids de récence (section 7.3), normalisée par la somme des poids utilisés
(gérer le cas où un cheval a moins de 6 performances : ne pondérer que sur les
performances réellement présentes).

### 7.8 Partants non analysés (outsiders virtuels)

Si le nombre de partants réel de la course (`nb_partants_course`) dépasse le
nombre de chevaux effectivement passés dans le moteur (`nb_analyses`), les
partants manquants sont traités comme des outsiders virtuels :

```python
n_virtuels = nb_partants_course - nb_analyses
score_moyen = moyenne(score_i pour i dans les chevaux analysés)
score_virtuel = max(score_moyen * 0.6, 0.0001)
```

Chacun des `n_virtuels` chevaux virtuels reçoit `score_virtuel` et participe
au calcul de probabilités (section 7.9) comme un cheval normal.

### 7.9 Probabilités (modèle Plackett-Luce)

```python
k = contraste  # défaut 3
pow_i = max(score_i, 0.0001) ** k
P_i = pow_i / sum(pow_j pour tout j, y compris les outsiders virtuels)
```

Vérifier que `sum(P_i) == 1.0` (à epsilon près) dans les tests.

### 7.10 Probabilités de place (Harville) — Top1/Top2/Top3/Top4

Chaîne de Harville standard :

```
P(i 1er) = P_i
P(i 2e)  = Σ_j≠i  P_j · P_i / (1 - P_j)
P(i 3e)  = Σ_j≠i Σ_k∉{i,j}  P_j · (P_k/(1-P_j)) · (P_i/(1-P_j-P_k))
```

`Top2 = P(1er) + P(2e)`, `Top3 = Top2 + P(3e)`, et de même pour Top4 en
étendant la récurrence d'un rang. Inclure les chevaux virtuels dans la somme
(ils comptent dans le champ mais n'apparaissent pas dans les résultats
affichés).

Vérifier dans les tests : `sum(Top1_i) ≈ 1`, `sum(Top2_i) ≈ 2`,
`sum(Top3_i) ≈ 3`, `sum(Top4_i) ≈ 4`.

### 7.11 Value et mise (Kelly fractionné)

Uniquement pour les chevaux dont la cote est connue :

```python
p_implicite = 1 / cote
value = P_i * cote - 1
kelly = (P_i * cote - 1) / (cote - 1)
mise = bankroll * kelly * fraction_kelly if kelly > 0 else 0
```

Défauts : `bankroll=100`, `fraction_kelly=0.25`.

`overround = sum(1/cote_i) - 1`, calculable seulement si toutes les cotes des
chevaux analysés sont connues.

### 7.12 Combinaisons de paris

Deux familles de calcul, à ne pas confondre :

**Énumération exacte** (Plackett-Luce) pour les paris à ordre/désordre :
Couplé (2), Trio/Tiercé (3), Quarté (4), Quinté (5). Limiter le pool aux
7-8 meilleurs chevaux du modèle pour garder la combinatoire praticable
(un Quinté sur 8 chevaux = 8×7×6×5×4 = 6720 permutations, largement
faisable). Pour chaque combinaison :

```python
p_ordre = P_a * (P_b/(1-P_a)) * (P_c/(1-P_a-P_b)) * ...
```

Le "désordre" agrège toutes les permutations d'un même ensemble de chevaux.

**Simulation Monte-Carlo** pour les paris "parmi les k premiers"
(Couplé Placé = 2 parmi les 3 premiers, 2 sur 4 = 2 parmi les 4 premiers) :
non calculables exactement à coût raisonnable. Simuler ~20 000 tirages sans
remise pondérés par les probabilités, compter les paires arrivées "dans le
groupe de tête" visé. Utiliser `numpy` pour vectoriser (le prototype JS utilise
une boucle simple ; en Python, préférer une implémentation vectorisée pour la
performance).

Afficher les combinaisons triées par probabilité décroissante, avec les
numéros de dossard (pas seulement les noms).

## 8. Endpoints API (FastAPI)

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/courses?date=` | Liste des courses d'un jour (depuis la BDD, fallback API PMU si absent) |
| GET | `/courses/{course_id}/partants` | Partants d'une course, avec leur historique déjà en base si disponible |
| POST | `/courses/{course_id}/importer` | Déclenche l'ingestion à la demande d'une course (si pas encore en base) |
| POST | `/analyse` | Corps : course cible + liste de chevaux (ou `course_id` pour utiliser les données déjà en base) + paramètres du moteur → renvoie classement, probabilités, value, combinaisons |
| POST | `/extraction/fiche` | Repli vision : image → JSON cheval structuré |
| POST | `/extraction/programme` | Repli vision : image → JSON course + partants structuré |

Le endpoint `/analyse` doit accepter soit des chevaux fournis directement dans
la requête (mode "je saisis/j'importe moi-même"), soit une référence à une
course déjà en base (mode "utilise ce qu'on a déjà collecté") — les deux
doivent produire un résultat dans le même format.

## 9. Tests — cas à porter depuis le prototype

Ces cas ont déjà été vérifiés numériquement en JavaScript pendant la
conception ; les reproduire en Python garantit un portage fidèle :

1. **Somme des probabilités** : sur un lot de 5 à 12 chevaux, `sum(P_i) == 1`
   à 1e-6 près.
2. **Sommes Harville** : `sum(Top1) ≈ 1`, `sum(Top2) ≈ 2`, `sum(Top3) ≈ 3`,
   `sum(Top4) ≈ 4` sur un lot de test.
3. **Lissage bayésien** : un cheval avec 1 seule performance à note parfaite
   (1.0) et un lot moyen à 0.55 doit être ramené à ~0.70 avec `shrink=2` (pas
   rester à 1.0).
4. **NR exclu** : une ligne marquée NR ne doit apparaître ni dans `nb_perfs`
   ni influencer `forme`, quelle que soit sa position dans les 6 lignes.
5. **Disqualification vs chute** : un cheval disqualifié après une 1ère place
   doit avoir une note strictement supérieure à un cheval tombé, toutes choses
   égales par ailleurs (0.8 de malus vs 1.2, la disqualification garde de la
   valeur informative).
6. **Outsiders virtuels** : avec 5 chevaux saisis sur 14 partants déclarés,
   la probabilité de victoire du favori doit baisser par rapport au même lot
   analysé seul (sans partants virtuels) — vérifier que la masse de probabilité
   des 9 chevaux virtuels est cohérente (~proportionnelle à leur score réduit).
7. **Value et Kelly** : reproduire l'exemple à 5 chevaux du prototype
   (cotes 2.4/3.6/5.0/7.0/11.0) et vérifier les mêmes ordres de grandeur de
   value et de mise.
8. **Ratio ordre/désordre** : sur un même lot, vérifier que le ratio
   désordre/ordre croît avec la taille de la combinaison (environ ×2 pour le
   couplé, très supérieur pour le quinté) — signe que le calcul combinatoire
   est correct.
9. **Terrain manquant** : une performance avec `terrain=None` doit produire
   `c_terr == 1.0` (ni bonus ni malus), et ne doit jamais lever d'exception ni
   être silencieusement exclue du calcul comme le sont les lignes vides ou NR.

## 10. Questions ouvertes

- **Terrain absent de `performances-detaillees` — DÉCISION PRISE** : traité
  comme neutre dans le moteur (`c_terr = 1.0`, section 7.5) et stocké comme
  `NULL` en base (section 6.3), jamais comme une valeur par défaut supposée.
  Aucune source gratuite et fiable de backfill automatique n'a été identifiée :
  - *France Galop* (galop uniquement) publie officiellement l'indice de
    pénétrométrie et son qualificatif sur son site au moment de chaque
    réunion, et propose depuis 2021 des données GoingStick plus riches sur les
    courses de sélection (Groupe I/II/III/Listed) via son partenaire TurfTrax
    — mais aucune API publique n'a été trouvée, et la profondeur d'archive
    historique consultable n'a pas été vérifiée. Un accès commercial existe
    (société Mclloyd, abonnement payant) pour les données de tracking des
    courses premium — hors périmètre d'un projet personnel.
  - *Trot* : l'organisme équivalent à France Galop est la SETF (Société
    d'encouragement à l'élevage du Trotteur Français, ex-SECF), exploitant le
    site LeTROT (letrot.com). Même situation : pas d'API publique identifiée.
  - À ce stade, le terrain manquant reste une limitation acceptée du produit,
    pas un problème à résoudre dans les premières phases. Revisiter
    uniquement si une source fiable apparaît, ou compléter ponctuellement à la
    main pour une course dont le terrain compte vraiment pour la décision.
- **Dérivation du niveau depuis l'allocation** : la méthode de quantiles
  proposée (section 7.2) doit être calibrée sur un premier jeu de données réel
  avant d'être considérée fiable — prévoir une phase de vérification manuelle
  sur un échantillon de courses dont le niveau est connu par ailleurs.
- **Fréquence et volume d'ingestion raisonnables** : combien de
  réunions/courses par jour ingérer sans solliciter excessivement une source
  non officielle ? À décider avant d'automatiser le job (section 6.1).
- **Gestion des homonymes de chevaux** : accepter le risque documenté, ou
  ajouter un critère de désambiguïsation (né la même année, même
  entraîneur récurrent) si un cas réel se présente ?

## 11. Plan de développement suggéré

1. **Port du moteur** (section 7) en Python pur, avec les tests de la
   section 9 qui passent avant toute intégration à une source de données.
2. **Client PMU** (section 5.1) contre des réponses enregistrées (fixtures
   JSON capturées manuellement), pas contre l'API en direct dans les tests
   automatisés.
3. **Base de données et job d'ingestion** (section 6), d'abord en écriture
   seule (collecter sans encore s'en servir) pour commencer à accumuler de
   l'historique pendant que le reste avance.
4. **API FastAPI** (section 8) reliant moteur + base de données.
5. **Mode de repli vision** (section 4.4), en réutilisant les prompts déjà
   rédigés dans le prototype React.
6. **Calibration** : une fois quelques semaines de données réelles
   accumulées, comparer les probabilités du modèle aux résultats réels
   (le cheval donné à 20% gagne-t-il environ une fois sur cinq ?) et ajuster
   les paramètres par défaut (`k`, `shrink`, `coef_inedit`, etc.) en
   conséquence.
