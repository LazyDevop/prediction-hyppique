# Réconciliation — Brief projet vs PRD + Addendum

*Document source :* `sources/brief_projet_analyse_hippique.md`
*Documents comparés :* `prd.md`, `addendum.md`
*Date :* 2026-08-22

Méthode : lecture intégrale des trois documents, comparaison section par section du brief contre le PRD/addendum, avec attention explicite portée aux pertes de nuance/ton (pas seulement aux faits factuels manquants).

Conclusion générale : le PRD et l'addendum couvrent fidèlement l'essentiel factuel du brief (périmètre, modèle économique, critères de succès, risque source de données, structuration bootstrap). Les écarts trouvés sont en majorité des pertes de **nuance de raisonnement et de ton épistémique**, pas des faits omis — cohérent avec l'hypothèse de départ. Un écart mérite une attention particulière car il touche à la validité du critère de succès principal (écart significatif n°3).

---

## Écarts significatifs

### 1. Faiblesse assumée disparue : l'angle mort tactique/humain du modèle

**Ce que dit la source (§2, "Faiblesses à assumer honnêtement") :**
> "Le modèle est aveugle à l'information tactique et humaine que les tipsters captent (changement de driver de dernière minute, intention de course rapportée par un entraîneur). Aucune donnée chiffrée ne remplace ça aujourd'hui."

**Ce qu'on trouve dans le PRD/addendum :** rien. Ni dans la Vision (§1), ni dans les Non-Goals (§5), ni dans les Constraints (§9), ni dans l'addendum. Le mot "tipster" n'apparaît que dans un JTBD émotionnel ("suivre aveuglément... l'avis d'un tipster anonyme") et dans la Vision comme repoussoir concurrentiel — jamais comme reconnaissance d'une limite du produit lui-même.

**Pourquoi c'est significatif :** c'est une faiblesse que le porteur de projet a choisi d'assumer explicitement plutôt que de la cacher — un signal de rigueur intellectuelle qui disparaît silencieusement dans le passage en FR/NFR. Un lecteur du PRD seul pourrait croire que le modèle chiffré est présenté comme strictement supérieur au jugement humain d'un tipster, alors que le brief dit l'inverse sur ce point précis.

**Suggestion :** ajouter à l'addendum (section A ou une nouvelle section "Limites assumées du modèle"), et idéalement une ligne dans le PRD §1 Vision ou §5 Non-Goals — au même titre que "le produit ne prétend jamais à une fiabilité garantie", ajouter que le modèle n'intègre aucune information tactique/humaine de dernière minute.

---

### 2. Le benchmark de calibration mesuré (SM-1) n'est pas celui que la faiblesse assumée visait à combler

**Ce que dit la source (§2 et §5) :**
La faiblesse assumée porte sur la comparaison au **jugement d'expert des pronostiqueurs** ("Aucune preuve à ce stade que les probabilités du modèle sont mieux calibrées que le jugement d'expert des pronostiqueurs"). C'est explicitement la question que le produit prétend résoudre (§1 : contrairement aux sites de pronostics).

**Ce qu'on trouve dans le PRD :** SM-1 (§7) mesure la calibration du modèle contre la **probabilité implicite du marché** (`1/cote`), pas contre le jugement des pronostiqueurs/tipsters. C'est la même mesure que dans le brief §5 — mais le brief §5 lui-même ne prétendait mesurer que la calibration vs marché, laissant ouverte, sans la traiter, la question "vs pronostiqueurs" posée en §2.

**Pourquoi c'est significatif :** ce n'est pas une contradiction introduite par le PRD — le brief a déjà cette tension en interne (la faiblesse assumée en §2 pose une question que le critère de succès en §5 ne mesure pas). Mais le PRD, en formalisant SM-1 comme LE critère primaire de succès sans jamais mentionner explicitement que la comparaison "vs jugement humain de pronostiqueur" reste et restera non mesurée, risque de laisser croire qu'un SM-1 positif validerait la promesse centrale du produit face aux sites de pronostics. Ce n'est pas le cas : un modèle mieux calibré que le marché ne prouve pas qu'il bat un bon pronostiqueur humain.

**Suggestion :** ajouter une clarification à l'addendum (ou en note sous SM-1 dans le PRD) : SM-1 valide la calibration vs marché, pas une supériorité démontrée sur le jugement expert humain — cette dernière question reste ouverte et n'est pas mesurée par ce PRD.

---

### 3. Raisonnement causal perdu : pourquoi la traction augmente le risque (justification du bootstrap)

**Ce que dit la source (§6) :**
> "Ce risque grandit avec la traction du produit — plus d'utilisateurs signifie plus de requêtes, plus de visibilité, plus de probabilité d'être bloqué."

C'est la chaîne de raisonnement qui justifie concrètement pourquoi lever des fonds maintenant serait prématuré — pas juste une prudence générale, mais un mécanisme précis (succès commercial → plus de charge sur une source non autorisée → risque de coupure accru).

