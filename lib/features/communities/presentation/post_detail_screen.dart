import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/presentation/widgets/social_sections.dart';
import '../application/community_providers.dart';
import '../domain/community_models.dart';

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.id});
  final int id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Post post) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.deletePost,
      body: l10n.deletePostConfirm,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(communityRepositoryProvider).deletePost(post.id);
      if (post.communityId != null) {
        ref.invalidate(communityFeedProvider((id: post.communityId!, query: '')));
      }
      if (!context.mounted) return;
      showToast(context, l10n.postDeleted);
      context.pop();
    } catch (error) {
      if (context.mounted) showToast(context, describeError(error, l10n), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postProvider(id));
    final user = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    final brand = context.brand;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (post.value != null && user?.id == post.value!.authorId)
            IconButton(
              tooltip: l10n.deletePost,
              icon: Icon(Icons.delete_outline, color: brand.danger),
              onPressed: () => _delete(context, ref, post.value!),
            ),
        ],
      ),
      body: AsyncSwitch(
        value: post,
        onRetry: () => ref.invalidate(postProvider(id)),
        data: (data) => ListView(
          padding: EdgeInsets.only(bottom: Space.xxl + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(l10n.filterPosts.toUpperCase()),
                    const SizedBox(height: Space.xxs),
                    Text(data.title, style: context.text.headlineSmall),
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        if (data.authorName != null) l10n.postBy(data.authorName!),
                        if (data.createdAt != null) formatDateTime(data.createdAt!, context.languageCode),
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(color: brand.muted),
                    ),
                    const SizedBox(height: Space.lg),
                    SelectableText(data.content, style: context.text.bodyLarge),
                  ],
                ),
              ),
            ),
            ContentWidth(child: CommentsSection.post(postId: data.id)),
          ],
        ),
      ),
    );
  }
}
