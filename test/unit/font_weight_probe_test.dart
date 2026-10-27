import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the bundled variable fonts: FontWeight must reach the `wght` axis,
/// otherwise every weight in the theme would render as Regular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (family, file) in [('Archivo', 'Archivo-Variable.ttf'), ('Fraunces', 'Fraunces-Variable.ttf')]) {
    test('$family variable font honours FontWeight', () async {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      final loader = FontLoader('${family}Probe')..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      double width(FontWeight weight) {
        final painter = TextPainter(
          text: TextSpan(
            text: 'Coleccionables 2026',
            style: TextStyle(fontFamily: '${family}Probe', fontSize: 40, fontWeight: weight),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return painter.width;
      }

      expect(width(FontWeight.w800), greaterThan(width(FontWeight.w400) + 4));
    });
  }
}
