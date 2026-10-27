import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auth/application/session_controller.dart';
import '../home/home_extras.dart';

enum _Scope { all, myBids, myAuctions }

/// Every bid across the auctions, newest first, with filters for the bids
/// the member placed and the bids received on their own lots.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _Scope _scope = _Scope.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final auctions = ref.watch(auctionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(auctionsProvider);
          await ref.read(auctionsProvider.future).catchError((Object _) => const <Never>[]);
        },
        child: AsyncSwitch(
          value: auctions,
          onRetry: () => ref.invalidate(auctionsProvider),
          data: (items) {
            final all = recentBids(items, limit: 200);
            final events = switch (_scope) {
              _Scope.all => all,
              _Scope.myBids => all.where((e) => user != null && e.bid.bidderId == user.id).toList(),
              _Scope.myAuctions => all.where((e) => user != null && e.auction.auctioneerId == user.id).toList(),
            };
            final total = events.fold<double>(0, (sum, e) => sum + e.bid.amount);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xs,
                Space.gutter,
                Space.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (scope, label) in [
                        (_Scope.all, l10n.filterAll),
                        (_Scope.myBids, l10n.myBids),
                        (_Scope.myAuctions, l10n.myAuctions),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _scope == scope,
                            onSelected: (_) => setState(() => _scope = scope),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: l10n.bidsLabel,
                        child: AnimatedNumber(
                          value: events.length.toDouble(),
                          format: (v) => v.round().toString(),
                          style: Fonts.figures(context.text.headlineMedium),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: _Figure(
                        label: l10n.amountBid,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: AnimatedNumber(
                            value: total,
                            format: (v) => context.money(v.roundToDouble()),
                            style: Fonts.figures(context.text.headlineMedium),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                if (events.isEmpty)
                  EmptyState(message: l10n.activityEmpty, icon: Icons.timeline_rounded)
                else
                  for (final (index, event) in events.indexed)
                    Reveal(
                      index: index,
                      child: _TimelineRow(
                        event: event,
                        first: index == 0,
                        last: index == events.length - 1,
                        mine: user != null && event.bid.bidderId == user.id,
                        onTap: () => context.go(Routes.auction(event.auction.id)),
                      ),
                    ),
                if (events.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Text(l10n.activityNote, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall?.copyWith(color: brand.muted)),
        ],
      ),
    );
  }
}

/// One bid on a vertical rail: dot (red for the member's own bids), photo,
/// who bid what on which lot, and when.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.first,
    required this.last,
    required this.mine,
    required this.onTap,
  });
  final BidEvent event;
  final bool first;
  final bool last;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    final rail = brand.line;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Expanded(child: Container(width: 2, color: first ? Colors.transparent : rail)),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mine ? brand.live : brand.surface,
                      border: Border.all(color: mine ? brand.live : brand.ink, width: 2),
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: last ? Colors.transparent : rail)),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: SizedBox.square(
                        dimension: 48,
                        child: CollectibleImage(
                          artworkFor(name: event.auction.collectibleName ?? '', url: event.auction.collectibleImage),
                          cacheWidth: 96,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.bidActivity(
                              mine ? l10n.you : (event.bid.bidderName ?? '—'),
                              context.money(event.bid.amount),
                            ),
                            style: context.text.titleSmall,
                          ),
                          Text(
                            event.auction.collectibleName ?? l10n.lotNumber(event.auction.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(color: brand.muted),
                          ),
                          Text(
                            timeAgo(context, event.bid.createdAt!),
                            style: context.text.labelMedium?.copyWith(color: brand.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
