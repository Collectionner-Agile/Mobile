import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auctions/application/watchlist.dart';
import '../../auctions/presentation/my_bids_screen.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../communities/application/community_providers.dart';
import '../../favorites/favorites.dart';

enum AchievementId { firstPiece, curator, firstBid, steadyBidder, winner, heart, lookout, community, profile }

/// One badge and how far along the user is.
class Achievement {
  const Achievement({required this.id, required this.icon, required this.progress, required this.goal});
  final AchievementId id;
  final IconData icon;
  final int progress;
  final int goal;

  bool get unlocked => progress >= goal;
  double get fraction => (progress / goal).clamp(0.0, 1.0);
}

/// Badges computed from what the user already did in the app.
final achievementsProvider = Provider<List<Achievement>>((ref) {
  final user = ref.watch(currentUserProvider);
  final pieces = (ref.watch(collectiblesProvider).value ?? const []).where((p) => p.ownerId == user?.id).length;
  final bids = ref.watch(myBidsProvider).value ?? const <MyBid>[];
  final won = bids.where((bid) => bid.status == MyBidStatus.won).length;
  final favorites = ref.watch(favoritesProvider).length;
  final watched = ref.watch(watchedAuctionsProvider).length;
  final communities = ref.watch(myCommunitiesProvider).value?.length ?? 0;
  final profile = [user?.bio, user?.location].where((v) => v != null && v.trim().isNotEmpty).length;
  return [
    Achievement(id: AchievementId.firstPiece, icon: Icons.diamond_outlined, progress: pieces, goal: 1),
    Achievement(id: AchievementId.curator, icon: Icons.workspace_premium_outlined, progress: pieces, goal: 5),
    Achievement(id: AchievementId.firstBid, icon: Icons.gavel_outlined, progress: bids.length, goal: 1),
    Achievement(id: AchievementId.steadyBidder, icon: Icons.payments_outlined, progress: bids.length, goal: 5),
    Achievement(id: AchievementId.winner, icon: Icons.emoji_events_outlined, progress: won, goal: 1),
    Achievement(id: AchievementId.heart, icon: Icons.favorite_border_rounded, progress: favorites, goal: 5),
    Achievement(id: AchievementId.lookout, icon: Icons.notifications_active_outlined, progress: watched, goal: 3),
    Achievement(id: AchievementId.community, icon: Icons.groups_outlined, progress: communities, goal: 2),
    Achievement(id: AchievementId.profile, icon: Icons.verified_outlined, progress: profile, goal: 2),
  ];
});

(String, String) achievementCopy(AppLocalizations l10n, AchievementId id) => switch (id) {
  AchievementId.firstPiece => (l10n.achFirstPiece, l10n.achFirstPieceBody),
  AchievementId.curator => (l10n.achCurator, l10n.achCuratorBody),
  AchievementId.firstBid => (l10n.achFirstBid, l10n.achFirstBidBody),
  AchievementId.steadyBidder => (l10n.achSteadyBidder, l10n.achSteadyBidderBody),
  AchievementId.winner => (l10n.achWinner, l10n.achWinnerBody),
  AchievementId.heart => (l10n.achHeart, l10n.achHeartBody),
  AchievementId.lookout => (l10n.achLookout, l10n.achLookoutBody),
  AchievementId.community => (l10n.achCommunity, l10n.achCommunityBody),
  AchievementId.profile => (l10n.achProfile, l10n.achProfileBody),
};

/// Level name for a number of unlocked badges.
String achievementLevel(AppLocalizations l10n, int unlocked) => switch (unlocked) {
  <= 2 => l10n.levelNovice,
  <= 5 => l10n.levelCollector,
  <= 8 => l10n.levelCurator,
  _ => l10n.levelLegend,
};

