---
title: Revue adversariale — Module Multi du PRD prediction-hyppique
date: 2026-10-17
portée: prd.md §1 (Multi), §2.1, UJ-4, glossaire Multi, §4.11 FR-22 à FR-30, §5, §6.1/6.2, §7 SM-4/SM-5/SM-C3, §8, §11 Q8-11, §12 ; addendum.md §G
référence de contrôle: docs/cahier_des_charges_module_multi.md (v2)
---

# Revue adversariale — Module Multi

## Verdict

Le module Multi est honnête dans ses intentions (« couverture garantie — pas un gain garanti », comparateurs étiquetés, journalisation immuable), mais tel qu'écrit il n'est **pas prêt à être découpé en epics**. Trois problèmes de fond le fragilisent : (1) tout le modèle de coût et de gain repose sur des règles PMU de 2001-2002 non vérifiées, et rien n'empêche de construire avant de les avoir vérifiées ; (2) le verdict « jouer / jouable avec un budget de X € » se fonde uniquement sur la probabilité de couverture, ce qui en fait de fait une recommandation de dépense, sans aucune considération d'espérance de gain, en contradiction avec le non-goal « aucune mise recommandée » et avec la promesse de ne pas induire en erreur ; (3) le verdict, ses seuils par défaut, la journalisation « live » et la levée des mentions dépendent d'un pilote et d'un harnais de backtest qui forment à eux seuls un projet entier, pour un développeur solo, alors que le MVP est censé livrer le verdict tout de suite. S'y ajoutent des trous de comportement hors ligne (comment un non-partant arrive-t-il sur l'appareil ?), des exigences non testables (« un système plus petit s'il en existe un », déterminisme sans liste d'entrées) et des métriques (SM-5) qui valident une tautologie plutôt que l'utilité du verdict. À corriger avant la story-isation.

## Constats

### 1. [CRITIQUE] Le modèle de coût repose sur des règles non vérifiées, et rien ne bloque le développement en attendant
- **Emplacement :** §11 Q8 ; FR-22 (2ᵉ conséquence) ; FR-23 ; FR-25 ; UJ-4 (« 11 tickets … 33 € ») ; cahier §2, §5.5.
- **Problème :** prix unitaire de 3 € quelle que soit la formule, coefficients de rapport 35 / 7 / 7⁄3 / 1, seuil de 14 partants, jours de course support, rapports minimums et requalification des non-partants viennent tous d'un document de 2001-2002. Si la règle actuelle du PMU est différente (par exemple un prix *par combinaison*, ce qui ferait coûter un Multi en 7 bien plus qu'un Multi en 4, ou une course support qui aurait changé), alors sont faux en même temps : le coût de chaque option (FR-23), le choix sous budget, le catalogue de systèmes réduits, l'argument du cahier §5.5 selon lequel « la structure ne change pas l'espérance », les chiffres de UJ-4 et le verdict. Le PRD traite ce point comme une simple question ouverte (Q8) et FR-22 se contente de demander une « date de dernière vérification ». Rien n'oblige à faire la vérification avant le premier ticket de développement.
- **Correction :** faire de la vérification des règles sur pmu.fr (prix, formules, course support, seuil de partants, Flexi) un **prérequis bloquant** du module, avant l'étape 1 du plan. Ajouter une conséquence testable à FR-22 : « si les règles vérifiées diffèrent de celles du cahier §2, FR-23, FR-25 et UJ-4 sont revus avant implémentation ». Prévoir aussi ce qui se passe si le Multi n'existe plus sous cette forme.

