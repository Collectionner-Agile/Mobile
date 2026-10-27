import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/media/artwork.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/pressable.dart';
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
      child: Card(
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: ColoredBox(
                      color: brand.surfaceMuted,
                      child: CollectibleImage(
                        artworkFor(name: auction.collectibleName ?? '', url: auction.collectibleImage),
                        cacheWidth: 104,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(l10n.lotNumber(auction.id), color: brand.muted),
                      const SizedBox(height: 2),
                      Text(
                        auction.collectibleName ?? '—',
                        style: context.text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.money(auction.currentPrice),
                            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '· ${l10n.bidsCount(auction.bidCount)}',
                            style: context.text.bodySmall?.copyWith(color: brand.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Countdown(auction: auction),
                    ],
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

/// Live remaining-time chip driven by a shared one-second clock.
class Countdown extends ConsumerWidget {
  const Countdown({super.key, required this.auction});
  final Auction auction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final brand = context.brand;
    final l10n = context.l10n;
    if (!auction.isLive(now)) {
      return InfoChip(label: l10n.ended, icon: Icons.lock_clock_outlined, color: brand.muted);
    }
    final remaining = auction.deadline!.difference(now);
    final urgent = remaining < const Duration(hours: 1);
    return InfoChip(
      label: l10n.endsIn(formatRemaining(remaining)),
      icon: Icons.schedule,
      color: urgent ? brand.danger : brand.success,
    );
  }
}

class AuctionCardSkeleton extends StatelessWidget {
  const AuctionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(Space.sm),
      child: Row(
        children: [
          Skeleton(width: 88, height: 88, radius: Radii.sm),
          SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 50, height: 10),
                SizedBox(height: Space.xs),
                Skeleton(height: 14),
                SizedBox(height: Space.xs),
                Skeleton(width: 120, height: 14),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
