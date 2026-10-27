import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../app/config/app_config.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/jwt.dart';
import '../domain/user.dart';

class Session {
  const Session({required this.token, required this.user});
  final String token;
  final AppUser user;

  Session withUser(AppUser user) => Session(token: token, user: user);
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// Opens [url] in a browser tab and resolves with the redirect to
/// `collectionner://oauth/...`. Overridden in tests.
typedef WebAuthenticator = Future<String> Function(String url);

final webAuthenticatorProvider = Provider<WebAuthenticator>(
  (ref) =>
      (url) => FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: 'collectionner'),
);

/// External sign-in providers the server can complete; empty when offline.
final oauthProvidersProvider = FutureProvider<Set<String>>(
  (ref) => ref.read(authRepositoryProvider).oauthProviders().catchError((Object _) => const <String>{}),
);

/// Raised when the browser flow ends without a usable ticket.
class OAuthSignInException implements Exception {
  const OAuthSignInException({this.cancelled = false});
  final bool cancelled;
}

/// Set when a stored session is rejected by the server, so the UI can tell the
/// user why they were signed out. Cleared once shown.
final sessionExpiredNoticeProvider = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final store = ref.read(secureSessionStoreProvider);
    final stored = await store.read();
    if (stored == null) return null;
    if (isJwtExpired(stored.token)) {
      await store.clear();
      return null;
    }
    final cachedUser = stored.user == null ? null : AppUser.fromJson(stored.user!);
    try {
      final user = await ref.read(authRepositoryProvider).me(bearer: stored.token);
      await store.write(stored.token, user.toJson());
      return Session(token: stored.token, user: user);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized || error.kind == ApiErrorKind.forbidden) {
        await store.clear();
        ref.read(sessionExpiredNoticeProvider.notifier).set(true);
        return null;
      }
      // Offline start: keep the still-valid token and the cached profile.
      return cachedUser == null ? null : Session(token: stored.token, user: cachedUser);
    }
  }

  Future<void> login(String username, String password) async {
    final auth = ref.read(authRepositoryProvider);
    final result = await auth.login(username.trim(), password);
    final user = await auth.me(bearer: result.token).catchError((Object _) => result.user);
    await _persist(Session(token: result.token, user: user));
  }

  /// Google sign-in through the backend's OAuth flow: a random `flow` id ties
  /// the browser round trip to this request, and the one-time ticket in the
  /// callback is exchanged for the same JWT a password login returns.
  Future<void> signInWithGoogle() async {
    final flow = _randomUuid();
    final start = Uri.parse(AppConfig.apiBaseUrl)
        .replace(path: '/api/v1/auth/oauth/start/google', queryParameters: {'flow': flow, 'client': 'mobile'});
    final String result;
    try {
      result = await ref.read(webAuthenticatorProvider)(start.toString());
    } on Exception {
      throw const OAuthSignInException(cancelled: true);
    }
    final callback = Uri.parse(result);
    final ticket = callback.queryParameters['ticket'];
    if (callback.host != 'oauth' ||
        callback.queryParameters['error'] != null ||
        callback.queryParameters['flow'] != flow ||
        ticket == null) {
      throw const OAuthSignInException();
    }
    final auth = ref.read(authRepositoryProvider);
    final session = await auth.exchangeOAuthTicket(ticket);
    final user = await auth.me(bearer: session.token).catchError((Object _) => session.user);
    await _persist(Session(token: session.token, user: user));
  }

  static String _randomUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String name,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    final result = await auth.register(
      username: username.trim(),
      email: email.trim(),
      password: password,
      name: name.trim(),
    );
    final user = await auth.me(bearer: result.token).catchError((Object _) => result.user);
    await _persist(Session(token: result.token, user: user));
  }

  Future<void> refreshProfile() async {
    final current = state.value;
    if (current == null) return;
    final user = await ref.read(authRepositoryProvider).me();
    await _persist(current.withUser(user));
  }

  Future<void> replaceUser(AppUser user) async {
    final current = state.value;
    if (current == null) return;
    await _persist(current.withUser(user));
  }

  Future<void> logout() async {
    if (state.value != null) {
      // Revoke server-side; local sign-out proceeds even if offline.
      await ref.read(authRepositoryProvider).logout().catchError((Object _) {});
    }
    await _clear();
  }

  /// Local sign-out after the server already invalidated the account/token.
  Future<void> signOutLocally() => _clear();

  /// Called by the API client on any 401 for an authenticated request.
  void expire() {
    if (state.value == null) return;
    ref.read(sessionExpiredNoticeProvider.notifier).set(true);
    unawaited(_clear());
  }

  Future<void> _persist(Session session) async {
    await ref.read(secureSessionStoreProvider).write(session.token, session.user.toJson());
    state = AsyncData(session);
  }

  Future<void> _clear() async {
    state = const AsyncData(null);
    await ref.read(secureSessionStoreProvider).clear();
  }
}

/// Convenience: the signed-in user or null.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(sessionProvider).value?.user);
