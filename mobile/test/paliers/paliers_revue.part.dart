// Revue de la story 9.8 (L1 à L14), côté écrans.
part of 'paliers_ecrans_test.dart';

class _StoreLent extends MemorySessionStore {
  final attente = Completer<void>();
  bool effacement = false;

  @override
  Future<void> effacer() async {
    effacement = true;
    await attente.future;
    await super.effacer();
  }
}

class _Extraction implements ExtractionApi {
  final reponse = Completer<ProgrammeExtrait>();
  @override
  Future<ProgrammeExtrait> extractProgramme({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) => reponse.future;
}

ProgrammeExtrait _extrait() => ProgrammeExtrait.fromJson({
  'hippo': 'DEAUVILLE',
  'horses': [
    {'num': 1, 'name': 'IMPORTE'},
  ],
});

Future<PickedUpload?> _fichier() async =>
    PickedUpload(bytes: Uint8List.fromList([1]), filename: 'p.jpg', contentType: 'image/jpeg');

Future<void> _largeur(WidgetTester tester, double l) async {
  tester.view.physicalSize = Size(l, 1000);
  await _attendre(tester);
}

Future<void> _echeance(WidgetTester tester, _Env env) async {
  env.horloge.avancer(const Duration(hours: 1));
  await tester.pump(const Duration(hours: 1));
  await _attendre(tester);
}

Future<void> _jusquAuxResultats(WidgetTester tester) async {
  await _toucher(tester, _ligneCourse);
  await _toucher(tester, find.text('Voir les partants'));
  await _toucher(tester, find.text('Calculer'));
}

void _testsRevue() {
  for (final large in [false, true]) {
    final nom = large ? 'web large' : 'une colonne';

    testWidgets("L1 $nom : aucun envoi au changement de palier (achat, fin du droit)", (tester) async {
      final env = await _app(tester, large: large, palier: palierTurfiste, droit: const Duration(days: 7));
      await _jusquAuxResultats(tester);
      expect(env.pronostics.envoyes, hasLength(1));
      await _acheter(tester, env, Fonction.combinaisons, 'Pass journée Expert');
      expect(find.byType(ComboBlock), findsWidgets);
      expect(env.pronostics.envoyes, hasLength(1));
      env.horloge.avancer(const Duration(days: 8));
      await tester.pump(const Duration(days: 8));
      await _attendre(tester);
      expect(find.text(messagePronosticIndisponible), findsOneWidget);
      expect(env.pronostics.envoyes, hasLength(1));
    });

    testWidgets('L2 $nom : échéance, relecture en cours → ni contenu ni verrou ; droit prolongé → contenu', (
      tester,
    ) async {
      final env = await _app(tester, large: large, palier: palierExpert, droit: const Duration(hours: 1));
      await _jusquAuxResultats(tester);
      final resultat = env.c.read(resultsProvider);
      env.compte.attente = Completer();
      await _echeance(tester, env);
      expect(env.c.read(palierProvider).verification, isTrue);
      expect(find.byType(ComboBlock), findsNothing);
      expect(find.byType(LockedFeature), findsNothing);
      expect(find.text(messagePronosticIndisponible), findsNothing);
      expect(env.c.read(resultsProvider), same(resultat));

      env.compte.activerPass(
        masqueGratuit,
        palier: palierExpert,
        finDroit: env.horloge().toUtc().add(const Duration(days: 1)),
      );
      env.compte.attente!.complete();
      await _attendre(tester);
      expect(find.byType(ComboBlock), findsWidgets);
      expect(env.c.read(resultsProvider), same(resultat));
      expect(env.pronostics.envoyes, hasLength(1));
    });

    testWidgets('L2 $nom : échéance, relecture en échec → Gratuit + Réessayer', (tester) async {
      final env = await _app(tester, large: large, palier: palierExpert, droit: const Duration(hours: 1));
      await _jusquAuxResultats(tester);
      env.compte.enPanne = true;
      await _echeance(tester, env);
      expect(find.text(messagePronosticIndisponible), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('L3 $nom : fin du droit sur Configuration, saisie conservée sous le verrou', (tester) async {
      final env = await _app(tester, large: large, palier: palierTurfiste, droit: const Duration(hours: 1));
      await _toucher(tester, _ligneCourse);
      await tester.enterText(find.widgetWithText(TextField, 'Hippodrome'), 'MA SAISIE');
      await _echeance(tester, env);
      expect(find.byType(RaceConfigScreen), findsOneWidget);
      expect(_verrou(Fonction.configuration), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      env.compte.activerPass(
        masqueGratuit,
        palier: palierTurfiste,
        finDroit: env.horloge().toUtc().add(const Duration(days: 1)),
      );
      await env.c.read(palierProvider.notifier).actualiser();
      await _attendre(tester);
      expect(find.text('MA SAISIE'), findsOneWidget);
    });

    testWidgets('L3 $nom : Configuration verrouillée, partants consultables', (tester) async {
      final env = await _app(tester, large: large, palier: palierTurfiste, droit: const Duration(hours: 1));
      await _toucher(tester, _ligneCourse);
      await _echeance(tester, env);
      await _toucher(tester, find.text('Voir les partants'));
      expect(find.byType(HorseListScreen), findsOneWidget);
      expect(_cta, findsOneWidget);
    });

    testWidgets('L12 $nom : verrou de saisie ou d\'import au-dessus de la course, qui reste ouverte', (tester) async {
      final env = await _app(tester, large: large);
      await _toucher(tester, _ligneCourse);
      if (!large) await _retour(tester, HorseListScreen);
      for (final (bouton, fonction) in [
        (find.text('Saisie manuelle').first, Fonction.saisieManuelle),
        (find.byTooltip('Importer un programme par photo/PDF'), Fonction.importPhoto),
      ]) {
        await _toucher(tester, bouton);
        expect(_verrou(fonction), findsOneWidget);
        expect(env.c.read(courseCouranteProvider)?.id, 9);
        if (large) {
          expect(find.text('Ouverte'), findsOneWidget);
          expect(find.byType(HorseListScreen, skipOffstage: false), findsOneWidget);
        }
        await _retour(tester, fonction == Fonction.importPhoto ? ImportPhotoScreen : RaceConfigScreen);
        if (large) expect(_cta, findsOneWidget);
      }
    });

    testWidgets('L14 $nom : un verrou par section, Gratuit', (tester) async {
      await _app(tester, large: large);
      await _toucher(tester, _ligneCourse);
      expect(find.byType(LockedFeature), findsOneWidget);
      await _toucher(tester, _cta);
      final verrous = tester.widgetList<LockedFeature>(find.byType(LockedFeature)).map((v) => v.fonction).toList();
      expect(verrous, [Fonction.valueEtMise, Fonction.combinaisons]);
    });
  }

  testWidgets('L3 web, Gratuit : 1280 → 800 → 1280, achat entre-temps → toujours les partants', (tester) async {
    final env = await _app(tester, large: true);
    await _largeur(tester, 1280);
    await _toucher(tester, _ligneCourse);
    expect(_cta, findsOneWidget);
    await _largeur(tester, 800);
    expect(_cta, findsOneWidget);
    env.compte.activerPass(
      masqueGratuit,
      palier: palierTurfiste,
      finDroit: env.horloge().toUtc().add(const Duration(days: 1)),
    );
    await env.c.read(palierProvider.notifier).actualiser();
    await _attendre(tester);
    await _largeur(tester, 1280);
    expect(find.byType(HorseListScreen), findsOneWidget);
    expect(find.byType(RaceConfigScreen), findsNothing);
    expect(find.byTooltip('Configuration course'), findsOneWidget);
  });

  testWidgets('L3 web : Configuration choisie puis droit terminé, 1280 → 800 → 1280 → toujours Configuration', (
    tester,
  ) async {
    final env = await _app(tester, large: true, palier: palierTurfiste, droit: const Duration(hours: 1));
    await _largeur(tester, 1280);
    await _toucher(tester, _ligneCourse);
    await _echeance(tester, env);
    for (final l in [800.0, 1280.0]) {
      await _largeur(tester, l);
      expect(_verrou(Fonction.configuration), findsOneWidget);
      expect(find.byType(HorseListScreen), findsNothing);
    }
  });

  testWidgets('L14 web, Gratuit : Résultats verrouillés, 1280 → 800 → 1280', (tester) async {
    final env = await _app(tester, large: true);
    await _largeur(tester, 1280);
    await _toucher(tester, _ligneCourse);
    await _toucher(tester, _cta);
    for (final l in [800.0, 1280.0]) {
      await _largeur(tester, l);
      expect(find.text(messagePronosticIndisponible), findsOneWidget);
      expect(find.byType(LockedFeature), findsNWidgets(2));
      expect(env.c.read(resultsProvider), isNull);
    }
    await _retour(tester, ResultsScreen);
    expect(_cta, findsOneWidget);
  });

  testWidgets('L12 web : verrou de saisie levé puis confirmé → la course n\'est plus « Ouverte », rouvrable', (
    tester,
  ) async {
    final env = await _app(tester, large: true);
    await _toucher(tester, _ligneCourse);
    await _toucher(tester, find.text('Saisie manuelle').first);
    env.compte.activerPass(
      masqueGratuit,
      palier: palierTurfiste,
      finDroit: env.horloge().toUtc().add(const Duration(days: 1)),
    );
    await env.c.read(palierProvider.notifier).actualiser();
    await _attendre(tester);
    expect(find.text('Ouverte'), findsOneWidget);
    await _toucher(tester, find.text('Voir les partants'));
    expect(env.c.read(courseCouranteProvider), isNull);
    expect(find.text('Ouverte'), findsNothing);
    await _toucher(tester, _ligneCourse);
    expect(env.c.read(courseCouranteProvider)?.id, 9);
    expect(find.text('Ouverte'), findsOneWidget);
  });

  testWidgets('L7 : déconnexion → configuration et course courante remises à zéro', (tester) async {
    final env = await _app(tester, masque: masqueExpert);
    await _toucher(tester, _ligneCourse);
    expect(env.c.read(raceConfigProvider).hippodrome, 'VINCENNES');
    expect(env.c.read(raceConfigProvider).distance, 2700);
    await env.c.read(authProvider.notifier).seDeconnecter();
    await _attendre(tester);
    expect(env.c.read(courseCouranteProvider), isNull);
    expect(env.c.read(raceConfigProvider).distance, 2000);
  });

  testWidgets('L7 : déconnexion en cours, une lecture ne part jamais sans compte', (tester) async {
    final store = _StoreLent();
    await store.enregistrerSession(accessToken: 'a', refreshToken: 'r', numeroMasque: masqueExpert);
    final env = await _app(tester, store: store);
    final fin = env.c.read(authProvider.notifier).seDeconnecter();
    await _attendre(tester);
    expect(store.effacement, isTrue);
    await env.c.read(palierProvider.notifier).actualiser();
    expect(env.compte.cles, isNot(contains(null)));
    store.attente.complete();
    await fin;
    await _attendre(tester);
    expect(env.compte.cleCompteCourant, isNull);
    expect(env.compte.cles, isNot(contains(null)));
  });

  testWidgets('L8 : sans CompteApi (démo coupée), aucun verrou', (tester) async {
    final env = await _app(tester, demo: false);
    expect(env.c.read(palierProvider).gere, isFalse);
    await _jusquAuxResultats(tester);
    expect(find.byType(ComboBlock), findsWidgets);
    expect(find.byType(LockedFeature, skipOffstage: false), findsNothing);
    expect(env.compte.cles, isEmpty);
  });

  testWidgets('L9 : feuille Terrain ouverte, fin du droit, choix → sans plantage', (tester) async {
    final env = await _app(tester, palier: palierTurfiste, droit: const Duration(hours: 1));
    await _toucher(tester, _ligneCourse);
    await _toucher(tester, find.text('Terrain'));
    expect(find.text('TERRAIN'), findsOneWidget);
    await _echeance(tester, env);
    await tester.tap(find.byType(ListTile).last);
    await _attendre(tester);
    expect(tester.takeException(), isNull);
    expect(_verrou(Fonction.configuration), findsOneWidget);
  });

  for (final champ in ['Terrain', 'Niveau']) {
    testWidgets('L9 : écran retiré sous la feuille $champ, choix → sans plantage', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cle = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [palierFixe(palierTurfiste)],
          child: MaterialApp(navigatorKey: cle, home: const Text('RACINE')),
        ),
      );
      final route = MaterialPageRoute<void>(builder: (_) => const RaceConfigScreen());
      cle.currentState!.push(route);
      await tester.pumpAndSettle();
      await tester.tap(find.text(champ));
      await tester.pumpAndSettle();
      cle.currentState!.removeRoute(route);
      await tester.pump();
      await tester.tap(find.byType(ListTile).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('RACINE'), findsOneWidget);
    });
  }

  group('écran isolé, revue', () {
    late PalierFixe palier;
    late ProviderContainer c;

    Future<void> pump(WidgetTester tester, Widget ecran, String? p) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      palier = PalierFixe(p);
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          palierProvider.overrideWith(() => palier),
          ...overridesAuth(store: await storeAvecSession(), web: true),
        ],
      );
      addTearDown(c.dispose);
      c.read(horsesProvider.notifier).setAll([Horse(nom: 'CHEVAL 1')]);
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: ecran)));
      await tester.pump();
    }

    testWidgets('L10 : sans course du programme, le verrou seul', (tester) async {
      await pump(tester, const HorseListScreen(), palierGratuit);
      expect(_verrou(Fonction.modifierPartants), findsOneWidget);
      expect(_cta, findsNothing);
      c.read(pronosticContextProvider.notifier).courseChargee(9);
      await tester.pump();
      expect(_cta, findsOneWidget);
    });

    testWidgets('L11 : import confirmé → plus de course courante, verrou « Saisie manuelle »', (tester) async {
      final api = _Extraction()..reponse.complete(_extrait());
      await pump(tester, ImportPhotoScreen(api: api, pickFile: _fichier), palierTurfiste);
      c.read(courseCouranteProvider.notifier).definir(_course);
      await tester.tap(find.text('Galerie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer et configurer'));
      await tester.pumpAndSettle();
      expect(c.read(courseCouranteProvider), isNull);
      palier.passerA(palierGratuit);
      await tester.pump();
      expect(_verrou(Fonction.saisieManuelle), findsOneWidget);
    });

    testWidgets("L14 : extraction en cours quand le palier tombe → verrou, rien d'appliqué", (tester) async {
      final api = _Extraction();
      await pump(tester, ImportPhotoScreen(api: api, pickFile: _fichier), palierTurfiste);
      await tester.tap(find.text('Galerie'));
      await tester.pump();
      palier.passerA(palierGratuit);
      await tester.pump();
      api.reponse.complete(_extrait());
      await tester.pumpAndSettle();
      expect(_verrou(Fonction.importPhoto), findsOneWidget);
      expect(find.text('Confirmer et configurer'), findsNothing);
      expect(c.read(horsesProvider).single.nom, 'CHEVAL 1');
    });

    testWidgets("L14 : choix du fichier en cours quand le palier tombe → aucun appel", (tester) async {
      final choix = Completer<PickedUpload?>();
      var appels = 0;
      final api = _ExtractionComptee(() => appels++);
      await pump(tester, ImportPhotoScreen(api: api, pickFile: () => choix.future), palierTurfiste);
      await tester.tap(find.text('Galerie'));
      await tester.pump();
      palier.passerA(palierGratuit);
      choix.complete(await _fichier());
      await tester.pumpAndSettle();
      expect(appels, 0);
    });

    testWidgets('L14 : boutons touchés dans la même image que la chute du palier → sans effet', (tester) async {
      await pump(tester, const HorseEditScreen(index: 0), palierTurfiste);
      final enregistrer = tester
          .widget<IconButton>(find.ancestor(of: find.byIcon(Icons.check), matching: find.byType(IconButton)))
          .onPressed!;
      await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'AUTRE');
      palier.passerA(palierGratuit);
      enregistrer();
      await tester.pump();
      expect(c.read(horsesProvider).single.nom, 'CHEVAL 1');
    });

    testWidgets('L14 : Configuration confirmée après la chute du palier → sans effet', (tester) async {
      await pump(tester, const RaceConfigScreen(), palierTurfiste);
      final confirmer = tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Voir les partants'))
          .onPressed!;
      await tester.enterText(find.widgetWithText(TextField, 'Hippodrome'), 'AUTRE');
      palier.passerA(palierGratuit);
      confirmer();
      await tester.pumpAndSettle();
      expect(c.read(raceConfigProvider).hippodrome, 'Vincennes');
      expect(find.byType(HorseListScreen), findsNothing);
    });

    for (final (cible, bankroll, contraste) in [(palierTurfiste, 100.0, 9.0), (palierGratuit, 500.0, 9.0)]) {
      testWidgets('L14 : Réglages, confirmation ouverte en Expert, palier $cible', (tester) async {
        await pump(tester, const SettingsScreen(), palierExpert);
        c.read(engineParamsProvider.notifier).update(const EngineParams(contraste: 9, bankroll: 500));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.restore));
        await tester.pumpAndSettle();
        palier.passerA(cible);
        await tester.pump();
        await tester.tap(find.text('Réinitialiser'));
        await tester.pumpAndSettle();
        expect(c.read(engineParamsProvider).bankroll, bankroll);
        expect(c.read(engineParamsProvider).contraste, contraste);
      });
    }

    testWidgets("L14 : verrou, nœud unique sans bouton enfant ; son action ouvre Offres", (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const ResultsScreen(), palierGratuit);
      final noeud = tester.getSemantics(_verrou(Fonction.combinaisons));
      expect(noeud.childrenCount, 0);
      expect(find.bySemanticsLabel('Voir les offres'), findsNothing);
      expect(
        find.bySemanticsLabel('Combinaisons, palier Expert, bouton Voir les offres'),
        findsOneWidget,
      );
      tester.semantics.tap(find.semantics.byLabel('Combinaisons, palier Expert, bouton Voir les offres'));
      await tester.pumpAndSettle();
      expect(find.byType(OffresScreen), findsOneWidget);
      handle.dispose();
    });

    testWidgets("L14 : « Voir les offres » n'est jamais en or, quel que soit son état", (tester) async {
      await pump(tester, const ResultsScreen(), palierGratuit);
      final bouton = tester.widget<OutlinedButton>(
        find.descendant(of: _verrou(Fonction.combinaisons), matching: find.byType(OutlinedButton)),
      );
      final style = bouton.style!;
      for (final etats in <Set<WidgetState>>[
        {},
        {WidgetState.hovered},
        {WidgetState.pressed},
        {WidgetState.focused},
        {WidgetState.disabled},
      ]) {
        expect(style.foregroundColor!.resolve(etats), isNot(JetonsAuth.gold));
        expect(style.backgroundColor!.resolve(etats), isNot(JetonsAuth.gold));
        expect(style.side!.resolve(etats)!.color, isNot(JetonsAuth.gold));
        final voile = style.overlayColor?.resolve(etats);
        if (voile != null) expect(voile.withValues(alpha: 1), isNot(JetonsAuth.gold));
      }
      expect(style.foregroundColor!.resolve({}), JetonsAuth.text);
    });
  });
}

class _ExtractionComptee implements ExtractionApi {
  final VoidCallback surAppel;
  _ExtractionComptee(this.surAppel);
  @override
  Future<ProgrammeExtrait> extractProgramme({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    surAppel();
    return _extrait();
  }
}
