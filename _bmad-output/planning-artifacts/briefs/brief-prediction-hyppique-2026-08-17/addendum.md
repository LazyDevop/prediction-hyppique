# Addendum — Analyseur Hippique

## Analyse concurrentielle détaillée (Geny, Bilto, ZEturf, CanalTurf)

**Constat central** : les quatre sites observés parlent tous le même langage — des *picks* (qui jouer), formulés en prose par un pronostiqueur nommé, parfois agrégés entre journaux (la "synthèse de la presse" de Geny). Aucun ne publie de probabilité chiffrée, ni ne la met explicitement en regard de la cote.

Le différenciateur de l'Analyseur Hippique n'est donc pas "plus de détail" mais un **changement de registre** : la question posée n'est pas "qui va bien courir" mais "où le marché et le modèle sont en désaccord, et de combien" — formalisé par `value = probabilité × cote − 1`.

### Point par point

- **Scoring propriétaire vs jugement d'expert qualitatif.** Geny n'est pas opaque par choix : son pronostiqueur *explique* ses choix en prose (ex. "retrouve Benjamin Rochard à son sulky"). C'est du jugement d'expert, pas un algorithme caché. La vraie différence : le modèle de l'Analyseur est **reproductible et réglable** — mêmes données, même résultat, et l'utilisateur peut recalibrer les coefficients (récence, sensibilité au poids, contraste…) et voir le classement bouger. Aucun concurrent observé ne permet à son lecteur de recalibrer le pronostic.

- **Combinaisons optimisées — point le plus démontrable.** Geny suggère une "solution" en une phrase (ex. "au second échelon avec Joyeux Nonna, Joria Mesloise..."). L'Analyseur sort des combinaisons **classées par probabilité chiffrée, en dossards, sur les dix types de paris** (couplé, tiercé, quarté, quinté, ordre et désordre, couplé placé, 2 sur 4). Rien de comparable observé chez les concurrents — bon point de démo concrète.

- **Profondeur d'historique en accès libre.** Pas de données fiables sur les modèles tarifaires concurrents pour trancher l'angle "prix" — ne pas inventer cet angle. Fait vérifié en revanche : la fiche Genybet limite l'historique à 5 performances pour un visiteur non identifié, profondeur complète réservée aux comptes. Le backend de l'Analyseur (via open-pmu-api) atteint un historique remontant à 2004, sans compte ni abonnement requis. Différenciateur d'accès réel, à formuler sur ce fait précis, pas sur une hypothèse de prix.

### Angles additionnels identifiés (absents des 4 concurrents observés)

- **Mise suggérée (Kelly fractionné).** Aucun des quatre sites ne dit combien miser, seulement quoi jouer. L'Analyseur relie recommandation et gestion de bankroll — rare même chez les services payants.
- **Amélioration par calibration continue.** Une fois le backend calibré sur l'historique réel de courses (cf. section calibration du cahier des charges), le modèle peut évoluer avec des données vérifiables. Un pronostic de journal ne se corrige jamais publiquement au vu de ses résultats passés.

### Faiblesses à assumer honnêtement (à ne pas taire dans le brief)

- Le modèle est aveugle à l'information tactique et humaine que les tipsters captent : changement de driver, intention de course ("part devant"), info d'écurie. Aucune donnée chiffrée ne remplace ça aujourd'hui.
- Aucune preuve à ce stade que les probabilités du modèle sont mieux calibrées que le jugement d'expert des pronostiqueurs concurrents. Seul un backtest sur plusieurs mois pourra le démontrer — pas une comparaison de fonctionnalités.

## Modèle économique — options considérées et rationale

**Point de coupure freemium retenu : sur l'actionnable, pas sur la donnée.**

Option écartée : gratuit = scoring de base, payant = combinaisons. Rejetée parce que le scoring (détection de value) est précisément le différenciateur identifié face à Geny et consorts — le distribuer gratuitement reviendrait à donner l'avantage concurrentiel. Les combinaisons, une fois les probabilités connues, sont plus mécaniques (énumération + Monte-Carlo) — moins un atout unique en soi que le scoring lui-même.

Découpage retenu :
- **Gratuit** : classement des chevaux + indicateur de value visible (l'accroche émotionnelle — "ce cheval est sous-coté").
- **Payant** : tout ce qui sert à agir — mise suggérée (Kelly fractionné), combinaisons précises en dossards, historique profond. C'est le moment où l'utilisateur a déjà compris la valeur et veut aller plus loin.

**Structure tarifaire : à l'usage / par crédits plutôt qu'abonnement mensuel fixe.**

Rationale : un abonnement classique (10-30€/mois) suppose un usage régulier, mais les courses hippiques se consomment par pics (Quinté+ du dimanche, une réunion précise) plutôt qu'au quotidien — un abonnement fixe ferait payer un parieur occasionnel les semaines où il ne joue pas. Un modèle à l'usage ou par crédits colle mieux aux habitudes réelles observées.

**Segment cercles/professionnels du pari : phase 2, pas point de départ.** Valeur potentielle plus élevée mais logique très différente (vente directe, relation commerciale) — hors périmètre de la V1.

