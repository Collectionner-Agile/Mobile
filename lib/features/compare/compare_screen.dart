import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../favorites/favorites.dart';

/// The two pieces being compared (ids), in the order they were picked.
final compareProvider = NotifierProvider<CompareController, List<int>>(CompareController.new);

class CompareController extends Notifier<List<int>> {
  @override
  List<int> build() => const [];

  /// Puts [id] in the comparison, replacing the oldest when two are there.
  void add(int id) {
    if (state.contains(id)) return;
    state = [...state, id].length > 2 ? [state.last, id] : [...state, id];
  }

  void replace(int slot, int id) {
    final next = [...state];
    if (slot < next.length) {
      next[slot] = id;
    } else {
      next.add(id);
    }
    state = next.toSet().toList();
  }

  void remove(int id) => state = [...state]..remove(id);
}

/// Outlined button that adds a piece to the comparison and opens it.
class CompareButton extends ConsumerWidget {
  const CompareButton({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BusyButton(
    label: context.l10n.compareAction,
    icon: Icons.compare_arrows_rounded,
    outlined: true,
    onPressed: () {
      ref.read(compareProvider.notifier).add(id);
      unawaited(context.push(Routes.compare));
    },
  );
}

/// Two pieces side by side: photos, names, then one row per fact with the
/// stronger value marked in gold, and a picker to change either side.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, int slot, List<Collectible> all, List<int> chosen) async {
    final favorites = ref.read(favoritesProvider);
    final options = all.where((piece) => !chosen.contains(piece.id)).toList()
      ..sort((a, b) {
        final favA = favorites.contains(a.id), favB = favorites.contains(b.id);
        if (favA != favB) return favA ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.sm),
              child: Text(context.l10n.comparePick, style: context.text.titleLarge),
            ),
            for (final piece in options)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: AppCard(
                  onTap: () => Navigator.of(context).pop(piece.id),
                  padding: const EdgeInsets.all(Space.xs),
                  shadow: false,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        child: SizedBox.square(dimension: 52, child: CollectibleImage(piece.artwork, cacheWidth: 110)),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          piece.name,
                          style: context.text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (favorites.contains(piece.id))
                        Icon(Icons.favorite_rounded, size: 16, color: context.brand.live),
                      const SizedBox(width: Space.xs),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      unawaited(HapticFeedback.selectionClick());
      ref.read(compareProvider.notifier).replace(slot, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chosen = ref.watch(compareProvider);
    final pieces = ref.watch(collectiblesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.compareTitle)),
      body: AsyncSwitch(
        value: pieces,
        onRetry: () => ref.invalidate(collectiblesProvider),
        data: (all) {
          final byId = {for (final piece in all) piece.id: piece};
          final selected = [for (final id in chosen) ?byId[id]];
          final left = selected.isNotEmpty ? selected[0] : null;
          final right = selected.length > 1 ? selected[1] : null;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              Space.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.compareSubtitle, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
                    const SizedBox(height: Space.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Slot(piece: left, onPick: () => _pick(context, ref, 0, all, chosen)),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: _Slot(piece: right, onPick: () => _pick(context, ref, 1, all, chosen)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    if (left != null && right != null)
                      Reveal(
                        child: _Table(left: left, right: right),
                      )
                    else
                      AppCard(
                        child: Row(
                          children: [
                            IconBadge(Icons.compare_arrows_rounded, color: context.brand.ink),
                            const SizedBox(width: Space.sm),
                            Expanded(child: Text(l10n.compareHint, style: context.text.bodyMedium)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.piece, required this.onPick});
  final Collectible? piece;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final piece = this.piece;
    if (piece == null) {
      return AppCard(
        onTap: onPick,
        padding: EdgeInsets.zero,
        // At least as tall as a square photo, taller when large text needs it.
        child: LayoutBuilder(
          builder: (context, box) => ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBadge(Icons.add_rounded, color: brand.ink, size: 48),
                  const SizedBox(height: Space.sm),
                  Text(l10n.comparePick, textAlign: TextAlign.center, style: context.text.labelLarge),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          onTap: () => context.push(Routes.collectible(piece.id)),
          padding: EdgeInsets.zero,
          child: AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(color: brand.surfaceMuted, child: CollectibleImage(piece.artwork, cacheWidth: 360)),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(piece.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        TextButton.icon(
          onPressed: onPick,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: brand.ink,
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: Text(l10n.compareChange),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.left, required this.right});
  final Collectible left;
  final Collectible right;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    // For each fact: the two values and which side (if any) is stronger.
    int? winner(num? a, num? b, {bool higher = true}) {
      if (a == null || b == null || a == b) return null;
      return (a > b) == higher ? 0 : 1;
    }

    final rows = [
      (
        Icons.monetization_on_outlined,
        l10n.declaredValue,
        context.money(left.value),
        context.money(right.value),
        winner(left.value, right.value),
      ),
      (
        Icons.event_outlined,
        l10n.year,
        left.eraYear?.toString() ?? '—',
        right.eraYear?.toString() ?? '—',
        winner(left.eraYear, right.eraYear, higher: false),
      ),
      (Icons.sell_outlined, l10n.category, left.category ?? '—', right.category ?? '—', null),
      (
        Icons.star_outline_rounded,
        l10n.compareRating,
        left.reviewCount == 0 ? '—' : left.rating.toStringAsFixed(1),
        right.reviewCount == 0 ? '—' : right.rating.toStringAsFixed(1),
        left.reviewCount == 0 || right.reviewCount == 0 ? null : winner(left.rating, right.rating),
      ),
      (
        Icons.forum_outlined,
        l10n.reviews,
        '${left.reviewCount}',
        '${right.reviewCount}',
        winner(left.reviewCount, right.reviewCount),
      ),
      (
        Icons.gavel_outlined,
        l10n.inAuction,
        left.auctionId == null ? l10n.no : l10n.yes,
        right.auctionId == null ? l10n.no : l10n.yes,
        null,
      ),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        children: [
          for (final (index, (icon, label, a, b, best)) in rows.indexed) ...[
            if (index > 0) Divider(height: 1, color: brand.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: brand.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: brand.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xxs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Value(text: a, best: best == 0),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: _Value(text: b, best: best == 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.text, required this.best});
  final String text;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            style: Fonts.figures(
              context.text.titleSmall,
            ).copyWith(color: best ? brand.success : brand.ink, fontWeight: best ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
        if (best) ...[const SizedBox(width: 4), Icon(Icons.verified_outlined, size: 14, color: brand.success)],
      ],
    );
  }
}
