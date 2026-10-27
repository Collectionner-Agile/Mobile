import 'package:flutter/widgets.dart';

import '../../../core/widgets/ui.dart';
import '../domain/auction_models.dart';

/// One bid with the lot it belongs to, newest first.
typedef BidEvent = ({Bid bid, Auction auction});

List<BidEvent> recentBids(List<Auction> auctions, {int limit = 8}) {
  final events = [
    for (final auction in auctions)
      for (final bid in auction.bids)
        if (bid.createdAt != null) (bid: bid, auction: auction),
  ]..sort((a, b) => b.bid.createdAt!.compareTo(a.bid.createdAt!));
  return events.take(limit).toList();
}

/// "hace 5 min" style time for activity rows.
String timeAgo(BuildContext context, DateTime when) {
  final l10n = context.l10n;
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
  return l10n.daysAgo(diff.inDays);
}
