import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/kit.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/ui.dart';
import '../../../favorites/favorites.dart';
import '../../domain/catalog_models.dart';

/// A piece as the catalogue shows it (21st.dev "Product Card", deltacomponents):
/// the photo in a soft rounded well with the heart on its corner, then name,
/// category and price. No frame around the text, so grids stay airy.
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
    final brand = context.brand;
    final l10n = context.l10n;
    final meta = [?item.category, if (item.eraYear != null) '${item.eraYear}'].join(' · ');
    // The heart sits over the photo's corner, outside the card's own tap
    // target and excluded semantics so it stays a separate control.
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Semantics(
            button: true,
            label: '${item.name}, ${context.money(item.value)}',
            excludeSemantics: true,
            child: TapScale(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // In fixed-height slots (grid cells, rails) the photo takes
                    // the space the text leaves; elsewhere it is square.
                    final well = DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        boxShadow: brand.cardShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            HeroMode(
                              enabled: hero,
                              child: Hero(
                                tag: 'collectible-${item.id}',
                                child: ColoredBox(
                                  color: brand.surfaceMuted,
                                  child: CollectibleImage(item.artwork, cacheWidth: 360),
                                ),
                              ),
                            ),
                            if (item.auctionId != null)
                              Positioned(
                                left: Space.xs,
                                bottom: Space.xs,
                                child: LivePill(label: l10n.inAuction),
                              ),
                          ],
                        ),
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (constraints.hasBoundedHeight)
                          Expanded(child: well)
                        else
                          AspectRatio(aspectRatio: 1, child: well),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, Space.sm, 4, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: context.text.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (meta.isNotEmpty)
                                Text(meta, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(child: PriceText(item.value, style: context.text.titleMedium)),
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
          ),
          Positioned(
            top: Space.xs,
            right: Space.xs,
            child: FavoriteButton(id: item.id, size: 36),
          ),
        ],
      ),
    );
  }
}

/// Height of the text block under the photo for the current text scale.
double collectibleCardTextHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0) * 94 + 16;

class CollectibleCardSkeleton extends StatelessWidget {
  const CollectibleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: Skeleton(radius: Radii.lg)),
      SizedBox(height: Space.sm),
      Skeleton(height: 14),
      SizedBox(height: Space.xs),
      Skeleton(width: 70, height: 12),
      SizedBox(height: Space.xs),
      Skeleton(width: 90, height: 16),
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

/// Grid delegate for piece cards: square photo plus a text block that grows
/// with the user's font scale.
SliverGridDelegate pieceGridDelegate(BuildContext context, double width) {
  final columns = gridColumnsFor(width);
  final cellWidth = (width - Space.md * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: Space.lg,
    crossAxisSpacing: Space.md,
    mainAxisExtent: cellWidth + collectibleCardTextHeight(context),
  );
}
