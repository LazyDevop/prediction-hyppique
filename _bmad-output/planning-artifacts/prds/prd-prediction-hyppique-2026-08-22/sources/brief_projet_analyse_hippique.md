# Brief projet — Outil d'analyse hippique

## 1. Le problème

Un parieur qui veut analyser une course avant de jouer dispose aujourd'hui
essentiellement de sites de pronostics (Geny, Bilto, ZEturf, CanalTurf) et
d'opérateurs de paris. Tous partagent la même limite structurelle :

- Ils donnent un **pronostic en prose**, formulé par un expert nommé
  ("la solution se trouve probablement au second échelon avec...") — un
  jugement qualitatif, pas une probabilité chiffrée.
- Aucun ne met explicitement en regard une probabilité estimée et la cote du
  marché — donc aucun ne dit jamais *pourquoi* un cheval serait sous-coté,
  seulement *lequel* jouer.
- Aucun ne propose de combinaisons de paris optimisées et classées par
  probabilité — au mieux une suggestion en une phrase.
- Aucun ne dit combien miser.
- L'historique consultable gratuitement est bridé (5 dernières performances
  sans compte, sur les sites vérifiés) — la profondeur est réservée aux
  abonnés.

Le problème n'est donc pas un manque d'information sur les courses — elle
est abondante — c'est un manque d'outil qui transforme cette information en
décision chiffrée, reproductible et actionnable.

## 2. Ce qui différencie

