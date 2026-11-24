// Corrections de revue W1–W14 de la story 8.7 (web).
part of 'web_compagnon_test.dart';

/// Réponses de statut retenues jusqu'à [porte].complete().
class _ApiRetenue extends FauxAppairageApi {
  final porte = Completer<void>();
  _ApiRetenue({super.horloge});

  @override
  Future<StatutAppairage> statut(String id) async {
    final r = await super.statut(id);
    await porte.future;
    return r;
  }
}

/// Création retenue tant que [porte] n'est pas complétée.
class _ApiCreationLente extends FauxAppairageApi {
  final porte = Completer<void>();
  _ApiCreationLente({super.horloge});

  @override
  Future<Appairage> creer() async {
    await porte.future;
    return super.creer();
  }
}

/// Nom d'appareil donné par le serveur.
class _ApiNommee extends FauxAppairageApi {
  _ApiNommee({super.horloge});

  @override
  Future<Appairage> creer() async {
    final a = await super.creer();
    return Appairage(id: a.id, contenuQr: a.contenuQr, validite: a.validite, nomAppareil: 'Firefox sur Linux');
  }
}

class _StoreSansEcriture extends MemorySessionStore {
  @override
  Future<void> enregistrerSession({
    required String accessToken,
    required String refreshToken,
    required String numeroMasque,
  }) async =>
      throw Exception('stockage plein');
}

ProviderContainer _conteneurDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PredictionHippiqueApp)));

NavigatorState _navDroite(WidgetTester tester) =>
    tester.state<NavigatorState>(find.descendant(of: _droite, matching: find.byType(Navigator)).first);

/// Écran qui refuse d'être quitté, comme Paiement pendant l'envoi.
void _pousserOccupe(WidgetTester tester) {
  unawaited(_navDroite(tester).push(MaterialPageRoute<void>(
    builder: (_) => const PopScope(canPop: false, child: Scaffold(body: Text('PAIEMENT EN COURS'))),
  )));
}

Future<void> _redimensionner(WidgetTester tester, double largeur) async {
  tester.view.physicalSize = Size(largeur, 800);
  await tester.pumpAndSettle();
}

/// Couleurs de tous les textes et icônes sous [zone].
Set<Color> _couleurs(WidgetTester tester, Finder zone) {
  final vues = <Color>{};
  for (final w in tester.widgetList<RichText>(find.descendant(of: zone, matching: find.byType(RichText)))) {
    w.text.visitChildren((span) {
      final c = span.style?.color;
      if (c != null) vues.add(c);
      return true;
    });
  }
  return vues;
}

Future<void> _ouvrirPartants(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('course-9')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Voir les partants'));
  await tester.pumpAndSettle();
}

