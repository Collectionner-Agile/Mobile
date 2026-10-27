import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_models.dart';

/// The member's archive in figures: declared value, how it splits across
/// categories (animated bars) and the most valuable pieces.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final catalogue = ref.watch(collectiblesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.insightsTitle)),
      body: AsyncSwitch(
        value: catalogue,
        onRetry: () => ref.invalidate(collectiblesProvider),
        data: (all) {
          final mine = all.where((item) => user != null && item.ownerId == user.id).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          if (mine.isEmpty) {
            return ListView(
              children: [
                EmptyState(
                  message: l10n.noItemsYet,
                  icon: Icons.insights_rounded,
                  actionLabel: l10n.publishItem,
                  onAction: () => context.push(Routes.publishCollectible),
                ),
              ],
            );
          }
          final total = mine.fold<double>(0, (sum, item) => sum + item.value);
          final rated = mine.where((item) => item.reviewCount > 0).toList();
          final rating = rated.isEmpty ? null : rated.fold<double>(0, (s, i) => s + i.rating) / rated.length;
          final byCategory = <String, double>{};
          for (final item in mine) {
            final key = item.category ?? l10n.uncategorized;
            byCategory[key] = (byCategory[key] ?? 0) + item.value;
          }
          final split = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              Space.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Reveal(
                child: _TotalCard(total: total, pieces: mine.length, rating: rating),
              ),
              const SizedBox(height: Space.xl),
              Text(l10n.valueByCategory, style: context.text.titleLarge),
              const SizedBox(height: Space.md),
              for (final (index, entry) in split.indexed)
                Reveal(
                  index: index + 1,
                  child: _CategoryBar(label: entry.key, value: entry.value, share: entry.value / total, index: index),
                ),
              const SizedBox(height: Space.xl),
              Text(l10n.mostValuable, style: context.text.titleLarge),
              const SizedBox(height: Space.sm),
              for (final (index, item) in mine.take(3).indexed)
                Reveal(
                  index: index + split.length + 1,
                  child: _RankRow(rank: index + 1, item: item),
                ),
              const SizedBox(height: Space.md),
              Text(l10n.declaredValueNote, style: context.text.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.pieces, required this.rating});
  final double total;
  final int pieces;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final fg = heroForeground(context);
    return HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.archiveValue, style: context.text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.75))),
          const SizedBox(height: Space.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedNumber(
              value: total,
              format: (v) => context.money(v.roundToDouble()),
              style: Fonts.figures(context.text.displayMedium).copyWith(color: fg),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              _Pill(icon: Icons.inventory_2_outlined, label: l10n.piecesCount(pieces)),
              if (rating != null) ...[
                const SizedBox(width: Space.xs),
                _Pill(icon: Icons.star_rounded, label: rating!.toStringAsFixed(1), tint: brand.gold),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.tint});
  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final fg = heroForeground(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tint ?? fg),
          const SizedBox(width: 5),
          Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Category share as a bar that grows into place.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.label, required this.value, required this.share, required this.index});
  final String label;
  final double value;
  final double share;
  final int index;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final color = index == 0 ? brand.ink : Color.lerp(brand.ink, brand.muted, (index / 4).clamp(0, 1))!;
    return Semantics(
      label: '$label, ${context.money(value)}, ${(share * 100).round()} %',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(context.money(value), style: Fonts.figures(context.text.titleSmall)),
                  const SizedBox(width: Space.xs),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(share * 100).round()} %',
                      textAlign: TextAlign.end,
                      style: Fonts.figures(context.text.bodySmall),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: brand.surfaceMuted)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: reduce ? share : 0, end: share),
                        duration: Duration(milliseconds: 900 + index * 120),
                        curve: Motion.enter,
                        builder: (context, factor, _) => FractionallySizedBox(
                          widthFactor: factor.clamp(0, 1),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.pill)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.item});
  final int rank;
  final Collectible item;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return InkWell(
      onTap: () => context.go(Routes.collectible(item.id)),
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('$rank', style: Fonts.figures(context.text.headlineSmall).copyWith(color: brand.muted)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox.square(dimension: 56, child: CollectibleImage(item.artwork, cacheWidth: 112)),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (item.category != null)
                    Text(item.category!, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Text(context.money(item.value), style: Fonts.figures(context.text.titleMedium)),
          ],
        ),
      ),
    );
  }
}
