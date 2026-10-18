# Cahier des charges — Module « Multi » (pronostic, systèmes réduits, évaluation)

> Addendum au **cahier des charges backend** (sections 6.3, 7.10, 7.12, 8, 9, 11) et au
> **cahier des charges mobile** (section 7). À lire avec eux ; ne les remplace pas.
> Source d'inspiration : document « Multi-Systèmes » (PMU, édition 2001-2002, scanné
> en trois PDF). Ses règles du pari (section 2) et ses systèmes réduits (section 5)
> sont repris ; ses méthodes de sélection (M1, M2) deviennent des **comparateurs**,
> pas la recommandation.
>
> **Version 3 — 2026-10-18. Le Multi devient un pronostic, sans argent.** Recadrage
> du porteur de projet (section « D ter » de
> `_bmad-output/planning-artifacts/multi/reconcile-cdc-multi-prd.md`, qui remplace
> D0, D3 et D5 et précise D4) : « pas de mise ni de gain, juste un pronostic sur les
> chevaux qui peuvent constituer l'arrivée du Multi ». Changements par rapport à la
> v2 : plus aucun budget, coût, multiplicateur, mise, gain, rapport, seuil de
> rentabilité ni « prix du point de couverture » ; la **taille de la sélection est
> choisie par l'utilisateur** (4 à 20, par défaut la dernière utilisée, sinon 10) et
> le modèle choisit les chevaux par le même algorithme ; les **bases** deviennent
> 3 « chevaux les plus probables » candidats, activables ; les **systèmes réduits** sont listés
> pour toutes les formules, sans coût ; le **verdict** est remplacé par un **indice
> de confiance** (élevée / moyenne / faible) ; l'**indice de valeur** est abandonné
> (annexe E) ; les **rapports Multi** ne sont plus ingérés ni évalués ; le « jeu
> retenu » devient le « **pronostic retenu** ». Règles, générateur, vérificateur,
> catalogue, relabellement, M1, B0, B1 et annexes sont inchangés.
>
> **Version 2 — 2026-10-17.** Réalignée sur le PRD et l'architecture après
> réconciliation (`_bmad-output/planning-artifacts/multi/reconcile-cdc-multi-prd.md`,
> décisions D0 à D7 du porteur de projet). Changements majeurs par rapport à la v1 :
> le **modèle** décide (section 4.1) ; ajout du **verdict** (6.4), des **bases
> proposées** (4.2), de la **taille choisie sous budget** (4.3) et des
> **explications** (6.5) ; M2 reporté hors V1 ; pas de mise recommandée ; nommage
> français ; MVP en français, explications en codes pour préparer l'anglais.
>
> **Architecture (2026-10-17, mise à jour 2026-10-18).** Pour l'organisation
> technique (où sont produits, stockés et lus les systèmes, les règles, les codes,
> le pronostic retenu, les tables et les migrations), la spine d'architecture fait
> foi (AD-6 à AD-13) :
> `_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`. Ce cahier a été aligné sur elle.

## 0. Contexte et principe directeur

### 0.1 Angle du module

> **Pour cette course et pour la taille de sélection que je choisis, le modèle me
> dit quels chevaux peuvent constituer l'arrivée du Multi, quels sont les chevaux
> les plus probables (bases), quels systèmes réduits les couvrent, avec quelle confiance, et
> pourquoi.**

Cinq questions (sélection, bases, systèmes, confiance, pourquoi), une seule
autorité : **le modèle** du produit (Plackett-Luce / Harville, cahier backend
7.9-7.10). C'est un **pronostic**, comme le reste de l'application : il ne dit ni
combien jouer, ni combien gagner. Toute exigence de ce cahier sert l'une de ces
cinq questions, ou l'évaluation de la qualité des réponses (section 8).

### 0.2 Ce que contient le document source

1. **Règles officielles du Multi** (prix, formules 4/5/6/7, rapports, non-partants,
   dead-heat, arrivée dégradée) — section 2.
2. **Deux méthodes de sélection** (« Méthode 1 » : 12 chevaux ; « Méthode 2 » :
   10 chevaux) avec fiche de travail et 4 exemples traités — section 4.5, comme
   comparateurs.
3. **Un catalogue de systèmes réduits** (« sans base », « 1 base », « 2 bases »,
   « 3 bases », « garantie 4/4 ») — c'est ce que l'utilisateur appelle *champ réduit*
   (« banco » = *base* dans le vocabulaire du document) — section 5.

### 0.3 Principes (à ne jamais dériver)

- L'outil **analyse et pronostique** ; il ne place **jamais** de pari. Aucune
  fonctionnalité d'achat de ticket, quelle que soit la version.
- **Aucune notion d'argent** (D ter) : ni budget, ni coût, ni multiplicateur, ni
  mise, ni gain, ni rapport, ni seuil de rentabilité, ni indice de valeur, ni « prix
  du point de couverture » — ni dans le moteur, ni dans l'API, ni à l'écran.
- **L'utilisateur choisit la taille, le modèle choisit les chevaux** (D1, D ter).
  M1, M2 et les références B0/B1 sont des **comparateurs** : consultables à part,
  avec le libellé « **hypothèse non validée** » tant que le protocole de la
  section 8 ne conclut pas.
- Le mot « garantie » du document est un **abus de langage commercial** : la
  « garantie 4/4 » est une **garantie de couverture** (si les 4 premiers sont dans
  la sélection, au moins un ticket les contient), **pas une garantie de gain**.
  Libellé obligatoire dans l'UI : « Couverture garantie — pas un gain garanti ».
- **La qualité du pronostic vient de la sélection, pas du système.** Un système
  réduit ne fait que couvrir la même sélection avec moins de tickets (5.5) ; tout
  avantage doit venir de la **sélection**, mesurée contre des références
  (section 8).
- **Pas de presse dans le calcul** (PRD §5) : aucune donnée de presse ou de
  consensus n'entre dans le pronostic.
- **Rien n'est inventé** : aucun seuil de l'indice de confiance n'est codé « à
  l'estime ». Les valeurs par défaut des seuils sont fixées par le pilote
  (section 8.4) et affichées « provisoires » jusque-là.

### 0.4 Constats vérifiés pendant la lecture du document (à connaître)

| Constat | Vérification |
|---|---|
| Les rapports respectent exactement 35 / 7 / 7⁄3 / 1 (en 4 / 5 / 6 / 7) | Recalculé sur les 4 exemples : ratios 35.000 / 7.000 / 2.333 / 1.000 |
| Les 4 exemples publiés sont tous des **réussites** (4/4 dans la sélection) | Biais de sélection classique. Hasard pur : 12/18 → 16,2 % ; 10/16 → 11,5 % ; 10/14 → 21,0 % |
| Les tableaux de grilles ne sont **pas toujours optimaux** | Solveur exact (MILP) : sur 18 cas testés, 11 égaux à l'optimum, 6 au-dessus (jusqu'à 5 grilles de trop), 1 coquille (3 bases + 14 : « 13 grilles » annoncées, 14 nécessaires). Détail en 5.3 |
| Le document contient des **incohérences internes** dans l'exemple 2 de la méthode 1 | Voir annexe B.3 |

## 1. Périmètre

**Dans le périmètre V1** : règles du Multi ; **pronostic du modèle** à la taille
choisie par l'utilisateur (sélection, bases candidates, systèmes réduits pour
toutes les formules, indice de confiance, explications) ; générateur et
vérificateur de systèmes réduits ; vérification d'un système saisi par
l'utilisateur ; calcul exact de la probabilité de couverture ; comparateurs M1,
B0, B1 ; schéma de données ; journalisation des pronostics et des arrivées ;
protocole de backtest et de test prospectif ; API ; écran mobile ; débrief après
course.

**Reporté (hors V1)** : méthode M2 et tout ce qui la sert (`/extraction/presse`,
fournisseurs de citations et de liste de forme, captures presse) — D2 ; systèmes
mixtes ; choix du système parmi les équivalents (5.5).

**Hors périmètre** : placement de paris ; **tout aspect financier** (mise, budget,
coût, multiplicateur, gain, rapports, rentabilité, indice de valeur — annexe E) ;
ingestion des rapports Multi et évaluation financière ; collecte automatisée de
contenus propriétaires (Paris Turf, 3615 Turf, Geny…) ; paris autres que le Multi
(couverts par le backend 7.12) ; Flexi (voir section 12) ; courses hors France et
PMUC (PRD §5).

## 2. Règles du Multi (source : document, 2001-2002 — À VÉRIFIER sur pmu.fr)

