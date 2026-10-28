import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/widgets/collectible_card.dart';
import '../../communities/application/community_providers.dart';
import '../../communities/presentation/widgets/community_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
                child: _ProfileHero(user: user, items: items.value, communities: communities.value?.length),
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
                child: _LinksCard(
                  links: [
                    (Icons.insights_rounded, l10n.insightsTitle, l10n.insightsSubtitle, Routes.insights),
                    (Icons.inventory_2_outlined, l10n.myCollectionTitle, null, Routes.myCollection),
                    (Icons.gavel_outlined, l10n.myBidsTitle, null, Routes.myBids),
                    (Icons.notifications_active_outlined, l10n.watchlistTitle, null, Routes.watchlist),
                    (Icons.notifications_none_rounded, l10n.noticesTitle, null, Routes.notifications),
                    (Icons.emoji_events_outlined, l10n.achievementsTitle, null, Routes.achievements),
                    (Icons.help_outline_rounded, l10n.helpTitle, null, Routes.help),
                  ],
                ),
              ),
            ),
            ContentWidth(
              child: SectionHeader(
                title: l10n.myArchive,
                actionLabel: l10n.seeAll,
                onAction: () => context.push(Routes.myCollection),
              ),
            ),
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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = gridColumnsFor(constraints.maxWidth);
                            final cell = (constraints.maxWidth - Space.md * (columns - 1)) / columns;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: Space.md,
                                mainAxisSpacing: Space.lg,
                                mainAxisExtent: cell + collectibleCardTextHeight(context),
                              ),
                              itemCount: list.length,
                              itemBuilder: (context, index) => Reveal(
                                index: index,
                                child: CollectibleCard(
                                  item: list[index],
                                  onTap: () => context.go(Routes.collectible(list[index].id)),
                                ),
                              ),
                            );
                          },
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

/// Everything that is yours, one row each, in a single hairline card.
class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.links});
  final List<(IconData, String, String?, String)> links;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: brand.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, (icon, title, subtitle, route)) in links.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: brand.line),
            ListTile(
              leading: Icon(icon, color: brand.ink),
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(route),
            ),
          ],
        ],
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

/// Cover card: the member's most valuable piece as backdrop, identity on the
/// photo and real archive figures underneath.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user, required this.items, required this.communities});
  final AppUser user;
  final List<Collectible>? items;
  final int? communities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final pieces = items;
    final cover = pieces == null || pieces.isEmpty
        ? null
        : (pieces.toList()..sort((a, b) => b.value.compareTo(a.value))).first.artwork;
    final total = pieces?.fold<double>(0, (sum, item) => sum + item.value);
    const white = Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Stack(
        children: [
          Positioned.fill(
            child: cover == null
                ? ColoredBox(color: BrandColors.dark.surface)
                : ExcludeSemantics(child: CollectibleImage(cover, fit: BoxFit.cover, cacheWidth: 720)),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xE6000000)],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(Space.md, cover == null ? Space.lg : 120, Space.md, Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: brand.paper,
                        border: Border.all(color: white, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: user.avatarUrl != null
                          ? CollectibleImage(user.avatarUrl, cacheWidth: 60)
                          : Center(
                              child: Text(
                                user.initial,
                                style: Fonts.display(context.text.headlineSmall).copyWith(color: brand.ink),
                              ),
                            ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.headlineSmall?.copyWith(color: white),
                          ),
                          Text(
                            '@${user.username}',
                            style: context.text.bodyMedium?.copyWith(color: const Color(0xCCFFFFFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user.bio != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(user.bio!, style: context.text.bodyMedium?.copyWith(color: const Color(0xE6FFFFFF))),
                ],
                if (user.location != null || user.memberSince != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    [
                      if (user.location != null) user.location!,
                      if (user.memberSince != null)
                        l10n.memberSince(formatDate(user.memberSince!, context.languageCode)),
                    ].join(' · '),
                    style: context.text.bodySmall?.copyWith(color: const Color(0xB3FFFFFF)),
                  ),
                ],
                const SizedBox(height: Space.md),
                GlassPanel(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
                  child: Row(
                    children: [
                      _Stat(value: pieces == null ? '—' : '${pieces.length}', label: l10n.statPieces),
                      _Stat(value: total == null ? '—' : context.money(total), label: l10n.declaredValue),
                      _Stat(value: communities == null ? '—' : '$communities', label: l10n.navCommunities),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: white, foregroundColor: BrandColors.light.ink),
                        onPressed: () => context.push(Routes.publishCollectible),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.publishItem, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    IconButton.outlined(
                      tooltip: l10n.editProfile,
                      style: IconButton.styleFrom(
                        foregroundColor: white,
                        side: const BorderSide(color: Color(0x80FFFFFF)),
                        minimumSize: const Size(52, 52),
                      ),
                      onPressed: () => context.push(Routes.editProfile),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: Fonts.figures(Fonts.display(context.text.titleMedium, weight: 760)).copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Fonts.label(context.text.labelSmall, weight: 560).copyWith(color: const Color(0xB3FFFFFF)),
        ),
      ],
    ),
  );
}
