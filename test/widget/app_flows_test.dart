import 'dart:async';

import 'package:collectionner/app/preferences.dart';
import 'package:collectionner/app/router/app_router.dart';
import 'package:collectionner/features/auctions/application/watchlist.dart';
import 'package:collectionner/features/auctions/presentation/watchlist_screen.dart';
import 'package:collectionner/features/auth/application/session_controller.dart';
import 'package:collectionner/features/catalog/presentation/photo_viewer_screen.dart';
import 'package:collectionner/features/catalog/presentation/widgets/collectible_card.dart';
import 'package:collectionner/features/favorites/favorites.dart';
import 'package:collectionner/features/launch/launch_scene.dart';
import 'package:collectionner/features/notifications/notices.dart';
import 'package:collectionner/features/recognition/application/scan_controller.dart';
import 'package:collectionner/features/recognition/domain/recognition_models.dart';
import 'package:collectionner/features/recognition/presentation/camera_screen.dart';
import 'package:collectionner/features/recognition/presentation/scan_result_screen.dart';
import 'package:collectionner/features/search/search_screen.dart';
import 'package:collectionner/features/success/success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  testWidgets('launch scene plays over the app once and then gets out of the way', (tester) async {
    await pumpApp(tester, launchScene: true);
    expect(find.byType(LaunchScene), findsOneWidget);
    await settle(tester, 20);
    expect(find.byType(LaunchScene), findsNothing);
    expect(find.text('¿Qué coleccionamos hoy?'), findsOneWidget);
  });

  testWidgets('back twice on home plays the farewell and closes the app', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpApp(tester);
    await tester.binding.handlePopRoute();
    await settle(tester, 3);
    expect(find.text('Presiona atrás otra vez para salir'), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));
    await tester.binding.handlePopRoute();
    await settle(tester, 8);
    expect(find.text('Hasta pronto'), findsOneWidget);
    await settle(tester, 14);
    expect(calls, contains('SystemNavigator.pop'));
  });

  testWidgets('home loads catalogue, auctions and communities from the API', (tester) async {
    await pumpApp(tester);
    expect(find.text('¿Qué coleccionamos hoy?'), findsOneWidget);
    // Closing auctions and the latest entries sit below the intro; lists build lazily.
    await tester.scrollUntilVisible(find.text('Recién llegadas'), 300, scrollable: find.byType(Scrollable).first);
    await settle(tester, 3);
    expect(find.text('Lego Millennium Falcon 75192'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Retro Gaming Preservation'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Retro Gaming Preservation'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs and catalogue search filters results', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Explorar'));
    await settle(tester);
    expect(find.text('4 piezas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'omega');
    await settle(tester, 6);
    expect(find.text('Reloj Omega Seamaster 1968'), findsOneWidget);
    expect(find.text('Charizard Holo Base Set'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'inexistente');
    await settle(tester, 6);
    expect(find.text('No hay piezas que coincidan con esa búsqueda.'), findsOneWidget);
    await tester.tap(find.text('Limpiar filtros'));
    await settle(tester, 6);
    expect(find.text('Charizard Holo Base Set'), findsOneWidget);
  });

  testWidgets('API failure shows an error state and retry recovers', (tester) async {
    final backend = Fixtures.standardBackend()..json('GET', '/api/v1/collectibles', {'detail': 'boom'}, status: 500);
    await pumpApp(tester, backend: backend);
    await tester.tap(find.byTooltip('Explorar'));
    await settle(tester);
    expect(find.text('Ocurrió un error en el servidor. Inténtalo más tarde.'), findsOneWidget);

    backend.json('GET', '/api/v1/collectibles', Fixtures.catalogue());
    await tester.tap(find.text('Reintentar'));
    await settle(tester);
    expect(find.text('Charizard Holo Base Set'), findsOneWidget);
  });

  testWidgets('collectible detail shows record, reviews and comments', (tester) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go(Routes.collectible(1));
    await settle(tester);
    expect(find.text('The Legend of Zelda: Ocarina of Time'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pieza impecable.'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pieza impecable.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('¿Incluye manual?'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Inicia sesión para participar.'), findsOneWidget);
  });

  testWidgets('photo viewer opens from the piece and closes with a downward drag', (tester) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go(Routes.collectible(1));
    await settle(tester);
    await tester.tap(find.byType(PageView).first);
    await settle(tester, 4);
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    await tester.drag(find.byType(PhotoViewerScreen), const Offset(0, 420));
    await settle(tester, 5);
    expect(find.byType(PhotoViewerScreen), findsNothing);
  });

  testWidgets('following an auction lists it under the auctions you follow', (tester) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go(Routes.auction(7));
    await settle(tester);
    await tester.tap(find.byTooltip('Seguir subasta'));
    await settle(tester, 4);
    expect(app.container.read(watchedAuctionsProvider), {7});
    unawaited(app.container.read(routerProvider).push(Routes.watchlist));
    await settle(tester);
    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(find.byTooltip('Dejar de seguir'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pref.watchedAuctions'), ['7']);
  });

  testWidgets('success screen celebrates and its button leads on', (tester) async {
    final app = await pumpApp(tester);
    unawaited(
      app.container
          .read(routerProvider)
          .push(
            Routes.success,
            extra: const SuccessArgs(
              title: '¡Puja realizada!',
              message: 'Listo.',
              primaryLabel: 'Ver la subasta',
              primaryRoute: '/auctions/7',
            ),
          ),
    );
    await settle(tester, 20);
    expect(find.text('¡Puja realizada!'), findsOneWidget);
    await tester.tap(find.text('Ver la subasta'));
    await settle(tester);
    expect(find.byType(SuccessScreen), findsNothing);
    expect(app.container.read(routerProvider).state.matchedLocation, '/auctions/7');
  });

  testWidgets('my bids shows where the user stands in each auction', (tester) async {
    final app = await pumpApp(tester, signedIn: true);
    app.container.read(routerProvider).go(Routes.myBids);
    await settle(tester);
    expect(find.text('Mis pujas'), findsOneWidget);
    expect(find.text('Vas ganando'), findsOneWidget);
    expect(find.text('Lego Millennium Falcon 75192'), findsOneWidget);
  });

  testWidgets('auction calendar and results open from the auctions tab', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('GET', '/api/v1/auctions', [Fixtures.auction(), Fixtures.auction(id: 8, open: false)]);
    final app = await pumpApp(tester, backend: backend);
    await tester.tap(find.byTooltip('Subastas'));
    await settle(tester);
    await tester.tap(find.text('Agenda'));
    await settle(tester);
    expect(find.text('Agenda de subastas'), findsOneWidget);
    expect(find.textContaining('cierra este día'), findsOneWidget);
    app.container.read(routerProvider).pop();
    await settle(tester);
    await tester.tap(find.text('Resultados'));
    await settle(tester);
    expect(find.text('Vendido en total'.toUpperCase()), findsOneWidget);
  });

  testWidgets('notices tell the user where they stand and can all be marked read', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('GET', '/api/v1/auctions', [
        {
          ...Fixtures.auction(),
          'bids': [
            {
              'id': 3,
              'auctionId': 7,
              'amount': 900,
              'bidderId': 3,
              'bidderName': 'poke_vault',
              'createdAt': '2026-10-04T10:00:00Z',
            },
            {
              'id': 2,
              'auctionId': 7,
              'amount': 780,
              'bidderId': 1,
              'bidderName': 'collector_prime',
              'createdAt': '2026-10-03T10:00:00Z',
            },
          ],
        },
      ]);
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    await tester.tap(find.byTooltip('Avisos'));
    await settle(tester);
    expect(find.text('Te superaron'), findsOneWidget);
    expect(app.container.read(unreadNoticesProvider), greaterThan(0));
    await tester.tap(find.byTooltip('Marcar leídos'));
    await settle(tester, 3);
    expect(app.container.read(unreadNoticesProvider), 0);
  });

  testWidgets('my collection totals the member pieces and switches to a list', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('GET', '/api/v1/collectibles', [
        Fixtures.collectible(ownerId: 1),
        Fixtures.collectible(id: 2, name: 'Charizard Holo Base Set', category: 'TCG & Cartas', value: 2310, ownerId: 1),
        Fixtures.collectible(id: 3, name: 'Reloj Omega Seamaster 1968', category: 'Relojería Vintage', value: 640),
      ]);
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    app.container.read(routerProvider).go(Routes.myCollection);
    await settle(tester, 14);
    expect(find.text('S/ 3.730'), findsOneWidget);
    expect(find.text('Reloj Omega Seamaster 1968'), findsNothing);
    await tester.tap(find.byTooltip('Ver en lista'));
    await settle(tester, 4);
    expect(find.text('Charizard Holo Base Set'), findsOneWidget);
  });

  testWidgets('categories open a category page with its pieces', (tester) async {
    final app = await pumpApp(tester);
    unawaited(app.container.read(routerProvider).push(Routes.categories));
    await settle(tester);
    expect(find.text('Categorías'), findsWidgets);
    await tester.tap(find.text('Relojería Vintage'));
    await settle(tester);
    expect(find.text('Reloj Omega Seamaster 1968'), findsOneWidget);
    expect(find.text('Charizard Holo Base Set'), findsNothing);
  });

  testWidgets('help search opens the matching answer and leads to the guides', (tester) async {
    final app = await pumpApp(tester);
    unawaited(app.container.read(routerProvider).push(Routes.help));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'supera');
    await settle(tester, 4);
    expect(find.textContaining('Puedes volver a pujar'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await settle(tester, 4);
    await tester.ensureVisible(find.text('Cómo funciona'));
    await settle(tester, 4);
    await tester.tap(find.text('Cómo funciona'));
    await settle(tester);
    expect(find.text('Toma la foto'), findsOneWidget);
    await tester.tap(find.text('Pujar'));
    await settle(tester, 6);
    expect(find.text('Haz tu oferta'), findsOneWidget);
  });

  testWidgets('trending ranks the most valuable pieces first and switches boards', (tester) async {
    final app = await pumpApp(tester);
    unawaited(app.container.read(routerProvider).push(Routes.trending));
    await settle(tester);
    final charizard = tester.getTopLeft(find.text('Charizard Holo Base Set'));
    final omega = tester.getTopLeft(find.text('Reloj Omega Seamaster 1968'));
    expect(charizard.dy, lessThan(omega.dy), reason: 'S/ 2310 ranks above S/ 640');
    await tester.tap(find.text('Más pujadas'));
    await settle(tester, 6);
    expect(find.text('Lego Millennium Falcon 75192'), findsOneWidget);
  });

  testWidgets('protected route redirects to login and back after signing in', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('POST', '/api/v1/auth/login', {
        'token': fakeJwt(),
        'userId': 1,
        'username': 'collector_prime',
        'email': 'diego@collectioneer.art',
        'name': 'Diego Collector',
      });
    final app = await pumpApp(tester, backend: backend);
    app.container.read(routerProvider).go(Routes.insights);
    await settle(tester);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);

    await tester.tap(find.text('Iniciar sesión').last);
    await settle(tester, 3);
    expect(find.text('Campo obligatorio.'), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).at(0), 'collector_prime');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Iniciar sesión').last);
    await settle(tester);
    expect(app.store.token, isNotNull, reason: 'token persisted to secure storage');
    expect(app.container.read(routerProvider).state.matchedLocation, Routes.insights);
  });

  testWidgets('wrong credentials show a clear message', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('POST', '/api/v1/auth/login', {
        'detail': 'Credenciales inválidas.',
        'errorCode': 'AUTHENTICATION_FAILED',
      }, status: 401);
    final app = await pumpApp(tester, backend: backend);
    app.container.read(routerProvider).go(Routes.login);
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'x');
    await tester.enterText(find.byType(TextFormField).at(1), 'y');
    await tester.tap(find.text('Iniciar sesión').last);
    await settle(tester);
    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('a 401 on an authenticated call signs the user out', (tester) async {
    final backend = Fixtures.standardBackend();
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    expect(app.container.read(currentUserProvider), isNotNull);
    backend.json('GET', '/api/v1/communities/user/1', {'detail': 'expired'}, status: 401);
    app.container.read(routerProvider).go(Routes.profile);
    await settle(tester);
    expect(app.container.read(currentUserProvider), isNull);
    expect(app.store.token, isNull);
  });

  testWidgets('theme and language change live and persist', (tester) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go(Routes.appearance);
    await settle(tester);
    await tester.tap(find.text('Oscuro'));
    await settle(tester, 4);
    expect(Theme.of(tester.element(find.text('Apariencia'))).brightness, Brightness.dark);

    await tester.tap(find.text('English'));
    await settle(tester, 4);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('scan tab asks guests to sign in instead of uploading', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Escanear'));
    await settle(tester);
    expect(find.text('Inicia sesión para escanear'), findsOneWidget);
  });

  testWidgets('scan opens the in-app camera, which offers other ways in when there is no camera', (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      overrides: [availableCamerasProvider.overrideWithValue(() async => const [])],
    );
    await tester.tap(find.byTooltip('Escanear'));
    await settle(tester);
    await tester.tap(find.text('Abrir cámara'));
    await settle(tester);
    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.text('Cámara no disponible'), findsOneWidget);
    expect(find.text('Usar cámara del sistema'), findsOneWidget);
  });

  group('scan result', () {
    Future<void> showResult(WidgetTester tester, Map<String, Object?> json) async {
      final app = await pumpApp(tester, signedIn: true);
      final controller = app.container.read(scanControllerProvider.notifier);
      // Inject a finished analysis as the controller would after a real call.
      controller.state = ScanState(
        stage: ScanStage.done,
        imagePath: '/tmp/x.jpg',
        result: RecognitionResult.fromJson(json),
      );
      app.container.read(routerProvider).go(Routes.scanResult);
      await settle(tester);
    }

    testWidgets('open auction match offers bidding, never a direct purchase', (tester) async {
      await showResult(tester, Fixtures.recognition());
      expect(find.text('Disponible en subasta'), findsOneWidget);
      expect(find.text('Ver subasta y pujar'), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);
    });

    testWidgets('ambiguous result requires choosing a match before continuing', (tester) async {
      await showResult(
        tester,
        Fixtures.recognition(status: 'requires_verification', action: 'review_matches', withAlternatives: true),
      );
      expect(find.text('Requiere verificación'), findsOneWidget);
      final continueButton = find.widgetWithText(FilledButton, 'Ver ficha');
      await tester.scrollUntilVisible(continueButton, 200, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      final alternative = find.text('Lego Falcon 7965');
      await tester.ensureVisible(alternative);
      await settle(tester, 2);
      await tester.tap(alternative);
      await settle(tester, 3);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    });

    testWidgets('not in catalogue proposes registering the object', (tester) async {
      final json = Fixtures.recognition(status: 'not_in_catalog', action: 'register_item')..['catalog_match'] = null;
      await showResult(tester, json);
      expect(find.text('No está en el catálogo'), findsOneWidget);
      expect(find.text('Registrar esta pieza'), findsOneWidget);
    });
  });

  group('Google sign-in', () {
    FakeBackend googleBackend({bool enabled = true}) => Fixtures.standardBackend()
      ..json('GET', '/api/v1/auth/oauth/providers', {'google': enabled, 'github': enabled})
      ..json('POST', '/api/v1/auth/oauth/exchange', {
        'token': fakeJwt(),
        'userId': 1,
        'username': 'collector_prime',
        'email': 'diego@collectioneer.art',
        'name': 'Diego Collector',
      });

    /// Answers like the backend redirect: echoes the flow id from the start URL.
    WebAuthenticator browser({String? flow, String? error}) => (url) async {
      final start = Uri.parse(url);
      expect(start.path, '/api/v1/auth/oauth/start/google');
      expect(start.queryParameters['client'], 'mobile');
      final params = error != null
          ? {'error': error}
          : {'ticket': 'A' * 43, 'flow': flow ?? start.queryParameters['flow']!};
      return Uri(scheme: 'collectionner', host: 'oauth', path: '/callback', queryParameters: params).toString();
    };

    testWidgets('exchanges the ticket and signs in', (tester) async {
      final backend = googleBackend();
      final app = await pumpApp(
        tester,
        backend: backend,
        overrides: [webAuthenticatorProvider.overrideWithValue(browser())],
      );
      app.container.read(routerProvider).go(Routes.insights);
      await settle(tester);
      await tester.tap(find.text('Continuar con Google'));
      await settle(tester);
      expect(app.store.token, isNotNull);
      expect(backend.requests.any((r) => r.path == '/api/v1/auth/oauth/exchange'), isTrue);
      expect(app.container.read(routerProvider).state.matchedLocation, Routes.insights);
    });

    testWidgets('rejects a callback for another flow', (tester) async {
      final backend = googleBackend();
      final app = await pumpApp(
        tester,
        backend: backend,
        overrides: [webAuthenticatorProvider.overrideWithValue(browser(flow: 'forged-flow'))],
      );
      app.container.read(routerProvider).go(Routes.login);
      await settle(tester);
      await tester.tap(find.text('Continuar con Google'));
      await settle(tester);
      expect(app.store.token, isNull);
      expect(backend.requests.any((r) => r.path == '/api/v1/auth/oauth/exchange'), isFalse);
      expect(find.text('No se pudo iniciar sesión con Google. Inténtalo de nuevo.'), findsOneWidget);
    });

    testWidgets('explains when the server has Google disabled', (tester) async {
      var opened = false;
      final app = await pumpApp(
        tester,
        backend: googleBackend(enabled: false),
        overrides: [
          webAuthenticatorProvider.overrideWithValue((url) async {
            opened = true;
            return '';
          }),
        ],
      );
      app.container.read(routerProvider).go(Routes.login);
      await settle(tester);
      await tester.tap(find.text('Continuar con Google'));
      await settle(tester);
      expect(opened, isFalse);
      expect(find.text('El inicio con Google aún no está activado en el servidor.'), findsOneWidget);
    });
  });

  testWidgets('first launch shows the introduction once', (tester) async {
    final app = await pumpApp(tester, prefs: {'pref.onboarded': false});
    expect(find.text('Tu colección en un solo lugar'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await settle(tester, 6);
    expect(find.text('Subastas en vivo'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await settle(tester, 6);
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    expect(find.text('¿Qué coleccionamos hoy?'), findsOneWidget);
    expect(app.container.read(onboardedProvider), isTrue);
  });

  testWidgets('saving a piece puts it in favourites and survives as a preference', (tester) async {
    final app = await pumpApp(tester);
    app.container.read(routerProvider).go(Routes.catalog);
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Guardar en favoritos').first);
    await settle(tester, 8);
    expect(app.container.read(favoritesProvider), hasLength(1));
    unawaited(app.container.read(routerProvider).push(Routes.favorites));
    await settle(tester);
    expect(find.byType(CollectibleCard), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pref.favorites'), hasLength(1));
  });

  testWidgets('global search finds pieces and remembers the term', (tester) async {
    final app = await pumpApp(tester);
    unawaited(app.container.read(routerProvider).push(Routes.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'omega');
    await settle(tester, 6);
    expect(find.text('Reloj Omega Seamaster 1968'), findsOneWidget);
    await tester.tap(find.text('Reloj Omega Seamaster 1968'));
    await settle(tester);
    expect(app.container.read(recentSearchesProvider), ['omega']);
  });

  testWidgets('collection insights total and split the member pieces', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('GET', '/api/v1/collectibles', [
        Fixtures.collectible(ownerId: 1),
        Fixtures.collectible(id: 2, name: 'Charizard Holo Base Set', category: 'TCG & Cartas', value: 2310, ownerId: 1),
        Fixtures.collectible(id: 3, name: 'Reloj Omega Seamaster 1968', category: 'Relojería Vintage', value: 640),
      ]);
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    app.container.read(routerProvider).go(Routes.insights);
    await settle(tester, 14);
    expect(find.text('S/ 3.730'), findsOneWidget, reason: 'only the member pieces count');
    expect(find.text('62 %'), findsOneWidget);
    expect(find.text('Reloj Omega Seamaster 1968'), findsNothing);
  });
}
