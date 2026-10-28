import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/ui.dart';
import '../auctions/domain/auction_models.dart';
import '../catalog/domain/catalog_models.dart';

/// One bid with the lot it belongs to, newest first.
typedef BidEvent = ({Bid bid, Auction auction});

List<BidEvent> recentBids(List<Auction> auctions, {int limit = 8}) {
  final events = [
    for (final auction in auctions)
      for (final bid in auction.bids)
        if (bid.createdAt != null) (bid: bid, auction: auction),
  ]..sort((a, b) => b.bid.createdAt!.compareTo(a.bid.createdAt!));
  return events.take(limit).toList();
}

/// "hace 5 min" style time for activity rows.
String timeAgo(BuildContext context, DateTime when) {
  final l10n = context.l10n;
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
  return l10n.daysAgo(diff.inDays);
}

/// Live strip of the latest bids scrolling in a seamless loop ("Marquee"
/// reference). Static, showing the newest bid, when motion is reduced.
class BidTicker extends StatefulWidget {
  const BidTicker({super.key, required this.events});
  final List<BidEvent> events;

  @override
  State<BidTicker> createState() => _BidTickerState();
}

class _BidTickerState extends State<BidTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Duration(seconds: 6 * widget.events.length.clamp(2, 8)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Widget _item(BuildContext context, BidEvent event) {
    final brand = context.brand;
    final name = event.auction.collectibleName ?? context.l10n.lotNumber(event.auction.id);
    return Padding(
      padding: const EdgeInsets.only(right: Space.xl),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: event.bid.bidderName ?? '—',
              style: TextStyle(color: brand.ink, fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '  ${context.l10n.bidOn}  ',
              style: TextStyle(color: brand.muted),
            ),
            TextSpan(
              text: name,
              style: TextStyle(color: brand.ink),
            ),
            TextSpan(
              text: '  ${context.money(event.bid.amount)}',
              style: Fonts.figures(Fonts.display(null, weight: 700)).copyWith(color: brand.live),
            ),
          ],
        ),
        maxLines: 1,
        style: context.text.bodyMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    final events = widget.events;
    final row = Row(mainAxisSize: MainAxisSize.min, children: [for (final e in events) _item(context, e)]);
    return Semantics(
      label: '${l10n.liveBids}: ${events.map((e) => '${e.bid.bidderName} ${context.money(e.bid.amount)}').join(', ')}',
      child: ExcludeSemantics(
        child: Container(
          height: 44 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: brand.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                alignment: Alignment.center,
                color: brand.live,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Pulse(color: brand.onLive),
                    const SizedBox(width: 6),
                    Text(
                      l10n.liveNow,
                      style: Fonts.label(context.text.labelMedium, weight: 700).copyWith(color: brand.onLive),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, constraints) => AnimatedBuilder(
                      animation: _loop,
                      builder: (context, _) => OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxWidth: double.infinity,
                        child: _MarqueeRow(progress: _loop.value, child: row),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws two copies of [child] side by side and shifts them by one copy's
/// width over a full cycle, so the loop has no seam.
class _MarqueeRow extends StatelessWidget {
  const _MarqueeRow({required this.progress, required this.child});
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => _MarqueeLayout(
    progress: progress,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: Space.md),
        child: child,
      ),
      Padding(
        padding: const EdgeInsets.only(left: Space.md),
        child: child,
      ),
    ],
  );
}

class _MarqueeLayout extends MultiChildRenderObjectWidget {
  const _MarqueeLayout({required this.progress, required super.children});
  final double progress;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMarquee(progress);

  @override
  void updateRenderObject(BuildContext context, _RenderMarquee renderObject) => renderObject.progress = progress;
}

class _MarqueeParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMarquee extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MarqueeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MarqueeParentData> {
  _RenderMarquee(this._progress);
  double _progress;
  set progress(double value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MarqueeParentData) child.parentData = _MarqueeParentData();
  }

  @override
  void performLayout() {
    var x = 0.0;
    var height = 0.0;
    var first = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints(maxHeight: constraints.maxHeight), parentUsesSize: true);
      if (first == 0) first = child.size.width;
      height = math.max(height, child.size.height);
      child = childAfter(child);
    }
    final shift = -first * _progress;
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as _MarqueeParentData;
      data.offset = Offset(
        x + shift,
        (constraints.maxHeight.isFinite ? constraints.maxHeight - child.size.height : 0) / 2,
      );
      x += child.size.width;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(x, constraints.maxHeight.isFinite ? constraints.maxHeight : height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => false;
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.color});
  final Color color;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 14,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 6 + 8 * _c.value,
            height: 6 + 8 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.5 * (1 - _c.value)),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
          ),
        ],
      ),
    ),
  );
}

