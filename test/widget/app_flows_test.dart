import 'package:collectionner/app/router/app_router.dart';
import 'package:collectionner/features/auth/application/session_controller.dart';
import 'package:collectionner/features/recognition/application/scan_controller.dart';
import 'package:collectionner/features/recognition/domain/recognition_models.dart';
import 'package:collectionner/features/recognition/presentation/scan_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  testWidgets('home loads catalogue, auctions and communities from the API', (tester) async {
    await pumpApp(tester);
    expect(find.text('Objetos con historia. Registro con criterio.'), findsOneWidget);
    // Live auctions and latest entries sit below the hero; lists build lazily.
    await tester.scrollUntilVisible(find.text('Últimos ingresos'), 300, scrollable: find.byType(Scrollable).first);
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
    await tester.tap(find.text('Catálogo').last);
    await settle(tester);
    expect(find.text('4 piezas'.toUpperCase()), findsOneWidget);

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
    await tester.tap(find.text('Catálogo').last);
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
    app.container.read(routerProvider).go(Routes.profile);
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
    expect(find.text('Mi archivo'), findsOneWidget);
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
    app.container.read(routerProvider).go(Routes.settings);
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
    await tester.tap(find.text('Escanear').last);
    await settle(tester);
    expect(find.text('Inicia sesión para escanear'), findsOneWidget);
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
}