### 2. [CRITIQUE] Le verdict « jouer » est une recommandation de mise qui ne dit pas son nom, et elle ignore la rentabilité
- **Emplacement :** FR-26 ; FR-23 (objectif) ; §5 non-goal Multi ; UJ-4 (résolution) ; SM-5 ; glossaire « Verdict ».
- **Problème :** le verdict ne dépend que de `p_couverture ≥ seuil` et d'un budget (cahier §6.4) ; FR-26 exclut même explicitement l'indice de valeur. Or la probabilité de couverture augmente mécaniquement avec la dépense. « Jouer » veut donc dire « avec cet argent vous couvrez souvent », et jamais « ce pari a une espérance raisonnable ». Avec la retenue du pari mutuel, couvrir les 4 premiers avec 11 tickets peut très bien rapporter moins que la mise : le rapport Multi en 7 d'une arrivée de favoris peut être inférieur à 33 €. « Jouable avec un budget de 33 € » indique un montant à dépenser au-delà du budget que l'utilisateur s'était fixé, ce qui contredit directement le non-goal « ne recommande aucune mise ni multiplicateur ». UJ-4 présente comme une fin normale que Marc dépasse son budget en suivant ce verdict.
- **Correction :** (a) renommer les verdicts en termes de couverture, sans verbe d'action (« couverture atteinte / atteignable avec X € / non atteinte »), ou bien conditionner « jouer » à un critère de rentabilité une fois l'indice calibré ; (b) ajouter à FR-26 l'obligation d'afficher, à côté de chaque verdict, le rapport R7 minimum pour ne pas perdre (`r7_seuil_eur`, déjà défini dans le cahier §5.4 mais absent du PRD) et la mention « rentabilité non évaluée » ; (c) reformuler le non-goal §5 pour reconnaître que le verdict « jouable avec X € » affiche un montant, et l'encadrer par un plafond (`facteur_budget_max`) qui ne soit jamais supérieur à une valeur fixée par le produit ; (d) réécrire la résolution de UJ-4 pour que le dépassement de budget ne soit pas présenté comme l'issue normale.

### 3. [ÉLEVÉ] Le verdict n'a pas de seuils par défaut tant que le pilote n'est pas fait, et le pilote dépend d'une infrastructure lourde
- **Emplacement :** FR-26 (3ᵉ conséquence) ; §6.1 (« sans eux, ni les seuils … n'existent ») ; §11 Q10 ; cahier §0.3 (« rien n'est inventé »), §8.4.
- **Problème :** le principe « aucun seuil n'est inventé » et l'exigence « afficher un verdict » ne peuvent pas être vrais en même temps au premier lancement. Soit le MVP affiche un verdict calculé avec des seuils inventés (même étiquetés « provisoires »), soit il n'affiche pas de verdict tant que le pilote n'a pas tourné. Or le pilote exige le harnais de backtest, la reconstruction du moteur à `donnees_a`, l'historique de courses de ≥ 14 partants et un découpage temporel. La journalisation « live » a besoin elle aussi de « budgets de référence fixés au pilote » (cahier §7) : avant le pilote, il n'y a rien à journaliser, donc l'évaluation prospective (SM-4) ne peut pas démarrer. Le chemin critique est circulaire et n'est écrit nulle part.
- **Correction :** décider explicitement dans le PRD si le verdict est livré (a) après le pilote seulement, avec avant cela un écran sans verdict qui montre couverture et coût, ou (b) avec des seuils provisoires déclarés et documentés, dont la provenance est dite. Ordonner : backtest et pilote → seuils et budgets de référence → journalisation live → levée des mentions.

### 4. [ÉLEVÉ] Le périmètre MVP Multi est un second produit pour un développeur solo
- **Emplacement :** §6.1 (puce Multi) ; FR-25 (vérification de systèmes saisis) ; FR-29 ; FR-30 ; addendum §G (plan en 10 étapes).
- **Problème :** la puce « Module Multi » de §6.1 englobe 8 endpoints, un générateur de covering designs (MILP + recuit simulé), un catalogue précalculé pour `v' ≤ 20, k' ≤ 7, t' ≤ 4`, la parité Python/Dart de toute la recommandation, M1 (avec décodeur de musique et colonnes de schéma nouvelles), B0 et B1, l'ingestion des rapports depuis une source encore inconnue (Q9), un job de journalisation avant chaque départ, un harnais de backtest anti-fuite, un pilote, un débrief et une saisie de systèmes externes. C'est sans doute plus lourd que tout le reste du MVP réuni. Le cahier §13 dit lui-même que les étapes 1 à 5 suffisent pour une recommandation utilisable.
- **Correction :** découper le Multi en deux jalons : **Multi-MVP** (étapes 1 à 5 : règles, vérificateur, catalogue, couverture, recommandation sans verdict ou à seuils déclarés, écran, export) et **Multi-évaluation** (comparateurs, journalisation, rapports, backtest, pilote, performances). Sortir du MVP la vérification de systèmes saisis à la main (FR-25, 4ᵉ conséquence) et la carte de couverture.

