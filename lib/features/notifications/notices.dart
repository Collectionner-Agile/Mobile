import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../../app/providers.dart';
import '../../core/network/repositories.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/application/watchlist.dart';
import '../auctions/domain/auction_models.dart';
import '../auth/application/session_controller.dart';
import '../catalog/application/catalog_providers.dart';

enum NoticeKind { outbid, leading, bidOnYours, closingSoon, ended, newPiece, welcome, sale }

/// Something worth telling the user. Signed in, bids and auction results come
/// from the server (written where they happen, so they reach every phone);
/// the rest (closing soon, new pieces, welcome) is derived from the data the
/// app already loads.
class Notice {
  const Notice({
    required this.id,
    required this.kind,
    required this.at,
    this.subject,
    this.amount,
    this.who,
    this.route,
    this.image,
    this.title,
    this.body,
    this.serverId,
    this.readOnServer = false,
  });

  /// Text written by the server; when set it is shown as is.
  final String? title;
  final String? body;

  /// Id of the server notification, to mark it read there too.
  final int? serverId;
  final bool readOnServer;

  /// Stable id, so read marks survive rebuilds.
  final String id;
  final NoticeKind kind;
  final DateTime at;

  /// The piece or auction it is about.
  final String? subject;
  final double? amount;

  /// The other person involved (the bidder).
  final String? who;

  /// Where tapping the notice goes.
  final String? route;
  final String? image;
}

/// The last list the server sent each user, kept for when a refresh fails.
final _lastServerNoticesProvider = Provider<Map<int, List<Notice>>>((ref) => {});

/// The signed-in user's server notifications; null when signed out or when
/// the server has not been reached yet (then notices are derived on the phone).
final serverNoticesProvider = FutureProvider<List<Notice>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final last = ref.read(_lastServerNoticesProvider);
  try {
    final items = await ref.read(meRepositoryProvider).notifications();
    return last[user.id] = [for (final item in items) _fromServer(item)];
  } catch (_) {
    return last[user.id];
  }
});

Notice _fromServer(ServerNotification n) => Notice(
  id: 'srv-${n.id}',
  kind: switch (n.type) {
    'OUTBID' => NoticeKind.outbid,
    'NEW_BID' || 'WATCHED_BID' => NoticeKind.bidOnYours,
    final type when type.startsWith('SALE_') => NoticeKind.sale,
    _ => NoticeKind.ended,
  },
  at: n.createdAt,
  title: n.title,
  body: n.body,
  route: n.targetType == 'auction' && n.targetId != null
      ? '/auctions/${n.targetId}'
      : n.targetType == 'collectible' && n.targetId != null
      ? '/catalog/item/${n.targetId}'
      : n.targetType == 'sale' && n.targetId != null
      ? '/sales/${n.targetId}'
      : null,
  serverId: n.id,
  readOnServer: n.read,
);

/// How often the server notices are asked for while the app is on screen.
const serverNoticesRefreshEvery = Duration(seconds: 60);

/// Keeps the signed-in user's server notices, and with them the bell's badge,
/// current: asks again every [serverNoticesRefreshEvery] while the app is on
/// screen and as soon as the user comes back to it. A notice not seen before
/// means an auction changed, so the auctions are reloaded too; otherwise the
/// notices derived from them could contradict the new one. The app keeps this
/// alive.
final serverNoticesRefreshProvider = Provider<void>((ref) {
  if (ref.watch(currentUserProvider) == null) return;

  void refresh() => ref.invalidate(serverNoticesProvider);
  Timer? timer;
  void start() => timer ??= Timer.periodic(serverNoticesRefreshEvery, (_) => refresh());
  void stop() {
    timer?.cancel();
    timer = null;
  }

  final lifecycle = AppLifecycleListener(
    onHide: stop,
    onShow: () {
      refresh();
      start();
    },
  );
  start();
  ref.onDispose(() {
    stop();
    lifecycle.dispose();
  });

  ref.listen(serverNoticesProvider, (previous, next) {
    final before = previous?.value;
    final after = next.value;
    if (before == null || after == null) return;
    final known = {for (final notice in before) notice.id};
    if (after.any((notice) => !known.contains(notice.id))) ref.invalidate(auctionsProvider);
  });
});

/// Ids of the notices already read, kept on the device (server notices are
/// also marked read on the server).
final readNoticesProvider = NotifierProvider<ReadNotices, Set<String>>(ReadNotices.new);

class ReadNotices extends Notifier<Set<String>> {
  static const _key = 'pref.noticesRead';

  @override
  Set<String> build() => (ref.read(sharedPreferencesProvider).getStringList(_key) ?? const []).toSet();

  Future<void> markRead(String id) {
    final serverId = id.startsWith('srv-') ? int.tryParse(id.substring(4)) : null;
    if (serverId != null) unawaited(ref.read(meRepositoryProvider).markNotificationRead(serverId).catchError((_) {}));
    return _save({...state, id});
  }

