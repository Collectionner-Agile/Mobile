import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/ui.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/auction_models.dart';

Future<Auction?> showCreateAuctionSheet(BuildContext context, {required Collectible collectible}) =>
    showModalBottomSheet<Auction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateAuctionSheet(collectible: collectible),
    );

class _CreateAuctionSheet extends ConsumerStatefulWidget {
  const _CreateAuctionSheet({required this.collectible});
  final Collectible collectible;

  @override
  ConsumerState<_CreateAuctionSheet> createState() => _CreateAuctionSheetState();
}

class _CreateAuctionSheetState extends ConsumerState<_CreateAuctionSheet> {
  static const _durations = [Duration(hours: 24), Duration(days: 3), Duration(days: 7)];

  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: widget.collectible.value > 0 ? widget.collectible.value.toStringAsFixed(0) : '',
  );
  Duration _duration = _durations.first;
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
      final auction = await ref
          .read(auctionRepositoryProvider)
          .create(
            collectibleId: widget.collectible.id,
            startingPrice: Validators.parseAmount(_price.text)!,
            deadline: DateTime.now().add(_duration),
          );
      if (mounted) Navigator.of(context).pop(auction);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(Duration duration) => duration.inDays >= 1 && duration.inHours % 24 == 0 && duration.inDays > 1
      ? context.l10n.durationDays(duration.inDays)
      : context.l10n.durationHours(duration.inHours);

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
              Text(l10n.createAuctionTitle, style: context.text.titleLarge),
              const SizedBox(height: Space.xxs),
              Text(widget.collectible.name, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(labelText: '${l10n.startingPrice} (S/)', prefixText: 'S/ '),
                validator: validators.positiveAmount,
              ),
              const SizedBox(height: Space.lg),
              Text(l10n.auctionDuration, style: context.text.labelLarge),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final duration in _durations)
                    ChoiceChip(
                      label: Text(_label(duration)),
                      selected: _duration == duration,
                      onSelected: (_) => setState(() => _duration = duration),
                    ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                l10n.closesAt(formatDateTime(DateTime.now().add(_duration), context.languageCode)),
                style: context.text.bodySmall?.copyWith(color: context.brand.muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Text(_error!, style: context.text.bodySmall?.copyWith(color: context.brand.danger)),
              ],
              const SizedBox(height: Space.lg),
              BusyButton(label: l10n.createAuctionSubmit, icon: AppIcons.gavel, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