### 5. [ÉLEVÉ] Hors ligne : rien ne dit comment un non-partant de dernière minute arrive sur l'appareil, et FR-15 se contredit
- **Emplacement :** UJ-4 (cas limite) ; FR-23 (5ᵉ conséquence) ; FR-14 ; FR-15 ; cahier §6.6.
- **Problème :** UJ-4 promet que, « sur l'hippodrome sans réseau », un non-partant annoncé déclenche un recalcul. Or sans réseau l'app ne peut pas apprendre ce non-partant, et FR-14 interdit tout rafraîchissement automatique. Aucune FR ne prévoit une action manuelle « déclarer non-partant », distincte de « retirer un cheval » (FR-28), qui fait passer la sélection en « modifiée » et fausse le débrief. FR-15 affirme que l'import photo et le rafraîchissement des cotes sont les **seules** fonctionnalités qui nécessitent le réseau. C'est faux pour le Multi : éligibilité (marqueur course support), rapport R7 historique, performances des comparateurs et débrief (résultats) en dépendent aussi.
- **Correction :** ajouter à FR-23 ou FR-28 une action « marquer non-partant » utilisable hors ligne, qui ne modifie pas le statut « modifiée ». Étendre FR-15 à la liste complète des fonctions réseau du Multi et préciser leur repli (valeurs en cache avec leur date, ou masquées).

### 6. [ÉLEVÉ] Après un non-partant, le recalcul d'une nouvelle recommandation ne répond pas au besoin du joueur
- **Emplacement :** UJ-4 (cas limite) ; FR-23 (5ᵉ conséquence) ; cahier §2 (requalification), §6.6.
- **Problème :** si Marc a déjà joué ses tickets, une recommandation recalculée (éventuellement une sélection différente) ne lui sert à rien : il a besoin de savoir ce que deviennent **ses** tickets (requalification de 7 en 6, remboursement, garantie encore tenue ou non). Le PRD ne distingue pas ces deux cas. Il ne traite pas non plus le non-partant d'une **base**, ni la course qui repasse sous 14 partants, ni la sélection qui tombe sous `k`.
- **Correction :** préciser dans FR-23 deux comportements : (a) avant de jouer, recalculer la recommandation ; (b) pour une sélection retenue (FR-30), afficher la requalification ticket par ticket, la nouvelle couverture et le statut de la garantie. Ajouter les cas « base non-partante » et « sélection < k ».

### 7. [ÉLEVÉ] « Propose un système valide plus petit s'il en existe un » ne peut pas être testé
- **Emplacement :** FR-25 (4ᵉ conséquence).
- **Problème :** savoir s'il existe un covering design plus petit est un problème d'optimalité que le cahier lui-même ne résout pas (optimum « entre 14 et 15 » pour un cas). Le cahier restreint d'ailleurs la règle à « s'il existe **dans le catalogue** ». Telle qu'écrite dans le PRD, l'exigence est invérifiable et sera soit impossible à tenir, soit tenue de façon trompeuse : l'app dirait « aucun système plus petit » alors que l'optimum n'est pas prouvé.
- **Correction :** « propose le plus petit système valide du catalogue pour les mêmes v, b, k s'il est plus petit ; sinon, n'affirme pas qu'il n'en existe pas ». Afficher « optimal prouvé / meilleur connu » (champ `optimal_prouve` du cahier).