Toutes ces constantes ont **une seule source de référence**, le fichier
`fixtures/multi_regles.json`, avec leur provenance et une **date de vérification
obligatoire** (sans elle, aucune grille n'est affichée). `engine/multi/regles.py` et
`regles.dart` sont validés contre ce fichier par les tests ; aucune constante n'est
dispersée dans le code. Toute modification entraîne la regénération du catalogue
de systèmes (5.2). (Spine AD-7.)

```python
MISE_UNITAIRE_EUR = 3.0         # 20 F à l'origine ; 3 € dès le 01/01/2002. Vérifier la valeur actuelle.
PARTANTS_DECLARES_MIN = 14      # course support : 14 partants déclarés au minimum
FORMULES = (4, 5, 6, 7)         # nombre de chevaux par ticket
CHEVAUX_PAR_TICKET_MAX = 7
SELECTION_MAX = 20              # taille max de sélection gérée par l'outil
PARIS_PAR_TICKET_PHYSIQUE = 4   # un ticket physique porte jusqu'à 4 paris Multi
MULTIPLICATEUR_MAX = 200        # « jusqu'à 200 fois l'enjeu minimum » pour une même combinaison
RAPPORT_MIN = {7: 1.05, 6: 1.10, 5: 1.20, 4: 1.30}   # rapports minimums

# Coefficients de rapport, exprimés en unités du rapport « Multi en 7 » (R7).
# Cause : un ticket en k contient C(k,4) combinaisons de 4 chevaux ; à prix égal,
# le rapport est inversement proportionnel à ce nombre.
from math import comb
COEF_R7 = {k: comb(7, 4) / comb(k, 4) for k in FORMULES}   # {4:35, 5:7, 6:7/3, 7:1}
```

Depuis la v3, les constantes monétaires (`MISE_UNITAIRE_EUR`, `MULTIPLICATEUR_MAX`,
`RAPPORT_MIN`, `COEF_R7`) restent dans le fichier de règles pour qu'il décrive le
pari complet et pour les tests de cohérence (test 1), mais **aucune n'est utilisée
par le pronostic ni affichée**.

**Éligibilité d'une course support.** Une course par jour, 14 partants déclarés au
minimum. Les jours de Quinté+ (document : mar, mer, jeu, sam, dim) c'est une autre
course de la réunion du Quinté+ ; les jours sans Quinté+ (lun, ven) c'est la course
du 2sur4. **À vérifier** : ces jours ont pu changer depuis 2002. Le backend détecte
la course support par la liste `paris` de la course (champ exact à confirmer en
phase de découverte) ; à défaut, il propose « courses de ≥ 14 partants » en mode
exploration (mention « course non support du Multi »).

**Non-partants.** Un ticket en k chevaux avec m non-partants est requalifié en
`k − m` si `k − m ≥ 4`, sinon remboursé :

| Ticket | 1 NP | 2 NP | 3 NP | ≥ 4 NP |
|---|---|---|---|---|
| Multi en 7 | → en 6 | → en 5 | → en 4 | remboursé |
| Multi en 6 | → en 5 | → en 4 | remboursé | remboursé |
| Multi en 5 | → en 4 | remboursé | remboursé | remboursé |
| Multi en 4 | remboursé | remboursé | remboursé | remboursé |

**Dead-heat.** Le rapport est **unique** pour toutes les combinaisons payables ;
le parieur touche autant de rapports que de combinaisons payables incluses dans son
jeu. Ex-aequo aux places 1 à 3 : une seule combinaison payable (pari sans ordre).
Ex-aequo à la 4ᵉ place : deux combinaisons payables, un seul rapport ; un ticket
qui contient les deux touche deux fois ce rapport.

**Aucun gagnant.** Recherche d'une arrivée dégradée, dans cet ordre :
`{1,2,3,5}` → `{1,2,4,5}` → `{1,3,4,5}` → `{2,3,4,5}` ; sinon tous les paris sont
remboursés.

**Fonctions à implémenter** (`engine/multi/regles.py`, pures, sans E/S) :

- `requalifier(ticket, non_partants) -> (k_effectif | None)`
- `combinaisons_payables(arrivee_avec_ex_aequo) -> list[frozenset]` (inclut
  l'arrivée dégradée)
- `regler(tickets, arrivee, non_partants) -> {touches, remboursements}` (tickets
  qui contiennent une combinaison payable, avec leur formule effective après
  requalification ; aucun montant)

## 3. Données d'entrée et sources

**Pronostic (sections 4.1 à 4.4)** : elle n'utilise **que** ce que le moteur
utilise déjà — scores, probabilités Plackett-Luce, Top1-Top4 Harville, cotes du jour,
partants virtuels, indicateurs de transparence. Aucune donnée nouvelle n'est requise.

**Comparateurs et évaluation** :

| Besoin | Source | Champ | Statut | Sert à |
|---|---|---|---|---|
| Rang à la dernière course | `performances-detaillees` → `coursesCourues[0].participants[itsHim].place`, recoupé avec la `musique` | `place`, `statusArrivee`, 1ʳᵉ position de la musique | Existant. Voir piège ci-dessous | M1 |
| Allocation de la dernière course | `performances-detaillees` → `coursesCourues[0].allocation` | `allocation` | **Existant dans l'API mais absent du schéma 6.3** → ajouter la colonne | M1 |
| Cote du jour | `Participation.cote_reference` / `cote_direct` | `dernierRapportReference` | Existant | M1 (départage), B1 |
| Partants déclarés, non-partants | Course PMU | `statut` | Existant | tout |
| Arrivée avec ex-aequo | `ordreArrivee` des participants | — | Existant | débrief, évaluation |

Les **rapports Multi** ne sont plus nécessaires (v3) : ni ingérés, ni affichés, ni
évalués.

**Piège sur le rang.** Le backend 4.3 note que `NON_PLACE` signifie « hors des
~5-6 premiers affichés ». Si seuls 5 sont affichés, un 6ᵉ est indiscernable d'un
7ᵉ. **Règle** : le rang de la dernière course est pris dans la **musique** quand il
est lisible (chiffre 1-9 ; `0` = non placé), la liste détaillée ne servant qu'au
recoupement. En cas de désaccord, `source_rang = "musique"` et un avertissement
est ajouté. Valider le décodeur de musique sur des chaînes réelles (annexe D).

**Cote « non cotée ».** Pour M1 : une cote manquante est traitée comme **la plus
délaissée possible** (+∞) pour le critère « plus délaissé », et comme **la plus
haute** pour « cote la plus basse » (donc jamais choisie). Hypothèse notée dans les
avertissements. Pour le pronostic : sans effet (le modèle ne lit la cote que pour
la value du moteur, non affichée dans le Multi ; elle reste sur l'écran Résultats).

**Schéma : champs à ajouter** (compléter 6.3) :

```
Performance_historique : + allocation (int, NULLABLE), + rang_brut (str: '1'..'9','0','D','T','A',...), + statut_arrivee (str)
Participation          : + cote_reference_decimale (float, NULLABLE)  # si pas déjà dérivé
```

## 4. Pronostic du modèle et comparateurs

### 4.0 Interface commune

```python
@dataclass(frozen=True)
class ChevalMulti:
    num: int                       # dossard DANS CETTE COURSE
    p_gagnant: float               # probabilité Plackett-Luce (moteur 7.9)
    top4: float                    # P(dans les 4 premiers), Harville (moteur 7.10)
    cote: float | None             # cote du jour ; None = non cotée
    value: float | None            # moteur 7.11 ; None si cote manquante ; non affichée dans le Multi
    drapeaux: tuple[str, ...]      # indicateurs de transparence (PRD FR-4) : "historique_court", "inedit", ...
    dernier_rang: str | None       # pour M1 uniquement
    derniere_allocation: int | None  # pour M1 uniquement
    est_partant: bool = True

@dataclass(frozen=True)
class Explication:                 # jamais une phrase : un code + des paramètres (D6)
    code: str                      # ex. "retenu_top4", "ecarte_top4_faible", "base_candidate"
    params: dict                   # ex. {"top4": 0.41, "rang_modele": 3}

@dataclass(frozen=True)
class Choix:
    num: int
    role: str                      # "base" | "selection"
    explications: list[Explication]

@dataclass(frozen=True)
class ResultatSelection:
    strategie: str                 # "modele" | "M1" | "M2" | "B0" | "B1"
    version: str                   # semver — incrémenté à toute modification de règle
    choix: list[Choix]             # dans l'ordre d'application des règles
    avertissements: list[Explication]
    entrees_utilisees: dict        # fournisseurs, variantes, drapeau "degrade"

class StrategieSelection(Protocol):
    id: str
    version: str
    def selectionner(self, chevaux: list[ChevalMulti], ctx: ContexteStrategie) -> ResultatSelection: ...
```

Propriétés exigées de toute stratégie : **déterministe** (mêmes entrées → mêmes
sorties), **pure** (pas de lecture de base ni de réseau), **sans doublon**,
**jamais de non-partant**, **jamais de partant virtuel**, au plus `taille` chevaux.

**Langue (D6).** Le code, l'API et les données sont en français. Le MVP s'affiche
en français ; l'anglais, au choix de l'utilisateur, viendra après le MVP pour toute
l'application. Pour que son ajout ne touche pas au moteur, toute explication,
raison ou avertissement est transmis comme `Explication(code, params)` et rendu par
l'application. Les codes et leurs paramètres sont déclarés dans le registre
`fixtures/multi_codes.json` ; dans le MVP, l'app les rend par une simple table Dart
code → phrase française (spine AD-8). Aucune phrase n'est écrite en dur dans le
moteur ni dans l'API.

### 4.1 Stratégie `modele` — le pronostic (D1, D ter)

**Taille de la sélection** : `v` est **choisie par l'utilisateur**, de 4 à
`min(SELECTION_MAX, nb_partants_reels)` (soit 20 au plus). Valeur par défaut : la
dernière taille utilisée (réglage de l'appareil), sinon **10**. Le
modèle ne choisit jamais la taille.

**Objectif** : pour la taille `v` et les bases actives `B` (4.2), trouver la
sélection `S` (|S| = v, `B ⊆ S`) qui maximise la **probabilité de couverture**
`p_couverture(S, B)` (section 6.1). Sans base active, c'est la probabilité que
l'arrivée (les 4 premiers) soit dans la sélection. La sélection ne dépend pas de la
formule `k`.

**Algorithme (déterministe)** :

1. Candidats : chevaux réels, partants, triés par `top4` décroissant (égalité →
   `p_gagnant` décroissant, puis dossard croissant).
2. Amorce : `B` + les meilleurs candidats par `top4` jusqu'à `v`.
3. Amélioration par échanges : tant qu'un échange (un cheval de `S \ B` contre un
   candidat hors de `S`) augmente `p_couverture` de plus de 1e-12, appliquer le
   meilleur échange (égalité → dossard le plus petit). Arrêt garanti (strictement
   croissant, ensemble fini).
4. Chaque cheval retenu reçoit ses explications (6.5).

Les partants virtuels du moteur (cahier backend 7.8) **entrent dans le champ** de
l'énumération (ils peuvent finir dans les 4) mais ne sont **jamais** sélectionnables.

**Temps de calcul (exécution sur téléphone, 11.3)** : les probabilités `P_ens(A)` de
tous les ensembles de 4 chevaux du champ sont calculées **une seule fois** par course
(≤ 4 845 valeurs) ; `p_couverture(S, B)` n'est alors qu'une somme sur les
sous-ensembles de `S`. La sélection est calculée une fois sans base (pour les bases
candidates, 4.2) et une fois avec les bases actives ; seuls les tickets varient avec
`k` (4.3). Le temps du pronostic complet est mesuré sur l'appareil cible (PRD §11,
question ouverte 1) ; s'il ne paraît pas instantané, l'étape 3 est limitée en
nombre d'itérations et l'avertissement `optimisation_tronquee` est ajouté.

**Pourquoi pas un simple tri par `top4`** : le Multi paie quand **les 4 premiers
ensemble** sont dans `S` ; `Σ top4_i` maximal ne donne pas toujours `p_couverture`
maximale. L'étape 3 corrige ce cas ; un test le vérifie (section 9).

### 4.2 Bases proposées — les « chevaux les plus probables » (D4, D ter)

Le modèle propose **3 bases candidates** (moins si la sélection compte moins de 3
chevaux). Elles sont calculées sur la sélection **sans base** construite par 4.1 à
la taille choisie : ce sont ses 3 chevaux de `top4` le plus élevé (égalité →
`p_gagnant`, puis dossard), c'est-à-dire les chevaux que le modèle estime les plus
probables dans les 4 premiers. Pour chaque base candidate, l'écran affiche :

- `top4` du cheval, présenté comme une estimation (« estimé à X % d'être dans les
  4 premiers ») ;
- les **tickets économisés** en l'activant, formule par formule (différence du
  nombre de tickets du système, à taille égale, avec et sans cette base en plus des
  bases déjà actives) ;
- la **couverture perdue** : `p_couverture(S, B) − p_couverture(S, B ∪ {base})`.

L'utilisateur **active** (= impose comme base) ou **désactive** chaque candidate ;
**aucune n'est active au premier affichage** — sans argent en jeu, activer
une base ne fait que réduire le nombre de tickets au prix d'une couverture plus
faible, ce que l'écran montre. Tout changement relance le calcul (4.1, 4.3, 6.4)
sur l'appareil.

### 4.3 Systèmes réduits de la sélection — toutes les formules, sans coût (D ter)

Il n'y a plus de choix sous budget : le module ne choisit ni la taille, ni le
nombre de bases, ni la formule. Pour la sélection `S` de 4.1 et les bases actives
`B` (`b = |B|`), il renvoie **un système par formule** `k ∈ FORMULES` avec
`k ≤ v`, tiré du catalogue (5.2), relabellé puis **vérifié** :

- nombre de tickets et de tickets physiques ;
- garantie de couverture (« Multi en k ») ;
- `p_couverture(S, B)` — identique pour toutes les formules, puisque chaque
  système valide couvre les mêmes combinaisons ;
- grilles en dossards et preuve du vérificateur.

Les formules sont listées par `k` décroissant (le moins de tickets d'abord). Aucune
n'est « recommandée » : le pronostic, c'est la sélection et ses bases ; les
systèmes sont des façons de la couvrir. Une forme absente du catalogue est omise
avec l'avertissement `systeme_absent_du_catalogue`. Aucun coût, aucun prix, aucun
multiplicateur n'est calculé ni affiché.

**Chevaux imposés** : l'utilisateur peut forcer l'inclusion de chevaux (ses
convictions). Ils sont ajoutés à `S` avant l'étape 2 de 4.1 ; l'écran affiche
la perte de `p_couverture` due à ce choix (différence avec le pronostic libre à la
même taille).

**Sélection personnelle** : l'utilisateur peut aussi saisir sa propre sélection ;
le modèle l'évalue (6.1) et propose les **1 à 2 échanges** qui augmentent le plus
`p_couverture`.

### 4.4 Ce que le pronostic ne fait pas

- Il ne parle **pas d'argent** : ni mise, ni budget, ni coût, ni gain, ni rapport.
- Il ne choisit **pas** la taille de la sélection : c'est l'utilisateur.
- Il n'utilise **aucun** indice de valeur (abandonné, annexe E).
- Il n'utilise **aucune** donnée de presse ni de consensus.

### 4.5 Comparateurs (évaluation uniquement)

Consultables à part dans l'écran Multi (« Autres méthodes — hypothèses non
validées ») et journalisés pour la section 8. Jamais proposés par défaut.

| id | Définition | Statut |
|---|---|---|
| `B0` | `taille` chevaux tirés au hasard (graine fixée par la clé de course → reproductible) ; **backend seulement**, journalisé, jamais affiché ni porté en Dart | V1 |
| `B1` | les `taille` chevaux de **cote la plus basse** (le marché) | V1 |
| `M1` | méthode 1 du document (4.6) | V1 |
| `M2` | méthode 2 du document (4.7) | **Reportée (D2)** |

Le critère de réussite de `modele` se mesure **contre B1** (le marché) ; M1 et B0
sont des repères.

### 4.6 Méthode 1 — « Multi-Sélection de 12 chevaux » (`M1`, comparateur, taille 12)

Principe du document : **un cheval par critère**, selon le résultat de la dernière
course, puis complément par un classement de référence (ici : le classement du
moteur, ordre de `p_gagnant`).

Pools (chaque cheval avec `dernier_rang` appartient à **un seul** pool) :

| Pool | Condition |
|---|---|
| `top3` | rang ∈ {1, 2, 3} |
| `r4`, `r5`, `r6` | rang = 4, 5, 6 |
| `queue` | rang ≥ 7, ou `0` (non placé), ou incident `D`, `T`, `A` et assimilés (voir backend 7.4) |
| (hors pools) | `dernier_rang is None` (inédit) ; incident `NR` : on remonte à la dernière course réellement courue |

Règles, dans l'ordre :

1. **`top3`** → prendre le cheval à **allocation maximale** ; égalité → le **plus
   délaissé** (cote la plus haute).
2. **`r4`** → allocation **minimale** (« épreuve la moins bien dotée ») ;
   égalité → le plus délaissé.
3. **`r5`** → idem 2.
4. **`r6`** → idem 2.
5. **`queue`** → les **2** chevaux d'allocation minimale (égalité → le plus
   délaissé) ; puis, parmi les restants du pool, **1** cheval d'allocation
   **maximale** (égalité → **cote la plus basse**).
