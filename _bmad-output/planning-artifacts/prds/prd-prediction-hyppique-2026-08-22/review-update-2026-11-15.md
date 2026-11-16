---
title: Revue de la mise à jour du PRD — 2026-11-15
reviewed: prd.md (updated 2026-11-15)
inputs:
  - sprint-change-proposal-2026-10-18.md §4.1 (P-1..P-14)
  - sprint-change-proposal-2026-11-15.md §4.1 (P-1..P-17), §5.3 (D-1..D-7)
  - brainstorm-intent.md (2026-11-15)
  - .claude/skills/bmad-prd/assets/prd-validation-checklist.md
date: 2026-11-15
---

# Revue de la mise à jour du PRD — 2026-11-15

## Verdict

Les 31 propositions sont appliquées, certaines avec de petites améliorations, et les décisions D-1 à D-7 sont reprises. Les MUST de l'intent sont couverts, dont l'appairage QR, l'offre Duo, l'app mobile comme produit complet et la web app compagnon. Mais le PRD ne dit pas encore **ce que chaque palier débloque dans les FR existants**. Le contenu payant central (pronostic du matin, instantanés H-60 à H-10, « modèle combiné ») n'a aucune FR. Plusieurs textes antérieurs (FR-14, FR-15, §6.2 notifications push, UJ-1/UJ-2) contredisent encore le service payant multi-appareils. Il faut une passe de corrections ciblée avant l'architecture et les epics 7-10.

Bilan : **1 critique, 5 hautes, 15 moyennes, 11 basses**.

---

## 1. Réconciliation

### 1.1 Proposition 2026-10-18 (Multi), P-1 à P-14