### 8. [ÉLEVÉ] Le déterminisme de FR-23 est mal défini et menacé par la parité flottante et le catalogue
- **Emplacement :** FR-23 (4ᵉ conséquence) ; FR-30 NFR parité ; §8 ; cahier §4.1 (seuil 1e-12, troncature), §11.3.
- **Problème :** « à données et budget identiques » oublie d'autres entrées du résultat : multiplicateur, bases activées, chevaux imposés, réglages du moteur, seuils, **version du catalogue** et version du moteur. Les sorties sont discrètes (choix d'une option, d'un échange) et dépendent d'égalités flottantes (seuil d'échange de 1e-12, départage d'options à `p_couverture` égale) alors que la parité Python/Dart n'est garantie qu'à 1e-9 : backend et mobile peuvent légitimement choisir des options différentes. Si l'avertissement `optimisation_tronquee` est déclenché par un temps limite, le résultat dépend en plus de l'appareil.
- **Correction :** énumérer les entrées dans FR-23. Exiger des départages avec tolérance explicite, identiques dans les deux langages, et des fixtures partagées qui contiennent des égalités. Imposer une troncature par nombre d'itérations, jamais par temps. Journaliser la version du catalogue avec chaque recommandation.

### 9. [ÉLEVÉ] Aucun plan si l'évaluation conclut que le modèle fait moins bien que le marché
- **Emplacement :** FR-23 (2ᵉ conséquence) ; FR-29 ; SM-4 ; cahier §8.3.
- **Problème :** les mentions ne sont levées que si l'intervalle de confiance exclut 0 « du bon côté ». Rien n'est prévu si l'intervalle l'exclut du **mauvais** côté (modèle inférieur au comparateur marché B1). Le produit continuerait alors à présenter par défaut une recommandation dont on sait qu'elle fait moins bien que les cotes, avec une simple mention « en cours d'évaluation », ce qui devient trompeur. Même question si M1 bat le modèle.
- **Correction :** ajouter une règle de sortie : si le modèle est significativement inférieur à B1, la recommandation passe en « modèle moins bon que le marché sur la période X », ou le marché devient la sélection par défaut. Inscrire ce choix dans le PRD dès maintenant.

### 10. [ÉLEVÉ] SM-5 valide une tautologie, et le jeu sur les métriques reste possible
- **Emplacement :** SM-4, SM-5, SM-C3 ; FR-26 (seuils réglables).
- **Problème :** « jouer » est défini par une `p_couverture` élevée. Que la couverture observée soit plus forte sur « jouer » que sur « passer » est presque garanti dès que le modèle est un tant soit peu corrélé au résultat, et ne dit rien de l'utilité du verdict pour l'utilisateur (gain ou perte). SM-C3 interdit de régler les seuils pour produire plus de « jouer », mais FR-26 laisse l'utilisateur les régler librement, jusqu'à 0, ce qui donne « jouer » partout sans avertissement. Le PRD retire aussi de SM-4 la précision « à taille égale » du cahier §8.2 : sans elle, la différence de capture entre le modèle (taille choisie sous budget) et B1 se gagne simplement en prenant des sélections plus grandes.
- **Correction :** SM-5 doit comparer la couverture observée à la couverture **annoncée** par tranche (calibration), et rapporter le retour financier observé sur « jouer » avec le nombre de courses. Remettre « à taille égale » dans SM-4. Dans FR-26, afficher « seuils personnalisés — non évalués » dès qu'un seuil diffère de la valeur par défaut, et borner les valeurs possibles.

### 11. [ÉLEVÉ] Formulations qui font passer une estimation pour un fait
- **Emplacement :** UJ-4 (« dans les 4 premiers dans 41 % des cas ») ; FR-24 ; FR-27 ; FR-30 ; glossaire « Probabilité de couverture ».
- **Problème :** « dans 41 % des cas » se lit comme une fréquence observée. C'est une estimation Harville, connue pour surestimer les favoris aux places 2 à 4 (cahier §6.1), produite par un moteur dont la calibration (SM-1) n'est pas démontrée. Les pourcentages de couverture s'affichent sans aucune incertitude, à côté du mot « garantie ».
- **Correction :** imposer la formule « le modèle estime … » pour tout pourcentage du Multi. Ajouter à FR-27 une conséquence testable : aucun pourcentage du modèle n'est affiché sans qualificatif d'estimation. Rappeler que SM-1 n'est pas encore atteint.

