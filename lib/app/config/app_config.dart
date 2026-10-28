/// Build-time configuration. Pass values with `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
///
/// No secret belongs here: everything compiled into the app can be extracted
/// from the binary. AI provider keys live only on the backend.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Reached through `adb reverse tcp:8080 tcp:8080` during local testing.
    defaultValue: 'http://127.0.0.1:8080',
  );

  /// Build with `--dart-define=DEMO_MODE=true` to run on the bundled sample
  /// data (no server). Nothing in the UI says so: the app looks and behaves
  /// as it does against the live service.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Gemini analysis can legitimately take longer than a catalogue read.
  static const Duration recognitionTimeout = Duration(seconds: 60);

  /// Upload budget after on-device downscaling; the backend accepts 5 MB.
  static const int maxUploadBytes = 4 * 1024 * 1024;

  static bool get isLoopback {
    final host = Uri.parse(apiBaseUrl).host;
    return host == '127.0.0.1' || host == 'localhost' || host == '10.0.2.2';
  }
}
