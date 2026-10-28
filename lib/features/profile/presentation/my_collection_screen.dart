import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/widgets/collectible_card.dart';

/// Everything the user owns: the total on top, then a searchable, sortable
/// collection shown as a grid or as a compact list.
class MyCollectionScreen extends ConsumerStatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  ConsumerState<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

class _MyCollectionScreenState extends ConsumerState<MyCollectionScreen> {
  String _search = '';
  CatalogSort _sort = CatalogSort.priceHigh;
  bool _list = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final items = ref
        .watch(collectiblesProvider)
        .whenData((all) => all.where((item) => item.ownerId == user?.id).toList());
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCollectionTitle),
        actions: [
          CircleIconButton(
            icon: _list ? Icons.grid_view_outlined : Icons.view_list_outlined,
            tooltip: _list ? l10n.viewAsGrid : l10n.viewAsList,
            onPressed: () => setState(() => _list = !_list),
          ),
          const SizedBox(width: Space.xs),
          CircleIconButton(
            icon: Icons.add_rounded,
            tooltip: l10n.publishItem,
            onPressed: () => context.push(Routes.publishCollectible),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: AsyncSwitch(
        value: items,
        onRetry: () => ref.invalidate(collectiblesProvider),
        data: (mine) {
          if (mine.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.diamond_outlined,
                  message: l10n.noItemsYet,
                  body: l10n.myCollectionEmptyBody,
                  actionLabel: l10n.publishItem,
                  onAction: () => context.push(Routes.publishCollectible),
                ),
              ),
            );
          }
          final shown = applyCatalogQuery(mine, search: _search, sort: _sort);
          final total = mine.fold<double>(0, (sum, item) => sum + item.value);
          final categories = <String, int>{};
          for (final item in mine) {
            if (item.category != null) categories[item.category!] = (categories[item.category!] ?? 0) + 1;
          }
          final topCategory = categories.isEmpty
              ? null
              : (categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                  child: ContentWidth(
                    child: Reveal(
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.collectionValue, style: context.text.bodySmall),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: PriceText(total, style: context.text.headlineMedium, animate: true),
                                  ),
                                  if (topCategory != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: Space.xxs),
                                      child: Tag(topCategory, icon: Icons.workspace_premium_outlined, color: brand.ink),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: Space.sm),
                            ProgressRing(
                              value: 1,
                              size: 64,
                              child: Text(
                                '${mine.length}',
                                style: Fonts.figures(Fonts.display(context.text.titleLarge, weight: 700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    textInputAction: TextInputAction.search,
                    decoration: searchDecoration(context, l10n.myCollectionSearch),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
                    children: [
                      for (final sort in [
                        CatalogSort.priceHigh,
                        CatalogSort.recent,
                        CatalogSort.rating,
                        CatalogSort.priceLow,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: ChoiceChip(
                            label: Text(sortLabel(context, sort)),
                            selected: sort == _sort,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _sort = sort);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.image_search_outlined, message: l10n.catalogNoResults),
                )
              else if (_list)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xxl),
                  sliver: SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (context, index) => Reveal(
                      index: index,
                      child: ContentWidth(child: _PieceRow(item: shown[index])),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xxl),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid.builder(
                      gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
                      itemCount: shown.length,
                      itemBuilder: (context, index) => Reveal(
                        index: index,
                        child: CollectibleCard(
                          item: shown[index],
                          onTap: () => context.push(Routes.collectible(shown[index].id)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.item});
  final Collectible item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return AppCard(
      onTap: () => context.push(Routes.collectible(item.id)),
      padding: const EdgeInsets.all(Space.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox.square(
              dimension: 60,
              child: ColoredBox(color: brand.surfaceMuted, child: CollectibleImage(item.artwork, cacheWidth: 130)),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [?item.category, if (item.eraYear != null) '${item.eraYear}'].join(' · '),
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.auctionId != null) ...[const SizedBox(height: 4), LivePill(label: l10n.inAuction)],
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          PriceText(item.value, style: context.text.titleMedium),
        ],
      ),
    );
  }
}