### 12. [MOYEN] La garantie affichée peut faire croire à un gain, et le PRD omet le seuil de rentabilité
- **Emplacement :** FR-25 (2ᵉ conséquence) ; FR-30 (R7 médian seulement à partir de 30 courses) ; §1.
- **Problème :** « au moins un ticket paie au moins le rapport Multi en k » emploie le verbe « payer » sans dire qu'un ticket payant peut rapporter moins que la mise totale. Le R7 historique n'apparaît qu'avec au moins 30 courses support en base ; or l'ingestion des rapports dépend de Q9, qui n'est pas résolue. Au lancement, l'utilisateur n'a donc aucun ordre de grandeur des gains. `r7_seuil_eur` (cahier §5.4) n'est pas exigé par le PRD.
- **Correction :** ajouter `r7_seuil_eur` aux champs obligatoires de FR-25, avec un libellé du type « pour ne pas perdre, il faut un rapport Multi en 7 d'au moins X € ». Quand le R7 historique n'est pas disponible, l'écrire (« rapports réels inconnus ») au lieu de laisser la ligne vide.

### 13. [MOYEN] Cas limites de budget non spécifiés
- **Emplacement :** FR-23 ; FR-26.
- **Problème :** rien n'est dit pour un budget inférieur au système le moins cher (3 € × multiplicateur), un budget de 0, négatif ou décimal, ou un budget très élevé. Avec un gros budget, la formule intégrale sur 20 chevaux (C(20,4) = 4 845 tickets, soit 14 535 €) donne un verdict « jouer » à couverture presque totale. La conséquence « coût ≤ budget » de FR-23 n'a pas de sens quand il n'y a pas de recommandée. L'objectif « maximiser la couverture sous budget » consomme toujours tout le budget ; l'alternative « la moins chère à moins de 2 points » du cahier §4.3, qui tempère cet effet, n'est pas dans le PRD.
- **Correction :** ajouter à FR-23 : (a) budget sous le minimum → aucune recommandée, message dédié, verdict défini ; (b) bornes de saisie ; (c) l'alternative « moins chère à couverture quasi égale » rendue obligatoire. Préciser aussi si l'option recommandée doit être présentée avant ou après celle-ci.

### 14. [MOYEN] Partants virtuels et saisie incomplète : la recommandation peut être structurellement biaisée sans que l'utilisateur le sache
- **Emplacement :** FR-23 (1ʳᵉ conséquence) ; FR-28 ; FR-8 (partants virtuels).
- **Problème :** si l'utilisateur n'a analysé que 10 des 18 partants, les 8 autres deviennent virtuels et ne sont jamais sélectionnables. La sélection ne peut alors pas contenir de vrais partants non saisis, et la couverture est plafonnée artificiellement. Rien n'oblige à le dire. FR-28 (« ajouter des chevaux ») ne précise pas si l'utilisateur peut ajouter un partant virtuel. Aucun cas n'est prévu si tous les chevaux sont sans historique ou inédits, ce qui donne des probabilités presque uniformes et une recommandation arbitraire, présentée pourtant avec le même aplomb.
- **Correction :** dans FR-22 ou FR-27, afficher « N partants non analysés, non sélectionnables » et en faire une raison du verdict. Définir ce que donne l'ajout d'un partant virtuel. Exiger un avertissement fort (ou un verdict « passer — données insuffisantes ») au-delà d'une proportion de chevaux inédits ou à historique court.

