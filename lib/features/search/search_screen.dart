import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/preferences.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/media/artwork.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/domain/auction_models.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/catalog_models.dart';
import '../catalog/presentation/widgets/collectible_card.dart';
import '../communities/application/community_providers.dart';
import '../communities/domain/community_models.dart';
import '../communities/presentation/widgets/community_tile.dart';

/// Last searches, newest first, kept on the device.
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

class RecentSearches extends Notifier<List<String>> {
  static const _key = 'pref.recentSearches';
  static const _max = 8;

  @override
  List<String> build() => ref.read(sharedPreferencesProvider).getStringList(_key) ?? const [];

  Future<void> add(String term) async {
    final value = term.trim();
    if (value.length < 2) return;
    state = [value, ...state.where((t) => t.toLowerCase() != value.toLowerCase())].take(_max).toList();
    await ref.read(sharedPreferencesProvider).setStringList(_key, state);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(sharedPreferencesProvider).remove(_key);
  }
}

/// One search across pieces, auctions and communities, grouped by kind.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => setState(() => _term = value.trim()));
  }

  void _use(String term) {
    _field
      ..text = term
      ..selection = TextSelection.collapsed(offset: term.length);
    setState(() => _term = term);
  }

  void _open(String route) {
    ref.read(recentSearchesProvider.notifier).add(_term);
    context.go(route);
  }

  bool _matches(String? text) => text != null && text.toLowerCase().contains(_term.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final pieces = ref.watch(collectiblesProvider).value ?? const [];
    final auctions = ref.watch(auctionsProvider).value ?? const [];
    final communities = ref.watch(communitiesProvider).value ?? const [];
    final recent = ref.watch(recentSearchesProvider);
    final categories = ref.watch(catalogCategoriesProvider);

    final foundPieces = _term.isEmpty
        ? const <Collectible>[]
        : pieces.where((p) => _matches(p.name) || _matches(p.category) || _matches(p.description)).toList();
    final foundAuctions = _term.isEmpty
        ? const <Auction>[]
        : auctions.where((a) => _matches(a.collectibleName)).toList();
    final foundCommunities = _term.isEmpty
        ? const <Community>[]
        : communities.where((c) => _matches(c.name) || _matches(c.description)).toList();
    final nothing = _term.isNotEmpty && foundPieces.isEmpty && foundAuctions.isEmpty && foundCommunities.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Space.md),
          child: TextField(
            controller: _field,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: (value) => ref.read(recentSearchesProvider.notifier).add(value),
            textInputAction: TextInputAction.search,
            decoration: searchDecoration(context, l10n.searchEverything).copyWith(
              suffixIcon: _term.isEmpty
                  ? null
                  : IconButton(tooltip: l10n.clear, icon: const Icon(Icons.close_rounded), onPressed: () => _use('')),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: Motion.of(context, Motion.base),
        child: _term.isEmpty
            ? ListView(
                key: const ValueKey('idle'),
                padding: const EdgeInsets.all(Space.gutter),
                children: [
                  if (recent.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(child: Text(l10n.recentSearches, style: context.text.titleLarge)),
                        TextButton(
                          onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
                          child: Text(l10n.clear),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    for (final (index, term) in recent.indexed)
                      Reveal(
                        index: index,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.history_rounded, color: brand.muted),
                          title: Text(term),
                          trailing: const Icon(Icons.north_west_rounded, size: 18),
                          onTap: () => _use(term),
                        ),
                      ),
                    const SizedBox(height: Space.lg),
                  ],
                  if (categories.isNotEmpty) ...[
                    Text(l10n.browseCategories, style: context.text.titleLarge),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        for (final category in categories)
                          ActionChip(
                            avatar: ClipOval(child: CollectibleImage(categoryArtwork(category), cacheWidth: 48)),
                            label: Text(category),
                            onPressed: () => _use(category),
                          ),
                      ],
                    ),
                  ],
                ],
              )
            : nothing
            ? ListView(
                key: const ValueKey('none'),
                children: [EmptyState(message: l10n.searchNoResults(_term), icon: Icons.search_off_rounded)],
              )
            : ListView(
                key: ValueKey('results-$_term'),
                padding: EdgeInsets.only(bottom: Space.xxl + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (foundPieces.isNotEmpty) ...[
                    SectionHeader(title: l10n.piecesCount(foundPieces.length)),
                    SizedBox(
                      height: 168 + collectibleCardTextHeight(context),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                        itemCount: foundPieces.length,
                        separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                        itemBuilder: (context, index) => Reveal(
                          index: index,
                          child: CollectibleCard(
                            width: 168,
                            item: foundPieces[index],
                            onTap: () => _open(Routes.collectible(foundPieces[index].id)),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (foundAuctions.isNotEmpty) ...[
                    SectionHeader(title: l10n.navAuctions),
                    for (final (index, auction) in foundAuctions.indexed)
                      Reveal(
                        index: index,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            child: SizedBox.square(
                              dimension: 52,
                              child: CollectibleImage(
                                artworkFor(name: auction.collectibleName ?? '', url: auction.collectibleImage),
                                cacheWidth: 104,
                              ),
                            ),
                          ),
                          title: Text(
                            auction.collectibleName ?? l10n.lotNumber(auction.id),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${l10n.currentBid} ${context.money(auction.currentPrice)}'),
                          trailing: auction.isLive(DateTime.now())
                              ? Icon(Icons.circle, size: 10, color: brand.live)
                              : null,
                          onTap: () => _open(Routes.auction(auction.id)),
                        ),
                      ),
                  ],
                  if (foundCommunities.isNotEmpty) ...[
                    SectionHeader(title: l10n.navCommunities),
                    for (final (index, community) in foundCommunities.indexed)
                      Reveal(
                        index: index,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                          leading: CommunityAvatar(community: community, size: 52),
                          title: Text(community.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(l10n.membersCount(community.memberCount)),
                          onTap: () => _open(Routes.community(community.id)),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
