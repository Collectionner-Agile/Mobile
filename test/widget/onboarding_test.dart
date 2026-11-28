import 'package:collectionner/app/router/app_router.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  for (final width in [384.0, 412.0]) {
    testWidgets('the button that moves on through the welcome is not cut off, ${width.round()} wide', (tester) async {
      final app = await pumpApp(tester, backend: Fixtures.standardBackend(), size: Size(width, 854));
      app.container.read(routerProvider).go(Routes.onboarding);
      await settle(tester);

      final label = tester.renderObject<RenderParagraph>(find.text('Siguiente'));

      // Narrower than the whole word needs means it is being shortened to "Sigui…".
      expect(label.size.width, greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity).floorToDouble()));
    });
  }
}
