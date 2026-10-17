# Tri des idées — angle « aide à la décision Multi »

*Source : `.memlog.md` de cette session (104 idées). Filtre : l'angle validé par le porteur de projet le 2026-10-17 et les décisions D0 à D7 de `_bmad-output/planning-artifacts/multi/reconcile-cdc-multi-prd.md`.*

> **Pour cette course, le modèle me dit si je joue le Multi, avec quelle sélection
> et quelles bases, quel système, et pourquoi.**

Bilan : **31 idées retenues**, rangées par question de l'angle ; **21 parquées** (utiles mais hors module ou trop tôt) ; **le reste écarté** (app de jeu sociale, guichet, plusieurs utilisateurs, PMUC, mise, notifications).

## Retenues

### 1. Si je joue
| Idée | Forme retenue |
|---|---|
| Thermomètre de course (entropie) | Entrée du verdict : « course trop ouverte pour ce budget, passe ton tour » |
| Prix du point de couverture | Métrique affichée : € par point de `p_couverture` — compare les options entre elles |
| Détecteur de course piège | Raison du verdict : favoris fragiles (rentrée, changement de distance ou de terrain) |
| « Jouable seulement avec un budget ≥ X » | Troisième issue du verdict, en plus de jouer / passer |

### 2. Quelle sélection
| Idée | Forme retenue |
|---|---|
| Optimiseur inverse au budget | Cœur de D5 : (taille, bases, k) de `p_couverture` max sous le budget, + 2-3 alternatives |
| Taille adaptative | Conséquence de D5, plus de taille fixe 12/10 |
| Sensibilité par cheval | Δ`p_couverture` si on retire le cheval → les chevaux qui « portent » la sélection |
| Swap suggéré | L'utilisateur part de sa propre sélection, le modèle propose les 1-2 échanges les plus utiles |
| Chevaux imposés (ex-« numéros fétiches ») | Inclusion forcée, avec le coût en `p_couverture` affiché |
| Divergence modèle/marché par cheval | Rappel de la value existante sur chaque cheval de la sélection |

### 3. Quelles bases
| Idée | Forme retenue |
|---|---|
| Bases proposées automatiquement | D4 : 0-3 bases parmi les Top4 les plus élevés, arbitrage coût économisé / couverture perdue |
| « 2 bases + longue traîne », « base favori + outsiders », « champ 3 bases » | Non plus des recettes : des **options comparées** par le modèle sur la même course |

### 4. Quel système
| Idée | Forme retenue |
|---|---|
| Vérificateur de systèmes du commerce | L'utilisateur saisit un système trouvé ailleurs → couverture réelle, système équivalent plus petit |
| Choix parmi les designs équivalents / relabelling pondéré | V1.5 : à taille égale, placer les recouvrements multiples sur les combinaisons les plus probables |
| Système tronqué au budget | Option explicite, avec `p_couverture` recalculée et la perte de garantie dite clairement |
| Couverture probabiliste (≈ 95 % de la masse) | Option « non garantie », toujours affichée comme telle, jamais par défaut |
| Simulation de non-partant | Ce que devient chaque ticket si tel cheval ne part pas (requalification) |
| Non-partant de dernière minute | Recalcul local instantané + « ce qui change » |
| Heatmap de couverture | Visualiser les combinaisons couvertes 1×, 2×, 3× |
| Curseur prudent ↔ large | Présentation des options de D5 (moins de chevaux et plus de bases ↔ plus de chevaux et moins de bases) |
| Presets de budget | Le budget est l'entrée principale de l'écran |
| Bouton « recommandation pour cette course » | L'écran s'ouvre directement sur la recommandation du modèle |
| Écran unique : sélection → budget → grilles | Principe de l'écran Multi |
| Pré-calcul à la synchro + tout en Dart | Hors ligne sur hippodrome (FR-13, UJ-2) |
| Moteur générique « k parmi n sans ordre » | Principe d'architecture : même générateur/vérificateur réutilisable (2 sur 4…) |

### 5. Pourquoi
| Idée | Forme retenue |
|---|---|
| Mode coach | Chaque cheval retenu/écarté expliqué par les quantités du moteur (Top4, value, forme, transparence) |
| Avertissements en langage simple | « Pas de cote pour le 7 : traité comme très délaissé » |
| Traducteur de musique | « 1h5s2h » → phrase lisible, sur la fiche et dans les explications |
| Fraîcheur des données | « Cotes de 9 h 12 » visible à côté du verdict |
| Débrief après course | Combien de chevaux capturés, lesquels le modèle avait vus, lesquels il a manqués |
| Écran preuves + musée des échecs + fiche méthode versionnée | La transparence du modèle étendue au Multi : performances mesurées, échecs compris |

## Parquées (utiles, mais pas dans ce module ou pas maintenant)

| Idée | Où elle irait |
|---|---|
| Trajectoire des 3 derniers rangs, descente de catégorie, rang relatif au peloton, battu de peu, changement de jockey, repos, stalle, mouvement de cote | **Moteur de scoring** (pas le Multi) — à tester contre la calibration SM-1 |
| Étude d'ablation « une seule variable » | Recherche sur le moteur |
| Routeur de stratégie par type de course, calendrier de jouabilité, rejeu d'un système | Évaluation (§8), quand l'historique le permet |
| Baseline contrarienne, vote M1∩modèle, « Multi des délaissés » | Comparateurs du protocole d'évaluation |
| Rapport probable par scénario d'arrivée | Après calibration de l'indice de valeur (D0) |
| Suivi de ce que l'utilisateur a réellement joué | Lié à SM-3 du PRD, pas au module |
| Casaques, mode plein soleil, mode une main | UX générale de l'app |
| Systèmes mixtes 5+6 | V2 (déjà prévu) |

## Écartées

Mode bulletin / guichet, partage WhatsApp, syndicat, ligue, quiz, sagesse de la foule, anti-collision entre utilisateurs, carte de tipster, devise/opérateur PMUC, règlement par photo du ticket, bankroll et Monte-Carlo de ruine, horizon hebdomadaire, plafond de pertes, gros joueur multi-systèmes, notifications, widget, vocal, partage QR, compte à rebours, carnet de systèmes, citations synthétiques (M2 hors V1).

## Ce que le tri révèle

1. **L'écran Multi tient en une phrase** : budget en entrée → verdict + sélection + bases + système en sortie, chaque élément expliqué. Tout le reste est secondaire.
2. **Le levier le plus original reste le choix du système à taille égale** (relabelling pondéré) — il est cohérent avec l'angle parce que c'est le modèle qui dit quelles combinaisons méritent d'être doublées.
3. **Beaucoup d'idées « stratégie » étaient en réalité des améliorations du moteur de scoring.** Elles servent tous les paris, pas seulement le Multi, et se valident par la calibration (SM-1).