void _testsRevuePorte() {
  testWidgets('W1 : session effacée → appairage avec message ; la saisie SMS ne revient pas au QR', (tester) async {
    await _pump(tester, store: await storeExpert());
    _conteneurDe(tester).read(authProvider.notifier).quitterAppareilBloque(message: messageSessionEffacee);
    await _attendre(tester);
    expect(_qr, findsOneWidget);
    expect(find.text(messageSessionEffacee), findsOneWidget);

    await tester.tap(find.text('Se connecter avec un code SMS'));
    await _attendre(tester);
    expect(find.text(messageSessionEffacee), findsOneWidget);
    await tester.enterText(find.byType(TextField), '6771');
    await _attendre(tester);
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.text('6771'), findsOneWidget, reason: 'la saisie est gardée');
    expect(_qr, findsNothing);
  });

  testWidgets("W5 : limite d'appareils par QR → Appareil bloqué, aucune session", (tester) async {
    final env = await _pump(tester, numero: FauxCompteApi.numeroBloque);
    await _approuver(tester);
    expect(find.byType(AppareilBloqueScreen), findsOneWidget);
    expect(env.store.session, isNull);
    expect(_conteneurDe(tester).read(authProvider).value!.blocage!.jeton.valeur, isNotEmpty);
  });

  testWidgets('W6 : à 1 min 59 le code est encore valable, à 2 min il expire', (tester) async {
    final env = await _pump(tester);
    await _avancer(tester, env.horloge, const Duration(minutes: 1, seconds: 59));
    expect(_qr, findsOneWidget);
    expect(find.textContaining('expire dans 1 s'), findsOneWidget);
    await _avancer(tester, env.horloge, const Duration(seconds: 1));
    expect(_qr, findsNothing);
    expect(find.text('Code expiré'), findsWidgets);
  });

  testWidgets("W6 : serveur en retard d'une heure sur l'ordinateur, décompte juste", (tester) async {
    final serveur = Horloge()..avancer(const Duration(hours: -1));
    await _pump(tester, api: FauxAppairageApi(horloge: serveur.call));
    await tester.pump(const Duration(seconds: 1));
    expect(_qr, findsOneWidget);
    expect(find.textContaining('expire dans 2 min'), findsOneWidget);
  });

  testWidgets("W7 : nouveau QR demandé pendant l'approbation → session ouverte", (tester) async {
    final api = _ApiRetenue(horloge: Horloge().call);
    await _pump(tester, api: api);
    await _approuver(tester);
    expect(_shell, findsNothing);
    await tester.tap(find.text('Afficher un nouveau QR code'));
    await _attendre(tester);
    api.porte.complete();
    await _attendre(tester);
    expect(_shell, findsOneWidget);
  });

  testWidgets("W7 : code SMS choisi pendant l'approbation → session ouverte", (tester) async {
    final api = _ApiRetenue(horloge: Horloge().call);
    await _pump(tester, api: api);
    await _approuver(tester);
    await tester.tap(find.text('Se connecter avec un code SMS'));
    await _attendre(tester);
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    api.porte.complete();
    await _attendre(tester);
    expect(_shell, findsOneWidget);
  });

  testWidgets('W12 : sans QR, aucun temps restant (création en cours, puis en échec)', (tester) async {
    final lente = _ApiCreationLente(horloge: Horloge().call);
    await _pump(tester, api: lente);
    expect(find.text('Connecter cet ordinateur'), findsOneWidget);
    expect(find.textContaining('expire dans'), findsNothing);
    lente.porte.completeError(Exception('réseau'));
    await _attendre(tester);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.textContaining('expire dans'), findsNothing);
  });

  testWidgets('W12 : ouverture de session en échec → message et nouveau QR, jamais « Code expiré »', (tester) async {
    final env = await _pump(tester, store: _StoreSansEcriture());
    final premier = env.api.dernierId;
    await _approuver(tester);
    expect(find.text('Une erreur est survenue — réessayez'), findsOneWidget);
    expect(find.text('Code expiré'), findsNothing);
    expect(_qr, findsOneWidget);
    expect(env.api.dernierId, isNot(premier));
  });

  testWidgets('W13 : zone calme ≥ 4 modules, modules et repères en `bg`', (tester) async {
    final env = await _pump(tester);
    final vue = tester.widget<QrImageView>(_qr);
    expect(vue.dataModuleStyle.color, JetonsAuth.bg);
    expect(vue.eyeStyle.color, JetonsAuth.bg);
    final zone = tester.getRect(find.byKey(const Key('zone-calme-qr')));
    final code = tester.getRect(_qr);
    // Même longueur de contenu, donc même nombre de modules.
    final modules = QrValidator.validate(
      data: 'analyseur-hippique:appairage:${env.api.dernierId}:${'0' * 32}',
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    ).qrCode!.moduleCount;
    final quatre = 4 * code.width / modules;
    expect(code.left - zone.left, greaterThanOrEqualTo(quatre));
    expect(code.top - zone.top, greaterThanOrEqualTo(quatre));
    expect(zone.right - code.right, greaterThanOrEqualTo(quatre));
    expect(zone.bottom - code.bottom, greaterThanOrEqualTo(quatre));
  });

  testWidgets("W14 : nom d'appareil donné par l'API", (tester) async {
    await _pump(tester, api: _ApiNommee(horloge: Horloge().call));
    expect(_texte('vérifiez le nom « Firefox sur Linux »'), findsOneWidget);
    expect(_texte('Chrome sur Windows'), findsNothing);
  });
}

