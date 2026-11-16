---
title: "Proposition de changement de sprint — Module Multi (Epics 5 et 6)"
date: 2026-10-18
workflow: bmad-correct-course (mode batch)
declencheur: _bmad-output/planning-artifacts/implementation-readiness.md (verdict CONCERNS, constats F1 à F29)
decisions_de_reference:
  - _bmad-output/planning-artifacts/multi/reconcile-cdc-multi-prd.md — « D ter », ses précisions, « D quater »
  - arbitrages de rédaction des stories approuvés le 2026-10-18 (rapport de préparation, tableau F7)
approche: Ajustement direct (Direct Adjustment)
portee: Moderate
statut: approuvée par le porteur de projet le 2026-11-15 (« lancer le multi ») — à appliquer avec la proposition du 2026-11-15 (PRD, cahier Multi, spine, UX, epics) ; story 5.4 (Alembic) devenue 7.1
---

# Proposition de changement de sprint — Module Multi (Epics 5 et 6)

> Ce document **ne modifie aucun artefact**. Il décrit, artefact par artefact, les changements à appliquer après approbation. Les choix de conception qu'aucun document n'enregistre encore sont marqués **« [À VALIDER] »** : ce sont les options les plus prudentes compatibles avec les décisions D ter / D quater et avec le code existant. Leur liste complète figure en §5.4.

## 1. Résumé du problème

### 1.1 Déclencheur

La revue de préparation à l'implémentation des Epics 5 et 6 (`implementation-readiness.md`, 2026-10-18) conclut **CONCERNS** : 29 constats (7 élevés, 13 moyens, 9 faibles), aucun critique. L'implémentation ne peut démarrer que par la story 5.1 (tâche humaine). Plusieurs stories (5.5, 5.7, 5.14, 5.15, 5.16, 6.1, 6.6 et, à un moindre degré, 5.4, 5.8, 5.12, 6.5, 6.7) obligeraient un agent de développement à inventer des décisions de fond.

Aucune story n'a démarré : tout le module est en `backlog` (`sprint-status.yaml`). Il n'y a donc rien à défaire dans le code.

### 1.2 Catégorie

- **Mauvaise compréhension d'une exigence d'origine**, révélée par les données réelles : le modèle « une course support unique par jour » vient du document PMU de 2001-2002 et ne correspond plus à la source.
- **Trous de spécification** : décisions jamais écrites (non-partant dans le champ de probabilités, schéma local du débrief, identifiant de course côté téléphone, persistance de la musique, cadence de relecture des partants).
- **Dette de traçabilité** : décisions du 2026-10-18 écrites seulement dans les stories, parfois contraires aux documents amont.

### 1.3 Énoncé du problème

Les documents amont (PRD FR-22, cahier Multi §2, spine AD-10, UX) décrivent une **course support unique par jour**, avec un mode « exploration » quand le marqueur est introuvable. Les données PMU du dépôt montrent un tout autre fonctionnement : le pari MULTI est proposé sur de nombreuses courses le même jour, et le Mini Multi existe à côté. En parallèle, quatre décisions de fond manquent pour que les stories soient réalisables sans invention, et les décisions prises le 2026-10-18 ne sont pas reportées dans les documents qui font foi.

### 1.4 Preuves

| Fait | Source | Vérification |
| --- | --- | --- |
| Le MULTI (et E_MULTI) est proposé sur **19 courses sur 48** le 15/01/2022 | `backend/tests/fixtures/pmu/programme_15012022.json`, champ `courses[].paris[].typePari` | Recompté pour cette proposition : 19 courses MULTI, dont **15 françaises** (R1 à R4) et 4 au Chili (R5, CHL) |
| Les courses étrangères ne sont jamais ingérées | `pmu_client.get_programme(..., pays_filter="FRA")` | Les 4 courses CHL n'entrent pas en base : 15 courses éligibles ce jour-là |
| Le MINI_MULTI est proposé sur **14 courses** de 10 à 13 déclarés ; toutes les courses MULTI ont ≥ 14 déclarés | même fixture | Aucune course ne propose les deux |
| Une course de 16 déclarés (R2C7) ne propose ni l'un ni l'autre | même fixture | — |
| La capture du 18/10/2026 (3 courses, partielle) ne contient que MINI_MULTI | `programme_18102026.json` | — |
| La musique n'est stockée que dans le JSON brut | `models.py` (`Participation` n'a pas de colonne `musique`), `repository.save_partants` (`donnees_brutes`) | — |
| Partants et cotes relus une fois par jour (6 h) ; seul le programme est relu toutes les heures (terrain) | `jobs/scheduler.py`, `jobs/ingest_daily.py` | — |
| Le téléphone ne connaît pas la clé PMU d'une course | `CourseOut` (pas de `numero_reunion` ni `numero_course`), table locale `programme_courses` | — |
| Partants et classement jamais persistés sur l'appareil | `CourseRepository.partants()` (réseau seul), `horsesProvider`, `resultsProvider` (mémoire) | — |
| Un non-partant laissé dans la liste reste dans le champ, et un partant virtuel compenserait son retrait si `nb_partants_course` n'était pas corrigé | `scoring.py` / `scoring.dart` : `n_virtuels = nb_partants_course − n_analyses` | — |
| Les musiques réelles portent des lettres de discipline **majuscules** | `participants_15012022_R1_C1.json` : `DA21DA2A1ADA1A` | Contredit le cahier, annexe D |
| `Repository()` est instancié à l'import de trois modules de routes | `routes_analyse.py`, `routes_chevaux.py`, `routes_courses.py` | Concerne le retrait de `create_all` (5.4) |

Le porteur de projet a déjà tranché F1 et F6 (reconcile, « D quater ») : **toute course dont la liste des paris contient le MULTI est éligible**, plus de course support unique ni de mode exploration ; **Mini Multi hors périmètre** ; **seuils provisoires = règle « hasard + plancher »**.

## 2. Analyse d'impact

### 2.1 Checklist de navigation du changement

Légende : [x] fait · [N/A] sans objet · [!] action nécessaire (détaillée dans cette proposition).

| # | Point | Statut | Constat |
| --- | --- | --- | --- |
| 1.1 | Story déclencheuse | [x] | Aucune story en cours : le déclencheur est la revue de préparation. Stories touchées en premier : 5.1 (contrôles à ajouter), 5.5 (éligibilité), 6.6 (journal). |
| 1.2 | Problème défini | [x] | §1.2 et §1.3 ci-dessus. |
| 1.3 | Preuves | [x] | §1.4 (fixtures et code relus pour cette proposition). |
| 2.1 | L'epic courant peut-il aboutir tel quel ? | [!] | Non. L'Epic 5 aboutit après correction des stories, ajout de 2 stories et découpage de 2 stories. Pas de changement d'objectif. |
| 2.2 | Changements au niveau des epics | [!] | Epic 5 : 16 → 21 stories. Epic 6 : 7 → 8 stories. Aucun epic ajouté ni retiré. |
| 2.3 | Revue des epics restants | [x] | Epic 6 touché (6.1, 6.4, 6.5, 6.6, 6.7). Epics 1 à 4 terminés : non rouverts. Écart signalé à l'Epic 3 (pas de cache des partants), corrigé par une story de l'Epic 5. |
| 2.4 | Epics rendus obsolètes ou nouveaux epics nécessaires | [N/A] | Aucun. |
| 2.5 | Ordre ou priorité des epics | [x] | Inchangé : 5 puis 6. Ordre interne revu (§2.3), sans dépendance en avant. |
| 3.1 | PRD | [!] | FR-22 réécrite ; FR-23, FR-26, FR-28, glossaire, §1, §2, UJ-4, §4.11, §6.1, §6.2, §9.5, §11 et §12 ajustés. MVP inchangé. |
| 3.2 | Architecture | [!] | AD-2, AD-6, AD-7, AD-9, AD-10, AD-11, AD-12, AD-13, schéma Multi et « Deferred ». |
| 3.3 | UX | [!] | EXPERIENCE.md (Réglages, accès, états, débrief, `base-chip`, `formula-row`) ; DESIGN.md (`base-chip`) ; maquette `multi.html` à aligner. |
| 3.4 | Autres artefacts | [!] | `Dockerfile` (COPY `scripts/`, story 5.4) ; nouvelles fixtures PMU à capturer (5.5, 6.1) ; `fixtures/engine_cases.json` (cas non-partant) ; `sprint-status.yaml`. CI/CD et IaC : [N/A] (aucun). |
| 4.1 | Option 1 — Ajustement direct | Viable | Effort moyen, risque faible. |
| 4.2 | Option 2 — Retour arrière | Non viable | Rien n'est implémenté : rien à annuler. |
| 4.3 | Option 3 — Revue du MVP | Non nécessaire | Le MVP reste atteignable ; seule la notion d'éligibilité change. |
| 4.4 | Voie retenue | [x] | Option 1 (§3). |
| 5.1 | Résumé du problème | [x] | §1. |
| 5.2 | Impact epics et artefacts | [x] | §2.2 à §2.6. |
| 5.3 | Voie recommandée et justification | [x] | §3. |
| 5.4 | Impact MVP et plan d'action | [x] | §3 et §5. |
| 5.5 | Plan de passation | [x] | §5. |
| 6.1 | Revue de la checklist | [x] | Tous les points applicables sont traités. |
| 6.2 | Exactitude de la proposition | [x] | Textes AVANT recopiés des fichiers au 2026-10-18. |
| 6.3 | Approbation explicite | [!] | **En attente** du porteur de projet, y compris les « [À VALIDER] ». |
| 6.4 | Mise à jour de `sprint-status.yaml` | [!] | Après approbation (item S-1). |
| 6.5 | Prochaines étapes et passation | [!] | §5, après approbation. |

### 2.2 Impact sur les epics