/// The most valuable piece, lit by a soft light that drifts across the photo
/// and follows the finger ("Card Spotlight" reference).
class FeaturedSpotlight extends StatefulWidget {
  const FeaturedSpotlight({super.key, required this.item, required this.onTap});
  final Collectible item;
  final VoidCallback onTap;

  @override
  State<FeaturedSpotlight> createState() => _FeaturedSpotlightState();
}

class _FeaturedSpotlightState extends State<FeaturedSpotlight> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  Offset? _touch;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = context.l10n;
    return Pressable(
      onTap: widget.onTap,
      semanticLabel: '${item.name}, ${context.money(item.value)}',
      borderRadius: Radii.lg,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: AspectRatio(
            aspectRatio: 4 / 4.6,
            child: LayoutBuilder(
              builder: (context, constraints) => Listener(
                onPointerMove: (event) => setState(() => _touch = event.localPosition),
                onPointerUp: (_) => setState(() => _touch = null),
                onPointerCancel: (_) => setState(() => _touch = null),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: BrandColors.dark.surfaceMuted,
                      child: CollectibleImage(item.artwork, fit: BoxFit.cover, cacheWidth: 900),
                    ),
                    const ColoredBox(color: Color(0x33000000)),
                    AnimatedBuilder(
                      animation: _drift,
                      builder: (context, _) {
                        final t = Curves.easeInOut.transform(_drift.value);
                        final auto = Offset(
                          constraints.maxWidth * (0.15 + 0.7 * t),
                          constraints.maxHeight * (0.25 + 0.2 * math.sin(t * math.pi)),
                        );
                        final at = _touch ?? auto;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(
                                at.dx / constraints.maxWidth * 2 - 1,
                                at.dy / constraints.maxHeight * 2 - 1,
                              ),
                              radius: 0.75,
                              colors: const [Color(0x38FFF3D6), Color(0x00FFF3D6)],
                            ),
                          ),
                        );
                      },
                    ),
                    const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
                    Positioned(
                      left: Space.md,
                      right: Space.md,
                      bottom: Space.md,
                      child: GlassPanel(
                        padding: const EdgeInsets.all(Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.headlineSmall?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: Space.xxs),
                            Row(
                              children: [
                                if (item.category != null)
                                  Flexible(
                                    child: Text(
                                      item.category!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall?.copyWith(color: const Color(0xCCFFFFFF)),
                                    ),
                                  ),
                                if (item.reviewCount > 0) ...[
                                  const SizedBox(width: Space.sm),
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF2C14E)),
                                  const SizedBox(width: 2),
                                  Text(
                                    item.rating.toStringAsFixed(1),
                                    style: context.text.bodySmall?.copyWith(color: const Color(0xCCFFFFFF)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            Row(
                              children: [
                                Flexible(child: PricePill(label: context.money(item.value))),
                                const Spacer(),
                                Text(l10n.viewPiece, style: context.text.labelLarge?.copyWith(color: Colors.white)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Latest bids as a short timeline.
class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key, required this.events, required this.onOpen});
  final List<BidEvent> events;
  final ValueChanged<Auction> onOpen;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: brand.line),
      ),
      child: Column(
        children: [
          for (final (index, event) in events.indexed) ...[
            if (index > 0) Divider(height: 1, indent: 64, color: brand.line),
            InkWell(
              onTap: () => onOpen(event.auction),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: SizedBox.square(
                        dimension: 36,
                        child: CollectibleImage(
                          artworkFor(name: event.auction.collectibleName ?? '', url: event.auction.collectibleImage),
                          cacheWidth: 72,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.bidActivity(event.bid.bidderName ?? '—', context.money(event.bid.amount)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall,
                          ),
                          Text(
                            event.auction.collectibleName ?? l10n.lotNumber(event.auction.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(color: brand.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Text(
                      timeAgo(context, event.bid.createdAt!),
                      style: context.text.labelMedium?.copyWith(color: brand.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
