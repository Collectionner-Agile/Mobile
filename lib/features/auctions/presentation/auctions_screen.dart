import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/account_button.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/auction_providers.dart';
import '../application/watchlist.dart';
import '../domain/auction_models.dart';
import 'widgets/auction_card.dart';

class AuctionsScreen extends ConsumerStatefulWidget {
  const AuctionsScreen({super.key});

  @override
  ConsumerState<AuctionsScreen> createState() => _AuctionsScreenState();
}

class _AuctionsScreenState extends ConsumerState<AuctionsScreen> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auctions = ref.watch(auctionsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(auctionsProvider);
          await ref.read(auctionsProvider.future).catchError((Object _) => <Auction>[]);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: Space.gutter,
              title: Text(l10n.auctionsTitle),
              actions: [
                IconButton(
                  tooltip: l10n.watchlistTitle,
                  onPressed: () => context.push(Routes.watchlist),
                  icon: Badge(
                    isLabelVisible: ref.watch(watchedAuctionsProvider).isNotEmpty,
                    backgroundColor: context.brand.live,
                    label: Text('${ref.watch(watchedAuctionsProvider).length}'),
                    child: const Icon(Icons.notifications_active_outlined),
                  ),
                ),
                const AccountButton(),
                const SizedBox(width: Space.xxs),
              ],
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.auctionsIntro, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          FilterChip(
                            label: Text(l10n.auctionsShowClosed),
                            selected: _showClosed,
                            onSelected: (value) => setState(() => _showClosed = value),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                            label: Text(l10n.calendarShort),
                            onPressed: () => context.push(Routes.auctionCalendar),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.emoji_events_outlined, size: 18),
                            label: Text(l10n.resultsTitle),
                            onPressed: () => context.push(Routes.auctionResults),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.gavel_outlined, size: 18),
                            label: Text(l10n.myBidsTitle),
                            onPressed: () => context.push(Routes.myBids),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...switch (auctions) {
              AsyncValue(:final value?) => () {
                final now = DateTime.now();
                final items = _showClosed ? value : value.where((a) => a.isLive(now)).toList();
                if (items.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(message: l10n.auctionsEmpty, icon: Icons.gavel_outlined),
                    ),
                  ];
                }
                return [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                      itemBuilder: (context, index) => Reveal(
                        index: index,
                        child: ContentWidth(
                          child: AuctionCard(
                            auction: items[index],
                            onTap: () => context.go(Routes.auction(items[index].id)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              }(),
              AsyncValue(:final error?) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(error: error, onRetry: () => ref.invalidate(auctionsProvider)),
                ),
              ],
              _ => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverList.separated(
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (_, _) => const AuctionCardSkeleton(),
                  ),
                ),
              ],
            },
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
          ],
        ),
      ),
    );
  }
}
