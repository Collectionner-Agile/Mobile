import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/artwork.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/ui.dart';
import '../application/sale_providers.dart';
import '../domain/sale_models.dart';
import 'sale_panel.dart';

/// The signed-in user's fixed-price operations: what they bought and what they listed, each
/// with where it stands (HU05: the status is visible to both sides).
class MySalesScreen extends ConsumerStatefulWidget {
  const MySalesScreen({super.key});

  @override
  ConsumerState<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends ConsumerState<MySalesScreen> {
  bool _selling = false;

  String get _role => _selling ? 'seller' : 'buyer';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sales = ref.watch(mySalesProvider(_role));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySalesTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ContentWidth(
            child: SegmentedTabs(
              labels: [l10n.mySalesBought, l10n.mySalesSold],
              index: _selling ? 1 : 0,
              onChanged: (index) => setState(() => _selling = index == 1),
            ),
          ),
          const SizedBox(height: Space.md),
          AsyncSwitch(
            value: sales,
            onRetry: () => ref.invalidate(mySalesProvider(_role)),
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: _selling ? Icons.sell_outlined : Icons.shopping_bag_outlined,
                    message: _selling ? l10n.mySalesEmptySold : l10n.mySalesEmptyBought,
                    body: l10n.mySalesEmptyBody,
                    actionLabel: l10n.navCatalog,
                    onAction: () => context.go(Routes.catalog),
                  )
                : Column(
                    children: [
                      for (final sale in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: ContentWidth(child: _SaleRow(sale: sale)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final (label, color) = switch (sale.status) {
      SaleStatus.active => (l10n.forSale, brand.success),
      SaleStatus.reserved => (l10n.saleReserved, brand.warning),
      SaleStatus.completed => (l10n.saleCompleted, brand.info),
      SaleStatus.cancelled => (l10n.saleCancelled, brand.muted),
    };
    final name = sale.collectibleName ?? '';
    return AppCard(
      onTap: () => context.push(Routes.sale(sale.id)),
      padding: const EdgeInsets.all(Space.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox.square(
              dimension: 56,
              child: ColoredBox(
                color: brand.surfaceMuted,
                child: CollectibleImage(artworkFor(name: name, url: sale.collectibleImage), cacheWidth: 120),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Space.xxs),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Space.sm,
                  runSpacing: Space.xxs,
                  children: [
                    InfoChip(label: label, color: color),
                    Text(context.money(sale.price), style: context.text.titleSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One operation on its own, opened from a notification or from "My purchases and sales".
class SaleScreen extends ConsumerWidget {
  const SaleScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sale = ref.watch(saleProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.saleDetailTitle)),
      body: AsyncSwitch(
        value: sale,
        onRetry: () => ref.invalidate(saleProvider(id)),
        data: (value) => ListView(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            ContentWidth(child: Text(value.collectibleName ?? '', style: context.text.headlineSmall)),
            const SizedBox(height: Space.md),
            ContentWidth(child: SalePanel(sale: value)),
            const SizedBox(height: Space.md),
            ContentWidth(
              child: OutlinedButton.icon(
                onPressed: () => context.push(Routes.collectible(value.collectibleId)),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(l10n.viewPiece),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
