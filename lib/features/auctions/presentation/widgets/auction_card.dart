import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/kit.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/auction_models.dart';

/// An auction as a row card: photo on the left, then the piece, the current
/// bid in serif and a single line with bids and the time left.
class AuctionCard extends StatelessWidget {
  const AuctionCard({super.key, required this.auction, required this.onTap, this.trailing});
  final Auction auction;
  final VoidCallback onTap;

  /// Optional control at the top-right (e.g. follow).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final live = auction.isLive(DateTime.now());
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.sm),
      semanticLabel:
          '${auction.collectibleName ?? l10n.lotNumber(auction.id)}, ${l10n.currentBid} ${context.money(auction.currentPrice)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: SizedBox.square(
                dimension: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: brand.surfaceMuted, child: CollectibleImage(auction.artwork, cacheWidth: 220)),
                    if (!live) const ColoredBox(color: Color(0x59000000)),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: live ? LivePill(label: l10n.liveLabel) : Tag(l10n.closedLabel, onPhoto: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          auction.collectibleName ?? l10n.lotNumber(auction.id),
                          style: context.text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(live ? l10n.currentBid : l10n.finalPrice, style: context.text.bodySmall),
                  PriceText(auction.currentPrice, style: context.text.titleLarge),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xxs,
                    children: [
                      Tag(l10n.bidsCount(auction.bidCount), icon: AppIcons.handCoins, color: brand.muted),
                      if (live)
                        Countdown(
                          deadline: auction.deadline,
                          builder: (context, left) => Tag(
                            formatRemaining(left),
                            icon: AppIcons.timer,
                            color: left.inHours < 24 ? brand.live : brand.ink,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuctionCardSkeleton extends StatelessWidget {
  const AuctionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const AppCard(
    padding: EdgeInsets.all(Space.sm),
    child: Row(
      children: [
        Skeleton(width: 104, height: 104, radius: Radii.md),
        SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 14),
              SizedBox(height: Space.sm),
              Skeleton(width: 70, height: 10),
              SizedBox(height: Space.xs),
              Skeleton(width: 110, height: 18),
              SizedBox(height: Space.sm),
              Skeleton(width: 140, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}
