import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config/app_config.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/presentation/widgets/live_auction_carousel.dart';
import '../auth/application/session_controller.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import '../communities/application/community_providers.dart';
import '../communities/presentation/widgets/community_tile.dart';
import '../notifications/notices.dart';

/// Home: a greeting, four plain shortcuts, the live auctions as a swipeable
/// showcase, categories, the newest pieces and the communities. One idea per
/// block, readable at a glance.
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

  void _openCategory(BuildContext context, WidgetRef ref, String category) => context.push(Routes.category(category));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final collectibles = ref.watch(collectiblesProvider);
    final auctions = ref.watch(auctionsProvider);
    final communities = ref.watch(communitiesProvider);
    final categories = ref.watch(catalogCategoriesProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SafeArea(bottom: false, child: ContentWidth(maxWidth: 900, child: _Header())),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                  child: _QuickActions(onCategories: () => context.push(Routes.categories)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.liveNow,
                note: l10n.liveNowNote,
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
                  child: Skeleton(height: 340, radius: Radii.xl),
                ),
                data: (items) {
                  final now = DateTime.now();
                  final live = items.where((a) => a.isLive(now)).toList()
                    ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
                  if (live.isEmpty) {
                    return EmptyState(message: l10n.auctionsEmpty, icon: AppIcons.gavel);
                  }
                  return LiveAuctionCarousel(
                    auctions: live.take(6).toList(),
                    onOpen: (auction) => context.go(Routes.auction(auction.id)),
                  );
                },
              ),
            ),
            if (categories.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: l10n.homeCategories,
                  actionLabel: l10n.seeAll,
                  onAction: () => context.push(Routes.categories),
                ),
              ),
              SliverToBoxAdapter(
                child: _CategoryRail(
                  categories: categories,
                  counts: {
                    for (final category in categories)
                      category: collectibles.value?.where((item) => item.category == category).length ?? 0,
                  },
                  onOpen: (category) => _openCategory(context, ref, category),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                  child: AppCard(
                    onTap: () => context.push(Routes.trending),
                    child: Row(
                      children: [
                        IconBadge(AppIcons.flame, color: context.brand.live, solid: true),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.trendingTitle, style: context.text.titleMedium),
                              Text(l10n.trendingTeaser, style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        Icon(AppIcons.chevronRight, color: context.brand.muted, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.recentlyCatalogued,
                actionLabel: l10n.seeAll,
                onAction: () => context.go(Routes.catalog),
              ),
            ),
            _LatestGrid(collectibles: collectibles, onRetry: () => ref.invalidate(collectiblesProvider)),
            const SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                  child: _ScanBanner(),
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
              child: AsyncSwitch(
                value: communities,
                onRetry: () => ref.invalidate(communitiesProvider),
                loading: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Skeleton(height: 150, radius: Radii.lg),
                ),
                data: (items) {
                  if (items.isEmpty) return EmptyState(message: l10n.communitiesEmpty, icon: AppIcons.usersRound);
                  return SizedBox(
                    height: 150 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      itemCount: items.length.clamp(0, 8),
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (context, index) => CommunityCoverCard(
                        community: items[index],
                        onTap: () => context.push(Routes.community(items[index].id)),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: Space.xxl + bottom)),
          ],
        ),
      ),
    );
  }
}

