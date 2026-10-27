import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/slab.dart';
import '../../core/widgets/ui.dart';
import '../auctions/domain/auction_models.dart';
import '../auctions/presentation/widgets/auction_card.dart';

/// Dark stage for the auctions closing soonest: a coverflow of full-bleed
/// cards over a blurred copy of the centred object.
class ClosingCoverflow extends StatefulWidget {
  const ClosingCoverflow({super.key, required this.auctions, required this.onOpen});
  final List<Auction> auctions;
  final ValueChanged<Auction> onOpen;

  @override
  State<ClosingCoverflow> createState() => _ClosingCoverflowState();
}

class _ClosingCoverflowState extends State<ClosingCoverflow> {
  PageController? _controller;
  double _fraction = 0;
  int _index = 0;

  /// The viewport fraction depends on the available width, so the controller
  /// is recreated (keeping the current page) when the width class changes.
  PageController _controllerFor(double fraction) {
    if (_controller == null || (fraction - _fraction).abs() > 0.001) {
      _controller?.dispose();
      _controller = PageController(viewportFraction: fraction, initialPage: _index);
      _fraction = fraction;
    }
    return _controller!;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _art(Auction auction) => artworkFor(name: auction.collectibleName ?? '', url: auction.collectibleImage);

  @override
  Widget build(BuildContext context) {
    final auctions = widget.auctions;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = math.min(width * 0.76, 320.0);
        final cardHeight = cardWidth * 1.5 + 170 * (textScale - 1);
        final controller = _controllerFor(cardWidth / width);
        final current = auctions[_index.clamp(0, auctions.length - 1)];
        return ClipRect(
          child: SizedBox(
            height: cardHeight + Space.xl * 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: BrandColors.dark.paper),
                ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.slow),
                    child: ImageFiltered(
                      key: ValueKey(current.id),
                      imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                      child: CollectibleImage(_art(current), fit: BoxFit.cover, cacheWidth: 160),
                    ),
                  ),
                ),
                const ColoredBox(color: Color(0xA6000000)),
                PageView.builder(
                  controller: controller,
                  itemCount: auctions.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      final page = controller.hasClients && controller.position.haveDimensions
                          ? controller.page ?? _index.toDouble()
                          : _index.toDouble();
                      final delta = (index - page).clamp(-1.0, 1.0);
                      return Transform(
                        alignment: delta > 0 ? Alignment.centerLeft : Alignment.centerRight,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(-delta * 0.38),
                        child: Transform.scale(
                          scale: 1 - 0.1 * delta.abs(),
                          child: Container(
                            foregroundDecoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45 * delta.abs()),
                              borderRadius: BorderRadius.circular(Radii.lg),
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xl),
                      child: _CoverCard(
                        auction: auctions[index],
                        image: _art(auctions[index]),
                        onTap: () => index == _index
                            ? widget.onOpen(auctions[index])
                            : controller.animateToPage(
                                index,
                                duration: Motion.of(context, Motion.slow),
                                curve: Motion.enter,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({required this.auction, required this.image, required this.onTap});
  final Auction auction;
  final String image;
  final VoidCallback onTap;

  static const _gold = Color(0xFFF2C14E);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = auction.collectibleName ?? l10n.lotNumber(auction.id);
    return Semantics(
      button: true,
      label: '$name, ${l10n.currentBid} ${context.money(auction.currentPrice)}',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: BrandColors.dark.surfaceMuted,
                child: ExcludeSemantics(child: CollectibleImage(image, fit: BoxFit.cover, cacheWidth: 640)),
              ),
              const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
              Positioned(
                top: Space.sm,
                left: Space.sm,
                child: LiveBadge(label: l10n.liveNow),
              ),
              Positioned(
                left: Space.sm,
                right: Space.sm,
                bottom: Space.sm,
                child: GlassPanel(
                  padding: const EdgeInsets.all(Space.sm),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Fonts.display(context.text.titleMedium, weight: 780).copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: Space.xxs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                context.money(auction.currentPrice),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Fonts.figures(context.text.titleLarge)
                                    .copyWith(color: Colors.white, fontVariations: Fonts.axes(width: 100, weight: 720)),
                              ),
                            ),
                            const SizedBox(width: Space.xs),
                            Text(
                              l10n.bidsCount(auction.bidCount),
                              style: context.text.bodySmall?.copyWith(color: const Color(0xB3FFFFFF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.xs),
                        CountdownBlocks(auction: auction, onDark: true, compact: true),
                        const SizedBox(height: Space.sm),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: const Color(0xFF241500),
                            minimumSize: const Size.fromHeight(44),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: onTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text(l10n.viewAuction, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: Space.xs),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
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
