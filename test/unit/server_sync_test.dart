import 'dart:convert';

import 'package:collectionner/app/preferences.dart';
import 'package:collectionner/app/providers.dart';
import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/features/auctions/application/watchlist.dart';
import 'package:collectionner/features/auctions/domain/auction_models.dart';
import 'package:collectionner/features/auth/application/session_controller.dart';
import 'package:collectionner/features/auth/domain/user.dart';
import 'package:collectionner/features/favorites/favorites.dart';
import 'package:collectionner/features/notifications/notices.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const user = AppUser(id: 7, username: 'ana', name: 'Ana');

  Future<(ProviderContainer, FakeBackend, SharedPreferences)> build({
    Map<String, Object> prefs = const {},
    AppUser? signedIn = user,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureSessionStoreProvider.overrideWithValue(MemorySessionStore()),
        currentUserProvider.overrideWithValue(signedIn),
        apiClientProvider.overrideWithValue(
          ApiClient(
            dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080'))..httpClientAdapter = backend,
            readToken: () => 'token',
            readLanguage: () => 'es',
            onUnauthorized: () {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container, backend, preferences);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('favorites and watchlist follow the account', () {
    test('signing in uploads what the phone saved and adopts the merged server list', () async {
      final (container, backend, prefs) = await build(prefs: {'pref.favorites': ['1', '2']});
      backend.on('POST', '/api/v1/users/me/favorites/sync', (options) {
        final sent = (options.data is String ? jsonDecode(options.data as String) : options.data) as Map;
        expect((sent['ids'] as List).toSet(), {1, 2});
        return const FakeReply(200, {'ids': [3, 2, 1]});
      });

      container.read(favoritesProvider);
      for (var i = 0; i < 50 && container.read(favoritesProvider).length < 3; i++) {
        await settle();
      }

      expect(container.read(favoritesProvider), {1, 2, 3});
      expect(prefs.getStringList('pref.favorites')!.toSet(), {'1', '2', '3'});
    });

    test('a change is saved at once and sent to the server', () async {
      final (container, backend, _) = await build();
      backend.json('POST', '/api/v1/users/me/watchlist/sync', {'ids': <int>[]});
      backend.json('PUT', '/api/v1/users/me/watchlist/40', null, status: 204);
      container.read(watchedAuctionsProvider);
      await settle();

      expect(await container.read(watchedAuctionsProvider.notifier).toggle(40), isTrue);
      await settle();

      expect(container.read(watchedAuctionsProvider), {40});
      expect(backend.requests.map((r) => '${r.method} ${r.uri.path}'), contains('PUT /api/v1/users/me/watchlist/40'));
    });

    test('a removal that fails is remembered and sent before the next sync, so it does not come back', () async {
      final (container, backend, prefs) = await build(prefs: {'pref.favorites': ['5']});
      backend.json('POST', '/api/v1/users/me/favorites/sync', {'ids': [5]});
      container.read(favoritesProvider);
      await settle();

      backend.json('DELETE', '/api/v1/users/me/favorites/5', {'title': 'down'}, status: 503);
      await container.read(favoritesProvider.notifier).toggle(5);
      await settle();
      expect(prefs.getStringList('pref.favorites.removedPending'), ['5']);

      backend
        ..json('DELETE', '/api/v1/users/me/favorites/5', null, status: 204)
        ..json('POST', '/api/v1/users/me/favorites/sync', {'ids': <int>[]});
      await container.read(favoritesProvider.notifier).syncNow();

      expect(container.read(favoritesProvider), isEmpty);
      expect(prefs.getStringList('pref.favorites.removedPending'), isEmpty);
    });

    test('signed out, nothing is sent and the phone keeps its list', () async {
      final (container, backend, _) = await build(signedIn: null);
      await container.read(favoritesProvider.notifier).toggle(9);
      await settle();
      expect(container.read(favoritesProvider), {9});
      expect(backend.requests, isEmpty);
    });
  });

  group('server notifications', () {
    test('bids and results come from the server with their own words and target', () async {
      final (container, backend, _) = await build();
      backend.json('GET', '/api/v1/users/me/notifications', {
        'items': [
          {
            'id': 11,
            'type': 'AUCTION_WON',
            'title': '¡Ganaste «Omega»!',
            'body': 'Tu oferta de S/ 200.00 fue la más alta.',
            'targetType': 'auction',
            'targetId': 4,
            'createdAt': '2026-11-25T12:00:00Z',
            'read': false,
          },
          {
            'id': 10,
            'type': 'OUTBID',
            'title': 'Te superaron',
            'body': 'x',
            'targetType': 'auction',
            'targetId': 4,
            'createdAt': '2026-11-25T11:00:00Z',
            'read': true,
          },
        ],
        'page': 0,
        'size': 50,
        'hasNext': false,
      });

      final notices = await container.read(serverNoticesProvider.future);

      expect(notices, hasLength(2));
      expect(notices!.first.title, '¡Ganaste «Omega»!');
      expect(notices.first.route, '/auctions/4');
      expect(notices.first.kind, NoticeKind.ended);
      expect(notices.last.kind, NoticeKind.outbid);
      expect(notices.last.readOnServer, isTrue);
    });

    test('when the server is unreachable the phone derives them as before', () async {
      final (container, _, _) = await build();
      expect(await container.read(serverNoticesProvider.future), isNull);
    });
  });

  test('a settled auction names its official winner', () {
    final auction = Auction.fromJson({
      'id': 4,
      'collectibleId': 1,
      'startingPrice': 100,
      'isOpen': false,
      'status': 'closed',
      'closedAt': '2026-11-25T12:00:00Z',
      'winnerId': 7,
      'winnerName': 'ana',
      'winningBid': 200,
      'bids': [
        {'id': 1, 'amount': 200, 'bidderId': 7},
        {'id': 2, 'amount': 150, 'bidderId': 8},
      ],
    });
    expect(auction.settled, isTrue);
    expect(auction.leaderId, 7);
    expect(auction.winningBid, 200);
  });
}