| Item | Statut | Remarque |
|---|---|---|
| P-1 §1 Vision | Appliqué | l. 31 |
| P-2 JTBD Multi | Appliqué | l. 46 |
| P-3 UJ-4 état d'entrée | Appliqué | l. 86 |
| P-4 Glossaire (course éligible, pronostic) | Appliqué | l. 132, 135 |
| P-5 §4.11 description, cahier v3 | Appliqué | l. 358. Le §0 (l. 18) dit encore « v2 », voir constat M-1 |
| P-6 FR-22 | Appliqué | `[À VALIDER]` remplacé par `[ASSUMPTION: … approuvé le 2026-11-15]` : cohérent avec l'approbation |
| P-7 FR-23 | Appliqué | l. 381-382 |
| P-8 FR-26 | Appliqué | l. 410 |
| P-9 FR-28 | Appliqué, avec un ajout | l. 429 : une phrase ajoutée (« L'export des grilles propose de retenir le pronostic… »), qui n'est pas dans P-9. Ajout acceptable, mais à tracer (constat B-1) |
| P-10 §6.1 endpoints | Appliqué | l. 610 : la réserve « noms des routes » du tag d'origine a disparu (constat B-2) |
| P-11 §6.2 Mini Multi | Appliqué | l. 624 |
| P-12 §9.5 | Appliqué | l. 694 |
| P-13 OQ 6, 8, 9, 10 | Appliqué | l. 719-723 (OQ 10 enrichie, sans conflit) |
| P-14 §12 trois lignes | Appliqué | l. 750-752 |

Résultat : aucun item manquant, aucun mal appliqué.

### 1.2 Proposition 2026-11-15 (service payant), P-1 à P-17

| Item | Statut | Remarque |
|---|---|---|
| P-1 frontmatter et §0 | Appliqué | l. 4, l. 19. L'intro l. 13 dit encore « quatre documents » et ne cite que backend et mobile (constat B-3) |
| P-2 §1 Modèle de service | Appliqué | l. 37 |
| P-3 §2.2 | Appliqué | l. 54, 56 |
| P-4 UJ-1, UJ-5, UJ-6 | Appliqué | l. 62, 93-106. Le palier Turfiste de UJ-1 contredit le reste du parcours (constat H-2) |
| P-5 Glossaire | Appliqué | l. 148-155 |
| P-6 §4.12 à §4.14 et index | Appliqué | Mot pour mot. Index l. 159 conforme |
| P-7 FR-30 | Appliqué | l. 447 |
| P-8 §5 | Appliqué | l. 597-598 |
| P-9 §6.1 | Appliqué | l. 606-607, 613. La puce « Usage mono-utilisateur » a bien disparu |
| P-10 §6.2 | Appliqué | l. 617-619 ; les anciennes puces V2 ont disparu |
| P-11 §7 SM-5, SM-6, SM-C4 | Appliqué | l. 639, 642, 648 |
| P-12 §8 | Appliqué, avec une extension | l. 659 : CORS étendu au back-office (cohérent avec FR-47) ; l. 661 reformulé |
| P-13 §9.1 | Appliqué | l. 668 |
| P-14 §9.2, §9.3 | Appliqué, D-1 résolu | l. 674, 686 : le `[TO CONFIRM — D-1]` est remplacé par la décision. La citation du « jalon §10 » ne correspond plus au texte du §10 (constat B-4) |
| P-15 §10 | Appliqué, D-2 et D-5 intégrés | l. 696-710. « Pass semaine » sans palier, alors que D-3 dit Turfiste et Expert (constat M-2) |
| P-16 §11 | Appliqué | OQ 2 close, OQ 3 réécrite, OQ 13 à 18 ajoutées. OQ 12 non mise à jour (constat M-9) |
| P-17 §12 | Appliqué, enrichi | l. 753-758 : D-1 à D-7 tracées |

Résultat : aucun item manquant.

### 1.3 Décisions D-1 à D-7

| Décision | Où | Statut |
|---|---|---|
| D-1 lancement malgré une source non légitime, sous avis juridique | §9.3 l. 686, §10 l. 708, §12 l. 757 | Reflétée |
| D-2 lancement sans attendre le Multi | §10 l. 702, §12 l. 756 | Reflétée |
| D-3 pass journée = Expert 24 h ; pass semaine et mensuel pour Turfiste et Expert | FR-41, §10 l. 704 | **Partielle** : le mensuel est précisé, pas le pass semaine (M-2) |
| D-4 droit hors ligne jusqu'à la date de fin, sans délai de grâce | FR-44, §12 l. 756 | Reflétée |
| D-5 verrouillage sur l'appareil, risque faible accepté, Play Integrity en V1.1 | §10 l. 707, §6.2 l. 617, §12 l. 758 | Reflétée |
| D-6 le QR est affiché par le web et approuvé par le téléphone | FR-37, §12 l. 754 | Reflétée. Conflit avec l'OTP de FR-36 (M-4) |
| D-7 web app sans cache hors ligne | FR-14 l. 286, §6.1 l. 607, §12 l. 755 | Reflétée |

### 1.4 Périmètre de lancement de l'intent (MUST)

| MUST de l'intent | PRD | Statut |
|---|---|---|
| Consultation juridique Cameroun | §9.2 | OK |
| App Android et web app | §1, §6.1 | OK |
| Téléphone + OTP, PIN avec verrouillage auto, jetons | FR-31 à FR-33 | OK |
| Email vérifié, récupération avec délai et alerte | FR-34, FR-35 | OK |
| « Mes appareils », appareil bloqué au-delà de la limite | FR-36 | OK. La notification contredit §6.2 (H-4) |
| **Appairage QR** | FR-37, UJ-6 | OK |
| **Offre Duo** | FR-43, §10 | Présente, mais son palier n'est pas défini (H-3) |
| Synchronisation côté serveur | FR-38 | OK |
| Paliers Gratuit, Turfiste, Expert et aperçu H-10 | FR-39, FR-40, §10 | Présents, mais aucune correspondance avec les FR existantes (C-1, H-1) |
| Pass journée, pass semaine, mensuel | FR-41 | OK (M-2) |
| Droits datés, quota photo par palier | Glossaire « Droit », FR-45 | OK (M-6) |
| Mobile Money : notification signée, requête de statut, idempotence, rapprochement | FR-42, FR-50 | OK |
| Contrôle serveur, filtrage par palier, limitation de débit, CORS, HTTPS | §8, FR-39 | OK |
| PostgreSQL, secrets hors APK, sauvegardes chiffrées | §8 | OK. PostgreSQL relève de l'architecture, absence justifiée |
| Blocage des captures d'écran | FR-46 | Présent, sans conséquence testable (M-11) |
| Back-office : rôles, validation, audit, 2FA, licence à quatre yeux | FR-47 à FR-50 | Présent, peu testable (M-12) |
| **Mobile = produit complet** | §1 l. 37, §5 l. 598, FR-38 | OK |
| **Web app compagnon** | §1, FR-14, §6.1 | OK |
| Modèle multi-tenant dès le lancement (note de l'intent) | — | Absent (B-6) |

---

## 2. Constats

Chaque constat cite le PRD et propose une correction. Les niveaux suivent le rubric : critique = bloque l'aval ; haute = contradiction ou trou qui produira une mauvaise story ; moyenne = ambiguïté ou référence fausse ; basse = forme.

### Critique

**C-1. Le contenu payant central n'a pas de FR : pronostic du matin, instantanés et « modèle combiné ».**
- PRD : §10 l. 700 « Pronostic du matin, consultation seule » ; l. 701 « + instantanés H-60, H-30 et H-15 » ; l. 702 « + instantané H-10 » ; Glossaire l. 155 « Instantané de cotes — … et pronostic recalculé sur ces cotes » ; §10 l. 708 « le modèle combiné bat le marché sur l'échantillon de test (log-loss 2,009…) ».
- Problème : la grille tarifaire repose entièrement sur ces contenus. FR-39 en dépend (« ex. instantané H-10 pour un compte Turfiste »), comme FR-40, UJ-5 et UJ-6. Pourtant, aucune FR ne dit :
  - qui produit le pronostic du matin, ni à quelle heure ;
  - ce qu'il contient (classement ? probabilités ? value ?) ;
  - quel modèle le produit : le moteur §4.3 lancé par l'utilisateur, ou le modèle ML combiné (cotes H-30, Benter) qui tourne côté serveur ;
  - comment un instantané arrive sur l'appareil ;
  - ce qui se passe quand un instantané manque.

  « Pronostic » n'est défini que pour le Multi (l. 135), et « modèle combiné » n'est défini nulle part. La Vision (§1) décrit toujours un moteur que l'utilisateur lance et règle lui-même, sans pronostic publié par le serveur.
- Correction : ajouter une section §4.15 « Pronostics publiés et instantanés de cotes », avec au moins :
  - FR-51 : pronostic du matin publié par le serveur (heure, contenu, modèle utilisé) ;
  - FR-52 : instantanés H-60, H-30, H-15 et H-10 (déclenchement, contenu, cas d'un instantané manquant ou d'une cote absente, livraison à l'app) ;
  - FR-53 : lien avec le calcul local §4.3, c'est-à-dire lequel fait foi à l'écran quand les deux existent.

  Ajouter au Glossaire « Pronostic publié » (distinct de « Pronostic (Multi) ») et « Modèle combiné ». Dans §1, ajouter une phrase qui situe le pronostic publié à côté du moteur transparent.

### Haute

**H-1. Les FR-1 à FR-30 n'indiquent aucun palier, et §10 utilise des libellés qui ne correspondent pas aux FR.**
- PRD : §10 l. 700-702 : « consultation seule », « value, mise Kelly, historique complet », « combinaisons sur les 10 types de paris, moteur expert réglable, Multi » ; FR-39 l. 522 « Le contenu accessible dépend du palier actif (§10) ».
- Problème : on ne peut pas savoir si un compte Gratuit peut :
  - configurer une course (FR-2) ;
  - éditer une fiche (FR-5) ;
  - lancer le calcul (FR-7, FR-8) ;
  - importer une photo (FR-18 : le §10 ne donne aucun quota au Gratuit) ;
  - exporter (FR-21).

  Rien ne dit non plus si un Turfiste voit des combinaisons (FR-11, FR-12), ni si « moteur expert réglable » couvre tout FR-20. FR-20 regroupe la bankroll et la fraction de Kelly (accordées au Turfiste) avec les réglages experts (Expert). « Historique complet » n'a pas de contrepartie pour le palier Gratuit. Le serveur ne peut pas filtrer (FR-39), ni l'app verrouiller (D-5), un périmètre qui n'est pas défini. Aucun test d'accès n'est possible.
- Correction : ajouter au §10, ou en conséquence de FR-39, une matrice FR × palier (Gratuit, Turfiste, Expert), avec une ligne par FR ou par écran. Expliciter au minimum :
  - Gratuit : FR-1, FR-4, la lecture du pronostic du matin ; ni FR-2, FR-5, FR-6, FR-7 à FR-12, FR-18 à FR-21 ?
  - « 10 types de paris » = FR-11 (8) + FR-12 (2) ;
  - le découpage de FR-20 : bankroll et Kelly pour Turfiste, autres coefficients pour Expert ;
  - le quota photo du Gratuit (0 ?).

**H-2. Les parcours de Marc contredisent son palier.**
- PRD : UJ-1 l. 62 « palier Turfiste » ; l. 65 « il consulte la grille de combinaisons (quinté ordre/désordre) ». Les combinaisons sont réservées à l'Expert (§10 l. 702). UJ-2 l. 71 « il ajuste un paramètre du moteur (ex. sensibilité au poids) » : c'est le « moteur expert réglable », lui aussi réservé à l'Expert. UJ-4 (Multi, Expert) ne dit pas le palier de Marc, et UJ-6 l. 102 le présente comme « palier Expert ».
- Problème : le même protagoniste change de palier d'un parcours à l'autre, et UJ-1 et UJ-2 utilisent des fonctions que son palier n'autorise pas. Des stories dérivées de ces UJ seraient fausses.
- Correction : mettre Marc en palier Expert dans UJ-1, avec un état d'entrée identique dans UJ-2 et UJ-4. Le parcours Turfiste reste illustré par Paul (UJ-5). Autre option : garder Turfiste et retirer de UJ-1 et UJ-2 les combinaisons et le réglage du moteur.

**H-3. L'offre Duo n'a pas de palier.**
- PRD : FR-43 l. 550 « Le titulaire d'une offre Duo invite 1 ou 2 personnes » ; Glossaire l. 149 « Duo et Club sont des formules de partage, pas des paliers » ; §10 l. 704 « offre Duo (2 ou 3 personnes) ».
- Problème : le Duo est un MUST du lancement, mais rien ne dit quel palier ont les membres (Turfiste ? Expert ? au choix ?), si le Duo existe en pass ou seulement en mensuel, ni quelle limite d'appareils s'applique à chaque membre. FR-43 n'est donc pas testable, au-delà du retrait d'un membre.
- Correction : compléter FR-43. Par exemple : « Le Duo existe pour chaque palier payant ; chaque membre reçoit un droit du palier du titulaire, de mêmes dates, et la limite d'appareils de ce palier. » Ajouter une conséquence : à l'expiration du droit du titulaire, tous les membres reviennent au palier Gratuit. Ajouter la question du palier à OQ 13.

**H-4. FR-36 exige une notification, mais les notifications push sont exclues.**
- PRD : FR-36 l. 499 « déclenche une notification sur les autres appareils » ; §6.2 l. 621 « Notifications push, rappels d'heure de départ » (hors MVP) ; §5 l. 599 « Exclusions différées (notifications push…) ».
- Problème : contradiction directe sur une exigence de sécurité du lancement (alerte en cas de nouvel appareil).
- Correction : préciser le canal dans FR-36, par exemple « une alerte par SMS au numéro du compte et une mention dans « Mes appareils » à la prochaine ouverture ». Autre option : sortir de l'exclusion §6.2 les notifications de sécurité (« Notifications push marketing et rappels d'heure de départ »).

**H-5. FR-15 dit encore que seules deux fonctionnalités demandent le réseau.**
- PRD : FR-15 l. 289 « L'import photo et le rafraîchissement des données de course (…), seules fonctionnalités nécessitant le réseau » ; l. 292 « Un échec réseau sur ces deux fonctionnalités… ».
- Problème : c'est faux depuis le §4.12 et le §4.13. La connexion par code (FR-31), le rattachement et l'appairage (FR-36, FR-37), la synchronisation (FR-38), le paiement (FR-42), la réception des instantanés (C-1) et la web app entière (FR-14) demandent le réseau. Le comportement en échec de ces parcours n'est pas spécifié, alors qu'UJ-2 se joue justement avec un réseau saturé.
- Correction : réécrire FR-15. « Les fonctionnalités qui demandent le réseau (liste : import photo, rafraîchissement de course, réception des instantanés, connexion, rattachement d'appareil, paiement, synchronisation) échouent proprement… » Ajouter deux conséquences :
  - le déverrouillage par code PIN et le calcul local ne demandent jamais le réseau ;
  - un paiement lancé puis interrompu par une coupure reste « en attente de confirmation », sans double débit au retour du réseau.

### Moyenne

**M-1. Le §0 cite encore la version v2 du cahier Multi.** l. 18 « `cahier_des_charges_module_multi.md` (v2, 2026-10-17) » contre §4.11 l. 358 « (v3) ». *Correction :* l. 18 « (v3, 2026-10-18) ».

**M-2. Le pass semaine n'a pas de palier (D-3).** FR-41 l. 535 et §10 l. 704 disent « pass semaine » ; UJ-5 l. 96 dit « pass semaine Turfiste » ; le Glossaire l. 151 dit « pass semaine » sans palier. *Correction :* « pass semaine (Turfiste ou Expert) » dans FR-41, §10 et le Glossaire, comme le dit D-3.

**M-3. Le droit expiré et le cache illimité se contredisent.** FR-14 l. 284 « Une course consultée une fois reste accessible hors ligne indéfiniment » ; FR-44 l. 559 « hors ligne, elle s'y fie jusqu'à cette date, jamais au-delà » ; FR-39 l. 526 « Un droit expiré ramène le compte au palier Gratuit ». Que voit un ex-Turfiste qui ouvre hors ligne une course en cache avec des instantanés et la mise Kelly ? *Correction :* ajouter à FR-44 « Après la date de fin, les données en cache restent consultables au niveau du palier Gratuit ; le contenu payant en cache (instantanés, value, Kelly, combinaisons, Multi) est masqué jusqu'à un nouveau droit. » Ajuster FR-14 en conséquence.

**M-4. L'appairage QR se passe de l'OTP exigé par FR-36.** FR-36 l. 499 « Le rattachement d'un nouvel appareil exige un code envoyé au numéro du compte » ; FR-37 et UJ-6 l. 104 décrivent un rattachement par approbation sur le téléphone, sans code. Rien ne dit non plus si la web app permet une connexion directe par OTP, pour un utilisateur qui n'a pas son téléphone sous la main. *Correction :* dans FR-36, « … exige un code envoyé au numéro du compte, **ou** l'approbation d'un appareil déjà connecté (FR-37) ». Dans FR-37, dire si la connexion par code (FR-31) est aussi possible sur la web app.

**M-5. FR-38 ne dit pas qui gagne entre deux versions synchronisées.** l. 514 « avant le départ, la dernière version enregistrée l'emporte ». Il manque deux règles : la référence (heure de l'appareil ou heure de réception par le serveur), et le sort d'une modification faite hors ligne avant le départ mais envoyée après. *Correction :* « La version qui l'emporte est la dernière reçue par le serveur avant l'heure de départ ; une version reçue après le départ est refusée et l'appareil affiche la version figée. »

**M-6. FR-45 renvoie à une limite qui n'existe pas.** l. 562 « en plus de la limite journalière globale (§9.4) » ; or §9.4 l. 690 dit « Aucun budget ni seuil de coût n'est fixé à ce stade ». *Correction :* créer la limite dans §9.4 (« une limite journalière globale d'appels, valeur : OQ 4 ») ou retirer la mention de FR-45.

**M-7. Le Glossaire n'est pas appliqué strictement (§0 l. 23) : « licence » et « droit », « formule », « offre ».**
- « Licence » est utilisé sans être défini (§1 l. 37 « licence par paliers », FR-48 « gère les licences », FR-50 « licence hors paiement », SM-5), alors que le Glossaire définit « Droit ».
- « Formule » désigne à la fois le Multi (FR-25 « chaque formule possible », « Formule intégrale ») et l'offre commerciale (§10 l. 704 « **Formules** : pass journée… », Glossaire l. 149 « formules de partage »).
- « Offre » (FR-41) n'est pas défini.

*Correction :* définir « Licence » comme synonyme interdit de « Droit » et remplacer le mot partout, ou définir « Licence manuelle » à part. Remplacer « Formules » au §10 et « formules de partage » au Glossaire par « Offres », et ajouter « Offre » au Glossaire.

**M-8. « Sélections de courses » se confond avec « Sélection (Multi) ».** FR-38 l. 510 « Les sélections de courses » ; UJ-6 l. 104 « il prépare ses sélections ». Le Glossaire l. 134 réserve « Sélection » au Multi. *Correction :* « les courses suivies » (nouveau terme : « Course suivie — course que l'utilisateur a retenue à la publication du programme ») ou « les courses préparées ».

**M-9. OQ 12 et SM-3 supposent encore qu'il n'y a pas de compte.** l. 725 « aucune exigence ne capte aujourd'hui les paris placés (pas de compte, aucun lien avec un compte de jeu) ». *Correction :* retirer « pas de compte » et ajouter : « un journal déclaratif, s'il est synchronisé (FR-38), devra respecter §5 (aucune mise conservée côté serveur) et §9.2 (données personnelles) ».

**M-10. L'export en texte contourne la protection des écrans payants.** FR-46 l. 568 bloque les captures, mais FR-21 l. 353 (export texte ou JSON du classement, de la value et des combinaisons) et FR-25 l. 401 (grilles en texte copiable) permettent de partager le même contenu en un geste. *Correction :* soit écrire que c'est assumé (défense par le temps et la personnalisation, §10 l. 706), soit restreindre : l'export porte l'identifiant court du compte et exclut les instantanés.

**M-11. FR-46 n'a aucune conséquence testable.** Rien ne dit quels écrans sont « payants », ce qui se passe sur la web app (aucune protection possible, à écrire), ni ce que voit l'utilisateur quand il tente une capture. *Correction :* ajouter des conséquences :
- liste des écrans protégés (Résultats, Combinaisons, Multi, instantanés) ;
- une capture sur un écran protégé produit une image noire ;
- la web app n'a pas cette protection, et c'est assumé ;
- sur iOS, la détection arrive en V1.1.

**M-12. FR-47, FR-48 et FR-49 n'ont aucune conséquence testable, et les rôles sont ambigus.** FR-48 dit « superviseur (valide les modifications) », mais rien ne dit si un superviseur peut valider ses propres saisies. FR-50 dit « validation d'une seconde personne », sans préciser son rôle (administrateur ? superviseur ?). *Correction :* ajouter des conséquences :
- un agent ne peut pas valider ;
- personne ne valide sa propre saisie ;
- la seconde personne de FR-50 est un autre administrateur ;
- une tentative d'accès d'un agent aux pronostics ou aux licences est refusée et journalisée ;
- sans 2FA configurée, aucun accès.

**M-13. Le journal d'audit n'est pas rendu infalsifiable.** FR-50 dit « un journal en ajout seul », alors que l'intent §9 demande « append-only, tamper-evident ». *Correction :* « en ajout seul, dont toute altération est détectable (chaînage), y compris par un administrateur ».

**M-14. Les prérequis de mise en vente sont incomplets.** §6.1 l. 613 « Prérequis de mise en vente : §9.2 » (juridique seulement). La porte de lancement de la proposition (§3) ajoute la validation du Play Store, la publication des CGU et de la politique de confidentialité, et les stories Must des epics 7 à 10. Les CGU et la politique de confidentialité n'apparaissent nulle part dans le PRD. *Correction :* lister les quatre conditions au §6.1 (ou §9.2), et ajouter une FR ou une conséquence : « l'inscription (FR-31) exige l'acceptation des CGU et de la politique de confidentialité, versionnées ».

**M-15. L'aperçu Gratuit vend un instantané que le palier proposé ne débloque pas.** UJ-5 l. 96 : l'aperçu « Le classement a changé à H-10 » pousse Paul vers un pass Turfiste, qui ne donne pas accès au H-10 (§10 l. 702). Rien n'est dit de ce que l'écran des offres annonce comme contenu débloqué. Cela touche SM-C4 (pas de relance trompeuse). *Correction :* ajouter à FR-40 « l'aperçu nomme le palier qui débloque l'instantané concerné » ; dans UJ-5, faire porter l'aperçu sur H-30, ou faire acheter à Paul un pass journée Expert.

### Basse

**B-1. Phrase ajoutée hors proposition (FR-28 l. 429).** « L'export des grilles propose de retenir le pronostic, sans le faire à la place de l'utilisateur. » *Correction :* la tracer au §12, ou la retirer si elle n'a pas été décidée.

**B-2. La réserve « noms des routes » a disparu (§6.1 l. 610).** Le tag `[À VALIDER : noms des routes]` de P-10 est devenu un `[ASSUMPTION]` générique, et les noms des endpoints sont du détail d'implémentation. *Correction :* garder « noms de routes indicatifs, l'architecture fait foi (AD-12) ».

**B-3. L'intro du §0 est périmée.** l. 13 « backend Python/FastAPI (…) et application mobile Flutter » et « quatre documents », alors que cinq sont listés et que la web app et le back-office manquent. La Vision l. 33 dit aussi « un produit backend + mobile ». *Correction :* « backend, application mobile Flutter (produit complet), web app compagnon et back-office ; il s'appuie sur cinq documents ».

**B-4. Le §9.3 cite un texte qui n'existe plus au §10.** l. 686 « Le jalon §10 « source légitime sécurisée ou plan crédible » ». Le §10 l. 708 parle maintenant de « Jalon de bascule revu… (2) la source de données légitime ». *Correction :* « le volet (2) du jalon de bascule (§10) n'est pas atteint ».

**B-5. Le chiffre de log-loss est ambigu (§10 l. 708).** « log-loss 2,009, intervalle de confiance excluant zéro » : une log-loss ne peut pas avoir un IC qui exclut zéro ; c'est l'écart avec le marché qui le peut. Le lien avec SM-1 (score de Brier, modèle §4.3) n'est pas fait. *Correction :* « log-loss 2,009 contre X pour le marché ; l'IC de l'écart exclut zéro » ; dire si cela vaut validation de SM-1 ou relève d'un autre critère.

**B-6. Le multi-tenant n'est pas mentionné.** L'intent §11 dit : « the data model must still be multi-tenant … at launch, even though Club is COULD ». *Correction :* ajouter au §6.2 (Plus tard, Club) : « le modèle de données accueille les organisations dès le lancement, voir l'architecture ».

**B-7. Le brief back-office est cité sans chemin.** §4.14 l. 572 « brief back-office du 2026-10-18 ». *Correction :* ajouter le chemin `briefs/brief-prediction-hyppique-backoffice-2026-10-18` et l'ajouter à la liste du §0.

**B-8. Le canal de l'OTP est incohérent.** FR-31 dit « SMS (ou WhatsApp) », FR-32 l. 472 « nouvelle connexion par code SMS ». *Correction :* « par code » (canal : OQ 17).

**B-9. La limite de deux appareils est déjà supposée dans UJ-6.** l. 106 « un troisième appareil … alors que la limite est atteinte » fige une limite de 2 pour l'Expert, alors qu'OQ 14 la laisse ouverte. *Correction :* « un appareil de plus que la limite de son palier ».

**B-10. Le §6.1 ne liste pas les nouveaux écrans.** l. 606 renvoie aux « écrans du cahier mobile §7 » et ne liste ni connexion, ni PIN, ni profil, ni « Mes appareils », ni offres, ni paiement. *Correction :* ajouter « et les écrans de §4.12-§4.13 (connexion, code PIN, profil, Mes appareils, offres, paiement) ».

**B-11. UJ-5 promet des comportements que les FR ne portent pas.** « un paiement confirmé plus tard active le droit sans action de Paul » et « se débloquent … sans redémarrer l'app » (l. 97, 99) ne figurent dans aucune conséquence de FR-42 ou FR-39. FR-30 l. 447 ne dit pas non plus si les 90 jours de conservation valent aussi côté serveur. *Correction :* ajouter à FR-42 « une confirmation tardive active le droit, et l'app l'affiche à la prochaine requête, sans redémarrage » ; à FR-30, « 90 jours sur l'appareil comme sur le serveur ».

---

## 3. Rubric (nouvelles sections : §4.12-§4.14, §9.1, §10, UJ-5, UJ-6)

| Dimension | Jugement | Synthèse |
|---|---|---|
| Decision-readiness | **adequate** | §9.1, §9.3 et §10 disent clairement les décisions et le risque accepté (D-1, D-5), avec le prix payé. Les questions ouvertes 13 à 18 sont de vraies questions. Le trou est la correspondance palier × FR (H-1, H-3). |
| Substance over theater | **strong** | Les NFR de sécurité sont propres au produit (filtrage par palier, PIN jamais envoyé, notification signée, idempotence). UJ-5 a un vrai persona, avec ses contraintes (pas de carte, Android d'entrée de gamme). |
| Strategic coherence | **thin** | La thèse « l'anti-copie est la stratégie produit » (H-10 réservé à l'Expert) tient, mais le contenu vendu n'est pas spécifié (C-1). SM-6 et SM-C4 sont bien appariés. |
| Done-ness clarity | **thin** | §4.12 est bien testable (5 min, 5 essais, 15 min, 2 min, usage unique). FR-46, FR-47, FR-48 et FR-49 n'ont aucune conséquence (M-11, M-12). FR-39 n'est pas testable sans matrice (H-1). FR-43 est incomplet (H-3). |
| Scope honesty | **adequate** | Le découpage V1.1 / Plus tard / Exclu (§6.2) est explicite et suit l'intent. Il manquent les CGU et la politique de confidentialité (M-14) et le multi-tenant (B-6). |
| Downstream usability | **thin** | La numérotation FR-31 à FR-50 est contiguë et l'index est exact. Mais le Glossaire dérive (M-7, M-8), deux références sont fausses (M-6, B-4) et Marc change de palier d'un UJ à l'autre (H-2). |
| Shape fit | **adequate** | Les UJ sont nommés et pertinents pour un produit grand public. Le §4.14 back-office est un cadre d'accès sans UJ, ce qui se défend pour un usage interne. |

### Détails d'implémentation dans le PRD (nouvelles sections)
- FR-33 : « Un jeton d'accès vit 15 minutes ; un jeton de renouvellement … remplacé à chaque usage » ; FR-42 : « notification signée … requête de statut » ; FR-44 : « preuve de droit signée ». Ce sont des mécanismes plus que des comportements. On peut les garder comme exigences de sécurité décidées par le porteur de projet, mais il serait plus propre de les formuler en résultat (« une session volée devient inutilisable en au plus 15 minutes » ; « un droit n'est jamais activé sur la seule déclaration de l'app ») et de renvoyer le mécanisme à l'architecture (AD-15). **Basse**, non comptée à part.
- §10 l. 708 : « architecture AD-14 », « log-loss 2,009 » : référence technique acceptable dans une justification (voir B-5).

### Ambiguïtés repérées (nouvelles sections)
- « contenu payant » (FR-46), « consultation seule » et « historique complet » (§10), « moteur expert réglable » (§10), « sélections de courses » (FR-38), « dernière version enregistrée » (FR-38), « une seconde personne » (FR-50), « par période » (FR-45 : jour ? mois ? durée du droit ?). Les constats H-1, M-5, M-8, M-11 et M-12 les couvrent ; FR-45 « par période » est à préciser avec OQ 14.

### Mécanique
- IDs : FR-1 à FR-50 contigus, sans doublon ; index l. 159 exact (libellés abrégés, comme pour les sections précédentes). UJ-1 à UJ-6 contigus. SM-1 à SM-6 et SM-C1 à SM-C4 sans doublon (l'ordre d'affichage n'est pas numérique, ce qui est acceptable). OQ 1 à 18 contigus.
- Index des hypothèses : les `[ASSUMPTION]` en ligne (§9.1, FR-22 ×2, FR-23, §6.1, OQ 6) sont tous indexés au §12.
- Ligne vide parasite dans le Glossaire, l. 147 (entre « Comparateur » et « Compte »).