  Future<void> markAll(Iterable<String> ids) {
    if (ids.any((id) => id.startsWith('srv-'))) {
      unawaited(ref.read(meRepositoryProvider).markAllNotificationsRead().catchError((_) {}));
    }
    return _save({...state, ...ids});
  }

  Future<void> _save(Set<String> ids) async {
    if (ids.length == state.length) return;
    state = ids;
    await ref.read(sharedPreferencesProvider).setStringList(_key, ids.toList());
  }
}

/// All current notices, newest first.
final noticesProvider = Provider<List<Notice>>((ref) {
  final user = ref.watch(currentUserProvider);
  final auctions = ref.watch(auctionsProvider).value ?? const [];
  final pieces = ref.watch(collectiblesProvider).value ?? const [];
  final watched = ref.watch(watchedAuctionsProvider);
  final server = ref.watch(serverNoticesProvider).value;
  // The server already reports bids and results; deriving them again would duplicate them.
  final fromServer = user != null && server != null;
  final now = DateTime.now();
  final notices = <Notice>[...?server];

  for (final auction in auctions) {
    final live = auction.isLive(now);
    final route = '/auctions/${auction.id}';
    final name = auction.collectibleName;
    final mine = user != null && auction.auctioneerId == user.id;
    final myBids = user == null ? const <Bid>[] : auction.bids.where((bid) => bid.bidderId == user.id).toList();
    final leader = auction.bids.isEmpty ? null : auction.bids.first;

    if (live && myBids.isNotEmpty && leader != null) {
      final ahead = leader.bidderId == user!.id;
      if (!ahead && !fromServer) {
        notices.add(
          Notice(
            id: 'outbid-${auction.id}-${leader.id}',
            kind: NoticeKind.outbid,
            at: leader.createdAt ?? now,
            subject: name,
            amount: leader.amount,
            who: leader.bidderName,
            route: route,
            image: auction.artwork,
          ),
        );
      } else if (ahead) {
        notices.add(
          Notice(
            id: 'leading-${auction.id}-${leader.id}',
            kind: NoticeKind.leading,
            at: leader.createdAt ?? now,
            subject: name,
            amount: leader.amount,
            route: route,
            image: auction.artwork,
          ),
        );
      }
    }

    if (mine && !fromServer) {
      for (final bid in auction.bids.take(3)) {
        notices.add(
          Notice(
            id: 'bid-${bid.id}',
            kind: NoticeKind.bidOnYours,
            at: bid.createdAt ?? now,
            subject: name,
            amount: bid.amount,
            who: bid.bidderName,
            route: route,
            image: auction.artwork,
          ),
        );
      }
    }

    final involved = mine || myBids.isNotEmpty || watched.contains(auction.id);
    if (live && watched.contains(auction.id) && auction.deadline!.difference(now) <= const Duration(hours: 24)) {
      final warnedAt = auction.deadline!.subtract(const Duration(hours: 24));
      notices.add(
        Notice(
          id: 'closing-${auction.id}',
          kind: NoticeKind.closingSoon,
          at: warnedAt.isAfter(now) ? now : warnedAt,
          subject: name,
          amount: auction.currentPrice,
          route: route,
          image: auction.artwork,
        ),
      );
    }
    if (!live && involved && auction.deadline != null && !fromServer) {
      notices.add(
        Notice(
          id: 'ended-${auction.id}',
          kind: NoticeKind.ended,
          at: auction.deadline!.isAfter(now) ? now : auction.deadline!,
          subject: name,
          amount: auction.currentPrice,
          who: leader?.bidderName,
          route: route,
          image: auction.artwork,
        ),
      );
    }
  }

  final fresh =
      pieces
          .where(
            (piece) =>
                piece.createdAt != null &&
                now.difference(piece.createdAt!) <= const Duration(days: 7) &&
                piece.ownerId != user?.id,
          )
          .toList()
        ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  for (final piece in fresh.take(4)) {
    notices.add(
      Notice(
        id: 'piece-${piece.id}',
        kind: NoticeKind.newPiece,
        at: piece.createdAt!,
        subject: piece.name,
        amount: piece.value,
        route: '/catalog/item/${piece.id}',
        image: piece.artwork,
      ),
    );
  }

  notices
    ..add(
      Notice(
        id: 'welcome',
        kind: NoticeKind.welcome,
        at: user?.memberSince ?? DateTime(2026, 10),
        subject: user?.name.split(' ').first,
        route: '/help/how-it-works',
      ),
    )
    ..sort((a, b) => b.at.compareTo(a.at));
  return notices;
});

/// How many notices are still unread (for the bell's badge).
final unreadNoticesProvider = Provider<int>((ref) {
  final read = ref.watch(readNoticesProvider);
  return ref.watch(noticesProvider).where((notice) => !notice.readOnServer && !read.contains(notice.id)).length;
});
