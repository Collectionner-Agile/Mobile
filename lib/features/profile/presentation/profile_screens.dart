import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auctions/application/watchlist.dart';
import '../../auctions/presentation/my_bids_screen.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/widgets/collectible_card.dart';
import '../../communities/application/community_providers.dart';
import '../../communities/presentation/widgets/community_tile.dart';
import '../../favorites/favorites.dart';
import '../../launch/launch_scene.dart';
import '../../notifications/notices.dart';
import 'achievements_screen.dart';

/// The Profile tab: who you are, what your collection is worth, shortcuts to
/// everything that is yours, and the account settings, in that order.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.signOut,
      body: l10n.signOutConfirm,
      confirmLabel: l10n.signOut,
      icon: AppIcons.logOut,
    );
    if (!ok || !context.mounted) return;
    final router = ref.read(routerProvider);
    await ref.read(sessionProvider.notifier).logout();
    if (!context.mounted) return;
    await farewell(
      context,
      title: l10n.farewellTitle,
      message: l10n.farewellSignedOut,
      then: () => router.go(Routes.home),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const _GuestProfile();
    final l10n = context.l10n;
    final brand = context.brand;
    final items = ref
        .watch(collectiblesProvider)
        .whenData((all) => all.where((item) => item.ownerId == user.id).toList());
    final communities = ref.watch(myCommunitiesProvider);
    final activeBids = ref.watch(myBidsProvider).value?.where((bid) => bid.active).length ?? 0;
    final unread = ref.watch(unreadNoticesProvider);
    final total = items.value?.fold<double>(0, (sum, item) => sum + item.value);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(collectiblesProvider)
            ..invalidate(myCommunitiesProvider);
          await ref.read(sessionProvider.notifier).refreshProfile().catchError((Object _) {});
        },
        child: ListView(
          padding: EdgeInsets.only(bottom: Space.xxl + bottom),
          children: [
            AmbientGlow(
              child: SafeArea(
                bottom: false,
                child: ContentWidth(child: _Identity(user: user)),
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                child: Reveal(
                  child: _ValueCard(
                    total: total,
                    pieces: items.value?.length,
                    communities: communities.value?.length,
                    activeBids: activeBids,
                  ),
                ),
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, 0),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Space.sm,
                  childAspectRatio: 0.78 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
                  children: [
                    QuickAction(
                      icon: AppIcons.handCoins,
                      label: l10n.myBidsTitle,
                      color: brand.gold,
                      badge: activeBids,
                      onTap: () => context.push(Routes.myBids),
                    ),
                    QuickAction(
                      icon: AppIcons.bellRing,
                      label: l10n.watchlistFollowing,
                      color: brand.live,
                      badge: ref.watch(watchedAuctionsProvider).length,
                      onTap: () => context.push(Routes.watchlist),
                    ),
                    QuickAction(
                      icon: AppIcons.heart,
                      label: l10n.favoritesTitle,
                      color: brand.danger,
                      badge: ref.watch(favoritesProvider).length,
                      onTap: () => context.push(Routes.favorites),
                    ),
                    QuickAction(
                      icon: AppIcons.bell,
                      label: l10n.noticesTitle,
                      color: brand.info,
                      badge: unread,
                      onTap: () => context.push(Routes.notifications),
                    ),
                  ],
                ),
              ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                child: Builder(
                  builder: (context) {
                    final achievements = ref.watch(achievementsProvider);
                    final unlocked = achievements.where((a) => a.unlocked).length;
                    return AppCard(
                      onTap: () => context.push(Routes.achievements),
                      child: Row(
                        children: [
                          ProgressRing(
                            value: unlocked / achievements.length,
                            size: 48,
                            stroke: 4,
                            child: Icon(AppIcons.trophy, size: 18, color: brand.gold),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.achievementsTitle, style: context.text.titleSmall),
                                Text(
                                  l10n.achievementsSummary(
                                    unlocked,
                                    achievements.length,
                                    achievementLevel(l10n, unlocked),
                                  ),
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(AppIcons.chevronRight, color: brand.muted, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            ContentWidth(
              child: SectionHeader(
                title: l10n.myPieces,
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
                          icon: AppIcons.gem,
                          message: l10n.noItemsYet,
                          actionLabel: l10n.publishItem,
                          onAction: () => context.push(Routes.publishCollectible),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate: pieceGridDelegate(context, constraints.maxWidth),
                            itemCount: list.length.clamp(0, 4),
                            itemBuilder: (context, index) => Reveal(
                              index: index,
                              child: CollectibleCard(
                                item: list[index],
                                onTap: () => context.go(Routes.collectible(list[index].id)),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            ContentWidth(child: SectionHeader(title: l10n.myCommunities)),
            AsyncSwitch(
              value: communities,
              onRetry: () => ref.invalidate(myCommunitiesProvider),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      message: l10n.noCommunitiesYet,
                      icon: AppIcons.usersRound,
                      actionLabel: l10n.discoverCommunities,
                      onAction: () => context.go(Routes.communities),
                    )
                  : SizedBox(
                      height: 150 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                        itemBuilder: (context, index) => CommunityCoverCard(
                          community: list[index],
                          onTap: () => context.push(Routes.community(list[index].id)),
                        ),
                      ),
                    ),
            ),
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                child: Column(
                  children: [
                    MenuGroup(
                      title: l10n.yourAccount,
                      children: [
                        MenuTile(
                          icon: AppIcons.chartLine,
                          title: l10n.insightsTitle,
                          subtitle: l10n.insightsSubtitle,
                          color: brand.gold,
                          onTap: () => context.push(Routes.insights),
                        ),
                        MenuTile(
                          icon: AppIcons.squarePen,
                          title: l10n.editProfile,
                          onTap: () => context.push(Routes.editProfile),
                        ),
                        MenuTile(
                          icon: AppIcons.settings,
                          title: l10n.settings,
                          onTap: () => context.push(Routes.settings),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    MenuGroup(
                      title: l10n.helpTitle,
                      children: [
                        MenuTile(
                          icon: AppIcons.circleHelp,
                          title: l10n.helpTitle,
                          color: brand.info,
                          onTap: () => context.push(Routes.help),
                        ),
                        MenuTile(
                          icon: AppIcons.lightbulb,
                          title: l10n.howItWorksTitle,
                          color: brand.gold,
                          onTap: () => context.push(Routes.howItWorks),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    MenuGroup(
                      children: [
                        MenuTile(
                          icon: AppIcons.logOut,
                          title: l10n.signOut,
                          destructive: true,
                          onTap: () => _signOut(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar with a gold ring, name, handle and a line of facts.
class _Identity extends StatelessWidget {
  const _Identity({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final facts = [
      if (user.location != null) user.location!,
      if (user.memberSince != null) l10n.memberSince(formatDate(user.memberSince!, context.languageCode)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CircleIconButton(
              icon: AppIcons.settings,
              tooltip: l10n.settings,
              onPressed: () => context.push(Routes.settings),
            ),
          ),
          Reveal(
            child: UserAvatar(name: user.name, url: user.avatarUrl, size: 88, ring: true),
          ),
          const SizedBox(height: Space.sm),
          Reveal(
            index: 1,
            child: Text(user.name, textAlign: TextAlign.center, style: context.text.headlineMedium),
          ),
          Text('@${user.username}', style: context.text.bodyMedium?.copyWith(color: brand.muted)),
          if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium,
            ),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.xs,
              runSpacing: Space.xxs,
              children: [
                if (user.location != null) Tag(user.location!, icon: AppIcons.mapPin, color: brand.muted),
                if (user.memberSince != null)
                  Tag(
                    l10n.memberSince(formatDate(user.memberSince!, context.languageCode)),
                    icon: AppIcons.calendar,
                    color: brand.muted,
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.editProfile),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 42)),
            icon: const Icon(AppIcons.squarePen, size: 16),
            label: Text(l10n.editProfile),
          ),
        ],
      ),
    );
  }
}

/// Midnight card with the collection's declared value (21st.dev wallet card).
class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.total, required this.pieces, required this.communities, required this.activeBids});
  final double? total;
  final int? pieces;
  final int? communities;
  final int activeBids;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.insightsTitle,
      child: TapScale(
        child: GestureDetector(
          onTap: () => context.push(Routes.insights),
          child: HeroPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.collectionValue.toUpperCase(),
                        style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: Brand.gold),
                      ),
                    ),
                    const Icon(AppIcons.arrowUpRight, color: Brand.goldLight, size: 18),
                  ],
                ),
                const SizedBox(height: Space.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: total == null
                      ? const SizedBox(height: 40, width: 120)
                      : PriceText(total!, style: context.text.displaySmall, color: Brand.ivory, animate: true),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(value: pieces == null ? '—' : '$pieces', label: l10n.statPieces),
                    ),
                    Expanded(
                      child: _Figure(value: communities == null ? '—' : '$communities', label: l10n.navCommunities),
                    ),
                    Expanded(
                      child: _Figure(value: '$activeBids', label: l10n.myBidsActive),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Fonts.figures(Fonts.display(context.text.titleLarge, weight: 680)).copyWith(color: Brand.ivory),
      ),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(color: const Color(0xB3F5F1E7)),
      ),
    ],
  );
}

/// Guests see what an account gives them and the two ways in.
class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final from = Uri(path: Routes.login, queryParameters: {'from': Routes.profile}).toString();
    return Scaffold(
      body: AmbientGlow(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              Space.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              ContentWidth(
                maxWidth: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: CircleIconButton(
                        icon: AppIcons.settings,
                        tooltip: l10n.settings,
                        onPressed: () => context.push(Routes.settings),
                      ),
                    ),
                    Center(
                      child: Reveal(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/branding/site-icon-512.png',
                            width: 84,
                            height: 84,
                            cacheWidth: 252,
                            semanticLabel: l10n.appName,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Text(l10n.profileGuestTitle, textAlign: TextAlign.center, style: context.text.headlineLarge),
                    const SizedBox(height: Space.xs),
                    Text(
                      l10n.profileGuestBody,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: brand.muted),
                    ),
                    const SizedBox(height: Space.xl),
                    for (final (index, (icon, text)) in [
                      (AppIcons.gem, l10n.guestPerkCollection),
                      (AppIcons.gavel, l10n.guestPerkBids),
                      (AppIcons.bellRing, l10n.guestPerkFollow),
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Reveal(
                          index: index + 1,
                          child: AppCard(
                            child: Row(
                              children: [
                                IconBadge(icon, color: brand.gold),
                                const SizedBox(width: Space.sm),
                                Expanded(child: Text(text, style: context.text.bodyMedium)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: Space.lg),
                    BusyButton(label: l10n.signIn, icon: AppIcons.logIn, onPressed: () => context.push(from)),
                    const SizedBox(height: Space.sm),
                    BusyButton(
                      label: l10n.createAccount,
                      outlined: true,
                      onPressed: () => context.push(
                        Uri(path: Routes.register, queryParameters: {'from': Routes.profile}).toString(),
                      ),
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
    final user = _user;
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
                    if (user != null)
                      Center(
                        child: ValueListenableBuilder(
                          valueListenable: _name,
                          builder: (_, value, _) =>
                              UserAvatar(name: value.text.isEmpty ? user.name : value.text, size: 84, ring: true),
                        ),
                      ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.fullName,
                        prefixIcon: const Icon(AppIcons.user, size: 20),
                      ),
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
                      decoration: InputDecoration(
                        labelText: '${l10n.fieldLocation} · ${l10n.optional}',
                        prefixIcon: const Icon(AppIcons.mapPin, size: 20),
                      ),
                    ),
                    if (_error != null)
                      Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.brand.danger)),
                    const SizedBox(height: Space.lg),
                    BusyButton(label: l10n.save, icon: AppIcons.check, busy: _busy, onPressed: _submit),
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
