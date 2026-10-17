# Parcours Multi de Marc — récit du porteur de projet (2026-10-17, verbatim)

Marc, 38 ans, joue au Multi le week-end par plaisir, avec un budget fixe qu'il se donne lui-même (30 € par course support). Il lit un peu la presse, sans s'y fier aveuglément. Il se méfie des « systèmes garantis ». Il joue lui-même auprès de son opérateur habituel, et l'app ne place rien.

User story : En tant que joueur occasionnel, je veux obtenir une sélection expliquée pour la course support, voir ce qu'un système de tickets couvre vraiment et ce qu'il coûte, et décider en connaissance de cause de jouer ou non, pour ne pas dépenser sur la foi d'une promesse de « garantie ».

## La séance, dans l'ordre

Samedi, 9 h 40, à la maison, sur son téléphone, connecté.

Il ouvre la course support du jour (écran Multi, depuis la course). L'app lui indique : 18 partants, course éligible. Elle affiche le rappel « L'outil ne place aucun pari ».
Il choisit la méthode 1. La carte porte la mention « hypothèse non validée ». Elle indique aussi que la comparaison avec le marché et avec le classement interne n'est pas encore concluante. Marc ne voit donc pas un oracle.
L'app génère 12 chevaux, règle par règle. Chaque cheval porte la règle qui l'a fait entrer. Exemples : « A fini 1ᵉʳ-3ᵉ : plus forte allocation » ; « A fini 4ᵉ : épreuve la moins dotée ». Un avertissement précise : « Aucun cheval 6ᵉ : créneau repris par le complément ». Marc comprend pourquoi chaque cheval est là.
Il retouche à la main. Il retire un cheval qu'il sait forfait de cœur et en ajoute un autre. La sélection passe en mode « modifiée » : ce n'est plus la méthode 1 pure, et l'app le note.
Il marque un cheval comme base (toggle « base »). Il le veut dans tous ses tickets.
Il compare les options de tickets. Le tableau montre, par taille de ticket k, le nombre de tickets, le coût, le niveau garanti et la probabilité de couverture.
La formule intégrale à 12 chevaux coûte beaucoup plus que ses 30 €. Cette option est marquée « dépasse le budget », sans être cachée.
Un système à 1 base, 12 chevaux, tickets de 7 donne 11 tickets, soit 33 € et 3 tickets physiques. L'app lit : « Si les 4 premiers sont dans votre sélection et incluent votre base, au moins un ticket paie au moins le rapport Multi en 7. » Elle ajoute : « Couverture garantie, pas un gain garanti ».
Il regarde l'évaluation. L'app affiche la probabilité que les 4 premiers soient tous dans sa sélection, la distribution du nombre de chevaux capturés (0 à 4) et un indice de valeur estimé, marqué « hypothèse ». Elle affiche aussi le rapport « Multi en 7 » historique médian, pour qu'il juge si 33 € est raisonnable.
Il importe, s'il veut, le consensus presse (photo d'un tableau). L'app extrait les citations, il les confirme, et la sélection se recalcule avec de vraies données. Sans cet import, la méthode 2 reste en mode dégradé, étiquetée « proxy ».

## Ce qu'il décide à la fin

Marc constate que la probabilité de couverture est modérée et que le rapport en 7 est le plus faible des quatre formules. Il décide donc de ne jouer que le système à 33 €, sans rien ajouter. Il copie les grilles en dossards (export texte), ferme l'app et va les jouer lui-même auprès de son opérateur.

Le soir, la course se termine et la séance est journalisée pour la validation des méthodes. Le lendemain, l'app lui montre « 3 chevaux sur 4 capturés ». Le résultat s'ajoute aux statistiques de la méthode, sans rien embellir.

## Critères d'acceptation

- Chaque cheval affiche la règle qui l'a sélectionné.
- Les mentions « hypothèse non validée », « Couverture garantie, pas un gain garanti » et « Aucun pari placé » sont visibles aux étapes concernées.
- Toute option dépassant le budget est signalée, pas supprimée.
- Chaque système de tickets affiché est vérifié (aucune combinaison non couverte).
- La séance est journalisée avec l'heure des données utilisées, avant le départ.
