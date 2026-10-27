import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/demo/demo_backend.dart';
import '../core/network/api_client.dart';
import '../core/network/repositories.dart';
import '../core/storage/secure_session_store.dart';
import '../features/auth/application/session_controller.dart';
import 'config/app_config.dart';
import 'preferences.dart';

final secureSessionStoreProvider = Provider<SecureSessionStore>((ref) => SecureSessionStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    dio: AppConfig.demoMode
        ? (Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))..httpClientAdapter = DemoBackend())
        : null,
    readToken: () => ref.read(sessionProvider).value?.token,
    readLanguage: () => resolveLanguageCode(ref.read(localeProvider)),
    onUnauthorized: () => ref.read(sessionProvider.notifier).expire(),
  );
});

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final catalogRepositoryProvider = Provider((ref) => CatalogRepository(ref.watch(apiClientProvider)));
final auctionRepositoryProvider = Provider((ref) => AuctionRepository(ref.watch(apiClientProvider)));
final communityRepositoryProvider = Provider((ref) => CommunityRepository(ref.watch(apiClientProvider)));
final recognitionRepositoryProvider = Provider((ref) => RecognitionRepository(ref.watch(apiClientProvider)));
