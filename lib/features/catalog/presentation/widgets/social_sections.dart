import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/ui.dart';
import '../../../auth/application/session_controller.dart';
import '../../../communities/application/community_providers.dart';
import '../../application/catalog_providers.dart';
import '../../domain/catalog_models.dart';

class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({super.key, required this.collectibleId, required this.ownerId});
  final int collectibleId;
  final int ownerId;

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    final published = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(collectibleId: collectibleId),
    );
    if (published == true && context.mounted) {
      ref
        ..invalidate(collectibleReviewsProvider(collectibleId))
        ..invalidate(collectibleProvider(collectibleId));
      showToast(context, context.l10n.reviewPublished);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reviews = ref.watch(collectibleReviewsProvider(collectibleId));
    final user = ref.watch(currentUserProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.reviews,
          actionLabel: user == null ? l10n.signIn : (user.id == ownerId ? null : l10n.writeReview),
          onAction: user == null
              ? () => context.push(Routes.login)
              : (user.id == ownerId ? null : () => _write(context, ref)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: AsyncSwitch(
            value: reviews,
            onRetry: () => ref.invalidate(collectibleReviewsProvider(collectibleId)),
            loading: const Skeleton(height: 64, radius: Radii.md),
            data: (items) => items.isEmpty
                ? _Muted(l10n.noReviews)
                : Column(children: [for (final review in items) _ReviewTile(review: review)]),
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: brand.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.userName, style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
              ),
              RatingStars(rating: review.rating.toDouble(), size: 14),
            ],
          ),
          if (review.createdAt != null)
            Text(
              formatDate(review.createdAt!, context.languageCode),
              style: context.text.bodySmall?.copyWith(color: brand.muted),
            ),
          const SizedBox(height: Space.xxs),
          Text(review.content, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.collectibleId});
  final int collectibleId;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _form = GlobalKey<FormState>();
  final _content = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(catalogRepositoryProvider).addReview(widget.collectibleId, _content.text.trim(), _rating);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.writeReview, style: context.text.titleLarge),
              const SizedBox(height: Space.md),
              Text(l10n.yourRating, style: context.text.labelLarge),
              Semantics(
                label: l10n.yourRating,
                value: l10n.ratingOutOfFive('$_rating'),
                child: Row(
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        tooltip: l10n.ratingOutOfFive('$star'),
                        onPressed: () => setState(() => _rating = star),
                        icon: Icon(
                          star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: brand.accent,
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
              TextFormField(
                controller: _content,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.reviewHint, alignLabelWithHint: true),
                validator: (value) => Validators(l10n).minLength(value, 3),
              ),
              if (_error != null) _InlineError(_error!),
              const SizedBox(height: Space.sm),
              BusyButton(label: l10n.send, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comment thread used by collectibles and community posts.
class CommentsSection extends ConsumerWidget {
  const CommentsSection._({required this.provider, required this.post, required this.invalidate});

  factory CommentsSection.collectible({required int collectibleId}) => CommentsSection._(
    provider: collectibleCommentsProvider(collectibleId),
    post: (ref, body) => ref.read(catalogRepositoryProvider).addComment(collectibleId, body),
    invalidate: (ref) => ref.invalidate(collectibleCommentsProvider(collectibleId)),
  );

  factory CommentsSection.post({required int postId}) => CommentsSection._(
    provider: postCommentsProvider(postId),
    post: (ref, body) => ref.read(communityRepositoryProvider).addPostComment(postId, body),
    invalidate: (ref) => ref.invalidate(postCommentsProvider(postId)),
  );

  final ProviderListenable<AsyncValue<List<Comment>>> provider;
  final Future<Comment> Function(WidgetRef ref, String body) post;
  final void Function(WidgetRef ref) invalidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final comments = ref.watch(provider);
    final user = ref.watch(currentUserProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.comments),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AsyncSwitch(
                value: comments,
                onRetry: () => invalidate(ref),
                loading: const Skeleton(height: 56, radius: Radii.md),
                data: (items) => items.isEmpty
                    ? _Muted(l10n.noComments)
                    : Column(children: [for (final comment in items) _CommentTile(comment: comment)]),
              ),
              const SizedBox(height: Space.sm),
              if (user == null)
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.login),
                  icon: const Icon(AppIcons.logIn),
                  label: Text(l10n.signInToParticipate),
                )
              else
                _CommentComposer(
                  onSend: (body) async {
                    await post(ref, body);
                    invalidate(ref);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initial = comment.authorName.isEmpty
        ? '?'
        : String.fromCharCode(comment.authorName.runes.first).toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: brand.surface,
            child: Text(initial, style: context.text.labelLarge?.copyWith(color: brand.ink)),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(comment.authorName, style: context.text.titleSmall),
                    if (comment.createdAt != null)
                      Text(
                        formatDate(comment.createdAt!, context.languageCode),
                        style: context.text.bodySmall?.copyWith(color: brand.muted),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({required this.onSend});
  final Future<void> Function(String body) onSend;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSend(body);
      _controller.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        showToast(context, context.l10n.commentPublished);
      }
    } catch (error) {
      if (mounted) showToast(context, describeError(error, context.l10n), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: 4,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: l10n.commentHint,
        counterText: '',
        suffixIcon: _busy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(tooltip: l10n.send, icon: const Icon(AppIcons.send), onPressed: _send),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.sm),
    child: Text(text, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xs),
    child: Semantics(
      liveRegion: true,
      child: Text(message, style: context.text.bodySmall?.copyWith(color: context.brand.danger)),
    ),
  );
}
