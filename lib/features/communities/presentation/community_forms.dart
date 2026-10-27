import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ui.dart';
import '../application/community_providers.dart';

/// Shared scaffold for the two simple publishing forms of this feature.
class _FormPage extends StatelessWidget {
  const _FormPage({
    required this.title,
    required this.intro,
    required this.form,
    required this.fields,
    required this.footer,
  });
  final String title;
  final String intro;
  final GlobalKey<FormState> form;
  final List<Widget> fields;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      top: false,
      child: Form(
        key: form,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xxl),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(intro, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
                  const SizedBox(height: Space.lg),
                  ...fields,
                  const SizedBox(height: Space.xl),
                  footer,
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref.read(communityRepositoryProvider).create(_name.text.trim(), _description.text.trim());
      ref
        ..invalidate(communitiesProvider)
        ..invalidate(myCommunitiesProvider);
      if (!mounted) return;
      showToast(context, l10n.communityCreated);
      context.go(Routes.community(created.id));
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    return _FormPage(
      title: l10n.createCommunity,
      intro: l10n.createCommunityIntro,
      form: _form,
      fields: [
        TextFormField(
          controller: _name,
          maxLength: 150,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l10n.communityName),
          validator: (value) => validators.minLength(value, 3),
        ),
        const SizedBox(height: Space.md),
        TextFormField(
          controller: _description,
          minLines: 4,
          maxLines: 10,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.communityDescription, alignLabelWithHint: true),
          validator: (value) => validators.minLength(value, 10),
        ),
        if (_error != null) Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.brand.danger)),
      ],
      footer: BusyButton(label: l10n.createCommunity, icon: Icons.add, busy: _busy, onPressed: _submit),
    );
  }
}

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, required this.communityId});
  final int communityId;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final post = await ref
          .read(communityRepositoryProvider)
          .createPost(communityId: widget.communityId, title: _title.text.trim(), content: _content.text.trim());
      ref
        ..invalidate(communityFeedProvider((id: widget.communityId, query: '')))
        ..invalidate(communityProvider(widget.communityId));
      if (!mounted) return;
      showToast(context, l10n.postPublished);
      context.pushReplacement(Routes.post(post.id));
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    final community = ref.watch(communityProvider(widget.communityId)).value;
    return _FormPage(
      title: l10n.newPost,
      intro: community?.name ?? '',
      form: _form,
      fields: [
        TextFormField(
          controller: _title,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l10n.postTitle),
          validator: (value) => validators.minLength(value, 3),
        ),
        const SizedBox(height: Space.md),
        TextFormField(
          controller: _content,
          minLines: 6,
          maxLines: 16,
          maxLength: 5000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l10n.postContent, alignLabelWithHint: true),
          validator: (value) => validators.minLength(value, 10),
        ),
        if (_error != null) Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.brand.danger)),
      ],
      footer: BusyButton(label: l10n.send, icon: Icons.send_rounded, busy: _busy, onPressed: _submit),
    );
  }
}
