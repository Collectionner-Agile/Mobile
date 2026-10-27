import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/account_button.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/domain/auction_models.dart';
import '../auctions/presentation/widgets/auction_card.dart';
import '../auth/application/session_controller.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import '../communities/application/community_providers.dart';
import '../communities/presentation/widgets/community_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(collectiblesProvider)
      ..invalidate(auctionsProvider)
      ..invalidate(communitiesProvider);
    try {
      await Future.wait<Object>([
        ref.read(collectiblesProvider.future),
        ref.read(auctionsProvider.future),
        ref.read(communitiesProvider.future),
      ]);
    } on Object {
      // Each section shows its own error state with a retry button.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final collectibles = ref.watch(collectiblesProvider);
    final auctions = ref.watch(auctionsProvider);
    final communities = ref.watch(communitiesProvider);
    final categories = ref.watch(catalogCategoriesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: Space.gutter,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xs),
                    child: Image.asset(
                      'assets/branding/site-icon-512.png',
                      width: 30,
                      height: 30,
                      cacheWidth: 90,
                      semanticLabel: l10n.appName,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Flexible(child: Text(l10n.appName, overflow: TextOverflow.ellipsis)),
                ],
              ),
              actions: const [
                SettingsButton(),
                AccountButton(),
                SizedBox(width: Space.xxs),
              ],
            ),
            const SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(padding: EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0), child: _Hero()),
              ),
            ),
            if (categories.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: l10n.homeCategories)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 72 + 12 + 44 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                    itemBuilder: (context, index) => _CategoryTile(
                      category: categories[index],
                      onTap: () {
                        ref.read(catalogFilterProvider.notifier).category(categories[index]);
                        context.go(Routes.catalog);
                      },
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.homeLiveAuctions,
                actionLabel: l10n.seeAll,
                onAction: () => context.go(Routes.auctions),
              ),
            ),
            SliverToBoxAdapter(
              child: AsyncSwitch(
                value: auctions,
                onRetry: () => ref.invalidate(auctionsProvider),
                loading: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Skeleton(height: 220, radius: Radii.md),
                ),
                data: (items) {
                  final live = items.where((a) => a.isLive(DateTime.now())).take(6).toList();
                  if (live.isEmpty) return EmptyState(message: l10n.auctionsEmpty, icon: Icons.gavel_outlined);
                  return SizedBox(
                    height: 236 + 40 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 1.5),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      itemCount: live.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (context, index) => _LiveAuctionCard(
                        auction: live[index],
                        onTap: () => context.go(Routes.auction(live[index].id)),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.homeLatest,
                actionLabel: l10n.seeAll,
                onAction: () => context.go(Routes.catalog),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 176 + collectibleCardTextHeight(context),
                child: AsyncSwitch(
                  value: collectibles,
                  onRetry: () => ref.invalidate(collectiblesProvider),
                  loading: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                    itemBuilder: (_, _) => const SizedBox(width: 176, child: CollectibleCardSkeleton()),
                  ),
                  data: (items) {
                    if (items.isEmpty) return EmptyState(message: l10n.catalogEmpty);
                    final latest = [...items]
                      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
                    final shown = latest.take(10).toList();
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs),
                      clipBehavior: Clip.none,
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (context, index) => CollectibleCard(
                        width: 176,
                        item: shown[index],
                        onTap: () => context.go(Routes.collectible(shown[index].id)),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.homeCommunities,
                actionLabel: l10n.seeAll,
                onAction: () => context.go(Routes.communities),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                  child: AsyncSwitch(
                    value: communities,
                    onRetry: () => ref.invalidate(communitiesProvider),
                    loading: const Skeleton(height: 96, radius: Radii.md),
                    data: (items) {
                      if (items.isEmpty) return EmptyState(message: l10n.communitiesEmpty);
                      return Column(
                        children: [
                          for (final community in items.take(3)) ...[
                            CommunityTile(
                              community: community,
                              onTap: () => context.go(Routes.community(community.id)),
                            ),
                            const SizedBox(height: Space.sm),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    const white = Colors.white;
    return HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(user == null ? l10n.homeScanKicker : l10n.homeGreeting(user.name).toUpperCase(), color: brand.gold),
          const SizedBox(height: Space.xs),
          Text(l10n.homeTitle, style: context.text.headlineMedium?.copyWith(color: white)),
          const SizedBox(height: Space.xs),
          Text(l10n.homeIntro, style: context.text.bodyMedium?.copyWith(color: white.withValues(alpha: 0.78))),
          const SizedBox(height: Space.lg),
          Material(
            color: white.withValues(alpha: 0.12),
            shape: const StadiumBorder(side: BorderSide(color: Color(0x33FFFFFF))),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => context.go(Routes.catalog),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: white, size: 22),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        l10n.catalogSearchHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(color: white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: brand.gold, foregroundColor: brand.onGold),
                onPressed: () => context.go(Routes.scan),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
                label: Text(l10n.homeScanCta),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: white,
                  side: const BorderSide(color: Color(0x66FFFFFF), width: 1.4),
                ),
                onPressed: () => context.go(Routes.catalog),
                child: Text(l10n.homeExplore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});
  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: 84,
      child: Pressable(
        onTap: onTap,
        semanticLabel: category,
        borderRadius: Radii.md,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brand.surfaceMuted,
                border: Border.all(color: brand.gold.withValues(alpha: 0.7), width: 2),
                boxShadow: brand.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: ExcludeSemantics(child: CollectibleImage(categoryArtwork(category), cacheWidth: 72)),
            ),
            const SizedBox(height: Space.xs),
            Flexible(
              child: Text(
                category,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large image card with a scrim, used in the home carousel.
class _LiveAuctionCard extends StatelessWidget {
  const _LiveAuctionCard({required this.auction, required this.onTap});
  final Auction auction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final name = auction.collectibleName ?? l10n.lotNumber(auction.id);
    return SizedBox(
      width: 264,
      child: Pressable(
        onTap: onTap,
        semanticLabel: '$name, ${l10n.currentBid} ${context.money(auction.currentPrice)}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: brand.surfaceMuted,
                  child: CollectibleImage(artworkFor(name: name, url: auction.collectibleImage), cacheWidth: 264),
                ),
                const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
                Positioned(
                  left: Space.sm,
                  top: Space.sm,
                  child: Countdown(auction: auction),
                ),
                Positioned(
                  left: Space.md,
                  right: Space.md,
                  bottom: Space.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: Space.xxs),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.money(auction.currentPrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleLarge?.copyWith(color: brand.gold, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: Space.xs),
                          Text(
                            l10n.bidsCount(auction.bidCount),
                            style: context.text.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
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
