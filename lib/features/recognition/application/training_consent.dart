import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';

/// Whether the user lets the backend keep scan photos and corrections to train
/// recognition. Off until the user turns it on; sent with every analysis so the
/// server never stores a photo without it.
final trainingConsentProvider = NotifierProvider<TrainingConsentController, bool>(TrainingConsentController.new);

class TrainingConsentController extends Notifier<bool> {
  static const key = 'pref.recognitionTrainingConsent';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(key, value);
  }
}
