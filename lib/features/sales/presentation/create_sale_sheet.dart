import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/sale_models.dart';

/// The owner offers a piece at a fixed price. Returns the new sale, or null if dismissed.
Future<Sale?> showCreateSaleSheet(BuildContext context, {required Collectible collectible}) =>
    showModalBottomSheet<Sale>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateSaleSheet(collectible: collectible),
    );

class _CreateSaleSheet extends ConsumerStatefulWidget {
  const _CreateSaleSheet({required this.collectible});
  final Collectible collectible;

  @override
  ConsumerState<_CreateSaleSheet> createState() => _CreateSaleSheetState();
}

class _CreateSaleSheetState extends ConsumerState<_CreateSaleSheet> {
  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: widget.collectible.value > 0 ? widget.collectible.value.toStringAsFixed(0) : '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sale = await ref
          .read(saleRepositoryProvider)
          .create(collectibleId: widget.collectible.id, price: Validators.parseAmount(_price.text)!);
      if (mounted) Navigator.of(context).pop(sale);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.createSaleTitle, style: context.text.titleLarge),
              const SizedBox(height: Space.xxs),
              Text(widget.collectible.name, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
              const SizedBox(height: Space.lg),
              TextFormField(
                key: const Key('sale-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(labelText: '${l10n.salePrice} (S/)', prefixText: 'S/ '),
                validator: validators.positiveAmount,
              ),
              const SizedBox(height: Space.sm),
              Text(l10n.createSaleBody, style: context.text.bodySmall?.copyWith(color: context.brand.muted)),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Text(_error!, style: context.text.bodySmall?.copyWith(color: context.brand.danger)),
              ],
              const SizedBox(height: Space.lg),
              BusyButton(label: l10n.createSaleSubmit, icon: Icons.sell_outlined, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
