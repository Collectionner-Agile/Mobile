import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/account_button.dart';
import '../../../core/widgets/ui.dart';
import '../application/community_providers.dart';
import '../domain/community_models.dart';
import 'widgets/community_tile.dart';

class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _term = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(communitySearchProvider(_term));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'community-fab',
        onPressed: () => context.push(Routes.newCommunity),
        icon: const Icon(Icons.add),
        label: Text(l10n.createCommunity),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communitiesProvider);
          ref.invalidate(communitySearchProvider(_term));
          await ref.read(communitySearchProvider(_term).future).catchError((Object _) => <Community>[]);
        },
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: Space.gutter,
              title: Text(l10n.communitiesTitle),
              actions: const [
                AccountButton(),
                SizedBox(width: Space.xxs),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
                  child: TextField(
                    controller: _search,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: searchDecoration(context, l10n.searchCommunities),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(l10n.communitiesKicker),
                    const SizedBox(height: Space.xxs),
                    Text(l10n.communitiesIntro, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
                  ],
                ),
              ),
            ),
            ...switch (results) {
              AsyncValue(:final value?) when value.isEmpty => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    message: _term.isEmpty ? l10n.communitiesEmpty : l10n.communitiesNoResults,
                    icon: Icons.forum_outlined,
                  ),
                ),
              ],
              AsyncValue(:final value?) => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverList.separated(
                    itemCount: value.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (context, index) => ContentWidth(
                      child: CommunityTile(
                        community: value[index],
                        onTap: () => context.go(Routes.community(value[index].id)),
                      ),
                    ),
                  ),
                ),
              ],
              AsyncValue(:final error?) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(error: error, onRetry: () => ref.invalidate(communitySearchProvider(_term))),
                ),
              ],
              _ => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverList.separated(
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (_, _) => const Skeleton(height: 104, radius: Radii.md),
                  ),
                ),
              ],
            },
            SliverToBoxAdapter(child: SizedBox(height: 88 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}
