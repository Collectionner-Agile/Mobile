import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/ui.dart';
import '../application/training_consent.dart';

/// Opt-in switch for keeping scan photos and corrections as training data.
/// Shown next to the analyse button and in Settings, both bound to the same
/// preference.
class TrainingConsentTile extends ConsumerWidget {
  const TrainingConsentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final consent = ref.watch(trainingConsentProvider);
    return SwitchListTile(
      value: consent,
      onChanged: (value) => ref.read(trainingConsentProvider.notifier).set(value),
      secondary: const Icon(Icons.school_outlined),
      title: Text(l10n.trainingConsentTitle),
      subtitle: Text(l10n.trainingConsentBody, style: context.text.bodySmall?.copyWith(color: brand.muted)),
    );
  }
}