6. **Complément** jusqu'à 12 : les chevaux dans l'ordre du classement de référence,
   hors déjà sélectionnés et hors chevaux sans rang (« abandonnés » dans les
   tableaux du document).

**Pool vide** : le critère ne produit aucun cheval, et son créneau est repris par le
complément (« 4ᵉ cheval : aucun » dans les exemples du document).

**Variantes (drapeaux, tous `False` par défaut)** :

- `nota_cote_la_plus_basse` : appliquer la « Nota » du document (« si un critère ne
  détecte aucun cheval, choisir le cheval dont la cote était la plus basse »).
  **Désactivée par défaut** : elle contredit les exemples traités.
- `taille` : 12 par défaut ; toute autre valeur est une **extension** à marquer.

**Allocation manquante** : exclure le cheval des critères d'allocation ; si tout
le pool est sans allocation, départager par la cote seule et ajouter
l'avertissement `allocation_manquante`.

**Ambiguïtés du document et décisions** :

| # | Ambiguïté | Décision par défaut | Où tester |
|---|---|---|---|
| 1 | Nota « cote la plus basse » vs exemples (« aucun ») | Suivre les exemples ; drapeau `nota_cote_la_plus_basse` | Annexe B.1 |
| 2 | Le texte de la dernière étape répète « 2 moins dotés + 1 plus doté » après le complément | Répétition d'impression de l'étape 5 | Annexe B.1 |
| 3 | « Cote » = cote du jour ou de la dernière course ? | **Cote du jour** — reproduit l'exemple 2 (5 départage 5/11/15) ; la cote de la dernière course n'est pas dans l'API | Annexe B.3 |
| 4 | « Allocation » : de la **dernière course** du cheval | Dernière course | Annexe B.1 |
| 5 | « Abandonné » dans « Class. Paris Turf » | Exclu du complément, pas des critères 1-5 (exemple 1 : le n°10 « abandonné » est choisi au critère 5) | Annexe B.1 |

Dans les fixtures de l'annexe B, le complément utilise le classement « Paris Turf »
du document (`rang_pt`) pour reproduire les exemples ; en production, c'est le
classement du moteur.

### 4.7 Méthode 2 — « 10 chevaux, presse + indice de forme » (`M2`) — REPORTÉE (D2)

Conservée pour mémoire et pour une éventuelle version future. **Non construite en
V1** : elle repose sur des citations de presse (exclues du calcul par le PRD §5) et
n'est pas évaluable en backtest. Si elle est réintroduite, ce sera comme comparateur
affiché à part, alimenté **uniquement** par des captures confirmées par
l'utilisateur, jamais par un proxy présenté comme M2.

Entrées : `citations[num] ∈ ℕ` (nombre de citations parmi 6 médias, 2 chevaux cités
par média, soit 0 à 6) ; `liste_forme` : liste ordonnée des numéros, **du haut au
bas** (« Indice de forme »).

Partition : `fort = {c ≥ 3}`, `moyen = {1 ≤ c ≤ 2}`, `zero = {c = 0}`.

1. 2 chevaux de `fort`, en parcourant `liste_forme` **par le haut**.
2. 1 cheval de `fort` (non déjà pris), en parcourant **par le bas**.
3. 2 chevaux de `moyen`, en parcourant **par le bas**.
4. Dans `zero` : **2 par le haut**, puis **3 par le bas**.
5. Complément jusqu'à 10 : en parcourant `liste_forme` **par le haut**, d'abord les
   chevaux de `zero` non pris, puis (si nécessaire) n'importe quel cheval non pris.

Une étape qui trouve moins de chevaux que demandé en prend autant qu'il y en a.
Ambiguïté du complément (« chevaux manquants » vs « non cités ») : règle
`zero_puis_tous`, qui satisfait les deux exemples (annexe B.2).

## 5. Systèmes réduits

### 5.1 Formalisation

Une **sélection** `S` (|S| = v chevaux), des **bases** `B ⊆ S` (0 à 3), une taille
de ticket `k ∈ {4, 5, 6, 7}`. Un **ticket** est un sous-ensemble de `S` de taille
`k` contenant `B`. Un système est **valide** si, pour toute combinaison de 4
chevaux `A` de `S` contenant `B`, il existe un ticket qui contient `A`.

Réduction exacte : poser `v' = v − b`, `k' = k − b`, `t' = 4 − b`. Les tickets sont
`B ∪ T` où `T` est un bloc de taille `k'` de `S \ B`. Le problème devient un
**covering design** `C(v', k', t')` sur les associés.

- `b = 3` : `t' = 1` → `N = ⌈v' / k'⌉` (forme close).
- `b = 0, k = 4` : formule intégrale, `N = C(v, 4)`.
- Autres cas : générateur général (5.2).

### 5.2 Générateur — jamais de grilles recopiées

Ne **pas** recopier les ~90 pages de grilles du document : elles contiennent des
coquilles (voir 5.3) et ne sont pas optimales. Générer, puis **vérifier**.

Paliers, appliqués dans l'ordre :

1. **Formes closes** (`t' = 1`, `k = 4`).
2. **Solveur exact** (MILP/HiGHS via `scipy.optimize.milp`, ou OR-Tools CP-SAT)
   quand `C(v', k')` ≤ ~5 000 blocs candidats, avec limite de temps (défaut 20 s).
3. **Glouton + recherche locale** (recuit simulé, plusieurs graines) pour le reste,
   limite de temps paramétrable ; le meilleur résultat est conservé.
4. *(optionnel, hors ligne)* amorçage depuis un dépôt public de couvertures
   (La Jolla Covering Repository, DOI Zenodo 10.5281/zenodo.10779736).
   **Licence non précisée sur la page consultée** : vérifier avant de redistribuer.

Le générateur est **lourd** : il tourne **uniquement sur la machine de
développement**, en script autonome (`scripts/generer_catalogue_multi.py`, dépendances
épinglées, lancé par `uv`), jamais sur le serveur ni sur l'appareil. Il écrit le
**catalogue de référence** `fixtures/multi_catalogue.json` (en-tête : version = sha256
des entrées, empreinte des règles utilisées, versions SciPy/HiGHS ; entrées par
`(v', k', t')`, blocs sur les indices `0..v'-1`, tous vérifiés), puis le copie à
l'identique dans `backend/app/engine/multi/` et `mobile/assets/`. À l'exécution,
rien ne génère de système (spine AD-7).

**Vérificateur (obligatoire, jamais contourné)** :

```python
def verifier_couverture(selection, bases, tickets) -> PreuveCouverture:
    requis = [frozenset(a) for a in combinations(selection, 4) if set(bases) <= set(a)]
    non_couverts = [a for a in requis if not any(a <= set(t) for t in tickets)]
    return PreuveCouverture(nb_requis=len(requis), nb_non_couverts=len(non_couverts),
                            multiplicite_max=..., multiplicite_min=...)
```

Un système n'est **jamais** renvoyé avec `nb_non_couverts > 0`. `C(20, 4) = 4 845` :
la vérification est instantanée, y compris sur l'appareil.

**Relabellement** : une seule correspondance, identique en Python et en Dart — les
chevaux non-bases de la sélection, triés par `top4` décroissant, puis `p_gagnant`
décroissant, puis dossard croissant, prennent les indices `0..v'-1` ; chaque ticket
est formé des bases et du bloc correspondant. Tout système relabellé est revérifié
avant affichage. Une forme absente du catalogue ne reçoit aucun système
(avertissement `systeme_absent_du_catalogue`). Il n'y a **pas** de table de cache.

