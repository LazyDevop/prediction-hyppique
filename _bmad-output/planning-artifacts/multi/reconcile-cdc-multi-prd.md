# Réconciliation — cahier des charges « Module Multi » vs PRD, architecture et code existant

*Document source analysé : `cahier_des_charges_module_multi.md` (fourni par le porteur de projet le 2026-10-17, pas encore versionné dans `docs/`).*
*Documents cibles : `prds/prd-prediction-hyppique-2026-08-22/prd.md`, `briefs/brief-prediction-hyppique-2026-08-17/brief.md`, `architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`, `epics.md`, et le code de `backend/app/engine/` et `mobile/lib/engine/`.*

## Angle retenu (porteur de projet, 2026-10-17)

> **Pour cette course, le modèle me dit si je joue le Multi, avec quelle sélection
> et quelles bases, quel système, et pourquoi.**

Cinq questions, une seule autorité (**le modèle**). Ce cadrage sert de filtre à tout ce
qui suit : une exigence du cahier Multi qui ne sert aucune des cinq questions est
reportée ou retirée ; une question à laquelle le cahier ne répond pas est un écart.

**Verdict global** : le cahier Multi est rigoureux (règles, vérificateur, protocole
d'évaluation, anti-fuite temporelle) et s'appuie naturellement sur le moteur existant
(Harville Top4 → `p_hit`). Mais il a été écrit autour des **méthodes du document de
2001 (M1/M2)**, alors que l'angle met le **modèle** aux commandes. Trois questions de
l'angle sur cinq ne sont pas traitées (« si je joue », « quelles bases »,
« pourquoi » pour une sélection issue du modèle), et deux points heurtent des
règles déjà posées (non-goal presse du PRD, convention de nommage de l'architecture).
Aucun écart ne remet en cause la faisabilité.

---

## A. Décisions à prendre (avec recommandation)

| # | Décision | Recommandation | Pourquoi |
|---|---|---|---|
| **D0** | La mise fait-elle partie du module Multi ? | **Non en V1** : le coût du système est affiché, aucune mise ni multiplicateur n'est recommandé (pas de Kelly Multi). | Retiré explicitement de l'angle. Kelly sur un système de N tickets n'a de sens qu'avec un rapport estimable — or l'indice de valeur (§6.2 du cahier) n'est pas calibré. À rouvrir quand il le sera. |
| **D1** | Qui décide la sélection : le modèle ou M1/M2 ? | **Le modèle.** La sélection recommandée vient des probabilités du moteur. M1, M2 et les références B0/B1 deviennent des **comparateurs** du protocole d'évaluation (§8), consultables à part avec le libellé « hypothèse non validée », jamais la recommandation par défaut. | C'est l'angle. C'est aussi la promesse du brief : une décision chiffrée et reproductible, pas une règle de 2001. |
| **D2** | M2 (citations de presse) reste-t-il ? | **Hors recommandation, et hors V1.** Garder M2 dans le cahier comme stratégie de comparaison future (captures confirmées uniquement), mais ne construire ni `/extraction/presse` ni `CitationsProvider` en V1. | Le PRD §5 et §6.2 excluent la presse/le consensus du calcul (« si réintroduit, affiché à part, jamais mélangé »). M2 n'est par ailleurs pas évaluable en backtest (cahier §8.1). |
| **D3** | Comment le modèle dit « je joue / je passe » ? | Un **verdict explicite par course** fondé sur : `p_hit` du meilleur système pour le budget, coût, et l'entropie de la course (course ouverte vs fermée). **Seuils réglables** par l'utilisateur (comme les autres paramètres, FR-20), **valeurs par défaut fixées après le pilote**, pas avant. | Le cahier ne traite pas cette question. Ne pas inventer de seuil : même posture que le brief §5 et le PRD SM-1. |
| **D4** | Comment le modèle choisit les bases ? | Recommander 0 à 3 bases parmi les chevaux de plus forte probabilité Top4, en affichant **l'arbitrage** : coût économisé vs couverture perdue (`p_hit` avec et sans chaque base, calcul exact). L'utilisateur peut les modifier. | Le cahier laisse l'utilisateur marquer les bases à la main (§11.2) ; l'angle demande que le modèle les propose. |
| **D5** | Taille de sélection : fixe (12/10) ou choisie par le modèle ? | **Choisie par le modèle** sous contrainte de budget : parmi les combinaisons (taille, bases, k) dont le coût ≤ budget, retenir celle de `p_hit` maximal ; afficher les 2-3 suivantes. | Fixe 12/10 vient de M1/M2. Avec le modèle aux commandes, la taille est une variable de décision. |
| **D6** | Nommage des nouveaux objets | **Vocabulaire français** pour les formes vues par le moteur et l'API (`selection`, `bases`, `tickets`, `couverture`, `p_couverture`…), conformément à la convention de l'architecture. | Le cahier utilise de l'anglais (`strategy_run`, `picks`, `slot`, `p_hit`) ; l'architecture impose le français de bout en bout pour les formes du moteur. |
| **D7** | Où vit le module ? | `backend/app/engine/multi/` (pur, sans I/O) + miroir `mobile/lib/engine/multi/` ; le cache des systèmes passe par `data/repository.py` ; fixtures partagées `fixtures/multi_cases.json`. | AD-1 (cœur sans I/O) et AD-2 (parité Python/Dart par fixtures). Le cahier dit `multi/rules.py` sans situer le module. |

---

## B. Écarts détaillés

### Écart 1 — Le Multi n'existe pas dans le PRD

**Source** : tout le cahier Multi.
**PRD** : §4.5 couvre couplé, tiercé, quarté, quinté (ordre/désordre), couplé placé et 2 sur 4. Le Multi n'apparaît ni dans les FR, ni dans le glossaire, ni dans le périmètre MVP.
**Conséquence** : il faut des **exigences nouvelles** et un **Epic 5**. Proposition de découpage, calqué sur l'angle :

| FR proposée | Capacité | Question de l'angle |
|---|---|---|
| FR-22 | Éligibilité d'une course au Multi (≥ 14 partants déclarés, course support) | prérequis |
| FR-23 | Verdict « jouer / passer » avec ses raisons (D3) | si je joue |
| FR-24 | Sélection recommandée par le modèle, taille choisie sous budget (D1, D5) | quelle sélection |
| FR-25 | Bases recommandées avec arbitrage coût/couverture (D4) | quelles bases |
| FR-26 | Systèmes réduits générés et **vérifiés**, en dossards, avec coût et couverture | quel système |
| FR-27 | Explication de chaque cheval retenu/écarté et de chaque choix | pourquoi |
| FR-28 | Journalisation des recommandations avant départ et évaluation après course (§7-8 du cahier) | preuve |

Glossaire PRD à compléter : *Multi*, *base*, *système réduit*, *couverture garantie*, *probabilité de couverture*.

### Écart 2 — « Si je joue » : aucune réponse dans le cahier

**Source** : §6 évalue une sélection (`p_hit`, distribution de X, indice de valeur) mais ne conclut jamais.
**Manque** : un verdict par course. Voir D3. Ajouter au cahier une section « Verdict » : entrées (budget, `p_hit` du meilleur système, entropie), sortie (`jouer` / `passer` / `jouable seulement avec un budget ≥ X`), toujours accompagnée de ses raisons.
**Garde-fou** : SM-C2 du PRD (« ne jamais optimiser le volume de signaux ») s'applique — un verdict « jouer » plus fréquent n'est pas un meilleur verdict ; seule la calibration de `p_hit` juge.

### Écart 3 — La sélection du modèle n'a pas de spécification

**Source** : §4 spécifie M1, M2 et les références B0-B2. La seule sélection issue du modèle est **B2** (« les `size` premiers du classement interne »).
**Manque** : B2 trie par classement de victoire, alors que le Multi récompense la présence **dans les 4 premiers**. La sélection du modèle doit trier par **Top4_i** (déjà calculé par Harville, `mobile/lib/engine/harville.dart`) ou, mieux, choisir l'ensemble qui maximise `p_hit` exact (§6.1) — ce n'est pas la même chose quand des chevaux sont corrélés dans l'ordre d'arrivée.
**À ajouter** : une stratégie `modele` (nom provisoire) = sélection qui maximise `p_couverture` sous contrainte de taille ; c'est elle que l'app recommande (D1).

### Écart 4 — Bases choisies par le modèle

Voir D4. Le calcul est déjà dans le cahier (§6.1, `p_hit` exact sur les ensembles contenant les bases) ; il manque la règle de proposition et l'affichage de l'arbitrage.

### Écart 5 — « Pourquoi » : n'existe que pour M1/M2

**Source** : `Pick.rule` (§4.1) explique une règle M1/M2 (« A fini 4e : épreuve la moins dotée »).
**Manque** : pour une sélection issue du modèle, l'explication doit venir des quantités du moteur — Top4_i, value, forme, indicateurs de transparence déjà affichés (FR-4 : « Historique court », « 🐎 Inédit », compteur de terrain inconnu). Exemples attendus : « retenu : 41 % d'être dans les 4 », « écarté : 6 % malgré une cote de 5 — historique court », « base : présent dans 78 % des arrivées simulées ».
Le verdict (Écart 2) et le choix du système doivent eux aussi être expliqués.

### Écart 6 — M2 contre le non-goal « presse » du PRD

Voir D2. Le PRD §5 : « Pas d'historique de presse/consensus intégré au score — si réintroduit un jour, affiché à part, jamais mélangé au calcul. » M2 fait des citations de presse le critère de sélection. Il est aussi inévaluable en backtest. → retiré de la V1.

### Écart 7 — Mise et multiplicateur

**Source** : §5.4 (`multiplier ≤ 200`, `cost_eur = n_tickets × 3 € × m`), §10 (`multiplier` dans `/multi/tickets`).
**Décision D0** : pas de mise recommandée. Le multiplicateur reste une **saisie utilisateur** (défaut 1) qui ne fait que multiplier le coût affiché. Pas de Kelly Multi en V1.

### Écart 8 — `p_hit` et les partants virtuels

**Source** : §6.1 énumère les ensembles de 4 chevaux parmi `n` partants.
**Code existant** : le moteur ajoute des **partants virtuels** pour les déclarés non saisis (PRD FR-8, cahier backend §7.8) et l'énumération quarté se limite aux 7-8 meilleurs (`combinatoire.py`, `_combo_ordre_desordre`).
**À préciser dans le cahier** : (a) les partants virtuels entrent dans le champ de l'énumération mais ne peuvent jamais être sélectionnés ; (b) l'énumération Multi porte sur **tout le champ** (≤ 20 → 4 845 ensembles × 24 ordres), pas sur le pool des 7-8 meilleurs ; (c) les contrôles du §6.1 (`Σ P_set = 1`, `E[X] = Σ Top4_i`) deviennent des cas de `fixtures/multi_cases.json` (AD-2), comme les invariants Harville existants.

### Écart 9 — Données : dépendances non résolues

| Besoin | État dans le projet |
|---|---|
| Rapports Multi définitifs, champ « course support » | Inconnus — à découvrir dans `pmu_client.py` (cahier Multi §12.3). |
| Allocation de la dernière course | Dans l'API, absente du schéma (cahier Multi §3) — nécessaire **seulement pour M1** ; plus nécessaire pour la recommandation si D1 est retenu. |
| Cotes historiques fiables | Sémantique inconnue (brief) — affecte B1 et l'indice de valeur, pas la sélection du modèle. |
| Volume d'appels | Ajouter les rapports Multi augmente les appels à une source non autorisée (PRD §9.3, question ouverte 6) — à intégrer au même arbitrage de fréquence. |

**Conséquence de D1** : la recommandation ne dépend **que** des données que le moteur utilise déjà. Les données nouvelles ne servent qu'à l'évaluation (rapports) et aux comparateurs (M1).

### Écart 10 — Évaluation : bien alignée, à rattacher aux métriques du PRD

Le protocole du cahier (§8 : différences appariées contre B1/B2, gel avant test, découpage temporel, correction de Holm) est cohérent avec SM-1/SM-2. À ajouter :
- **Calibration de `p_couverture`** comme métrique primaire du module (prolongement direct de SM-1).
- **Calibration du verdict** : sur les courses marquées « jouer » vs « passer », la couverture observée diffère-t-elle comme annoncé ?
- Rappeler SM-C2 : ne pas régler le verdict pour produire plus de « jouer ».

### Écart 11 — Hors ligne et parité : compatible, à formaliser

Le cahier (§11) prévoit les fonctions pures en Dart et un **catalogue précalculé** de systèmes (`assets/multi_catalog.json`). Compatible avec FR-13 et AD-2. À ajouter : le calcul exact de `p_couverture` et la recommandation (sélection, bases, verdict) doivent aussi tourner **sur l'appareil**, sinon UJ-2 (hippodrome, réseau saturé) n'est pas couvert pour le Multi.

### Écart 12 — Mentions obligatoires

Cahier : « Couverture garantie — pas un gain garanti », « L'outil ne place aucun pari ». PRD : rappel de jeu responsable sur chaque écran de résultats. → les trois sur l'écran Multi.

---

## C. Ce qui reste du cahier tel quel

- §2 Règles du Multi et fonctions pures (`requalify`, `payable_sets`, `settle`) — **à vérifier sur pmu.fr** avant de figer (règles de 2001-2002), PMU France uniquement.
- §5 Générateur + **vérificateur obligatoire** + cache relabellé ; critère « ≤ taille du document » sur l'annexe A.
- §6.1 Calcul exact de `p_hit` et de la distribution de X.
- §7 Journalisation immuable, anti-fuite temporelle, mode `live` en écriture seule avant usage.
- §8 Protocole d'évaluation (avec les ajouts de l'Écart 10).
- Annexes A, C, D ; annexe B comme tests de non-régression de M1 (comparateur).

