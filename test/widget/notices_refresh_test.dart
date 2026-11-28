import 'package:collectionner/features/notifications/notices.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

const _path = '/api/v1/users/me/notifications';

/// A little longer than the time between two automatic refreshes.
const _nextRefresh = Duration(seconds: 61);

/// What the server says right now; each test changes it while the app runs.
class _Server {
  _Server() {
    backend.on('GET', _path, (_) {
      if (down) return const FakeReply(503, {'title': 'down'});
      return FakeReply(200, {
        'items': [
          if (outbid)
            {
              'id': 4,
              'type': 'OUTBID',
              'title': 'Te superaron',
              'body': 'Alguien ofreció S/ 900.',
              'targetType': 'auction',
              'targetId': 7,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'read': false,
            },
        ],
      });
    });
    backend.on('GET', '/api/v1/auctions', (_) {
      final auction = Fixtures.auction();
      return FakeReply(200, [
        if (!outbid)
          auction
        else
          {
            ...auction,
            'currentHighestBid': 900,
            'bids': [
              ...auction['bids']! as List,
              {'id': 3, 'auctionId': 7, 'amount': 900, 'bidderId': 3, 'bidderName': 'poke_vault'},
            ],
          },
      ]);
    });
  }

  final backend = Fixtures.standardBackend();

  /// A rival has outbid the member.
  bool outbid = false;
  bool down = false;

  int get fetches => backend.requests.where((r) => r.method == 'GET' && r.uri.path == _path).length;
}

List<String> _ids(TestApp app) => app.container.read(noticesProvider).map((n) => n.id).toList();

Future<void> _lifecycle(WidgetTester tester, List<AppLifecycleState> states) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

const _toBackground = [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused];
const _toForeground = [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed];

void main() {
  testWidgets('opening the notices shows what arrived after signing in', (tester) async {
    final server = _Server();
    await pumpApp(tester, backend: server.backend, signedIn: true);

    server.outbid = true;
    await tester.tap(find.byTooltip('Avisos'));
    await settle(tester);

    expect(find.text('Te superaron'), findsOneWidget);
    expect(find.text('Vas ganando'), findsNothing);
  });

  testWidgets('a new notice reaches the bell while the app is on screen', (tester) async {
    final server = _Server();
    final app = await pumpApp(tester, backend: server.backend, signedIn: true);
    expect(_ids(app), isNot(contains('srv-4')));

    server.outbid = true;
    await tester.pump(_nextRefresh);
    await settle(tester);

    expect(_ids(app), contains('srv-4'));
    // The auctions were reloaded too: the phone no longer thinks the member leads.
    expect(app.container.read(noticesProvider).where((n) => n.kind == NoticeKind.leading), isEmpty);
  });

  testWidgets('nothing is asked in the background and returning to the app asks again', (tester) async {
    final server = _Server();
    final app = await pumpApp(tester, backend: server.backend, signedIn: true);

    await _lifecycle(tester, _toBackground);
    final before = server.fetches;
    server.outbid = true;
    await tester.pump(_nextRefresh * 3);
    expect(server.fetches, before);

    await _lifecycle(tester, _toForeground);
    await settle(tester);
    expect(server.fetches, before + 1);
    expect(_ids(app), contains('srv-4'));
  });

  testWidgets('a refresh that fails keeps the notices already received', (tester) async {
    final server = _Server()..outbid = true;
    final app = await pumpApp(tester, backend: server.backend, signedIn: true);
    expect(_ids(app), contains('srv-4'));

    server.down = true;
    final before = server.fetches;
    await tester.pump(_nextRefresh);
    await settle(tester);

    expect(server.fetches, greaterThan(before));
    expect(_ids(app), contains('srv-4'));
  });

  testWidgets('a guest is never asked about', (tester) async {
    final server = _Server();
    await pumpApp(tester, backend: server.backend);

    await tester.pump(_nextRefresh * 2);
    await settle(tester);

    expect(server.fetches, 0);
  });

  testWidgets('with server notices an outbid member is not told they are winning', (tester) async {
    final server = _Server()..outbid = true;
    final app = await pumpApp(tester, backend: server.backend, signedIn: true);

    final kinds = app.container.read(noticesProvider).map((n) => n.kind);
    expect(kinds, contains(NoticeKind.outbid));
    expect(kinds, isNot(contains(NoticeKind.leading)));
  });

  testWidgets('with server notices the leader is still told they are winning', (tester) async {
    final server = _Server();
    final app = await pumpApp(tester, backend: server.backend, signedIn: true);

    expect(app.container.read(noticesProvider).map((n) => n.kind), contains(NoticeKind.leading));
  });
}
