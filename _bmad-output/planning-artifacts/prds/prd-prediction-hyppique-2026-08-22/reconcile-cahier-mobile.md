# Réconciliation — cahier des charges app mobile vs PRD + addendum

Date : 2026-08-22
Source : `sources/cahier_des_charges_app_mobile.md`
Cible : `prd.md` + `addendum.md`

Rappel de cadrage (non remis en cause ici) : le PRD est volontairement écrit
au niveau produit/capacité. L'absence de détails de stack (Riverpod, dio,
sqflite, freezed, structure `lib/`) dans le PRD n'est **pas** un écart — ces
détails sont correctement conservés dans le cahier mobile (référence) et
dans l'addendum, section E.

---

## 1. Couverture des 7 écrans (cahier mobile §7)

| Écran (cahier §7) | Couverture PRD | Statut |
|---|---|---|
| 7.1 Accueil — programme du jour | FR-1, UJ-1 | Couvert |
| 7.2 Configuration de la course cible | FR-2, FR-3 | Couvert |
| 7.3 Liste des partants | FR-4 | Couvert |
| 7.4 Fiche cheval éditable | FR-5, FR-6, FR-18 | Couvert |
| 7.5 Import photo (programme complet) | FR-19 | Couvert |
| 7.6 Résultats | FR-7 à FR-12, FR-13 à FR-15 | Couvert (contenu), deux détails d'affichage non repris — voir écart 3 |
| 7.7 Réglages | Partiellement — voir écart 1 | **Gap** |

6 écrans sur 7 sont couverts par au moins une exigence fonctionnelle
explicite avec conséquences testables. L'écran Réglages (7.7) est nommé
dans le périmètre MVP (PRD §6.1) mais n'a pas de FR dédiée qui opérationnalise
l'exposition de tous les paramètres du moteur — voir écart 1.

## 2. Couverture des critères d'acceptation (cahier mobile §11)

Le cahier mobile §11 liste en réalité **4** critères (l'énoncé de la tâche
en cite 3, le 4e — avertissement jeu responsable — a été vérifié aussi par
souci de complétude) :

