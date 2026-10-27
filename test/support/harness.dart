import 'package:collectionner/app/app.dart';
import 'package:collectionner/app/preferences.dart';
import 'package:collectionner/app/providers.dart';
import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/core/storage/secure_session_store.dart';
import 'package:collectionner/features/auth/application/session_controller.dart';
import 'package:collectionner/features/launch/launch_scene.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

class MemorySessionStore extends SecureSessionStore {
  MemorySessionStore([this._token, this._user]);
  String? _token;
  Map<String, dynamic>? _user;

  @override
  Future<({String token, Map<String, dynamic>? user})?> read() async =>
      _token == null ? null : (token: _token!, user: _user);

  @override
  Future<void> write(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
  }

  @override
  Future<void> clear() async {
    _token = null;
    _user = null;
  }

  String? get token => _token;
}

class TestApp {
  TestApp(this.backend, this.store, this.container);
  final FakeBackend backend;
  final MemorySessionStore store;
  final ProviderContainer container;
}

/// Pumps the real app with a fake HTTP backend and in-memory storage.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  FakeBackend? backend,
  bool signedIn = false,
  Size size = const Size(412, 915),
  double textScale = 1,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  bool launchScene = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // The test binding reports en_US; most assertions use the primary (Spanish) copy.
  SharedPreferences.setMockInitialValues({'pref.locale': 'es', 'pref.onboarded': true, ...prefs});
  final preferences = await SharedPreferences.getInstance();
  final fake = backend ?? Fixtures.standardBackend();
  final store = signedIn ? MemorySessionStore(fakeJwt(), Fixtures.user()) : MemorySessionStore();

  // ProviderScope (not an external container) so the container, and every
  // timer its providers own, is disposed together with the widget tree.
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        launchSceneEnabledProvider.overrideWithValue(launchScene),
        secureSessionStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWith((ref) {
          final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080'))..httpClientAdapter = fake;
          return ApiClient(
            dio: dio,
            readToken: () => ref.read(sessionProvider).value?.token,
            readLanguage: () => resolveLanguageCode(ref.read(localeProvider)),
            onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
          );
        }),
        ...overrides,
      ],
      child: const CollectionnerApp(),
    ),
  );
  final container = ProviderScope.containerOf(tester.element(find.byType(CollectionnerApp)));
  await settle(tester);
  return TestApp(fake, store, container);
}

/// Pumps enough frames for async loads without waiting on infinite animations
/// (skeleton pulses, countdown ticks).
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
