import 'package:collectionner/app/theme/app_theme.dart';
import 'package:collectionner/core/widgets/collectible_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app bundle that does not carry the file asked for, and says so the way the real one does.
class _MissingAssets extends CachingAssetBundle {
  final asked = <String>[];

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    throw FlutterError('Unable to load asset: "$key".');
  }
}

/// A bundle that carries one small drawing under every name.
class _OneDrawing extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 4"><rect width="4" height="4"/></svg>'.codeUnits,
    ),
  );
}

Widget _shown(AssetBundle bundle, String path) => MaterialApp(
  theme: AppTheme.light(),
  home: DefaultAssetBundle(
    bundle: bundle,
    child: Center(child: SizedBox.square(dimension: 80, child: CollectibleImage(path))),
  ),
);

/// The server may name an image this version of the app does not carry.
void main() {
  testWidgets('a drawing the app carries is shown', (tester) async {
    await tester.pumpWidget(_shown(_OneDrawing(), '/assets/collectibles/cards/pokemon-card.svg'));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  for (final path in [
    // What the server gives a community created without a picture.
    '/assets/categories/collectibles-index.svg',
    '/assets/categories/not-bundled.webp',
  ]) {
    testWidgets('an image the app does not carry shows the placeholder: $path', (tester) async {
      final bundle = _MissingAssets();

      await tester.pumpWidget(_shown(bundle, path));
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(bundle.asked, isNotEmpty, reason: 'the app tried to read the file');
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });
  }
}
