import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/artwork.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../application/auction_providers.dart';
import '../domain/auction_models.dart';
import 'widgets/auction_card.dart';

class AuctionDetailScreen extends ConsumerWidget {
  const AuctionDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auction = ref.watch(auctionProvider(id));
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lotNumber(id))),
      body: AsyncSwitch(
        value: auction,
        onRetry: () => ref.invalidate(auctionProvider(id)),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(auctionProvider(id));
            await ref.read(auctionProvider(id).future).catchError((Object _) => data);
          },
          child: _AuctionBody(auction: data),
        ),
      ),
    );
  }
}

class _AuctionBody extends ConsumerWidget {
  const _AuctionBody({required this.auction});
  final Auction auction;

  Future<void> _bid(BuildContext context, WidgetRef ref) async {
    final placed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BidSheet(auction: auction),
    );
    if (placed == true && context.mounted) {
      ref
        ..invalidate(auctionProvider(auction.id))
        ..invalidate(auctionsProvider);
      unawaited(HapticFeedback.mediumImpact());
      showToast(context, context.l10n.bidPlaced);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.cancelAuction,
      body: l10n.cancelAuctionConfirm,
      confirmLabel: l10n.cancelAuction,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(auctionRepositoryProvider).cancel(auction.id);
      ref
        ..invalidate(auctionsProvider)
        ..invalidate(collectiblesProvider)
        ..invalidate(collectibleProvider(auction.collectibleId));
      if (!context.mounted) return;
      showToast(context, l10n.auctionCancelled);
      context.pop();
    } catch (error) {
      if (context.mounted) showToast(context, describeError(error, l10n), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final live = auction.isLive(now);
    final isOwner = user != null && user.id == auction.auctioneerId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final image = ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: brand.surface,
              child: CollectibleImage(
                artworkFor(name: auction.collectibleName ?? '', url: auction.collectibleImage),
                fit: BoxFit.cover,
                cacheWidth: 600,
              ),
            ),
          ),
        );
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(auction.collectibleName ?? '—', style: context.text.headlineSmall),
            const SizedBox(height: Space.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Countdown(auction: auction),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: l10n.currentBid, value: context.money(auction.currentPrice), emphasis: true),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _Stat(label: l10n.startingPrice, value: context.money(auction.startingPrice)),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              [
                l10n.bidsCount(auction.bidCount),
                if (auction.deadline != null) l10n.closesAt(formatDateTime(auction.deadline!, context.languageCode)),
                if (auction.auctioneerName != null) '${l10n.auctioneer}: ${auction.auctioneerName}',
              ].join(' · '),
              style: context.text.bodySmall?.copyWith(color: brand.muted),
            ),
            const SizedBox(height: Space.lg),
            if (!live)
              _Notice(icon: Icons.lock_clock_outlined, text: l10n.auctionClosedNotice)
            else if (isOwner)
              _Notice(icon: Icons.info_outline, text: l10n.ownAuction)
            else if (user == null)
              BusyButton(
                label: l10n.signInToParticipate,
                icon: Icons.login,
                onPressed: () => context.push(Routes.login),
              )
            else
              BusyButton(label: l10n.placeBid, icon: Icons.gavel, onPressed: () => _bid(context, ref)),
            const SizedBox(height: Space.xs),
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.collectible(auction.collectibleId)),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(l10n.actionViewRecord),
            ),
            if (isOwner && live && auction.bidCount == 0) ...[
              const SizedBox(height: Space.xs),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: brand.danger),
                onPressed: () => _cancel(context, ref),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(l10n.cancelAuction),
              ),
            ],
          ],
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xs,
            Space.gutter,
            Space.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: image),
                  const SizedBox(width: Space.xl),
                  Expanded(child: info),
                ],
              )
            else ...[
              image,
              const SizedBox(height: Space.lg),
              info,
            ],
            const SizedBox(height: Space.xl),
            Text(l10n.bidHistory, style: context.text.titleMedium),
            const SizedBox(height: Space.xs),
            if (auction.bids.isEmpty)
              Text(l10n.noBids, style: context.text.bodyMedium?.copyWith(color: brand.muted))
            else
              for (final (index, bid) in auction.bids.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: brand.line)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        index == 0 ? Icons.emoji_events_outlined : Icons.circle_outlined,
                        size: index == 0 ? 20 : 10,
                        color: index == 0 ? brand.accent : brand.line,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bid.bidderName ?? '—',
                              style: context.text.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (bid.createdAt != null)
                              Text(
                                formatDateTime(bid.createdAt!, context.languageCode),
                                style: context.text.bodySmall?.copyWith(color: brand.muted),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        context.money(bid.amount),
                        style: context.text.titleSmall?.copyWith(color: index == 0 ? brand.accentStrong : brand.ink),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: brand.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: emphasis ? brand.accent.withValues(alpha: 0.5) : brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.bodySmall?.copyWith(color: brand.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.text.titleLarge?.copyWith(color: emphasis ? brand.accentStrong : brand.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: brand.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: brand.muted),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

class _BidSheet extends ConsumerStatefulWidget {
  const _BidSheet({required this.auction});
  final Auction auction;

  @override
  ConsumerState<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends ConsumerState<_BidSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.auction.minimumNextBid().toStringAsFixed(0));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final l10n = context.l10n;
    final amount = Validators.parseAmount(value);
    if (amount == null || amount <= 0) return l10n.errPositive;
    if (amount <= widget.auction.currentPrice) return l10n.bidMustExceed(context.money(widget.auction.currentPrice));
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    final amount = Validators.parseAmount(_amount.text)!;
    final ok = await confirmDialog(
      context,
      title: l10n.confirmBidTitle,
      body: l10n.confirmBidBody(context.money(amount)),
      confirmLabel: l10n.placeBid,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(auctionRepositoryProvider).placeBid(widget.auction.id, amount);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final minimum = widget.auction.minimumNextBid();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.placeBid, style: context.text.titleLarge),
              const SizedBox(height: Space.xxs),
              Text(
                '${l10n.currentBid}: ${context.money(widget.auction.currentPrice)}',
                style: context.text.bodyMedium?.copyWith(color: brand.muted),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: l10n.bidAmount,
                  prefixText: 'S/ ',
                  helperText: l10n.minBid(context.money(minimum)),
                ),
                validator: _validate,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.xs,
                children: [
                  for (final step in [1, 2, 5])
                    ActionChip(
                      label: Text(
                        '+ ${context.money(minimum - widget.auction.currentPrice > 0 ? (minimum - widget.auction.currentPrice) * step : step)}',
                      ),
                      onPressed: () =>
                          _amount.text = (widget.auction.currentPrice + (minimum - widget.auction.currentPrice) * step)
                              .toStringAsFixed(0),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: context.text.bodySmall?.copyWith(color: brand.danger)),
                ),
              ],
              const SizedBox(height: Space.lg),
              BusyButton(label: l10n.placeBid, icon: Icons.gavel, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
