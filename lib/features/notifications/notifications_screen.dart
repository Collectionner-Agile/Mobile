import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/collectible_image.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/application/bid_events.dart';
import '../catalog/application/catalog_providers.dart';
import 'notices.dart';

/// Notices grouped by day (21st.dev "Notification Inbox"): each with a
/// coloured icon for its kind, one plain sentence, the time, and a dot while
/// unread. "All" or only unread, and one tap to mark everything read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final read = ref.watch(readNoticesProvider);
    final all = ref.watch(noticesProvider);
    final unread = all.where((notice) => !read.contains(notice.id)).toList();
    final shown = _unreadOnly ? unread : all;
    final loading = ref.watch(auctionsProvider).isLoading && ref.watch(auctionsProvider).value == null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String group(Notice notice) {
      final day = DateTime(notice.at.year, notice.at.month, notice.at.day);
      if (!day.isBefore(today)) return l10n.groupToday;
      if (today.difference(day).inDays < 7) return l10n.groupThisWeek;
      return l10n.groupEarlier;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noticesTitle),
        actions: [
          if (unread.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(readNoticesProvider.notifier).markAll(all.map((notice) => notice.id));
              },
              icon: const Icon(AppIcons.listChecks, size: 18),
              label: Text(l10n.markAllRead),
            ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(auctionsProvider)
            ..invalidate(collectiblesProvider);
          await ref.read(auctionsProvider.future).catchError((Object _) => const <Never>[]);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xs,
            Space.gutter,
            Space.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            ContentWidth(
              child: SegmentedTabs(
                labels: [l10n.noticesAll, l10n.noticesUnread(unread.length)],
                index: _unreadOnly ? 1 : 0,
                onChanged: (index) => setState(() => _unreadOnly = index == 1),
              ),
            ),
            const SizedBox(height: Space.md),
            if (loading)
              for (var i = 0; i < 4; i++) ...[
                const Skeleton(height: 76, radius: Radii.lg),
                const SizedBox(height: Space.sm),
              ]
            else if (shown.isEmpty)
              EmptyState(icon: AppIcons.bell, message: l10n.noticesEmpty, body: l10n.noticesEmptyBody)
            else
              RevealWindow(
                key: ValueKey(_unreadOnly),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, notice) in shown.indexed) ...[
                      if (index == 0 || group(shown[index - 1]) != group(notice))
                        Padding(
                          padding: EdgeInsets.fromLTRB(Space.xxs, index == 0 ? 0 : Space.md, 0, Space.xs),
                          child: Text(
                            group(notice).toUpperCase(),
                            style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: brand.muted),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: ContentWidth(
                          child: Reveal(
                            index: index,
                            child: _NoticeCard(
                              notice: notice,
                              unread: !read.contains(notice.id),
                              onTap: () {
                                ref.read(readNoticesProvider.notifier).markRead(notice.id);
                                if (notice.route != null) context.push(notice.route!);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.unread, required this.onTap});
  final Notice notice;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final subject = notice.subject ?? '';
    final amount = notice.amount == null ? '' : context.money(notice.amount!);
    final who = notice.who ?? '—';
    final (icon, color, title, body) = switch (notice.kind) {
      NoticeKind.outbid => (
        AppIcons.triangleAlert,
        brand.live,
        l10n.noticeOutbidTitle,
        l10n.noticeOutbidBody(who, amount, subject),
      ),
      NoticeKind.leading => (
        AppIcons.trendingUp,
        brand.success,
        l10n.noticeLeadingTitle,
        l10n.noticeLeadingBody(subject, amount),
      ),
      NoticeKind.bidOnYours => (
        AppIcons.handCoins,
        brand.gold,
        l10n.noticeBidTitle,
        l10n.noticeBidBody(who, amount, subject),
      ),
      NoticeKind.closingSoon => (
        AppIcons.hourglass,
        brand.warning,
        l10n.noticeClosingTitle,
        l10n.noticeClosingBody(subject),
      ),
      NoticeKind.ended => (AppIcons.trophy, brand.info, l10n.noticeEndedTitle, l10n.noticeEndedBody(subject, amount)),
      NoticeKind.newPiece => (AppIcons.sparkles, brand.gold, l10n.noticePieceTitle, l10n.noticePieceBody(subject)),
      NoticeKind.welcome => (
        AppIcons.partyPopper,
        brand.accent,
        subject.isEmpty ? l10n.noticeWelcomeTitleGuest : l10n.noticeWelcomeTitle(subject),
        l10n.noticeWelcomeBody,
      ),
    };
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.sm),
      color: unread ? Color.alphaBlend(color.withValues(alpha: context.isDark ? 0.08 : 0.04), brand.surface) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (notice.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: SizedBox.square(
                    dimension: 48,
                    child: ColoredBox(
                      color: brand.surfaceMuted,
                      child: CollectibleImage(notice.image, cacheWidth: 100),
                    ),
                  ),
                )
              else
                IconBadge(icon, color: color, size: 48),
              if (notice.image != null)
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: brand.surface, shape: BoxShape.circle),
                    child: IconBadge(icon, color: color, size: 24, solid: true),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: Space.xs),
                    Text(timeAgo(context, notice.at), style: context.text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall?.copyWith(color: brand.ink.withValues(alpha: 0.75))),
              ],
            ),
          ),
          AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            margin: const EdgeInsets.only(left: Space.xs, top: 6),
            width: unread ? 8 : 0,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
