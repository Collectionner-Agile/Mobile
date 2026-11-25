import 'package:collectionner/app/preferences.dart';
import 'package:collectionner/app/providers.dart';
import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/core/network/api_exception.dart';
import 'package:collectionner/features/recognition/application/scan_history.dart';
import 'package:collectionner/features/recognition/application/training_consent.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, FakeBackend, SharedPreferences)> build({Map<String, Object> initialPrefs = const {}}) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureSessionStoreProvider.overrideWithValue(MemorySessionStore()),
        apiClientProvider.overrideWithValue(
          ApiClient(
            dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080'))..httpClientAdapter = backend,
            readToken: () => 'token',
            readLanguage: () => 'es',
            onUnauthorized: () {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container, backend, prefs);
  }

  const consentKey = TrainingConsentController.key;
  const pendingKey = TrainingConsentController.pendingDeletionKey;
  const deletePath = '/api/v1/recognition/training-data';

  group('training consent', () {
    test('turning it off deletes what the server kept', () async {
      final (container, backend, prefs) = await build(initialPrefs: {consentKey: true});
      backend.json('DELETE', deletePath, {'deleted_photos': 3, 'deleted_feedback': 1});

      final deleted = await container.read(trainingConsentProvider.notifier).set(false);

      expect(deleted?.photos, 3);
      expect(container.read(trainingConsentProvider), isFalse);
      expect(prefs.getBool(pendingKey), isFalse);
      expect(backend.requests.single.method, 'DELETE');
    });

    test('turning it on, or off when it was already off, calls nothing', () async {
      final (container, backend, _) = await build();
      await container.read(trainingConsentProvider.notifier).set(false);
      await container.read(trainingConsentProvider.notifier).set(true);
      expect(backend.requests, isEmpty);
      expect(container.read(trainingConsentProvider), isTrue);
    });

    test('a failed deletion stays pending, consent stays off, and a retry sends it', () async {
      final (container, backend, prefs) = await build(initialPrefs: {consentKey: true});
      backend.json('DELETE', deletePath, {'title': 'down'}, status: 503);
      final controller = container.read(trainingConsentProvider.notifier);

      await expectLater(controller.set(false), throwsA(isA<ApiException>()));
      expect(container.read(trainingConsentProvider), isFalse, reason: 'future scans stop sending consent at once');
      expect(prefs.getBool(pendingKey), isTrue);

      backend.json('DELETE', deletePath, {'deleted_photos': 1, 'deleted_feedback': 0});
      await controller.retryQuietly();
      expect(prefs.getBool(pendingKey), isFalse);
    });

    test('consent cannot come back on while a withdrawal is still pending', () async {
      final (container, backend, _) = await build(initialPrefs: {consentKey: false, pendingKey: true});
      backend.json('DELETE', deletePath, {'title': 'down'}, status: 503);

      await expectLater(container.read(trainingConsentProvider.notifier).set(true), throwsA(isA<ApiException>()));
      expect(container.read(trainingConsentProvider), isFalse);
    });
  });

  group('scan history sync', () {
    Map<String, Object?> item(String id, String at, {String? name}) => {
      'analysis_id': id,
      'detected': true,
      'product_name': name ?? 'Pieza $id',
      'category': 'consola',
      'purchase_status': 'not_in_catalog',
      'analyzed_at': at,
      'training_consent': false,
      'photo_kept': false,
    };

    test('adds analyses the server remembers, newest first, without duplicates or removed ones', () async {
      final (container, backend, _) = await build();
      backend.json('GET', '/api/v1/recognition/history', {
        'items': [
          item('s3', '2026-11-20T10:00:00Z'),
          item('s2', '2026-11-19T10:00:00Z'),
          item('s1', '2026-11-18T10:00:00Z'),
        ],
        'page': 0,
        'size': 30,
        'has_more': false,
      });
      final history = container.read(scanHistoryProvider.notifier);

      await history.syncFromServer();
      expect(container.read(scanHistoryProvider).map((r) => r.id), ['s3', 's2', 's1']);
      expect(container.read(scanHistoryProvider).first.fromServer, isTrue);

      await history.remove('s2');
      await history.syncFromServer();
      expect(container.read(scanHistoryProvider).map((r) => r.id), ['s3', 's1'], reason: 'removed here stays removed');
    });

    test('clearing the history keeps older server entries away', () async {
      final (container, backend, _) = await build();
      backend.json('GET', '/api/v1/recognition/history', {
        'items': [item('old', '2020-01-01T00:00:00Z')],
        'page': 0,
        'size': 30,
        'has_more': false,
      });
      final history = container.read(scanHistoryProvider.notifier);
      await history.clear();
      await history.syncFromServer();
      expect(container.read(scanHistoryProvider), isEmpty);
    });
  });
}
