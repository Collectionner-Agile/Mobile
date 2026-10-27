import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final results = await Future.wait<Object?>([
    SharedPreferences.getInstance(),
    initializeDateFormatting('es_PE'),
    initializeDateFormatting('en_US'),
  ]);

  runApp(
    ProviderScope(
      // Failed requests surface an error state with a retry button instead of
      // being silently re-sent in the background.
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(results.first! as SharedPreferences)],
      child: const CollectionnerApp(),
    ),
  );
}