**Vérification d'un système saisi** : l'utilisateur peut saisir un système trouvé
ailleurs (journal, site) ; le module le passe au vérificateur, indique la couverture
réelle (garantie tenue ou non, combinaisons manquantes) et, s'il existe dans le
catalogue un système valide plus petit pour les mêmes `v`, `b`, `k`, le propose.

### 5.3 Tailles de référence et objectif de qualité

L'annexe A reprend le catalogue du document. **Critère d'acceptation** : pour
chaque entrée de l'annexe, le générateur renvoie un système **vérifié** de taille
**inférieure ou égale** à celle du document, sauf coquilles documentées
(3 bases + 14 chevaux : « 13 » imprimé, 14 nécessaires). Contrôle exact effectué à la
rédaction (MILP) sur 18 cas :

| Cas | Document | Optimum / meilleur connu |
|---|---|---|
| Sans base, 8 chevaux, tickets de 5 | 21 | **20** (optimal) |
| 1 base + 12 chevaux, tickets de 7 (v = 13) | 20 | **≤ 15** trouvé (optimum entre 14 et 15) |
| 2 bases, v = 12, tickets de 6 | 10 | **9** |
| 2 bases, v = 11, tickets de 7 | 6 | **5** |
| 2 bases, v = 12, tickets de 7 | 7 | **6** |
| 2 bases, v = 13, tickets de 7 | 8 | **7** |
| 3 bases + 14 chevaux, tickets de 4 (v = 17) | « 13 » (coquille) | **14** (la grille imprimée a bien 14 lignes) |
| 11 autres cas contrôlés (ex. 9/5 → 30 ; 9/6 → 12 ; 1 base 9/4 → 56) | = optimum | = |

La littérature récente établit `C(12, 6, 4) = 41` (arXiv:2607.23766, 25 juillet
2026) : le document donne 42 grilles pour « 12 chevaux, tickets de 6 ».

### 5.4 Options de systèmes

Pour une sélection `S` et des bases `B`, le module renvoie **toutes** les formules
valides (`k ≤ v`), pas une seule, sans aucun champ monétaire :

| Champ | Sens |
|---|---|
| `k` | taille des tickets (4 = intégrale en combinaisons) |
| `nb_tickets`, `nb_tickets_physiques` | `⌈nb_tickets / 4⌉` tickets physiques |
| `garantie` | niveau garanti « Multi en k » |
| `p_couverture` | probabilité de couverture (section 6) |
| `tickets` | grilles : liste de listes de dossards |
| `preuve` | sortie du vérificateur |

Texte d'UI pour `garantie` : « Si les 4 premiers sont dans votre sélection (bases
comprises), au moins un ticket de **k** chevaux les contient tous les quatre. »

### 5.5 Ce que la réduction change — et ne change pas

> Contexte théorique conservé de la v2. Depuis la v3, rien de financier n'est
> calculé ni affiché ; la conclusion utile reste : **un système réduit ne rend pas
> le pronostic meilleur**, il couvre la même sélection avec moins de tickets.

Sous la règle de prix documentée (2), un ticket en `k` paie `R4(w) / C(k, 4)` pour
chaque combinaison `w` qu'il contient, et coûte `MISE_UNITAIRE_EUR`. Donc, par
combinaison couverte, **le coût et le gain sont identiques** quelle que soit la
formule. Conséquences :

- Si les 4 premiers sont équiprobables parmi les `C(v, 4)` combinaisons,
  l'espérance par euro est **identique** pour la formule intégrale et pour tout
  système réduit (vérifié numériquement : 9 chevaux → 0,09259 ; 12 chevaux →
  0,02357 pour intégrale, 113×5, 42×6 et 27×7, en unités de R7 par euro).
- Ce qui change : le **budget**, la **probabilité de toucher au moins un rapport
  faible** vs un rapport élevé, la **variance**.
- **Nuance** : avec des probabilités hétérogènes, **la répartition du recouvrement
  compte** — un système réduit couvre certaines combinaisons 2-3 fois et d'autres
  une seule. Plusieurs systèmes optimaux de même taille existent souvent ; choisir
  celui (et le relabelling) qui place les recouvrements multiples sur les
  combinaisons les plus probables selon le modèle est un **levier sans coût de
  taille**. **V1.5** (après la V1, section 12). Le recouvrement pondéré par la
  valeur est abandonné avec l'indice de valeur (annexe E).

### 5.6 Systèmes mixtes (tickets de 5 et de 6) — V2

Le document propose des systèmes mixtes (ex. 8 chevaux : 10 tickets de 5 + 3 de 6,
« garantie Multi en 6 minimum »). **Hors V1** : généraliser le vérificateur à un
niveau de garantie (« toute combinaison couverte par un ticket de taille ≤ g ») et
le générateur à plusieurs tailles de blocs.

## 6. Évaluation, indice de confiance et explications

### 6.1 Probabilité de couverture et distribution du nombre de chevaux capturés

On note `X = |top4 ∩ S|`, le nombre des 4 premiers présents dans `S`.

- `P_ens(A)` = probabilité que l'ensemble `A` de 4 chevaux soit exactement le
  top-4 (sans ordre) = somme, sur les 24 permutations de `A`, de la probabilité
  ordonnée de Plackett-Luce/Harville du moteur (backend 7.9-7.10), **sur le champ
  complet** (chevaux réels + partants virtuels).
- **Énumération exacte** sur tous les ensembles du champ (n ≤ 20 → ≤ 4 845
  ensembles × 24 ordres) — **pas** sur le pool réduit aux 7-8 meilleurs utilisé par
  `combinatoire.py` pour le quarté. Vectoriser (numpy côté Python ; boucles simples
  suffisent en Dart à cette taille).
- `p_couverture(S, B) = Σ_{A ⊆ S, B ⊆ A} P_ens(A)` ;
  `P(X = j) = Σ_A P_ens(A) · 1[|A ∩ S| = j]`.
- **Contrôles** : `Σ_A P_ens(A) = 1` à 1e-9 ; `E[X] = Σ_{i ∈ S} top4_i` (recoupe
  7.10) ; avec des forces égales, `X` suit la loi hypergéométrique
  `C(v,j)·C(n−v,4−j) / C(n,4)`.
- **Modèle d'ordre** : Harville (celui du moteur). Harville est connu pour
  surestimer les favoris aux places 2-4 ; l'écart se mesure par la calibration de
  `p_couverture` (section 8), il ne se devine pas.

### 6.2 Entropie de la course

`H = −Σ_i p_gagnant_i · ln(p_gagnant_i)` sur le champ complet, normalisée par
`ln(n)` → `H_norm ∈ [0, 1]` (0 : un seul cheval concentre tout ; 1 : course
totalement ouverte). Affichée comme « course fermée / ouverte » et utilisée par
l'indice de confiance (6.4).

### 6.3 Indice de valeur — **abandonné (v3)**

Retiré du module avec toute notion d'argent (D ter) : il reposait sur les rapports
Multi et sur une retenue inconnue. La définition de la v2 est conservée pour mémoire
en **annexe E** ; rien n'en est calculé, journalisé ni affiché.

### 6.4 Indice de confiance du pronostic (D ter — remplace le verdict de la v2)

L'indice qualifie le pronostic ; il ne dit **pas** de jouer ou de passer.

Entrées :

- `p = p_couverture(S, B)` du pronostic (taille choisie, bases actives) ; sans base
  active, c'est la probabilité que l'arrivée soit dans la sélection ;
- `H_norm` (6.2) ;
- la **fragilité des données** : proportion `f` des chevaux de `S` inédits ou à
  historique court, et présence d'un favori fragile (meilleur `p_gagnant` avec
  drapeau `historique_court`, `inedit` ou terrain inconnu majoritaire).

Calcul, en trois temps :

| Étape | Règle |
|---|---|
| 1. Niveau de départ | `elevee` si `p ≥ seuil_confiance_elevee[v]` ; `moyenne` si `p ≥ seuil_confiance_moyenne[v]` ; sinon `faible` |
| 2. Course ouverte | si `H_norm ≥ seuil_course_ouverte` : niveau abaissé d'un cran |
| 3. Données fragiles | si `f ≥ seuil_donnees_fragiles` ou favori fragile : niveau abaissé d'un cran, avertissement fort |

Le niveau ne descend jamais sous `faible`. Libellés d'écran : « confiance élevée /
moyenne / faible ».

- **Seuils par taille.** `p_couverture` croît mécaniquement avec la taille : une
  sélection de 18 chevaux sur 18 partants contient toujours l'arrivée. Les seuils
  de probabilité sont donc donnés **par taille `v`** (une valeur pour chaque taille
  de 4 à 20) ; sans cela, une grande sélection serait toujours en confiance
  élevée. Le niveau est toujours affiché avec la taille.
- **Seuils réglables** (`seuil_confiance_elevee`, `seuil_confiance_moyenne`,
  `seuil_course_ouverte`, `seuil_donnees_fragiles`) : paramètres de l'utilisateur
  dans les réglages, comme les autres paramètres du moteur (PRD FR-20), persistés
  et réinitialisables. **Valeurs par défaut fixées par le pilote** (8.4), affichées
  « provisoires » jusque-là.
- **Raisons** (codes, D6) jointes à tout indice : `p_couverture` et taille,
  `H_norm` (« course ouverte »), nombre de chevaux à historique court ou inédits
  dans la sélection (« données fragiles »), partants non analysés, favori fragile.
- **Course non éligible** (section 2) : pas d'indice ; en mode exploration, l'indice
  est calculé avec la mention « course non support du Multi ».
- **Garde-fou** (PRD SM-C3) : on ne règle jamais les seuils pour produire plus de
  « confiance élevée ». Seule la calibration de `p_couverture` (8.2, PRD SM-4), qui
  fonde l'indice, juge.

### 6.5 Explications (le « pourquoi »)

Chaque élément du pronostic porte ses explications (`Explication(code, params)`,
rendues en FR, puis EN après le MVP) :

| Élément | Exemples de codes | Paramètres |
|---|---|---|
| Cheval retenu | `retenu_top4`, `retenu_par_echange` | `top4`, rang modèle, hausse de `p_couverture` |
| Cheval écarté (les 3 plus proches de la sélection) | `ecarte_top4_faible`, `ecarte_donnees_fragiles` | `top4`, drapeaux de transparence |
| Base candidate | `base_candidate` | `top4`, tickets économisés par formule, couverture perdue |
| Système d'une formule | `systeme_formule` | `k`, `nb_tickets`, `nb_tickets_physiques` |
| Contribution d'un cheval | `contribution` | baisse de `p_couverture` si on le retire |
| Indice de confiance | voir 6.4 (`couverture`, `course_ouverte`, `donnees_fragiles`, `favori_fragile`, …) | — |
| Données | `cote_manquante`, `cotes_du`, `allocation_manquante` | heure des cotes, dossard |

La **contribution** de chaque cheval de la sélection (baisse de `p_couverture` s'il
est retiré) est calculée et affichée : elle montre quels chevaux « portent » le
pronostic. Une **carte de couverture** (combinaisons couvertes 1×, 2×, 3×) est
disponible pour chaque système.

### 6.6 Simulation de non-partant

Pour chaque cheval de la sélection : ce que devient chaque ticket s'il est déclaré
non-partant (requalification, section 2), et la nouvelle `p_couverture`. En cas de
non-partant réel de dernière minute, le pronostic est **recalculé sur
l'appareil** et l'écran indique ce qui change.

