import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/auction_models.dart';

final auctionsProvider = FutureProvider<List<Auction>>((ref) async {
  final auctions = await ref.watch(auctionRepositoryProvider).auctions();
  final now = DateTime.now();
  // Open lots first, closest deadline first; closed ones after.
  return [...auctions]..sort((a, b) {
    final liveA = a.isLive(now), liveB = b.isLive(now);
    if (liveA != liveB) return liveA ? -1 : 1;
    return (a.deadline ?? now).compareTo(b.deadline ?? now);
  });
});

final auctionProvider = FutureProvider.autoDispose.family<Auction, int>(
  (ref, id) => ref.watch(auctionRepositoryProvider).auction(id),
);

/// One-second clock for countdowns. Only alive while a countdown is on screen.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => controller.add(DateTime.now()));
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