/// Badges as gold medallions (grey until earned) with progress, under a
/// level card; tapping one says how to earn it.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final achievements = ref.watch(achievementsProvider);
    final unlocked = achievements.where((a) => a.unlocked).length;
    final next = achievements.where((a) => !a.unlocked).toList()..sort((a, b) => b.fraction.compareTo(a.fraction));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 4 : 3;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.lg),
                  child: ContentWidth(
                    child: Reveal(
                      child: HeroPanel(
                        child: Row(
                          children: [
                            ProgressRing(
                              value: unlocked / achievements.length,
                              size: 84,
                              stroke: 7,
                              color: Brand.gold,
                              child: Text(
                                '$unlocked/${achievements.length}',
                                style: Fonts.figures(Fonts.display(context.text.titleLarge, weight: 700))
                                    .copyWith(color: Brand.chalk),
                              ),
                            ),
                            const SizedBox(width: Space.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.yourLevel.toUpperCase(),
                                    style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: Brand.gold),
                                  ),
                                  Text(
                                    achievementLevel(l10n, unlocked),
                                    style: Fonts.display(
                                      context.text.headlineMedium,
                                      weight: 660,
                                    ).copyWith(color: Brand.chalk),
                                  ),
                                  if (next.isNotEmpty) ...[
                                    const SizedBox(height: Space.xxs),
                                    Text(
                                      l10n.nextAchievement(achievementCopy(l10n, next.first.id).$1),
                                      style: context.text.bodySmall?.copyWith(color: const Color(0xB3F5F1E7)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: Space.md,
                    crossAxisSpacing: Space.sm,
                    childAspectRatio: 0.68 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.7),
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) => Reveal(
                    index: index,
                    child: _Medal(achievement: achievements[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.achievement});
  final Achievement achievement;

  void _explain(BuildContext context) {
    final l10n = context.l10n;
    final (title, body) = achievementCopy(l10n, achievement.id);
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Disc(achievement: achievement, size: 88, shine: true),
              const SizedBox(height: Space.md),
              Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Space.xs),
              Text(
                body,
                style: context.text.bodyMedium?.copyWith(color: context.brand.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.md),
              Tag(
                achievement.unlocked
                    ? l10n.achievementUnlocked
                    : '${achievement.progress.clamp(0, achievement.goal)}/${achievement.goal}',
                icon: achievement.unlocked ? Icons.check_circle_outline_rounded : Icons.track_changes_rounded,
                color: achievement.unlocked ? context.brand.success : context.brand.gold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final (title, _) = achievementCopy(l10n, achievement.id);
    return Semantics(
      button: true,
      label:
          '$title, ${achievement.unlocked ? l10n.achievementUnlocked : '${achievement.progress}/${achievement.goal}'}',
      excludeSemantics: true,
      child: TapScale(
        child: GestureDetector(
          onTap: () => _explain(context),
          child: Column(
            children: [
              _Disc(achievement: achievement, size: 72),
              const SizedBox(height: Space.xs),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: achievement.unlocked ? brand.ink : brand.muted),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: SizedBox(
                  width: 56,
                  child: LinearProgressIndicator(
                    value: achievement.fraction,
                    minHeight: 4,
                    color: achievement.unlocked ? brand.success : brand.gold,
                    backgroundColor: brand.surfaceMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.achievement, required this.size, this.shine = false});
  final Achievement achievement;
  final double size;

  /// Gold glint sweeping over an earned medal. Only for the one open in the
  /// sheet, so the grid never keeps animations running.
  final bool shine;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final unlocked = achievement.unlocked;
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Brand.chalk, Brand.gold, Color(0xFF9C7426)],
              )
            : null,
        color: unlocked ? null : brand.surfaceMuted,
        border: Border.all(color: unlocked ? Brand.chalk : brand.line, width: 2),
        boxShadow: unlocked
            ? [BoxShadow(color: brand.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
            : null,
      ),
      child: Icon(achievement.icon, size: size * 0.42, color: unlocked ? const Color(0xFF1A1305) : brand.muted),
    );
    if (!unlocked) return Opacity(opacity: 0.7, child: disc);
    return shine ? ShineSweep(period: const Duration(milliseconds: 3200), child: disc) : disc;
  }
}
