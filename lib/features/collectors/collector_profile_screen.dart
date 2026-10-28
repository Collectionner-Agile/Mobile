import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/presentation/widgets/auction_card.dart';
import '../auth/domain/user.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/presentation/widgets/collectible_card.dart';

final collectorProvider = FutureProvider.autoDispose.family<AppUser, int>(
  (ref, id) => ref.watch(authRepositoryProvider).publicProfile(id),
);

/// Another collector's page: who they are, what their pieces add up to,
/// their open auctions and their pieces. When the profile cannot be loaded,
/// the pieces still show under the name we know from them.
class CollectorProfileScreen extends ConsumerWidget {
  const CollectorProfileScreen({super.key, required this.id, this.name});
  final int id;

  /// Name already known from where the user came from (the piece's owner).
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final profile = ref.watch(collectorProvider(id));
    final pieces = (ref.watch(collectiblesProvider).value ?? const []).where((p) => p.ownerId == id).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final now = DateTime.now();
    final auctions = (ref.watch(auctionsProvider).value ?? const [])
        .where((a) => a.auctioneerId == id && a.isLive(now))
        .toList();
    final user = profile.value;
    final displayName = user?.name ?? name ?? (pieces.isEmpty ? '—' : pieces.first.ownerName ?? '—');
    final total = pieces.fold<double>(0, (sum, p) => sum + p.value);

    return Scaffold(
      appBar: AppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AmbientGlow(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
                child: ContentWidth(
                  child: Column(
                    children: [
                      Reveal(
                        child: UserAvatar(name: displayName, url: user?.avatarUrl, size: 88, ring: true),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(displayName, textAlign: TextAlign.center, style: context.text.headlineMedium),
                      if (user != null)
                        Text('@${user.username}', style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                      if (user?.bio != null && user!.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        Text(user.bio!, textAlign: TextAlign.center, style: context.text.bodyMedium),
                      ],
                      const SizedBox(height: Space.sm),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Space.xs,
                        runSpacing: Space.xxs,
                        children: [
                          if (user?.location != null) Tag(user!.location!, icon: AppIcons.mapPin, color: brand.muted),
                          if (user?.memberSince != null)
                            Tag(
                              l10n.memberSince(formatDate(user!.memberSince!, context.languageCode)),
                              icon: AppIcons.calendar,
                              color: brand.muted,
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: StatTile(value: '${pieces.length}', label: l10n.statPieces),
                            ),
                            Expanded(
                              child: StatTile(
                                value: context.money(total),
                                label: l10n.collectorValue,
                                icon: AppIcons.gem,
                              ),
                            ),
                            Expanded(
                              child: StatTile(
                                value: '${auctions.length}',
                                label: l10n.liveLabel,
                                icon: AppIcons.gavel,
                                color: brand.live,
                              ),
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
          if (auctions.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title: l10n.collectorAuctions)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.separated(
                itemCount: auctions.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, index) => ContentWidth(
                  child: AuctionCard(
                    auction: auctions[index],
                    onTap: () => context.push(Routes.auction(auctions[index].id)),
                  ),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SectionHeader(title: l10n.collectorPieces)),
          if (pieces.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(icon: AppIcons.gem, message: l10n.collectorNoPieces),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) => SliverGrid.builder(
                  gridDelegate: pieceGridDelegate(context, constraints.crossAxisExtent),
                  itemCount: pieces.length,
                  itemBuilder: (context, index) => Reveal(
                    index: index,
                    child: CollectibleCard(
                      item: pieces[index],
                      onTap: () => context.push(Routes.collectible(pieces[index].id)),
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