### 6.7 Sorties de l'évaluation

Taille ; indice de confiance (niveau, raisons, seuils provisoires ou non) ;
pronostic (sélection, bases candidates et bases actives) ; `p_couverture` ;
distribution de `X` (chevaux capturés, 0 à 4) ; `H_norm` ; contributions ; chevaux
écartés ; pour chaque formule : nombre de tickets, tickets physiques, garantie,
grilles et preuve. Aucun montant, aucun rapport.

## 7. Données, schéma et journalisation

Nouvelles tables (SQLAlchemy, mêmes conventions que 6.3, accès uniquement via
`data/repository.py`, un seul écrivain par table, migrations **Alembic** — spine
AD-10, AD-13). Une course est identifiée par sa clé PMU (date, réunion, course) ;
toute heure est en UTC avec décalage (spine AD-12). Les noms techniques
`recommandation_multi`, `resultat_recommandation`, `recommandation_consultee` et la
route `/multi/recommandation` sont conservés ; ils désignent le pronostic. Seule la
table locale du pronostic retenu est renommée (`pronostic_retenu`) :

```
multi_course                        -- écrivain : job d'ingestion/finalisation
  course_id (FK, unique), est_course_support (bool), nb_partants_declares,
  arrivee_json  (top-5 avec ex-aequo, NULLABLE tant que non finalisée), finalisee
  -- v3 : plus de colonnes de rapports (ni rapport_en4..en7, ni source_rapports)

recommandation_multi                -- une ligne par pronostic journalisé (modèle ou comparateur) ; écrivain : job de journalisation
  id, course_id (FK), strategie, version_strategie, parametres_json,
  donnees_a (timestamp UTC : instant des données utilisées — AVANT le départ),
  selection_json (choix ordonnés avec rôle et explications), bases_json, taille,
  confiance (NULLABLE : "elevee" | "moyenne" | "faible", seulement pour "modele"),
  seuils_provisoires (bool),
  empreinte_entrees (sha256 des entrées), version_catalogue, empreinte_regles,
  version_moteur_multi (fixtures/multi_versions.json), mode ("live" | "backfill"),
  degrade (bool), cree_le
  UNIQUE (course_id, strategie, version_strategie, mode, taille)   -- taille = une des tailles de référence

echec_journal_multi                 -- écrivain : job de journalisation
  id, course_id (FK), raison, survenu_le

resultat_recommandation             -- rempli à la finalisation de la course ; écrivain : job de finalisation
  recommandation_id (FK, unique), nb_captures (0..4),
  arrivee_dans_selection (bool)        -- selon la section 2 (ex-aequo, arrivée dégradée) ; aucun coût ni gain

performance_strategie               -- écrivain : commande d'import du backtest
  id, strategie, version_strategie, periode_debut, periode_fin, effectif,
  metriques_json, constantes_figees_le, importe_le
```

**Règles** :

- **Immuabilité** : une `recommandation_multi` n'est jamais modifiée ni supprimée ;
  une correction crée une nouvelle `version_strategie`.
- **Pas de fuite temporelle** : toute recommandation en mode `backfill` ne lit que
  les données **antérieures** à `donnees_a` (historique du cheval jusqu'à la veille
  de la course, cotes finales seulement si le mode les déclare disponibles). Un test
  automatique le vérifie (9, test 14).
- **Ingestion de l'arrivée** : idempotente ; `NULL` tant que la course n'est pas
  finalisée (PRD FR-17) ; ne jamais inventer une arrivée. Les **rapports Multi ne
  sont pas ingérés** (v3). Les appels supplémentaires à la source PMU entrent dans
  le même arbitrage de fréquence que l'ingestion quotidienne (PRD §9.3, question
  ouverte 6).
- Mode `live` : le job quotidien journalise, pour la course support, la
  pronostic `modele` (aux **tailles de référence** fixées au pilote) et les
  comparateurs `M1`, `B0`, `B1`, **avant** le départ. Il ne démarre qu'**après** le
  pilote (8.4). Un échec (source indisponible, course support introuvable, départ
  décalé) est journalisé comme tel (`non_journalise`, raison) et la course est
  exclue de l'évaluation de façon comptée. Un non-partant survenu après la
  journalisation est traité par les règles de requalification (section 2), sans
  réécrire l'entrée.
- **Constantes figées** : toute constante dérivée des données (quantiles de niveau,
  réglages du moteur) est figée avant la période de test ; sa date figure dans le
  rapport d'évaluation. L'heure des cotes du comparateur `B1` est alignée sur celle
  du modèle, ou l'écart est déclaré.
- **Sur l'appareil** (V1 mono-utilisateur, sans compte, rien n'est envoyé au
  serveur) : l'action **« Je retiens ce pronostic »** (une par course, remplaçable
  jusqu'à l'heure de départ, figée ensuite) enregistre dans le cache local
  (table `pronostic_retenu`, ex-`jeu_retenu`, et `recommandation_consultee`) le
  pronostic du modèle **et** le pronostic retenu, tel quel ou modifié (taille,
  sélection, bases actives, formule consultée, heure des données), conservés
  **90 jours**. L'export des grilles propose de retenir le pronostic sans le faire
  à la place de l'utilisateur. Après finalisation de la course, le **débrief**
  affiche pour les deux « N chevaux capturés sur 4 » et « arrivée dans la
  sélection : oui / non », selon les règles du pari (ex-aequo, arrivée dégradée) ;
  une correction de l'arrivée après finalisation met le débrief à jour avec une
  mention. Sans embellissement, sans aucun montant.

## 8. Protocole d'évaluation

### 8.1 Ce qui est mesurable, et avec quelles données

| Stratégie | Backtest historique | Test prospectif |
|---|---|---|
| `modele` | oui (le moteur est reconstructible à `donnees_a`) | oui |
| `B0`, `B1` | oui (B1 : seulement si l'historique des cotes est fiable, sinon `degrade`) | oui |
| `M1` | **partiel** : rang et allocation reconstructibles ; complément par le classement du moteur ; départage par cote `degrade` si cotes historiques douteuses | oui |
| `M1-structure` (critères 1-5 seulement, sans complément) | oui | oui |
| `M2` | non | reportée (D2) |

**Courses utilisables pour la couverture** : toute course avec ≥ 14 partants (pas
seulement la course support) → des dizaines de milliers de courses en historique.
Seule l'arrivée (avec ex-aequo) est nécessaire ; il n'y a plus de volet financier
(v3).

### 8.2 Métriques

- **Principale — calibration de `p_couverture`** (prolongement de PRD SM-1) : score
  de Brier et courbe par tranches ; comparée à la même quantité calculée sur les
  probabilités implicites du marché.
- **Capture** : `nb_captures` moyen (0 à 4) par stratégie, **différence appariée par
  course** contre `B1`, intervalle de confiance bootstrap 95 %, à taille égale.
- `arrivee_dans_selection` (4/4) en proportion, intervalle de Wilson, comparée à
  la loi hypergéométrique attendue pour une sélection aléatoire de même taille.
- **Indice de confiance** : proportion d'arrivées dans la sélection par niveau
  (élevée / moyenne / faible) et par taille ; les niveaux doivent être ordonnés
  (élevée > moyenne > faible), sinon les seuils sont revus au pilote suivant, jamais
  pendant la période de test.
- **Ablation** : `modele` sans l'étape d'échanges (tri par `top4` seul) vs `modele`
  complet — dit si l'optimisation exacte apporte quelque chose.

### 8.3 Règle de décision (aucun seuil d'effet inventé)

Le libellé « hypothèse non validée » d'un comparateur, et la mention « modèle en
cours d'évaluation » du pronostic, ne sont levés que si, sur la **période de
test gelée**, l'intervalle de confiance à 95 % concerné **exclut 0** du bon côté.
Taille minimale : à fixer **après** le pilote qui mesure la variance.

**Garde-fous méthodologiques** :

1. **Gel avant test** : paramètres et version figés avant la période de test.
2. **Découpage temporel** (jamais aléatoire) : développement → validation → test.
3. **Comparaisons multiples** : toutes les stratégies et variantes testées sont
   listées dans le rapport ; correction de Holm si plusieurs sont comparées.
4. **Le hasard n'est pas la référence** : `B1` (le marché) l'est.
5. **Biais de survivance** : les exemples du document sont des succès choisis ;
   ils servent de **tests de non-régression de M1**, pas de preuve.

### 8.4 Pilote

Avant toute période de test : un pilote en mode `backfill` sur une période de
développement, pour (1) mesurer la variance et fixer la taille d'échantillon,
(2) fixer les **valeurs par défaut** des seuils de l'indice de confiance (6.4 :
`seuil_confiance_elevee[v]` et `seuil_confiance_moyenne[v]` par taille,
`seuil_course_ouverte`, `seuil_donnees_fragiles`), les **tailles de référence**
de la journalisation `live` et l'effectif minimal au-delà duquel les performances des comparateurs
s'affichent (toujours avec effectif et intervalle). Ces valeurs sont alors gelées
pour la période de test, dans `fixtures/multi_parametres_pilote.json` (lu par les deux
moteurs et le job de journalisation — spine AD-11). Le harnais tourne d'abord sur la
machine de développement, sur une copie de la base ; ses résultats sont exportés
puis importés en production (`performance_strategie`). **Ordre imposé** : backtest
et pilote → seuils et tailles de référence → journalisation `live`. Le pilote ne dépend pas de la journalisation
`live`.

**Cotes manquantes** : `B1` et la référence marché de SM-4 ne sont pas calculés pour
une course où une cote manque ; la course est exclue de ces mesures, et l'exclusion
est comptée dans le rapport.

## 9. Tests (à porter avec le module)

Tous les tests de `regles`, des stratégies et du pronostic sont purs (sans
réseau ni base). Les cas à entrée/sortie fixes vivent dans
**`fixtures/multi_cases.json`**, chargé par les tests Python **et** Dart (AD-2) ;
tolérance 1e-9 sur les probabilités.

