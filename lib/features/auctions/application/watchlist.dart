import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/ui.dart';

/// Auctions the user follows, kept on the device (no account needed). They
/// get their own list and feed the notices about closing times and results.
final watchedAuctionsProvider = NotifierProvider<WatchlistController, Set<int>>(WatchlistController.new);

class WatchlistController extends Notifier<Set<int>> {
  static const _key = 'pref.watchedAuctions';

  @override
  Set<int> build() =>
      (ref.read(sharedPreferencesProvider).getStringList(_key) ?? const []).map(int.tryParse).whereType<int>().toSet();

  /// Returns true when the auction is now followed.
  Future<bool> toggle(int id) async {
    final following = !state.contains(id);
    state = following ? {...state, id} : ({...state}..remove(id));
    await ref.read(sharedPreferencesProvider).setStringList(_key, [for (final id in state) '$id']);
    return following;
  }
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
