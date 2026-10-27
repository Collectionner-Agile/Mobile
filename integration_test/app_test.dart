// End-to-end flow against a real backend. Run on a device with the Spring
// backend started locally (`./mvnw spring-boot:run -Dspring-boot.run.profiles=dev`)
// and the port forwarded: `adb reverse tcp:8080 tcp:8080`, then
// `flutter test integration_test -d <device>`.
//
// Credentials are the development seed account documented in backend/README.md.
import 'package:collectionner/app/router/app_router.dart';
import 'package:collectionner/features/catalog/presentation/widgets/collectible_card.dart';
import 'package:collectionner/features/communities/presentation/widgets/community_tile.dart';
import 'package:collectionner/features/profile/presentation/insights_screen.dart';
import 'package:collectionner/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _username = String.fromEnvironment('E2E_USERNAME', defaultValue: 'collector_prime');
const _password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'secret123');

Future<void> pumpFor(WidgetTester tester, [Duration duration = const Duration(seconds: 3)]) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real backend: browse, sign in, profile, preferences, scan gate', (tester) async {
    await app.main();
    await pumpFor(tester);
    final router = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider);

    // Catalogue comes from the API (dev seed has six collectibles).
    router.go(Routes.catalog);
    await waitFor(tester, find.byType(CollectibleCard));
    await tester.tap(find.byType(CollectibleCard).first);
    await pumpFor(tester);

    // Auctions and communities.
    router.go(Routes.auctions);
    await pumpFor(tester);
    router.go(Routes.communities);
    await waitFor(tester, find.byType(CommunityTile));

    // Sign in with the seed account and land on a protected screen.
    router.go(Routes.insights);
    await waitFor(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField).at(0), _username);
    await tester.enterText(find.byType(TextFormField).at(1), _password);
    await tester.tap(find.byType(FilledButton).last);
    await waitFor(tester, find.byType(InsightsScreen));

    // Preferences apply live.
    router.go(Routes.settings);
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('English'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.tap(find.byIcon(Icons.brightness_auto_outlined));
    await pumpFor(tester, const Duration(seconds: 1));

    // Scan tab is reachable when signed in; analysis availability is reported by the server.
    router.go(Routes.scan);
    await pumpFor(tester);
    expect(find.byIcon(Icons.photo_camera_outlined), findsWidgets);
  });
}
