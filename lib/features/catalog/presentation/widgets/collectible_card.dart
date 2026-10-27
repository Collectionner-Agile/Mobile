import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/slab.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/catalog_models.dart';

class CollectibleCard extends StatelessWidget {
  const CollectibleCard({super.key, required this.item, required this.onTap, this.width, this.hero = false});
  final Collectible item;
  final VoidCallback onTap;
  final double? width;

  /// Only one on-screen list may own the shared-element tag for an item; tabs
  /// stay alive in an IndexedStack, so the catalogue grid is that owner.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        semanticLabel: '${item.name}, ${context.money(item.value)}',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // In fixed-height slots (grid cells, rails) the slab takes the
              // space the text leaves; elsewhere its image well is square.
              final slab = HeroMode(
                enabled: hero,
                child: Slab(
                  imageUrl: item.artwork,
                  lot: item.id,
                  category: item.category,
                  heroTag: 'collectible-${item.id}',
                  aspectRatio: constraints.hasBoundedHeight ? null : 1,
                  compact: (width ?? constraints.maxWidth) < 200,
                  overlay: item.auctionId != null ? LiveBadge(label: context.l10n.inAuction) : null,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.hasBoundedHeight) Expanded(child: slab) else slab,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, Space.xs, 2, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: Space.xxs),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.money(item.value),
                                style: Fonts.figures(context.text.titleMedium)
                                    .copyWith(fontVariations: Fonts.axes(width: 100, weight: 720)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.reviewCount > 0) RatingPill(rating: item.rating),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Height of the slab label plus the text block under the slab, for the
/// current text scale.
double collectibleCardTextHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0) * 104 + 8;

class CollectibleCardSkeleton extends StatelessWidget {
  const CollectibleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: Skeleton(radius: Radii.md)),
      SizedBox(height: Space.xs),
      Skeleton(height: 14),
      SizedBox(height: Space.xs),
      Skeleton(width: 80, height: 14),
    ],
  );
}

/// Grid column count from available width (2 on phones, more when wider).
int gridColumnsFor(double width) => width >= 1100
    ? 5
    : width >= 840
    ? 4
    : width >= 560
    ? 3
    : 2;
