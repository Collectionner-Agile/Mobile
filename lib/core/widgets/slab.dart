import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'collectible_image.dart';
import 'ui.dart';

/// The signature element: an object shown the way a graded collectible is
/// cased. A label strip (lot number and category) sits above the image well
/// inside one hairline frame.
class Slab extends StatelessWidget {
  const Slab({
    super.key,
    required this.imageUrl,
    required this.lot,
    this.category,
    this.overlay,
    this.heroTag,
    this.aspectRatio,
    this.compact = false,
    this.semanticLabel,
    this.cacheWidth = 360,
  });

  final String? imageUrl;
  final int lot;
  final String? category;

  /// Widget pinned to the image's top-right corner (e.g. a live badge).
  final Widget? overlay;
  final String? heroTag;

  /// When null the image well fills the height the parent gives it.
  final double? aspectRatio;
  final bool compact;
  final String? semanticLabel;
  final double cacheWidth;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    Widget image = ColoredBox(
      color: brand.surfaceMuted,
      child: CollectibleImage(imageUrl, cacheWidth: cacheWidth, semanticLabel: semanticLabel),
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);
    final well = Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (overlay != null) Positioned(right: Space.xs, top: Space.xs, child: overlay!),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: brand.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md - 1),
        child: Column(
          mainAxisSize: aspectRatio == null ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SlabLabel(lot: lot, category: category, compact: compact),
            if (aspectRatio == null) Expanded(child: well) else AspectRatio(aspectRatio: aspectRatio!, child: well),
          ],
        ),
      ),
    );
  }
}

class SlabLabel extends StatelessWidget {
  const SlabLabel({super.key, required this.lot, this.category, this.compact = false});
  final int lot;
  final String? category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final style = Fonts.label(
      context.text.labelSmall,
      weight: 700,
    ).copyWith(color: brand.ink, fontSize: compact ? 10.5 : 11.5);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(bottom: BorderSide(color: brand.line)),
      ),
      // Two loose children with the slack between them: the lot number keeps
      // the left edge and the category the right, each truncating if needed.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              context.l10n.lotRef(lot.toString().padLeft(4, '0')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.figures(style),
            ),
          ),
          if (category != null) ...[
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                category!,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: brand.muted, fontVariations: Fonts.axes(width: 100, weight: 560)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lacquer-red marker for things that are live right now.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(color: brand.live, borderRadius: BorderRadius.circular(Radii.xs)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: brand.onLive, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.label(context.text.labelSmall, weight: 700).copyWith(color: brand.onLive),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin bar showing how much of an auction's window remains.
class TimeLeftBar extends StatelessWidget {
  const TimeLeftBar({super.key, required this.remaining});

  /// 0 (closed) to 1 (just opened).
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: LinearProgressIndicator(
        value: remaining.clamp(0, 1),
        minHeight: 3,
        color: brand.live,
        backgroundColor: brand.line,
      ),
    );
  }
}
