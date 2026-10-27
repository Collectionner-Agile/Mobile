import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import '../communities/application/community_providers.dart';
import '../communities/domain/community_models.dart';
import '../communities/presentation/widgets/community_tile.dart';

enum ExploreTab { pieces, communities }

/// The Explore tab: pieces and communities behind one pill switch, each with
/// its own search and scroll position.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.tab = ExploreTab.pieces});
  final ExploreTab tab;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late ExploreTab _tab = widget.tab;

  @override
  void didUpdateWidget(ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) _tab = widget.tab;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pieces = _tab == ExploreTab.pieces;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageTitle(
              title: l10n.navExplore,
              subtitle: l10n.exploreSubtitle,
              actions: [
                CircleIconButton(
                  icon: AppIcons.search,
                  tooltip: l10n.searchEverything,
                  onPressed: () => context.push(Routes.search),
                ),
                CircleIconButton(
                  icon: AppIcons.plus,
                  tooltip: pieces ? l10n.publishItem : l10n.createCommunity,
                  onPressed: () => context.push(pieces ? Routes.publishCollectible : Routes.newCommunity),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.sm),
              child: ContentWidth(
                child: SegmentedTabs(
                  labels: [l10n.explorePieces, l10n.navCommunities],
                  icons: const [AppIcons.gem, AppIcons.usersRound],
                  index: _tab.index,
                  onChanged: (index) => setState(() => _tab = ExploreTab.values[index]),
                ),
              ),
            ),
            Expanded(
              child: _Panes(index: _tab.index, children: const [_PiecesPane(), _CommunitiesPane()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps both panes alive (search text and scroll survive switching) and
/// fades the incoming one in.
class _Panes extends StatefulWidget {
  const _Panes({required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<_Panes> createState() => _PanesState();
}

class _PanesState extends State<_Panes> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.base, value: 1);

  @override
  void didUpdateWidget(_Panes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !Motion.reduced(context)) _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _fade, curve: Motion.enter);
    return Stack(
      children: [
        for (final (i, child) in widget.children.indexed)
          Offstage(
            offstage: i != widget.index,
            child: TickerMode(
              enabled: i == widget.index,
              // Same wrappers for every pane so switching never remounts one.
              child: FadeTransition(
                opacity: i == widget.index ? curve : kAlwaysCompleteAnimation,
                child: SlideTransition(
                  position: i == widget.index
                      ? Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curve)
                      : const AlwaysStoppedAnimation(Offset.zero),
                  child: child,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PiecesPane extends ConsumerStatefulWidget {
  const _PiecesPane();

  @override
  ConsumerState<_PiecesPane> createState() => _PiecesPaneState();
}

class _PiecesPaneState extends ConsumerState<_PiecesPane> {
  late final TextEditingController _search = TextEditingController(text: ref.read(catalogFilterProvider).search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => ref.read(catalogFilterProvider.notifier).search(value));
  }

  void _clear() {
    _search.clear();
    ref.read(catalogFilterProvider.notifier).clear();
  }

  Future<void> _pickSort() async {
    final l10n = context.l10n;
    final current = ref.read(catalogFilterProvider).sort;
    final picked = await showModalBottomSheet<CatalogSort>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.sm),
                child: Text(l10n.sortBy, style: context.text.titleLarge),
              ),
              for (final (sort, icon) in [
                (CatalogSort.recent, AppIcons.clock),
                (CatalogSort.priceLow, AppIcons.coins),
                (CatalogSort.priceHigh, AppIcons.gem),
                (CatalogSort.rating, AppIcons.star),
              ])
                MenuTile(
                  icon: icon,
                  title: sortLabel(context, sort),
                  color: sort == current ? context.brand.gold : null,
                  trailing: sort == current ? Icon(AppIcons.check, color: context.brand.gold, size: 20) : null,
                  onTap: () => Navigator.of(context).pop(sort),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) ref.read(catalogFilterProvider.notifier).sort(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = ref.watch(catalogFilterProvider);
    final categories = ref.watch(catalogCategoriesProvider);
    final results = ref.watch(filteredCatalogProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(collectiblesProvider);
        await ref.read(collectiblesProvider.future).catchError((Object _) => <Collectible>[]);
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.xs),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearch,
                      textInputAction: TextInputAction.search,
                      decoration: searchDecoration(context, l10n.catalogSearchHint).copyWith(
                        suffixIcon: ValueListenableBuilder(
                          valueListenable: _search,
                          builder: (_, value, _) => value.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  tooltip: l10n.clearFilters,
                                  icon: const Icon(AppIcons.x, size: 18),
                                  onPressed: () {
                                    _search.clear();
                                    ref.read(catalogFilterProvider.notifier).search('');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  CircleIconButton(
                    icon: AppIcons.slidersHorizontal,
                    tooltip: l10n.sortBy,
                    size: 48,
                    onPressed: _pickSort,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xxs),
                children: [
                  _CategoryChip(
                    label: l10n.catalogAllCategories,
                    selected: filter.category == null,
                    onTap: () => ref.read(catalogFilterProvider.notifier).category(null),
                  ),
                  for (final category in categories)
                    _CategoryChip(
                      label: category,
                      selected: filter.category == category,
                      onTap: () => ref
                          .read(catalogFilterProvider.notifier)
                          .category(filter.category == category ? null : category),
                    ),
                ],
              ),
            ),
          ),
          ...switch (results) {
            AsyncValue(:final value?) => _results(context, value, filter),
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(error: error, onRetry: () => ref.invalidate(collectiblesProvider)),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.all(Space.gutter),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) => SliverGrid.builder(
                    gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
                    itemCount: 6,
                    itemBuilder: (_, _) => const CollectibleCardSkeleton(),
                  ),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: Space.xl + bottom)),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, List<Collectible> items, CatalogFilter filter) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: filter.isActive
              ? EmptyState(
                  message: l10n.catalogNoResults,
                  icon: AppIcons.scanSearch,
                  actionLabel: l10n.clearFilters,
                  onAction: _clear,
                )
              : EmptyState(
                  message: l10n.catalogEmpty,
                  actionLabel: l10n.publishItem,
                  onAction: () => context.push(Routes.publishCollectible),
                ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.sm),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(child: Semantics(liveRegion: true, child: Kicker(l10n.resultsCount(items.length)))),
              Kicker(sortLabel(context, filter.sort)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
            itemCount: items.length,
            itemBuilder: (context, index) => Reveal(
              index: index,
              child: CollectibleCard(
                item: items[index],
                hero: true,
                onTap: () => context.go(Routes.collectible(items[index].id)),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

String sortLabel(BuildContext context, CatalogSort sort) => switch (sort) {
  CatalogSort.recent => context.l10n.sortRecent,
  CatalogSort.priceLow => context.l10n.sortPriceLow,
  CatalogSort.priceHigh => context.l10n.sortPriceHigh,
  CatalogSort.rating => context.l10n.sortRating,
};

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Space.xs),
    child: TapScale(
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    ),
  );
}

class _CommunitiesPane extends ConsumerStatefulWidget {
  const _CommunitiesPane();

  @override
  ConsumerState<_CommunitiesPane> createState() => _CommunitiesPaneState();
}

class _CommunitiesPaneState extends ConsumerState<_CommunitiesPane> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _term = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(communitySearchProvider(_term));
    final bottom = MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(communitiesProvider);
        ref.invalidate(communitySearchProvider(_term));
        await ref.read(communitySearchProvider(_term).future).catchError((Object _) => <Community>[]);
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.xs),
              child: TextField(
                controller: _search,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: searchDecoration(context, l10n.searchCommunities),
              ),
            ),
          ),
          ...switch (results) {
            AsyncValue(:final value?) when value.isEmpty => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  message: _term.isEmpty ? l10n.communitiesEmpty : l10n.communitiesNoResults,
                  icon: AppIcons.usersRound,
                  actionLabel: _term.isEmpty ? l10n.createCommunity : null,
                  onAction: _term.isEmpty ? () => context.push(Routes.newCommunity) : null,
                ),
              ),
            ],
            AsyncValue(:final value?) => [
              if (_term.isEmpty && value.any((c) => c.isJoined)) ...[
                SliverToBoxAdapter(child: SectionHeader(title: l10n.myCommunities)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 150 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      itemCount: value.where((c) => c.isJoined).length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                      itemBuilder: (context, index) {
                        final community = value.where((c) => c.isJoined).elementAt(index);
                        return CommunityCoverCard(
                          community: community,
                          onTap: () => context.push(Routes.community(community.id)),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SectionHeader(title: l10n.discoverCommunities)),
              ] else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                    child: Text(
                      l10n.communitiesIntro,
                      style: context.text.bodyMedium?.copyWith(color: context.brand.muted),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                sliver: SliverList.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, index) => Reveal(
                    index: index,
                    child: ContentWidth(
                      child: CommunityTile(
                        community: value[index],
                        onTap: () => context.push(Routes.community(value[index].id)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(error: error, onRetry: () => ref.invalidate(communitySearchProvider(_term))),
              ),
            ],
            _ => [
              SliverPadding(
                padding: const EdgeInsets.all(Space.gutter),
                sliver: SliverList.separated(
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (_, _) => const Skeleton(height: 104, radius: Radii.lg),
                ),
              ),
            ],
          },
          SliverToBoxAdapter(child: SizedBox(height: Space.xl + bottom)),
        ],
      ),
    );
  }
}
