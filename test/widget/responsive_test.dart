import 'package:collectionner/app/router/app_router.dart';
import 'package:collectionner/features/recognition/application/scan_controller.dart';
import 'package:collectionner/features/recognition/domain/recognition_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// Renders every main route across phone sizes, landscape, text scales and
/// both themes/languages. Any RenderFlex overflow or build error fails the test.
void main() {
  const sizes = {
    'small 320x568': Size(320, 568),
    'S26 Ultra 412x915': Size(412, 915),
    'landscape 915x412': Size(915, 412),
  };
  const routes = [
    Routes.onboarding,
    Routes.favorites,
    Routes.activity,
    Routes.search,
    Routes.insights,
    Routes.home,
    Routes.catalog,
    Routes.auctions,
    Routes.communities,
    Routes.scan,
    Routes.scanResult,
    Routes.settings,
    Routes.profile,
    Routes.publishCollectible,
    Routes.login,
    Routes.register,
    '/catalog/item/1',
    '/auctions/7',
    '/communities/1',
    // Full-screen route opened over a tab whose stack holds grid + detail.
    Routes.scanResult,
    Routes.notifications,
    Routes.watchlist,
    Routes.myBids,
    Routes.myCollection,
    Routes.auctionCalendar,
    Routes.auctionResults,
    Routes.categories,
    '/categories/Relojer%C3%ADa%20Vintage',
    Routes.help,
    Routes.howItWorks,
    Routes.appearance,
    Routes.about,
    Routes.trending,
    Routes.achievements,
    '/collectors/1',
    Routes.compare,
    Routes.scanHistory,
    '/share/1',
  ];

  for (final entry in sizes.entries) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final (language, theme) in [('es', 'light'), ('en', 'dark')]) {
        testWidgets('${entry.key} · text ${scale}x · $language/$theme: no overflow', (tester) async {
          final app = await pumpApp(
            tester,
            signedIn: true,
            size: entry.value,
            textScale: scale,
            prefs: {'pref.locale': language, 'pref.themeMode': theme},
          );
          app.container.read(scanControllerProvider.notifier).state = ScanState(
            stage: ScanStage.done,
            result: RecognitionResult.fromJson(Fixtures.recognition(withAlternatives: true)),
          );
          final router = app.container.read(routerProvider);
          for (final route in routes) {
            router.go(route);
            await settle(tester, 6);
            final error = tester.takeException();
            expect(error, isNull, reason: 'route $route threw $error');
          }
        });
      }
    }
  }

  testWidgets('keyboard open on login keeps the form scrollable without overflow', (tester) async {
    final app = await pumpApp(tester, size: const Size(360, 640));
    app.container.read(routerProvider).go(Routes.login);
    await settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.showKeyboard(find.byType(TextFormField).first);
    await settle(tester, 3);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Iniciar sesión'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
  });
}
