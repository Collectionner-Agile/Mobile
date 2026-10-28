import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../application/auction_providers.dart';
import '../domain/auction_models.dart';

enum MyBidStatus { leading, outbid, won, lost }

/// One auction the user bid on, with where they stand.
class MyBid {
  const MyBid({required this.auction, required this.myBest, required this.status});
  final Auction auction;
  final double myBest;
  final MyBidStatus status;

  bool get active => status == MyBidStatus.leading || status == MyBidStatus.outbid;
}

/// Auctions the signed-in user has bid on, newest deadline first.
final myBidsProvider = Provider<AsyncValue<List<MyBid>>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(auctionsProvider).whenData((auctions) {
    if (user == null) return const [];
    final now = DateTime.now();
    final mine = <MyBid>[];
    for (final auction in auctions) {
      final bids = auction.bids.where((bid) => bid.bidderId == user.id).toList();
      if (bids.isEmpty) continue;
      final best = bids.map((bid) => bid.amount).reduce((a, b) => a > b ? a : b);
      final leading = auction.bids.isNotEmpty && auction.bids.first.bidderId == user.id;
      final live = auction.isLive(now);
      mine.add(
        MyBid(
          auction: auction,
          myBest: best,
          status: live
              ? (leading ? MyBidStatus.leading : MyBidStatus.outbid)
              : (leading ? MyBidStatus.won : MyBidStatus.lost),
        ),
      );
    }
    return mine..sort((a, b) => (a.auction.deadline ?? now).compareTo(b.auction.deadline ?? now));
  });
});

/// Where you stand in every auction you bid on: winning, outbid (with a
/// quick way back in), won or not.
class MyBidsScreen extends ConsumerStatefulWidget {
  const MyBidsScreen({super.key});

  @override
  ConsumerState<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends ConsumerState<MyBidsScreen> {
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final bids = ref.watch(myBidsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myBidsTitle)),
      body: AsyncSwitch(
        value: bids,
        onRetry: () => ref.invalidate(auctionsProvider),
        data: (all) {
          if (all.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.payments_outlined,
                  message: l10n.myBidsEmpty,
                  body: l10n.myBidsEmptyBody,
                  actionLabel: l10n.navAuctions,
                  onAction: () => context.go(Routes.auctions),
                ),
              ),
            );
          }
          final active = all.where((bid) => bid.active).toList();
          final finished = all.where((bid) => !bid.active).toList().reversed.toList();
          final shown = _finished ? finished : active;
          return ListView(
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
                          child: StatTile(value: '${active.length}', label: l10n.myBidsActive),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${all.where((b) => b.status == MyBidStatus.leading).length}',
                            label: l10n.myBidsLeading,
                            icon: Icons.trending_up_rounded,
                            color: brand.success,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: '${all.where((b) => b.status == MyBidStatus.won).length}',
                            label: l10n.myBidsWon,
                            icon: Icons.emoji_events_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              ContentWidth(
                child: SegmentedTabs(
                  labels: [l10n.myBidsActive, l10n.finishedLabel],
                  index: _finished ? 1 : 0,
                  onChanged: (index) => setState(() => _finished = index == 1),
                ),
              ),
              const SizedBox(height: Space.md),
              if (shown.isEmpty)
                EmptyState(
                  icon: _finished ? Icons.history_rounded : Icons.gavel_outlined,
                  message: _finished ? l10n.myBidsNoneFinished : l10n.myBidsNoneActive,
                )
              else
                for (final (index, bid) in shown.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: ContentWidth(
                      child: Reveal(
                        key: ValueKey('$_finished-${bid.auction.id}'),
                        index: index,
                        child: _MyBidCard(bid: bid),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _MyBidCard extends StatelessWidget {
  const _MyBidCard({required this.bid});
  final MyBid bid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final auction = bid.auction;
    final (label, color, icon) = switch (bid.status) {
      MyBidStatus.leading => (l10n.myBidLeading, brand.success, Icons.trending_up_rounded),
      MyBidStatus.outbid => (l10n.myBidOutbid, brand.live, Icons.warning_amber_rounded),
      MyBidStatus.won => (l10n.myBidWon, brand.gold, Icons.emoji_events_outlined),
      MyBidStatus.lost => (l10n.myBidLost, brand.muted, Icons.cancel_outlined),
    };
    return AppCard(
      onTap: () => context.push(Routes.auction(auction.id)),
      padding: const EdgeInsets.all(Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox.square(
                  dimension: 64,
                  child: ColoredBox(
                    color: brand.surfaceMuted,
                    child: CollectibleImage(auction.artwork, cacheWidth: 140),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(label, icon: icon, color: color),
                    const SizedBox(height: Space.xxs),
                    Text(
                      auction.collectibleName ?? l10n.lotNumber(auction.id),
                      style: context.text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _Figure(label: l10n.myBestBid, value: context.money(bid.myBest)),
              ),
              Expanded(
                child: _Figure(
                  label: bid.active ? l10n.currentBid : l10n.finalPrice,
                  value: context.money(auction.currentPrice),
                  emphasis: true,
                ),
              ),
            ],
          ),
          if (bid.status == MyBidStatus.outbid) ...[
            const SizedBox(height: Space.sm),
            BusyButton(
              label: l10n.bidAgain,
              icon: Icons.gavel_outlined,
              color: brand.live,
              onPressed: () => context.push(Routes.auction(auction.id)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Fonts.figures(emphasis ? Fonts.display(context.text.titleMedium, weight: 700) : context.text.titleSmall),
      ),
    ],
  );
}
