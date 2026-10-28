import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/auction_providers.dart';
import '../application/watchlist.dart';
import '../domain/auction_models.dart';
import 'widgets/auction_card.dart';

enum AuctionFilter { live, today, closed }

/// The Auctions tab: three plain segments (live, closing today, finished)
/// over one list of row cards.
class AuctionsScreen extends ConsumerStatefulWidget {
  const AuctionsScreen({super.key});

  @override
  ConsumerState<AuctionsScreen> createState() => _AuctionsScreenState();
}

class _AuctionsScreenState extends ConsumerState<AuctionsScreen> {
  AuctionFilter _filter = AuctionFilter.live;

  List<Auction> _apply(List<Auction> all) {
    final now = DateTime.now();
    return switch (_filter) {
      AuctionFilter.live => all.where((a) => a.isLive(now)).toList(),
      AuctionFilter.today =>
        all.where((a) => a.isLive(now) && a.deadline!.difference(now) <= const Duration(hours: 24)).toList(),
      AuctionFilter.closed =>
        all.where((a) => !a.isLive(now)).toList()..sort((a, b) => (b.deadline ?? now).compareTo(a.deadline ?? now)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auctions = ref.watch(auctionsProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(auctionsProvider);
          await ref.read(auctionsProvider.future).catchError((Object _) => <Auction>[]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: PageTitle(
                  title: l10n.auctionsTitle,
                  subtitle: l10n.auctionsIntro,
                  actions: [
                    CircleIconButton(
                      icon: AppIcons.bellRing,
                      tooltip: l10n.watchlistTitle,
                      badge: ref.watch(watchedAuctionsProvider).isNotEmpty,
                      onPressed: () => context.push(Routes.watchlist),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxs),
                  children: [
                    _Shortcut(
                      icon: AppIcons.calendarDays,
                      label: l10n.calendarShort,
                      onTap: () => context.push(Routes.auctionCalendar),
                    ),
                    _Shortcut(
                      icon: AppIcons.trophy,
                      label: l10n.resultsTitle,
                      onTap: () => context.push(Routes.auctionResults),
                    ),
                    _Shortcut(
                      icon: AppIcons.handCoins,
                      label: l10n.myBidsTitle,
                      onTap: () => context.push(Routes.myBids),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.md),
                child: ContentWidth(
                  child: SegmentedTabs(
                    labels: [l10n.liveLabel, l10n.closingToday, l10n.finishedLabel],
                    index: _filter.index,
                    onChanged: (index) => setState(() => _filter = AuctionFilter.values[index]),
                  ),
                ),
              ),
            ),
            ...switch (auctions) {
              AsyncValue(:final value?) => () {
                final items = _apply(value);
                if (items.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        message: _filter == AuctionFilter.closed ? l10n.noClosedAuctions : l10n.auctionsEmpty,
                        icon: AppIcons.gavel,
                      ),
                    ),
                  ];
                }
                return [
                  // A new window per filter replays the entrance when the
                  // segment changes.
                  RevealWindow(
                    key: ValueKey(_filter),
                    child: SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                        itemBuilder: (context, index) => Reveal(
                          key: ValueKey('${_filter.name}-${items[index].id}'),
                          index: index,
                          child: ContentWidth(
                            child: AuctionCard(
                              auction: items[index],
                              trailing: FollowAuctionButton(auctionId: items[index].id, size: 36),
                              onTap: () => context.go(Routes.auction(items[index].id)),
                            ),
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
            SliverToBoxAdapter(child: SizedBox(height: Space.xxl + bottom)),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.only(right: Space.xs),
      child: TapScale(
        child: Material(
          color: brand.surface,
          shape: StadiumBorder(side: BorderSide(color: brand.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: brand.gold),
                  const SizedBox(width: 6),
                  Text(label, style: context.text.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
