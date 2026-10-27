import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/artwork.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/slab.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../application/community_providers.dart';
import '../domain/community_models.dart';
import 'widgets/community_tile.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  FeedItemType? _filter;
  String _query = '';
  Timer? _debounce;
  bool _joining = false;

  /// True once the cover has scrolled under the toolbar; shows the name there.
  bool _collapsed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _toggleJoin(Community community) async {
    final l10n = context.l10n;
    if (ref.read(currentUserProvider) == null) {
      unawaited(context.push(Routes.login));
      return;
    }
    setState(() => _joining = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      community.isJoined ? await repo.leave(community.id) : await repo.join(community.id);
      ref
        ..invalidate(communityProvider(community.id))
        ..invalidate(communitiesProvider)
        ..invalidate(myCommunitiesProvider);
      if (mounted) showToast(context, community.isJoined ? l10n.leftMessage : l10n.joinedMessage);
    } catch (error) {
      if (mounted) showToast(context, describeError(error, l10n), error: true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openItem(FeedItem item) {
    switch (item.type) {
      case FeedItemType.collectible:
        context.go(Routes.collectible(item.id));
      case FeedItemType.auction:
        context.go(Routes.auction(item.id));
      case FeedItemType.post:
        context.push(Routes.post(item.id));
      case FeedItemType.other:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final community = ref.watch(communityProvider(widget.id));
    final feedArgs = (id: widget.id, query: _query);
    final feed = ref.watch(communityFeedProvider(feedArgs));

    return Scaffold(
      floatingActionButton: community.value?.isJoined == true
          ? FloatingActionButton.extended(
              heroTag: 'post-fab',
              onPressed: () => context.push(Routes.newPost(widget.id)),
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.newPost),
            )
          : null,
      body: AsyncSwitch(
        value: community,
        onRetry: () => ref.invalidate(communityProvider(widget.id)),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(communityProvider(widget.id))
              ..invalidate(communityFeedProvider(feedArgs));
            await ref.read(communityFeedProvider(feedArgs).future).catchError((Object _) => <FeedItem>[]);
          },
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) {
                final collapsed = notification.metrics.pixels > _coverHeight(context) - kToolbarHeight - 24;
                if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
              }
              return false;
            },
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                _CoverAppBar(community: data, height: _coverHeight(context), collapsed: _collapsed),
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (data.description.isNotEmpty) ...[
                            Text(data.description, style: context.text.bodyLarge),
                            const SizedBox(height: Space.md),
                          ],
                          BusyButton(
                            label: data.isJoined ? l10n.leave : l10n.join,
                            icon: data.isJoined ? Icons.logout : Icons.group_add_outlined,
                            outlined: data.isJoined,
                            busy: _joining,
                            onPressed: () => _toggleJoin(data),
                          ),
                          const SizedBox(height: Space.xl),
                          Semantics(header: true, child: Text(l10n.communityActivity, style: context.text.titleLarge)),
                          const SizedBox(height: Space.sm),
                          TextField(
                            textInputAction: TextInputAction.search,
                            onChanged: (value) {
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 350),
                                () => setState(() => _query = value.trim()),
                              );
                            },
                            decoration: searchDecoration(context, l10n.searchInCommunity),
                          ),
                          const SizedBox(height: Space.sm),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final (type, label) in [
                                  (null, l10n.filterAll),
                                  (FeedItemType.collectible, l10n.filterCollectibles),
                                  (FeedItemType.post, l10n.filterPosts),
                                  (FeedItemType.auction, l10n.filterAuctions),
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(right: Space.xs),
                                    child: ChoiceChip(
                                      label: Text(label),
                                      selected: _filter == type,
                                      onSelected: (_) => setState(() => _filter = type),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.md),
                        ],
                      ),
                    ),
                  ),
                ),
                ...switch (feed) {
                  AsyncValue(:final value?) => () {
                    final items = _filter == null ? value : value.where((item) => item.type == _filter).toList();
                    if (items.isEmpty) {
                      return [
                        SliverToBoxAdapter(
                          child: EmptyState(message: l10n.feedEmpty, icon: Icons.dynamic_feed_outlined),
                        ),
                      ];
                    }
                    return [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                          itemBuilder: (context, index) => ContentWidth(
                            child: items[index].type == FeedItemType.post
                                ? _PostCard(item: items[index], onTap: () => _openItem(items[index]))
                                : _MediaCard(item: items[index], onTap: () => _openItem(items[index])),
                          ),
                        ),
                      ),
                    ];
                  }(),
                  AsyncValue(:final error?) => [
                    SliverToBoxAdapter(
                      child: ErrorState(error: error, onRetry: () => ref.invalidate(communityFeedProvider(feedArgs))),
                    ),
                  ],
                  _ => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                        child: Skeleton(height: 200, radius: Radii.md),
                      ),
                    ),
                  ],
                },
                SliverToBoxAdapter(child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _coverHeight(BuildContext context) => (MediaQuery.sizeOf(context).width * 0.72).clamp(220.0, 360.0);
}

