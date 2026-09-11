# Extrait UI — prototype `analyse_hippique_ia.jsx`

Ce fichier n'est PAS le prototype complet (500 lignes, dont un moteur de calcul React déjà couvert par le PRD/cahier backend). C'est un extrait des éléments pertinents pour la conception visuelle/UX : palette de couleurs, microcopie, libellés d'état. Le prototype complet vit dans l'historique de conversation de la session PRD du 2026-08-22 (document `analyse_hippique_ia.jsx`).

## Palette (identique au prototype HTML `analyse_hippique_v2.html` — confirme la stabilité du système)

```js
const C = {
  bg: "#0B1120", surface: "#131C2E", surface2: "#0F1728",
  line: "rgba(255,255,255,.08)", line2: "rgba(255,255,255,.16)",
  gold: "#E8B33C", goldDim: "rgba(232,179,60,.12)",
  green: "#3DD68C", red: "#E5533D", blue: "#5B9BD5",
  txt: "#E7E4DA", muted: "#8B93A7",
};
```

## Microcopie et libellés d'état observés (vocabulaire à reprendre tel quel)

**En-tête / accroche**
- Titre : "Analyse Hippique · IA"
- Sous-titre : "Importez le programme d'une course ou une fiche cheval — l'IA remplit les champs, vous validez, le moteur calcule."

**Import par photo — boutons et états**
- "📸 Importer une course complète (photo/PDF)"
- "📸 Lecture du programme en cours…" (état occupé)
- "📷 Importer une fiche cheval (photo/PDF)"
- "📷 Lecture de la fiche en cours…" (état occupé)
- "➕ Cheval vide"
- "Tout effacer"
- Bandeau sur un cheval importé par IA : "✨ Rempli par l'IA depuis votre image — vérifiez les champs avant de calculer"
- Erreur d'extraction : "Extraction échouée : {message}. Réessayez avec une capture plus nette." (variante programme : "Extraction du programme échouée : {message}. Réessayez avec une capture plus nette du tableau des partants.")

**Cheval inédit**
- Case à cocher : "Cheval inédit — il n'a jamais couru (à cocher seulement si l'absence de performance est un fait, pas un oubli de saisie)"

**Étiquettes de régularité (colonne "Régularité" du classement)**
- "🐎 Inédit" (bleu)
- "Données non saisies" (gris)
- "Historique court (N)" (gris)
- "Très régulier" / "Régulier" (vert)
- "Moyen" (or)
- "Irrégulier" (rouge)

**Étiquettes de recommandation (colonne "Reco")**
- "Données non saisies" (cheval sans historique ni statut inédit)
- "Cote manquante"
- "🔥 Value forte — jouable" (value ≥ 15 %, prob ≥ 7 %)
- "📈 Léger avantage" (value > 5 %)
- "↗ Avantage marginal" (value > 0)
- "⭐ Favori du modèle, cote trop courte" (dans le top 2 sans value positive)
- "— Pas d'avantage"

**Indicateur de fiabilité au saut (courses d'obstacle)**
- "⚠️ Sauteur fragile (N chutes/N perfs)" (rouge, si ≥2 chutes et taux ≥34 %)
- "N chute(s)" (or, si ≥1 chute sans atteindre le seuil fragile)

**Légende / pédagogie sous le tableau de résultats**
- "Barre or = probabilité du modèle, barre bleue = probabilité implicite de la cote."
- "Value = p × cote − 1. Mise = Kelly fractionné (N %) sur N unités."
- "Petits historiques lissés vers la moyenne du lot. Partants non analysés traités en outsiders moyens."

**Avertissement de jeu responsable (présent sous chaque tableau de résultats)**
- "Outil d'aide à la décision — aucun modèle ne garantit un gain. Jouez uniquement ce que vous pouvez vous permettre de perdre."

**Import course complète — hint de vérification**
- "Numéros de dossard, classés par probabilité décroissante. Paris à ordre et désordre : calcul exact. Couplé placé et 2 sur 4 : estimés par simulation de 20 000 courses (± 0,3 %). Une probabilité faible n'est pas un mauvais pari — comparez-la au rapport attendu, pas à zéro."
