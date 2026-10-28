import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/kit.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/auction_models.dart';

/// Live auctions as a showcase you swipe through: the centred card stands
/// forward while its neighbours recede, each with its own countdown.
class LiveAuctionCarousel extends StatefulWidget {
  const LiveAuctionCarousel({super.key, required this.auctions, required this.onOpen});
  final List<Auction> auctions;
  final ValueChanged<Auction> onOpen;

  @override
  State<LiveAuctionCarousel> createState() => _LiveAuctionCarouselState();
}

class _LiveAuctionCarouselState extends State<LiveAuctionCarousel> {
  late final PageController _pages = PageController(viewportFraction: 0.86);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).width * 0.86 * 1.1).clamp(300.0, 460.0);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.auctions.length,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _index = index);
            },
            itemBuilder: (context, index) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final page = _pages.hasClients && _pages.position.haveDimensions
                    ? (_pages.page ?? _index.toDouble())
                    : _index.toDouble();
                final distance = (page - index).abs().clamp(0.0, 1.0);
                return Transform.scale(
                  scale: 1 - 0.06 * distance,
                  child: Opacity(opacity: 1 - 0.35 * distance, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _LiveAuctionCard(
                  auction: widget.auctions[index],
                  onTap: () => widget.onOpen(widget.auctions[index]),
                ),
              ),
            ),
          ),
        ),
        if (widget.auctions.length > 1) ...[
          const SizedBox(height: Space.md),
          DotsIndicator(count: widget.auctions.length, index: _index),
        ],
      ],
    );
  }
}

class _LiveAuctionCard extends StatelessWidget {
  const _LiveAuctionCard({required this.auction, required this.onTap});
  final Auction auction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      radius: Radii.xl,
      semanticLabel: '${auction.collectibleName ?? ''}, ${l10n.currentBid} ${context.money(auction.currentPrice)}',
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: brand.surfaceMuted, child: CollectibleImage(auction.artwork, cacheWidth: 720)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.3, 0.55, 1],
                  colors: [Color(0x66000000), Color(0x00000000), Color(0x14000000), Color(0xE6060A14)],
                ),
              ),
            ),
            Positioned(
              left: Space.md,
              top: Space.md,
              right: Space.md,
              // Wraps under the pill when large text leaves no room beside it.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  LivePill(label: l10n.liveLabel),
                  CountdownTiles(deadline: auction.deadline, onPhoto: true, compact: true),
                ],
              ),
            ),
            Positioned(
              left: Space.lg,
              right: Space.lg,
              bottom: Space.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auction.collectibleName ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Fonts.display(context.text.headlineMedium, weight: 660).copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.currentBid} · ${l10n.bidsCount(auction.bidCount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(color: const Color(0xCCFFFFFF)),
                            ),
                            PriceText(auction.currentPrice, style: context.text.headlineSmall, color: Brand.goldLight),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
                        decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(Radii.pill)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.placeBid,
                              style: Fonts.label(
                                context.text.labelLarge,
                                weight: 700,
                              ).copyWith(color: const Color(0xFF1A1305)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(AppIcons.arrowUpRight, size: 16, color: Color(0xFF1A1305)),
                          ],
                        ),
                      ),
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