- **Epic 5 — Pronostiquer le Multi d'une course** : même objectif. L'éligibilité devient « le Multi est proposé sur cette course » (plusieurs courses par jour). Deux stories nouvelles : relecture à la demande des partants et des cotes (F9), réouverture d'une course hors ligne après redémarrage (F10). Deux découpages : 5.7 en trois, 5.12 en deux (F18).
- **Epic 6 — Évaluer le pronostic Multi** : même objectif. Le journal quotidien couvre **toutes les courses éligibles du jour** (environ 15 par jour d'après la fixture) au lieu d'une seule. 6.4 est découpée en deux (F18). La musique est persistée (F5).
- **Epic 3 (terminé)** : écart reconnu, pas de réouverture. FR-14 promettait un cache des courses consultées ; seul le programme est mis en cache. La nouvelle story 5.7 comble l'écart pour les besoins de UJ-4.

### 2.3 Impact sur les stories — table de correspondance ancien → nouveau

La renumérotation conserve l'ordre d'exécution, sans dépendance en avant.

| Ancien | Nouveau | Titre (nouveau) | Nature du changement |
| --- | --- | --- | --- |
| 5.1 | 5.1 | Règles du pari vérifiées et datées | Contrôles ajoutés (F1), empreinte des règles (F13), marquée tâche humaine (F29) |
| 5.2 | 5.2 | Heures de départ fiables (UTC) | Inchangée |
| 5.3 | 5.3 | Cartes plus lisibles dans toute l'app (line-card 3:1, on-gold) | Inchangée |
| 5.4 | 5.4 | Mises à jour du serveur sans perte de données (Alembic) | Baseline, Dockerfile, instanciation à l'import (F20) |
| 5.5 | 5.5 | Savoir si une course est éligible au Multi | **Réécrite** (F1, F2, F4, F28) |
| — | **5.6** | Rafraîchir les partants et les cotes d'une course avant le départ | **Nouvelle** (F9) |
| — | **5.7** | Rouvrir une course hors ligne après redémarrage (cache local v2) | **Nouvelle** (F10, F2 côté Dart, F4) |
| 5.6 | 5.8 | Catalogue de systèmes vérifié | Section `verification` des cas partagés (F17) |
| 5.7 | **5.9** | Moteur Multi Python : couverture et sélection pour une taille | **Découpage** (F18) + dossards (F11) + drapeaux (F12) |
| 5.7 | **5.10** | Moteur Multi Python : chevaux les plus probables, systèmes par formule, relabellement | **Découpage** (F18) |
| 5.7 | **5.11** | Moteur Multi Python : évaluation, non-partant et bilan d'arrivée | **Découpage** (F18) + non-partant (F2) |
| 5.8 | 5.12 | Indice de confiance et explications (Python), registre, règle provisoire des seuils | **Réécrite** (F6, F12, F13, F1) |
| 5.9 | 5.13 | API du pronostic Multi (contexte, recommandation, systèmes, vérifier, évaluer) | Clé PMU (F4), plus d'exploration (F1) |
| 5.10 | 5.14 | Moteur Multi en Dart à parité | Rejeu `verification` et `drapeaux` (F17, F12) |
| 5.11 | 5.15 | Confiance et explications en Dart + table de libellés FR | `versions.dart`, empreinte des règles (F13) |
| 5.12 | **5.16** | Écran Multi — accès, taille et confiance | **Découpage** (F18) + raisons (F1, F11) |
| 5.12 | **5.17** | Écran Multi — sélection, chevaux les plus probables, évaluation, états | **Découpage** (F18) + tickets économisés (F8) |
| 5.13 | 5.18 | Écran Multi — grilles | Puce de base suit la formule affichée (F8, F25) |
| 5.14 | 5.19 | Retoucher sa sélection et gérer les non-partants | **Réécrite** (F2, F9, F25) |
| 5.15 | 5.20 | Retenir son pronostic, même hors ligne (sqflite v3, gel au départ, purge 90 j) | **Réécrite** (F3, F26, F19) |
| 5.16 | 5.21 | Le débrief du lendemain | **Réécrite** (F3, F4, F27, F1) |
| 6.1 | 6.1 | Données de la dernière course pour la méthode 1 | Musique persistée (F5), règle du rang (F14), captures (F28) |
| 6.2 | 6.2 | Comparateurs méthode 1 et marché | Inchangée |
| 6.3 | 6.3 | Section « Autres méthodes » à l'écran | Inchangée |
| 6.4 | **6.4** | Backtest : harnais sans fuite et périodes figées | **Découpage** (F18) |
| 6.4 | **6.5** | Backtest : stratégies, métriques et export | **Découpage** (F18) |
| 6.5 | 6.6 | Pilote et import en production | `type_periode`, `gelee` (F16) ; F15 différé |
| 6.6 | 6.7 | Journalisation quotidienne avant le départ | **Réécrite** (F1, F9) |
| 6.7 | 6.8 | Performances et statut du modèle affichés | Statut par comparateur, cache local (F16) |

### 2.4 Conflits entre artefacts (C1 à C15 du rapport) — résolution

| # | Conflit | Résolution | Items |
| --- | --- | --- | --- |
| C1 | Contexte « avec les partants » contre objet `multi` dans `/courses` | Objet `multi` de `CourseOut` retenu | A-4, C-15 |
| C2 | Deux tables locales contre colonnes supplémentaires | Version 2 (cache de course) + version 3 (tables Multi) | A-6, C-12, E-11, E-21 |
| C3 | Copie du seul catalogue contre miroirs backend | Patron « miroir validé par test » écrit dans AD-2 | A-3, A-5, A-8, A-9 |
| C4 | « Rien n'est inventé » contre seuils provisoires | Exception datée (D quater) dans le cahier et le PRD | C-2, C-10, P-8, P-13 |
| C5 | Rang depuis la musique contre liste détaillée | Liste détaillée prioritaire [À VALIDER] | C-6, C-17, E-23 |
| C6 | Lettre de discipline minuscule contre majuscule | Majuscule (données réelles) | C-17 |
| C7 | Allocation « absente » contre présente | Le code fait foi | C-6 |
| C8 | Texte de garantie | Aligné sur PRD et UX | C-9 |
| C9 | Course support unique contre ~19 courses MULTI | D quater | P-1 à P-6, C-5, A-4, A-7, U-2 à U-9, E-9, E-26 |
| C10 | Sauvegarde SQLite différée contre décidée | Décidée (AD-13) | A-10, A-12 |
| C11 | Horaire du journal différé contre 30 min | Décidé (AD-10) | A-7, A-12, C-12 |
| C12 | Recalcul de `top4` interdit contre non-partant à retirer | Le cœur de scoring recalcule ; le moteur Multi ne renormalise jamais | A-4, C-11, P-7 |
| C13 | Clé PMU contre id auto-incrémenté | Clé PMU pour toute route et tout enregistrement Multi | A-9, C-14, P-10 |
| C14 | Cahier v2 cité par le PRD | v3 | P-5 |
| C15 | « Aucun contrat UX formel » | Mis à jour | E-1, E-2 |

### 2.5 Impact technique

- **Backend** : colonnes `participations.non_partant` (5.5) et `participations.musique` (6.1) ; table `multi_course` avec `multi_propose` et `mini_multi_propose` au lieu de `est_course_support` ; exclusion des non-partants de l'entrée du scoring (`get_horses_for_course`, `/analyse`) ; nouvelles routes `GET /multi/courses/{cle_course}` et `POST /multi/courses/{cle_course}/rafraichir` ; `CourseOut` expose `cle_course`, `numero_reunion`, `numero_course` ; miroirs `regles.py`, `parametres.py`, `versions.py` ; `COPY scripts` dans le `Dockerfile`.
- **Volume d'appels PMU** (PRD OQ 6) : ingestion de 6 h inchangée ; au plus **un appel `participants` par course éligible et par jour** pour le journal (environ 15) ; rafraîchissements à la demande limités à un appel toutes les 5 minutes par course, seulement avant le départ ; aucune relecture périodique de toutes les courses ; captures ponctuelles de fixtures (moins de 10 appels).
- **Mobile** : base locale v2 (cache des partants, clé, contexte Multi) puis v3 (tables Multi) ; exclusion des non-partants dans l'adaptateur Dart du scoring, avec un cas partagé dans `fixtures/engine_cases.json` ; recalcul automatique du classement quand un non-partant arrive.
- **Moteur Multi** : n'enlève jamais un cheval de `P_ens` ; la simulation de non-partant ne renvoie que la requalification des tickets.

### 2.6 Décision par constat

| Constat | Résolution | Où | Items |
| --- | --- | --- | --- |
| F1 | **Corrigé maintenant** selon D quater : éligibilité par la liste des paris, Mini Multi hors périmètre, plus d'exploration, journal de toutes les courses éligibles | PRD, cahier, spine, UX, epics | P-1 à P-6, P-11 à P-13, C-1, C-3 à C-5, C-10, C-16, A-4, A-5, A-7, A-12, U-2 à U-4, U-7 à U-9, U-14, E-3, E-5, E-7, E-9, E-14, E-15, E-18, E-22, E-24, E-26 |
| F2 | **Corrigé maintenant** : un non-partant sort de l'entrée du scoring ; le champ compte les déclarés moins les non-partants ; le cœur de scoring recalcule ; le moteur Multi consomme sa sortie | spine AD-6, cahier §4.0 et §6.6, PRD FR-23, stories 5.5, 5.7, 5.11, 5.19 | A-4, C-7, C-11, P-7, E-9, E-11, E-13, E-20 |
| F3 | **Corrigé maintenant** : schéma local v3 complet, règle d'écriture de `recommandation_consultee`, arrivée côté `recommandation_consultee` | spine AD-9, cahier §7, stories 5.20, 5.21 | A-6, C-12, E-21, E-22 |
| F4 | **Corrigé maintenant** : clé PMU de bout en bout (`cle_course` sur `CourseOut`, routes Multi par clé, `course_id` → `cle_course`) | spine AD-12, cahier §10, PRD §6.1, stories 5.5, 5.7, 5.13, 5.21 | A-9, C-14, P-10, E-9, E-11, E-15, E-22 |
| F5 | **Corrigé maintenant** : `participations.musique` (Alembic), alimentée par `save_partants`, lignes anciennes remplies par une commande ponctuelle [À VALIDER] | story 6.1, spine AD-10 | A-7, E-23 |
| F6 | **Corrigé maintenant** : règle D quater dans 5.12 (ex-5.8), exception « provisoire » au cahier, PRD OQ 10 marquée « provisoire décidé » | PRD, cahier, story 5.12 | P-8, P-13, P-14, C-2, C-10, E-14 |
| F7 | **Corrigé maintenant** : chaque arbitrage du 2026-10-18 est reporté en amont (tableau ci-dessous) | PRD, cahier, spine | voir §4.7 |
| F8 | **Corrigé maintenant** : la puce de base affiche les tickets économisés pour la formule affichée | UX, stories 5.17, 5.18 | U-6, U-15, E-19, E-20 ; maquette à aligner (bmad-ux) |
| F9 | **Corrigé maintenant** : relecture à la demande (route limitée), relecture avant journalisation, pas de relecture périodique | nouvelle story 5.6, story 6.7, spine AD-10, PRD OQ 6 | A-7, P-13, E-10, E-26 |
| F10 | **Corrigé maintenant** : nouvelle story 5.7 (cache local des partants, réouverture hors ligne) ; écart Epic 3 signalé | PRD FR-23, spine AD-9, UX | P-7, A-6, U-13, E-11 |
| F11 | **Corrigé maintenant** : sans dossard = dans le champ, non sélectionnable ; dossards en double = Multi bloqué ; course saisie à la main = pas de Multi [À VALIDER] | PRD FR-22, cahier §4.1, stories 5.9, 5.16 | P-6, C-8, E-13, E-18 |
| F12 | **Corrigé maintenant** : drapeaux définis dans `constantes_moteur`, calculés par l'adaptateur des deux langages | cahier §6.4, stories 5.9, 5.12, 5.14 | C-10, E-13, E-14, E-16 |
| F13 | **Corrigé maintenant** : miroirs `versions.py` / `versions.dart`, constante `EMPREINTE_REGLES` dans `regles.py` / `regles.dart` | spine AD-2, AD-12, stories 5.1, 5.12, 5.15 | A-3, A-9, E-7, E-14, E-17 |
| F14 | **Corrigé maintenant** : liste détaillée prioritaire, musique en complément [À VALIDER] | cahier §3 et annexe D, story 6.1 | C-6, C-17, E-23 |
| F15 | **Différé** (§5.3) | — | C-13 (marqueur), E-25 |
| F16 | **Corrigé maintenant** : `type_periode`, `gelee` ; statut par comparateur dans le contexte ; cache local des performances | stories 6.6, 6.8, spine AD-9 | A-6, E-25, E-27 |
| F17 | **Corrigé maintenant** : section `verification` écrite par 5.8, rejouée par 5.14 | stories 5.8, 5.14 | E-12, E-16 |
| F18 | **Corrigé maintenant** : 5.7 → 5.9/5.10/5.11 ; 5.12 → 5.16/5.17 ; 6.4 → 6.4/6.5 | epics | E-13, E-18, E-24 |
| F19 | **Corrigé maintenant** : forme des Réglages Multi [À VALIDER] | UX, story 5.20 | U-1, E-21 |
| F20 | **Corrigé maintenant** | spine AD-13, story 5.4 | A-10, E-8 |
| F21 | **Corrigé maintenant** : lignes NFR dans la table de couverture | epics | E-29 |
| F22 | **Corrigé maintenant** | epics | E-1, E-2 |
| F23 | **Corrigé maintenant** | PRD §4.11 | P-5 |
| F24 | **Corrigé maintenant** | cahier §5.4 | C-9 |
| F25 | **Corrigé maintenant** : formule par défaut sans mémoire (UX alignée sur la story) ; écarté touché → feuille réduite (story alignée sur l'UX) [À VALIDER] | UX, stories 5.18, 5.19 | U-5, E-19, E-20 |
| F26 | **Corrigé maintenant** | story 5.20 | E-21 |
| F27 | **Corrigé maintenant** avec F3 : débrief sans « Autres méthodes » [À VALIDER] | UX, story 5.21 | U-11, E-22 |
| F28 | **Corrigé maintenant** : les stories exigent les captures et disent leur volume | stories 5.5, 6.1 | E-9, E-23 |
| F29 | **Corrigé maintenant** | sprint-status, story 5.1 | S-1, E-7 |

## 3. Approche recommandée

**Option retenue : Ajustement direct (Option 1).**

- **Pourquoi pas un retour arrière** : aucune story Multi n'est commencée ; il n'y a rien à annuler.
- **Pourquoi pas une revue du MVP** : le MVP reste atteignable et l'angle du module (D ter) ne change pas. D quater simplifie même le produit : plus de mode exploration, une seule règle d'éligibilité lisible dans la source. Le seul effet de périmètre (Mini Multi) est déjà tranché.
- **Pourquoi l'ajustement direct** : tous les constats se corrigent dans les documents, sans refonte. L'architecture hexagonale, la parité par fixtures et l'immuabilité du journal restent intactes.

| Critère | Évaluation |
| --- | --- |
| Effort | **Moyen** : une passe documentaire (PRD, cahier, spine, UX, epics, sprint-status), environ 1 à 2 jours d'agent. Côté implémentation : +5 stories nettes dans l'Epic 5 et +1 dans l'Epic 6, dont 3 viennent seulement de découpages. |
| Risque | **Faible à moyen**. Le principal risque reste la vérification humaine des règles (5.1), qui peut encore arrêter le chantier. Risques secondaires : volume d'appels PMU (contenu par les limites ci-dessus) ; seuils provisoires peu discriminants tant que le pilote n'a pas tourné (D quater les plancher). |
| Calendrier | Aucun calendrier fixe (rythme bootstrap). Ordre : 5.1 (humain) en parallèle de l'application de cette proposition, puis relance de la revue de préparation avant 5.5. 5.2 à 5.4 peuvent démarrer dès 5.1 terminée. |
| Impact MVP | Aucun retrait de fonctionnalité. FR-22 change de règle ; FR-23, FR-26 et FR-28 gagnent des précisions. |

## 4. Propositions détaillées

Conventions :

- **Identifiants** : P-n (PRD), C-n (cahier), A-n (spine), U-n (UX), E-n (epics), S-n (sprint-status), R-n (reconcile).
- **AVANT** cite le texte exact du fichier au 2026-10-18. Quand seule une partie d'un paragraphe change, l'AVANT cite cette partie : remplacer cette chaîne par l'APRÈS.
- **Langue** : PRD, cahier, UX et epics sont rédigés en français ; la spine en anglais. Les textes APRÈS suivent la langue de leur document.

### 4.1 PRD — `prds/prd-prediction-hyppique-2026-08-22/prd.md`

#### P-1 — §1 Vision (F1)

AVANT :
> Pour le **Multi**, le même modèle donne un pronostic : sur la course support, et pour le nombre de chevaux que le parieur choisit,

APRÈS :
> Pour le **Multi**, le même modèle donne un pronostic : sur chaque course où le PMU propose le Multi, et pour le nombre de chevaux que le parieur choisit,

Justification : D quater, plusieurs courses par jour.

#### P-2 — §2.1 Jobs To Be Done, ligne « Fonctionnel (Multi) » (F1)

AVANT :
> - **Fonctionnel (Multi)** : pour la course support, obtenir un pronostic expliqué

APRÈS :
> - **Fonctionnel (Multi)** : pour une course où le Multi est proposé, obtenir un pronostic expliqué

Justification : D quater.

#### P-3 — §2.3 UJ-4, état d'entrée (F1)

AVANT :
> - **État d'entrée :** programme du jour chargé ; la course support a 18 partants.

APRÈS :
> - **État d'entrée :** programme du jour chargé ; une course où le Multi est proposé a 18 partants.

Justification : D quater.

#### P-4 — §3 Glossaire (F1)

AVANT :
> - **Course support** — La course du jour sur laquelle le Multi est proposé (≥ 14 partants déclarés).

APRÈS :
> - **Course éligible (Multi)** — Course française ingérée depuis la source PMU dont la liste des paris contient le Multi. Plusieurs courses le sont chaque jour (19 sur 48 le 15/01/2022, dont 15 françaises). Le Mini Multi est hors périmètre. Remplace la notion de « course support » (décision D quater du 2026-10-18).

AVANT :
> - **Pronostic (Multi)** — Ce que le module propose pour une course support :

APRÈS :
> - **Pronostic (Multi)** — Ce que le module propose pour une course éligible :

Justification : D quater.

#### P-5 — §4.11 Description (F1, F23)

AVANT :
> **Description :** Pour la course support, le modèle propose un pronostic :

APRÈS :
> **Description :** Pour une course éligible (FR-22), le modèle propose un pronostic :

AVANT :
> est dans `cahier_des_charges_module_multi.md` (v2), référence normative non dupliquée ici, **recadrée par la décision du porteur de projet du 2026-10-18** (`multi/reconcile-cdc-multi-prd.md`, section « D ter »), qui fait foi en cas d'écart.

APRÈS :
> est dans `cahier_des_charges_module_multi.md` (v3), référence normative non dupliquée ici, **recadrée par les décisions du porteur de projet du 2026-10-18** (`multi/reconcile-cdc-multi-prd.md`, sections « D ter » et « D quater »), qui font foi en cas d'écart.

Justification : D quater ; le cahier est en v3 (F23, C14).

#### P-6 — FR-22, texte complet (F1, F11)

AVANT (de `#### FR-22: Éligibilité d'une course au Multi` jusqu'à la ligne « - Les partants déclarés mais non analysés sont signalés … »  incluse) :

> #### FR-22: Éligibilité d'une course au Multi
> L'utilisateur voit, pour une course, si elle est éligible au Multi (course support, ≥ 14 partants déclarés) et peut ouvrir l'écran Multi depuis celle-ci.
>
> **Consequences (testable):**
> - Une course non éligible affiche la raison (pas course support, moins de 14 partants) au lieu d'un pronostic.
> - Si le marqueur « course support » est introuvable dans la source (Open Question 9), les courses de ≥ 14 partants restent accessibles en mode « exploration — course support non confirmée ».
> - Les règles du pari (formules, tickets, non-partants, ex-aequo, arrivée dégradée) ont une seule source de référence, partagée par le backend et l'application, avec leur provenance et une date de dernière vérification sur pmu.fr ; sans cette date, aucune grille n'est affichée (§9.5).
> - Les partants déclarés mais non analysés sont signalés (« N partants non analysés, non sélectionnables ») ; l'utilisateur peut les analyser (FR-6) pour les rendre sélectionnables.

APRÈS :

> #### FR-22: Éligibilité d'une course au Multi
> L'utilisateur voit, pour chaque course du programme, si le Multi y est proposé, et peut ouvrir l'écran Multi depuis une course éligible.
>
> **Consequences (testable):**
> - Une course est éligible si la liste des paris que la source PMU publie pour elle contient le Multi. Plusieurs courses peuvent l'être le même jour (décision D quater du 2026-10-18). Si les règles vérifiées sur pmu.fr (§9.5) fixent un nombre minimal de partants déclarés, cette condition s'ajoute ; un non-partant survenu après la déclaration ne fait pas perdre l'éligibilité.
> - Le Mini Multi est hors périmètre : une course qui ne propose que le Mini Multi est non éligible, et l'écran le dit.
> - Une course non éligible affiche sa raison (Multi non proposé, Mini Multi seulement, liste des paris indisponible) au lieu d'un pronostic. Il n'existe pas de mode « exploration ».
> - Seules les courses issues de l'ingestion PMU (courses françaises, §5) portent un contexte Multi. Une course saisie à la main ou importée par photo n'ouvre pas le Multi. `[À VALIDER]`
> - Les règles du pari (formules, tickets, non-partants, ex-aequo, arrivée dégradée) ont une seule source de référence, partagée par le backend et l'application, avec leur provenance et une date de dernière vérification sur pmu.fr ; sans cette date, aucune grille n'est affichée (§9.5).
> - Les partants déclarés mais non analysés sont signalés (« N partants non analysés, non sélectionnables ») ; l'utilisateur peut les analyser (FR-6) pour les rendre sélectionnables. Un cheval sans dossard reste dans le calcul des probabilités mais n'est pas sélectionnable ; des dossards en double bloquent le Multi jusqu'à correction de la liste des partants. `[À VALIDER]`

Justification : D quater (F1) ; F11 (cheval sans dossard, course hors ingestion).

#### P-7 — FR-23, non-partant et hors ligne (F2, F9, F10)

AVANT :
> - L'information de non-partant parvient à l'appareil par le rafraîchissement explicite de la course (réseau) ou, sans réseau, par l'action « marquer non-partant » de l'utilisateur. Le nouveau pronostic est recalculé localement, et l'écran montre à part ce que deviennent les tickets du pronostic retenu (requalification selon les règles du pari).

APRÈS :
> - L'information de non-partant parvient à l'appareil par le rafraîchissement explicite de la course (réseau : le backend relit alors les partants et les cotes de cette course à la source) ou, sans réseau, par l'action « marquer non-partant » de l'utilisateur. Un non-partant sort du champ : le moteur de scoring recalcule les probabilités sans lui (aucun partant virtuel ne le remplace), puis le pronostic est recalculé localement ; Résultats et Multi montrent le même champ. L'écran montre à part ce que deviennent les tickets du pronostic retenu (requalification selon les règles du pari).
> - Une course déjà ouverte se rouvre sans réseau après fermeture de l'application, avec les partants tels que reçus lors du dernier chargement réussi ; les modifications manuelles de la liste des partants ne sont pas conservées après fermeture. `[À VALIDER]`

Justification : F2 (décision d'architecture AD-6 : le cœur de scoring recalcule, le moteur Multi ne renormalise jamais) ; F9 ; F10.

#### P-8 — FR-26, valeurs par défaut des seuils (F6)

AVANT :
> - Leurs valeurs par défaut sont fixées par le pilote d'évaluation, qui tourne sur l'historique (backtest) et ne dépend pas de la journalisation quotidienne ; jusque-là, l'écran affiche « seuils provisoires ».

APRÈS :
> - Leurs valeurs par défaut sont fixées par le pilote d'évaluation, qui tourne sur l'historique (backtest) et ne dépend pas de la journalisation quotidienne. Jusque-là, une règle provisoire décidée par le porteur de projet le 2026-10-18 (D quater) s'applique et l'écran affiche « seuils provisoires ». Avec `p_hasard(v) = C(v,4) / C(n,4)` (n = chevaux du champ, non-partants exclus) : « confiance moyenne » si la probabilité de couverture ≥ min(max(2 × p_hasard ; 0,15) ; 0,90), « confiance élevée » si ≥ min(max(3 × p_hasard ; 0,35) ; 0,95), un cran de moins si la course est très ouverte ou les données fragiles. Une valeur saisie par l'utilisateur pour une taille remplace la règle pour cette taille.

Justification : F6, C4.

#### P-9 — FR-28, heure de départ inconnue (F7)

AVANT :
> - L'action « Je retiens ce pronostic » enregistre une seule sélection par course (avec bases et système), remplaçable jusqu'à l'heure de départ, figée ensuite ; c'est la seule source du débrief de l'utilisateur (FR-30).

APRÈS :
> - L'action « Je retiens ce pronostic » enregistre une seule sélection par course (avec bases et système), remplaçable jusqu'à l'heure de départ, figée ensuite ; si l'heure de départ est inconnue, le pronostic reste remplaçable jusqu'à la fin du jour de la course (heure de Paris). C'est la seule source du débrief de l'utilisateur (FR-30).

Justification : arbitrage approuvé le 2026-10-18 (F7).

#### P-10 — §6.1, endpoints de l'incrément Multi 1 (F4, F9)

AVANT :
> endpoints `/courses/{id}/multi/eligibilite`, `/multi/recommandation`, `/multi/systemes`, `/multi/verifier`, `/multi/evaluer` (à la racine de l'API, sauf l'éligibilité).

APRÈS :
> endpoints `GET /multi/courses/{cle_course}` (contexte Multi, non-partants et arrivée d'une course désignée par sa clé PMU `AAAAMMJJ-Rn-Cn`), `POST /multi/courses/{cle_course}/rafraichir` (relecture des partants et des cotes, avant le départ seulement), `/multi/recommandation`, `/multi/systemes`, `/multi/verifier`, `/multi/evaluer`. `[À VALIDER : noms des routes]`

Justification : F4 (AD-12, la clé PMU identifie une course entre systèmes) ; F9.

#### P-11 — §6.2 Out of Scope, ligne Multi (F1)

AVANT :
> - Module Multi : méthode 2 et import du consensus presse ; systèmes mixtes (tickets de 5 et 6) ; choix du système parmi les systèmes équivalents selon la valeur ; Flexi.

APRÈS :
> - Module Multi : méthode 2 et import du consensus presse ; systèmes mixtes (tickets de 5 et 6) ; choix du système parmi les systèmes équivalents selon la valeur ; Flexi ; **Mini Multi** (à réétudier après la vérification de ses règles, story 5.1 — décision D quater du 2026-10-18).

Justification : D quater.

#### P-12 — §9.5 Règles du Multi (F1)

AVANT :
> Les règles du pari Multi (formules, tickets, tickets physiques, jours de course support, seuil de 14 partants, non-partants, ex-aequo, arrivée dégradée) viennent d'un document PMU de 2001-2002.

APRÈS :
> Les règles du pari Multi (formules, tickets, tickets physiques, courses sur lesquelles le Multi est proposé, seuil éventuel de partants déclarés, non-partants, ex-aequo, arrivée dégradée, statut du Mini Multi) viennent d'un document PMU de 2001-2002.

Justification : D quater, contrôles ajoutés à 5.1.

#### P-13 — §11 Open Questions 6, 8, 9, 10 (F1, F6, F9)

AVANT :
> 6. Fréquence et volume d'ingestion quotidienne raisonnables pour ne pas solliciter excessivement une source non officielle (§9.3) — à décider avant d'automatiser le job d'ingestion.

APRÈS :
> 6. Fréquence et volume d'ingestion quotidienne raisonnables pour ne pas solliciter excessivement une source non officielle (§9.3) — à décider avant d'automatiser le job d'ingestion. *Volet Multi décidé le 2026-10-18 : pas de relecture périodique des partants ; au plus une relecture par course éligible et par jour avant la journalisation, et des relectures à la demande limitées à une toutes les 5 minutes par course, avant le départ seulement.* `[À VALIDER]`

AVANT :
> 8. Règles du Multi (formules, tickets, jours de course support, seuil de 14 partants, non-partants, ex-aequo, arrivée dégradée) : la source date de 2001-2002

APRÈS :
> 8. Règles du Multi (formules, tickets, courses où le Multi est proposé, seuil éventuel de partants, non-partants, ex-aequo, arrivée dégradée, statut du Mini Multi) : la source date de 2001-2002

AVANT :
> 9. Emplacement du marqueur « course support » dans la source PMU — à découvrir dans l'adaptateur `pmu_client.py` ; en attendant, mode « exploration » (FR-22). *Volet « rapports Multi définitifs » clos le 2026-10-18 : rapports hors périmètre, seule l'arrivée officielle sert.*

APRÈS :
> 9. ~~Emplacement du marqueur « course support » dans la source PMU.~~ **Close le 2026-10-18** : l'éligibilité se lit dans la liste des paris de la course (`paris[].typePari` contient `MULTI`), plus de course support unique ni de mode « exploration » (D quater). *Volet « rapports Multi définitifs » clos le 2026-10-18 : rapports hors périmètre, seule l'arrivée officielle sert.*

AVANT :
> 10. Valeurs par défaut des seuils de l'indice de confiance Multi (FR-26), qui dépendent de la taille de la sélection — fixées par le pilote d'évaluation (cahier Multi §8.4), affichées « provisoires » jusque-là.

APRÈS :
> 10. Valeurs par défaut des seuils de l'indice de confiance Multi (FR-26), qui dépendent de la taille de la sélection — fixées par le pilote d'évaluation (cahier Multi §8.4), affichées « provisoires » jusque-là. **Provisoire décidé le 2026-10-18 (D quater)** : règle « hasard + plancher » de FR-26, remplacée par le pilote.

Justification : D quater, F6, F9.

#### P-14 — §12 Assumptions Index, lignes ajoutées en fin de liste (F1, F6, F7)

AVANT (dernière ligne actuelle) :
> - FR-30 — Débrief sur le pronostic du modèle et sur le pronostic retenu par l'utilisateur (conservé sur l'appareil) : confirmé par le porteur de projet le 2026-10-17, maintenu par le recadrage du 2026-10-18.

APRÈS (la ligne est conservée, suivie de) :
> - FR-22, §6.2 — Éligibilité par la liste des paris PMU (plusieurs courses par jour), abandon de la course support unique et du mode exploration, Mini Multi hors périmètre : décision du porteur de projet du 2026-10-18 (D quater), après le constat F1 de la revue de préparation.
> - FR-26 — Règle provisoire « hasard + plancher » des seuils de confiance : décision du porteur de projet du 2026-10-18 (D quater), en exception au principe « rien n'est inventé » du cahier Multi, jusqu'au pilote.
> - FR-23, FR-28 — Non-partant retiré du champ et recalculé par le moteur de scoring ; heure de départ inconnue → pronostic remplaçable jusqu'à la fin du jour de la course (Paris) : correction de cap du 2026-10-18 (`sprint-change-proposal-2026-10-18.md`).

### 4.2 Cahier Multi — `docs/cahier_des_charges_module_multi.md`

#### C-1 — En-tête, nouvelle version (F1, F7)

AVANT :
> > **Version 2 — 2026-10-17.** Réalignée sur le PRD et l'architecture après

APRÈS (insérer avant cette ligne) :
> > **Version 3.1 — 2026-10-18 (correction de cap).** Décisions « D quater » du
> > reconcile et proposition `sprint-change-proposal-2026-10-18.md` : éligibilité
> > par la liste des paris PMU (plusieurs courses par jour, plus de course support
> > unique ni de mode exploration) ; Mini Multi hors périmètre ; règle provisoire
> > des seuils de confiance ; non-partant retiré du champ par le moteur de scoring ;
> > clé PMU dans l'API ; arbitrages d'implémentation du 2026-10-18 reportés.
> >

Justification : traçabilité.

#### C-2 — §0.3, principe « Rien n'est inventé » (F6, C4)

AVANT :
> - **Rien n'est inventé** : aucun seuil de l'indice de confiance n'est codé « à
>   l'estime ». Les valeurs par défaut des seuils sont fixées par le pilote
>   (section 8.4) et affichées « provisoires » jusque-là.

APRÈS :
> - **Rien n'est inventé** : aucun seuil de l'indice de confiance n'est codé « à
>   l'estime ». Les valeurs par défaut des seuils sont fixées par le pilote
>   (section 8.4) et affichées « provisoires » jusque-là. **Seule exception**,
>   décidée par le porteur de projet le 2026-10-18 (D quater) : la règle provisoire
>   « hasard + plancher » de la section 6.4, étiquetée « provisoire » à l'écran et
>   remplacée par le pilote.

#### C-3 — §1 Périmètre, hors périmètre (F1)

AVANT :
> (couverts par le backend 7.12) ; Flexi (voir section 12) ; courses hors France et
> PMUC (PRD §5).

APRÈS :
> (couverts par le backend 7.12) ; Flexi (voir section 12) ; **Mini Multi** (à
> réétudier après la vérification de ses règles) ; courses hors France et PMUC
> (PRD §5).

#### C-4 — §2, commentaire de `PARTANTS_DECLARES_MIN` (F1)

AVANT :
> PARTANTS_DECLARES_MIN = 14      # course support : 14 partants déclarés au minimum

APRÈS :
> PARTANTS_DECLARES_MIN = 14      # document 2001-2002 ; condition d'éligibilité seulement si la vérification pmu.fr la confirme

#### C-5 — §2, paragraphe « Éligibilité » (F1)

AVANT :
> **Éligibilité d'une course support.** Une course par jour, 14 partants déclarés au
> minimum. Les jours de Quinté+ (document : mar, mer, jeu, sam, dim) c'est une autre
> course de la réunion du Quinté+ ; les jours sans Quinté+ (lun, ven) c'est la course
> du 2sur4. **À vérifier** : ces jours ont pu changer depuis 2002. Le backend détecte
> la course support par la liste `paris` de la course (champ exact à confirmer en
> phase de découverte) ; à défaut, il propose « courses de ≥ 14 partants » en mode
> exploration (mention « course non support du Multi »).

APRÈS :
> **Éligibilité d'une course (D quater, 2026-10-18).** Le document de 2001-2002
> décrivait une course support unique par jour. La source actuelle propose le Multi
> sur de nombreuses courses le même jour (fixture du 15/01/2022 : 19 courses sur 48,
> dont 15 françaises, toutes de 14 à 18 déclarés). **Règle** : une course est
> éligible si la liste des paris de la course (`paris[].typePari`, lue par
> `pmu_client.py` seul) contient `MULTI` ; `E_MULTI` seul ne suffit pas. Si la
> vérification pmu.fr (story 5.1) confirme un nombre minimal de partants déclarés,
> il s'ajoute à la règle. Liste absente ou illisible → non éligible, raison
> « liste des paris indisponible ». Course ne proposant que `MINI_MULTI` → non
> éligible, raison « Mini Multi non pris en charge » (hors périmètre). Il n'existe
> **ni course support unique ni mode exploration**. Les courses hors France ne sont
> pas ingérées (PRD §5). `[À VALIDER : MULTI exact, raisons distinctes]`

#### C-6 — §3 Données d'entrée (F7, F14, F5)

AVANT :
> | Allocation de la dernière course | `performances-detaillees` → `coursesCourues[0].allocation` | `allocation` | **Existant dans l'API mais absent du schéma 6.3** → ajouter la colonne | M1 |

APRÈS :
> | Allocation de la dernière course | `performances-detaillees` → `coursesCourues[0].allocation` | `allocation` | **Déjà stockée** (`performances_historiques.allocation`, alimentée par `get_historique`) | M1 |
> | Musique | `participants` → `musique` | `musique` | **À persister** : `participations.musique` (story 6.1) ; le JSON brut n'est jamais relu hors de `pmu_client.py` | M1, explications |

AVANT :
> **Piège sur le rang.** Le backend 4.3 note que `NON_PLACE` signifie « hors des
> ~5-6 premiers affichés ». Si seuls 5 sont affichés, un 6ᵉ est indiscernable d'un
> 7ᵉ. **Règle** : le rang de la dernière course est pris dans la **musique** quand il
> est lisible (chiffre 1-9 ; `0` = non placé), la liste détaillée ne servant qu'au
> recoupement. En cas de désaccord, `source_rang = "musique"` et un avertissement
> est ajouté. Valider le décodeur de musique sur des chaînes réelles (annexe D).

APRÈS :
> **Piège sur le rang.** Le backend 4.3 note que `NON_PLACE` signifie « hors des
> ~5-6 premiers affichés ». Si seuls 5 sont affichés, un 6ᵉ est indiscernable d'un
> 7ᵉ. **Règle (tranchée le 2026-10-18, alignée sur l'annexe D)** : le rang de la
> dernière course vient de la **liste détaillée** (`place`, `statusArrivee`) quand
> elle donne une place ou un incident ; la **musique** ne sert que lorsque la liste
> dit `NON_PLACE` sans place (elle peut alors donner 6 à 9, ou `0`), ou lorsque la
> liste manque. En cas de désaccord, la liste l'emporte, `source_rang =
> "liste_detaillee"` et l'avertissement `rang_desaccord` est ajouté. Une musique
> indécidable n'est jamais devinée. `[À VALIDER]`

AVANT :
> Performance_historique : + allocation (int, NULLABLE), + rang_brut (str: '1'..'9','0','D','T','A',...), + statut_arrivee (str)
> Participation          : + cote_reference_decimale (float, NULLABLE)  # si pas déjà dérivé

APRÈS :
> Performance_historique : + rang_brut (str: '1'..'9','0','D','T','A',...), + statut_arrivee (str)   # allocation : déjà présente
> Participation          : + non_partant (bool, défaut faux — story 5.5), + musique (texte, NULLABLE — story 6.1)

Justification : C7 (le code fait foi), F5, F14.

#### C-7 — §4.0, propriétés exigées (F2, F11)

AVANT :
> Propriétés exigées de toute stratégie : **déterministe** (mêmes entrées → mêmes
> sorties), **pure** (pas de lecture de base ni de réseau), **sans doublon**,
> **jamais de non-partant**, **jamais de partant virtuel**, au plus `taille` chevaux.

APRÈS :
> Propriétés exigées de toute stratégie : **déterministe** (mêmes entrées → mêmes
> sorties), **pure** (pas de lecture de base ni de réseau), **sans doublon**,
> **jamais de non-partant**, **jamais de partant virtuel**, **jamais de cheval sans
> dossard**, au plus `taille` chevaux. Un non-partant n'est pas un `ChevalMulti` :
> il a été retiré de l'entrée du moteur de scoring avant le calcul (6.6) ;
> `est_partant` reste à `True` pour tout cheval reçu et sert seulement aux
> comparateurs rejoués en backtest. Des dossards en double dans la course sont une
> erreur codée (`dossards_en_double`), jamais un départage.

#### C-8 — §4.1, borne de la taille (F7, F11)

AVANT :
> **Taille de la sélection** : `v` est **choisie par l'utilisateur**, de 4 à
> `min(SELECTION_MAX, nb_partants_reels)` (soit 20 au plus).

APRÈS :
> **Taille de la sélection** : `v` est **choisie par l'utilisateur**, de 4 à
> `min(SELECTION_MAX, nb_selectionnables)` (soit 20 au plus), où
> `nb_selectionnables` compte les chevaux analysés, partants et pourvus d'un
> dossard unique. L'API refuse une taille supérieure (422,
> `taille_superieure_aux_selectionnables`) ; l'application, elle, la ramène au
> plafond et le dit.

#### C-9 — §5.4, texte de garantie (F24)

AVANT :
> Texte d'UI pour `garantie` : « Si les 4 premiers sont dans votre sélection (bases
> comprises), au moins un ticket de **k** chevaux les contient tous les quatre. »

APRÈS :
> Texte d'UI pour `garantie` (identique au PRD FR-25 et à l'UX) : « Si les 4
> premiers sont dans votre sélection, au moins un de vos tickets les contient
> tous », avec la variante « … dans votre sélection et incluent votre base / vos
> bases, … », toujours suivi de « Couverture garantie — pas un gain garanti ».

#### C-10 — §6.4 Indice de confiance (F6, F12, F1)

AVANT :
> - la **fragilité des données** : proportion `f` des chevaux de `S` inédits ou à
>   historique court, et présence d'un favori fragile (meilleur `p_gagnant` avec
>   drapeau `historique_court`, `inedit` ou terrain inconnu majoritaire).

APRÈS :
> - la **fragilité des données** : proportion `f` des chevaux de `S` portant le
>   drapeau `inedit`, `historique_court` ou `donnees_non_saisies`, et présence d'un
>   favori fragile (meilleur `p_gagnant` parmi les chevaux réels, avec l'un de ces
>   drapeaux ou `terrain_majoritairement_inconnu`). Définitions communes aux deux
>   langages, déclarées dans `fixtures/multi_cases.json` (`constantes_moteur`) et
>   calculées par l'adaptateur `depuis_analyse` : `historique_court` si
>   `0 < nb_perfs < len(RECENCE_STD)` (6 aujourd'hui, comme le libellé de FR-4) ;
>   `donnees_non_saisies` si `nb_perfs == 0` et non inédit ;
>   `terrain_majoritairement_inconnu` si strictement plus de la moitié des
>   performances utilisées par la forme ont un terrain `NULL`. `[À VALIDER]`

AVANT :
> | 2. Course ouverte | si `H_norm ≥ seuil_course_ouverte` : niveau abaissé d'un cran |
> | 3. Données fragiles | si `f ≥ seuil_donnees_fragiles` ou favori fragile : niveau abaissé d'un cran, avertissement fort |

APRÈS :
> | 2. Course ouverte ou données fragiles | si `H_norm ≥ seuil_course_ouverte`, **ou** si `f ≥ seuil_donnees_fragiles` ou favori fragile : niveau abaissé d'**un seul** cran (D quater), avertissement fort si les données sont fragiles `[À VALIDER : un cran au total, et non un cran par cause]` |

AVANT :
> - **Seuils réglables** (`seuil_confiance_elevee`, `seuil_confiance_moyenne`,
>   `seuil_course_ouverte`, `seuil_donnees_fragiles`) : paramètres de l'utilisateur
>   dans les réglages, comme les autres paramètres du moteur (PRD FR-20), persistés
>   et réinitialisables. **Valeurs par défaut fixées par le pilote** (8.4), affichées
>   « provisoires » jusque-là.

APRÈS :
> - **Seuils réglables** (`seuil_confiance_elevee[v]`, `seuil_confiance_moyenne[v]`,
>   `seuil_course_ouverte`, `seuil_donnees_fragiles`) : paramètres de l'utilisateur
>   dans les réglages, comme les autres paramètres du moteur (PRD FR-20), persistés
>   et réinitialisables. **Valeurs par défaut fixées par le pilote** (8.4), affichées
>   « provisoires » jusque-là.
> - **Règle provisoire (D quater, 2026-10-18)**, appliquée à toute taille dont le
>   seuil n'est fixé ni par l'utilisateur ni par le pilote. Avec
>   `p_hasard(v) = C(v,4) / C(n,4)`, `n` = chevaux du champ (réels partants et
>   partants virtuels, non-partants exclus) : « moyenne » si
>   `p ≥ min(max(2 × p_hasard ; 0,15) ; 0,90)` ; « élevée » si
>   `p ≥ min(max(3 × p_hasard ; 0,35) ; 0,95)`. Exemples pour n = 16 : v = 8 →
>   0,15 / 0,35 ; v = 10 → 0,231 / 0,35 ; v = 12 → 0,544 / 0,816 ; v ≥ 14 →
>   0,90 / 0,95. Valeurs provisoires conservées : `seuil_course_ouverte = 0,90`,
>   `seuil_donnees_fragiles = 0,25`. `[À VALIDER]`
> - **Sélection égale au champ** : si la sélection contient tous les chevaux du champ
>   (aucun partant virtuel hors sélection), `p_couverture = 1` par construction ;
>   aucun niveau n'est donné, code `selection_egale_au_champ`. `[À VALIDER]`

AVANT :
> - **Course non éligible** (section 2) : pas d'indice ; en mode exploration, l'indice
>   est calculé avec la mention « course non support du Multi ».

APRÈS :
> - **Course non éligible** (section 2) : pas d'indice. Il n'y a plus de mode
>   exploration (D quater).

#### C-11 — §6.6 Simulation de non-partant (F2, C12)

AVANT :
> Pour chaque cheval de la sélection : ce que devient chaque ticket s'il est déclaré
> non-partant (requalification, section 2), et la nouvelle `p_couverture`. En cas de
> non-partant réel de dernière minute, le pronostic est **recalculé sur
> l'appareil** et l'écran indique ce qui change.

APRÈS :
> Pour chaque cheval de la sélection : ce que devient chaque ticket s'il est déclaré
> non-partant (requalification, section 2). Le moteur Multi **ne recalcule pas**
> `p_couverture` sans ce cheval : il ne retire jamais un cheval de `P_ens` et ne
> renormalise aucune probabilité (spine AD-6).
>
> **Non-partant réel** (signalé par la source ou marqué par l'utilisateur) : il est
> retiré de l'entrée du **moteur de scoring**, et la taille du champ devient
> « partants déclarés − non-partants » (aucun partant virtuel ne le remplace). Le
> moteur de scoring recalcule `p_gagnant` et `top4` des chevaux restants ; pour
> Plackett-Luce, cela revient à renormaliser leurs forces (axiome de Luce). Le
> pronostic est ensuite recalculé sur cette sortie, sur l'appareil, et l'écran
> Résultats montre le même champ. Le pronostic retenu n'est jamais réécrit :
> l'écran montre à part la requalification de ses tickets.

#### C-12 — §7 Données, schéma et journalisation (F1, F3, F7, F9, F10)

AVANT :
> multi_course                        -- écrivain : job d'ingestion/finalisation
>   course_id (FK, unique), est_course_support (bool), nb_partants_declares,
>   arrivee_json  (top-5 avec ex-aequo, NULLABLE tant que non finalisée), finalisee

APRÈS :
> multi_course                        -- écrivain : job d'ingestion/finalisation (et rafraîchissement à la demande pour donnees_maj_le)
>   course_id (FK, unique), multi_propose (bool, NULLABLE = liste des paris illisible),
>   mini_multi_propose (bool, NULLABLE), nb_partants_declares, donnees_maj_le (UTC),
>   arrivee_json  (top-5 avec ex-aequo, NULLABLE tant que non finalisée), finalisee,
>   arrivee_corrigee_le (UTC, NULLABLE)

AVANT :
> - Mode `live` : le job quotidien journalise, pour la course support, la
>   pronostic `modele` (aux **tailles de référence** fixées au pilote) et les
>   comparateurs `M1`, `B0`, `B1`, **avant** le départ. Il ne démarre qu'**après** le
>   pilote (8.4). Un échec (source indisponible, course support introuvable, départ
>   décalé) est journalisé comme tel (`non_journalise`, raison) et la course est
>   exclue de l'évaluation de façon comptée.

APRÈS :
> - Mode `live` : pour **chaque course éligible du jour**, le job quotidien relit
>   les partants et les cotes de la course, puis journalise, `MULTI_JOURNAL_AVANCE_MINUTES`
>   (30 par défaut) avant le départ, le pronostic `modele` (aux **tailles de
>   référence** fixées au pilote) et les comparateurs `M1`, `B0`, `B1`. Il ne démarre
>   qu'**après** le pilote (8.4). Un échec (source indisponible, heure de départ
>   inconnue, départ décalé ou passé, erreur du moteur) est journalisé comme tel
>   (`non_journalise`, raison) et la course est exclue de l'évaluation de façon
>   comptée.
> - **Arrivée recontrôlée** : pour les courses finalisées depuis moins de
>   `MULTI_RECONTROLE_ARRIVEE_JOURS` jours (3 par défaut), le job de finalisation
>   relit l'arrivée ; une correction met à jour `arrivee_json` et
>   `arrivee_corrigee_le`.

AVANT :
> - **Sur l'appareil** (V1 mono-utilisateur, sans compte, rien n'est envoyé au
>   serveur) : l'action **« Je retiens ce pronostic »** (une par course, remplaçable
>   jusqu'à l'heure de départ, figée ensuite) enregistre dans le cache local
>   (table `pronostic_retenu`, ex-`jeu_retenu`, et `recommandation_consultee`) le
>   pronostic du modèle **et** le pronostic retenu, tel quel ou modifié (taille,
>   sélection, bases actives, formule consultée, heure des données), conservés
>   **90 jours**.

APRÈS :
> - **Sur l'appareil** (V1 mono-utilisateur, sans compte, rien n'est envoyé au
>   serveur ; spine AD-9) : `hippique_cache.db` version 2 garde, par clé de course,
>   les partants reçus et le contexte Multi (réouverture hors ligne) ; la version 3
>   ajoute `pronostic_retenu` et `recommandation_consultee`. Chaque ligne porte un
>   instantané suffisant pour afficher le débrief sans recalcul : taille, sélection
>   (dossards, noms, `top4`), bases, niveau et raisons de confiance, bases
>   candidates, `p_couverture`, distribution des chevaux capturés, heure des données,
>   `version` du catalogue, identité du pronostic. `pronostic_retenu` garde en plus
>   la formule affichée et ses grilles telles qu'affichées.
>   `recommandation_consultee` est réécrite à chaque calcul complet du pronostic du
>   modèle avant le départ, tant qu'aucun pronostic n'est retenu ; ensuite, seule
>   une nouvelle retenue la réécrit (pronostic du modèle à la taille retenue). Elle
>   porte l'arrivée lue au backend (`arrivee_json`, `arrivee_corrigee_le`).
>   L'action **« Je retiens ce pronostic »** (une par course, remplaçable jusqu'à
>   l'heure de départ — jusqu'à la fin du jour de la course, heure de Paris, si
>   l'heure est inconnue — figée ensuite) enregistre les deux. Tout est conservé
>   **90 jours**. `[À VALIDER : règle d'écriture, versions 2 et 3]`

#### C-13 — §8.4 Pilote, marqueur de décision différée (F15)

AVANT :
> Avant toute période de test : un pilote en mode `backfill` sur une période de
> développement, pour (1) mesurer la variance et fixer la taille d'échantillon,

APRÈS :
> Avant toute période de test : un pilote en mode `backfill` sur une période de
> développement, pour (1) mesurer la variance et fixer la taille d'échantillon
> (**règle de taille d'échantillon et règle de proposition des seuils : à décider
> avec le porteur de projet avant la story 6.6** — constat F15, différé),

#### C-14 — §10 API (F4, F7, F1)

AVANT :
> | GET | `/courses/{id}/multi/eligibilite` | course support ? nb de partants, non-partants |

APRÈS :
> | GET | `/multi/courses/{cle_course}` | contexte Multi d'une course désignée par sa clé PMU `AAAAMMJJ-Rn-Cn` : éligibilité et raison, partants déclarés, non-partants, heure des données, arrivée avec ex-aequo et date de correction |
> | POST | `/multi/courses/{cle_course}/rafraichir` | relit à la source les partants et les cotes de la course (avant le départ, au plus une fois toutes les 5 minutes) ; renvoie le contexte et les partants |

AVANT :
> { "course_id": "20261016-R1-C5",

APRÈS :
> { "cle_course": "20261016-R1-C5",

AVANT :
> (`taille` obligatoire, de 4 à 20 ; l'application envoie la dernière taille utilisée,
> sinon 10. `seuils` à `null` → valeurs par défaut en vigueur pour cette taille.
> Comme `/analyse`, le corps accepte aussi une liste de chevaux saisis à la place de
> `course_id`.)

APRÈS :
> (`taille` obligatoire, de 4 à 20. `seuils` à `null` → valeurs par défaut en
> vigueur pour cette taille. Comme `/analyse`, le corps accepte aussi une liste de
> chevaux saisis à la place de `cle_course`. `cle_course` est la clé PMU, jamais
> l'id auto-incrémenté (spine AD-12). Une taille supérieure aux sélectionnables est
> refusée par l'API (422) ; seule l'application la ramène au plafond, en le disant.)

AVANT :
> **Erreurs** : `422` si `taille < 4`, `taille > 20` ou `taille > nb_partants_reels`,

APRÈS :
> **Erreurs** : `422` si `taille < 4`, `taille > 20` ou `taille > nb_selectionnables`, course non éligible (`course_non_eligible`), dossards en double (`dossards_en_double`),

#### C-15 — §11.3 Hors ligne (F7, F10, C1)

AVANT :
> Elle calcule **toujours** le pronostic
> elle-même, avec le contexte Multi de la course (éligibilité, état de l'évaluation,
> seuils provisoires ou non) reçu du backend avec les partants et mis en cache ; elle
> n'appelle pas `/multi/recommandation`. Le pronostic retenu et le pronostic du modèle
> consulté sont stockés dans `hippique_cache.db` (version 2, tables
> `pronostic_retenu` et `recommandation_consultee`) et conservés **90 jours** ;

APRÈS :
> Elle calcule **toujours** le pronostic
> elle-même, avec le contexte Multi de la course (éligibilité, non-partants, état de
> l'évaluation, seuils provisoires ou non), reçu comme objet `multi` de chaque course
> de `GET /courses` et mis en cache avec le programme ; elle n'appelle pas
> `/multi/recommandation`. Les partants d'une course ouverte sont mis en cache
> (`hippique_cache.db` version 2) : la course se rouvre hors ligne après
> redémarrage. Le pronostic retenu et le pronostic du modèle consulté sont stockés
> dans la version 3 (tables `pronostic_retenu` et `recommandation_consultee`) et
> conservés **90 jours** ;

#### C-16 — §12 Questions ouvertes, lignes 1 et 3 (F1)

AVANT :
> | 1 | Formules, jours de Quinté+, seuil de 14 partants, règle des non-partants, arrivée dégradée (prix unitaire et rapports : non affichés) : le document date de 2001-2002 | **Vérifier sur pmu.fr avant de figer `regles.py`** |

APRÈS :
> | 1 | Formules, courses où le Multi est proposé, seuil éventuel de partants, statut du Mini Multi, règle des non-partants, arrivée dégradée (prix unitaire et rapports : non affichés) : le document date de 2001-2002 | **Vérifier sur pmu.fr avant de figer `regles.py`** (story 5.1) |

AVANT :
> | 3 | Champ « course support » et arrivée avec ex-aequo dans la source PMU (les rapports Multi ne sont plus nécessaires) | À découvrir dans `pmu_client.py` |

APRÈS :
> | 3 | Arrivée avec ex-aequo dans la source PMU (les rapports Multi ne sont plus nécessaires) | À documenter dans `pmu_client.py` (story 5.5). **Éligibilité close le 2026-10-18** : liste des paris (`paris[].typePari`), D quater |

#### C-17 — Annexe D, décodeur de musique (F7, F14, C6)

AVANT :
> - Jeton de course : `rang_brut` (chiffre 1-9, `0` = non placé, ou lettre
>   d'incident `D`, `T`, `A`, …) suivi d'**une lettre minuscule** de discipline
>   (`p` plat, `h` haies, `s` steeple, `c` cross, `a` attelé, `m` monté) ; les années
>   peuvent apparaître entre parenthèses (`(23)`).

APRÈS :
> - Jeton de course : `rang_brut` (chiffre 1-9, `0` = non placé, ou lettre
>   d'incident `D`, `T`, `A`, …) suivi d'**une lettre de discipline, majuscule dans
>   les données réelles** (`P` plat, `H` haies, `S` steeple, `C` cross, `A` attelé,
>   `M` monté ; ex. `DA21DA2A1ADA1A`), minuscule dans le document ; le décodeur
>   accepte les deux casses. Les années peuvent apparaître entre parenthèses
>   (`(23)`). `A` désigne à la fois l'attelé et l'incident « arrêté » : la position
>   dans le jeton lève l'ambiguïté quand la segmentation est sûre, sinon le résultat
>   est « indécidable ».

AVANT :
> course vient en priorité de `performances-detaillees`, la musique ne servant que
> de recoupement.

APRÈS :
> course vient en priorité de `performances-detaillees`, la musique ne servant qu'en
> complément (place `NON_PLACE` sans rang, liste absente) et au recoupement (§3).
> Cette règle est désormais définitive, pas seulement provisoire. `[À VALIDER]`

### 4.3 Spine d'architecture — `architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`

#### A-1 — Schéma Multi (diagramme), nœud local (F3, F10)

AVANT :
>     LOCAL[(sqflite v2: pronostic_retenu,<br/>recommandation_consultee)]

APRÈS :
>     LOCAL[(sqflite v2: race cache<br/>v3: pronostic_retenu,<br/>recommandation_consultee)]

#### A-2 — `updated` du frontmatter

Inchangé (`'2026-10-18'`). Ajouter en fin de chaque AD modifié la mention `amended 2026-10-18 (course correction)`.

#### A-3 — AD-2, miroirs d'exécution (F7, F13, C3)

AVANT :
>   - Comparative/structural tests that assert a *relationship* between two computed results in the same test (disqualification-vs-chute ordering, désordre/ordre ratio growth by depth) stay hand-written per language — they encode the property in the assertion itself, not a value that can silently drift. [decided this run; widened after adversarial + rubric-walker review]

APRÈS (la puce est conservée, suivie de) :
>   - **Runtime mirrors of root fixtures.** `fixtures/` is in neither the backend Docker build context nor the APK. When production code needs a fixture value at runtime, a mirror module carries it — `backend/app/engine/multi/regles.py`, `parametres.py`, `versions.py` and their Dart counterparts — and a test in each language validates the mirror against the canonical file (any drift fails the suite). `regles.py`/`regles.dart` also carry `EMPREINTE_REGLES`, the sha256 of `fixtures/multi_regles.json`, validated the same way. Only the systems catalogue is a byte-identical file copy (AD-7). [amended 2026-10-18, course correction]

#### A-4 — AD-6, règle (F1, F2, F7, F11, C1, C12)

AVANT :
> - **Rule:** the Multi engine's inputs are (1) the scoring core's output for the race (win probabilities, `top4`, `value`, transparency flags, virtual runners) and (2) a **Multi race context** built by the backend and delivered with the race's runners: eligibility (support race, declared runners), model evaluation status, and whether the confidence-index thresholds are still provisional.

APRÈS :
> - **Rule:** the Multi engine's inputs are (1) the scoring core's output for the race (win probabilities, `top4`, `value`, transparency flags, virtual runners) and (2) a **Multi race context** built by the backend and delivered as a typed `multi` object on each race of `GET /courses` (`MultiContexteOut`, AD-4) and by `GET /multi/courses/{cle_course}`: eligibility (the race's PMU bet list contains `MULTI` — several races a day, no single support race, no exploration mode; Mini Multi out of scope — decision D quater 2026-10-18), declared runners, non-runners, data timestamp, model evaluation status, and whether the confidence-index thresholds are still provisional. **Non-runners leave the field before scoring**: a declared non-runner (from the source or marked by the user) is removed from the scoring core's input and the field size becomes declared runners minus non-runners, so no virtual runner replaces it; the scoring core recomputes win probabilities and `top4` for the remaining field (for Plackett-Luce, a renormalisation of the remaining strengths), and the Multi engine consumes that new output. The Multi engine never drops a horse from `P_ens` nor rescales a probability itself; Results and Multi always show the same field. A horse without a dossard stays in the field but is never selectable; duplicated dossards stop the forecast with the coded error `dossards_en_double`. A race with no backend context (manual entry, photo import) has no Multi forecast.

Le reste de la règle AD-6 est inchangé ; remplacer la fin `[decided this run, tightened at review; amended 2026-10-18 — no money in the context]` par `[decided this run, tightened at review; amended 2026-10-18 — no money in the context; course correction 2026-10-18 — eligibility, non-runners, context location]`.

#### A-5 — AD-7, contenu du fichier de règles (F1, F13)

AVANT :
>   - **Rules.** `fixtures/multi_regles.json` holds unit stake, formulas, rapport coefficients, minimum rapports, support-race criteria, non-runner requalification and a mandatory `date_verification`; `regles.py` and `regles.dart` are validated against it;

APRÈS :
>   - **Rules.** `fixtures/multi_regles.json` holds unit stake, formulas, rapport coefficients, minimum rapports, the eligibility criterion (bet type `MULTI` in the race's bet list; a minimum of declared runners only if the pmu.fr check confirms one), non-runner requalification and a mandatory `date_verification`; `regles.py` and `regles.dart` mirror it and carry its sha256 (`EMPREINTE_REGLES`), both validated against it (AD-2);

#### A-6 — AD-9, règle complète (F3, F7, F10, F16, C2)

AVANT (puce **Rule:** entière de AD-9) :
> - **Rule:** the retained forecast (« pronostic retenu », formerly « jeu retenu ») and the model forecast consulted with it are stored in two new tables of `hippique_cache.db` (`pronostic_retenu` — renamed from `jeu_retenu`, never shipped — and `recommandation_consultee`, name kept), each referencing the race by its stable key and carrying the recommendation identity (AD-12). `onCreate` builds schema version 2 directly and `onUpgrade` migrates 1 → 2; both paths are tested. A retained forecast is replaceable until the race's departure time and frozen afterwards (UTC comparison, AD-12). Entries older than 90 days are purged at app start-up (no background task). Confidence-index thresholds and the last-used selection size are user settings stored in `shared_preferences` with the other engine parameters (FR-20). Nothing of this is sent to the backend. [decided this run, tightened at review; amended 2026-10-18 — retained forecast]

APRÈS :
> - **Rule:** `hippique_cache.db` gains successive schema versions; `onCreate` builds the latest version directly and every `onUpgrade` step migrates without losing rows; every path is tested with `sqflite_common_ffi`.
>   - **Version 2 — race cache** (before any Multi screen): `programme_courses` gains the race key (`cle_course`, `numero_reunion`, `numero_course`) and the cached Multi context (`multi_contexte`, JSON); a new table `partants_course` keeps, per race key, the runners payload last received from the backend and its fetch time, so an opened race reopens offline after a restart. User edits to the runner list are not persisted.
>   - **Version 3 — Multi**: `pronostic_retenu` (renamed from `jeu_retenu`, never shipped) and `recommandation_consultee` (name kept), one row per race key each, carrying the recommendation identity (AD-12) and a snapshot sufficient to show the debrief without recomputation: size, selection (dossards, names, `top4`, roles), bases, confidence level and reasons, candidate bases, `p_couverture`, capture distribution, data timestamp, catalogue `version`. `pronostic_retenu` also keeps the displayed formula and its tickets as shown. `recommandation_consultee` also holds the race label and date and the arrival read from the backend (`arrivee_json`, `arrivee_corrigee_le`). Write rule: `recommandation_consultee` is upserted at each completed model computation before departure while no forecast is retained for the race; once one is retained, only a (re)retention rewrites it, with the model forecast at the retained size.
>   - A retained forecast is replaceable until the race's departure time and frozen afterwards (UTC comparison, AD-12); if the departure time is unknown, until the end of the race day in Europe/Paris. Rows whose race is older than 90 days are purged at app start-up (no background task), cached runners included.
>   - Confidence-index threshold overrides (per size) and the last-used selection size are user settings stored in `shared_preferences` with the other engine parameters (FR-20). Epic 6 may add a version 4 table for the cached `/multi/performance` response.
>   - Nothing of this is sent to the backend. [decided this run, tightened at review; amended 2026-10-18 — retained forecast; course correction 2026-10-18 — race cache, snapshot, write rule, unknown departure]

#### A-7 — AD-10, tables et journal (F1, F5, F7, F9, C11)

AVANT :
>   | `multi_course` | eligibility, arrival with ties (no rapports) | ingestion/finalisation job |

APRÈS :
>   | `multi_course` | eligibility (`multi_propose`, `mini_multi_propose`), declared runners, data timestamp, arrival with ties and correction date (no rapports) | ingestion/finalisation job; the on-demand runner refresh updates `donnees_maj_le` through the same repository method |

AVANT :
>   `recommandation_multi` rows are never updated or deleted; a correction is a new strategy version. The daily Multi log runs in the `ingestion` container and starts only once the pilot has fixed the reference sizes (PRD §6.1).

APRÈS :
>   `recommandation_multi` rows are never updated or deleted; a correction is a new strategy version. The daily Multi log runs in the `ingestion` container for **every eligible race of the day**: `MULTI_JOURNAL_AVANCE_MINUTES` (default 30) before each departure it re-reads that race's runners and odds from the source, then logs; it starts only once the pilot has fixed the reference sizes (PRD §6.1). Runners and odds are otherwise re-read only by the 6 a.m. ingestion and by `POST /multi/courses/{cle_course}/rafraichir` (before departure, at most once every `MULTI_RAFRAICHISSEMENT_MIN_MINUTES`, default 5) — no periodic intraday re-read (PRD OQ 6). The finalisation job re-checks the arrival of races finalised less than `MULTI_RECONTROLE_ARRIVEE_JOURS` days ago (default 3) and records a correction in `multi_course`. `participations` gains `non_partant` and `musique`, written by the ingestion through `repository.py`.

#### A-8 — AD-11, miroir des paramètres du pilote (F7, C3)

AVANT :
> live in `fixtures/multi_parametres_pilote.json`, validated by both languages' tests and read by the daily job (AD-2 pattern).

APRÈS :
> live in `fixtures/multi_parametres_pilote.json`; production code reads them through the runtime mirrors `engine/multi/parametres.py` and `parametres.dart`, validated against the file by both languages' tests (AD-2 runtime-mirror pattern). Until the pilot, the file holds the provisional rule decided on 2026-10-18 (D quater) and `provisoire: true`.

#### A-9 — AD-12, clé de course dans l'API et versions (F4, F13, C13)

AVANT :
> - **Rule:** a race is identified across systems by its PMU key (date, `numero_reunion`, `numero_course` — already unique in `courses`), never by an autoincrement id; a horse by `num_pmu` within that race only. A recommendation is identified by the tuple (race key, Multi engine version, catalogue `version`, rules hash, parameters hash, data timestamp); the engine version lives in `fixtures/multi_versions.json` with the registry and pilot-parameter versions,

APRÈS :
> - **Rule:** a race is identified across systems by its PMU key (date, `numero_reunion`, `numero_course` — already unique in `courses`), never by an autoincrement id; a horse by `num_pmu` within that race only. On the wire the key is the string `cle_course` = `AAAAMMJJ-Rn-Cn`, exposed on `CourseOut` with `numero_reunion` and `numero_course`; every Multi route and request names a race by `cle_course` (`/multi/courses/{cle_course}`, `cle_course` in `/multi/recommandation`), never by `course_id`. The autoincrement routes of Epics 1–3 (`/courses/{id}/partants`, `/analyse`) stay as they are. A recommendation is identified by the tuple (race key, Multi engine version, catalogue `version`, rules hash, parameters hash, data timestamp); the engine version lives in `fixtures/multi_versions.json` with the registry and pilot-parameter versions and reaches runtime through the mirrors `versions.py` / `versions.dart`, the rules hash through `EMPREINTE_REGLES` (AD-2),

#### A-10 — AD-13, sauvegarde et baseline (F7, F20, C10)

AVANT :
> - **Rule:** every server schema change ships as an Alembic revision under `backend/alembic/` (inside the Docker build context). The existing production schema is the baseline revision, stamped once on the live database.

APRÈS :
> - **Rule:** every server schema change ships as an Alembic revision under `backend/alembic/` (inside the Docker build context, with `backend/scripts/`, which holds the start-up script). The baseline revision is the schema produced by `Repository._migrate()` at the commit of the Alembic story — including any column added since planning, e.g. `performances_historiques.rang_impute` — not a closed list; it is stamped once on the live database after `_migrate()` has run one last time. Before the stamp and before each upgrade, the start-up script copies the SQLite file to `hippique.db.avant-<revision>.bak` and keeps the 3 latest copies; a failed migration stops start-up with a non-zero exit and leaves the copy in place. Route modules instantiate `Repository()` at import, so removing `create_all` covers that path too.

#### A-11 — Consistency Conventions, ligne « State & cross-cutting » (F10)

AVANT :
> | State & cross-cutting | Mobile local calculation never depends on network reachability once a course is cached (PRD FR-13) — this includes the whole Multi forecast and confidence index;

APRÈS :
> | State & cross-cutting | Mobile local calculation never depends on network reachability once a course is cached (PRD FR-13) — this includes the whole Multi forecast and confidence index, and survives an app restart (race cache, AD-9);

#### A-12 — Deferred, deux puces (F1, F7, C10, C11)

AVANT :
> - **Where the support-race marker and the arrival with ties sit in the PMU source** (PRD Open Question 9) — discovered inside `pmu_client.py` (AD-1); no structural hook needed beyond AD-10. Multi rapports are out of scope since 2026-10-18 (the Multi is a forecast): not ingested, not stored, not displayed.

APRÈS :
> - **Where the arrival with ties sits in the PMU source** — documented inside `pmu_client.py` (AD-1) by the eligibility story; no structural hook needed beyond AD-10. Eligibility is read from the race's bet list (closed 2026-10-18, D quater; PRD Open Question 9 closed). Multi rapports are out of scope since 2026-10-18 (the Multi is a forecast): not ingested, not stored, not displayed.

AVANT :
> - **Operations of the Multi jobs.** Schedule of the daily Multi log relative to departure times, and backup of the production SQLite file (now the only home of logged recommendations): decide when increment 2 starts.

APRÈS :
> - **Operations of the Multi jobs.** Decided on 2026-10-18: log schedule and arrival re-check (AD-10), SQLite copy at each migration (AD-13). Still deferred: regular backups outside migrations and monitoring of the daily log — decide when increment 2 starts.

### 4.4 UX — `ux-designs/ux-prediction-hyppique-2026-08-22/`

#### U-1 — EXPERIENCE.md, Information Architecture, ligne « Réglages » (F19)

AVANT :
> Paramètres du moteur (FR-20), persistés — y compris un groupe « Multi » : seuils de l'indice de confiance (probabilité que l'arrivée soit dans la sélection, ouverture de la course) et seuil de données fragiles, libellés « provisoire » tant que le pilote ne les a pas fixés. Retour vers le Multi → recalcul local |

APRÈS :
> Paramètres du moteur (FR-20), persistés — y compris un groupe « Multi » : « Seuil de course ouverte » et « Seuil de données fragiles » (un champ chacun), puis « Seuils de confiance par taille », replié par défaut : une ligne par taille de 4 à 20 chevaux, avec deux champs en pourcentage (« Moyenne à partir de », « Élevée à partir de »). Un champ vide vaut « Auto » (règle provisoire, qui dépend du nombre de partants de la course) ; une valeur saisie remplace la règle pour cette taille. Libellé « provisoire » tant que le pilote n'a pas fixé les seuils ; une incohérence (moyenne > élevée, valeur hors de 0–100 %) est refusée et expliquée sous le champ. Retour vers le Multi → recalcul local `[À VALIDER]` |

#### U-2 — EXPERIENCE.md, ligne « Multi » de l'Information Architecture (F1)

AVANT :
> | Pour la course support : pronostic des chevaux qui peuvent constituer l'arrivée,

APRÈS :
> | Pour une course où le Multi est proposé : pronostic des chevaux qui peuvent constituer l'arrivée,

#### U-3 — EXPERIENCE.md, paragraphe de navigation (F1)

AVANT :
> la carte de la course support porte un badge « Multi » à l'Accueil pour qu'on la repère.

APRÈS :
> la carte de chaque course éligible porte un badge « Multi » à l'Accueil pour qu'on la repère (plusieurs par jour).

#### U-4 — EXPERIENCE.md, ordre de l'écran Multi, étape 1 (F1, F9, F11)

AVANT :
> Les `status-banner` d'état (exploration, règles à vérifier, non-partant, pronostic retenu touché par un non-partant, classement modifié) s'insèrent sous l'en-tête.

APRÈS :
> L'en-tête porte aussi « Rafraîchir la course » (`cta-ghost`, réseau seulement, avant le départ). Les `status-banner` d'état (règles à vérifier, non-partant, pronostic retenu touché par un non-partant, classement modifié, chevaux sans dossard) s'insèrent sous l'en-tête.

#### U-5 — EXPERIENCE.md, `formula-row` (F25)

AVANT :
> Une seule est « Affichée » : par défaut Multi en 7 (confirmé par le porteur de projet le 2026-10-18), puis la dernière formule utilisée `[ASSUMPTION]`.

APRÈS :
> Une seule est « Affichée » : par défaut Multi en 7 (confirmé par le porteur de projet le 2026-10-18), sinon la plus grande formule disponible ; aucune mémoire d'une course à l'autre `[À VALIDER]`.

#### U-6 — EXPERIENCE.md, `base-chip` (F8)

AVANT :
> Chacun : dossard, nom, « Top 4 estimé 58 % », effet en base « −4 pts d'arrivée dans la sélection » ; jamais de montant.

APRÈS :
> Chacun : dossard, nom, « Top 4 estimé 58 % », effet en base « −4 pts d'arrivée dans la sélection » et tickets économisés pour la formule affichée (« 16 tickets en moins en Multi en 7 ») ; sans formule disponible (règles non vérifiées, forme absente du catalogue), la ligne des tickets est omise ; jamais de montant (PRD FR-24).

#### U-7 — EXPERIENCE.md, `multi-badge` (F1)

AVANT :
> Résultats d'une course non éligible : « Multi indisponible » à la place du CTA « Multi » ; tap → la raison (« Pas une course support » ou « Moins de 14 partants déclarés (12) »). |

APRÈS :
> Résultats d'une course non éligible : « Multi indisponible » à la place du CTA « Multi » ; tap → la raison (« Multi non proposé sur cette course », « Mini Multi non pris en charge », « Liste des paris indisponible — rafraîchissez le programme », « Course saisie à la main : Multi indisponible », ou, si les règles fixent un seuil, « Moins de 14 partants déclarés (12) »). |

#### U-8 — EXPERIENCE.md, état « Course non éligible » (F1)

AVANT :
> | Course non éligible | Résultats | Le CTA « Multi » est remplacé par un `multi-badge` « Multi indisponible » ; tap → la raison (« Pas une course support » ou « Moins de 14 partants déclarés »). L'écran Multi ne s'ouvre pas. |

APRÈS :
> | Course non éligible | Résultats | Le CTA « Multi » est remplacé par un `multi-badge` « Multi indisponible » ; tap → la raison (voir `multi-badge`). L'écran Multi ne s'ouvre pas. |

#### U-9 — EXPERIENCE.md, état « Mode exploration » remplacé (F1, F11)

AVANT :
> | Mode exploration (marqueur course support introuvable) | Multi | `status-banner` « Exploration — course support non confirmée » ; pronostic, confiance et systèmes calculés normalement. `[ASSUMPTION]` |

APRÈS :
> | Chevaux sans dossard | Multi | `status-banner` « 2 chevaux sans dossard, non sélectionnables » + « Analyser » vers Liste des partants ; ils restent dans le calcul des probabilités. `[À VALIDER]` |
> | Dossards en double | Multi | `status-banner` « Dossards en double : n° 7 — corrigez la liste des partants » + « Analyser » ; aucun pronostic tant que la liste n'est pas corrigée. `[À VALIDER]` |

Justification : D quater supprime le mode exploration ; F11.

#### U-10 — EXPERIENCE.md, état « Non-partant déclaré » (F2)

AVANT :
> | Non-partant déclaré (rafraîchissement ou marqué à la main) | Multi | Recalcul local immédiat, taille conservée ;

APRÈS :
> | Non-partant déclaré (rafraîchissement ou marqué à la main) | Multi et Résultats | Le cheval sort du champ : le classement est recalculé automatiquement sur l'appareil (Résultats affiche « Non-partant : n° 7 — classement recalculé », sans passer par « Résultat périmé »), puis le Multi ; un rafraîchissement qui n'apporte que des cotes rend le classement « périmé » comme aujourd'hui `[À VALIDER]`. Recalcul local immédiat, taille conservée ;

#### U-11 — EXPERIENCE.md, état « Multi en état débrief » (F3, F27)

AVANT :
> | Multi en état débrief (lecture seule) | Multi, ouvert depuis « Mes pronostics Multi » | En-tête avec l'arrivée (4 premiers en dossards) et « 🔒 Pronostic figé au départ (15 h 05) » ; les deux `debrief-row` sous l'en-tête ; puis le pronostic retenu tel qu'enregistré (taille, confiance, sélection, chevaux les plus probables, formule) en lecture seule, chevaux de l'arrivée marqués « Capturé » en texte ; Évaluation, Autres méthodes et rappel visibles ; la barre ne garde que « Voir les grilles ». `[ASSUMPTION]` |

APRÈS :
> | Multi en état débrief (lecture seule) | Multi, ouvert depuis « Mes pronostics Multi » | En-tête avec l'arrivée (4 premiers en dossards) et « 🔒 Pronostic figé au départ (15 h 05) » ; les deux `debrief-row` sous l'en-tête ; puis le pronostic retenu tel qu'enregistré (à défaut, le pronostic du modèle consulté) : taille, confiance, sélection, chevaux les plus probables, formule, en lecture seule, chevaux de l'arrivée marqués « Capturé » en texte. Évaluation affichée depuis les valeurs enregistrées (jamais recalculée) ; « Autres méthodes » absente (elle exigerait un recalcul) ; rappel visible. La barre ne garde que « Voir les grilles », qui montre les grilles enregistrées au moment de la retenue ; sans pronostic retenu, aucune grille. `[À VALIDER]` |

#### U-12 — EXPERIENCE.md, état « Hors ligne » (F10)

AVANT :
> | Hors ligne | Multi | Fonctionnement identique (calcul local) ; seuls le rafraîchissement des non-partants et le débrief attendent le réseau, avec message clair. |

APRÈS :
> | Hors ligne | Multi | Fonctionnement identique (calcul local), y compris après redémarrage de l'app pour une course déjà ouverte (partants en cache, ligne « Partants du 18/10 à 9 h 38 ») ; seuls le rafraîchissement de la course et le débrief attendent le réseau, avec message clair. |

#### U-13 — EXPERIENCE.md, état « Mode avion / hors ligne, course en cache » (F10)

AVANT :
> | Mode avion / hors ligne, course en cache | Toute surface sauf import/rafraîchissement | Fonctionnement identique au mode connecté (PRD FR-13, non négociable). |

APRÈS :
> | Mode avion / hors ligne, course en cache | Toute surface sauf import/rafraîchissement | Fonctionnement identique au mode connecté (PRD FR-13, non négociable). Une course déjà ouverte se rouvre après redémarrage avec ses partants en cache ; les modifications manuelles de la liste ne sont pas conservées après fermeture. |

#### U-14 — EXPERIENCE.md, récit UJ-4, étape 1 (F1)

AVANT :
> 1. Résultats de la course support calculés → il touche « Multi », en tête de Résultats.

APRÈS :
> 1. Résultats d'une course où le Multi est proposé calculés → il touche « Multi », en tête de Résultats.

#### U-15 — DESIGN.md, composant `base-chip` (F8)

AVANT :
> Porte toujours son top 4 estimé en chiffres. La puce entière est la cible (≥ 48dp de haut).

APRÈS :
> Porte toujours son top 4 estimé en chiffres, son effet en points et les tickets économisés pour la formule affichée (texte `muted`). La puce entière est la cible (≥ 48dp de haut).

#### U-16 — Maquette `mockups/multi.html` (F8, F1)

Action pour bmad-ux, pas un remplacement mécanique : ajouter la ligne des tickets économisés sur les `base-chip` ; remplacer toute mention de course support ou d'exploration. La spine UX fait foi en attendant.

### 4.5 Epics et stories — `epics.md`

#### E-1 — Overview, ligne 20 (F22)

AVANT :
> This document provides the complete epic and story breakdown for prediction-hyppique, decomposing the requirements from the PRD and the Architecture Spine into implementable stories. No formal UX design contract exists — the mobile screens are already specified in detail in `docs/cahier_des_charges_app_mobile.md` §7, treated here as the UX reference.

APRÈS :
> This document provides the complete epic and story breakdown for prediction-hyppique, decomposing the requirements from the PRD and the Architecture Spine into implementable stories. Epics 1 to 4 used `docs/cahier_des_charges_app_mobile.md` §7 as their UX reference; since 2026-10-18 the UX contract `DESIGN.md` + `EXPERIENCE.md` (final) governs every screen, the Multi module included. Epics 5 and 6 were revised by the course correction of 2026-10-18 (`sprint-change-proposal-2026-10-18.md`).

#### E-2 — §UX Design Requirements, ligne 108 (F22)

AVANT :
> Aucun contrat UX formel (bmad-ux) produit. Référence de substitution : `docs/cahier_des_charges_app_mobile.md` §7 (parcours écran par écran : accueil, configuration course, liste partants, fiche cheval, import photo, résultats, réglages) et le prototype `analyse_hippique_v2.html`/`analyse_hippique_ia.jsx` pour le rendu concret des résultats et combinaisons.

APRÈS :
> Epics 1 à 4 : référence `docs/cahier_des_charges_app_mobile.md` §7 et prototypes `analyse_hippique_v2.html` / `analyse_hippique_ia.jsx`. Depuis le 2026-10-18, le contrat UX `DESIGN.md` + `EXPERIENCE.md` (final) fait foi pour toute l'application.

#### E-3 — Inventaire FR-22 et FR-23 (F1, F2, F10)

AVANT :
> FR-22: Éligibilité d'une course au Multi (course support, ≥ 14 partants déclarés) ; raison affichée si non éligible ; mode « exploration » si le marqueur course support est introuvable ; règles du pari en source unique datée (sans date de vérification, aucune grille) ; partants non analysés signalés et non sélectionnables.

APRÈS :
> FR-22: Éligibilité d'une course au Multi : le Multi figure dans la liste des paris PMU de la course (plusieurs courses par jour ; seuil de partants seulement si les règles vérifiées le fixent ; Mini Multi hors périmètre ; ni course support unique ni mode exploration — D quater) ; raison affichée si non éligible ; courses hors ingestion sans Multi ; règles du pari en source unique datée (sans date de vérification, aucune grille) ; partants non analysés ou sans dossard signalés et non sélectionnables ; dossards en double bloquants.

AVANT :
> calcul local hors ligne ; non-partant par rafraîchissement ou « marquer non-partant », avec requalification du pronostic retenu.

APRÈS :
> calcul local hors ligne, y compris après redémarrage (partants en cache) ; non-partant par rafraîchissement (relecture à la demande) ou « marquer non-partant », retiré du champ et recalculé par le moteur de scoring, avec requalification du pronostic retenu.

#### E-4 — Additional Requirements, puces AD-9 et « Différé » (F3, F7)

AVANT :
> - AD-9 : `hippique_cache.db` passe en version 2 (`pronostic_retenu`, `recommandation_consultee`) : `onCreate` v2 direct + `onUpgrade` 1→2, les deux testés ; figé au départ (UTC) ; purge > 90 jours au démarrage ; dernière taille et seuils dans `shared_preferences`.

APRÈS :
> - AD-9 : `hippique_cache.db` version 2 (cache de course : clé, contexte Multi, partants) puis version 3 (`pronostic_retenu`, `recommandation_consultee`, instantané suffisant au débrief) : `onCreate` direct en dernière version + chaque `onUpgrade` testé ; figé au départ (UTC), ou fin du jour de Paris si l'heure est inconnue ; purge > 90 jours au démarrage ; dernière taille et seuils par taille dans `shared_preferences`.

AVANT :
> - Différé (spine) : taille du catalogue à mesurer, outillage de traduction Flutter (après MVP), backtest sur serveur, exploitation des jobs Multi et sauvegarde SQLite, environnement de test local aligné sur la prod (Python 3.12 / NumPy 1.26.4).

APRÈS :
> - Différé (spine) : taille du catalogue à mesurer, outillage de traduction Flutter (après MVP), backtest sur serveur, sauvegardes régulières hors migration et supervision du journal Multi, environnement de test local aligné sur la prod (Python 3.12 / NumPy 1.26.4). Décidé le 2026-10-18 : horaire du journal (T−30 min), recontrôle de l'arrivée (3 jours), copie SQLite à chaque migration (3 conservées).

#### E-5 — UX-DR1 et UX-DR11 (F1, F11)

AVANT :
> UX-DR1: Accès au Multi — CTA « Multi » en tête de Résultats pour une course éligible ; `multi-badge` sur la carte de la course support à l'Accueil

APRÈS :
> UX-DR1: Accès au Multi — CTA « Multi » en tête de Résultats pour une course éligible ; `multi-badge` sur la carte de chaque course éligible à l'Accueil

AVANT :
> UX-DR11: États Multi couverts par `status-banner` et la carte confiance : premier affichage, calcul en cours/erreur, classement modifié, exploration, règles non vérifiées,

APRÈS :
> UX-DR11: États Multi couverts par `status-banner` et la carte confiance : premier affichage, calcul en cours/erreur, classement modifié, chevaux sans dossard, dossards en double, règles non vérifiées,

#### E-6 — Epic 5, notes d'implémentation (F3, F10)

AVANT :
> cache local en version 2 et purge à 90 jours (AD-9)

APRÈS :
> cache local en versions 2 (course) et 3 (pronostic retenu), purge à 90 jours (AD-9), relecture à la demande des partants et des cotes

Et, dans la description de l'Epic 6 (§Epic List), ajouter après « puis journalisation quotidienne dans le conteneur `ingestion` (AD-10) » : « , pour toutes les courses éligibles du jour ».

#### E-7 — Story 5.1 (F1, F13, F29)

AVANT :
> **Then** aucune autre story des epics 5 et 6 (5.2 à 5.16, 6.1 à 6.7, y compris les stories techniques 5.2 à 5.4) ne démarre avant que cette story soit terminée
> **And** cette règle figure en tête de la story et dans le suivi de sprint.

APRÈS :
> **Then** aucune autre story des epics 5 et 6 (5.2 à 5.21, 6.1 à 6.8, y compris les stories techniques 5.2 à 5.4) ne démarre avant que cette story soit terminée
> **And** cette règle figure en tête de la story et dans le suivi de sprint, où la story est marquée **tâche humaine** (porteur de projet, ou développeur avec sa validation) : un agent de développement ne peut pas l'achever seul.

AVANT :
> **When** il contrôle chaque règle du cahier Multi §2 — formules 4 à 7, nombre de paris par ticket physique, choix de la course support selon les jours (Quinté+ ou 2sur4), seuil de 14 partants déclarés, requalification des non-partants, ex-aequo, ordre de l'arrivée dégradée

APRÈS :
> **When** il contrôle chaque règle du cahier Multi §2 — formules 4 à 7, nombre de paris par ticket physique, **courses sur lesquelles le Multi est proposé (une seule par jour, ou plusieurs comme le montre la fixture du 15/01/2022 : 19 courses sur 48)**, seuil de partants déclarés (14 ?) et s'il conditionne encore l'offre, **différence entre `MULTI` et `E_MULTI`**, **statut et règles du Mini Multi** (pour mémoire : hors périmètre, D quater), requalification des non-partants, ex-aequo, ordre de l'arrivée dégradée

AVANT :
> **And** si le Multi n'existe plus ou si sa mécanique (formules, tickets, garantie) a changé, la story s'arrête sur ce constat et le porteur de projet décide avant toute autre story.

APRÈS :
> **And** si le Multi n'existe plus ou si sa mécanique (formules, tickets, garantie) a changé, la story s'arrête sur ce constat et le porteur de projet décide avant toute autre story
> **And** le résultat sur l'éligibilité (plusieurs courses par jour, seuil) est reporté dans `fixtures/multi_regles.json` (`eligibilite`: type de pari `MULTI`, `partants_declares_min` ou `null`) ; s'il contredit D quater, la story s'arrête de même.

AVANT :
> **Then** chaque constante du module est égale à celle de `fixtures/multi_regles.json`, chargé depuis la racine du dépôt comme `engine_constants.json` (AD-2), et tout écart fait échouer le test

APRÈS :
> **Then** chaque constante du module est égale à celle de `fixtures/multi_regles.json`, chargé depuis la racine du dépôt comme `engine_constants.json` (AD-2), et tout écart fait échouer le test
> **And** `regles.py` porte `EMPREINTE_REGLES`, le sha256 du fichier canonique, vérifié par le même test (miroir d'exécution, AD-2 et AD-12)

AVANT :
> **And** les cas fixes de cette story sont écrits dans la section `regles` de `fixtures/multi_cases.json` (créé), pour être rejoués en Dart à la story 5.10 (NFR-9).

APRÈS :
> **And** les cas fixes de cette story sont écrits dans la section `regles` de `fixtures/multi_cases.json` (créé), pour être rejoués en Dart à la story 5.14 (NFR-9).

#### E-8 — Story 5.4 (F20)

AVANT :
> **Then** le `Dockerfile` copie `alembic.ini` et `alembic/` (dans le contexte de build `backend/`) (AD-13).

APRÈS :
> **Then** le `Dockerfile` copie `alembic.ini`, `alembic/` et `scripts/` (dans le contexte de build `backend/`), puisque le `CMD` appelle `scripts/demarrer_api.py` (AD-13).

AVANT :
> **Then** le schéma obtenu est identique à celui de la production actuelle : `courses` (avec `heure_depart`), `chevaux`, `participations`, `performances_historiques` (avec `cheval_id`, `participation_id` facultatif et l'index unique `uq_perf_hist_cheval_date_hippo`) — comparaison par inspection dans un test.

APRÈS :
> **Then** le schéma obtenu est identique à celui que `Repository._migrate()` produit au commit de cette story (référence, pas liste fermée : il comprend par exemple `performances_historiques.rang_impute`, ajouté par la branche `fix/ingestion-etat-terrain`) — comparaison par inspection dans un test entre une base créée par `create_all` + `_migrate()` et une base créée par `alembic upgrade head`.

AVANT :
> **Then** il n'appelle plus ni `create_all` ni `_migrate` ; seuls les tests sur base jetable créent le schéma, via un paramètre explicite

APRÈS :
> **Then** il n'appelle plus ni `create_all` ni `_migrate` ; seuls les tests sur base jetable créent le schéma, via un paramètre explicite
> **And** les instanciations de `Repository()` à l'import (`routes_analyse.py`, `routes_chevaux.py`, `routes_courses.py`) et dans les jobs (`scheduler.py`, `ingest_daily.py`, `backfill_historique.py`) ne créent plus aucun schéma (test)

#### E-9 — Story 5.5, réécriture complète (F1, F2, F4, F28)

Remplacer toute la story (du titre `### Story 5.5: Savoir si une course est éligible au Multi` jusqu'à la ligne précédant `### Story 5.6: Catalogue de systèmes vérifié`) par :

```markdown
### Story 5.5: Savoir si une course est éligible au Multi

En tant que turfiste,
je veux savoir, pour chaque course du programme, si le Multi y est proposé,
afin d'ouvrir le Multi là où il existe et de comprendre pourquoi il est indisponible ailleurs.

**Acceptance Criteria:**

**Given** la fixture `backend/tests/fixtures/pmu/programme_15012022.json` et une journée 2026 complète capturée pour cette story dans `backend/tests/fixtures/pmu/` (programme, plus les participants d'au moins une course MULTI ; si possible un jour où un partant est non-partant), avec au moins une course proposant `MULTI` et une ne proposant que `MINI_MULTI` — capture ponctuelle de moins de 10 appels, notée dans la story (PRD OQ 6)
**When** `pmu_client.get_programme` lit une course
**Then** `CourseInfo.multi_propose` vaut `True` si `paris[].typePari` contient exactement `MULTI` (`E_MULTI` seul ne suffit pas), `False` si la liste est lue et ne le contient pas, `None` si elle est absente ou illisible — jamais `False` par défaut ; `CourseInfo.mini_multi_propose` suit la même règle pour `MINI_MULTI` ; le champ est documenté en commentaire dans `pmu_client.py`
**And** sur la fixture du 15/01/2022, avec le filtre `FRA` par défaut, exactement 15 courses ont `multi_propose = True` (test)
**And** aucun autre module ne lit ce champ brut (AD-1, FR-16).

**Given** `pmu_client.get_participants`
**When** un partant porte le statut non-partant de la source (valeur exacte relevée sur une capture réelle et documentée en commentaire)
**Then** `PartantInfo.non_partant` vaut `True`
**And** les notes de la story disent si `nombreDeclaresPartants` compte les non-partants ; `nb_partants_declares` stocké est toujours le nombre de partants déclarés **non-partants compris**, recalculé si besoin.

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée la table `multi_course` (`course_id` unique, `multi_propose` facultatif, `mini_multi_propose` facultatif, `nb_partants_declares`, `arrivee_json` facultatif, `finalisee`, `arrivee_corrigee_le` facultatif, `donnees_maj_le`, instants en UTC) et ajoute `participations.non_partant` (booléen, faux par défaut) — rien d'autre (AD-10, AD-13).

**Given** le job d'ingestion du programme et des partants
**When** il enregistre une course
**Then** il écrit, via `repository.py` et lui seul (AD-10), `multi_propose`, `mini_multi_propose`, le nombre de partants déclarés et `donnees_maj_le` (instant UTC de la dernière lecture des partants et des cotes)
**And** un partant au statut non-partant de la source a `non_partant = True`.

**Given** une course dont au moins un partant a `non_partant = True`
**When** `repository.get_horses_for_course` et `/analyse` construisent l'entrée du moteur de scoring
**Then** le non-partant est exclu des chevaux et `nb_partants_course` vaut « partants déclarés − non-partants », si bien qu'aucun partant virtuel ne le remplace (AD-6, décision F2)
**And** un cas de `fixtures/engine_cases.json` (ajouté) fixe ce comportement : sur un champ de 16 déclarés dont 1 non-partant et 15 analysés, aucun partant virtuel, probabilités qui somment à 1 ; le test Dart de ce cas est écrit à la story 5.7.

**Given** le job de finalisation (`ingest_resultats_veille`)
**When** l'arrivée d'une course est définitive
**Then** il écrit `arrivee_json` (5 premières places avec ex-aequo, ex. `[{"rang": 4, "nums": [3, 12]}]`) ; tant que la course n'est pas finalisée, la valeur reste `NULL` et n'est jamais inventée ; deux exécutions donnent le même résultat (FR-17)
**And** pour les courses finalisées depuis moins de `MULTI_RECONTROLE_ARRIVEE_JOURS` jours (défaut 3, variable d'environnement), il relit l'arrivée : si elle a changé, il met à jour `arrivee_json` et `arrivee_corrigee_le` et journalise la correction ; sinon il ne modifie rien.

**Given** `repository.get_multi_contexte(course)`
**When** il construit le contexte Multi d'une course (AD-6)
**Then** le contexte porte `cle_course` (`AAAAMMJJ-Rn-Cn`, AD-12), `eligible`, `raison` (`multi_non_propose`, `mini_multi_non_pris_en_charge`, `paris_inconnus`, `moins_de_n_partants` avec `n` et le nombre — seulement si `regles.py` fixe un minimum —, ou rien), `nb_partants_declares`, les dossards non-partants, `donnees_a` (UTC), `statut_modele` (`en_cours_d_evaluation`) et `seuils_provisoires` (`true`)
**And** il n'y a ni `mode_exploration` ni `est_course_support`, ni aucun champ d'argent ; le minimum de partants éventuel vient de `regles.py` (story 5.1), jamais d'un littéral.

**Given** les cas d'éligibilité
**When** les tests tournent
**Then** `MULTI` proposé → éligible ; `MINI_MULTI` seul → `mini_multi_non_pris_en_charge` ; liste lue sans aucun des deux → `multi_non_propose` ; liste absente → `paris_inconnus` ; si `regles.py` fixe 14 et que la course en déclare 13 avec `MULTI` → `moins_de_n_partants`
**And** un non-partant survenu après la déclaration ne fait pas perdre l'éligibilité
**And** une course ingérée avant cette story, sans ligne `multi_course`, a la raison `paris_inconnus` jusqu'à sa prochaine ingestion.

**Given** l'API existante
**When** `/courses` et `/courses/{id}/partants` répondent
**Then** chaque `CourseOut` porte `cle_course`, `numero_reunion`, `numero_course` et un objet `multi` typé (`MultiContexteOut`, AD-4), et chaque `ParticipationOut` porte `non_partant`
**And** côté mobile, `mobile/lib/models/multi_contexte.dart` (créé), `CourseSummary` (`cleCourse`, `numeroReunion`, `numeroCourse`, `multi`) et `Horse` (`nonPartant`) lisent ces champs ; un champ absent (ancien backend) donne un contexte nul, que l'app traitera comme « contexte Multi non chargé » ; leur mise en cache locale arrive à la story 5.7.
```

#### E-10 — Nouvelle story 5.6 (F9)

Insérer après la story 5.5 :

```markdown
### Story 5.6: Rafraîchir les partants et les cotes d'une course avant le départ

En tant que turfiste,
je veux pouvoir demander, avant le départ, la relecture des partants et des cotes d'une course où le Multi est proposé,
afin que les non-partants déclarés dans la journée et les cotes récentes arrivent dans mon pronostic.

**Acceptance Criteria:**

**Given** une fonction `rafraichir_partants(repository, course)` (créée dans `backend/app/jobs/ingest_daily.py`)
**When** elle est appelée
**Then** elle relit `pmu_client.get_participants` pour cette seule course et met à jour, via `repository.py`, les cotes, `non_partant` et `multi_course.donnees_maj_le` (UTC) ; elle ne relit ni le programme ni l'historique
**And** la même fonction servira au job de journalisation (story 6.7).

**Given** `POST /multi/courses/{cle_course}/rafraichir` (`backend/app/api/routes_multi.py`, créé ; schéma `RafraichissementOut`, AD-4)
**When** la course existe, est éligible, son départ n'est pas passé (heure inconnue : jusqu'à la fin du jour de la course, heure de Paris) et `donnees_maj_le` date de plus de `MULTI_RAFRAICHISSEMENT_MIN_MINUTES` (défaut 5, variable d'environnement)
**Then** la route relit la source, puis renvoie `rafraichi: true`, le contexte Multi (story 5.5) et la liste des partants au format `ParticipationOut`
**And** sinon elle renvoie l'état stocké avec `rafraichi: false` et `raison` (`donnees_recentes`, `depart_passe`) sans appeler la source (test avec un client PMU simulé : deux appels dans la fenêtre → un seul appel à la source).

**Given** une clé mal formée (`^\d{8}-R\d+-C\d+$`), une course inconnue ou non éligible
**When** la route est appelée
**Then** elle renvoie respectivement 422 `cle_course_invalide`, 404, ou 422 `course_non_eligible` avec sa raison.

**Given** une source PMU indisponible
**When** la relecture échoue
**Then** la route renvoie 503 avec le code `source_indisponible`, la base reste inchangée et l'échec est journalisé.

**Given** le scheduler du conteneur `ingestion`
**When** cette story est livrée
**Then** il ne gagne aucune relecture périodique des partants : seuls l'ingestion de 6 h, cette route et le job de journalisation (story 6.7) relisent les partants (décision du 2026-10-18, PRD OQ 6).
```

#### E-11 — Nouvelle story 5.7 (F10, F2 côté Dart, F4)

Insérer après la story 5.6 :

```markdown
### Story 5.7: Rouvrir une course hors ligne après redémarrage (cache local v2, rafraîchir la course)

En tant que turfiste,
je veux qu'une course déjà ouverte se rouvre sans réseau même après avoir fermé l'application, et pouvoir rafraîchir ses partants à la demande,
afin de préparer mon pronostic sur l'hippodrome, où le réseau manque.

**Acceptance Criteria:**

**Given** `mobile/lib/data/local/database_helper.dart`
**When** la base passe en version 2 (AD-9)
**Then** `onCreate` crée directement la version 2 et `onUpgrade` migre de 1 à 2 sans perdre les lignes existantes, les deux chemins testés avec `sqflite_common_ffi`
**And** la version 2 ajoute à `programme_courses` les colonnes `cle_course`, `numero_reunion`, `numero_course` et `multi_contexte` (JSON, facultatif), et crée `partants_course` (`cle_course` clé primaire, `course_id`, `contenu_json` = réponse de `/courses/{id}/partants` telle que reçue, `lu_le` UTC).

**Given** `CourseRepository.partants(course)` avec réseau
**When** les partants sont reçus
**Then** ils sont enregistrés dans `partants_course` (remplacement) puis renvoyés
**And** sans réseau ou en cas d'échec, le cache est renvoyé avec sa provenance, et Liste des partants affiche « Partants du 18/10 à 9 h 38 (hors ligne) » ; sans cache, le message d'échec actuel est conservé (FR-15).

**Given** l'application redémarrée sans réseau
**When** l'utilisateur ouvre depuis l'Accueil une course déjà ouverte
**Then** la liste des partants et le contexte Multi viennent du cache, et le classement se calcule sur l'appareil (FR-13, NFR-3)
**And** les modifications manuelles de la liste (ajout, cote modifiée) ne sont pas conservées après fermeture : l'écart avec l'Epic 3 (FR-14) est noté dans les notes de la story.

**Given** un cheval avec `nonPartant = true`
**When** l'adaptateur Dart construit l'entrée de `analyseCourse`
**Then** il l'exclut et passe `nbPartantsCourse` = déclarés − non-partants ; le cas ajouté à `fixtures/engine_cases.json` par la story 5.5 passe en Dart (AD-2).

**Given** une course éligible et le réseau
**When** l'utilisateur touche « Rafraîchir la course » (Liste des partants ; en-tête du Multi à la story 5.16)
**Then** l'app appelle `POST /multi/courses/{cle_course}/rafraichir`, met à jour le cache, les cotes et les non-partants de la liste, et le contexte Multi
**And** si au moins un nouveau non-partant arrive, le classement est recalculé automatiquement avec les mêmes réglages, et Résultats affiche « Non-partant : n° 7 — classement recalculé » au lieu de « Résultat périmé » ; si seules les cotes changent, le classement passe en « Résultat périmé » comme aujourd'hui
**And** `rafraichi: false` est dit en clair (« Données déjà à jour (9 h 38) », « Départ passé : partants figés ») ; sans réseau, « Rafraîchissement impossible hors ligne », le cache reste affiché (FR-15).

**Given** le démarrage de l'application
**When** des lignes de `partants_course` portent sur des courses de plus de 90 jours
**Then** elles sont supprimées (même purge que la story 5.20, horloge injectée en test).
```

#### E-12 — Story 5.8 (ex-5.6), section `verification` (F17)

Renommer le titre `### Story 5.6: Catalogue de systèmes vérifié` en `### Story 5.8: Catalogue de systèmes vérifié`.

AVANT :
> **And** au chargement, un catalogue dont `version` ne correspond pas à ses entrées est refusé avec le code `catalogue_invalide`.

APRÈS :
> **And** au chargement, un catalogue dont `version` ne correspond pas à ses entrées est refusé avec le code `catalogue_invalide`
> **And** chaque cas du vérificateur (système valide, ticket retiré, sélection trop petite, cheval hors sélection, base oubliée, dossard répété, système plus petit trouvé au catalogue) est écrit dans la section `verification` de `fixtures/multi_cases.json`, entrées et preuves attendues, pour être rejoué en Dart à la story 5.14 (NFR-9).

#### E-13 — Stories 5.9, 5.10, 5.11 : découpage de l'ancienne 5.7 (F18, F2, F11, F12)

Remplacer toute l'ancienne story 5.7 (du titre `### Story 5.7: Moteur Multi Python : couverture, sélection pour une taille, chevaux les plus probables, systèmes par formule, relabellement` jusqu'à la ligne précédant `### Story 5.8: Indice de confiance…`) par les trois stories suivantes :

```markdown
### Story 5.9: Moteur Multi Python : couverture et sélection pour une taille

En tant que développeur,
je veux le cœur du moteur Multi en Python — probabilités de couverture et sélection du modèle à une taille donnée —, branché sur la sortie du moteur de scoring,
afin que le backend sache, de façon déterministe, quels chevaux maximisent la probabilité que l'arrivée soit dans la sélection.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/modeles.py`, `couverture.py` et `recommandation.py` (créés)
**When** ils sont importés
**Then** ils ne dépendent que de `app.engine` (AD-1)
**And** un adaptateur `depuis_analyse(...)` construit les `ChevalMulti` et le champ (chevaux réels partants + partants virtuels) depuis la sortie du scoring, sans recalculer score, `top4` ni value (AD-6) — test : `top4` identique au scoring.

**Given** la sortie du scoring
**When** l'adaptateur calcule les drapeaux de transparence (FR-27)
**Then** il applique les définitions de la section `constantes_moteur` de `fixtures/multi_cases.json` (créée ici) : `inedit` ; `historique_court` si `0 < nb_perfs < len(RECENCE_STD)` ; `donnees_non_saisies` si `nb_perfs == 0` et non inédit ; `terrain_majoritairement_inconnu` si strictement plus de la moitié des performances utilisées par la forme ont un terrain `NULL`
**And** la longueur de la fenêtre est validée contre `fixtures/engine_constants.json` ; les cas sont écrits dans la section `drapeaux`.

**Given** un cheval sans dossard, ou des dossards en double
**When** le champ est construit
**Then** un cheval sans dossard reste dans le champ mais n'est jamais sélectionnable, et `chevaux_sans_dossard` (`nb`) est émis ; des dossards en double lèvent l'erreur `dossards_en_double` (`nums`) (FR-22).

**Given** un champ de n chevaux (réels et virtuels)
**When** `couverture.py` calcule `P_ens` sur tous les ensembles de 4 chevaux (énumération exacte Harville, cahier Multi §6.1), `p_couverture(S, B)`, la distribution du nombre de chevaux capturés (0 à 4) et `h_norm`
**Then** le test 8 passe : `Σ P_ens = 1` à 1e-9 ; `E[X] = Σ top4` ; à forces égales, loi hypergéométrique à 1e-9
**And** les partants virtuels entrent dans le champ mais jamais dans une sélection ; un non-partant n'est jamais dans le champ (il a été exclu avant le scoring, story 5.5) et le moteur ne retire ni ne renormalise jamais lui-même une probabilité (AD-6).

**Given** une taille `v`, des bases, des chevaux imposés et des chevaux retirés
**When** `selectionner` applique l'algorithme du cahier Multi §4.1 et l'annexe C
**Then** les comparaisons se font sur des probabilités quantifiées à la grille 1e-9 et les égalités suivent les règles du cahier (`top4` décroissant, puis `p_gagnant`, puis dossard ; échange : dossard entrant puis sortant le plus petit) (AD-6, FR-23)
**And** la recherche d'échanges est bornée par `ITERATIONS_ECHANGES_MAX` (section `constantes_moteur`) ; une recherche tronquée ajoute l'avertissement `optimisation_tronquee`.

**Given** les cas d'erreur
**When** `v < 4`, `v > 20`, `v` supérieur au nombre de sélectionnables, plus de 3 bases, une base hors sélection, un dossard inconnu, ou imposés et bases plus nombreux que `v`
**Then** le moteur lève une erreur portant un code (`taille_hors_bornes`, `taille_superieure_aux_selectionnables`, …), jamais une phrase.

**Given** les tests 9 et 10 du cahier Multi §9
**When** ils tournent
**Then** sur des champs de 10 chevaux au plus, la sélection a la même `p_couverture` que l'optimum exhaustif, et au moins un cas montre que le tri par `top4` seul n'est pas optimal et que les échanges le corrigent
**And** la sélection compte exactement `v` chevaux pour chaque `v` de 4 à `min(20, sélectionnables)` ; `p_couverture` ne décroît pas quand `v` augmente
**And** deux appels identiques donnent le même résultat ; aucune clé `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` n'apparaît (NFR-8)
**And** les cas fixes sont écrits dans les sections `drapeaux`, `couverture` et `selection` de `fixtures/multi_cases.json`, quantifiés, lisibles par Dart (NFR-9).

### Story 5.10: Moteur Multi Python : chevaux les plus probables, systèmes par formule, relabellement

En tant que développeur,
je veux que le moteur Python propose les chevaux les plus probables comme bases et renvoie, pour chaque formule, un système vérifié en dossards,
afin que le pronostic dise quelles bases activer et ce que chaque formule couvre réellement.

**Acceptance Criteria:**

**Given** la sélection sans base à la taille choisie (story 5.9)
**When** les bases candidates sont calculées (FR-24)
**Then** il y en a 3 (moins si la sélection en compte moins), ordonnées par `top4`, `p_gagnant` puis dossard, aucune active par défaut
**And** chacune porte `top4`, les tickets économisés par formule (≥ 0) et la couverture perdue (≥ 0) — test 11.

**Given** une sélection et ses bases actives
**When** `systemes(...)` est appelé (FR-25)
**Then** il renvoie un système par formule `k ≤ v` présente au catalogue (story 5.8), de `k = 7` à `k = 4`, avec `nb_tickets`, `nb_tickets_physiques` (`⌈nb_tickets / 4⌉`), la garantie, la même `p_couverture` pour toutes et les grilles en dossards
**And** le relabellement est canonique (non-bases triées par `top4`, `p_gagnant`, dossard → indices `0..v'-1`) et chaque système est revérifié avant d'être renvoyé ; un système non couvrant n'est jamais renvoyé
**And** une forme absente donne l'avertissement `systeme_absent_du_catalogue` (`{k}`) ; des règles non vérifiées (story 5.1) donnent zéro système et l'avertissement `regles_non_verifiees`.

**Given** toutes les sorties de cette story
**When** les tests de forme tournent
**Then** deux appels identiques donnent le même résultat ; seules des `Explication(code, params)` y figurent ; aucune clé d'argent (NFR-8)
**And** les cas fixes sont écrits dans les sections `bases` et `systemes` de `fixtures/multi_cases.json`, listes complètes de tickets après relabellement (NFR-9).

### Story 5.11: Moteur Multi Python : évaluation, non-partant et bilan d'arrivée

En tant que développeur,
je veux que le moteur Python évalue n'importe quelle sélection, dise ce que deviennent les tickets avec un non-partant et calcule le bilan d'une arrivée,
afin d'expliquer les retouches de l'utilisateur, de requalifier un pronostic retenu et de faire le débrief.

**Acceptance Criteria:**

**Given** une sélection quelconque (dont celle de l'utilisateur)
**When** `evaluer(...)` est appelé (FR-28, FR-30)
**Then** il renvoie `p_couverture`, la distribution des chevaux capturés, la contribution de chaque cheval (baisse de `p_couverture` s'il est retiré), les 3 écartés de plus fort `top4`, 1 à 2 échanges suggérés qui augmentent `p_couverture` (aucun s'il n'y en a pas) et le coût en couverture des chevaux imposés par rapport au pronostic libre à taille égale.

**Given** des tickets et un cheval de la sélection
**When** `simuler_non_partant(...)` est appelé
**Then** il renvoie la formule effective de chaque ticket (requalification de la story 5.1) ou « ticket annulé », sans calculer de nouvelle `p_couverture` (cahier Multi §6.6 : le non-partant réel passe par le moteur de scoring, AD-6).

**Given** une sélection et une arrivée avec ex-aequo
**When** `bilan_arrivee(selection, arrivee)` est appelé
**Then** il renvoie le nombre de chevaux capturés (maximum sur les combinaisons payables) et « arrivée dans la sélection » selon les ex-aequo et l'arrivée dégradée ; une arrivée inexploitable renvoie le code `arrivee_inexploitable`.

**Given** toutes les sorties de cette story
**When** les tests de forme tournent
**Then** deux appels identiques donnent le même résultat (test 15) ; seules des `Explication(code, params)` y figurent ; aucune clé `cout`, `budget`, `multiplicateur`, `mise`, `gain`, `rapport` ni `prix` (NFR-8)
**And** les cas fixes sont écrits dans les sections `evaluation`, `non_partant` et `bilan` de `fixtures/multi_cases.json` (NFR-9).
```

#### E-14 — Story 5.12 (ex-5.8), réécriture complète (F6, F12, F13, F1)

Remplacer toute l'ancienne story 5.8 (du titre `### Story 5.8: Indice de confiance et explications (Python), registre multi_codes.json, seuils provisoires par taille` jusqu'à la ligne précédant `### Story 5.9: API du pronostic Multi…`) par :

```markdown
### Story 5.12: Indice de confiance et explications (Python), registre multi_codes.json, règle provisoire des seuils

En tant que développeur,
je veux que le moteur Python qualifie chaque pronostic par un indice de confiance avec ses raisons et explique chaque élément par des codes déclarés dans un registre,
afin que l'utilisateur sache à quel point se fier au pronostic et pourquoi, sans phrase figée dans le moteur.

**Acceptance Criteria:**

**Given** `backend/app/engine/multi/confiance.py` (créé), `p = p_couverture(S, B)`, `h_norm`, les drapeaux de la story 5.9 et `n` = nombre de chevaux du champ (réels partants et virtuels)
**When** l'indice est calculé (cahier Multi §6.4, FR-26)
**Then** le niveau de départ suit les seuils de la taille `v` : un seuil fixé (utilisateur ou pilote) pour `v` s'applique ; sinon la règle provisoire D quater : `p_hasard(v) = C(v,4) / C(n,4)`, `moyenne` si `p ≥ min(max(2 × p_hasard ; 0,15) ; 0,90)`, `elevee` si `p ≥ min(max(3 × p_hasard ; 0,35) ; 0,95)`, sinon `faible`
**And** le niveau baisse d'**un seul** cran si `h_norm ≥ seuil_course_ouverte` **ou** si les données sont fragiles (part des chevaux de la sélection portant `inedit`, `historique_court` ou `donnees_non_saisies` ≥ `seuil_donnees_fragiles`, ou favori fragile : meilleur `p_gagnant` des chevaux réels portant l'un de ces drapeaux ou `terrain_majoritairement_inconnu`) ; il ne descend jamais sous `faible`
**And** si la sélection contient tous les chevaux du champ (`p_couverture = 1` par construction), aucun niveau n'est donné et le code `selection_egale_au_champ` est émis.

**Given** tout indice calculé
**When** il est renvoyé
**Then** il porte au moins les raisons `couverture` (`p_couverture`, `taille`, `bases_comprises`), `ouverture_course` (`h_norm`), `donnees` (inédits, historiques courts, données non saisies, cotes manquantes, partants non analysés) et, s'il y a lieu, `favori_fragile` (`num`), ainsi que l'état `seuils_provisoires` et `statut_modele`
**And** la fragilité ajoute l'avertissement fort `donnees_fragiles` (FR-23)
**And** une course non éligible n'a pas d'indice ; aucun code ne dit « course non support », « jouer » ou « passer » ; aucune entrée ne vient de la presse.

**Given** le test 12 du cahier Multi §9
**When** les cas de la section `confiance` de `fixtures/multi_cases.json` tournent
**Then** chaque niveau et chaque abaissement (course ouverte, données fragiles, favori fragile, les deux à la fois = un seul cran) est atteint par au moins un cas
**And** un cas fixe les seuils de la règle provisoire pour n = 16 et n = 14, v = 4 à 16 (ex. n = 16 : v = 10 → 0,2308 / 0,35 ; v = 12 → 0,5440 / 0,8159), quantifiés à 1e-9.

**Given** `fixtures/multi_parametres_pilote.json` (créé)
**When** il est écrit avant le pilote
**Then** il contient `regle_provisoire` (`multiplicateur_moyenne: 2`, `plancher_moyenne: 0.15`, `plafond_moyenne: 0.90`, `multiplicateur_elevee: 3`, `plancher_elevee: 0.35`, `plafond_elevee: 0.95`), `seuil_confiance_elevee[v]` et `seuil_confiance_moyenne[v]` à `null` pour chaque taille de 4 à 20 (= règle provisoire), `seuil_course_ouverte: 0.90`, `seuil_donnees_fragiles: 0.25`, `tailles_reference` et `effectif_minimal` à `null`, `provisoire: true` et une `provenance` qui cite la décision D quater du 2026-10-18 — remplacé par le pilote (story 6.6)
**And** `backend/app/engine/multi/parametres.py` en porte le miroir d'exécution validé par test contre le fichier (AD-2, AD-11), et le contexte Multi de la story 5.5 lit désormais `seuils_provisoires` dans ce miroir.

**Given** des seuils fournis par l'utilisateur
**When** ils sont incohérents (seuil moyen supérieur au seuil élevé, valeur hors de [0, 1], taille absente)
**Then** le moteur lève une erreur codée ; des seuils à `null` prennent la valeur par défaut de la taille (pilote, sinon règle provisoire).

**Given** `backend/app/engine/multi/explications.py` (créé)
**When** le pronostic est expliqué (FR-27)
**Then** chaque cheval retenu porte `retenu_top4` ou `retenu_par_echange` (`top4`, `rang_modele`, hausse de couverture), `contribution` et ses drapeaux de transparence ; chacun des 3 écartés porte sa raison (`ecarte_top4_faible`, `ecarte_donnees_fragiles`, `ecarte_par_vous`) ; chaque base candidate porte `base_candidate` ; chaque système porte `systeme_formule` (`k`, `nb_tickets`, `nb_tickets_physiques`) ; les limites des données portent `cotes_du` (heure UTC), `cote_manquante` (`num`), `partants_non_analyses` (`nb`) et `chevaux_sans_dossard` (`nb`)
**And** aucun code n'exprime une value.

**Given** `fixtures/multi_codes.json` (créé)
**When** les tests du registre tournent (AD-8, NFR-11)
**Then** chaque code émis dans tous les cas de `fixtures/multi_cases.json` (stories 5.8 à 5.12) est déclaré avec exactement ses paramètres, sa famille (raison, explication, avertissement, erreur) et sa force (normale ou forte)
**And** un code non déclaré ou un paramètre en trop fait échouer la suite.

**Given** `fixtures/multi_versions.json` (créé : version du moteur Multi, du registre, des paramètres du pilote) et `backend/app/engine/multi/versions.py`, son miroir d'exécution validé par test (AD-2, AD-12)
**When** `identite_pronostic(...)` est calculée
**Then** elle réunit la clé de course, la version du moteur (lue dans `versions.py`), la `version` du catalogue, `regles.EMPREINTE_REGLES`, l'empreinte sha256 des paramètres canoniques et `donnees_a` (UTC), sans lire aucun fichier de `fixtures/` à l'exécution
**And** un cas partagé fixe l'identité attendue pour la comparer en Dart.
```

#### E-15 — Story 5.13 (ex-5.9), clé PMU et éligibilité (F4, F1)

Renommer le titre `### Story 5.9: API du pronostic Multi (éligibilité, recommandation, systèmes, vérifier, évaluer)` en `### Story 5.13: API du pronostic Multi (contexte, recommandation, systèmes, vérifier, évaluer)`.

AVANT :
> **Given** `backend/app/api/routes_multi.py` et `backend/app/schemas/multi.py` (créés), inclus dans `backend/app/main.py`

APRÈS :
> **Given** `backend/app/api/routes_multi.py` (créé à la story 5.6) et `backend/app/schemas/multi.py` (créé), inclus dans `backend/app/main.py`

AVANT :
> **Given** `GET /courses/{id}/multi/eligibilite`
> **When** la course existe
> **Then** la réponse porte le contexte Multi de la story 5.5, les dossards non-partants et, si la course est finalisée, l'arrivée avec ses ex-aequo et `arrivee_corrigee_le`
> **And** une course inconnue renvoie 404.

APRÈS :
> **Given** `GET /multi/courses/{cle_course}` (clé PMU `AAAAMMJJ-Rn-Cn`, AD-12)
> **When** la course existe
> **Then** la réponse porte le contexte Multi de la story 5.5, les dossards non-partants et, si la course est finalisée, l'arrivée avec ses ex-aequo et `arrivee_corrigee_le`
> **And** une course inconnue renvoie 404, une clé mal formée 422 `cle_course_invalide`.

AVANT :
> **Given** `POST /multi/recommandation` avec `course_id` (clé PMU `AAAAMMJJ-Rn-Cn`, AD-12) ou une liste de chevaux saisis comme `/analyse`, `taille`, `bases_actives`, `chevaux_imposes`, `chevaux_exclus`, `non_partants` et `seuils`
> **When** la course est éligible ou en mode exploration
> **Then** la réponse suit le cahier Multi §10 : `taille`, `confiance` (niveau et raisons), `pronostic` (sélection avec rôles et explications, `p_couverture`, `distribution_captures`, `h_norm`), `bases_candidates`, `systemes` de toutes les formules, `ecartes`, `statut_modele`, `seuils_provisoires`, `mode_exploration` et l'identité du pronostic

APRÈS :
> **Given** `POST /multi/recommandation` avec `cle_course` (clé PMU `AAAAMMJJ-Rn-Cn`, AD-12 ; jamais `course_id`) ou une liste de chevaux saisis comme `/analyse`, `taille`, `bases_actives`, `chevaux_imposes`, `chevaux_exclus` et `seuils`
> **When** la course est éligible
> **Then** les non-partants connus du backend sont exclus de l'entrée du scoring (story 5.5) et la réponse suit le cahier Multi §10 : `taille`, `confiance` (niveau et raisons), `pronostic` (sélection avec rôles et explications, `p_couverture`, `distribution_captures`, `h_norm`), `bases_candidates`, `systemes` de toutes les formules, `ecartes`, `statut_modele`, `seuils_provisoires` et l'identité du pronostic

AVANT :
> **When** `taille < 4`, `taille > 20`, `taille` supérieure aux sélectionnables, bases hors sélection, plus de 3 bases, sélection de plus de 20 chevaux, dossard inconnu, `k < 4` ou `k > 7`

APRÈS :
> **When** `taille < 4`, `taille > 20`, `taille` supérieure aux sélectionnables (l'API refuse, seule l'app ramène au plafond), bases hors sélection, plus de 3 bases, sélection de plus de 20 chevaux, dossard inconnu, dossards en double, `k < 4` ou `k > 7`

AVANT :
> **Then** aucune méthode n'appelle `/multi/recommandation`, `/multi/systemes`, `/multi/verifier` ni `/multi/evaluer` : le téléphone calcule toujours localement (AD-6).

APRÈS :
> **Then** aucune méthode n'appelle `/multi/recommandation`, `/multi/systemes`, `/multi/verifier` ni `/multi/evaluer` : le téléphone calcule toujours localement (AD-6) ; il n'appelle que `GET /multi/courses/{cle_course}` (débrief, story 5.21) et `POST /multi/courses/{cle_course}/rafraichir` (story 5.7).

#### E-16 — Story 5.14 (ex-5.10), rejeu `verification` et `drapeaux` (F17, F12)

Renommer le titre `### Story 5.10: Moteur Multi en Dart à parité (couverture, sélection, bases, systèmes, catalogue embarqué)` en `### Story 5.14: Moteur Multi en Dart à parité (couverture, sélection, bases, systèmes, vérification, catalogue embarqué)`.

AVANT :
> **Then** ils n'importent ni `data/`, ni `providers/`, ni Flutter, ni aucune bibliothèque réseau (test qui parcourt les imports, AD-1)
> **And** `regles.dart` est validé contre `fixtures/multi_regles.json` et rejoue la section `regles` de `fixtures/multi_cases.json`.

APRÈS :
> **Then** ils n'importent ni `data/`, ni `providers/`, ni Flutter, ni aucune bibliothèque réseau (test qui parcourt les imports, AD-1)
> **And** `regles.dart` est validé contre `fixtures/multi_regles.json`, porte `EMPREINTE_REGLES` (validée contre le sha256 du fichier) et rejoue la section `regles` de `fixtures/multi_cases.json`.

AVANT :
> **Given** chaque cas des sections `couverture`, `selection`, `bases`, `systemes`, `evaluation`, `non_partant` et `bilan` de `fixtures/multi_cases.json`

APRÈS :
> **Given** chaque cas des sections `drapeaux`, `couverture`, `selection`, `bases`, `systemes`, `verification`, `evaluation`, `non_partant` et `bilan` de `fixtures/multi_cases.json`

AVANT :
> **Then** `top4` et `p_gagnant` sont repris tels quels, jamais recalculés (AD-6)

APRÈS :
> **Then** `top4` et `p_gagnant` sont repris tels quels, jamais recalculés (AD-6) ; les drapeaux suivent les définitions de `constantes_moteur` ; un cheval sans dossard n'est pas sélectionnable et des dossards en double donnent `dossards_en_double`

#### E-17 — Story 5.15 (ex-5.11), versions et numéros (F13)

Renommer le titre `### Story 5.11: Confiance et explications en Dart + table de libellés FR` en `### Story 5.15: Confiance et explications en Dart + table de libellés FR`.

AVANT :
> **And** `parametres.dart` et `versions.dart` sont validés contre `fixtures/multi_parametres_pilote.json` et `fixtures/multi_versions.json`, et l'identité du pronostic du cas partagé est la même qu'en Python (AD-12).

APRÈS :
> **And** `parametres.dart` (règle provisoire comprise) et `versions.dart` sont des miroirs d'exécution validés contre `fixtures/multi_parametres_pilote.json` et `fixtures/multi_versions.json` (AD-2) ; l'identité du pronostic du cas partagé, calculée avec `regles.EMPREINTE_REGLES`, est la même qu'en Python (AD-12).

#### E-18 — Stories 5.16 et 5.17 : découpage de l'ancienne 5.12 (F18, F1, F8, F11)

Remplacer toute l'ancienne story 5.12 (du titre `### Story 5.12: Écran Multi — pronostic (accès depuis Résultats, taille, confiance, sélection, chevaux les plus probables, évaluation)` jusqu'à la ligne précédant `### Story 5.13: Écran Multi — grilles…`) par :

```markdown
### Story 5.16: Écran Multi — accès, taille et confiance

En tant que turfiste,
je veux ouvrir le Multi depuis les résultats d'une course où il est proposé, choisir mon nombre de chevaux et voir la confiance du pronostic,
afin de savoir en un coup d'œil à quel point me fier au pronostic du modèle pour la taille que je choisis.

**Acceptance Criteria:**

**Given** l'écran Résultats d'une course dont le contexte Multi est éligible
**When** le classement est calculé
**Then** un `cta-ghost` « Multi » apparaît sous le titre de la course et ouvre `mobile/lib/screens/multi_screen.dart` (UX-DR1, FR-22)
**And** pour une course non éligible, un `multi-badge` « Multi indisponible » le remplace ; un tap affiche la raison (« Multi non proposé sur cette course », « Mini Multi non pris en charge », « Liste des paris indisponible — rafraîchissez le programme », « Moins de 14 partants déclarés (12) » si les règles fixent ce seuil) ; sans contexte (course saisie à la main ou importée par photo, ancien backend), « Multi indisponible pour une course saisie à la main » ou « Contexte Multi non chargé — rafraîchissez le programme ».

**Given** l'écran Multi qui s'ouvre
**When** le pronostic est calculé
**Then** il l'est par le moteur Dart via `mobile/lib/providers/multi_provider.dart`, sans aucun appel réseau (test avec un client API qui échoue à tout appel, FR-13, AD-6)
**And** l'en-tête montre la course, « 18 partants · course éligible », « Cotes de 9 h 38 » (`donnees_a`), « Modifiable jusqu'au départ (15 h 05) », l'icône Réglages, « Rafraîchir la course » (story 5.7) et « L'outil ne place aucun pari », puis les bandeaux d'état, la taille, la confiance et, en fin d'écran, le rappel de jeu responsable (UX-DR2, NFR-7) ; les sections suivantes arrivent aux stories 5.17 et 5.18.

**Given** le `size-stepper` au premier affichage
**When** l'écran s'ouvre
**Then** la taille vaut 10, plafonnée au nombre de sélectionnables (analysés, partants, avec dossard unique), avec la ligne « Plafond : 15 partants analysés » (FR-23)
**And** à une borne, le bouton concerné est désactivé, pas masqué, avec sa raison
**And** chaque tap change la valeur tout de suite ; le recalcul part après environ 800 ms sans nouveau tap ; entre-temps, l'ancien état reste affiché atténué, sans résultat intermédiaire (UX-DR3)
**And** le contrôle est un seul nœud ajustable TalkBack (« Taille de la sélection, 12 chevaux, de 4 à 20 ») et une seule annonce polie suit un recalcul, seulement si le niveau de confiance a changé.

**Given** la `confidence-card`
**When** l'indice est affiché (FR-26, UX-DR4)
**Then** elle montre « Confiance élevée », « Confiance moyenne » ou « Confiance faible », les raisons en libellés courts (arrivée dans la sélection estimée, ouverture de la course, données) et les étiquettes « modèle en cours d'évaluation » et « seuils provisoires » quand elles s'appliquent ; sans niveau (`selection_egale_au_champ`), « Confiance : sans objet — la sélection contient tout le champ »
**And** l'or n'est utilisé que pour « Confiance élevée », toujours doublé du libellé ; « Confiance faible » n'est jamais en rouge et ne bloque rien
**And** des données fragiles ajoutent sous la carte le bandeau fort « ⚠️ 4 chevaux inédits ou à historique court dans la sélection » ; les emojis sont ignorés par TalkBack.

**Given** les états de cette story (UX-DR11)
**When** ils surviennent
**Then** chacun a son traitement : calcul en cours (indicateur dans la carte confiance) ; erreur (« Calcul du Multi impossible : {raison} », taille conservée, retour possible) ; classement modifié (« Classement modifié — recalculez sur Résultats », contenu atténué) ; dossards en double (« Dossards en double : n° 7 — corrigez la liste des partants » + « Analyser », aucun pronostic) ; hors ligne identique au mode connecté.

**Given** l'écran de cette story
**When** un test parcourt tous ses textes
**Then** aucun mot ni symbole d'argent n'apparaît (NFR-8, UX-DR13)
**And** à un facteur de police de 2,0, aucun chiffre n'est tronqué ; les titres de section sont des en-têtes TalkBack ; les mentions obligatoires font partie du flux de lecture (UX-DR12).

### Story 5.17: Écran Multi — sélection, chevaux les plus probables, évaluation et états

En tant que turfiste,
je veux voir, pour la taille choisie, la sélection du modèle, les chevaux les plus probables à activer comme bases et l'évaluation,
afin de savoir quels chevaux peuvent constituer l'arrivée et pourquoi.

**Acceptance Criteria:**

**Given** la section Sélection, sous la confiance
**When** elle est rendue (FR-27, UX-DR5)
**Then** chaque `multi-row` montre dossard, nom, « Top 4 estimé 41 % », « contribution −6 pts », les indicateurs de transparence existants, « Cote manquante » s'il y a lieu et l'étiquette « Base » s'il est base, en un nœud TalkBack groupé
**And** aucun badge de value n'existe dans l'écran (test sur l'arbre de widgets)
**And** les 3 écartés les plus proches suivent sous « Écartés les plus proches », dossard en contour, avec « Écarté : » et leur raison.

**Given** la section « Chevaux les plus probables · selon le modèle »
**When** elle est rendue (FR-24, UX-DR6)
**Then** 3 `base-chip` (moins si la sélection est plus petite) montrent dossard, nom, « Top 4 estimé 58 % », l'effet en base (« −4 pts d'arrivée dans la sélection ») et les tickets économisés en Multi en 7 (« 16 tickets en moins en Multi en 7 », sinon la plus grande formule disponible ; la story 5.18 fera suivre la formule affichée) ; sans système (règles non vérifiées, forme absente), la ligne des tickets est omise ; aucune puce active au premier affichage
**And** chaque puce est une seule cible ≥ 48dp, rôle interrupteur, état « Base imposée dans tous les tickets » / « Interdite comme base » ; un basculement recalcule sélection, confiance et évaluation sur l'appareil
**And** le mot « sûr » n'apparaît nulle part.

**Given** l'`evaluation-block`
**When** il est rendu (FR-30, UX-DR8)
**Then** il montre « Arrivée dans la sélection : 31 % (estimé) » (« bases comprises » s'il y a des bases) et la distribution des chevaux capturés de 0 à 4, en cinq lignes au pourcentage écrit
**And** si le contexte porte `statut_modele = pas_meilleur_que_le_marche`, un bandeau fort en tête de l'Évaluation dit « Évaluation sur N courses : le modèle ne fait pas mieux que le marché », et le pronostic ne bascule vers aucune autre méthode.

**Given** les états de cette story (UX-DR11)
**When** ils surviennent
**Then** partants non analysés : « 3 partants non analysés, non sélectionnables » + « Analyser » vers Liste des partants ; chevaux sans dossard : « 2 chevaux sans dossard, non sélectionnables » + « Analyser » ; cote manquante : « Cote manquante » sur la ligne.

**Given** les sections de cette story
**When** un test parcourt leurs textes
**Then** aucun mot ni symbole d'argent n'apparaît (NFR-8, UX-DR13)
**And** à un facteur de police de 2,0, aucun chiffre ni dossard n'est tronqué (UX-DR12).
```

#### E-19 — Story 5.18 (ex-5.13), formule et puces de base (F8, F25)

Renommer le titre `### Story 5.13: Écran Multi — grilles (formules, feuille des grilles, copie, vérifier un système)` en `### Story 5.18: Écran Multi — grilles (formules, feuille des grilles, copie, vérifier un système)`.

AVANT :
> **And** la formule « Affichée » par défaut est Multi en 7 (sinon la plus grande formule disponible) ; un tap en fait la formule affichée, avec l'état sémantique « sélectionné » et le texte de garantie de la story 5.11, puis « Couverture garantie — pas un gain garanti »

APRÈS :
> **And** la formule « Affichée » par défaut est Multi en 7 (sinon la plus grande formule disponible), sans mémoire d'une course à l'autre ; un tap en fait la formule affichée, avec l'état sémantique « sélectionné » et le texte de garantie de la story 5.15, puis « Couverture garantie — pas un gain garanti »
> **And** les tickets économisés des `base-chip` (story 5.17) suivent la formule affichée.

#### E-20 — Story 5.19 (ex-5.14), réécriture complète (F2, F9, F25)

Remplacer toute l'ancienne story 5.14 (du titre `### Story 5.14: Retoucher sa sélection et gérer les non-partants` jusqu'à la ligne précédant `### Story 5.15: …`) par :

```markdown
### Story 5.19: Retoucher sa sélection et gérer les non-partants

En tant que turfiste,
je veux retirer, ajouter ou imposer un cheval, saisir ma propre sélection et marquer un non-partant, même sans réseau,
afin d'ajuster le pronostic à mes convictions et aux nouvelles du jour en voyant ce que chaque choix change.

**Acceptance Criteria:**

**Given** un tap sur une `multi-row`
**When** la `multi-actions-sheet` s'ouvre, titrée « N° 7, Ondine Royale »
**Then** elle propose Retirer (taille −1), Imposer avec son effet (« Imposer : −3 pts d'arrivée dans la sélection par rapport au pronostic du modèle »), Base oui/non avec l'état courant, Marquer non-partant (FR-28, UX-DR5)
**And** une action ferme la feuille et recalcule sur l'appareil ; une fermeture sans action rend le focus à la ligne ; après « Retirer » ou « Marquer non-partant », le focus va au bandeau de confirmation
**And** une action impossible est désactivée avec sa raison (retirer à 4 chevaux, 4ᵉ base, imposer au-delà de la taille).

**Given** un tap sur un des écartés les plus proches
**When** la `multi-actions-sheet` s'ouvre
**Then** elle est réduite à « Ajouter à la sélection » (taille +1, le `size-stepper` suit, plafond 20), comme le veut EXPERIENCE.md.

**Given** « + Ajouter un cheval »
**When** la `horse-picker-sheet` s'ouvre
**Then** elle liste les partants analysés non retenus (dossard, nom, top 4 estimé) ; un tap ajoute le cheval (taille +1, plafond 20)
**And** les partants non analysés et les chevaux sans dossard sont grisés « à analyser », non sélectionnables ; « Analyser » renvoie à Liste des partants (FR-22).

**Given** « Saisir ma propre sélection »
**When** l'utilisateur coche de 4 à 20 chevaux et touche « Évaluer ma sélection »
**Then** sa sélection remplace celle du modèle, passe en « Modifiée » et est évaluée (confiance, arrivée dans la sélection, systèmes, échanges suggérés)
**And** moins de 4 cases cochées laisse le bouton désactivé avec sa raison.

**Given** une sélection retouchée
**When** elle est recalculée
**Then** l'étiquette « Modifiée » apparaît en tête de section, avec 1 à 2 échanges suggérés (« Échanger n° 8 contre n° 3 : +2 pts d'arrivée dans la sélection » + « Appliquer ») ou aucun s'il n'en existe pas, et « Revenir au pronostic du modèle » qui annule toutes les retouches
**And** un cheval ajouté porte « Ajouté par vous »
**And** les retouches (imposés, retirés, non-partants) sont conservées comme contraintes quand la taille change ; une taille qui ne peut plus les contenir est refusée par le stepper avec sa raison.

**Given** un cheval marqué non-partant, hors ligne compris
**When** l'action est confirmée (FR-23)
**Then** le cheval reçoit `nonPartant = true` dans la liste de la course ; le moteur de scoring est relancé sur l'appareil avec les mêmes réglages, sans lui, et `nbPartantsCourse` = déclarés − non-partants (story 5.7, AD-6) ; le pronostic est recalculé sur la nouvelle sortie, le modèle le remplace pour garder la taille, et le bandeau « Non-partant : n° 7 — pronostic recalculé » s'annonce une fois puis disparaît au recalcul suivant
**And** Résultats affiche le même champ, avec « Non-partant : n° 7 — classement recalculé »
**And** une base marquée non-partante perd son rôle de base, et le bandeau le dit
**And** « Annuler non-partant » dans la feuille du cheval revient en arrière (nouveau calcul du scoring avec le cheval).

**Given** « Rafraîchir la course » dans l'en-tête du Multi, avec réseau (story 5.7)
**When** le backend signale des non-partants
**Then** ils sont appliqués comme un marquage manuel, avec le même bandeau
**And** sans réseau, le rafraîchissement échoue avec un message clair et le marquage manuel reste possible (FR-15).
```

#### E-21 — Story 5.20 (ex-5.15), réécriture complète (F3, F7, F19, F26)

Remplacer toute l'ancienne story 5.15 (du titre `### Story 5.15: Retenir son pronostic, même hors ligne (sqflite v2, gel au départ, purge 90 j, dernière taille)` jusqu'à la ligne précédant `### Story 5.16: …`) par :

```markdown
### Story 5.20: Retenir son pronostic, même hors ligne (sqflite v3, gel au départ, purge 90 j, dernière taille)

En tant que turfiste,
je veux retenir le pronostic que je compte suivre, le remplacer jusqu'au départ et retrouver ma taille et mes seuils habituels,
afin d'avoir sur mon téléphone, sans compte et sans réseau, la seule trace de ce que j'ai décidé.

**Acceptance Criteria:**

**Given** `mobile/lib/data/local/database_helper.dart` en version 2 (story 5.7)
**When** la base passe en version 3 (AD-9)
**Then** `onCreate` crée directement la version 3 et `onUpgrade` migre de 1 à 3 et de 2 à 3 sans perdre les lignes existantes, chaque chemin testé avec `sqflite_common_ffi`
**And** la version 3 crée `pronostic_retenu` (`cle_course` unique, `taille`, `selection_json` (dossard, nom, `top4`, rôle, explications), `bases_json`, `formule_affichee` facultative, `tickets_json` facultatif (grilles de la formule affichée, telles qu'affichées), `version_catalogue` facultative, `modifie`, `confiance_niveau` facultatif, `confiance_raisons_json`, `bases_candidates_json`, `p_couverture`, `distribution_json`, `donnees_a`, `retenu_le`, `heure_depart` facultative, `identite_json`) et `recommandation_consultee` (`cle_course` unique, `libelle_course`, `date_course`, `taille`, `selection_json`, `bases_candidates_json`, `confiance_niveau` facultatif, `confiance_raisons_json`, `p_couverture`, `distribution_json`, `donnees_a`, `heure_depart` facultative, `identite_json`, `consulte_le`, `arrivee_json` facultatif, `arrivee_corrigee_le` facultatif, `arrivee_lue_le` facultatif), instants en UTC.

**Given** un calcul complet du pronostic du modèle (ouverture, taille changée après la pause, retour de Réglages), avant le départ
**When** aucun pronostic n'est encore retenu pour la course
**Then** `recommandation_consultee` est remplacée par ce pronostic (une ligne par course)
**And** dès qu'un pronostic est retenu, seule une nouvelle retenue la réécrit ; après le départ, rien ne l'écrit plus.

**Given** la `multi-action-bar`
**When** l'utilisateur touche « JE RETIENS CE PRONOSTIC », seul CTA plein de l'écran (UX-DR9, FR-28)
**Then** l'app enregistre le pronostic affiché dans `pronostic_retenu` et le pronostic du modèle à la même taille dans `recommandation_consultee`, puis affiche « Pronostic retenu à 9 h 52 » avec une annonce polie
**And** le CTA devient « Remplacer mon pronostic retenu » ; un nouveau pronostic retenu remplace l'ancien (un seul par course)
**And** avec des règles non vérifiées, le pronostic peut être retenu sans formule ni grilles
**And** quand le classement est à recalculer, le CTA est désactivé, pas masqué, avec sa raison
**And** rien n'est envoyé au backend (test avec un client API qui enregistre les appels).

**Given** l'heure de départ (UTC, story 5.2)
**When** elle est passée
**Then** le pronostic retenu est figé : « 🔒 Pronostic figé au départ (15 h 05) » remplace le CTA, les contrôles restent visibles mais désactivés, et toute action échoue avec un message explicite
**And** si l'écran est ouvert au moment du départ, la bascule se fait en direct, avec l'annonce « Départ passé : pronostic figé, lecture seule » et le focus déplacé du CTA vers l'étiquette
**And** si l'heure de départ est inconnue, l'en-tête le dit et le pronostic reste remplaçable jusqu'à la fin du jour de la course (heure de Paris).

**Given** la `tickets-sheet` après une copie réussie (story 5.18)
**When** le pronostic affiché n'est ni retenu à l'identique ni figé
**Then** l'invitation « Retenir ce pronostic ? » (« Retenir » / « Plus tard ») apparaît, n'expire pas et ne retient jamais à la place de l'utilisateur ; « Plus tard » n'enregistre rien (UX-DR7).

**Given** un pronostic retenu qui contient un cheval devenu non-partant
**When** le non-partant est marqué ou reçu (story 5.19)
**Then** un bandeau distinct dit « Votre pronostic retenu contient le n° 7, non-partant » et montre ce que deviennent ses tickets (Multi en 7 → en 6, etc., ou ticket annulé), selon `simuler_non_partant` (story 5.11) (FR-23, UX-DR11)
**And** l'entrée enregistrée n'est pas réécrite.

**Given** le démarrage de l'application
**When** des entrées portent sur des courses de plus de 90 jours
**Then** elles sont supprimées, sans tâche de fond (test avec horloge injectée) (FR-30).

**Given** `shared_preferences`
**When** l'utilisateur change de taille
**Then** la dernière taille est mémorisée et sert de taille par défaut à la course suivante, plafonnée au nombre de sélectionnables (FR-23, UX-DR3)
**And** l'écran Réglages gagne un groupe « Multi » conforme à EXPERIENCE.md : « Seuil de course ouverte », « Seuil de données fragiles », puis « Seuils de confiance par taille » replié, une ligne par taille de 4 à 20 avec « Moyenne à partir de » et « Élevée à partir de » en pourcentage, vides = « Auto » (règle provisoire) ; marqués « provisoire » tant que les paramètres du pilote le sont, réinitialisés avec les autres réglages, refusés et expliqués sous le champ s'ils sont incohérents (FR-26)
**And** au retour vers le Multi, le pronostic est recalculé localement, sans marquer le classement comme périmé.
```

#### E-22 — Story 5.21 (ex-5.16), réécriture complète (F1, F3, F4, F27)

Remplacer toute l'ancienne story 5.16 (du titre `### Story 5.16: Le débrief du lendemain (Mes pronostics Multi, arrivée corrigée, Multi en lecture seule)` jusqu'à la ligne précédant `## Epic 6: Évaluer le pronostic Multi`) par :

```markdown
### Story 5.21: Le débrief du lendemain (Mes pronostics Multi, arrivée corrigée, Multi en lecture seule)

En tant que turfiste,
je veux retrouver sur l'accueil mes pronostics Multi et voir, après la course, combien de chevaux de l'arrivée ils ont capturés,
afin de juger honnêtement mes choix et ceux du modèle, sans embellissement.

**Acceptance Criteria:**

**Given** l'Accueil et les courses éligibles du programme (plusieurs par jour)
**When** leurs cartes sont affichées
**Then** chacune porte un `multi-badge` « Multi » (cible ≥ 48dp) (UX-DR1)
**And** un tap ouvre le Multi directement si un classement à jour de cette course est en mémoire (retour → Accueil), sinon la Liste des partants avec « Calculez le classement pour ouvrir le Multi ».

**Given** la section « Mes pronostics Multi » sous le programme
**When** `recommandation_consultee` contient au moins une course des 90 derniers jours
**Then** une `debrief-row` par course, de la plus récente à la plus ancienne, montre la course (`libelle_course`), la date, la taille, puis deux lignes qui commencent par leur sujet : « Votre pronostic : … » (depuis `pronostic_retenu`) et « Pronostic du modèle : … » (depuis `recommandation_consultee`) (UX-DR10)
**And** sans pronostic retenu, « Votre pronostic : aucun pronostic retenu » ; la section est masquée si elle est vide ; son pied dit « Conservés 90 jours sur ce téléphone ».

**Given** un rafraîchissement explicite de l'Accueil avec réseau
**When** une ligne n'a pas d'arrivée, ou porte sur une course de moins de 5 jours (fenêtre de recontrôle serveur de 3 jours, plus 2 jours de marge)
**Then** l'app lit `GET /multi/courses/{cle_course}` (story 5.13) et enregistre l'arrivée et `arrivee_corrigee_le` dans `recommandation_consultee` ; tant qu'il n'y en a pas, la ligne dit « En attente du résultat »
**And** sans réseau, la ligne reste « En attente du résultat » et un message clair dit que le résultat sera lu au prochain rafraîchissement (FR-15).

**Given** une arrivée officielle disponible
**When** le débrief est calculé avec `bilan_arrivee` du moteur Dart (story 5.14) sur les sélections enregistrées
**Then** chaque ligne dit « N chevaux capturés sur 4 · arrivée dans la sélection : oui / non », pour le pronostic retenu et pour le pronostic du modèle (FR-30)
**And** seule l'arrivée officielle compte ; les ex-aequo et l'arrivée dégradée suivent les règles du pari ; une course sans arrivée exploitable affiche « Aucune arrivée exploitable »
**And** le texte n'a aucune couleur de réussite ni d'échec (ni or ni vert pour « oui »).

**Given** une arrivée corrigée après finalisation (`arrivee_corrigee_le` renvoyé par le backend)
**When** l'Accueil est rafraîchi
**Then** le débrief est recalculé et porte la mention « Arrivée corrigée » (FR-30).

**Given** un tap sur une `debrief-row`
**When** le Multi s'ouvre en état débrief
**Then** l'en-tête montre l'arrivée (4 premiers en dossards) et « 🔒 Pronostic figé au départ (15 h 05) », puis les deux lignes de débrief, puis le pronostic retenu tel qu'enregistré (à défaut, le pronostic du modèle consulté) : taille, confiance (niveau et raisons enregistrés), sélection, chevaux les plus probables, formule, sans aucun recalcul
**And** l'Évaluation est affichée depuis `p_couverture` et `distribution_json` enregistrés ; la section « Autres méthodes » est absente
**And** les chevaux de l'arrivée portent le texte « Capturé » ; tout est en lecture seule ; la barre ne garde que « Voir les grilles », qui affiche `tickets_json` tel qu'enregistré (jamais reconstruit depuis le catalogue courant) et n'existe pas sans pronostic retenu
**And** TalkBack lit chaque ligne en commençant par son sujet (« Votre pronostic : 3 chevaux capturés sur 4, arrivée dans la sélection : non »).
```

#### E-23 — Story 6.1, musique, règle du rang, captures (F5, F14, F28)

AVANT :
> **Then** elle ajoute `performances_historiques.rang_brut` (texte : `1`..`9`, `0`, `D`, `T`, `A`, …) et `performances_historiques.statut_arrivee` (texte), facultatifs

APRÈS :
> **Then** elle ajoute `performances_historiques.rang_brut` (texte : `1`..`9`, `0`, `D`, `T`, `A`, …), `performances_historiques.statut_arrivee` (texte) et `participations.musique` (texte), facultatifs
> **And** `repository.save_partants` écrit `participations.musique` depuis `PartantInfo.musique` ; une commande ponctuelle et idempotente (`python -m app.jobs.remplir_musique`) remplit les lignes anciennes en appelant `pmu_client.musique_depuis_brut(donnees_brutes)` — seul `pmu_client.py` connaît la clé brute (AD-1) ; une ligne sans `donnees_brutes` garde `NULL`, traité comme « absent » ; la commande n'est pas une migration Alembic

AVANT :
> **And** il est validé sur au moins 30 musiques réelles des fixtures de `backend/tests/fixtures/pmu/` ; une chaîne ambiguë renvoie « indécidable » avec un avertissement, jamais un rang deviné ; `NR` est sauté pour remonter à la course réellement courue ; une lettre d'incident inconnue va au pool « queue » avec avertissement.

APRÈS :
> **And** il est validé sur au moins 30 musiques réelles : les fixtures actuelles n'en contiennent que 12, donc la story capture les participants de 2 ou 3 courses supplémentaires (moins de 5 appels, notés dans la story, PRD OQ 6) ; une chaîne ambiguë renvoie « indécidable » avec un avertissement, jamais un rang deviné ; `NR` est sauté pour remonter à la course réellement courue ; une lettre d'incident inconnue va au pool « queue » avec avertissement ; les lettres de discipline sont acceptées en majuscules et en minuscules (cahier Multi annexe D).

AVANT :
> **Then** il fournit `dernier_rang`, `derniere_allocation` et `source_rang` : le rang vient de la musique quand elle est lisible, la liste détaillée servant au recoupement ; en cas de désaccord, `source_rang = "musique"` et l'avertissement `rang_desaccord` (cahier Multi §3, piège `NON_PLACE`)

APRÈS :
> **Then** il fournit `dernier_rang`, `derniere_allocation` et `source_rang` depuis les colonnes stockées (`performances_historiques`, `participations.musique`), jamais depuis `donnees_brutes` : le rang vient de la liste détaillée quand elle donne une place ou un incident ; la musique ne sert que pour `NON_PLACE` sans place ou liste absente ; en cas de désaccord, la liste l'emporte, `source_rang = "liste_detaillee"` et l'avertissement `rang_desaccord` (cahier Multi §3 et annexe D, révisés le 2026-10-18)

#### E-24 — Stories 6.4 et 6.5 : découpage de l'ancienne 6.4 (F18, F1)

Remplacer toute l'ancienne story 6.4 (du titre `### Story 6.4: Backtest sur la machine de dev (sans fuite, constantes figées, export)` jusqu'à la ligne précédant `### Story 6.5: Pilote…`) par :

```markdown
### Story 6.4: Backtest : harnais sans fuite et périodes figées

En tant que porteur de projet,
je veux rejouer le pronostic du modèle et les comparateurs sur l'historique, sans aucune donnée postérieure à l'heure de chaque pronostic,
afin de disposer d'une base honnête pour mesurer s'il fait mieux que le marché.

**Acceptance Criteria:**

**Given** `backend/app/jobs/backtest_multi.py` (créé), adaptateur pilotant configuré par la seule `DATABASE_URL` (AD-11)
**When** il tourne sur la machine de développement contre une copie de la base de production
**Then** il appelle le moteur Multi et `repository.py` comme tout job, en lecture seule (test : aucune écriture en base)
**And** il retient toute course de ≥ 14 partants qui a une arrivée, que le Multi y ait été proposé ou non (cahier Multi §8.1) ; les non-partants connus sont exclus de l'entrée du scoring comme en production (story 5.5).

**Given** une course rejouée en mode `backfill`
**When** les entrées du moteur sont reconstruites à `donnees_a`
**Then** seules les données antérieures sont lues (historique jusqu'à la veille, musique de la participation, cotes finales seulement si le mode les déclare disponibles, sinon B1 et le départage M1 sont marqués `degrade`)
**And** le test 14 passe : supprimer de la base toute donnée postérieure à `donnees_a` ne change pas le pronostic (FR-30).

**Given** le fichier de configuration du backtest
**When** une période est demandée
**Then** chaque période porte son `type_periode` (`developpement`, `validation`, `test`) ; les périodes sont temporelles, jamais tirées au hasard
**And** les constantes dérivées des données (réglages du moteur, quantiles éventuels) sont figées avec leur date `constantes_figees_le`, antérieure au début d'une période de test ; sinon le harnais refuse de tourner.

**Given** les stratégies rejouées — `modele` aux tailles demandées, `modele` sans échanges (ablation), M1, M1-structure, B0 et B1
**When** une course est rejouée
**Then** chaque stratégie produit sa sélection et son `bilan_arrivee` (story 5.11), et les exclusions sont comptées par cause (cote manquante, arrivée absente, données insuffisantes).

### Story 6.5: Backtest : stratégies, métriques et export

En tant que porteur de projet,
je veux les métriques du backtest par stratégie et un export reproductible,
afin de savoir, chiffres et intervalles à l'appui, si le modèle fait mieux que le marché.

**Acceptance Criteria:**

**Given** les résultats de la story 6.4 sur une période
**When** les métriques sont calculées (cahier Multi §8.2)
**Then** le rapport contient le Brier et la courbe de calibration de `p_couverture` comparés au marché, le nombre moyen de chevaux capturés avec la différence appariée contre B1 et son intervalle bootstrap à 95 % (graine fixée), la proportion d'arrivées dans la sélection avec intervalle de Wilson comparée à la loi hypergéométrique, la proportion par niveau de confiance et par taille, l'ablation, et la correction de Holm sur toutes les comparaisons listées
**And** l'alignement de l'heure des cotes de B1 sur celle du modèle est déclaré.

**Given** la fin d'un backtest
**When** les résultats sont exportés
**Then** un fichier JSON porte un en-tête (versions de `fixtures/multi_versions.json`, `version` du catalogue, empreinte des règles, `constantes_figees_le`, période et `type_periode`, commit) et les métriques par stratégie, sans aucun montant ni rapport
**And** deux exécutions identiques donnent le même fichier.
```

#### E-25 — Story 6.6 (ex-6.5), période et gel (F16, F15)

Renommer le titre `### Story 6.5: Pilote et import en production (multi_parametres_pilote.json, performance_strategie, /multi/performance)` en `### Story 6.6: Pilote et import en production (multi_parametres_pilote.json, performance_strategie, /multi/performance)`.

AVANT :
> **Given** le harnais de la story 6.4 sur la période de développement
> **When** le pilote tourne
> **Then** il mesure la variance des métriques et en déduit la taille d'échantillon de la période de test

APRÈS :
> **Given** le harnais des stories 6.4 et 6.5 sur la période de développement, et la règle de taille d'échantillon et de proposition des seuils décidée par le porteur de projet avant cette story (constat F15, différé ; écrite au cahier Multi §8.4)
> **When** le pilote tourne
> **Then** il mesure la variance des métriques et applique cette règle pour fixer la taille d'échantillon de la période de test

AVANT :
> **Then** elle crée seulement la table `performance_strategie` (stratégie, version, période, effectif, métriques, `constantes_figees_le`, `importe_le`).

APRÈS :
> **Then** elle crée seulement la table `performance_strategie` (stratégie, version, période, `type_periode`, `gelee` (booléen : période de test gelée), `close` (booléen : période de test terminée), effectif, métriques, `constantes_figees_le`, `importe_le`).

Remplacer aussi, dans cette story, `(story 6.5)` par `(story 6.6)` partout où la story se cite, et `(AD-11)` reste.

#### E-26 — Story 6.7 (ex-6.6), réécriture complète (F1, F9)

Remplacer toute l'ancienne story 6.6 (du titre `### Story 6.6: Journalisation quotidienne avant le départ (immuable, échecs, résultats à la finalisation)` jusqu'à la ligne précédant `### Story 6.7: …`) par :

```markdown
### Story 6.7: Journalisation quotidienne avant le départ (immuable, échecs, résultats à la finalisation)

En tant que porteur de projet,
je veux que le backend journalise, avant le départ de chaque course éligible du jour, le pronostic du modèle et les comparateurs, et en note le résultat après l'arrivée,
afin que l'évaluation prospective repose sur des pronostics impossibles à retoucher après coup.

**Acceptance Criteria:**

**Given** `fixtures/multi_parametres_pilote.json` sans `tailles_reference` ou encore provisoire (miroir `parametres.py`)
**When** le job de journalisation démarre
**Then** il refuse de journaliser et le dit dans le journal (ordre imposé : pilote → seuils et tailles de référence → journalisation, PRD §6.1).

**Given** une révision Alembic de cette story
**When** elle est appliquée
**Then** elle crée `recommandation_multi` (unique par course, stratégie, version de stratégie, mode et taille de référence ; identité du pronostic, `donnees_a`, confiance pour `modele`, `seuils_provisoires`, `degrade`, `cree_le`), `echec_journal_multi` (course, raison, `survenu_le`) et `resultat_recommandation` (une ligne par entrée journalisée : `nb_captures`, `arrivee_dans_selection`, `calcule_le`) — aucune colonne d'argent (AD-10).

**Given** le job `backend/app/jobs/journal_multi.py` (créé), lancé chaque minute par le scheduler du conteneur `ingestion`
**When** une course éligible du jour (`multi_course.multi_propose` vrai et contexte éligible — environ 15 par jour) arrive à `MULTI_JOURNAL_AVANCE_MINUTES` (défaut 30) de son départ et n'a encore ni entrée ni échec
**Then** il relit ses partants et ses cotes par `rafraichir_partants` (story 5.6), puis journalise, en mode `live`, le pronostic `modele` à chaque taille de référence et les comparateurs M1, B0 et B1, non-partants exclus du scoring, avec `donnees_a` = instant de cette relecture, strictement antérieur au départ (comparaison UTC, AD-12) (FR-30)
**And** si la relecture échoue, il journalise avec les dernières données stockées et `donnees_a` = leur `donnees_maj_le`
**And** une deuxième exécution ne crée pas de doublon (contrainte d'unicité) ; le volume est d'au plus un appel `participants` par course éligible et par jour (PRD OQ 6).

**Given** une entrée de `recommandation_multi`
**When** n'importe quel code du backend tente de la modifier ou de la supprimer
**Then** `repository.py` n'offre aucune méthode pour le faire ; une correction crée une nouvelle `version_strategie`
**And** un non-partant survenu après la journalisation ne réécrit pas l'entrée : son résultat suit la requalification.

**Given** un échec — heure de départ inconnue, départ passé avant que le job ait pu tourner, erreur du moteur, cote manquante pour B1
**When** le job ne peut pas journaliser une stratégie
**Then** il écrit `echec_journal_multi` avec un code de raison (`heure_depart_inconnue`, `depart_passe`, `erreur_moteur`, `cote_manquante`), la course (ou la seule stratégie B1) est exclue de l'évaluation et l'exclusion est comptée
**And** l'échec n'arrête pas la boucle du scheduler.

**Given** le job de finalisation, une fois l'arrivée définitive dans `multi_course`
**When** il traite les entrées journalisées de la course
**Then** il écrit `resultat_recommandation` avec `bilan_arrivee` (ex-aequo et arrivée dégradée compris), de façon idempotente, en seul écrivain de cette table
**And** si l'arrivée est corrigée (story 5.5), le résultat est recalculé et `calcule_le` mis à jour, sans toucher à l'entrée journalisée.
```

#### E-27 — Story 6.8 (ex-6.7), statut par comparateur et cache local (F16)

Renommer le titre `### Story 6.7: Performances et statut du modèle affichés (seuils définitifs, mention retirée ou maintenue)` en `### Story 6.8: Performances et statut du modèle affichés (seuils définitifs, mention retirée ou maintenue)`.

AVANT :
> **Then** `statut_modele` vaut `valide` seulement si, sur la période de test gelée et au-delà de l'effectif minimal, l'intervalle à 95 % de la différence avec B1 exclut 0 du bon côté ; `pas_meilleur_que_le_marche` si la période de test est close sans que ce soit le cas, avec l'effectif ; sinon `en_cours_d_evaluation`
> **And** la même règle décide, pour chaque comparateur, si « hypothèse non validée » est retirée.

APRÈS :
> **Then** `statut_modele` vaut `valide` seulement si, sur une période de `type_periode = test` avec `gelee = true` et au-delà de l'effectif minimal, l'intervalle à 95 % de la différence avec B1 exclut 0 du bon côté ; `pas_meilleur_que_le_marche` si cette période a `close = true` sans que ce soit le cas, avec l'effectif ; sinon `en_cours_d_evaluation`
> **And** la même règle décide, pour chaque comparateur, si « hypothèse non validée » est retirée ; le contexte Multi porte `statut_comparateurs` (`{"M1": "hypothese_non_validee" | "valide", "B1": …}`), lu par l'app.

AVANT :
> **Then** elle les garde en cache local pour l'usage hors ligne ; sans réseau, les dernières valeurs connues restent affichées.

APRÈS :
> **Then** elle garde le contexte dans `programme_courses.multi_contexte` (story 5.7) et la réponse de `/multi/performance` dans une table `performance_multi` (`cle` = filtre demandé, `contenu_json`, `lu_le`) créée par une version 4 de `hippique_cache.db` (`onCreate` v4 direct, `onUpgrade` 3→4 testé, AD-9) ; sans réseau, les dernières valeurs connues restent affichées.

AVANT :
> **Given** des paramètres du pilote non provisoires (story 6.5)

APRÈS :
> **Given** des paramètres du pilote non provisoires (story 6.6)

#### E-28 — Renvois internes restants

Dans les stories non réécrites, remplacer les renvois selon la table §2.3. Occurrences connues au 2026-10-18 hors stories réécrites : aucune dans 5.2, 5.3, 6.1, 6.2, 6.3. Le développeur de chaque story vérifie que tout « story X.Y » pointe vers le nouveau numéro.

#### E-29 — Table « Couverture des exigences Multi », remplacement complet (F21, F18)

AVANT : la table entière sous `### Couverture des exigences Multi` (de `| Exigence | Stories |` à `| UX-DR13 | 5.11, 5.12, 5.13 |`).

APRÈS :

```markdown
| Exigence | Stories |
| --- | --- |
| FR-22 | 5.1, 5.5, 5.9, 5.13, 5.16, 5.17, 5.18, 5.19 |
| FR-23 | 5.2, 5.5, 5.6, 5.7, 5.9, 5.14, 5.16, 5.17, 5.19, 5.20, 6.8 |
| FR-24 | 5.10, 5.14, 5.17, 5.18 |
| FR-25 | 5.8, 5.10, 5.13, 5.14, 5.15, 5.18 |
| FR-26 | 5.12, 5.15, 5.16, 5.20, 6.6, 6.8 |
| FR-27 | 5.9, 5.12, 5.15, 5.17 |
| FR-28 | 5.11, 5.13, 5.19, 5.20 |
| FR-29 | 6.2, 6.3, 6.6, 6.8 |
| FR-30 | 5.5, 5.11, 5.17, 5.20, 5.21, 6.4, 6.5, 6.7 |
| NFR-7 | 5.15, 5.16, 5.18 |
| NFR-8 | 5.1, 5.9, 5.10, 5.11, 5.13, 5.15, 5.16, 5.17, 5.18, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8 |
| NFR-9 | 5.1, 5.8, 5.9, 5.10, 5.11, 5.12, 5.14, 5.15, 6.2 |
| NFR-10 | 5.14 |
| NFR-11 | 5.12, 5.15 |
| UX-DR1 | 5.16, 5.21 |
| UX-DR2 | 5.16, 5.17, 5.18, 6.3 |
| UX-DR3 | 5.16, 5.20 |
| UX-DR4 | 5.16 |
| UX-DR5 | 5.17, 5.19 |
| UX-DR6 | 5.17, 5.18 |
| UX-DR7 | 5.18, 5.20 |
| UX-DR8 | 5.17, 6.3, 6.8 |
| UX-DR9 | 5.20 |
| UX-DR10 | 5.21 |
| UX-DR11 | 5.7, 5.16, 5.17, 5.18, 5.19, 5.20, 6.3, 6.8 |
| UX-DR12 | 5.3, 5.16, 5.17 |
| UX-DR13 | 5.15, 5.16, 5.17, 5.18 |
```

#### E-30 — Ordre physique dans `epics.md`

Après application, l'Epic 5 se lit dans l'ordre 5.1 à 5.21 et l'Epic 6 dans l'ordre 6.1 à 6.8 (déplacer les blocs renommés en conséquence).

### 4.6 Suivi de sprint — `implementation-artifacts/sprint-status.yaml`

#### S-1 — Entrées des Epics 5 et 6 et actions (F18, F29)

AVANT (de `  epic-5: backlog` à `  epic-6-retrospective: optional`, puis le bloc `action_items`) : texte actuel du fichier, lignes 50 à 97.

APRÈS :

```yaml
  epic-5: backlog
  # 5.1 : TÂCHE HUMAINE (porteur de projet, ou développeur avec sa validation) — bloque toutes les autres stories des epics 5 et 6
  5-1-règles-du-pari-vérifiées-et-datées: backlog
  5-2-heures-de-départ-fiables-utc: backlog
  5-3-cartes-plus-lisibles-dans-toute-l-app-line-card-3-1-on-gold: backlog
  5-4-mises-à-jour-du-serveur-sans-perte-de-données-alembic: backlog
  5-5-savoir-si-une-course-est-éligible-au-multi: backlog
  5-6-rafraîchir-les-partants-et-les-cotes-d-une-course-avant-le-dép: backlog
  5-7-rouvrir-une-course-hors-ligne-après-redémarrage-cache-local-v2: backlog
  5-8-catalogue-de-systèmes-vérifié: backlog
  5-9-moteur-multi-python-couverture-et-sélection-pour-une-taille: backlog
  5-10-moteur-multi-python-chevaux-les-plus-probables-systèmes-par-fo: backlog
  5-11-moteur-multi-python-évaluation-non-partant-et-bilan-d-arrivée: backlog
  5-12-indice-de-confiance-et-explications-python-registre-multi_co: backlog
  5-13-api-du-pronostic-multi-contexte-recommandation-systèmes-vérif: backlog
  5-14-moteur-multi-en-dart-à-parité-couverture-sélection-bases-sys: backlog
  5-15-confiance-et-explications-en-dart-table-de-libellés-fr: backlog
  5-16-écran-multi-accès-taille-et-confiance: backlog
  5-17-écran-multi-sélection-chevaux-les-plus-probables-évaluation-é: backlog
  5-18-écran-multi-grilles-formules-feuille-des-grilles-copie-vérif: backlog
  5-19-retoucher-sa-sélection-et-gérer-les-non-partants: backlog
  5-20-retenir-son-pronostic-même-hors-ligne-sqflite-v3-gel-au-dépa: backlog
  5-21-le-débrief-du-lendemain-mes-pronostics-multi-arrivée-corrigé: backlog
  epic-5-retrospective: optional

  epic-6: backlog
  6-1-données-de-la-dernière-course-pour-la-méthode-1-allocation-r: backlog
  6-2-comparateurs-méthode-1-et-marché-en-python-et-dart-b0-python: backlog
  6-3-section-autres-méthodes-à-l-écran: backlog
  6-4-backtest-harnais-sans-fuite-et-périodes-figées: backlog
  6-5-backtest-stratégies-métriques-et-export: backlog
  6-6-pilote-et-import-en-production-multi_parametres_pilote-json: backlog
  6-7-journalisation-quotidienne-avant-le-départ-immuable-échecs-r: backlog
  6-8-performances-et-statut-du-modèle-affichés-seuils-définitifs: backlog
  epic-6-retrospective: optional

# Action items from the implementation readiness gate (2026-10-18, verdict CONCERNS)
# Full report: _bmad-output/planning-artifacts/implementation-readiness.md
# Course correction: _bmad-output/planning-artifacts/sprint-change-proposal-2026-10-18.md
action_items:
  - epic: 5
    action: "Story 5.1 est une tâche humaine : vérifier sur pmu.fr les règles actuelles du Multi (courses où il est proposé, seuil, MULTI/E_MULTI, Mini Multi), dater fixtures/multi_regles.json ; aucune autre story Multi avant."
    owner: "Lazyd"
    status: open
  - epic: 5
    action: "Appliquer la correction de cap (sprint-change-proposal-2026-10-18.md) aux PRD, cahier, spine, UX et epics, puis relancer la revue de préparation avant 5.5."
    owner: "Lazyd"
    status: open
  - epic: 5
    action: "F1 : éligibilité et Mini Multi décidés (D quater) — reportés par la correction de cap."
    owner: "Lazyd"
    status: done
  - epic: 5
    action: "F6 : règle provisoire « hasard + plancher » décidée (D quater) — reportée en 5.12 par la correction de cap."
    owner: "Lazyd"
    status: done
  - epic: 6
    action: "F15 (différé) : décider la règle de taille d'échantillon et la règle de proposition des seuils du pilote avant la story 6.6."
    owner: "Lazyd"
    status: open
```

Mettre `last_updated` à la date d'application.

### 4.7 Journal des décisions — `multi/reconcile-cdc-multi-prd.md`

#### R-1 — Arbitrages du 2026-10-18 et choix « [À VALIDER] » (F6, F7)

AVANT (dernière ligne du tableau « D quater ») :
> | Seuils provisoires de l'indice de confiance | Avec `p_hasard(v) = C(v,4) / C(n,4)` (n = partants du champ) : « moyenne » si probabilité de couverture ≥ min(max(2 × p_hasard ; 0,15) ; 0,90) ; « élevée » si ≥ min(max(3 × p_hasard ; 0,35) ; 0,95) ; un cran de moins si course très ouverte ou données fragiles. Provisoire jusqu'au pilote (6.5), qui la remplace. Remplace la règle « 2× / 3× le hasard » de la story 5.8. |

APRÈS (la ligne est conservée, suivie de) :
> | Arbitrages de rédaction des stories (approuvés le 2026-10-18) | Contexte Multi dans l'objet `multi` de `/courses` ; cache local avec contexte Multi ; miroirs backend `regles.py`, `parametres.py`, `versions.py` ; sauvegarde SQLite à chaque migration (3 gardées) ; journal à T−30 min, arrivée recontrôlée 3 jours ; heure de départ inconnue → remplaçable jusqu'à la fin du jour de Paris ; taille trop grande : 422 à l'API, ramenée par l'app ; allocation déjà stockée ; musiques en majuscules. Reportés dans PRD, cahier et spine par `sprint-change-proposal-2026-10-18.md`. |
> | Choix de la correction de cap | Liste « [À VALIDER] » de `sprint-change-proposal-2026-10-18.md` §5.4 : à confirmer ou corriger ligne par ligne par le porteur de projet. |

Note : dans cette ligne D quater, « pilote (6.5) » devient « pilote (6.6) » et « story 5.8 » devient « story 5.12 (ex-5.8) » après renumérotation.

### 4.8 Report des arbitrages F7 dans les documents amont

| Arbitrage du 2026-10-18 | Items |
| --- | --- |
| Contexte Multi dans l'objet `multi` de `/courses` | A-4, C-15 |
| Cache local avec `multi_contexte` et colonnes de débrief | A-6, C-12, C-15, E-4 |
| Miroirs backend `regles.py`, `parametres.py`, `versions.py` | A-3, A-5, A-8, A-9 |
| Sauvegarde du fichier SQLite, `_migrate()` hérité, tampon, 3 sauvegardes | A-10, A-12, E-4 |
| Journal 30 min avant le départ ; arrivée recontrôlée 3 jours | A-7, A-12, C-12 |
| Heure de départ inconnue → fin du jour de Paris | A-6, P-9, C-12 |
| Taille > sélectionnables : 422 à l'API, ramenée par l'app | C-8, C-14 |
| Allocation déjà stockée | C-6 |
| Musiques en majuscules | C-17 |

## 5. Passation

### 5.1 Classification

**Moderate** : réorganisation du backlog (2 stories nouvelles, 3 découpages, renumérotation) et mise à jour de documents PM / architecture / UX, sans revue du MVP ni nouvel epic. Rien à défaire dans le code.

### 5.2 Qui fait quoi

| Rôle | Responsabilité | Items |
| --- | --- | --- |
| **Porteur de projet (Lazyd)** | 1. Approuver ou corriger cette proposition et chaque « [À VALIDER] » (§5.4). 2. Réaliser la story 5.1 (tâche humaine), avec les contrôles ajoutés. 3. Décider F15 avant la story 6.6. | — |
| **PM (bmad-prd / John)** | Appliquer les changements du PRD | P-1 à P-14 |
| **Architecte (bmad-architecture / Winston)** | Appliquer les changements de la spine ; vérifier la cohérence d'AD-6 (non-partant) avec le moteur de scoring | A-1 à A-12 |
| **PM ou architecte** | Appliquer les changements du cahier Multi (v3.1) et du reconcile | C-1 à C-17, R-1 |
| **UX (bmad-ux / Sally)** | Appliquer EXPERIENCE.md et DESIGN.md ; aligner la maquette `multi.html` | U-1 à U-16 |
| **PO / SM (bmad-create-epics-and-stories, bmad-sprint-planning)** | Appliquer `epics.md` (stories, renumérotation, couverture) et `sprint-status.yaml` | E-1 à E-30, S-1 |
| **Revue (bmad-check-implementation-readiness via bmad-sprint-planning)** | Relancer la revue de préparation sur les documents mis à jour, avant la story 5.5 | — |
| **Développeur (bmad-build)** | Rien avant la levée du CONCERNS, sauf 5.2 à 5.4 une fois 5.1 terminée | — |

Ordre conseillé : approbation → PRD et reconcile → spine → cahier → UX → epics et sprint-status → nouvelle revue de préparation. La story 5.1 peut se faire en parallèle ; si son résultat contredit D quater, la story s'arrête et cette proposition est revue.

### 5.3 Constats différés

| Constat | Pourquoi | Responsable | Condition de reprise |
| --- | --- | --- | --- |
| **F15** — règle de taille d'échantillon et règle de proposition des seuils du pilote | Elle exige un effet minimal, un α et une puissance, ou une précision visée, que le cahier interdit d'inventer ; elle ne bloque rien avant l'Epic 6. Pistes à soumettre : règle de précision (largeur visée de l'intervalle de la différence appariée contre B1) plutôt que de puissance ; seuils proposés par des quantiles de `p_couverture` par taille sur la période de développement, sous contrainte d'ordre élevée > moyenne > faible. | Porteur de projet, avec le PM | Avant le démarrage de la story 6.6 (pilote) ; à écrire au cahier §8.4 (item C-13) |
| **NFR-10** — seuil chiffré de l'« instantané » | Déjà accepté (PRD OQ 1) ; mesuré en story 5.14 | Porteur de projet | Après la mesure sur l'appareil cible |

Accepté sans changement : aucun constat. Les constats faibles F21 à F29 sont tous corrigés.

### 5.4 Choix « [À VALIDER] » (un par ligne)

1. Éligibilité sur `MULTI` exact ; `E_MULTI` seul ne suffit pas.
2. Liste des paris absente ou illisible → non éligible (`paris_inconnus`), sans mode exploration ; une course ingérée avant la story 5.5 reste `paris_inconnus` jusqu'à sa prochaine ingestion.
3. Course ne proposant que `MINI_MULTI` → raison distincte « Mini Multi non pris en charge ».
4. Seuil de partants appliqué seulement si la story 5.1 le confirme (`moins_de_n_partants`).
5. Course saisie à la main ou importée par photo → pas de Multi.
6. Cheval sans dossard : dans le champ, non sélectionnable ; dossards en double : Multi bloqué.
7. Non-partant : exclu de l'entrée du scoring, champ = déclarés − non-partants, classement recalculé automatiquement sur l'appareil (Résultats « classement recalculé », pas « périmé ») ; rafraîchissement sans non-partant (cotes seules) → « Résultat périmé ».
8. `simuler_non_partant` ne renvoie que la requalification des tickets, sans nouvelle `p_couverture`.
9. Relecture des partants : route à la demande `POST /multi/courses/{cle_course}/rafraichir`, au plus une toutes les 5 minutes par course, avant le départ seulement, courses éligibles seulement ; aucune relecture périodique ; relecture avant chaque journalisation.
10. Noms des routes : `GET /multi/courses/{cle_course}` et `POST /multi/courses/{cle_course}/rafraichir` ; `CourseOut` expose `cle_course`, `numero_reunion`, `numero_course` ; les routes par id des Epics 1 à 3 restent.
11. Base locale : version 2 = cache de course (story 5.7), version 3 = tables Multi (story 5.20), version 4 = cache des performances (story 6.8) ; modifications manuelles des partants non conservées après fermeture ; purge à 90 jours du cache des partants.
12. Règle d'écriture de `recommandation_consultee` : remplacée à chaque calcul complet avant le départ tant que rien n'est retenu, puis seulement par une nouvelle retenue ; l'arrivée y est rangée.
13. Débrief en lecture seule : Évaluation depuis les valeurs enregistrées, pas d'« Autres méthodes », grilles enregistrées seulement (aucune grille sans pronostic retenu).
14. Débrief : relecture de l'arrivée pour les lignes sans arrivée ou de moins de 5 jours.
15. Musique : colonne `participations.musique` + commande ponctuelle `remplir_musique` (pas dans la migration Alembic).
16. Rang de la dernière course (M1) : liste détaillée prioritaire, musique en complément (inverse du cahier §3 actuel, aligné sur l'annexe D).
17. Indice de confiance : un seul cran d'abaissement au total si la course est ouverte **ou** les données fragiles (lecture littérale de D quater ; le cahier v3 cumulait deux crans).
18. Sélection égale au champ (`p_couverture = 1`) : pas de niveau, code `selection_egale_au_champ`.
19. Drapeaux : « Données non saisies » compte comme fragile ; « terrain majoritairement inconnu » = plus de la moitié des performances utilisées sans terrain.
20. Valeurs provisoires conservées : `seuil_course_ouverte = 0,90`, `seuil_donnees_fragiles = 0,25`.
21. Réglages Multi : deux seuils globaux + « Seuils de confiance par taille » replié, 17 lignes × 2 champs en %, vide = « Auto » (règle provisoire).
22. Formule affichée par défaut : Multi en 7, sinon la plus grande, sans mémoire (l'UX s'aligne sur la story).
23. Écarté touché : `multi-actions-sheet` réduite à « Ajouter à la sélection » (la story s'aligne sur l'UX).
24. Puce de base : tickets économisés pour la formule affichée (Multi en 7 par défaut).
25. Journal : en cas d'échec de la relecture avant journalisation, journaliser avec les dernières données stockées (`donnees_a` = leur heure).
26. `performance_strategie` : colonnes `type_periode`, `gelee`, `close` ; contexte Multi avec `statut_comparateurs`.

### 5.5 Critères de succès

- Chaque item P, C, A, U, E, S et R est appliqué ou explicitement rejeté par le porteur de projet ; chaque « [À VALIDER] » est confirmé ou remplacé, et le choix final est noté dans le reconcile (R-1).
- Plus aucune occurrence de « course support » (hors historique et mention du document de 2001-2002) ni de « mode exploration » dans le PRD, le cahier, la spine, l'UX et `epics.md`.
- `epics.md` : Epic 5 de 5.1 à 5.21, Epic 6 de 6.1 à 6.8, sans dépendance en avant ; table de couverture avec les lignes NFR ; `sprint-status.yaml` aux mêmes clés.
- La nouvelle revue de préparation ne relève plus aucun constat **élevé** et aucune « décision que le développeur devrait inventer » (§7 du rapport actuel), hors F15 différé.
- La story 5.1 est terminée, et son résultat est compatible avec D quater, ou la proposition est revue.

### 5.6 Fichier

Cette proposition : `_bmad-output/planning-artifacts/sprint-change-proposal-2026-10-18.md`. Aucun autre fichier n'a été modifié.
