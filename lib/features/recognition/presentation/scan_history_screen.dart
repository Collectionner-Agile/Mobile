import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auctions/application/bid_events.dart';
import '../application/scan_history.dart';
import '../domain/recognition_models.dart';

/// Past identifications kept on this phone: the thumbnail, what it was,
/// whether it can be bid on, and a way back to the piece or auction. Swipe
/// one away to forget it, or clear them all.
class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.scanHistoryClear,
      body: l10n.scanHistoryClearBody,
      confirmLabel: l10n.scanHistoryClear,
      destructive: true,
    );
    if (ok) await ref.read(scanHistoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(scanHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanHistoryTitle),
        actions: [
          if (history.isNotEmpty)
            CircleIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.scanHistoryClear,
              onPressed: () => _clear(context, ref),
            ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  message: l10n.scanHistoryEmpty,
                  body: l10n.scanHistoryEmptyBody,
                  actionLabel: l10n.openCamera,
                  onAction: () => context.go(Routes.scan),
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xs,
                Space.gutter,
                Space.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ContentWidth(child: Text(l10n.scanHistoryNote(history.length), style: context.text.bodySmall)),
                const SizedBox(height: Space.md),
                for (final (index, record) in history.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: ContentWidth(
                      child: Reveal(
                        index: index,
                        child: Dismissible(
                          key: ValueKey(record.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: Space.lg),
                            decoration: BoxDecoration(
                              color: context.brand.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(Radii.lg),
                            ),
                            child: Icon(Icons.delete_outline_rounded, color: context.brand.danger),
                          ),
                          onDismissed: (_) {
                            HapticFeedback.mediumImpact();
                            ref.read(scanHistoryProvider.notifier).remove(record.id);
                            showToast(context, l10n.scanHistoryRemoved, icon: Icons.delete_outline_rounded);
                          },
                          child: _RecordCard(record: record),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});
  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final (label, color, icon) = !record.detected
        ? (l10n.scanHistoryNotDetected, brand.muted, Icons.image_search_outlined)
        : switch (record.status) {
            PurchaseStatus.available => (l10n.statusAvailable, brand.live, Icons.gavel_outlined),
            PurchaseStatus.notInCatalog => (l10n.statusNotInCatalog, brand.info, Icons.add_photo_alternate_outlined),
            PurchaseStatus.unavailable => (l10n.statusUnavailable, brand.muted, Icons.cancel_outlined),
            PurchaseStatus.unsupportedProduct => (l10n.statusUnsupported, brand.muted, Icons.error_outline_rounded),
            PurchaseStatus.requiresVerification => (
              l10n.statusRequiresVerification,
              brand.warning,
              Icons.help_outline_rounded,
            ),
          };
    final route = record.auctionOpen && record.auctionId != null
        ? Routes.auction(record.auctionId!)
        : record.collectibleId != null
        ? Routes.collectible(record.collectibleId!)
        : null;
    return AppCard(
      onTap: route == null ? null : () => context.push(route),
      padding: const EdgeInsets.all(Space.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: SizedBox.square(
              dimension: 72,
              child: ColoredBox(
                color: brand.surfaceMuted,
                child: record.thumbnail == null
                    ? Icon(Icons.image_outlined, color: brand.muted)
                    : CollectibleImage(record.thumbnail, cacheWidth: 150),
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name ?? l10n.scanHistoryUnknown,
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.category != null)
                  Text(record.category!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Space.xxs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xxs,
                  children: [
                    Tag(label, icon: icon, color: color),
                    Tag(timeAgo(context, record.at), color: brand.muted),
                  ],
                ),
              ],
            ),
          ),
          if (route != null) Icon(Icons.chevron_right_rounded, color: brand.muted, size: 20),
        ],
      ),
    );
  }
}