| Ce que font les sites existants | Ce que fait cet outil |
|---|---|
| Pronostic qualitatif d'expert | Probabilité chiffrée par cheval (modèle Plackett-Luce / Harville) |
| Aucune comparaison explicite à la cote | Value = probabilité × cote − 1, affichée par cheval |
| Une suggestion de combinaison en une phrase | 10 types de paris (couplé à quinté, ordre/désordre, couplé placé, 2 sur 4) classés par probabilité, en dossards |
| Aucune indication de mise | Mise suggérée par Kelly fractionné, sur bankroll paramétrable |
| Modèle opaque, non réglable | Moteur transparent : chaque coefficient (récence, poids, âge, terrain...) est visible et modifiable par l'utilisateur |
| Historique bridé sans compte (5 perfs) | Historique profond accessible (jusqu'à 2004 via les sources agrégées), sans abonnement |
| Pronostic jamais recorrigé publiquement | Modèle calibrable sur données réelles à mesure que l'historique s'accumule |

**Faiblesses à assumer honnêtement**, pas à cacher dans le brief :
- Le modèle est aveugle à l'information tactique et humaine que les
  tipsters captent (changement de driver de dernière minute, intention de
  course rapportée par un entraîneur). Aucune donnée chiffrée ne remplace
  ça aujourd'hui.
- Aucune preuve à ce stade que les probabilités du modèle sont mieux
  calibrées que le jugement d'expert des pronostiqueurs. Seul un backtest
  sur un volume significatif de courses le établira (voir section 5).

## 3. Périmètre V1

- **Géographie** : France uniquement (courses PMU, `pays=FRA`). Pas de
  paris internationaux dans cette version.
- **Disciplines** : plat, trot (attelé et monté), obstacle — les trois
  disciplines déjà couvertes par le moteur et les sources de données.
- **Hors périmètre explicite** : le PMUC (Pari Mutuel Urbain Camerounais,
  distinct du PMU français) n'est pas couvert — le produit analyse des
  courses françaises, consommées depuis n'importe quelle géographie, pas
  des courses camerounaises.
- Aucune fonctionnalité de placement de pari automatisé, quelle que soit la
  version — l'outil calcule et informe, il n'agit jamais sur un compte de
  jeu.

## 4. Qui ça sert, et modèle économique

**Cible V1** : le parieur individuel qui analyse ses courses avant de jouer,
pas encore les cercles ou professionnels (segment envisageable en phase 2,
avec une relation commerciale différente — vente directe plutôt
qu'abonnement grand public).

**Principe retenu pour la coupure gratuit/payant** : ne pas mettre le
scoring de base en gratuit et les combinaisons en payant — le scoring
(détection de value) est le vrai différenciateur face aux sites de
pronostics, le donner gratuitement dilue l'avantage. La coupure proposée se
situe plutôt sur l'**actionnable** :
- Gratuit : classement et indicateur de value par cheval (l'accroche : "ce
  cheval semble sous-coté").
- Payant : mise suggérée (Kelly), combinaisons précises en dossards sur les
  10 types de paris, historique profond au-delà des dernières performances.

**Format tarifaire** : encore ouvert, mais un modèle à l'usage ou par
crédits est probablement mieux adapté qu'un abonnement mensuel fixe classique
(10-30€) — la consommation de courses hippiques se fait par pics (un
Quinté+ du dimanche, une réunion précise), pas au quotidien ; un abonnement
fixe fait payer les semaines sans usage.

**Point de vigilance réglementaire, à trancher avant de figer ce modèle** :
l'opérateur du projet est basé au Cameroun, qui a son propre cadre légal sur
les jeux d'argent (loi n°2015/012 du 16 juillet 2015 et ses textes
d'application, éventuellement révisés depuis — à vérifier sur une source
primaire à jour). Ce cadre cible structurellement les opérateurs qui
collectent des mises, pas les outils d'analyse qui n'en collectent jamais —
mais cette lecture doit être confirmée par un avocat camerounais avant de
lancer un modèle payant, en particulier parce que le produit pointe vers des
courses françaises (PMU) plutôt que camerounaises (PMUC), une situation qui
n'a pas d'équivalent tout tracé.

## 5. Critères de succès

**Critère primaire — calibration, pas ROI.** Un ROI positif sur peu de
courses est peu fiable (variance élevée des résultats de courses). Le test
à privilégier, mesurable plus tôt : sur un échantillon d'au moins quelques
centaines de courses avec résultat connu, la calibration du modèle
(quand il annonce 20 % de chances à un ensemble de chevaux, gagnent-ils
environ une fois sur cinq ?) doit être mesurablement meilleure que celle
de la probabilité implicite du marché (1/cote). Mesurable par un score de
Brier ou une courbe de calibration par tranches de probabilité. En dessous
de quelques centaines de courses, aucune conclusion n'est fiable, dans un
sens comme dans l'autre.

**Critère secondaire, directionnel seulement.** ROI simulé positif sur les
paris à value détectée — à ne présenter que couplé à sa taille
d'échantillon, jamais comme preuve isolée.

**Aucun seuil chiffré (type "+X % vs marché") n'est fixé à ce stade** — ce
serait une précision inventée avant d'avoir lancé le calibrage. Ce seuil
sera posé une fois les premiers résultats de calibration disponibles (voir
document backend, section calibration).

**Côté utilisateur**, l'indicateur retenu n'est pas la rétention brute
(revient chaque semaine) ni la recommandation (indicateur retardé) mais un
changement de comportement mesurable : la proportion des mises
effectivement placées par l'utilisateur sur des chevaux signalés "value"
par le modèle, suivie dans le temps. Un utilisateur qui continue à jouer
ses habitudes malgré le signal de l'outil n'est pas un succès, même s'il
revient chaque dimanche.

## 6. Structuration — bootstrap, pas levée dans l'immédiat

Développement en solo ou très petite équipe recommandé pour cette phase,
pour une raison précise et documentée plutôt que par prudence générale :
**la dépendance actuelle à des sources de données non autorisées par le
PMU** (voir section 7). Ce risque grandit avec la traction du produit — plus
d'utilisateurs signifie plus de requêtes, plus de visibilité, plus de
probabilité d'être bloqué. Lever des fonds aujourd'hui reviendrait à vendre
une promesse construite sur une fondation encore fragile.

**Jalon de bascule vers une levée envisageable**, conditionné aux deux
éléments suivants réunis :
1. Le calibrage (section 5) démontre un avantage prédictif réel et mesuré,
   pas supposé.
2. Une source de données légitime est sécurisée — ou au minimum, un plan
   crédible pour y parvenir (accord commercial, ou dépendance réduite grâce
   à l'historique déjà accumulé en base propre).

## 7. Risque principal à documenter explicitement

**Aucune des deux sources de données du backend n'est autorisée par le
PMU** :
- L'API technique du PMU (`turfinfo.api.pmu.fr`) est non officielle, non
  documentée, appelée avec un user-agent générique ("personal project") —
  aucun accord écrit n'existe, une demande d'autorisation posée par un
  développeur tiers sur le forum officiel du PMU n'a jamais reçu de réponse
  claire.
- `open-pmu-api`, utilisée pour le backfill historique, est un projet tiers
  non affilié au PMU, construit lui-même sur les mêmes données non
  officielles.
- Un durcissement des mécanismes anti-bot du PMU a été documenté comme en
  cours depuis fin 2024 — un signal cohérent avec un risque croissant, pas
  décroissant, dans le temps.

**Conséquence en cas de coupure** : perte de l'ingestion automatisée
quotidienne du jour au lendemain. Le repli existant (extraction de fiches
par image ou PDF) reste fonctionnel mais nettement plus lent — un
utilisateur devrait saisir ou importer manuellement chaque course plutôt
que de la voir préremplie.

Ce risque doit apparaître comme une ligne à part dans le brief, pas comme
une mention en passant — c'est le facteur qui conditionne directement la
recommandation de la section 6.
