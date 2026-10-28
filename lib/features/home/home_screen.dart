import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/account_button.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auth/application/session_controller.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import '../communities/application/community_providers.dart';
import '../communities/presentation/widgets/community_tile.dart';
import 'closing_coverflow.dart';
import 'home_extras.dart';

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

    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2);
    final bids = recentBids(auctions.value ?? const []);
    final pieces = collectibles.value ?? const [];
    final featured = pieces.isEmpty ? null : (pieces.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

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
                      width: 28,
                      height: 28,
                      cacheWidth: 84,
                      semanticLabel: l10n.appName,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  // Scales down on narrow phones instead of being cut off.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.appName,
                        maxLines: 1,
                        style: Fonts.display(context.text.titleLarge, weight: 820),
                      ),
                    ),
                  ),
                ],
              ),
              actions: const [
                FavoritesButton(),
                NotificationsButton(),
                SettingsButton(),
                AccountButton(),
                SizedBox(width: Space.xxs),
              ],
            ),
            const SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(padding: EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0), child: _Intro()),
              ),
            ),
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: SizedBox(
                    height: 40 * textScale,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                      itemBuilder: (context, index) => _CategoryChip(
                        category: categories[index],
                        onTap: () {
                          ref.read(catalogFilterProvider.notifier).category(categories[index]);
                          context.go(Routes.catalog);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                  child: _StatsStrip(
                    pieces: collectibles.value?.length,
                    openAuctions: auctions.value?.where((a) => a.isLive(DateTime.now())).length,
                    communities: communities.value?.length,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: SizedBox(
                  height: 40 * textScale,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    children: [
                      _ShortcutChip(
                        icon: Icons.trending_up_rounded,
                        label: l10n.trendingTitle,
                        onTap: () => context.push(Routes.trending),
                      ),
                      _ShortcutChip(
                        icon: Icons.calendar_month_outlined,
                        label: l10n.calendarShort,
                        onTap: () => context.push(Routes.auctionCalendar),
                      ),
                      _ShortcutChip(
                        icon: Icons.emoji_events_outlined,
                        label: l10n.resultsTitle,
                        onTap: () => context.push(Routes.auctionResults),
                      ),
                      _ShortcutChip(
                        icon: Icons.menu_book_outlined,
                        label: l10n.howItWorksTitle,
                        onTap: () => context.push(Routes.howItWorks),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (bids.isNotEmpty)
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                    child: BidTicker(events: bids),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l10n.closingSoon,
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
                  child: Skeleton(height: 300, radius: Radii.md),
                ),
                data: (items) {
                  final now = DateTime.now();
                  final live = items.where((a) => a.isLive(now)).toList()
                    ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
                  if (live.isEmpty) return EmptyState(message: l10n.auctionsEmpty, icon: Icons.gavel_outlined);
                  return ClosingCoverflow(
                    auctions: live.take(6).toList(),
                    onOpen: (auction) => context.go(Routes.auction(auction.id)),
                  );
                },
              ),
            ),
            if (featured != null) ...[
              SliverToBoxAdapter(child: SectionHeader(title: l10n.featuredPiece)),
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: Reveal(
                      child: FeaturedSpotlight(
                        item: featured,
                        onTap: () => context.go(Routes.collectible(featured.id)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (categories.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: l10n.homeCategories,
                  actionLabel: l10n.seeAll,
                  onAction: () => context.push(Routes.categories),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: _CategoryBento(
                      categories: categories,
                      counts: {
                        for (final category in categories)
                          category: collectibles.value?.where((item) => item.category == category).length ?? 0,
                      },
                      onOpen: (category) => context.push(Routes.category(category)),
                    ),
                  ),
                ),
              ),
            ],
            if (bids.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: l10n.recentActivity,
                  actionLabel: l10n.seeAll,
                  onAction: () => context.push(Routes.activity),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: RecentActivity(
                      events: bids.take(4).toList(),
                      onOpen: (auction) => context.go(Routes.auction(auction.id)),
                    ),
                  ),
                ),
              ),
            ],
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

/// Headline and a search field that opens the catalogue.
class _Intro extends ConsumerWidget {
  const _Intro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user != null) ...[
          Text(
            l10n.homeGreeting(user.name.split(' ').first),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(color: brand.muted),
          ),
          const SizedBox(height: Space.xs),
        ],
        Text(l10n.homeTitle, style: context.text.headlineMedium),
        const SizedBox(height: Space.xs),
        Text(l10n.homeIntro, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
        const SizedBox(height: Space.md),
        Material(
          color: brand.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            side: BorderSide(color: brand.line),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
            onTap: () => context.push(Routes.search),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: brand.muted, size: 22),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      l10n.catalogSearchHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: brand.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Outlined pill leading to one of the app's guides and boards.
class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.icon, required this.label, required this.onTap});
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
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: brand.ink),
                  const SizedBox(width: Space.xs),
                  Text(label, style: Fonts.label(context.text.labelLarge, weight: 640)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});
  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      shape: StadiumBorder(side: BorderSide(color: brand.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, Space.md, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 30,
                  child: ColoredBox(
                    color: brand.surfaceMuted,
                    child: ExcludeSemantics(child: CollectibleImage(categoryArtwork(category), cacheWidth: 30)),
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              Text(category, style: Fonts.label(context.text.labelLarge, weight: 640)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-column grid (more on wide screens) of the newest catalogue entries.
class _LatestGrid extends StatelessWidget {
  const _LatestGrid({required this.collectibles, required this.onRetry});
  final AsyncValue<List<Collectible>> collectibles;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!collectibles.hasValue) {
      return SliverToBoxAdapter(
        child: collectibles.hasError
            ? ErrorState(error: collectibles.error!, onRetry: onRetry)
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Skeleton(height: 260, radius: Radii.md),
              ),
      );
    }
    final items = collectibles.requireValue;
    if (items.isEmpty) return SliverToBoxAdapter(child: EmptyState(message: context.l10n.catalogEmpty));
    final latest = [...items]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = gridColumnsFor(constraints.crossAxisExtent);
          final shown = latest.take(columns * 2).toList();
          final cellWidth = (constraints.crossAxisExtent - Space.md * (columns - 1)) / columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: Space.md,
              mainAxisSpacing: Space.lg,
              mainAxisExtent: cellWidth + collectibleCardTextHeight(context),
            ),
            itemCount: shown.length,
            itemBuilder: (context, index) => Reveal(
              index: index,
              child: CollectibleCard(item: shown[index], onTap: () => context.go(Routes.collectible(shown[index].id))),
            ),
          );
        },
      ),
    );
  }
}