1. **Cohérence du fichier de règles** : `COEF_R7 == {4: 35, 5: 7, 6: 7/3, 7: 1}` ;
   les 4 jeux de rapports de l'annexe B vérifient `r4/r7 == 35`, `r5/r7 == 7`,
   `r6/r7 == 7/3` à 1e-3 (contrôle du document ; rien de monétaire n'est exposé).
2. **Formule intégrale** : `C(n,4)` pour n = 4..19 → 1, 5, 15, 35, 70, 126, 210,
   330, 495, 715, 1001, 1365, 1820, 2380, 3060, 3876 tickets.
3. **Non-partants** : toute la table de requalification de la section 2.
4. **Dead-heat** : ex-aequo 4ᵉ → 2 combinaisons payables, 1 rapport ; ticket qui
   contient les deux → 2 × rapport.
5. **Arrivée dégradée** : les 4 combinaisons de repli dans l'ordre, puis
   remboursement.
6. **Catalogue** (sans SciPy) : pour chaque entrée de l'annexe A, le catalogue
   contient un système vérifié (`nb_non_couverts == 0`) avec `len(tickets) <= N_document`
   (sauf coquilles documentées) ; 3 bases + 14 (v = 17) → exactement 14 ; les copies
   backend et mobile sont identiques octet à octet à l'original ; le relabellement
   donne les mêmes listes de tickets en Python et en Dart.
7. **Vérificateur** : un système auquel on retire un ticket doit échouer ;
   une sélection plus petite que `k` renvoie une erreur explicite ; un système saisi
   non valide est signalé avec ses combinaisons manquantes.
8. **Probabilités** : `Σ_A P_ens(A) = 1` ; `E[X] = Σ top4_i` ; forces égales →
   loi hypergéométrique à 1e-9 ; les partants virtuels entrent dans le champ mais
   jamais dans une sélection.
9. **Pronostic — optimalité** : sur des champs de ≤ 10 chevaux, la sélection de
   4.1 a la même `p_couverture` que l'optimum obtenu par énumération exhaustive ;
   au moins un cas où le tri par `top4` seul n'est pas optimal et où l'étape
   d'échanges le corrige.
10. **Taille et systèmes** : la sélection compte exactement `v` chevaux pour
    chaque `v` de 4 à `min(20, nb_partants_reels)` ; `v < 4`, `v > 20` ou
    `v > nb_partants_reels` → erreur explicite ; `p_couverture` du pronostic non
    décroissante quand `v` augmente ; taille par défaut = dernière utilisée, sinon
    10 ; un système vérifié est listé pour chaque formule `k ≤ v` présente au
    catalogue, avec la même `p_couverture` ; aucune clé monétaire (`cout`, `budget`,
    `multiplicateur`, `mise`, `gain`, `rapport`, `prix`) dans les sorties du moteur
    ni de l'API.
11. **Bases** : toujours 3 candidates (si la sélection a ≥ 3 chevaux), ordonnées par
    `top4` ; aucune active par défaut ; couverture perdue ≥ 0 ; tickets économisés
    ≥ 0 pour chaque formule.
12. **Indice de confiance** : chaque niveau (élevée, moyenne, faible) et chaque
    abaissement (course ouverte, données fragiles, favori fragile) atteint par un
    cas de fixture ; le niveau ne descend jamais sous `faible` ; seuils lus par
    taille ; course non éligible → pas d'indice ; toute sortie porte au moins une
    raison et l'état « provisoire » des seuils.
13. **M1 — exemples** : annexe B.1 et B.3 réconciliée, sélection attendue exacte par
    créneau ; B.3 brute → écart détecté.
14. **Absence de fuite** : une recommandation `backfill` dont `donnees_a` précède la
    course ne change pas si l'on supprime de la base toute donnée postérieure.
15. **Déterminisme** : `selectionner` et le pronostic appelés 2 fois →
    résultat identique (y compris `B0`, côté backend) ; Python et Dart donnent le même
    pronostic et le même indice de confiance sur les cas partagés (probabilités quantifiées à 1e-9).
16. **Langue** : aucune chaîne de libellé dans les sorties du moteur et de l'API ;
    chaque code d'explication a un libellé français dans le catalogue de l'app
    (l'anglais s'y ajoutera après le MVP sans modifier le moteur).

## 10. API (FastAPI) — compléments à la section 8 du backend

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/courses/{id}/multi/eligibilite` | course support ? nb de partants, non-partants |
| POST | `/multi/recommandation` | **le pronostic** à la taille demandée : indice de confiance, sélection, bases candidates, systèmes de toutes les formules, explications |
| POST | `/multi/systemes` | sélection + bases → systèmes vérifiés de toutes les formules (5.4) |
| POST | `/multi/verifier` | système saisi par l'utilisateur → preuve de couverture, système plus petit éventuel |
| POST | `/multi/evaluer` | sélection quelconque (dont celle de l'utilisateur) → `p_couverture`, distribution de `X`, contributions, échanges suggérés |
| POST | `/multi/comparateur` | applique `M1` / `B0` / `B1` → choix + explications, libellé « hypothèse non validée » |
| GET | `/multi/performance` | métriques par stratégie (8.2), filtrables par période |
| POST | `/multi/backtest` | lance un backtest — **construit seulement quand le harnais passe sur un serveur** ; d'ici là, le harnais tourne sur la machine de développement (8.4) |

Aucune route ne reçoit ni ne renvoie de champ monétaire (budget, multiplicateur,
coût, mise, gain, rapport, prix).

**`POST /multi/recommandation`**

```json
{ "course_id": "20261016-R1-C5",
  "taille": 12,
  "bases_actives": [11],
  "chevaux_imposes": [],
  "seuils": { "seuil_confiance_elevee": null, "seuil_confiance_moyenne": null,
              "seuil_course_ouverte": null, "seuil_donnees_fragiles": null } }
```

(`taille` obligatoire, de 4 à 20 ; l'application envoie la dernière taille utilisée,
sinon 10. `seuils` à `null` → valeurs par défaut en vigueur pour cette taille.
Comme `/analyse`, le corps accepte aussi une liste de chevaux saisis à la place de
`course_id`.)

```json
{ "taille": 12,
  "confiance": {
    "niveau": "moyenne",
    "raisons": [ {"code": "couverture", "params": {"p_couverture": 0.31, "taille": 12}},
                 {"code": "course_ouverte", "params": {"h_norm": 0.82}} ] },
  "pronostic": {
    "selection": [
      { "num": 11, "role": "base",
        "explications": [{"code": "base_candidate", "params": {"top4": 0.78}}] },
      { "num": 2, "role": "selection",
        "explications": [{"code": "retenu_top4", "params": {"top4": 0.41, "rang_modele": 3}}] } ],
    "p_couverture": 0.31,
    "distribution_captures": [0.01, 0.06, 0.21, 0.41, 0.31],
    "h_norm": 0.82 },
  "bases_candidates": [
    { "num": 11, "top4": 0.78, "active": true,
      "tickets_economises": {"4": 330, "5": 66, "6": 20, "7": 16}, "couverture_perdue": 0.04 },
    { "num": 2,  "top4": 0.41, "active": false,
      "tickets_economises": {"4": 120, "5": 30, "6": 12, "7": 4}, "couverture_perdue": 0.11 },
    { "num": 5,  "top4": 0.37, "active": false,
      "tickets_economises": {"4": 120, "5": 30, "6": 12, "7": 4}, "couverture_perdue": 0.13 } ],
  "systemes": [
    { "k": 7, "nb_tickets": 11, "nb_tickets_physiques": 3, "garantie": "multi_en_7",
      "p_couverture": 0.31, "tickets": [[11, 2, 5, 8, 14, 17, 3], "…"],
      "preuve": { "nb_requis": 165, "nb_non_couverts": 0 } },
    { "k": 6, "nb_tickets": 22, "nb_tickets_physiques": 6, "garantie": "multi_en_6", "…": "…" },
    { "k": 5, "nb_tickets": 47, "nb_tickets_physiques": 12, "garantie": "multi_en_5", "…": "…" },
    { "k": 4, "nb_tickets": 165, "nb_tickets_physiques": 42, "garantie": "multi_en_4", "…": "…" } ],
  "ecartes": [ { "num": 9, "explications": [{"code": "ecarte_top4_faible", "params": {"top4": 0.06}}] } ],
  "statut_modele": "en_cours_d_evaluation",
  "seuils_provisoires": true }
```

Les valeurs ci-dessus sont **illustratives** (format), pas des résultats. Les
systèmes montrés reprennent les tailles de l'annexe A (le catalogue peut faire
mieux) : 1 base active + 11 autres chevaux (v = 12) → 11 tickets de 7, 22 de 6,
47 de 5, `C(11, 3) = 165` de 4 ; `C(11, 3) = 165` combinaisons requises dans tous
les cas. Les tickets économisés comparent, à v = 12, la sélection sans base (27, 42,
113, 495 tickets) à 1 base pour la base active, et 1 base à 2 bases (7, 10, 17,
45 tickets) pour les candidates inactives.

**Erreurs** : `422` si `taille < 4`, `taille > 20` ou `taille > nb_partants_reels`,
`bases ⊄ selection`, `|bases| > 3`, `|selection| > 20`, dossard inconnu, `k < 4`,
`k > 7`. Réponses typées par schéma Pydantic (AD-4), jamais `__dict__`.

## 11. Application mobile (compléments à la section 7 du cahier mobile)

### 11.1 Écran « Multi » (accessible depuis une course éligible)

Un seul écran, de haut en bas, sans aucun montant :

1. **Taille de la sélection** : sélecteur de 4 à 20 (borné au nombre de partants
   réels), par défaut la dernière taille utilisée, sinon 10. Toute modification
   relance le calcul sur l'appareil et mémorise la taille.
2. **Indice de confiance** : « confiance élevée / moyenne / faible » pour cette
   taille, avec ses raisons. Mention « seuils provisoires » tant que le pilote n'a
   pas fixé les valeurs par défaut, et « modèle en cours d'évaluation » tant que la
   section 8 ne conclut pas.
3. **Sélection** : chaque cheval avec son dossard, sa probabilité d'être dans les
   4, sa contribution et ses explications (aucun badge de value : la value reste
   sur l'écran Résultats) ; les 3
   chevaux écartés les plus proches, avec la raison.
4. **Bases (chevaux les plus probables)** : les 3 bases candidates proposées par le modèle,
   chacune avec sa probabilité d'être dans les 4, les tickets économisés et la
   couverture perdue, activables/désactivables (aucune active au premier affichage).
5. **Systèmes et grilles** : pour la sélection et ses bases actives, toutes les
   formules (tickets de 7 à 4) avec nombre de tickets, tickets physiques et
   garantie ; formule affichée par défaut : Multi en 7 ; les grilles **en dossards** ; export texte copiable (PRD FR-21) ;
   carte de couverture.
6. **Évaluation** : probabilité que l'arrivée soit dans la sélection
   (`p_couverture`), distribution du nombre de chevaux capturés (0 à 4), course
   ouverte / fermée.
7. **Mes choix** : imposer des chevaux, **marquer un non-partant** (hors ligne
   compris), saisir sa propre sélection (évaluée, avec échanges suggérés), ou
   saisir un système trouvé ailleurs (vérifié) ; bouton **« Je retiens ce
   pronostic »**. Après un non-partant, l'écran montre à part ce que deviennent les
   tickets du pronostic déjà retenu (requalification).
8. **Autres méthodes** (repliée par défaut) : M1, B1 — « hypothèses non validées »,
   avec leurs performances mesurées dès qu'il y en a.
9. **Mentions obligatoires** : « Couverture garantie — pas un gain garanti » ;
   « L'outil ne place aucun pari » ; rappel de jeu responsable (PRD §5).

### 11.2 Langue (D6)

Le MVP est **en français**. L'affichage en anglais, au choix de l'utilisateur, est
une exigence transverse de **toute l'application**, planifiée **après le MVP**
(PRD §6.2, §8). Dès le MVP, les explications arrivent du moteur sous forme de
codes (6.5), déclarés dans `fixtures/multi_codes.json`, et sont rendues par une
simple table Dart code → phrase française ; elle migrera vers l'outillage de
traduction de Flutter quand l'anglais arrivera, sans reprendre le moteur.

### 11.3 Hors ligne (hippodrome)

Le pronostic complet (4.1-4.3), `p_couverture`, l'indice de confiance, les explications,
le vérificateur et les règles sont des **fonctions pures portées en Dart**
(`mobile/lib/engine/multi/`), à parité avec Python par `fixtures/multi_cases.json`.
Le générateur ne tourne pas sur l'appareil : l'app embarque la copie
`mobile/assets/multi_catalogue.json` du catalogue de référence (5.2), pour
`v' ≤ 20`, `k' ∈ [1, 7]`, `t' ∈ [1, 4]`, chaque entrée **vérifiée**. L'application
relabelle et revérifie localement. Elle calcule **toujours** le pronostic
elle-même, avec le contexte Multi de la course (éligibilité, état de l'évaluation,
seuils provisoires ou non) reçu du backend avec les partants et mis en cache ; elle
n'appelle pas `/multi/recommandation`. Le pronostic retenu et le pronostic du modèle
consulté sont stockés dans `hippique_cache.db` (version 2, tables
`pronostic_retenu` et `recommandation_consultee`) et conservés **90 jours** ; la
dernière taille utilisée et les seuils de l'indice sont des réglages
(`shared_preferences`) (spine AD-6, AD-9). Si une
combinaison manque au catalogue, elle est exclue des options (et non calculée à la
volée), avec l'avertissement `systeme_absent_du_catalogue`.

## 12. Questions ouvertes et risques

| # | Sujet | Statut |
|---|---|---|
| 1 | Formules, jours de Quinté+, seuil de 14 partants, règle des non-partants, arrivée dégradée (prix unitaire et rapports : non affichés) : le document date de 2001-2002 | **Vérifier sur pmu.fr avant de figer `regles.py`** |
| 2 | Mécanique du **Flexi** absente du document | À documenter depuis la règle PMU actuelle ; hors V1 |
| 3 | Champ « course support » et arrivée avec ex-aequo dans la source PMU (les rapports Multi ne sont plus nécessaires) | À découvrir dans `pmu_client.py` |
| 4 | Source des **cotes historiques** pour le backtest (sémantique de `cotes` dans open-pmu-api inconnue) | Tant que non clarifié : B1 et le départage M1 sont `degrade` en backfill ; sans effet sur `modele` |
| 5 | Contenus Paris Turf / Geny : **propriétaires** | Rien n'est automatisé ni redistribué ; M2 reportée |
| 6 | « long champ » / « Longchamp » : notion citée par l'utilisateur, **absente du document** | À définir avant d'être spécifiée |
| 7 | Valeurs par défaut des seuils de l'indice de confiance (par taille) et tailles de référence de la journalisation | Fixées par le pilote (8.4) |
| 8 | Affichage en anglais (D6) — toute l'application, **après le MVP** | Calendrier à fixer (PRD question ouverte 11) ; le module Multi y est prêt dès le MVP (codes d'explication) |
| 9 | Choix du système parmi les équivalents (5.5) ; systèmes mixtes (5.6) ; M2 | V1.5 / V2 |
| 10 | Licence du dépôt de couvertures | Vérifier avant d'embarquer des fichiers tiers |
| 11 | Hypothèses de la v3 : taille par défaut 10 (sinon la dernière utilisée) ; aucune base active au premier affichage ; libellés « confiance élevée / moyenne / faible » ; seuils de probabilité par taille, provisoires jusqu'au pilote ; formule affichée par défaut Multi en 7 ; bases nommées « chevaux les plus probables » | **Confirmé par le porteur de projet le 2026-10-18** ; reste `[ASSUMPTION]` : indice calculé sur `p_couverture(S, B)` avec les bases actives |
| 12 | `value` du moteur affichée par cheval dans la sélection ? | **Tranché par le porteur de projet le 2026-10-18** : aucun badge de value dans le Multi, qui ne parle que de la probabilité d'être dans les 4 premiers ; la value reste sur l'écran Résultats |

