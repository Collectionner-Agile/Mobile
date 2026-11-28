import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/sse.dart';
import 'auction_providers.dart';

enum LiveState { connecting, live, offline }

/// Something that just happened to an auction, as the server announced it.
class AuctionLiveUpdate {
  const AuctionLiveUpdate({
    required this.type,
    required this.auctionId,
    this.amount,
    this.bidCount,
    this.bidderName,
    this.sold,
    this.winnerName,
    this.winningBid,
  });

  /// `bid`, `closed` or `cancelled`.
  final String type;
  final int auctionId;
  final double? amount;
  final int? bidCount;
  final String? bidderName;
  final bool? sold;
  final String? winnerName;
  final double? winningBid;

  static AuctionLiveUpdate? fromEvent(SseEvent event) {
    final json = event.json;
    final id = json?['auctionId'];
    if (json == null || id is! num) return null;
    double? number(String key) => (json[key] as num?)?.toDouble();
    return AuctionLiveUpdate(
      type: event.event,
      auctionId: id.toInt(),
      amount: number('amount'),
      bidCount: (json['bidCount'] as num?)?.toInt(),
      bidderName: json['bidderName'] as String?,
      sold: json['sold'] as bool?,
      winnerName: json['winnerName'] as String?,
      winningBid: number('winningBid'),
    );
  }
}

/// Connection state plus the latest update (null until something happens).
class AuctionLive {
  const AuctionLive(this.state, [this.update]);
  final LiveState state;
  final AuctionLiveUpdate? update;
}

/// Follows auctions over Server-Sent Events while something on screen watches
/// the provider: each change reloads the affected data, the connection comes
/// back on its own (2 s, 4 s … up to 30 s), and it stops for good when the
/// server says the auction does not exist (404) or was withdrawn.
Stream<AuctionLive> _follow(
  Ref ref,
  Stream<SseEvent> Function(CancelToken cancel) connect,
  void Function(AuctionLiveUpdate? update) onChange, {
  bool Function(AuctionLiveUpdate update)? isFinal,
}) {
  final controller = StreamController<AuctionLive>();
  var active = true;
  CancelToken? cancel;
  void emit(AuctionLive value) {
    if (active && !controller.isClosed) controller.add(value);
  }

  ref.onDispose(() {
    active = false;
    cancel?.cancel();
    controller.close();
  });

  Future<void> run() async {
    var backoff = const Duration(seconds: 2);
    while (active) {
      emit(const AuctionLive(LiveState.connecting));
      cancel = CancelToken();
      try {
        await for (final event in connect(cancel!)) {
          if (!active) return;
          if (event.event == 'ready') {
            backoff = const Duration(seconds: 2);
            emit(const AuctionLive(LiveState.live));
            // Reload once subscribed: nothing between the first load and now is missed.
            onChange(null);
            continue;
          }
          final update = AuctionLiveUpdate.fromEvent(event);
          if (update == null) continue;
          onChange(update);
          emit(AuctionLive(LiveState.live, update));
          if (isFinal != null && isFinal(update)) {
            active = false;
            return;
          }
        }
      } on ApiException catch (error) {
        if (error.kind == ApiErrorKind.notFound || error.kind == ApiErrorKind.cancelled) return;
      } catch (_) {
        // Dropped connection: retry below.
      }
      if (!active) return;
      emit(const AuctionLive(LiveState.offline));
      await Future<void>.delayed(backoff);
      final doubled = backoff * 2;
      backoff = doubled > const Duration(seconds: 30) ? const Duration(seconds: 30) : doubled;
    }
  }

  unawaited(run());
  return controller.stream;
}

/// One auction, live, while its screen is open.
final auctionLiveProvider = StreamProvider.autoDispose.family<AuctionLive, int>((ref, id) {
  return _follow(
    ref,
    (cancel) => ref.read(auctionRepositoryProvider).liveEvents([id], single: true, cancelToken: cancel),
    (update) {
      ref.invalidate(auctionProvider(id));
      if (update != null) ref.invalidate(auctionsProvider);
    },
    isFinal: (update) => update.type == 'cancelled',
  );
});

/// The open auctions of the list, live, while the list is on screen (up to 50).
final auctionsLiveProvider = StreamProvider.autoDispose<AuctionLive>((ref) {
  // Only the set of open ids matters: reloading the list must not reconnect.
  final key = ref.watch(
    auctionsProvider.select((value) {
      final now = DateTime.now();
      final ids = (value.value ?? const []).where((a) => a.isLive(now)).map((a) => a.id).take(50).toList()..sort();
      return ids.join(',');
    }),
  );
  if (key.isEmpty) return Stream.value(const AuctionLive(LiveState.offline));
  final ids = key.split(',').map(int.parse).toList();
  Timer? pending;
  ref.onDispose(() => pending?.cancel());
  return _follow(
    ref,
    (cancel) => ref.read(auctionRepositoryProvider).liveEvents(ids, cancelToken: cancel),
    (_) {
      // Events and every (re)subscription alike: what happened while not connected was missed.
      // Several bids in a burst cause one reload.
      pending?.cancel();
      pending = Timer(const Duration(milliseconds: 800), () => ref.invalidate(auctionsProvider));
    },
  );
});
