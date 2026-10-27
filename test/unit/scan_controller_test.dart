import 'dart:io';

import 'package:collectionner/app/preferences.dart';
import 'package:collectionner/app/providers.dart';
import 'package:collectionner/core/media/image_pipeline.dart';
import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/core/network/api_exception.dart';
import 'package:collectionner/features/recognition/application/scan_controller.dart';
import 'package:collectionner/features/recognition/domain/recognition_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late String photo;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('scan_test');
    final image = img.Image(width: 3000, height: 2000);
    img.fill(image, color: img.ColorRgb8(166, 59, 29));
    photo = '${temp.path}/photo.jpg';
    File(photo).writeAsBytesSync(img.encodeJpg(image));
  });

  tearDownAll(() => temp.delete(recursive: true));

  Future<(ProviderContainer, FakeBackend)> build() async {
    SharedPreferences.setMockInitialValues({});
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
    return (container, backend);
  }

  test('image pipeline downsizes and re-encodes as JPEG under the upload budget', () async {
    final bytes = await prepareJpeg(photo, quarterTurns: 1);
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, 1067, reason: 'rotated 90° then long side capped at 1600');
    expect(decoded.height, 1600);
  });

  test('pipeline rejects files that are not images', () async {
    final bogus = '${temp.path}/bogus.jpg';
    File(bogus).writeAsStringSync('not an image');
    await expectLater(
      prepareJpeg(bogus),
      throwsA(isA<ImageProcessingException>().having((e) => e.reason, 'reason', ImageProcessingFailure.unreadable)),
    );
  });

  test('nothing is uploaded until analyze is called; success yields a result', () async {
    final (container, backend) = await build();
    backend.json('POST', '/api/v1/recognition/analyze', Fixtures.recognition());
    final controller = container.read(scanControllerProvider.notifier);

    controller.usePhoto(photo);
    expect(container.read(scanControllerProvider).stage, ScanStage.preview);
    expect(backend.requests, isEmpty);

    await controller.analyze();
    final state = container.read(scanControllerProvider);
    expect(state.stage, ScanStage.done);
    expect(state.result!.purchaseStatus, PurchaseStatus.available);
    final request = backend.requests.single;
    expect(request.data, isA<FormData>());
    expect(request.headers['Idempotency-Key'], isA<String>());
  });

  test('retrying the same photo reuses the idempotency key; a new photo gets a new one', () async {
    final (container, backend) = await build();
    backend.json('POST', '/api/v1/recognition/analyze', {
      'detail': 'busy',
      'errorCode': 'AI_PROVIDER_BUSY',
    }, status: 503);
    final controller = container.read(scanControllerProvider.notifier);
    controller.usePhoto(photo);
    await controller.analyze();
    expect(container.read(scanControllerProvider).stage, ScanStage.failed);
    expect((container.read(scanControllerProvider).error! as ApiException).kind, ApiErrorKind.unavailable);
    await controller.analyze();
    final keys = backend.requests.map((r) => r.headers['Idempotency-Key']).toList();
    expect(keys[0], keys[1]);
    controller.replacePhoto(photo);
    await controller.analyze();
    expect(backend.requests.last.headers['Idempotency-Key'], isNot(keys[0]));
  });

  test('rate limit and auth errors surface as typed failures', () async {
    final (container, backend) = await build();
    backend.on(
      'POST',
      '/api/v1/recognition/analyze',
      (_) => const FakeReply(429, {'errorCode': 'RATE_LIMIT_EXCEEDED'}, {'retry-after': '60'}),
    );
    final controller = container.read(scanControllerProvider.notifier)..usePhoto(photo);
    await controller.analyze();
    final error = container.read(scanControllerProvider).error! as ApiException;
    expect(error.kind, ApiErrorKind.rateLimited);
    expect(error.retryAfter, const Duration(seconds: 60));
  });

  test('offline device reports a network error and keeps the photo for retry', () async {
    final (container, backend) = await build();
    backend.offline = true;
    final controller = container.read(scanControllerProvider.notifier)..usePhoto(photo);
    await controller.analyze();
    final state = container.read(scanControllerProvider);
    expect((state.error! as ApiException).kind, ApiErrorKind.network);
    expect(state.imagePath, photo);
  });

  test('reset clears the flow', () async {
    final (container, _) = await build();
    final controller = container.read(scanControllerProvider.notifier)
      ..usePhoto(photo)
      ..rotate()
      ..reset();
    expect(container.read(scanControllerProvider).imagePath, isNull);
    expect(controller, isNotNull);
  });
}