void _testsRevueLarge() {
  testWidgets('W2 : 1280 → 800 → 1280, course et écrans gardés sans rechargement', (tester) async {
    final env = await _pump(tester, store: await storeExpert());
    await _ouvrirPartants(tester);
    expect(find.text('Calculer'), findsOneWidget);

    await _redimensionner(tester, 800);
    expect(_shell, findsNothing);
    expect(find.text('Calculer'), findsOneWidget);
    expect(find.text('FOUDRE NOIRE'), findsOneWidget);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

    await _redimensionner(tester, 1280);
    expect(find.text('Calculer'), findsOneWidget);
    expect(find.descendant(of: _droite, matching: find.text('Calculer')), findsOneWidget);
    expect(find.text('Ouverte'), findsOneWidget);
    expect(env.repo.partantsDemandes, [9]);

    // Toute la pile a suivi : retour → Configuration → vide.
    final retour = find.descendant(of: _droite, matching: find.byType(BackButton));
    await tester.tap(retour);
    await tester.pumpAndSettle();
    expect(find.text('Configuration course'), findsOneWidget);
    await tester.tap(retour);
    await tester.pumpAndSettle();
    expect(find.text('Choisissez une course dans la liste.'), findsOneWidget);
  });

  testWidgets('W2 : course ouverte en étroit, puis fenêtre élargie', (tester) async {
    final env = await _pump(tester, taille: _etroit, store: await storeExpert());
    await _ouvrirPartants(tester);
    await _redimensionner(tester, 1280);
    expect(find.descendant(of: _droite, matching: find.text('Calculer')), findsOneWidget);
    expect(find.text('Ouverte'), findsOneWidget);
    expect(env.repo.partantsDemandes, [9]);
  });

  testWidgets('W2 : seuils 1023 / 1024, retour sous 960 seulement', (tester) async {
    await _pump(tester, taille: const Size(1023, 800), store: await storeExpert());
    expect(_shell, findsNothing);
    await _redimensionner(tester, 1024);
    expect(_shell, findsOneWidget);
    await _redimensionner(tester, 1023);
    expect(_shell, findsOneWidget);
    await _redimensionner(tester, 960);
    expect(_shell, findsOneWidget);
    await _redimensionner(tester, 959);
    expect(_shell, findsNothing);
    await _redimensionner(tester, 1023);
    expect(_shell, findsNothing);
  });

  testWidgets('W2 : date choisie gardée à la bascule', (tester) async {
    await _pump(tester, store: await storeExpert());
    await tester.tap(find.byTooltip('Choisir la date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('18/11/2026'), findsOneWidget);
    await _redimensionner(tester, 800);
    expect(find.text('18/11/2026'), findsOneWidget);
    await _redimensionner(tester, 1280);
    expect(find.text('18/11/2026'), findsOneWidget);
  });

  testWidgets('W3 : écran occupé gardé, snackbar, aucune course chargée', (tester) async {
    final env = await _pump(tester, store: await storeExpert());
    _pousserOccupe(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await _attendre(tester);
    expect(find.text("Terminez ou quittez l'écran en cours avant d'ouvrir une course."), findsOneWidget);
    expect(find.text('PAIEMENT EN COURS'), findsOneWidget);
    expect(env.repo.partantsDemandes, isEmpty);
    expect(find.text('Ouverte'), findsNothing);
    // Saisie manuelle et liens de l'en-tête : même règle.
    await tester.tap(find.text('Saisie manuelle'));
    await tester.tap(find.text('Profil'));
    await _attendre(tester);
    expect(find.text('PAIEMENT EN COURS'), findsOneWidget);
  });

  testWidgets('W3 : écran devenu occupé pendant le chargement → données non remplacées', (tester) async {
    final env = await _pump(tester, store: await storeExpert());
    env.repo.attente = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await tester.pump();
    _pousserOccupe(tester);
    await _attendre(tester);
    env.repo.attente!.complete();
    await _attendre(tester);
    expect(find.text('PAIEMENT EN COURS'), findsOneWidget);
    expect(_conteneurDe(tester).read(courseCouranteProvider), isNull);
  });

  testWidgets('W3 : cliquer la course déjà ouverte ne fait rien', (tester) async {
    final env = await _pump(tester, store: await storeExpert());
    await _ouvrirPartants(tester);
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await tester.pumpAndSettle();
    expect(env.repo.partantsDemandes, [9]);
    expect(find.text('Calculer'), findsOneWidget);
  });

  testWidgets('W4 : Profil → Mes appareils → Profil ; Réglages garde la course dessous', (tester) async {
    await _pump(tester, store: await storeExpert());
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mes appareils'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes appareils'));
    await tester.pumpAndSettle();
    expect(find.byType(MesAppareilsScreen), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.byType(MesAppareilsScreen, skipOffstage: false), findsNothing);
    expect(find.byType(ProfilScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ProfilScreen, skipOffstage: false), findsNothing);
    await tester.tap(find.descendant(of: _droite, matching: find.byType(BackButton)));
    await tester.pumpAndSettle();
    expect(find.text('Configuration course'), findsOneWidget);
    expect(find.text('Ouverte'), findsOneWidget);
  });

  testWidgets('W8 : saisie manuelle et import dans la colonne de droite', (tester) async {
    await _pump(tester, store: await storeExpert());
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await tester.pumpAndSettle();
    final c = _conteneurDe(tester);
    expect(c.read(courseCouranteProvider)?.id, 9);

    await tester.tap(find.descendant(of: _gauche, matching: find.text('Saisie manuelle')));
    await tester.pumpAndSettle();
    expect(c.read(courseCouranteProvider), isNull);
    expect(find.descendant(of: _droite, matching: find.text('Configuration course')), findsOneWidget);
    expect(find.text('Ouverte'), findsNothing);

    await tester.tap(find.byTooltip('Importer un programme par photo/PDF'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _droite, matching: find.byType(ImportPhotoScreen)), findsOneWidget);
    expect(_gauche, findsOneWidget);
  });

  testWidgets('W9, W11 : ligne « sélectionnée », arbre stable, contour intérieur', (tester) async {
    await _pump(tester, store: await storeExpert());
    bool? choisie(int id) => tester
        .widget<Semantics>(
          find.ancestor(of: find.byKey(ValueKey('course-$id')), matching: find.byType(Semantics)).first,
        )
        .properties
        .selected;
    expect(choisie(9), isFalse);
    final avant = tester.element(find.byKey(const ValueKey('course-9')));
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await tester.pumpAndSettle();
    expect(choisie(9), isTrue);
    expect(choisie(10), isFalse);
    expect(tester.element(find.byKey(const ValueKey('course-9'))), same(avant));
    final lignes = tester
        .widgetList<ContourFocus>(find.descendant(of: _gauche, matching: find.byType(ContourFocus)))
        .where((w) => w.interieur);
    expect(lignes, hasLength(2), reason: 'une par ligne de course');
  });

  testWidgets('W11 : le tracé intérieur reste dans la ligne', (tester) async {
    expect(
      (Canvas canvas) => const PeintreContourFocus(4, interieur: true).paint(canvas, const Size(100, 50)),
      paints..rrect(rrect: RRect.fromLTRBR(3, 3, 97, 47, const Radius.circular(4)), color: JetonsAuth.gold),
    );
  });

  testWidgets('W10 : aucun or à gauche sans focus (liste, chargement, vide, erreur)', (tester) async {
    final env = await _pump(tester, store: await storeExpert());
    void sansOr(String cas) {
      final couleurs = _couleurs(tester, _gauche);
      expect(couleurs, isNotEmpty, reason: cas);
      expect(couleurs, isNot(contains(JetonsAuth.gold)), reason: cas);
      for (final e in find.descendant(of: _gauche, matching: find.byType(CircularProgressIndicator)).evaluate()) {
        expect(ProgressIndicatorTheme.of(e).color, JetonsAuth.muted, reason: cas);
      }
    }

    sansOr('liste dépliée');
    env.repo.attente = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('course-9')));
    await tester.pump();
    expect(find.descendant(of: _gauche, matching: find.byType(CircularProgressIndicator)), findsWidgets);
    sansOr('chargement');
    env.repo.attente!.complete();
    await tester.pumpAndSettle();
    sansOr('course ouverte');

    env.repo.programme.clear();
    await tester.tap(find.text('Rafraîchir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune course chargée'), findsOneWidget);
    sansOr('vide');
  });

  testWidgets('W10 : aucun or à gauche, programme en erreur', (tester) async {
    await _pump(tester, store: await storeExpert(), programmeEnEchec: true);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(_couleurs(tester, _gauche), isNot(contains(JetonsAuth.gold)));
  });
}
