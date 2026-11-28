import 'dart:convert';

import 'package:collectionner/app/preferences.dart';
import 'package:collectionner/app/providers.dart';
import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/core/network/sse.dart';
import 'package:collectionner/features/auctions/application/auction_live.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Server-Sent Events parser', () {
    Stream<List<int>> bytes(List<String> chunks) => Stream.fromIterable(chunks.map(utf8.encode));

    test('named events, data split over lines and chunks, comments ignored', () async {
      final events = await parseSse(bytes([
        ': ping\n\nevent: ready\ndata: {"auctionIds":[4]}\n\n',
        'event:bid\ndata:{"auctionId":4,\ndata:"amount":150}\n',
        '\nid: 7\ndata: plain\n\n',
      ])).toList();

      expect(events.map((e) => e.event), ['ready', 'bid', 'message']);
      expect(events[0].json, {'auctionIds': [4]});
      expect(events[1].data, '{"auctionId":4,\n"amount":150}');
      expect(events[1].json?['amount'], 150);
      expect(events[2].id, '7');
      expect(events[2].json, isNull);
    });
  });

  group('live auction', () {
    late FakeBackend backend;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      backend = FakeBackend();
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureSessionStoreProvider.overrideWithValue(MemorySessionStore()),
          apiClientProvider.overrideWithValue(
            ApiClient(
              dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080'))..httpClientAdapter = backend,
              readToken: () => null,
              readLanguage: () => 'es',
              onUnauthorized: () {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    int count(String method, String path) =>
        backend.requests.where((r) => r.method == method && r.uri.path == path).length;

    test('announces bids and results and reloads the auction each time', () async {
      backend
        ..on(
          'GET',
          '/api/v1/auctions/4/events',
          (_) => const FakeReply.text(
            200,
            'event:ready\ndata:{"auctionIds":[4]}\n\n'
            'event:bid\ndata:{"auctionId":4,"amount":150,"bidCount":1,"bidderName":"bob"}\n\n'
            'event:closed\ndata:{"auctionId":4,"sold":true,"winnerName":"bob","winningBid":150}\n\n',
          ),
        )
        ..json('GET', '/api/v1/auctions/4', {'id': 4, 'collectibleId': 1, 'startingPrice': 100, 'isOpen': true});

      final updates = <AuctionLive>[];
      final sub = container.listen(auctionLiveProvider(4), (_, next) {
        if (next.value != null) updates.add(next.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      for (var i = 0; i < 50 && !updates.any((u) => u.update?.type == 'closed'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final bid = updates.firstWhere((u) => u.update?.type == 'bid').update!;
      expect(bid.amount, 150);
      expect(bid.bidderName, 'bob');
      final closed = updates.firstWhere((u) => u.update?.type == 'closed').update!;
      expect(closed.sold, isTrue);
      expect(closed.winnerName, 'bob');
      expect(updates.any((u) => u.state == LiveState.live), isTrue);
    });

    test('an auction that does not exist is not retried', () async {
      // Nothing stubbed: the stream answers 404.
      final sub = container.listen(auctionLiveProvider(9), (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count('GET', '/api/v1/auctions/9/events'), 1);
    });

    test('a withdrawn auction stops the stream for good', () async {
      backend.on(
        'GET',
        '/api/v1/auctions/5/events',
        (_) => const FakeReply.text(200, 'event:ready\ndata:{"auctionIds":[5]}\n\nevent:cancelled\ndata:{"auctionId":5}\n\n'),
      );
      final sub = container.listen(auctionLiveProvider(5), (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(count('GET', '/api/v1/auctions/5/events'), 1);
      expect(sub.read().value?.update?.type, 'cancelled');
    });

    test('a dropped connection comes back by itself', () async {
      backend.on('GET', '/api/v1/auctions/6/events', (_) => const FakeReply.text(200, 'event:ready\ndata:{"auctionIds":[6]}\n\n'));
      final sub = container.listen(auctionLiveProvider(6), (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sub.read().value?.state, LiveState.offline, reason: 'the server closed the stream');
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(count('GET', '/api/v1/auctions/6/events'), 2);
    });

    test('the list reloads after every (re)connection, so nothing missed stays stale', () async {
      backend
        ..json('GET', '/api/v1/auctions', [Fixtures.auction()])
        // Subscribes and is then ended by the server, without any bid in between.
        ..on('GET', '/api/v1/auctions/events', (_) => const FakeReply.text(200, 'event:ready\ndata:{"auctionIds":[7]}\n\n'));
      final sub = container.listen(auctionsLiveProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      // First connection: the list, then once more when subscribed (after the 800 ms grouping).
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(count('GET', '/api/v1/auctions/events'), 1, reason: 'reloading must not reconnect');
      expect(count('GET', '/api/v1/auctions'), 2);

      // The app comes back 2 s after the stream ended, and reloads what it may have missed.
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(count('GET', '/api/v1/auctions/events'), 2);
      expect(count('GET', '/api/v1/auctions'), 3);
    });
  });
}
