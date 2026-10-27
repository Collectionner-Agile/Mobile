import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import 'favorites.dart';

/// Saved pieces, newest first in the catalogue's own order.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(favoritesProvider);
    final catalogue = ref.watch(collectiblesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: AsyncSwitch(
        value: catalogue,
        onRetry: () => ref.invalidate(collectiblesProvider),
        data: (items) {
          final list = items.where((item) => saved.contains(item.id)).toList();
          if (list.isEmpty) {
            return ListView(
              children: [
                EmptyState(
                  message: l10n.favoritesEmpty,
                  icon: Icons.favorite_border_rounded,
                  actionLabel: l10n.homeExplore,
                  onAction: () => context.go(Routes.catalog),
                ),
              ],
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth - Space.gutter * 2;
              final columns = gridColumnsFor(width);
              final cell = (width - Space.md * (columns - 1)) / columns;
              return GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.xs,
                  Space.gutter,
                  Space.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: Space.md,
                  mainAxisSpacing: Space.lg,
                  mainAxisExtent: cell + collectibleCardTextHeight(context),
                ),
                itemCount: list.length,
                itemBuilder: (context, index) => Reveal(
                  index: index,
                  child: CollectibleCard(
                    item: list[index],
                    onTap: () => context.push(Routes.collectible(list[index].id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
