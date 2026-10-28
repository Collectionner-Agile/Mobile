import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../auctions/application/auction_providers.dart';
import '../auctions/application/watchlist.dart';
import '../auctions/domain/auction_models.dart';
import '../auth/application/session_controller.dart';
import '../catalog/application/catalog_providers.dart';

enum NoticeKind { outbid, leading, bidOnYours, closingSoon, ended, newPiece, welcome }

/// Something worth telling the user, derived from the data the app already
/// loads (auctions with their bids, the catalogue, the followed auctions).
/// Nothing is pushed from a server: the list is rebuilt each time.
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
  });

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

/// Ids of the notices already read, kept on the device.
final readNoticesProvider = NotifierProvider<ReadNotices, Set<String>>(ReadNotices.new);

class ReadNotices extends Notifier<Set<String>> {
  static const _key = 'pref.noticesRead';

  @override
  Set<String> build() => (ref.read(sharedPreferencesProvider).getStringList(_key) ?? const []).toSet();

  Future<void> markRead(String id) => _save({...state, id});

  Future<void> markAll(Iterable<String> ids) => _save({...state, ...ids});

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
  final now = DateTime.now();
  final notices = <Notice>[];

  for (final auction in auctions) {
    final live = auction.isLive(now);
    final route = '/auctions/${auction.id}';
    final name = auction.collectibleName;
    final mine = user != null && auction.auctioneerId == user.id;
    final myBids = user == null ? const <Bid>[] : auction.bids.where((bid) => bid.bidderId == user.id).toList();
    final leader = auction.bids.isEmpty ? null : auction.bids.first;

    if (myBids.isNotEmpty && leader != null) {
      if (live && leader.bidderId != user!.id) {
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
      } else if (live) {
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

    if (mine) {
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
    if (!live && involved && auction.deadline != null) {
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
  return ref.watch(noticesProvider).where((notice) => !read.contains(notice.id)).length;
});
