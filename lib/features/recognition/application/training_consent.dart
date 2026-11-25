import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../app/providers.dart';
import '../domain/recognition_models.dart';

/// Whether the user lets the backend keep scan photos and corrections to train
/// recognition. Off until the user turns it on; sent with every analysis so the
/// server never stores a photo without it.
///
/// Turning it off also asks the server to delete what it kept. If that call
/// fails the request stays pending on the device and is retried, and the
/// switch cannot be turned back on until it succeeds: otherwise the late
/// deletion would also take photos the user consented to afterwards.
final trainingConsentProvider = NotifierProvider<TrainingConsentController, bool>(TrainingConsentController.new);

class TrainingConsentController extends Notifier<bool> {
  static const key = 'pref.recognitionTrainingConsent';
  static const pendingDeletionKey = 'pref.recognitionTrainingDeletionPending';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(key) ?? false;

  bool get deletionPending => ref.read(sharedPreferencesProvider).getBool(pendingDeletionKey) ?? false;

  /// Turns consent on or off. Turning it off returns what the server deleted;
  /// a failed deletion throws (an `ApiException`) and stays pending.
  Future<TrainingDataDeletion?> set(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (value) {
      // Finish any withdrawal first; a failure here keeps the switch off.
      if (deletionPending) await retryPendingDeletion();
      state = true;
      await prefs.setBool(key, true);
      return null;
    }
    final wasOn = state;
    // Future scans stop sending consent at once, whatever the server answers.
    state = false;
    await prefs.setBool(key, false);
    if (!wasOn && !deletionPending) return null;
    await prefs.setBool(pendingDeletionKey, true);
    return retryPendingDeletion();
  }

  /// Sends a pending withdrawal. Returns null when nothing was pending.
  Future<TrainingDataDeletion?> retryPendingDeletion() async {
    if (!deletionPending) return null;
    final deleted = await ref.read(recognitionRepositoryProvider).deleteTrainingData();
    await ref.read(sharedPreferencesProvider).setBool(pendingDeletionKey, false);
    return deleted;
  }

  /// Background retry (e.g. when a screen with the switch opens); errors stay pending.
  Future<void> retryQuietly() async {
    try {
      await retryPendingDeletion();
    } on Object {
      // Still pending; the next screen visit tries again.
    }
  }
}
