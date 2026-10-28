import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/auction_providers.dart';
import '../application/watchlist.dart';
import '../domain/auction_models.dart';
import 'widgets/auction_card.dart';

/// Auctions you follow: the live ones first, closest to closing first, then
/// the finished ones with their final price.
class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final watched = ref.watch(watchedAuctionsProvider);
    final auctions = ref.watch(auctionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.watchlistTitle)),
      body: AsyncSwitch(
        value: auctions,
        onRetry: () => ref.invalidate(auctionsProvider),
        data: (all) {
          final now = DateTime.now();
          final items = all.where((a) => watched.contains(a.id)).toList()
            ..sort((a, b) {
              final liveA = a.isLive(now), liveB = b.isLive(now);
              if (liveA != liveB) return liveA ? -1 : 1;
              return (a.deadline ?? now).compareTo(b.deadline ?? now);
            });
          if (items.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  message: l10n.watchlistEmpty,
                  body: l10n.watchlistEmptyBody,
                  actionLabel: l10n.navAuctions,
                  onAction: () => context.go(Routes.auctions),
                ),
              ),
            );
          }
          final live = items.where((a) => a.isLive(now)).length;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(auctionsProvider);
              await ref.read(auctionsProvider.future).catchError((Object _) => <Auction>[]);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xs,
                Space.gutter,
                Space.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ContentWidth(
                  child: Reveal(
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: StatTile(value: '${items.length}', label: l10n.watchlistFollowing),
                          ),
                          Expanded(
                            child: StatTile(value: '$live', label: l10n.liveLabel, color: context.brand.live),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                for (final (index, auction) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: ContentWidth(
                      child: Reveal(
                        index: index + 1,
                        child: AuctionCard(
                          auction: auction,
                          trailing: FollowAuctionButton(auctionId: auction.id, size: 36),
                          onTap: () => context.push(Routes.auction(auction.id)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
