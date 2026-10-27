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
import '../../../core/widgets/pressable.dart';
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
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverAppBar(pinned: true, title: Text(data.name, overflow: TextOverflow.ellipsis)),
              SliverToBoxAdapter(
                child: ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CommunityAvatar(community: data, size: 56),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data.name, style: context.text.titleLarge),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l10n.membersCount(data.memberCount)} · ${l10n.postsCount(data.postCount)}',
                                    style: context.text.bodySmall?.copyWith(color: context.brand.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        Text(data.description, style: context.text.bodyMedium),
                        const SizedBox(height: Space.md),
                        BusyButton(
                          label: data.isJoined ? l10n.leave : l10n.join,
                          icon: data.isJoined ? Icons.logout : Icons.group_add_outlined,
                          outlined: data.isJoined,
                          busy: _joining,
                          onPressed: () => _toggleJoin(data),
                        ),
                        const SizedBox(height: Space.lg),
                        Text(l10n.feedTitle, style: context.text.titleMedium),
                        const SizedBox(height: Space.xs),
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
                        const SizedBox(height: Space.xs),
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
                        const SizedBox(height: Space.sm),
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
                        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                        itemBuilder: (context, index) => ContentWidth(
                          child: _FeedCard(item: items[index], onTap: () => _openItem(items[index])),
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
                      child: Skeleton(height: 96, radius: Radii.md),
                    ),
                  ),
                ],
              },
              SliverToBoxAdapter(child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item, required this.onTap});
  final FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    final (icon, label) = switch (item.type) {
      FeedItemType.collectible => (Icons.inventory_2_outlined, l10n.filterCollectibles),
      FeedItemType.post => (Icons.notes, l10n.filterPosts),
      FeedItemType.auction => (Icons.gavel, l10n.filterAuctions),
      FeedItemType.other => (Icons.circle_outlined, ''),
    };
    return Pressable(
      onTap: onTap,
      semanticLabel: item.title,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null ||
                  item.type == FeedItemType.collectible ||
                  item.type == FeedItemType.auction) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: CollectibleImage(artworkFor(name: item.title, url: item.imageUrl), cacheWidth: 72),
                  ),
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 14, color: brand.accentStrong),
                        const SizedBox(width: 4),
                        Flexible(child: Kicker(label.toUpperCase())),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        style: context.text.bodySmall?.copyWith(color: brand.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      [
                        if (item.username != null) l10n.postBy(item.username!),
                        if (item.createdAt != null) formatDate(item.createdAt!, context.languageCode),
                        if (item.value != null && item.type != FeedItemType.post) context.money(item.value!),
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(color: brand.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