**Ce qu'on trouve dans le PRD/addendum :** la conclusion est reprise presque mot pour mot (PRD §10, dernier point : "lever des fonds avant reviendrait à vendre une promesse construite sur une fondation encore fragile"), mais le mécanisme causal intermédiaire (traction → requêtes → visibilité → blocage) a disparu. Le PRD §9.3 documente bien le risque source de données, mais sans le relier explicitement à la croissance du produit lui-même.

**Suggestion :** ajouter cette phrase de mécanisme (ou une reformulation équivalente) à l'addendum, section E ou une note sous §9.3/§10 — c'est un argument qui reste pertinent pour l'équipe technique au moment de dimensionner l'ingestion ou d'évaluer une opportunité de croissance rapide.

---

### 4. Édulcoration de l'honnêteté épistémique sur l'absence de seuil chiffré

**Ce que dit la source (§5) :**
> "Aucun seuil chiffré (type "+X % vs marché") n'est fixé à ce stade — **ce serait une précision inventée** avant d'avoir lancé le calibrage."

Le brief nomme explicitement le risque : fixer un seuil maintenant serait une fausse précision, pas juste une décision remise à plus tard.

**Ce qu'on trouve dans le PRD (§7, SM-1) :**
> "pas de seuil chiffré fixé avant d'avoir ce volume."

La conclusion (pas de seuil) est identique, mais la justification qualitative — pourquoi ce serait malhonnête de le faire maintenant, pas juste prématuré — est reformulée de façon neutre et perd le mot "inventée", qui portait un jugement de valeur assumé par le porteur de projet sur la fausse rigueur.

**Suggestion :** écart mineur à la limite du significatif — à la discrétion du PM. Si le ton épistémique du document compte (ce qui semble être le cas vu l'insistance du brief sur "faiblesses à assumer honnêtement"), une reformulation proche de l'original dans le PRD ou l'addendum serait cohérente. Sinon, ignorer : le sens factuel est préservé.

---

## Écarts mineurs

### 5. Stat concurrentielle perdue : bridage à 5 performances gratuites

**Source (§1, §2) :** "L'historique consultable gratuitement est bridé (5 dernières performances sans compte, sur les sites vérifiés)."

**PRD :** absente. Le PRD §1 Vision et §10 parlent d'"historique profond" comme argument différenciateur payant, mais sans reprendre le chiffre concret (5 performances) qui rendait l'argument vérifiable/mémorable.

**Suggestion :** écart mineur, à ignorer ou à ajouter en une ligne dans le PRD §1 si le PM veut garder l'argument chiffré pour un futur pitch produit.

### 6. "10 types de paris" comme chiffre différenciateur explicite

**Source (§2, tableau) :** "10 types de paris (couplé à quinté, ordre/désordre, couplé placé, 2 sur 4) classés par probabilité."

**PRD :** les types sont bien tous couverts (FR-11, FR-12) mais le chiffre "10" comme argument de comparaison marketing/concurrentielle n'est jamais énoncé tel quel.

**Suggestion :** écart mineur à ignorer — c'est un artefact de présentation (tableau comparatif du brief), pas une exigence produit ; le contenu fonctionnel est intégralement repris.

### 7. Différenciateur "modèle recalibrable publiquement" pas formulé comme argument compétitif

**Source (§2, tableau) :** "Pronostic jamais recorrigé publiquement" (concurrents) vs "Modèle calibrable sur données réelles à mesure que l'historique s'accumule" (produit).

**PRD :** le mécanisme existe (JTBD porteur de projet en §2.1, SM-1), mais jamais formulé comme un axe de différenciation face aux pronostiqueurs qui ne publient jamais de bilan de leurs erreurs passées.

**Suggestion :** écart mineur à ignorer, ou à ajouter en une phrase dans la Vision si le PM veut garder cet angle pour la communication produit.

### 8. Forme tableau comparatif → prose narrative

**Source (§2) :** comparaison structurée en tableau à deux colonnes (sites existants vs cet outil).

**PRD (§1 Vision) :** même contenu factuel repris, mais en prose continue — perte de la lisibilité comparative point par point, pas de perte de fond.

**Suggestion :** écart mineur à ignorer — choix de format légitime pour un PRD narratif ; aucune information n'est perdue.

---

## Récapitulatif

| # | Écart | Gravité | Type |
|---|---|---|---|
| 1 | Faiblesse assumée "aveugle au tactique/humain" absente | Significatif | Nuance/faiblesse honnête effacée |
| 2 | Benchmark SM-1 (vs marché) ≠ benchmark visé par la faiblesse assumée (vs jugement expert) | Significatif | Nuance de raisonnement + risque de sur-interprétation d'un futur résultat SM-1 |
| 3 | Raisonnement causal traction→risque perdu | Significatif | Nuance de raisonnement |
| 4 | "précision inventée" édulcoré en "pas fixé" | Significatif (limite mineur) | Ton épistémique |
| 5 | Stat "5 performances gratuites" absente | Mineur | Fait concurrentiel |
| 6 | "10 types de paris" non chiffré comme argument | Mineur | Forme |
| 7 | Différenciateur "recalibrable publiquement" pas formulé comme tel | Mineur | Argument compétitif implicite |
| 8 | Tableau → prose | Mineur | Forme, aucune perte de fond |

**Total : 4 écarts significatifs, 4 écarts mineurs.**
