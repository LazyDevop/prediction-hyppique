# Addendum — prediction-hyppique

Contenu apporté par le porteur de projet qui appartient à un document en aval (architecture / solution design) plutôt qu'au PRD, ou qui documente une décision déjà tranchée dont il faut garder la trace. Le PRD (`prd.md`) reste la référence pour le *quoi* ; ce document et les cahiers des charges cités restent la référence pour le *comment*.

## A. Contexte d'origine — discipline de validation itérative

Le projet n'est pas parti d'un plan initial figé mais d'une démarche de démontage puis reconstruction validée à chaque étape :

- Une première proposition d'architecture Flutter, produite par un autre outil, a été **rejetée après examen** plutôt qu'acceptée en surface — cinq défauts l'auraient rendue inutilisable ou trompeuse (voir section D ci-dessous, repris comme contraintes testables dans le PRD §4).
- Le moteur de calcul a été construit et **vérifié numériquement** à chaque étape dans un prototype HTML autonome, pas seulement "testé à l'œil" — sommes de probabilités égales à 1, comportement des cas limites vérifié (cas de test repris au cahier backend §9).
- L'échelle de terrain a été revue **trois fois** au fil de vraies fiches de courses et de vérifications croisées avec France Galop, jusqu'à découvrir qu'un "Super Lourd" présenté comme officiel n'existait pas.
- Le niveau des courses a connu la même révision : ce qui semblait être "Classe 1/2/3/4" s'est révélé être une échelle par lettre A à G, confirmée par trois sources indépendantes — une "Breeders Course" censée expliquer la catégorie B s'est avérée être une invention, alors que la vraie catégorie B existait sous un autre nom.

**Implication pour l'équipe de développement** : cette discipline de vérification croisée (formule → cas de test → vérification contre une source primaire) doit continuer à s'appliquer à tout ajustement futur du moteur, pas seulement à sa conception initiale. Le cahier backend §7 le formalise déjà : "Toute modification de ces constantes doit être un choix explicite, pas une divergence accidentelle de portage."

## B. Spécification normative du moteur — pointeur, pas duplication

Les constantes et formules exactes du moteur (terrain, niveau, pondération de récence, incidents, formule de note, lissage bayésien, outsiders virtuels, Plackett-Luce, Harville, Kelly, combinatoire) sont intégralement spécifiées dans `cahier_des_charges_backend_hippique.md`, section 7. Ce document fait foi pour toute question de formule ou de constante — le PRD (`prd.md` §4.3-4.5) n'en donne que le comportement observable et les invariants testables (sommes de probabilités, ordre de grandeur des cas limites), volontairement sans redonner les valeurs numériques pour éviter toute divergence entre deux copies.

Les 9 cas de test de référence (cahier backend §9) doivent être portés à l'identique en Python (`tests/test_scoring.py`, `tests/test_combinatoire.py`) et en Dart (mêmes cas, même précision epsilon — cahier mobile §5.2, §9), condition de la NFR de parité fonctionnelle (PRD §8).

## C. Source de données PMU — détails techniques (architecture)

Référence complète : `cahier_des_charges_backend_hippique.md`, sections 3 et 4. Points à ne pas perdre en conception d'architecture :

- Base d'API : `https://offline.turfinfo.api.pmu.fr/rest/client/{id}/programme/...` (miroir `online.turfinfo.api.pmu.fr` existant). `{id}` = numéro de version client (7 et 61 observés fonctionnels, à re-tester si un endpoint cesse de répondre).
- `numPmu` **n'est pas un identifiant stable de cheval** — valable uniquement pour une course donnée. La clé de rapprochement inter-courses doit être le nom du cheval normalisé (majuscules, espaces normalisés), avec le risque résiduel d'homonymes documenté (PRD Open Question 7) plutôt que traité comme résolu.
- `handicapPoids` est exprimé en dixièmes de kg (ex. 720 = 72,0 kg) — **à vérifier l'unité exacte avant usage**, ne pas supposer.
- `handicapValeur` observé fréquemment à 0.0 sur des fiches réelles où la valeur n'est probablement pas calculée plutôt que réellement nulle — ne jamais interpréter 0.0 comme un signal.
- Aucun champ d'état du terrain (pénétrométrie) dans `performances-detaillees` — limitation connue et acceptée (cahier backend §10), traiter comme `NULL`/neutre (PRD FR-5), jamais deviner.
- `NON_PLACE` dans le statut d'arrivée signifie vraisemblablement "hors du top 5-6 affiché", pas un incident — ne jamais le mapper automatiquement sur un code incident A/RO/RR sans vérification supplémentaire ; seul `DISQUALIFIE` correspond avec certitude à un incident réel (code D).
- Dérivation du niveau depuis l'allocation (cahier backend §7.2) : la case catégorie/lettre est le plus souvent vide sur les fiches réelles — c'est le chemin normal à gérer, pas un cas de repli rare. Une dérivation par quantiles est proposée mais reste à calibrer sur un premier jeu de données réel (PRD Open Question 5). Le libellé "Réclamer"/"À Réc." doit être traité comme un signal de niveau modeste (~1.4) distinct du générique "Cond." (~2.0).

