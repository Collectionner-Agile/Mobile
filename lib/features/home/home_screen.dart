import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/account_button.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import '../communities/application/community_providers.dart';
import '../communities/presentation/widgets/community_tile.dart';
import 'closing_coverflow.dart';

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
                  Flexible(
                    child: Text(
                      l10n.appName,
                      overflow: TextOverflow.ellipsis,
                      style: Fonts.display(context.text.titleLarge, weight: 800),
                    ),
                  ),
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
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            onTap: () => context.go(Routes.catalog),
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
            itemBuilder: (context, index) =>
                CollectibleCard(item: shown[index], onTap: () => context.go(Routes.collectible(shown[index].id))),
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
