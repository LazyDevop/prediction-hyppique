# Revue — actualité technologique (module Multi, modifications du 2026-10-17)

- **Cible :** `ARCHITECTURE-SPINE.md` — lignes Stack NumPy / SciPy / uv, AD-7 (générateur, copies du catalogue, Docker, assets Flutter), AD-9 (`onUpgrade` sqflite, `shared_preferences`)
- **Angle :** chaque décision engagée a-t-elle été vérifiée sur le web, dans le projet existant ou dans l'outil installé, plutôt qu'affirmée de mémoire ?
- **Date de la revue :** 2026-10-17
- **Projet vérifié :** `backend/requirements.txt`, `backend/Dockerfile`, `backend/.dockerignore`, `backend/.venv`, `docker-compose.yml`, `mobile/pubspec.yaml`, `mobile/pubspec.lock`, `mobile/lib/data/local/database_helper.dart`, `mobile/lib/main.dart`, commit `2bb2518`, `uv --version`, `py --list`

## Verdict

**ACCEPTABLE AVEC CORRECTIONS (aucun bloquant).** La structure d'AD-7 tient : le générateur reste hors production, `milp` s'appuie bien sur HiGHS, uv gère bien PEP 723 et le choix de l'interpréteur, et le contexte Docker `./backend` embarque bien la copie du catalogue. En revanche, la ligne SciPy est **déjà périmée** : la 1.18.1 est sortie et publie des wheels Python 3.15, Windows compris. Du coup, la justification « SciPy exige 3.12–3.14, donc on le lance sur 3.12 » ne tient plus. La ligne NumPy est juste sur le fond (1.26.4 fonctionne), mais elle se trompe en parlant de « dernière version » compatible et passe sous silence deux contraintes réelles. Enfin, le générateur n'épingle pas ses dépendances, ce qui va à l'encontre de l'exigence de reproductibilité du catalogue.

## Constats

### F1 — MOYEN — SciPy « 1.18.0 actuelle, Python 3.12–3.14 » : version et plage Python obsolètes

- **Affirmation (Stack) :** « 1.18.0 current (June 2026), requires Python 3.12–3.14 and NumPy ≥ 2.0 — hence … run with `uv` on Python 3.12 ».
- **Vérifié :**
  - PyPI : la dernière version est **1.18.1**, mise en ligne le **2026-08-21**. Ses métadonnées déclarent `requires_python >=3.12`, **sans borne haute**, et `numpy>=2.0.0,<2.8`. Elle publie des wheels **cp315**, dont `scipy-1.18.1-cp315-cp315-win_amd64.whl` (ainsi que cp315t, manylinux et macOS). — https://pypi.org/pypi/scipy/json , https://pypi.org/pypi/scipy/1.18.1/json
  - La 1.18.0 (mise en ligne le 2026-06-19) n'avait que des wheels cp312, cp313 et cp314, et déjà `requires_python >=3.12`. — https://pypi.org/pypi/scipy/1.18.0/json
  - Conclusion : « 3.12–3.14 » décrivait les wheels de la 1.18.0, pas une exigence de SciPy. La donnée est périmée depuis août. Avec la 1.18.1, la machine du développeur (Python 3.15 par défaut, vu avec `py --list`) installe SciPy sans compilation.
- **Ce qui reste vrai :** NumPy ≥ 2.0 est bien incompatible avec le `numpy==1.26.4` du backend. L'isolement du générateur reste donc justifié, mais pour cette seule raison.
- **Correction :** remplacer la ligne par « SciPy 1.18.1 (2026-08-21), `requires-python >=3.12`, `numpy>=2.0,<2.8` ; isolé du backend à cause de NumPy ≥ 2 ». Garder Python 3.12 seulement si le but est d'aligner le générateur sur la version de production, et l'écrire comme un choix. Sinon, déclarer `requires-python = ">=3.12"` et laisser uv prendre l'interpréteur 3.15 déjà installé.

### F2 — MOYEN — Dépendances du générateur non épinglées : le catalogue « canonique et vérifié » ne peut pas être reproduit