/// Cover photo with the community name, figures and membership on glass; the
/// name moves to the toolbar once the cover scrolls away.
class _CoverAppBar extends StatelessWidget {
  const _CoverAppBar({required this.community, required this.height, required this.collapsed});
  final Community community;
  final double height;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    return SliverAppBar(
      pinned: true,
      expandedHeight: height,
      backgroundColor: brand.paper,
      title: AnimatedSwitcher(
        duration: Motion.of(context, Motion.fast),
        child: collapsed
            ? Text(community.name, key: const ValueKey('title'), maxLines: 1, overflow: TextOverflow.ellipsis)
            : const SizedBox.shrink(),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: BackButton(
          style: IconButton.styleFrom(
            backgroundColor: brand.surface,
            foregroundColor: brand.ink,
            side: BorderSide(color: brand.line),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: brand.surfaceMuted,
              child: ExcludeSemantics(
                child: CollectibleImage(communityCover(community), fit: BoxFit.cover, cacheWidth: 900),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x26000000), Color(0x00000000), Color(0xCC000000)],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: Space.gutter,
              right: Space.gutter,
              bottom: Space.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      community.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  GlassPanel(
                    radius: Radii.pill,
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                    child: Text(
                      [
                        l10n.membersCount(community.memberCount),
                        l10n.postsCount(community.postCount),
                        if (community.isJoined) l10n.joined,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fonts.label(context.text.labelLarge, weight: 640).copyWith(color: Colors.white),
                    ),
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

String _feedKind(BuildContext context, FeedItemType type) => switch (type) {
  FeedItemType.collectible => context.l10n.pieceKind,
  FeedItemType.auction => context.l10n.auctionKind,
  FeedItemType.post => context.l10n.postKind,
  FeedItemType.other => '',
};

/// Piece or auction in the feed: photo first, then title, author and price.
class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item, required this.onTap});
  final FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    final auction = item.type == FeedItemType.auction;
    return Pressable(
      onTap: onTap,
      semanticLabel: item.title,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: brand.surfaceMuted,
                      child: CollectibleImage(
                        artworkFor(name: item.title, url: item.imageUrl),
                        fit: BoxFit.cover,
                        cacheWidth: 720,
                      ),
                    ),
                    Positioned(
                      left: Space.sm,
                      top: Space.sm,
                      child: auction
                          ? LiveBadge(label: _feedKind(context, item.type))
                          : GlassPanel(
                              radius: Radii.xs,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                _feedKind(context, item.type),
                                style: Fonts.label(context.text.labelMedium, weight: 680).copyWith(color: Colors.white),
                              ),
                            ),
                    ),
                    if (item.value != null)
                      Positioned(
                        right: Space.sm,
                        bottom: Space.sm,
                        child: PricePill(label: context.money(item.value!)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(item.title, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              [
                if (item.username != null) l10n.postBy(item.username!),
                if (item.createdAt != null) formatDate(item.createdAt!, context.languageCode),
              ].join(' · '),
              style: context.text.bodySmall?.copyWith(color: brand.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Text post in the feed: author line, title and an excerpt.
class _PostCard extends StatelessWidget {
  const _PostCard({required this.item, required this.onTap});
  final FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final author = item.username ?? '';
    final initial = author.isEmpty ? '?' : String.fromCharCode(author.runes.first).toUpperCase();
    return Pressable(
      onTap: onTap,
      semanticLabel: item.title,
      child: Card(
        margin: EdgeInsets.zero,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: brand.ink,
                      child: Text(initial, style: Fonts.display(context.text.labelLarge).copyWith(color: brand.paper)),
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        [
                          if (author.isNotEmpty) author,
                          if (item.createdAt != null) formatDate(item.createdAt!, context.languageCode),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: brand.muted),
                      ),
                    ),
                    Icon(Icons.notes_rounded, size: 18, color: brand.muted),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(item.title, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: Space.xxs),
                  Text(
                    item.description,
                    style: context.text.bodyMedium?.copyWith(color: brand.muted),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
