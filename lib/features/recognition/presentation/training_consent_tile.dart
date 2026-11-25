import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/ui.dart';
import '../application/training_consent.dart';

/// Opt-in switch for keeping scan photos and corrections as training data.
/// Shown next to the analyse button and in Settings, both bound to the same
/// preference. Turning it off deletes on the server what was kept.
class TrainingConsentTile extends ConsumerStatefulWidget {
  const TrainingConsentTile({super.key});

  @override
  ConsumerState<TrainingConsentTile> createState() => _TrainingConsentTileState();
}

class _TrainingConsentTileState extends ConsumerState<TrainingConsentTile> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A withdrawal that failed earlier (offline, server down) is retried here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(trainingConsentProvider.notifier).retryQuietly();
    });
  }

  Future<void> _toggle(bool value) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final deleted = await ref.read(trainingConsentProvider.notifier).set(value);
      if (mounted && deleted != null) showToast(context, l10n.trainingDeletionDone(deleted.photos));
    } on Object {
      if (mounted) showToast(context, value ? l10n.trainingDeletionBeforeEnable : l10n.trainingDeletionFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final consent = ref.watch(trainingConsentProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          value: consent,
          onChanged: _busy ? null : _toggle,
          secondary: const Icon(Icons.school_outlined),
          title: Text(l10n.trainingConsentTitle),
          subtitle: Text(l10n.trainingConsentBody, style: context.text.bodySmall?.copyWith(color: brand.muted)),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: Space.xl + Space.lg),
            child: TextButton.icon(
              onPressed: () => showTrainingPrivacySheet(context),
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(l10n.trainingConsentLearnMore),
            ),
          ),
        ),
      ],
    );
  }
}

/// What training consent means, in plain words: what is kept, why, where,
/// for how long and how to withdraw it.
Future<void> showTrainingPrivacySheet(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final brand = context.brand;
      final paragraphs = [
        (Icons.photo_camera_outlined, l10n.trainingPrivacyWhat),
        (Icons.insights_outlined, l10n.trainingPrivacyWhy),
        (Icons.lock_outline, l10n.trainingPrivacyWhere),
        (Icons.schedule_outlined, l10n.trainingPrivacyRetention),
        (Icons.delete_outline, l10n.trainingPrivacyWithdraw),
        (Icons.visibility_off_outlined, l10n.trainingPrivacyTip),
      ];
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.trainingPrivacyTitle, style: context.text.titleLarge),
              const SizedBox(height: Space.lg),
              for (final (icon, text) in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20, color: brand.muted),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(text, style: context.text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