## D. Erreurs identifiées dans une proposition d'architecture antérieure — à ne pas reproduire

Une précédente proposition d'architecture Flutter (générée par un autre outil, rejetée après examen — voir section A) contenait cinq défauts, repris comme contraintes testables dans le PRD (§4.3, FR-7 ; §4.4, FR-9) mais détaillés ici pour l'architecte :

1. **Coefficient de récence potentiellement inversé** — vérifier explicitement que la pondération la plus forte s'applique à C1 (performance la plus récente), pas à la plus ancienne.
2. **"Value bet" cosmétique** — une détection basée sur un simple seuil de score sans comparaison réelle à la cote n'est pas de la value, c'est une étiquette. La formule exacte (`probabilité × cote − 1`) est non négociable.
3. **Indexation des cotes désynchronisée du classement** — si les cotes sont stockées dans un tableau séparé indexé sur le classement trié plutôt que sur l'identité du cheval, la value calculée est attribuée au mauvais cheval. Toujours porter la cote comme propriété du cheval lui-même.
4. **Erreurs de compilation Dart classiques** : `(x).sqrt()` n'existe pas sur `double` — utiliser `sqrt(x)` de `dart:math` ; `Icons.horse` n'existe pas dans Material Icons ; une variable de `Consumer` ne doit pas être référencée hors de son `builder` (ex. dans un `floatingActionButton` au même niveau).
5. **Niveau de la course cible jamais utilisé dans le calcul** — le niveau du jour doit intervenir dans `c_niv` (ratio avec le niveau de chaque performance passée), pas seulement être stocké sans effet.

## E. Décisions techniques et alternatives écartées

- **Riverpod plutôt que Provider** pour la gestion d'état mobile — Riverpod apporte une meilleure testabilité et évite certains pièges de cycle de vie que Provider peut poser. Si l'équipe est déjà à l'aise avec Provider, ce n'est pas bloquant, mais Riverpod reste le choix par défaut pour un projet neuf (cahier mobile §5.1).
- **Moteur dupliqué en Dart plutôt qu'un simple appel API** pour le calcul — décision directement dérivée de la contrainte offline (PRD §4.6) : le calcul étant déterministe et léger (aucun appel à un modèle d'IA dans le calcul lui-même, seule l'extraction d'image en a besoin), le dupliquer est raisonnable et évite une dépendance réseau sur le chemin critique.
- **`dio` plutôt que `http`** pour le client HTTP mobile — gestion des timeouts et retries plus confortable pour un usage en connexion incertaine (cahier mobile §9).
- **Extraction vision toujours côté backend, jamais depuis le client mobile avec une clé embarquée** — une clé API dans un binaire Flutter est extractible par rétro-ingénierie de l'APK/IPA ; c'est le backend qui doit détenir le secret (cahier mobile §6.3). Repris comme critère d'acceptation testable au PRD FR-18.
- **SQLite plutôt que PostgreSQL** pour démarrer côté backend — zéro configuration, fichier unique, largement suffisant pour un usage personnel avec quelques milliers de courses par an ; migration vers PostgreSQL envisageable uniquement si le volume ou un besoin d'accès concurrent l'impose (cahier backend §6.4). SQLAlchemy utilisé pour ne pas coupler le code au moteur choisi.
- **Pattern adaptateur pour l'accès PMU** (`pmu_client.py`) — la seule partie du code qui connaît le format de réponse du PMU ; objectif explicite : si l'API change de format ou est remplacée par l'extraction vision en repli permanent, seul ce fichier change (cahier backend §5.1). Élevé au rang de contrainte produit au PRD §9.3, pas seulement de préférence d'architecture.

## F. Plans de développement suggérés (source)

Les deux cahiers des charges proposent chacun un plan de développement séquencé (backend §11, mobile §10) : port du moteur d'abord (testable en isolation, sans dépendance réseau), puis stockage local et écrans de saisie manuelle, puis client API une fois le backend disponible, puis import photo en dernier (le plus optionnel en usage trackside), puis calibration une fois un historique réel accumulé. Ces séquences restent la référence pour la planification epics/stories (`bmad-create-epics-and-stories`), le PRD n'en reprend que les capacités (§4), pas l'ordonnancement.