| Critère (cahier §11) | Repris dans PRD | Statut |
|---|---|---|
| Classement identique à epsilon près au prototype HTML | PRD §8 NFR « Reproductibilité » | Couvert (principe repris ; l'exemple précis « 12 partants » n'est pas cité — voir écart 4, mineur) |
| Utilisable en mode avion | FR-13 (« L'app reste utilisable... en mode avion ») | Couvert, quasi mot pour mot |
| Aucune clé API dans le binaire | FR-18 Consequences + PRD §8 NFR « Aucune clé API tierce embarquée » | Couvert, repris deux fois |
| Avertissement jeu responsable sur chaque écran de résultats | PRD §5 Non-Goals + §6.1 MVP Scope | Couvert |

Les 3 (4) critères d'acceptation de la section 11 sont bien repris comme
FR/NFR testables dans le PRD. Aucun écart significatif ici.

---

## 3. Écarts identifiés

### Écart 1 — Écran Réglages : exposition des paramètres du moteur non opérationnalisée en FR (SIGNIFICATIF)

**Source (cahier §7.7) :** « Tous les paramètres du moteur (section
"engine_params" du modèle) exposés avec leurs valeurs par défaut » :
pondération de récence, contraste k, sensibilité au poids, âges min/max,
lissage bayésien, coefficient inédit, intensité du malus incident, bankroll,
fraction de Kelly.

**PRD/addendum :** Le PRD §1 Vision affirme le principe au niveau produit
(« chaque coefficient — récence, poids, âge, terrain, niveau — est visible
et réglable par l'utilisateur »), et UJ-2 illustre un ajustement de réglage
(« sensibilité au poids ») en usage hors ligne. FR-13 mentionne en creux
qu'un changement de réglage ne déclenche pas de requête réseau. Mais seuls
deux paramètres ont une FR avec conséquences testables : bankroll et
fraction de Kelly (FR-10 : « réglages persistés, pas resaisis à chaque
calcul »). Les sept autres paramètres cités par le cahier (récence, k,
sensibilité poids, âges min/max, lissage bayésien, coefficient inédit,
malus incident) ne sont mentionnés dans aucune FR comme devant être
visibles/réglables/persistés avec une valeur par défaut.

**Suggestion :** Ajouter au PRD une FR dédiée (ex. FR-2x « Réglages du
moteur ») avec des conséquences testables du type : « Tous les paramètres
du moteur sont visibles avec leur valeur par défaut et modifiables par
l'utilisateur » + « Les réglages modifiés sont persistés et survivent à un
redémarrage de l'app » + « Un bouton "réinitialiser aux valeurs par défaut"
[si voulu] ». Les valeurs numériques par défaut elles-mêmes restent
correctement dans le cahier backend (référence normative) — seul le
comportement produit (exposition + persistance + réglabilité) manque au
PRD.

### Écart 2 — Export/partage du classement : pas de FR dédiée (MINEUR À MODÉRÉ)

**Source (cahier §3, Dans le périmètre) :** « Export/partage du classement
calculé (au minimum en texte ou JSON — un export PDF est un bonus, pas un
prérequis). »

**PRD/addendum :** Repris textuellement dans PRD §6.1 MVP Scope (« Export/
partage du classement calculé (texte ou JSON au minimum ; export PDF en
bonus, pas requis) »), mais aucune Feature/FR en section 4 ne le
spécifie avec des conséquences testables (ex. quel contenu minimal dans
l'export, déclenchement depuis l'écran résultats, format exact).

**Suggestion :** Ajouter une FR courte (ex. FR-2x « Export/partage du
classement ») ou, alternative plus légère, l'attacher comme conséquence
testable à une FR existante de la section 4.5 (combinaisons) ou 4.3
(scoring). Écart mineur à modéré : la fonctionnalité est bien mentionnée
dans le périmètre MVP, donc pas totalement absente, mais elle n'a pas le
même niveau de spécification testable que les autres capacités du PRD.

### Écart 3 — Deux éléments d'affichage de l'écran résultats non repris (MINEUR)

**Source (cahier §7.6) :** L'écran résultats affiche, par cheval, entre
autres : « régularité » et une « recommandation textuelle ».

**PRD/addendum :** Ni le mot « régularité » ni une notion de recommandation
textuelle par cheval n'apparaissent dans le PRD (glossaire §3 ou FR-7 à
FR-12).

**Suggestion :** Écart mineur, probable détail d'implémentation UI plutôt
que comportement produit à part entière (contrairement à la value ou la
mise Kelly qui sont des calculs avec une formule et une conséquence
testable). À laisser hors PRD si « régularité » est un simple affichage
dérivé du score déjà couvert par FR-7, et si la « recommandation
textuelle » est un habillage sans règle métier propre. Si au contraire la
recommandation textuelle doit suivre une règle produit spécifique (ex.
seuils qui déterminent le texte affiché), cela mériterait une conséquence
testable dans FR-9 ou une FR dédiée — à clarifier avec le porteur de
projet plutôt qu'à trancher ici.

### Écart 4 — Cas de test précis (12 partants) non cité dans le NFR de reproductibilité (MINEUR — À IGNORER)

**Source (cahier §11) :** « vérifié en rejouant l'exemple à 12 partants du
prototype HTML. »

**PRD/addendum :** PRD §8 NFR « Reproductibilité » reprend le principe
général sans citer cet exemple précis à 12 partants.

**Suggestion :** Écart mineur, niveau détail de cas de test plutôt que
niveau produit — cohérent avec le principe de cadrage du PRD (les cas de
test précis restent dans les cahiers/addendum, cf. addendum §B : « Les 9
cas de test de référence... doivent être portés à l'identique »). À
ignorer, ou au mieux ajouter une ligne dans l'addendum §B/F listant cet
exemple 12 partants comme cas de non-régression pour le portage Dart —
pas une action PRD.

---

## 4. Ce qui est bien couvert (pas d'écart)

- Contrainte offline (cahier §4) : intégralement traduite en FR-13, FR-14,
  FR-15 et NFR §8, y compris la distinction entre fonctionnalités
  réseau-dépendantes (import photo, rafraîchissement cotes) et le reste.
- Sécurité clé API (cahier §6.3) : reprise dans FR-18 et NFR §8, cohérente
  avec addendum §E.
- Les 6 erreurs à ne pas reproduire (cahier §8, items 1, 2, 3, 5, 6) :
  toutes reprises comme conséquences testables (FR-2, FR-7, FR-9, FR-5).
  L'item 4 (erreurs de compilation Dart) reste correctement au niveau
  technique (addendum §D), pas de niveau produit — normal qu'il soit
  absent du PRD.
- Labels de transparence sur historique (« Historique court », « Données
  non saisies », « 🐎 Inédit ») : repris mot pour mot dans FR-4.
- Distinction cheval inédit / historique non saisi : reprise dans FR-4 et
  glossaire §3.
- Terrain NULL neutre (`c_terr = 1.0`), jamais deviné : repris FR-5 et
  addendum §C.
- Stratégie de synchronisation / pas de re-fetch automatique : reprise
  FR-1, FR-14.
- Hors périmètre (compte, paiement, paris automatisés, hors France,
  notifications push, presse/consensus) : tous repris dans PRD §5
  Non-Goals et §9.1.
- Les 3 (4) critères d'acceptation §11 : couverts, voir section 2
  ci-dessus.

---

## 5. Conclusion

2 écarts significatifs à modérés (réglages du moteur non opérationnalisés
en FR ; export/partage sans FR dédiée), et 2 écarts mineurs (deux détails
d'affichage de l'écran résultats ; cas de test précis non cité dans le
NFR). Aucun écran totalement absent du PRD, aucun des critères
d'acceptation de la section 11 manquant. La contrainte offline et la
contrainte de sécurité (clé API) — les deux points explicitement demandés
en vérification — sont intégralement et correctement reprises.
