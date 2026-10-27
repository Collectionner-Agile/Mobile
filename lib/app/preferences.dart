import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the instance loaded before the first frame, so
/// theme and language are known synchronously (no flash of the wrong theme).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'pref.themeMode';

  @override
  ThemeMode build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere((mode) => mode.name == stored, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

const supportedLanguageCodes = ['es', 'en'];

/// `null` means "follow the device language".
final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'pref.locale';

  @override
  Locale? build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_key);
    return supportedLanguageCodes.contains(stored) ? Locale(stored!) : null;
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}

/// Language actually in effect, used for API Accept-Language and formatting.
String resolveLanguageCode(Locale? chosen) {
  if (chosen != null) return chosen.languageCode;
  final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return supportedLanguageCodes.contains(device) ? device : 'es';
}
