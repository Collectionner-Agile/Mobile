import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/pressable.dart';
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
    final brand = context.brand;
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        semanticLabel: '${item.name}, ${context.money(item.value)}',
        child: Card(
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // In fixed-height slots (grid cells, horizontal rails) the photo
                // takes whatever the text leaves; otherwise it is square.
                final bounded = constraints.hasBoundedHeight;
                final image = Stack(
                  fit: StackFit.expand,
                  children: [
                    HeroMode(
                      enabled: hero,
                      child: Hero(
                        tag: 'collectible-${item.id}',
                        child: ColoredBox(
                          color: brand.surface,
                          child: CollectibleImage(item.coverUrl, cacheWidth: 360),
                        ),
                      ),
                    ),
                    if (item.auctionId != null)
                      Positioned(
                        left: Space.xs,
                        top: Space.xs,
                        child: InfoChip(label: context.l10n.inAuction, icon: Icons.gavel, color: brand.rustStrong),
                      ),
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bounded) Expanded(child: image) else AspectRatio(aspectRatio: 1, child: image),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.category != null) Kicker(item.category!.toUpperCase(), color: brand.muted),
                          const SizedBox(height: 2),
                          Text(item.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: Space.xs),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.money(item.value),
                                  style: context.text.labelLarge?.copyWith(color: brand.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.reviewCount > 0) ...[
                                Icon(Icons.star_rounded, size: 15, color: brand.rust),
                                const SizedBox(width: 2),
                                Text(
                                  item.rating.toStringAsFixed(1),
                                  style: context.text.labelMedium?.copyWith(color: brand.muted),
                                ),
                              ],
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
    );
  }
}

/// Height of the text block under the photo for the current text scale.
double collectibleCardTextHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0) * 104 + 8;

class CollectibleCardSkeleton extends StatelessWidget {
  const CollectibleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Skeleton(radius: 0)),
        Padding(
          padding: EdgeInsets.all(Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 60, height: 10),
              SizedBox(height: Space.xs),
              Skeleton(height: 14),
              SizedBox(height: Space.xs),
              Skeleton(width: 80, height: 14),
            ],
          ),
        ),
      ],
    ),
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