/// Greeting by time of day, a one-line invitation, and the search pill.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final hour = DateTime.now().hour;
    final first = user?.name.split(' ').first;
    final greeting = switch (hour) {
      < 12 => l10n.greetingMorning,
      < 19 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go(Routes.profile),
                child: user == null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/branding/site-icon-512.png',
                          width: 44,
                          height: 44,
                          cacheWidth: 132,
                          semanticLabel: l10n.appName,
                        ),
                      )
                    : UserAvatar(name: user.name, url: user.avatarUrl, size: 44, ring: true),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first == null || first.isEmpty ? greeting : '$greeting, $first',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: brand.muted),
                    ),
                    Text(
                      l10n.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fonts.display(context.text.titleLarge, weight: 680),
                    ),
                  ],
                ),
              ),
              if (AppConfig.demoMode) ...[
                Tag(l10n.demoBadge, icon: AppIcons.sparkles, color: brand.gold),
                const SizedBox(width: Space.xs),
              ],
              CircleIconButton(
                icon: AppIcons.bell,
                tooltip: l10n.noticesTitle,
                badge: ref.watch(unreadNoticesProvider) > 0,
                onPressed: () => context.push(Routes.notifications),
              ),
              const SizedBox(width: Space.xs),
              CircleIconButton(
                icon: AppIcons.heart,
                tooltip: l10n.favoritesTitle,
                onPressed: () => context.push(Routes.favorites),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(l10n.homeTitle, style: context.text.headlineLarge),
          const SizedBox(height: Space.xs),
          Text(l10n.homeIntro, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
          const SizedBox(height: Space.md),
          Semantics(
            button: true,
            label: l10n.searchEverything,
            excludeSemantics: true,
            child: TapScale(
              child: Material(
                color: brand.surface,
                shape: StadiumBorder(side: BorderSide(color: brand.line)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push(Routes.search);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, 14, Space.xs, 14),
                    child: Row(
                      children: [
                        Icon(AppIcons.search, color: brand.muted, size: 20),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            l10n.searchEverything,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(color: brand.muted),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: brand.surfaceMuted, shape: BoxShape.circle),
                          child: Icon(AppIcons.arrowRight, size: 16, color: brand.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onCategories});
  final VoidCallback onCategories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final actions = [
      QuickAction(icon: AppIcons.scanLine, label: l10n.navScan, highlight: true, onTap: () => context.go(Routes.scan)),
      QuickAction(
        icon: AppIcons.imagePlus,
        label: l10n.quickPublish,
        color: brand.gold,
        onTap: () => context.push(Routes.publishCollectible),
      ),
      QuickAction(
        icon: AppIcons.gavel,
        label: l10n.navAuctions,
        color: brand.live,
        onTap: () => context.go(Routes.auctions),
      ),
      QuickAction(icon: AppIcons.layoutGrid, label: l10n.quickCategories, color: brand.info, onTap: onCategories),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, action) in actions.indexed)
          Expanded(
            child: Reveal(index: i, offset: 12, child: action),
          ),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.categories, required this.counts, required this.onOpen});
  final List<String> categories;
  final Map<String, int> counts;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      height: 168 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Reveal(
            index: index,
            offset: 10,
            child: SizedBox(
              width: 132,
              child: AppCard(
                onTap: () => onOpen(category),
                padding: EdgeInsets.zero,
                semanticLabel: category,
                child: ExcludeSemantics(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: context.brand.surfaceMuted,
                        child: CollectibleImage(categoryArtwork(category), cacheWidth: 280),
                      ),
                      const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
                      Positioned(
                        left: Space.sm,
                        right: Space.sm,
                        bottom: Space.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(color: Colors.white),
                            ),
                            Text(
                              context.l10n.piecesCount(counts[category] ?? 0),
                              maxLines: 1,
                              style: context.text.bodySmall?.copyWith(color: const Color(0xCCFFFFFF)),
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
        },
      ),
    );
  }
}

class _LatestGrid extends StatelessWidget {
  const _LatestGrid({required this.collectibles, required this.onRetry});
  final AsyncValue<List<Collectible>> collectibles;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (collectibles) {
      AsyncValue(:final value?) when value.isEmpty => SliverToBoxAdapter(
        child: EmptyState(
          message: context.l10n.catalogEmpty,
          actionLabel: context.l10n.publishItem,
          onAction: () => context.push(Routes.publishCollectible),
        ),
      ),
      AsyncValue(:final value?) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final latest = [...value]
              ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
            final count = gridColumnsFor(constraints.crossAxisExtent) * 2;
            return SliverGrid.builder(
              gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
              itemCount: latest.length.clamp(0, count),
              itemBuilder: (context, index) => Reveal(
                index: index,
                child: CollectibleCard(
                  item: latest[index],
                  onTap: () => context.go(Routes.collectible(latest[index].id)),
                ),
              ),
            );
          },
        ),
      ),
      AsyncValue(:final error?) => SliverToBoxAdapter(
        child: ErrorState(error: error, onRetry: onRetry),
      ),
      _ => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
            itemCount: 4,
            itemBuilder: (_, _) => const CollectibleCardSkeleton(),
          ),
        ),
      ),
    };
  }
}

/// Midnight invitation to identify a piece with the camera.
class _ScanBanner extends StatelessWidget {
  const _ScanBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.scanBannerTitle,
      excludeSemantics: true,
      child: TapScale(
        child: GestureDetector(
          onTap: () => context.go(Routes.scan),
          child: HeroPanel(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Brand.gold.withValues(alpha: 0.16),
                    border: Border.all(color: Brand.gold.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(AppIcons.scanSearch, color: Brand.goldLight, size: 26),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.scanBannerTitle,
                        style: Fonts.display(context.text.titleLarge, weight: 660).copyWith(color: Brand.ivory),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.scanBannerBody,
                        style: context.text.bodySmall?.copyWith(color: const Color(0xB3F5F1E7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.xs),
                const Icon(AppIcons.arrowRight, color: Brand.goldLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
