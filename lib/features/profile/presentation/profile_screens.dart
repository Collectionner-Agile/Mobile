import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../communities/application/community_providers.dart';
import '../../communities/presentation/widgets/community_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final items = ref
        .watch(collectiblesProvider)
        .whenData((all) => all.where((item) => item.ownerId == user.id).toList());
    final communities = ref.watch(myCommunitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(collectiblesProvider)
            ..invalidate(myCommunitiesProvider);
          await ref.read(sessionProvider.notifier).refreshProfile().catchError((Object _) {});
        },
        child: ListView(
          padding: EdgeInsets.only(bottom: Space.xxl + MediaQuery.paddingOf(context).bottom),
          children: [
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: brand.ink,
                          child: user.avatarUrl != null
                              ? ClipOval(
                                  child: SizedBox.expand(child: CollectibleImage(user.avatarUrl, cacheWidth: 64)),
                                )
                              : Text(user.initial, style: context.text.headlineSmall?.copyWith(color: brand.paper)),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: context.text.titleLarge),
                              Text('@${user.username}', style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                              if (user.memberSince != null)
                                Text(
                                  l10n.memberSince(formatDate(user.memberSince!, context.languageCode)),
                                  style: context.text.bodySmall?.copyWith(color: brand.muted),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (user.bio != null) ...[
                      const SizedBox(height: Space.md),
                      Text(user.bio!, style: context.text.bodyMedium),
                    ],
                    if (user.location != null) ...[
                      const SizedBox(height: Space.xs),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 16, color: brand.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(user.location!, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(Routes.editProfile),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(l10n.editProfile),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => context.push(Routes.publishCollectible),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.publishItem, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ContentWidth(child: SectionHeader(title: l10n.myArchive)),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AsyncSwitch(
                  value: items,
                  onRetry: () => ref.invalidate(collectiblesProvider),
                  data: (list) => list.isEmpty
                      ? EmptyState(
                          message: l10n.noItemsYet,
                          actionLabel: l10n.publishItem,
                          onAction: () => context.push(Routes.publishCollectible),
                        )
                      : Column(
                          children: [
                            for (final item in list)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(Radii.sm),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: CollectibleImage(item.artwork, cacheWidth: 56),
                                  ),
                                ),
                                title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  [item.category, context.money(item.value)].whereType<String>().join(' · '),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go(Routes.collectible(item.id)),
                              ),
                          ],
                        ),
                ),
              ),
            ),
            ContentWidth(child: SectionHeader(title: l10n.myCommunities)),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AsyncSwitch(
                  value: communities,
                  onRetry: () => ref.invalidate(myCommunitiesProvider),
                  data: (list) => list.isEmpty
                      ? EmptyState(message: l10n.noCommunitiesYet, icon: Icons.forum_outlined)
                      : Column(
                          children: [
                            for (final community in list) ...[
                              CommunityTile(
                                community: community,
                                onTap: () => context.go(Routes.community(community.id)),
                              ),
                              const SizedBox(height: Space.sm),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _user = ref.read(currentUserProvider);
  late final _name = TextEditingController(text: _user?.name);
  late final _bio = TextEditingController(text: _user?.bio);
  late final _location = TextEditingController(text: _user?.location);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
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
    String? clean(TextEditingController controller) => controller.text.trim().isEmpty ? null : controller.text.trim();
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            name: _name.text.trim(),
            bio: clean(_bio),
            location: clean(_location),
            avatarUrl: _user?.avatarUrl,
          );
      await ref.read(sessionProvider.notifier).replaceUser(updated);
      if (!mounted) return;
      showToast(context, l10n.profileUpdated);
      context.pop();
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xxl),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: l10n.fullName),
                      validator: (value) => validators.minLength(value, 2),
                    ),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _bio,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: '${l10n.fieldBio} · ${l10n.optional}',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _location,
                      maxLength: 120,
                      decoration: InputDecoration(labelText: '${l10n.fieldLocation} · ${l10n.optional}'),
                    ),
                    if (_error != null)
                      Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.brand.danger)),
                    const SizedBox(height: Space.lg),
                    BusyButton(label: l10n.save, busy: _busy, onPressed: _submit),
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
