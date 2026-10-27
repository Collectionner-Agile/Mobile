// Frame-timing scenario for profile builds on a real device:
//   adb reverse tcp:8080 tcp:8080
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_test.dart -d <device>
// Writes build/catalog_scroll.timeline_summary.json and build/navigation.timeline_summary.json.
import 'package:collectionner/app/router/app_router.dart';
import 'package:collectionner/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catalogue scroll and tab navigation frame timings', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 3));
    final router = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider);

    router.go(Routes.catalog);
    await pumpFor(tester, const Duration(seconds: 3));
    final list = find.byType(Scrollable).first;

    await binding.traceAction(() async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(list, const Offset(0, -900), 2500);
        await pumpFor(tester, const Duration(milliseconds: 900));
        await tester.fling(list, const Offset(0, 900), 2500);
        await pumpFor(tester, const Duration(milliseconds: 900));
      }
    }, reportKey: 'catalog_scroll');

    await binding.traceAction(() async {
      for (final route in [
        Routes.home,
        Routes.auctions,
        Routes.communities,
        Routes.catalog,
        '/catalog/item/1',
        Routes.scan,
      ]) {
        router.go(route);
        await pumpFor(tester, const Duration(milliseconds: 1200));
      }
    }, reportKey: 'navigation');
  });
}