- **Affirmation (AD-7) :** un script autonome avec des dépendances inline (PEP 723), lancé via `uv` sur Python 3.12, qui produit un catalogue canonique dont la copie doit rester identique octet par octet.
- **Vérifié :** la documentation uv confirme que `uv run script.py` lit le bloc `# /// script`, que `requires-python` dans ce bloc ou `--python 3.12` choisissent l'interpréteur, qu'uv télécharge Python s'il manque, et qu'un `[tool.uv] exclude-newer = "<RFC 3339>"` fige la résolution. — https://docs.astral.sh/uv/guides/scripts/ . Sur la machine : `uv 0.13.1 (2026-10-13)`, qui est aussi la dernière version sur PyPI. — https://pypi.org/pypi/uv/json
- **Problème :** le spine ne dit pas *comment* Python 3.12 est imposé. Sans `requires-python` ni `--python`, uv prend l'interpréteur par défaut, 3.15. Il ne fixe pas non plus de version de SciPy ou de NumPy. Or HiGHS évolue d'une version de SciPy à l'autre, et `milp` peut alors renvoyer une autre solution optimale, à coût égal, pour la même forme de sélection. Une régénération déclenchée par un changement de `multi_regles.json` modifierait alors des systèmes que la règle n'aurait pas dû toucher.
- **Correction :** ajouter à AD-7 que le bloc PEP 723 épingle `scipy==1.18.1` et `numpy==<version>`, déclare `requires-python`, et fixe `[tool.uv] exclude-newer`. Ajouter aussi que le catalogue enregistre en métadonnées les versions de SciPy et de HiGHS qui l'ont produit.

### F3 — MOYEN — NumPy 1.26.4 présentée à tort comme « la dernière » compatible SSE2 ; deux contraintes non dites

- **Affirmation (Stack, AD-7) :** « `1.26.4`, pinned — last manylinux wheel that runs on the SSE2-only production VPS ».
- **Vérifié :**
  - La note de version de NumPy 2.4.0 relève la `cpu-baseline` x86 par défaut à **x86-64-v2** (SSE4.2, POPCNT…). — https://numpy.org/doc/stable/release/2.4.0-notes.html
  - Avec NumPy 2.3, la baseline `min` sur x86_64 est `SSE SSE2 SSE3`, la même que pour la série 1.26. — https://numpy.org/doc/2.3/reference/simd/build-options.html . La rupture date donc de la **2.4** : les versions 2.0 à 2.3.x restent compatibles avec un CPU sans x86-64-v2. La 1.26.4 n'est pas « la dernière ». Le commit `2bb2518` décrit d'ailleurs correctement la cause (x86-64-v2).
  - Le VPS n'est pas strictement « SSE2-only » : la 1.26.4 elle-même exige SSE3, que fournit le modèle QEMU par défaut. Le terme est donc approximatif.
  - Les wheels manylinux x86_64 de la 1.26.4 existent seulement pour **cp39 à cp312**. — https://pypi.org/pypi/numpy/1.26.4/json . Cet épinglage **verrouille donc aussi l'image backend sur Python 3.12**, une contrainte que la ligne « Python 3.12 » ne mentionne pas.
  - Le `backend/.venv` local tourne en **Python 3.15 avec numpy 2.5.4**, et non 1.26.4, qui n'a pas de wheel cp315. Les tests backend en local, dont ceux du moteur Multi, s'exécutent donc sur une NumPy différente de celle de la production.
- **Correction :** écrire « la série NumPy 2.4+ exige x86-64-v2 ; 1.26.4 est épinglée (2.0–2.3 seraient aussi compatibles) ; cet épinglage impose Python ≤ 3.12 dans l'image ». Ajouter un point à surveiller : l'environnement de test local diverge de la production (Python 3.15 et NumPy 2.5 contre 3.12 et 1.26). Pour éviter cette divergence, lancer les tests backend dans le conteneur, ou dans un venv 3.12 créé avec `uv venv --python 3.12`.

### F4 — FAIBLE — `onUpgrade` vers la version 2 : le chemin « première installation » n'est pas couvert par la règle

