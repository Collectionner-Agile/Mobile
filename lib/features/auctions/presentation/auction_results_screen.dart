import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/auction_providers.dart';

/// Finished auctions and what they closed at: totals on top, then each lot
/// with its final price, the winning bidder and how many bids it drew.
class AuctionResultsScreen extends ConsumerWidget {
  const AuctionResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final auctions = ref.watch(auctionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultsTitle)),
      body: AsyncSwitch(
        value: auctions,
        onRetry: () => ref.invalidate(auctionsProvider),
        data: (all) {
          final now = DateTime.now();
          final closed = all.where((a) => !a.isLive(now)).toList()
            ..sort((a, b) => (b.deadline ?? now).compareTo(a.deadline ?? now));
          if (closed.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: l10n.noClosedAuctions,
                  body: l10n.resultsEmptyBody,
                ),
              ),
            );
          }
          final sold = closed.where((a) => a.bidCount > 0).toList();
          final total = sold.fold<double>(0, (sum, a) => sum + a.currentPrice);
          final top = sold.isEmpty ? null : sold.reduce((a, b) => a.currentPrice >= b.currentPrice ? a : b);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              Space.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              ContentWidth(
                child: Reveal(
                  child: HeroPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.resultsTotal.toUpperCase(),
                          style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: const Color(0xB3FFFFFF)),
                        ),
                        const SizedBox(height: Space.xxs),
                        PriceText(total, style: context.text.displaySmall, color: Brand.chalk, animate: true),
                        const SizedBox(height: Space.md),
                        Row(
                          children: [
                            Expanded(
                              child: _HeroFigure(value: '${closed.length}', label: l10n.resultsClosed),
                            ),
                            Expanded(
                              child: _HeroFigure(value: '${sold.length}', label: l10n.resultsSold),
                            ),
                            if (top != null)
                              Expanded(
                                child: _HeroFigure(value: context.money(top.currentPrice), label: l10n.resultsTop),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              for (final (index, auction) in closed.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: ContentWidth(
                    child: Reveal(
                      index: index + 1,
                      child: AppCard(
                        onTap: () => context.push(Routes.auction(auction.id)),
                        padding: const EdgeInsets.all(Space.sm),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(Radii.md),
                              child: SizedBox.square(
                                dimension: 76,
                                child: ColoredBox(
                                  color: brand.surfaceMuted,
                                  child: CollectibleImage(auction.artwork, cacheWidth: 160),
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auction.collectibleName ?? l10n.lotNumber(auction.id),
                                    style: context.text.titleSmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  PriceText(auction.currentPrice, style: context.text.titleMedium),
                                  const SizedBox(height: Space.xxs),
                                  Wrap(
                                    spacing: Space.xs,
                                    runSpacing: Space.xxs,
                                    children: [
                                      if (auction.bids.isNotEmpty)
                                        Tag(
                                          auction.bids.first.bidderName ?? '—',
                                          icon: Icons.workspace_premium_outlined,
                                          color: brand.gold,
                                        )
                                      else
                                        Tag(l10n.resultsUnsold, icon: Icons.cancel_outlined, color: brand.muted),
                                      Tag(l10n.bidsCount(auction.bidCount), color: brand.muted),
                                      if (auction.deadline != null)
                                        Tag(formatDate(auction.deadline!, context.languageCode), color: brand.muted),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Fonts.figures(Fonts.display(context.text.titleLarge, weight: 680)).copyWith(color: Brand.chalk),
      ),
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(color: const Color(0xB3F5F1E7)),
      ),
    ],
  );
}