/// The one ink moment on the home screen: identify a piece with the camera.
class _ScanBanner extends StatelessWidget {
  const _ScanBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final fg = heroForeground(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.center_focus_strong_rounded, color: fg, size: 28),
          const SizedBox(height: Space.sm),
          Text(l10n.scanBannerTitle, style: context.text.titleLarge?.copyWith(color: fg)),
          const SizedBox(height: Space.xxs),
          Text(l10n.scanBannerBody, style: context.text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.72))),
          const SizedBox(height: Space.md),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dark ? brand.ink : brand.paper,
              foregroundColor: dark ? brand.paper : brand.ink,
            ),
            onPressed: () => context.go(Routes.scan),
            child: Text(l10n.homeScanCta),
          ),
        ],
      ),
    );
  }
}

/// Live figures from the loaded data: catalogued pieces, open auctions and
/// communities. Shows a dash until each source has loaded.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.pieces, required this.openAuctions, required this.communities});
  final int? pieces;
  final int? openAuctions;
  final int? communities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final stats = [
      (pieces, l10n.statPieces),
      (openAuctions, l10n.openAuctionsStat),
      (communities, l10n.navCommunities),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: brand.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (index, (value, label)) in stats.indexed) ...[
              if (index > 0) VerticalDivider(width: 1, color: brand.line, indent: Space.sm, endIndent: Space.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
                  child: Column(
                    children: [
                      if (value == null)
                        Text('—', style: Fonts.figures(Fonts.display(context.text.headlineSmall, weight: 780)))
                      else
                        AnimatedNumber(
                          value: value.toDouble(),
                          format: (v) => v.round().toString(),
                          style: Fonts.figures(Fonts.display(context.text.headlineSmall, weight: 780)),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Fonts.label(context.text.labelMedium).copyWith(color: brand.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bento of category tiles: one tall tile beside two short ones, repeated,
/// with a full-width tile for any leftover category.
class _CategoryBento extends StatelessWidget {
  const _CategoryBento({required this.categories, required this.counts, required this.onOpen});
  final List<String> categories;
  final Map<String, int> counts;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final unit = 116 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    const gap = Space.sm;
    Widget tile(String category, double height) => SizedBox(
      height: height,
      child: _CategoryTile(category: category, count: counts[category] ?? 0, onTap: () => onOpen(category)),
    );

    final rows = <Widget>[];
    var i = 0;
    while (i < categories.length) {
      final left = categories.length - i;
      if (left >= 3) {
        rows.add(
          Row(
            children: [
              Expanded(child: tile(categories[i], unit * 2 + gap)),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    tile(categories[i + 1], unit),
                    const SizedBox(height: gap),
                    tile(categories[i + 2], unit),
                  ],
                ),
              ),
            ],
          ),
        );
        i += 3;
      } else if (left == 2) {
        rows.add(
          Row(
            children: [
              Expanded(child: tile(categories[i], unit)),
              const SizedBox(width: gap),
              Expanded(child: tile(categories[i + 1], unit)),
            ],
          ),
        );
        i += 2;
      } else {
        rows.add(tile(categories[i], unit));
        i += 1;
      }
    }
    return Column(
      children: [
        for (final (index, row) in rows.indexed) ...[if (index > 0) const SizedBox(height: gap), row],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.onTap});
  final String category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      button: true,
      label: '$category, ${context.l10n.piecesCount(count)}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: Material(
            color: brand.surfaceMuted,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CollectibleImage(categoryArtwork(category), fit: BoxFit.cover, cacheWidth: 420),
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
                          style: Fonts.display(context.text.titleSmall, weight: 760).copyWith(color: Colors.white),
                        ),
                        Text(
                          context.l10n.piecesCount(count),
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
      ),
    );
  }
}
