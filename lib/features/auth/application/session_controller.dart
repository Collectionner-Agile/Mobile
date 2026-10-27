import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
