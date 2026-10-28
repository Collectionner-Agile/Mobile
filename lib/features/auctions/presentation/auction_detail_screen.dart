import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../application/auction_providers.dart';
import '../application/bid_events.dart';
import '../domain/auction_models.dart';

/// One auction: the piece large, the countdown in tiles, the current bid in
/// big serif figures, the bid history as a timeline and one sticky action.
class AuctionDetailScreen extends ConsumerWidget {
  const AuctionDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auction = ref.watch(auctionProvider(id));
    return Scaffold(
      body: AsyncSwitch(
        value: auction,
        onRetry: () => ref.invalidate(auctionProvider(id)),
        loading: const _DetailSkeleton(),
        data: (data) => _AuctionBody(auction: data),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: const [
        Skeleton(height: 300, radius: Radii.xl),
        SizedBox(height: Space.lg),
        Skeleton(height: 24, width: 220),
        SizedBox(height: Space.md),
        Skeleton(height: 64, radius: Radii.md),
        SizedBox(height: Space.md),
        Skeleton(height: 120, radius: Radii.lg),
      ],
    ),
  );
}

class _AuctionBody extends ConsumerStatefulWidget {
  const _AuctionBody({required this.auction});
  final Auction auction;

  @override
  ConsumerState<_AuctionBody> createState() => _AuctionBodyState();
}

/// Rebuilds once, exactly when the auction closes, instead of every second:
/// only the countdown tiles tick.
class _AuctionBodyState extends ConsumerState<_AuctionBody> {
  Timer? _closing;

  Auction get auction => widget.auction;

  void _scheduleClose() {
    _closing?.cancel();
    final deadline = auction.deadline;
    if (deadline == null || !auction.isOpen) return;
    final left = deadline.difference(DateTime.now());
    if (left > Duration.zero) _closing = Timer(left, () => mounted ? setState(() {}) : null);
  }

  @override
  void initState() {
    super.initState();
    _scheduleClose();
  }

