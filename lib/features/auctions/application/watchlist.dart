import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/sync/server_id_set.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/ui.dart';

/// Auctions the user follows: on the device without an account, and on the
/// server once signed in (the server then notifies about their bids and
/// results). They get their own list and feed the closing-time notices.
final watchedAuctionsProvider = NotifierProvider<WatchlistController, Set<int>>(WatchlistController.new);

class WatchlistController extends ServerIdSet {
  @override
  String get listName => 'watchlist';

  @override
  String get prefsKey => 'pref.watchedAuctions';
}

/// Bell toggle to follow an auction; rings in gold while followed.
class FollowAuctionButton extends ConsumerWidget {
  const FollowAuctionButton({super.key, required this.auctionId, this.onPhoto = false, this.size = 40});
  final int auctionId;
  final bool onPhoto;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final following = ref.watch(watchedAuctionsProvider).contains(auctionId);
    return Semantics(
      toggled: following,
      child: CircleIconButton(
        icon: following ? Icons.notifications_active_outlined : Icons.notifications_none_rounded,
        tooltip: following ? l10n.unfollowAuction : l10n.followAuction,
        onPhoto: onPhoto,
        size: size,
        color: following ? (onPhoto ? Brand.chalk : context.brand.live) : null,
        onPressed: () async {
          final now = await ref.read(watchedAuctionsProvider.notifier).toggle(auctionId);
          await HapticFeedback.lightImpact();
          if (context.mounted) {
            showToast(
              context,
              now ? l10n.followingAuction : l10n.unfollowedAuction,
              icon: now ? Icons.notifications_active_outlined : Icons.notifications_none_rounded,
            );
          }
        },
      ),
    );
  }
}
