import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/account_button.dart';
import '../../../core/widgets/ui.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_models.dart';
import 'widgets/collectible_card.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = ref.watch(catalogFilterProvider);
    final categories = ref.watch(catalogCategoriesProvider);
    final results = ref.watch(filteredCatalogProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'publish-fab',
        onPressed: () => context.push(Routes.publishCollectible),
        icon: const Icon(Icons.add),
        label: Text(l10n.publishItem),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(collectiblesProvider);
          await ref.read(collectiblesProvider.future).catchError((Object _) => <Collectible>[]);
        },
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(l10n.catalogTitle),
              titleSpacing: Space.gutter,
              actions: [
                PopupMenuButton<CatalogSort>(
                  tooltip: l10n.sortBy,
                  icon: const Icon(Icons.sort),
                  initialValue: filter.sort,
                  onSelected: ref.read(catalogFilterProvider.notifier).sort,
                  itemBuilder: (context) => [
                    for (final sort in CatalogSort.values)
                      CheckedPopupMenuItem(
                        value: sort,
                        checked: sort == filter.sort,
                        child: Text(_sortLabel(context, sort)),
                      ),
                  ],
                ),
                const AccountButton(),
                const SizedBox(width: Space.xxs),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(116),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs),
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
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _search.clear();
                                      ref.read(catalogFilterProvider.notifier).search('');
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
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
                      gridDelegate: _gridDelegate(constraints.crossAxisExtent),
                      itemCount: 6,
                      itemBuilder: (_, _) => const CollectibleCardSkeleton(),
                    ),
                  ),
                ),
              ],
            },
            SliverToBoxAdapter(child: SizedBox(height: 88 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
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
                  icon: Icons.search_off,
                  actionLabel: l10n.clearFilters,
                  onAction: _clear,
                )
              : EmptyState(message: l10n.catalogEmpty),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xs),
        sliver: SliverToBoxAdapter(child: Semantics(liveRegion: true, child: Kicker(l10n.resultsCount(items.length)))),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: _gridDelegate(constraints.crossAxisExtent),
            itemCount: items.length,
            itemBuilder: (context, index) => CollectibleCard(
              item: items[index],
              hero: true,
              onTap: () => context.go(Routes.collectible(items[index].id)),
            ),
          ),
        ),
      ),
    ];
  }

  SliverGridDelegate _gridDelegate(double width) {
    final columns = gridColumnsFor(width);
    final cellWidth = (width - Space.sm * (columns - 1)) / columns;
    // Square photo plus a text block that grows with the user's font scale.
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: Space.sm,
      crossAxisSpacing: Space.sm,
      mainAxisExtent: cellWidth + collectibleCardTextHeight(context),
    );
  }

  String _sortLabel(BuildContext context, CatalogSort sort) => switch (sort) {
    CatalogSort.recent => context.l10n.sortRecent,
    CatalogSort.priceLow => context.l10n.sortPriceLow,
    CatalogSort.priceHigh => context.l10n.sortPriceHigh,
    CatalogSort.rating => context.l10n.sortRating,
  };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Space.xs),
    child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
  );
}
