import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/widgets/collectible_card.dart';

/// One category with its pieces and figures.
class CategorySummary {
  const CategorySummary({required this.name, required this.pieces});
  final String name;
  final List<Collectible> pieces;

  double get average => pieces.isEmpty ? 0 : pieces.fold<double>(0, (sum, p) => sum + p.value) / pieces.length;
  double get from => pieces.isEmpty ? 0 : pieces.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  int get inAuction => pieces.where((p) => p.auctionId != null).length;
}

/// Categories with at least one piece, the largest first.
final categorySummariesProvider = Provider<AsyncValue<List<CategorySummary>>>((ref) {
  return ref.watch(collectiblesProvider).whenData((items) {
    final groups = <String, List<Collectible>>{};
    for (final item in items) {
      final category = item.category;
      if (category == null || category.trim().isEmpty) continue;
      groups.putIfAbsent(category, () => []).add(item);
    }
    return [for (final entry in groups.entries) CategorySummary(name: entry.key, pieces: entry.value)]
      ..sort((a, b) => b.pieces.length.compareTo(a.pieces.length));
  });
});

/// Every category as a bento of artwork tiles: the largest one wide on top,
/// the rest two by two, each with its count and starting price.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summaries = ref.watch(categorySummariesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      body: AsyncSwitch(
        value: summaries,
        onRetry: () => ref.invalidate(collectiblesProvider),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: EmptyState(icon: Icons.grid_view_outlined, message: l10n.catalogEmpty),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 3 : 2;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l10n.categoriesSubtitle,
                        style: context.text.bodyMedium?.copyWith(color: context.brand.muted),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    sliver: SliverToBoxAdapter(
                      child: Reveal(
                        child: AspectRatio(
                          aspectRatio: columns == 3 ? 3 : 16 / 10,
                          child: _CategoryTile(summary: list.first, large: true),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.md,
                      Space.gutter,
                      Space.xxl + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: Space.md,
                        crossAxisSpacing: Space.md,
                        childAspectRatio: 0.82 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                      ),
                      itemCount: list.length - 1,
                      itemBuilder: (context, index) => Reveal(
                        index: index + 1,
                        child: _CategoryTile(summary: list[index + 1]),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.summary, this.large = false});
  final CategorySummary summary;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppCard(
      onTap: () => context.push(Routes.category(summary.name)),
      padding: EdgeInsets.zero,
      radius: Radii.xl,
      semanticLabel: '${summary.name}, ${l10n.piecesCount(summary.pieces.length)}',
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'category-${summary.name}',
              child: ColoredBox(
                color: context.brand.surfaceMuted,
                child: CollectibleImage(categoryArtwork(summary.name), cacheWidth: large ? 900 : 420),
              ),
            ),
            const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
            Positioned(
              left: Space.md,
              right: Space.md,
              bottom: Space.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Fonts.display(
                      large ? context.text.headlineMedium : context.text.titleLarge,
                      weight: 660,
                    ).copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: Space.xxs),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xxs,
                    children: [
                      Tag(l10n.piecesCount(summary.pieces.length), onPhoto: true),
                      if (large) Tag(l10n.fromPrice(context.money(summary.from)), onPhoto: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One category: its artwork as a header, three figures, sort chips and the
/// pieces.
class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  CatalogSort _sort = CatalogSort.priceHigh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final summaries = ref.watch(categorySummariesProvider);
    return Scaffold(
      body: AsyncSwitch(
        value: summaries,
        onRetry: () => ref.invalidate(collectiblesProvider),
        data: (list) {
          final summary = list.where((s) => s.name == widget.name).firstOrNull;
          final pieces = applyCatalogQuery(summary?.pieces ?? const [], sort: _sort);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 260,
                backgroundColor: brand.paper,
                automaticallyImplyLeading: false,
                leadingWidth: 60,
                leading: Padding(
                  padding: const EdgeInsets.all(Space.xxs),
                  child: CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: l10n.back,
                    onPhoto: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'category-${widget.name}',
                        child: CollectibleImage(categoryArtwork(widget.name), cacheWidth: 900),
                      ),
                      const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
                      Positioned(
                        left: Space.gutter,
                        right: Space.gutter,
                        bottom: Space.lg,
                        child: Text(
                          widget.name,
                          style: Fonts.display(context.text.displaySmall, weight: 660).copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (summary == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.grid_view_outlined, message: l10n.catalogNoResults),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                    child: ContentWidth(
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: StatTile(value: '${summary.pieces.length}', label: l10n.statPieces),
                            ),
                            Expanded(
                              child: StatTile(value: context.money(summary.average), label: l10n.averageValue),
                            ),
                            Expanded(
                              child: StatTile(value: '${summary.inAuction}', label: l10n.inAuction, color: brand.live),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
                      children: [
                        for (final sort in [
                          CatalogSort.priceHigh,
                          CatalogSort.priceLow,
                          CatalogSort.rating,
                          CatalogSort.recent,
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
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.md,
                    Space.gutter,
                    Space.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid.builder(
                      gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
                      itemCount: pieces.length,
                      itemBuilder: (context, index) => Reveal(
                        index: index,
                        child: CollectibleCard(
                          item: pieces[index],
                          onTap: () => context.push(Routes.collectible(pieces[index].id)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