- **Affirmation (AD-9) :** les deux nouvelles tables sont « introduced by a tested `onUpgrade` migration to version 2 ».
- **Vérifié :** la documentation de sqflite précise que `onCreate`, `onUpgrade` et `onDowngrade` s'excluent mutuellement. Sur une installation neuve, seul `onCreate` s'exécute, pas `onUpgrade` (sauf si `onCreate` est omis, auquel cas `onUpgrade` est appelé avec `oldVersion = 0`). — https://pub.dev/documentation/sqflite/latest/sqflite/openDatabase.html . Le code actuel (`database_helper.dart`) contient `version: 1` et seulement `onCreate`. Côté versions, sqflite `^2.4.3` reste correct : la dernière est la 2.4.4+2, publiée il y a quelques jours. — https://pub.dev/packages/sqflite/versions
- **Correction :** ajouter à AD-9 que `onCreate` doit produire directement le schéma v2, ou qu'il appelle les mêmes étapes de migration que `onUpgrade` à partir de 0. Prévoir deux tests : une base v1 existante migrée vers v2, et une installation neuve en v2.

### F5 — FAIBLE — `shared_preferences` : l'API utilisée est l'API historique, appelée à être dépréciée

- **Affirmation (AD-9) :** les seuils du verdict sont stockés dans `shared_preferences` avec les autres paramètres du moteur.
- **Vérifié :** la dernière version est la 2.5.6 ; le lockfile est en 2.5.5. La page du paquet « encourage fortement » les nouveaux utilisateurs à passer à `SharedPreferencesAsync` ou `SharedPreferencesWithCache`, et précise que l'API `SharedPreferences` « will be deprecated in the future ». — https://pub.dev/packages/shared_preferences . Le projet utilise `SharedPreferences.getInstance()` (`mobile/lib/main.dart`).
- **Correction :** rien à changer pour le MVP, puisque cela suit le code existant. Noter dans le spine que l'ajout des seuils suit l'API existante, et que la migration vers `SharedPreferencesWithCache` regroupera tous les paramètres d'un coup, sans mélange d'API.

### F6 — FAIBLE — Assets Flutter « seulement sous `mobile/` » : plausible, mais aucune source ne le confirme

- **Affirmation (AD-7) :** « Flutter bundles only files under `mobile/` ».
- **Vérifié :** la documentation officielle dit seulement que chaque asset est identifié par un chemin « relative to the `pubspec.yaml` file ». Elle ne dit rien des chemins `../` ni des fichiers hors du paquet. — https://docs.flutter.dev/ui/assets/assets-and-images . Il n'y a pas non plus de section `assets:` aujourd'hui dans `mobile/pubspec.yaml` : elle est à créer.
- **Impact :** nul sur la décision. Copier le catalogue dans `mobile/assets/` et vérifier l'identité octet par octet est la solution sûre dans tous les cas. Seule la justification est affirmée sans source.
- **Correction :** reformuler en « assets déclarés relativement à `pubspec.yaml` ; on ne s'appuie pas sur des chemins hors paquet ». Ajouter `assets/multi_catalogue.json` à la liste des fichiers liés par AD-7, dans la section `flutter: assets:`.

## Points vérifiés et conformes

- **`scipy.optimize.milp`** : il enveloppe HiGHS (« a wrapper of the HiGHS linear optimization software »), accepte `time_limit` et `mip_rel_gap`, et existe depuis SciPy 1.9.0 (« Added `scipy.optimize.milp` »). — https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.milp.html , https://docs.scipy.org/doc/scipy/release/1.9.0-notes.html
- **uv 0.13.1** : version installée identique à la dernière publiée sur PyPI. PEP 723, `--python` / `requires-python` et le téléchargement automatique de Python sont confirmés (voir F2 pour les sources).
- **Contexte Docker `./backend`** : confirmé par `docker-compose.yml` (`build: ./backend` pour `api` comme pour `ingestion`). `COPY app ./app` embarque `app/engine/multi/multi_catalogue.json`, et `backend/.dockerignore` n'exclut pas les `*.json`. `fixtures/`, à la racine, est bien hors du contexte : la copie est donc nécessaire.
- **sqflite `^2.4.3`** : contrainte compatible avec la dernière version, 2.4.4+2.
