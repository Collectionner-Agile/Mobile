import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/account_button.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
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
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final collectibles = ref.watch(collectiblesProvider);
    final auctions = ref.watch(auctionsProvider);
    final communities = ref.watch(communitiesProvider);

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
                  Flexible(child: Text(l10n.appName, overflow: TextOverflow.ellipsis)),
                ],
              ),
              actions: const [
                SettingsButton(),
                AccountButton(),
                SizedBox(width: Space.xxs),
              ],
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(user == null ? l10n.homeKicker : l10n.homeGreeting(user.name).toUpperCase()),
                      const SizedBox(height: Space.xs),
                      Text(l10n.homeTitle, style: context.text.headlineMedium),
                      const SizedBox(height: Space.xs),
                      Text(l10n.homeIntro, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                      const SizedBox(height: Space.lg),
                      const _ScanBanner(),
                    ],
                  ),
                ),
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
                height: 168 + collectibleCardTextHeight(context),
                child: AsyncSwitch(
                  value: collectibles,
                  onRetry: () => ref.invalidate(collectiblesProvider),
                  loading: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                    itemBuilder: (_, _) => const SizedBox(width: 168, child: CollectibleCardSkeleton()),
                  ),
                  data: (items) {
                    if (items.isEmpty) return EmptyState(message: l10n.catalogEmpty);
                    final latest = [...items]
                      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
                    final shown = latest.take(10).toList();
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (context, index) => CollectibleCard(
                        width: 168,
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
                title: l10n.homeLiveAuctions,
                actionLabel: l10n.seeAll,
                onAction: () => context.go(Routes.auctions),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: AsyncSwitch(
                    value: auctions,
                    onRetry: () => ref.invalidate(auctionsProvider),
                    loading: const Column(
                      children: [
                        AuctionCardSkeleton(),
                        SizedBox(height: Space.sm),
                        AuctionCardSkeleton(),
                      ],
                    ),
                    data: (items) {
                      final live = items.where((a) => a.isLive(DateTime.now())).take(3).toList();
                      if (live.isEmpty) return EmptyState(message: l10n.auctionsEmpty, icon: Icons.gavel_outlined);
                      return Column(
                        children: [
                          for (final auction in live) ...[
                            AuctionCard(auction: auction, onTap: () => context.go(Routes.auction(auction.id))),
                            const SizedBox(height: Space.sm),
                          ],
                        ],
                      );
                    },
                  ),
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

class _ScanBanner extends StatelessWidget {
  const _ScanBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Same ink panel in both themes: a deliberate brand moment.
    const brand = BrandColors.light;
    return Container(
      decoration: BoxDecoration(
        color: brand.ink,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.brand.line),
      ),
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l10n.homeScanKicker, color: const Color(0xFFF0A07F)),
                const SizedBox(height: Space.xs),
                Text(l10n.homeScanTitle, style: context.text.titleLarge?.copyWith(color: brand.paper)),
                const SizedBox(height: Space.xxs),
                Text(
                  l10n.homeScanBody,
                  style: context.text.bodySmall?.copyWith(color: brand.paper.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: Space.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: brand.rust, foregroundColor: brand.onRust),
                  onPressed: () => context.go(Routes.scan),
                  icon: const Icon(Icons.center_focus_strong, size: 20),
                  label: Text(l10n.homeScanCta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