### 15. [MOYEN] Ex-aequo et arrivée dégradée cassent le débrief « X chevaux sur 4 »
- **Emplacement :** FR-30 (5ᵉ conséquence) ; UJ-4 (résolution) ; cahier §2.
- **Problème :** avec un ex-aequo à la 4ᵉ place, il y a 5 chevaux dans « les 4 premiers ». Sans gagnant, l'arrivée dégradée s'applique. Une disqualification après finalisation est aussi possible. « X sur 4 » est alors ambigu, et le compteur `nb_captures (0..4)` du cahier ne peut pas représenter ces cas.
- **Correction :** définir le débrief par combinaison payable (« votre sélection contenait une combinaison payable : oui / non ») en plus du compte. Préciser la règle pour l'ex-aequo et l'arrivée dégradée, et le comportement en cas de correction après finalisation (FR-17).

### 16. [MOYEN] « Retenir une sélection » n'est déclenché par aucune action définie
- **Emplacement :** FR-30 (4ᵉ et 5ᵉ conséquences) ; FR-28 ; UJ-4.
- **Problème :** le débrief compare le modèle à « la sélection que l'utilisateur a retenue », mais aucune FR ne définit le geste qui fait « retenir ». Est-ce l'export, un bouton, la dernière sélection affichée ? Que se passe-t-il si l'utilisateur en retient plusieurs, change de budget ou modifie après coup ? Dans UJ-4, Marc copie les grilles : ce geste vaut-il « retenir » ?
- **Correction :** ajouter une action explicite « Je retiens ce jeu » (une par course, remplaçable avant l'heure de départ, figée ensuite), et en faire la seule source du débrief utilisateur.

### 17. [MOYEN] Les bases candidates dépendent de la sélection, qui dépend des bases
- **Emplacement :** FR-24 ; cahier §4.2-4.3.
- **Problème :** les bases candidates sont « les 3 meilleurs `top4` de la sélection », mais la sélection est construite à partir des bases (`B ⊆ S`, échanges sur `S \ B`). Le PRD ne dit pas sur quelle sélection les candidates sont calculées, ni par rapport à quelle formule se calculent « coût économisé » et « couverture perdue » (l'option recommandée peut changer de `k` une fois la base retenue). « Activer / désactiver » est ambigu : activer force-t-il la base ? Désactiver l'interdit-il dans le choix sous budget ? « Toujours 3 » échoue si la sélection compte moins de 3 chevaux, une réserve que le test du cahier §9.11 fait lui-même.
- **Correction :** préciser que les candidates sont calculées sur la sélection sans base (b = 0) à la taille recommandée. Définir activer = imposer et désactiver = interdire, et la référence utilisée pour le coût et la couverture. Remplacer « toujours 3 » par « 3, ou moins si la sélection en compte moins ».

### 18. [MOYEN] Le backtest « sans donnée postérieure » laisse passer des fuites indirectes
- **Emplacement :** FR-30 (3ᵉ conséquence) ; §11 Q5 ; cahier §7, §12.4.
- **Problème :** le test du cahier (supprimer les lignes postérieures) n'attrape pas les fuites par paramètres : quantiles d'allocation calibrés sur tout l'historique (Q5), constantes du moteur réglées après avoir vu les données, cotes « finales » de sémantique inconnue (open-pmu-api). SM-4 compare le modèle au marché : si les cotes historiques sont des cotes finales et la recommandation live une cote du matin, les deux côtés ne sont pas mesurés au même moment.
- **Correction :** étendre FR-30 : toute constante dérivée des données (quantiles, réglages) est figée à une date antérieure à la période de test, et la date figure dans le rapport. Aligner l'heure des cotes du comparateur marché sur celle utilisée par le modèle, ou déclarer l'écart.

### 19. [MOYEN] Journalisation « avant le départ » : fragile et silencieuse en cas d'échec
- **Emplacement :** FR-30 (2ᵉ conséquence) ; §9.3 ; Q6, Q9.
- **Problème :** le job dépend d'une source non autorisée et soumise à des blocages IP, de l'heure de départ (qui peut être décalée) et du marqueur « course support » (Q9). Un jour sans journalisation crée un trou non aléatoire : les jours de panne sont souvent les jours de forte affluence. Si un non-partant survient après la journalisation, l'entrée figée contient un cheval non-partant, et rien ne dit comment l'évaluer.
- **Correction :** journaliser explicitement les échecs (entrée « non journalisé, raison ») et les exclure de l'évaluation de façon documentée. Définir le traitement des non-partants survenus après journalisation (requalification selon les règles, sans réécrire l'entrée).

### 20. [MOYEN] Comparateurs et cotes manquantes : B1 et la référence marché de SM-4 ne sont pas définis
- **Emplacement :** FR-29 ; SM-4 ; glossaire « Overround ».
- **Problème :** B1 (« cotes les plus basses ») et « la même quantité calculée à partir des cotes du marché » (SM-4) exigent des cotes. Avec des cotes manquantes, et à plus forte raison si toutes manquent, la probabilité marché d'un ensemble de 4 n'est pas calculable : il faut retirer l'overround, ce qui suppose toutes les cotes. FR-29 affiche les « performances mesurées dès qu'il y en a », donc parfois sur 3 courses, sans intervalle.
- **Correction :** définir B1 et la référence marché en cas de cote manquante (exclusion de la course de SM-4, ou drapeau `degrade`). N'afficher de performance qu'au-delà d'une taille d'échantillon minimale, toujours avec intervalle et effectif.

### 21. [MOYEN] Le multiplicateur « ne fait que multiplier le coût » : c'est faux
- **Emplacement :** FR-23 (énoncé).
- **Problème :** le multiplicateur multiplie aussi les gains, et surtout il resserre la contrainte de budget, donc il **change** la recommandation. La formulation laisse croire à un réglage purement cosmétique.
- **Correction :** « multiplie le coût et les gains ; à budget fixé, il réduit les options accessibles ».

### 22. [BAS] Glossaire et FR ne sont pas alignés
- **Emplacement :** glossaire « Couverture garantie », « Comparateur » ; FR-29.
- **Problème :** la définition « Couverture garantie » omet la condition « et incluent les bases » (présente dans FR-25 et « Probabilité de couverture »). Le glossaire cite le tirage au hasard comme comparateur, mais FR-29 n'expose que M1 et le marché.
- **Correction :** aligner les définitions, et dire si B0 est affiché ou seulement journalisé.

### 23. [BAS] Le critère de taille « ≤ document » échoue sur une coquille connue
- **Emplacement :** FR-25 (3ᵉ conséquence) ; cahier §5.3 (3 bases + 14 : « 13 » annoncé, 14 nécessaires).
- **Problème :** telle qu'écrite, l'exigence ne peut pas passer sur cette entrée. Le catalogue du document est en outre relevé sur des scans, « valeurs à valider ».
- **Correction :** « … au plus autant de tickets que le document, sauf coquilles documentées (liste en annexe du cahier) ».

### 24. [BAS] Ambiguïtés de UJ-4 et de FR-27
- **Emplacement :** UJ-4 (« 1 base, 12 chevaux, tickets de 7 : 11 tickets ») ; FR-27 (2ᵉ conséquence) ; FR-22.
- **Problème :** « 1 base, 12 chevaux » se lit comme v = 13, ce qui ferait 15 tickets et 45 € selon le cahier §5.3, alors que le cahier §10 parle de 1 base + 11 autres (v = 12). Le texte est donc incohérent avec le coût affiché. « Les 3 chevaux écartés les plus proches » ne dit pas selon quelle mesure (`top4` ou gain d'échange). FR-22 ne prévoit pas le mode « exploration » (courses de ≥ 14 partants sans marqueur course support) que le cahier §2 prévoit si Q9 échoue.
- **Correction :** écrire « 12 chevaux dont 1 base ». Définir « plus proches » (par exemple `top4` décroissant parmi les non retenus). Ajouter à FR-22 le comportement quand le marqueur course support est introuvable.

## Décompte

| Sévérité | Nombre |
|---|---|
| Critique | 2 |
| Élevé | 9 |
| Moyen | 10 |
| Bas | 3 |
| **Total** | **24** |
