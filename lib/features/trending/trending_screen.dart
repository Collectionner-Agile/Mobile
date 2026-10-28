import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../catalog/application/catalog_providers.dart';

enum TrendingBoard { valuable, rated, bidded, newest }

/// Rankings at a glance: the most valuable pieces, the best rated, the
/// auctions drawing the most bids and the newest arrivals, each a top ten
/// with big serif ranks and the podium in gold, silver and bronze.
class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

typedef _Row = ({String title, String subtitle, String image, String figure, String route});

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  TrendingBoard _board = TrendingBoard.valuable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pieces = ref.watch(collectiblesProvider);
    final auctions = ref.watch(auctionsProvider);
    final value = _board == TrendingBoard.bidded
        ? auctions.whenData<List<_Row>>((all) {
            final sorted = [...all]..sort((a, b) => b.bidCount.compareTo(a.bidCount));
            return [
              for (final auction in sorted.take(10))
                (
                  title: auction.collectibleName ?? l10n.lotNumber(auction.id),
                  subtitle: '${l10n.currentBid} ${context.money(auction.currentPrice)}',
                  image: auction.artwork,
                  figure: l10n.bidsCount(auction.bidCount),
                  route: Routes.auction(auction.id),
                ),
            ];
          })
        : pieces.whenData<List<_Row>>((all) {
            final sorted = [...all];
            switch (_board) {
              case TrendingBoard.valuable:
                sorted.sort((a, b) => b.value.compareTo(a.value));
              case TrendingBoard.rated:
                sorted.sort((a, b) {
                  final byRating = b.rating.compareTo(a.rating);
                  return byRating != 0 ? byRating : b.reviewCount.compareTo(a.reviewCount);
                });
              case TrendingBoard.newest:
                sorted.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
              case TrendingBoard.bidded:
                break;
            }
            return [
              for (final piece in sorted.take(10))
                (
                  title: piece.name,
                  subtitle: piece.category ?? '',
                  image: piece.artwork,
                  figure: _board == TrendingBoard.rated
                      ? '★ ${piece.rating.toStringAsFixed(1)}'
                      : context.money(piece.value),
                  route: Routes.collectible(piece.id),
                ),
            ];
          });

    final boards = [
      (TrendingBoard.valuable, l10n.trendingValuable, AppIcons.gem),
      (TrendingBoard.rated, l10n.trendingRated, AppIcons.star),
      (TrendingBoard.bidded, l10n.trendingBidded, AppIcons.flame),
      (TrendingBoard.newest, l10n.trendingNewest, AppIcons.sparkles),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trendingTitle)),
      body: Column(
        children: [
          // All four boards visible at once: they wrap instead of scrolling.
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxs, Space.gutter, Space.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final (board, label, icon) in boards)
                    Padding(
                      padding: EdgeInsets.zero,
                      child: TapScale(
                        child: ChoiceChip(
                          avatar: Icon(
                            icon,
                            size: 15,
                            color: board == _board ? context.brand.onAccent : context.brand.gold,
                          ),
                          label: Text(label),
                          selected: board == _board,
                          onSelected: (_) => setState(() => _board = board),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncSwitch(
              value: value,
              onRetry: () => ref
                ..invalidate(collectiblesProvider)
                ..invalidate(auctionsProvider),
              data: (rows) => rows.isEmpty
                  ? Center(
                      child: EmptyState(icon: AppIcons.trendingUp, message: l10n.catalogEmpty),
                    )
                  : RevealWindow(
                      key: ValueKey(_board),
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          Space.gutter,
                          Space.sm,
                          Space.gutter,
                          Space.xxl + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                        itemBuilder: (context, index) => Reveal(
                          index: index,
                          child: ContentWidth(
                            child: _RankRow(rank: index + 1, row: rows[index]),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row});
  final int rank;
  final _Row row;

  static const _podium = [Color(0xFFD4A84B), Color(0xFFA8B0BD), Color(0xFFB87A4B)];

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final medal = rank <= 3 ? _podium[rank - 1] : null;
    return AppCard(
      onTap: () => context.push(row.route),
      padding: const EdgeInsets.all(Space.sm),
      color: rank == 1 ? Color.alphaBlend(brand.gold.withValues(alpha: 0.07), brand.surface) : null,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: Fonts.figures(Fonts.display(context.text.headlineMedium, weight: 720))
                  .copyWith(color: medal ?? brand.muted),
            ),
          ),
          const SizedBox(width: Space.xs),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox.square(
                  dimension: 58,
                  child: ColoredBox(color: brand.surfaceMuted, child: CollectibleImage(row.image, cacheWidth: 120)),
                ),
              ),
              if (medal != null)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: medal, shape: BoxShape.circle),
                    child: const Icon(AppIcons.crown, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (row.subtitle.isNotEmpty)
                  Text(row.subtitle, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  row.figure,
                  style: Fonts.figures(Fonts.display(context.text.titleSmall, weight: 700)).copyWith(color: brand.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
