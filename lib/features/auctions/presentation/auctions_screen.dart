import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/account_button.dart';
import '../../../core/widgets/ui.dart';
import '../application/auction_providers.dart';
import '../domain/auction_models.dart';
import 'widgets/auction_card.dart';

class AuctionsScreen extends ConsumerStatefulWidget {
  const AuctionsScreen({super.key});

  @override
  ConsumerState<AuctionsScreen> createState() => _AuctionsScreenState();
}

class _AuctionsScreenState extends ConsumerState<AuctionsScreen> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auctions = ref.watch(auctionsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(auctionsProvider);
          await ref.read(auctionsProvider.future).catchError((Object _) => <Auction>[]);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: Space.gutter,
              title: Text(l10n.auctionsTitle),
              actions: const [
                AccountButton(),
                SizedBox(width: Space.xxs),
              ],
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(l10n.auctionsKicker),
                      const SizedBox(height: Space.xxs),
                      Text(l10n.auctionsIntro, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
                      const SizedBox(height: Space.xs),
                      FilterChip(
                        label: Text(l10n.auctionsShowClosed),
                        selected: _showClosed,
                        onSelected: (value) => setState(() => _showClosed = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...switch (auctions) {
              AsyncValue(:final value?) => () {
                final now = DateTime.now();
                final items = _showClosed ? value : value.where((a) => a.isLive(now)).toList();
                if (items.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(message: l10n.auctionsEmpty, icon: Icons.gavel_outlined),
                    ),
                  ];
                }
                return [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                      itemBuilder: (context, index) => ContentWidth(
                        child: AuctionCard(
                          auction: items[index],
                          onTap: () => context.go(Routes.auction(items[index].id)),
                        ),
                      ),
                    ),
                  ),
                ];
              }(),
              AsyncValue(:final error?) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(error: error, onRetry: () => ref.invalidate(auctionsProvider)),
                ),
              ],
              _ => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverList.separated(
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (_, _) => const AuctionCardSkeleton(),
                  ),
                ),
              ],
            },
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
          ],
        ),
      ),
    );
  }
}
