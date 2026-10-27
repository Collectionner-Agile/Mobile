import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/media/artwork.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/slab.dart';
import '../../../../core/widgets/ui.dart';
import '../../application/auction_providers.dart';
import '../../domain/auction_models.dart';

class AuctionCard extends StatelessWidget {
  const AuctionCard({super.key, required this.auction, required this.onTap});
  final Auction auction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${auction.collectibleName ?? l10n.lotNumber(auction.id)}, ${l10n.currentBid} ${context.money(auction.currentPrice)}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: brand.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Slab(
                    imageUrl: artworkFor(name: auction.collectibleName ?? '', url: auction.collectibleImage),
                    lot: auction.id,
                    aspectRatio: 1,
                    compact: true,
                    cacheWidth: 224,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.xxs, right: Space.xxs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auction.collectibleName ?? '—',
                          style: context.text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          context.money(auction.currentPrice),
                          style: Fonts.figures(context.text.titleLarge),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.bidsCount(auction.bidCount),
                          style: context.text.bodySmall?.copyWith(color: brand.muted),
                        ),
                        const SizedBox(height: Space.xs),
                        Countdown(auction: auction, showBar: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Remaining time in tabular figures, red while the auction is live, with an
/// optional bar showing how much of the bidding window is left. Driven by a
/// shared one-second clock.
class Countdown extends ConsumerWidget {
  const Countdown({super.key, required this.auction, this.showBar = false, this.color});
  final Auction auction;
  final bool showBar;

  /// Overrides the text color (e.g. on an ink panel).
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final brand = context.brand;
    final l10n = context.l10n;
    final style = Fonts.figures(Fonts.label(context.text.labelLarge, weight: 680));
    if (!auction.isLive(now)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_outlined, size: 15, color: color ?? brand.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(l10n.ended, style: style.copyWith(color: color ?? brand.muted)),
          ),
        ],
      );
    }
    final remaining = auction.deadline!.difference(now);
    final fraction = auction.remainingFraction(now);
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: brand.live, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            l10n.endsIn(formatRemaining(remaining)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: color ?? brand.live),
          ),
        ),
      ],
    );
    if (!showBar || fraction == null) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        const SizedBox(height: 6),
        TimeLeftBar(remaining: fraction),
      ],
    );
  }
}

class AuctionCardSkeleton extends StatelessWidget {
  const AuctionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Space.xs),
    child: Row(
      children: [
        Skeleton(width: 112, height: 136, radius: Radii.md),
        SizedBox(width: Space.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 14),
              SizedBox(height: Space.xs),
              Skeleton(width: 120, height: 18),
              SizedBox(height: Space.xs),
              Skeleton(width: 90, height: 10),
            ],
          ),
        ),
      ],
    ),
  );
}