## 13. Plan de développement

**Prérequis bloquant (PRD §9.5)** : vérifier les règles du pari sur pmu.fr et les
dater dans `regles.py` avant toute autre étape.

**Incrément 1 — décider** (étapes 1 à 5) ; **incrément 2 — évaluer** (étapes 6 à
10, dans l'ordre : le pilote précède la journalisation `live`).

1. **`engine/multi/regles.py` + tests 1-5** (pur, sans données).
2. **Vérificateur + générateur** (formes closes → MILP → glouton/recuit), tests 6-7,
   rapport d'écart avec l'annexe A ; **catalogue** généré hors ligne, versionné dans
   `fixtures/`, puis copié à l'identique dans le backend et l'app.
3. **`p_couverture` exacte, distribution de `X`, entropie** + test 8, fixtures
   partagées Python/Dart.
4. **Pronostic `modele`** : sélection à la taille choisie (4.1), bases candidates
   (4.2), systèmes de toutes les formules (4.3), indice de confiance (6.4),
   explications (6.5) + tests 9-12, 15-16 — en Python **et** en Dart.
5. **Écran mobile** (11.1-11.3), hors ligne, pronostic retenu et débrief local.
6. **Comparateurs** M1, B0, B1 + test 13.
7. **Schéma** (section 7) par migrations Alembic, ingestion de l'arrivée (pas des
   rapports).
8. **API** (section 10) ; les endpoints de l'incrément 1 sont livrés avec lui.
9. **Harnais de backtest** (section 8) + test 14, sur la machine de développement ;
   **pilote** (8.4) et import des résultats en production ; puis mode `live` en
   **écriture seule**. `/multi/backtest` attend le passage du harnais sur un serveur.
10. **Rapport d'évaluation** : stratégies testées, période gelée, résultats, décision.

Les étapes 1 à 5 ne dépendent d'**aucune donnée nouvelle** : elles livrent un
pronostic utilisable à partir de ce que le moteur calcule déjà.

---

## Annexe A — Catalogue relevé dans le document (références de taille)

Lecture à partir de scans : **valeurs à valider par le vérificateur, pas à
recopier.** Colonnes : `v` = nombre de chevaux de la sélection (bases incluses) ;
`N` = nombre de grilles du document ; `k` = chevaux par grille.

**Sans base (`t' = 4`)**

| k | (v → N) |
|---|---|
| 4 | (5 → 5), (6 → 15), (7 → 35) |
| 5 | (8 → 21), (9 → 30), (10 → 51), (12 → 113) |
| 6 | (7 → 5), (9 → 12), (11 → 37), (12 → 42), (13 → 72) |
| 7 | (12 → 27), (13 → 40), (14 → 57), (15 → 82), (16 → 112) |
| mixte 5+6 | (8 → 10×5 + 3×6), (9 → 19×5 + 5×6), (10 → 38×5 + 7×6), (11 → 46×5 + 16×6) |

