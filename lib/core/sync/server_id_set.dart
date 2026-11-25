import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../../app/providers.dart';
import '../../features/auth/application/session_controller.dart';

/// A set of ids saved on the phone (works signed out and offline) that follows
/// the account's list on the server once signed in: favorites and watchlist.
///
/// On sign-in the phone uploads what it has (`/sync`) and keeps the merged list.
/// Changes are applied locally first and sent in the background; a removal
/// that could not be sent is remembered and retried before the next sync, so
/// the server does not bring it back.
abstract class ServerIdSet extends Notifier<Set<int>> {
  /// `favorites` or `watchlist` (the server list name).
  String get listName;

  /// Preferences key of the local copy.
  String get prefsKey;

  String get _removedKey => '$prefsKey.removedPending';

  int? _syncedFor;

  @override
  Set<int> build() {
    ref.listen<int?>(currentUserProvider.select((user) => user?.id), (previous, next) {
      // After build: the state must exist before the sync reads it.
      if (next != null && next != _syncedFor) unawaited(Future<void>.microtask(syncNow));
    }, fireImmediately: true);
    return _read(prefsKey);
  }

  Set<int> _read(String key) =>
      (ref.read(sharedPreferencesProvider).getStringList(key) ?? const []).map(int.tryParse).whereType<int>().toSet();

  Future<void> _write(String key, Set<int> ids) =>
      ref.read(sharedPreferencesProvider).setStringList(key, [for (final id in ids) '$id']);

  Future<void> _save(Set<int> ids) async {
    state = ids;
    await _write(prefsKey, ids);
  }

  /// Adds or removes [id]; returns true when it is now in the set.
  Future<bool> toggle(int id) async {
    final adding = !state.contains(id);
    await _save(adding ? {...state, id} : ({...state}..remove(id)));
    if (ref.read(currentUserProvider) != null) unawaited(_send(id, adding));
    return adding;
  }

  Future<void> _send(int id, bool adding) async {
    final me = ref.read(meRepositoryProvider);
    try {
      if (adding) {
        await me.add(listName, id);
      } else {
        await me.remove(listName, id);
      }
    } catch (_) {
      // Additions are re-sent by the next sync; removals must be remembered.
      if (!adding) await _write(_removedKey, {..._read(_removedKey), id});
    }
  }

  /// Uploads the local list and adopts the server's merged list.
  Future<void> syncNow() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final me = ref.read(meRepositoryProvider);
    try {
      final pending = _read(_removedKey);
      for (final id in pending) {
        await me.remove(listName, id);
      }
      if (pending.isNotEmpty) await _write(_removedKey, const {});
      final merged = await me.sync(listName, state.difference(pending));
      _syncedFor = user.id;
      await _save(merged.toSet());
    } catch (_) {
      // Offline or server error: keep the local list and try again on the next sign-in or refresh.
    }
  }
}