## D. Ce qui est reporté ou retiré

| Élément du cahier | Sort | Raison |
|---|---|---|
| M2, `/extraction/presse`, `CitationsProvider`, `FormListProvider`, `press_snapshot` | Reporté (hors V1) | D2 |
| M1 comme recommandation | Rétrogradé en comparateur | D1 |
| Écran « Choix de la méthode M1/M2/B2 » (§11.1) | Remplacé par la recommandation du modèle + accès secondaire aux comparateurs | D1 |
| `multiplier` comme recommandation | Saisie utilisateur seulement | D0 |
| Indice de valeur (§6.2) dans la décision | Affiché comme hypothèse, **hors verdict** tant que non calibré | D0, D3 |
| Systèmes mixtes, recouvrement pondéré par la valeur | V2 (déjà prévu) | — |

## D bis. Décisions du porteur de projet (2026-10-17)

| # | Réponse | Application dans le cahier Multi |
|---|---|---|
| D0 | Non | Aucune mise ni multiplicateur recommandé ; coût du système affiché ; multiplicateur = saisie utilisateur (défaut 1). |
| D1 | Le modèle | Stratégie `modele` = recommandation ; M1, B0, B1 = comparateurs « hypothèse non validée ». |
| D2 | « Laisse » | M2 reste dans le cahier comme stratégie future, **non construite en V1** (conflit PRD §5). Interprétation confirmée. |
| D3 | Un verdict | Verdict par course : `jouer` / `jouable_avec_budget` / `passer`, avec raisons ; seuils réglables, valeurs par défaut fixées au pilote. |
| D4 | Le modèle propose 3 | *Interprété* : toujours **3 bases candidates** classées, chacune avec son arbitrage ; la recommandation en retient 0 à 3 ; l'utilisateur les active/désactive. Interprétation confirmée. |
| D5 | Le modèle choisit | Taille, bases et formule choisies par le modèle sous contrainte de budget, + alternatives. |
| D6 | Français, anglais selon le choix de l'utilisateur | Code et API en français ; **langue d'affichage FR/EN au choix de l'utilisateur** → explications et raisons transmises comme **codes + paramètres**, rendues dans la langue choisie. **Portée confirmée : toute l'application**, pas seulement le Multi. **Calendrier confirmé : MVP en français, anglais après le MVP** ; les codes d'explication du Multi préparent l'ajout. |
| D7 | `engine/multi` | `backend/app/engine/multi/` + miroir `mobile/lib/engine/multi/`. |

## E. Prochaines étapes

1. Le porteur de projet valide ou corrige **D0 à D7**.
2. Mettre à jour le cahier Multi (sections 4, 6, 10, 11) et l'enregistrer dans `docs/`.
3. Ajouter FR-22 à FR-28 et le glossaire au PRD ; créer l'**Epic 5** dans `epics.md`.
4. Premier incrément conseillé, sans dépendance de données nouvelles : `rules.py` + vérificateur + `p_couverture` exact + sélection du modèle, avec fixtures partagées Python/Dart.
