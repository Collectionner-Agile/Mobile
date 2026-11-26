import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kit.dart' show AppCard;
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../application/sale_providers.dart';
import '../domain/sale_models.dart';

/// A sale and what the viewer can do with it: buy it, confirm their step of the hand-over,
/// withdraw or call it off. Every rule is checked again by the server; the buttons only show
/// what the server would accept.
class SalePanel extends ConsumerStatefulWidget {
  const SalePanel({super.key, required this.sale, this.onChanged});
  final Sale sale;

  /// Called with the sale as the server returned it after an action.
  final ValueChanged<Sale>? onChanged;

  @override
  ConsumerState<SalePanel> createState() => _SalePanelState();
}

class _SalePanelState extends ConsumerState<SalePanel> {
  bool _busy = false;
  String? _error;

  Future<void> _run(
    Future<Sale> Function() action, {
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
    String Function(Sale)? toast,
  }) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      ref
        ..invalidate(saleProvider(updated.id))
        ..invalidate(collectibleProvider(updated.collectibleId))
        ..invalidate(collectiblesProvider)
        ..invalidate(mySalesProvider);
      if (toast != null) showToast(context, toast(updated));
      widget.onChanged?.call(updated);
    } catch (error) {
      if (!mounted) return;
      final taken = error is ApiException && error.errorCode == 'SALE_NOT_AVAILABLE';
      setState(() => _error = taken ? l10n.saleNotAvailable : describeError(error, l10n));
      if (taken) ref.invalidate(collectibleProvider(widget.sale.collectibleId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final sale = widget.sale;
    final user = ref.watch(currentUserProvider);
    final role = sale.roleOf(user?.id);
    final repo = ref.read(saleRepositoryProvider);

    final (statusLabel, statusColor, statusIcon) = switch (sale.status) {
      SaleStatus.active => (l10n.forSale, brand.success, Icons.sell_outlined),
      SaleStatus.reserved => (l10n.saleReserved, brand.warning, Icons.hourglass_top_rounded),
      SaleStatus.completed => (l10n.saleCompleted, brand.info, Icons.verified_outlined),
      SaleStatus.cancelled => (l10n.saleCancelled, brand.muted, Icons.block_outlined),
    };

    final who = switch ((sale.status, role)) {
      (SaleStatus.active, _) when sale.sellerName != null => l10n.saleSoldBy(sale.sellerName!),
      (SaleStatus.reserved || SaleStatus.completed, SaleRole.buyer) => l10n.saleYouBought,
      (SaleStatus.reserved || SaleStatus.completed, _) when sale.buyerName != null => l10n.saleBoughtBy(
        sale.buyerName!,
      ),
      _ => null,
    };

    final actions = <Widget>[
      if (sale.status == SaleStatus.active && role == SaleRole.visitor)
        BusyButton(
          key: const Key('sale-buy'),
          label: l10n.buyNow,
          icon: Icons.shopping_bag_outlined,
          busy: _busy,
          onPressed: user == null
              ? () => context.push(
                  Uri(
                    path: Routes.login,
                    queryParameters: {'from': GoRouterState.of(context).uri.toString()},
                  ).toString(),
                )
              : () => _run(
                  () => repo.purchase(sale.id),
                  title: l10n.confirmPurchaseTitle,
                  body: l10n.confirmPurchaseBody(sale.collectibleName ?? '', context.money(sale.price)),
                  confirmLabel: l10n.buyNow,
                  toast: (_) => l10n.purchaseDone,
                ),
        ),
      if (sale.status == SaleStatus.reserved && role == SaleRole.seller && !sale.sellerConfirmed)
        BusyButton(
          key: const Key('sale-confirm-delivery'),
          label: l10n.confirmDelivery,
          icon: Icons.local_shipping_outlined,
          busy: _busy,
          onPressed: () => _run(
            () => repo.confirmDelivery(sale.id),
            title: l10n.confirmDelivery,
            body: l10n.confirmDeliveryBody,
            confirmLabel: l10n.confirm,
            toast: (_) => l10n.saleConfirmed,
          ),
        ),
      if (sale.status == SaleStatus.reserved && role == SaleRole.buyer && !sale.buyerConfirmed)
        BusyButton(
          key: const Key('sale-confirm-receipt'),
          label: l10n.confirmReceipt,
          icon: Icons.inventory_2_outlined,
          busy: _busy,
          onPressed: () => _run(
            () => repo.confirmReceipt(sale.id),
            title: l10n.confirmReceipt,
            body: l10n.confirmReceiptBody,
            confirmLabel: l10n.confirm,
            toast: (s) => s.status == SaleStatus.completed ? l10n.saleNowYours : l10n.saleConfirmed,
          ),
        ),
      if (sale.canCancel(role))
        BusyButton(
          key: const Key('sale-cancel'),
          label: sale.status == SaleStatus.active ? l10n.withdrawSale : l10n.cancelPurchase,
          icon: Icons.close_rounded,
          outlined: true,
          busy: _busy,
          onPressed: () => _run(
            () => repo.cancel(sale.id),
            title: sale.status == SaleStatus.active ? l10n.withdrawSale : l10n.cancelPurchase,
            body: sale.status == SaleStatus.active ? l10n.withdrawSaleBody : l10n.cancelPurchaseBody,
            confirmLabel: l10n.confirm,
            destructive: true,
            toast: (_) => sale.status == SaleStatus.active ? l10n.saleWithdrawn : l10n.saleCancelledToast,
          ),
        ),
    ];

    return AppCard(
      key: const Key('sale-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap, not Row: at large text sizes the price drops under the status instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              InfoChip(label: statusLabel, icon: statusIcon, color: statusColor),
              Text(context.money(sale.price), style: context.text.titleLarge),
            ],
          ),
          if (who != null) ...[
            const SizedBox(height: Space.xs),
            Text(who, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
          ],
          if (sale.status == SaleStatus.reserved) ...[
            const SizedBox(height: Space.sm),
            _Step(done: sale.sellerConfirmed, label: l10n.saleStepDelivery),
            _Step(done: sale.buyerConfirmed, label: l10n.saleStepReceipt),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            for (final (index, action) in actions.indexed) ...[if (index > 0) const SizedBox(height: Space.xs), action],
          ],
          if (_error != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              _error!,
              key: const Key('sale-error'),
              style: context.text.bodySmall?.copyWith(color: brand.danger),
            ),
          ],
          if (sale.status.isOpen) ...[
            const SizedBox(height: Space.sm),
            Text(l10n.saleNoPayment, style: context.text.bodySmall?.copyWith(color: brand.muted)),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.label});
  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? brand.success : brand.muted,
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(label, style: context.text.bodySmall?.copyWith(color: done ? brand.ink : brand.muted)),
          ),
        ],
      ),
    );
  }
}

/// Loads the sale by id and shows its [SalePanel]; used on the piece's detail.
class SalePanelLoader extends ConsumerWidget {
  const SalePanelLoader({super.key, required this.saleId});
  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(saleProvider(saleId));
    return AsyncSwitch(
      value: sale,
      onRetry: () => ref.invalidate(saleProvider(saleId)),
      loading: const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      data: (value) => SalePanel(sale: value),
    );
  }
}