**1 base** (garantie : la base + 3 autres chevaux de la sélection à l'arrivée)

| k | (v → N) |
|---|---|
| 4 | (6 → 10), (7 → 20), (9 → 56) |
| 5 | (12 → 47), (14 → 88), (15 → 91) |
| 6 | (10 → 12), (12 → 22), (15 → 55), (16 → 57) |
| 7 | (12 → 11), (13 → 20), (15 → 25), (16 → 31), (19 → 48) |
| mixte 5+6 | (8 → 6×5 + 2×6), (9 → 12×5 + 3×6), (10 → 15×5 + 3×6), (11 → 28×5 + 4×6), (12 → 35×5 + 6×6), (13 → 45×5 + 8×6) |

**2 bases** (garantie : les 2 bases + 2 autres chevaux)

| k | (v → N) |
|---|---|
| 4 | (8 → 15), (9 → 21), (10 → 28), (11 → 36), (12 → 45) |
| 5 | (8 → 6), (11 → 12), (12 → 17), (15 → 26), (16 → 33), (18 → 43) |
| 6 | (10 → 6), (12 → 10), (16 → 21), (18 → 28), (20 → 36) |
| 7 | (11 → 6), (12 → 7), (13 → 8) |

**3 bases** (garantie : les 3 bases + 1 autre cheval)

| k | (v → N) |
|---|---|
| 4 | (15 → 12), (16 → 13), (17 → « 13 » **coquille, 14 réels**), (18 → 15) |
| 5 | (10 → 4), (12 → 5), (13 → 5), (15 → 6), (17 → 7), (19 → 8) |
| 6 | (10 → 3), (12 → 3), (14 → 4), (18 → 5) |

Exemple d'usage donné par le document (p. 30-31) : 8 chevaux, 21 grilles de 5 →
**6 tickets physiques** (21 / 4 arrondi au-dessus) ; il faut jouer le système
**dans son intégralité** pour que la couverture soit effective.

## Annexe B — Fixtures de test (comparateurs M1 et M2)

Convention : `cote` = cote du jour (ordre seul important), `null` = « non cité ».
`rang_pt` = rang du « Classement Paris Turf » (`null` = « abandonné »), utilisé
**uniquement** pour reproduire les exemples du document.

### B.1 Méthode 1 — exemple 1 (lundi 22 octobre, 5ᵉ course, 18 partants) — **cohérent**

```yaml
chevaux:  # num: [allocation_derniere, derniere_course, cote, rang_pt]
  1:  [80000,  "D", null, 10]    2:  [80000,  1,  3.5,  4]
  3:  [100000, 2,   null, 9]     4:  [55000,  3,  null, 12]
  5:  [200000, 5,   26,   7]     6:  [80000,  "D", null, 14]
  7:  [110000, 0,   40,   null]  8:  [160000, 8,  36,   null]
  9:  [110000, 8,   null, 13]    10: [200000, 8,  7,    null]
  11: [350000, 2,   19,   1]     12: [90000,  "A", 25,  2]
  13: [170000, "D", 40,   15]    14: [170000, 4,  15,   11]
  15: [110000, 3,   35,   5]     16: [200000, 3,  33,   8]
  17: [85000,  4,   null, 6]     18: [110000, 5,  2.75, 3]
creneaux_attendus:
  top3: 11          # {2,3,4,11,15,16} -> plus forte allocation : 350 000
  r4:   17          # {14 (170 000), 17 (85 000)} -> moins dotée
  r5:   18          # {5 (200 000), 18 (110 000)}
  r6:   null        # aucun
  queue_bas: [1, 6] # allocations 80 000 ; 1 et 6 (2 plus bas, ex-aequo sans conflit)
  queue_haut: 10    # plus forte allocation du pool restant : 200 000
  complement: [12, 2, 15, 5, 16, 3]     # classement PT hors sélectionnés et hors "abandonnés"
ensemble_attendu: [11, 17, 18, 1, 6, 10, 12, 2, 15, 5, 16, 3]
arrivee: [2, 17, 3, 5]            # -> nb_captures = 4
rapports_F: {en4: 22050, en5: 4410, en6: 1470, en7: 630}
```

Remarque : le texte du document écrit « 1-6-7-8-9-10-11 et 12 » pour le pool
`queue` ; la ligne 11 est une coquille (le n°11 est 2ᵉ), c'est le n°13 (D).

### B.2 Méthode 2 — exemples A et B (M2 reportée ; fixtures conservées)

```yaml
A:  # lundi 8 octobre, 5e course, 16 partants
  citations: {6: 6, 10: 6}                      # 6 médias, tous : 6 et 10
  liste_forme: [6, 8, 10, 13, 15, 3, 7, 16, 11, 5, 14, 2, 1, 4, 12, 9]
  creneaux_attendus:
    s1: [6, 10]
    s2: []
    s3: []
    s4_haut: [8, 13]
    s4_bas: [9, 12, 4]
    complement: [15, 3, 7]
  ensemble_attendu: [6, 10, 8, 13, 9, 12, 4, 15, 3, 7]
  arrivee: [6, 10, 13, 4]
  rapports_F: {en4: 13860, en5: 2772, en6: 924, en7: 396}

B:  # vendredi 26 octobre, 5e course, 14 partants
  choix_medias: {paris_turf: [13, 4], france_antilles: [13, 12], france_soir: [13, 12],
                 "3615_turf": [13, 12], geny_courses: [4, 13], turf_derniere: [3, 12]}
  citations: {13: 5, 12: 4, 4: 2, 3: 1}         # à recalculer depuis choix_medias (test)
  liste_forme: [3, 4, 8, 10, 9, 6, 5, 7, 12, 11, 1, 13, 14, 2]
  creneaux_attendus:
    s1: [12, 13]          # par le haut de la liste : 12 (rang 9) avant 13 (rang 12)
    s2: []
    s3: [4, 3]            # par le bas : 4 avant 3
    s4_haut: [8, 10]
    s4_bas: [2, 14, 1]
    complement: [9]
  ensemble_attendu: [13, 12, 4, 3, 8, 10, 2, 14, 1, 9]
  arrivee: [12, 4, 2, 9]
  rapports_F: {en4: 1050, en5: 210, en6: 70, en7: 30}
```

Remarque : le texte du document cite « le 7, le 14 et le 1 » pour `s4_bas` mais sa
sélection finale contient le **2** ; la liste de forme confirme `[2, 14, 1]`
(coquille d'impression sur « 7 »).

### B.3 Méthode 1 — exemple 2 (samedi 20 octobre, 6ᵉ course, 18 partants) — **réconcilié**

Le tableau imprimé est **incohérent avec le texte explicatif** du document :
le texte désigne `{5, 11, …}` comme pool « 3 premiers » et le n°10 comme
appartenant au pool de queue, alors que le tableau donne 10 → « 3 » et 11 → « 8 » ;
il dit « seul le n°13 a terminé 6ᵉ » alors que le tableau donne aussi 6 au n°12.
En **permutant les lignes 10 et 11** (10 → 8 ; 11 → 3) et en classant le n°12 dans
la queue, le texte du document est reproduit exactement (pool de queue
`{2,3,4,6,7,8,9,10,12,14,16,17,18}`, égalité 5/11/15 à 65 000 tranchée par la cote
du jour 32/1 du n°5). **Fixture réconciliée = cas de test ; le tableau brut = cas
« écart documenté »** (le test vérifie que l'écart est détecté, pas qu'il passe).

```yaml
chevaux_reconcilies:  # num: [allocation_derniere, derniere_course, cote, rang_pt]
  1:  [65000,  5,  34,   12]   2:  [100000, 9,  2.25, 3]
  3:  [270000, 0,  45,   1]    4:  [30000,  9,  null, 10]
  5:  [65000,  3,  32,   9]    6:  [50000,  0,  84,   null]
  7:  [65000,  10, 62,   7]    8:  [100000, 7,  39,   4]
  9:  [35000,  "A", 5,   11]   10: [100000, 8,  62,   8]      # corrigé : 8 (imprimé : 3)
  11: [65000,  3,  2,    2]    12: [70000,  8,  34,   14]     # 11 corrigé : 3 ; 12 corrigé : queue
  13: [65000,  6,  19,   6]    14: [100000, 10, 30,   null]
  15: [65000,  3,  4.75, 5]    16: [40000,  0,  null, null]
  17: [65000,  0,  125,  13]   18: [45000,  0,  null, 15]
creneaux_attendus:
  top3: 5            # {5, 11, 15} à 65 000 -> égalité -> le plus délaissé : 5 (32/1)
  r4:   null
  r5:   1
  r6:   13
  queue_bas: [4, 9]  # 30 000 et 35 000
  queue_haut: 3      # 270 000
  complement: [11, 2, 8, 15, 7, 10]
ensemble_attendu: [5, 1, 13, 4, 9, 3, 11, 2, 8, 15, 7, 10]
arrivee: [11, 2, 9, 1]    # -> nb_captures = 4
rapports_F: {en4: 13650, en5: 2730, en6: 910, en7: 390}
```

## Annexe C — Pseudocode de référence

```python
def modele_selectionner(chevaux, champ, taille, bases):
    """4.1 — chevaux : réels et partants ; champ : réels + virtuels (pour P_ens)."""
    candidats = sorted((c for c in chevaux if c.est_partant),
                       key=lambda c: (-c.top4, -c.p_gagnant, c.num))
    S = list(bases) + [c.num for c in candidats if c.num not in bases][:taille - len(bases)]
    p = p_couverture(champ, S, bases)
    while True:
        meilleur = None
        for sortant in [n for n in S if n not in bases]:
            for entrant in [c.num for c in candidats if c.num not in S]:
                S2 = [entrant if n == sortant else n for n in S]
                p2 = p_couverture(champ, S2, bases)
                cle = (p2, -entrant, -sortant)
                if p2 > p + 1e-12 and (meilleur is None or cle > meilleur[0]):
                    meilleur = (cle, S2, p2)
        if meilleur is None:
            return S, p
        _, S, p = meilleur


def m1_selectionner(chevaux, classement, taille=12, nota_cote_la_plus_basse=False):
    INF = float("inf")
    choix, pris = [], set()

    def ok(c):  return c.est_partant and c.num not in pris
    def delaisse(c):  return c.cote if c.cote is not None else INF       # plus haut = plus délaissé
    def alloc_basse(pool):   # moins bien dotée ; égalité -> plus délaissé
        return sorted(pool, key=lambda c: (c.derniere_allocation, -delaisse(c)))
    def alloc_haute(pool):   # mieux dotée ; égalité -> cote la plus basse
        return sorted(pool, key=lambda c: (-c.derniere_allocation, delaisse(c)))

    top3 = [c for c in chevaux if ok(c) and c.dernier_rang in {"1", "2", "3"}]
    r = {n: [c for c in chevaux if ok(c) and c.dernier_rang == str(n)] for n in (4, 5, 6)}
    queue = [c for c in chevaux if ok(c) and est_queue(c.dernier_rang)]   # >=7, "0", D/T/A et assimilés

    def prendre(pool, ordre, creneau, code, n=1):
        pool = [c for c in pool if c.num not in pris and c.derniere_allocation is not None]
        for c in ordre(pool)[:n]:
            pris.add(c.num); choix.append(Choix(c.num, "selection", [Explication(code, {"creneau": creneau})]))

    prendre(top3, alloc_haute, "top3", "m1_top3_allocation_max")
    for n in (4, 5, 6):
        prendre(r[n], alloc_basse, f"r{n}", "m1_rang_allocation_min")
    prendre(queue, alloc_basse, "queue_bas", "m1_queue_allocation_min", n=2)
    prendre(queue, alloc_haute, "queue_haut", "m1_queue_allocation_max")

    for num in classement:                 # complément par le classement de référence
        if len(choix) >= taille: break
        c = par_num(chevaux, num)
        if c and ok(c) and a_un_rang(c):
            pris.add(num); choix.append(Choix(num, "selection", [Explication("m1_complement", {})]))
    return choix


def m2_selectionner(citations, liste_forme, taille=10, complement="zero_puis_tous"):
    """REPORTÉE (D2) — conservée pour mémoire."""
    haut = list(liste_forme)
    fort  = [n for n in haut if citations.get(n, 0) >= 3]
    moyen = [n for n in haut if 1 <= citations.get(n, 0) <= 2]
    zero  = [n for n in haut if citations.get(n, 0) == 0]
    choix = []
    def prendre(src, n, par_le_bas=False):
        seq = reversed(src) if par_le_bas else src
        got = [x for x in seq if x not in choix][:n]
        choix.extend(got)
    prendre(fort, 2); prendre(fort, 1, par_le_bas=True)
    prendre(moyen, 2, par_le_bas=True)
    prendre(zero, 2); prendre(zero, 3, par_le_bas=True)
    if len(choix) < taille:
        prendre(zero, taille - len(choix))
        prendre(haut, taille - len(choix))
    return choix
```

## Annexe D — Décodeur de musique (spécification minimale)

- Entrée : chaîne `musique` brute du champ `participants` (backend 4.2).
- Sortie : liste d'`(annee_ou_None, rang_brut, lettre_discipline)` de la plus
  récente à la plus ancienne.
- Jeton de course : `rang_brut` (chiffre 1-9, `0` = non placé, ou lettre
  d'incident `D`, `T`, `A`, …) suivi d'**une lettre minuscule** de discipline
  (`p` plat, `h` haies, `s` steeple, `c` cross, `a` attelé, `m` monté) ; les années
  peuvent apparaître entre parenthèses (`(23)`).
- Les lettres d'incident inconnues → pool `queue` + avertissement ; `NR` (non-partant
  noté) est ignoré et on remonte à la course suivante.
- **Non négociable** : valider sur des chaînes **réelles** capturées. La chaîne
  d'exemple du backend (`1h5s2h1s2s1s2s0p161h`) contient `0p161h` dont la
  segmentation est ambiguë : tant qu'elle n'est pas levée, le rang de la dernière
  course vient en priorité de `performances-detaillees`, la musique ne servant que
  de recoupement.
- Le même décodeur sert à afficher la musique en clair dans les explications
  (« 1er en haies, 5e en steeple… »), en FR ou EN.

## Annexe E — Indice de valeur (v2) — **abandonné**

> Abandonné en v3 (D ter) avec toute notion d'argent : il dépendait des rapports
> Multi réels (qui ne sont plus ingérés) et d'une retenue inconnue. Conservé pour
> mémoire ; **rien n'en est calculé, journalisé ni affiché**. Texte de la v2 :

Hypothèse : le rapport « Multi en 4 » d'une arrivée `w` est proche de la mise
divisée par la probabilité que le **public** attribue à `w`, à la retenue près.

```
R4_proxy(w) = (1 − τ) · MISE_UNITAIRE_EUR / P_marche_ens(w)
P_marche_ens : même énumération (6.1), appliquée aux probabilités implicites des cotes
               du jour, overround retiré (backend 7.11).
indice_valeur(S, tickets) = Σ_w  P_modele(w) · n(w) / (C(k,4) · N)  ·  1 / P_marche_ens(w)
```

- `n(w)` = nombre de tickets contenant `w` ; `N` = nombre de tickets.
- `τ` (retenue) est **inconnu** : **ne pas le coder en dur.** On affiche
  `indice_valeur` seul (« 1,00 = équivalent au marché »), et on **estime `τ_eff`**
  à partir des rapports réels journalisés (section 7).
- Le public du Multi ne mise pas comme le public du gagnant : l'indicateur n'est
  utile que **calibré** sur nos rapports réels. Libellé : « indice de valeur estimé
  (hypothèse) ». **Il n'entre ni dans la recommandation ni dans le verdict** (D0,
  4.4) tant que cette calibration n'est pas faite.