  @override
  void didUpdateWidget(_AuctionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auction.deadline != auction.deadline) _scheduleClose();
  }

  @override
  void dispose() {
    _closing?.cancel();
    super.dispose();
  }

  Future<void> _bid(BuildContext context) async {
    final placed = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => BidSheet(auction: auction),
    );
    if (placed != null && context.mounted) {
      ref
        ..invalidate(auctionProvider(auction.id))
        ..invalidate(auctionsProvider);
      unawaited(HapticFeedback.mediumImpact());
      showToast(context, context.l10n.bidPlaced, icon: AppIcons.gavel);
    }
  }

  Future<void> _cancel(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final isOwner = user != null && user.id == auction.auctioneerId;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.44).clamp(240.0, 460.0);
    final live = auction.isLive(DateTime.now());

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(auctionProvider(auction.id));
              await ref.read(auctionProvider(auction.id).future).catchError((Object _) => auction);
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: heroHeight,
                  backgroundColor: brand.paper,
                  automaticallyImplyLeading: false,
                  leading: Padding(
                    padding: const EdgeInsets.all(Space.xxs),
                    child: CircleIconButton(
                      icon: AppIcons.arrowLeft,
                      tooltip: l10n.back,
                      onPhoto: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  leadingWidth: 60,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: brand.surfaceMuted,
                          child: CollectibleImage(
                            auction.artwork,
                            cacheWidth: 900,
                            semanticLabel: auction.collectibleName,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, 0.3, 1],
                              colors: [Color(0x73000000), Color(0x00000000), Color(0x40000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: Space.gutter,
                          bottom: Space.lg,
                          child: live ? LivePill(label: l10n.liveLabel) : Tag(l10n.closedLabel, onPhoto: true),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Reveal(
                            child: Text(
                              auction.collectibleName ?? l10n.lotNumber(auction.id),
                              style: context.text.headlineMedium,
                            ),
                          ),
                          if (auction.auctioneerName != null) ...[
                            const SizedBox(height: Space.sm),
                            Reveal(
                              index: 1,
                              child: Row(
                                children: [
                                  UserAvatar(name: auction.auctioneerName!, size: 28),
                                  const SizedBox(width: Space.xs),
                                  Expanded(
                                    child: Text(
                                      '${l10n.auctioneer} · ${auction.auctioneerName}',
                                      style: context.text.bodyMedium?.copyWith(color: brand.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: Space.lg),
                          Reveal(
                            index: 2,
                            child: _BidPanel(auction: auction, live: live),
                          ),
                          const SizedBox(height: Space.xl),
                          Text(l10n.bidHistory, style: context.text.titleLarge),
                          const SizedBox(height: Space.sm),
                          _BidTimeline(bids: auction.bids),
                          const SizedBox(height: Space.xl),
                          OutlinedButton.icon(
                            onPressed: () => context.go(Routes.collectible(auction.collectibleId)),
                            icon: const Icon(AppIcons.fileText, size: 18),
                            label: Text(l10n.actionViewRecord),
                          ),
                          if (isOwner && live && auction.bidCount == 0) ...[
                            const SizedBox(height: Space.xs),
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: brand.danger),
                              onPressed: () => _cancel(context),
                              icon: const Icon(AppIcons.circleX, size: 18),
                              label: Text(l10n.cancelAuction),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        BottomCta(
          child: !live
              ? _Notice(icon: AppIcons.lock, text: l10n.auctionClosedNotice)
              : isOwner
              ? _Notice(icon: AppIcons.info, text: l10n.ownAuction)
              : user == null
              ? BusyButton(
                  label: l10n.signInToParticipate,
                  icon: AppIcons.logIn,
                  onPressed: () => context.push(
                    Uri(path: Routes.login, queryParameters: {'from': Routes.auction(auction.id)}).toString(),
                  ),
                )
              : BusyButton(
                  label: '${l10n.placeBid} · ${context.money(auction.minimumNextBid())}',
                  icon: AppIcons.gavel,
                  onPressed: () => _bid(context),
                ),
        ),
      ],
    );
  }
}

/// Countdown tiles, the current bid rolling in big figures and the opening
/// price, with a thin bar for the share of the window left.
class _BidPanel extends StatelessWidget {
  const _BidPanel({required this.auction, required this.live});
  final Auction auction;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final remaining = auction.remainingFraction(DateTime.now());
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (live) ...[
            Text(
              l10n.closesIn.toUpperCase(),
              style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: brand.live),
            ),
            const SizedBox(height: Space.xs),
            CountdownTiles(deadline: auction.deadline),
            if (remaining != null) ...[
              const SizedBox(height: Space.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: remaining),
                  duration: Motion.of(context, const Duration(milliseconds: 900)),
                  curve: Motion.enter,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    color: brand.live,
                    backgroundColor: brand.surfaceMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
          ],
          Text(live ? l10n.currentBid : l10n.finalPrice, style: context.text.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PriceText(auction.currentPrice, style: context.text.displaySmall, animate: true),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xxs,
            children: [
              Tag(l10n.bidsCount(auction.bidCount), icon: AppIcons.handCoins, color: brand.gold),
              Tag(
                '${l10n.startingPrice}: ${context.money(auction.startingPrice)}',
                icon: AppIcons.tag,
                color: brand.muted,
              ),
              if (auction.deadline != null)
                Tag(
                  l10n.closesAt(formatDateTime(auction.deadline!, context.languageCode)),
                  icon: AppIcons.calendarClock,
                  color: brand.muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bids as a vertical timeline: the leader crowned in gold, the rest as dots
/// on a hairline.
class _BidTimeline extends StatelessWidget {
  const _BidTimeline({required this.bids});
  final List<Bid> bids;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    if (bids.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            IconBadge(AppIcons.sparkles, color: brand.gold),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(l10n.noBids, style: context.text.bodyMedium)),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      child: Column(
        children: [
          for (final (index, bid) in bids.indexed)
            Reveal(
              index: index,
              offset: 10,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Expanded(child: Container(width: 1.5, color: index == 0 ? Colors.transparent : brand.line)),
                          if (index == 0)
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(color: brand.goldSoft, shape: BoxShape.circle),
                              child: Icon(AppIcons.crown, size: 16, color: brand.gold),
                            )
                          else
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: brand.surface,
                                border: Border.all(color: brand.muted, width: 1.5),
                              ),
                            ),
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: index == bids.length - 1 ? Colors.transparent : brand.line,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: Row(
                          children: [
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
                                    Text(timeAgo(context, bid.createdAt!), style: context.text.bodySmall),
                                ],
                              ),
                            ),
                            Text(
                              context.money(bid.amount),
                              style: Fonts.figures(
                                index == 0
                                    ? Fonts.display(context.text.titleMedium, weight: 700)
                                    : context.text.titleSmall,
                              ).copyWith(color: index == 0 ? brand.gold : brand.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(color: brand.surfaceMuted, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          Icon(icon, color: brand.muted, size: 20),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Bid entry: the amount large between − and + steppers, quick raises, and
/// a confirmation before anything is sent. Pops with the amount placed.
class BidSheet extends ConsumerStatefulWidget {
  const BidSheet({super.key, required this.auction});
  final Auction auction;

  @override
  ConsumerState<BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends ConsumerState<BidSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.auction.minimumNextBid().toStringAsFixed(0));
  bool _busy = false;
  String? _error;

  double get _step {
    final step = widget.auction.minimumNextBid() - widget.auction.currentPrice;
    return step > 0 ? step : 1;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _nudge(double delta) {
    final current = Validators.parseAmount(_amount.text) ?? widget.auction.minimumNextBid();
    final next = (current + delta).clamp(widget.auction.minimumNextBid(), double.infinity);
    HapticFeedback.selectionClick();
    setState(() => _amount.text = next.toStringAsFixed(0));
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
      icon: AppIcons.gavel,
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(auctionRepositoryProvider).placeBid(widget.auction.id, amount);
      if (mounted) Navigator.of(context).pop(amount);
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
              Text(l10n.yourBid, style: context.text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Space.xxs),
              Text(
                '${l10n.currentBid}: ${context.money(widget.auction.currentPrice)}',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: brand.muted),
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  CircleIconButton(
                    icon: AppIcons.minus,
                    tooltip: l10n.lowerBid,
                    size: 52,
                    onPressed: () => _nudge(-_step),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      style: Fonts.figures(Fonts.display(context.text.displaySmall, weight: 700)),
                      decoration: InputDecoration(
                        labelText: l10n.bidAmount,
                        floatingLabelAlignment: FloatingLabelAlignment.center,
                        prefixText: 'S/ ',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      validator: _validate,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  CircleIconButton(
                    icon: AppIcons.plus,
                    tooltip: l10n.raiseBid,
                    size: 52,
                    onPressed: () => _nudge(_step),
                  ),
                ],
              ),
              Text(l10n.minBid(context.money(minimum)), textAlign: TextAlign.center, style: context.text.bodySmall),
              const SizedBox(height: Space.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final steps in [1, 2, 5])
                    TapScale(
                      child: ActionChip(
                        avatar: const Icon(AppIcons.plus, size: 14),
                        label: Text(context.money(_step * steps)),
                        onPressed: () => setState(
                          () => _amount.text = (widget.auction.currentPrice + _step * steps).toStringAsFixed(0),
                        ),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: brand.danger),
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              BusyButton(label: l10n.confirmBidTitle, icon: AppIcons.gavel, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
