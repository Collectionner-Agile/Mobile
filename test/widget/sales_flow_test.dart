import 'package:collectionner/app/router/app_router.dart';
import 'package:collectionner/features/auth/presentation/auth_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// HU05: buying and selling a piece at a fixed price, from the phone.
void main() {
  const saleId = 30;

  Map<String, Object?> sale({
    String status = 'active',
    int sellerId = 2,
    int? buyerId,
    bool sellerConfirmed = false,
    bool buyerConfirmed = false,
  }) => {
    'id': saleId,
    'collectibleId': 2,
    'collectibleName': 'Charizard Holo Base Set',
    'collectibleImage': null,
    'sellerId': sellerId,
    'sellerName': sellerId == 1 ? 'collector_prime' : 'galaxy_builder',
    'buyerId': buyerId,
    'buyerName': buyerId == null ? null : (buyerId == 1 ? 'collector_prime' : 'poke_vault'),
    'price': 2100,
    'status': status,
    'sellerConfirmed': sellerConfirmed,
    'buyerConfirmed': buyerConfirmed,
    'createdAt': '2026-11-20T10:00:00Z',
  };

  /// The standard backend, with piece 2 for sale; [ownerId] 1 makes the signed-in user its seller.
  FakeBackend backendWith(Map<String, Object?> current, {int ownerId = 2}) {
    final backend = Fixtures.standardBackend();
    final piece = {
      ...Fixtures.collectible(id: 2, name: 'Charizard Holo Base Set', category: 'TCG & Cartas', value: 2310),
      'ownerId': ownerId,
      'isLinkedToProcess': true,
      'saleId': saleId,
    };
    backend
      ..json('GET', '/api/v1/collectibles/2', piece)
      ..on('GET', '/api/v1/sales/$saleId', (_) => FakeReply(200, current));
    return backend;
  }

  Future<void> openPiece(TestApp app, WidgetTester tester) async {
    app.container.read(routerProvider).go(Routes.collectible(2));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('sale-panel')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, 4);
  }

  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await settle(tester);
  }

  testWidgets('HU05-E1: a collector buys an active piece and sees it reserved for them', (tester) async {
    var current = sale();
    final backend = backendWith(current)
      ..on('POST', '/api/v1/sales/$saleId/purchase', (_) {
        current = sale(status: 'reserved', buyerId: 1);
        return FakeReply(200, current);
      });
    backend.on('GET', '/api/v1/sales/$saleId', (_) => FakeReply(200, current));
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    await openPiece(app, tester);

    expect(find.text('En venta'), findsWidgets);
    expect(find.text('Vende galaxy_builder'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sale-buy')));
    await settle(tester, 4);
    expect(find.text('Confirmar compra'), findsOneWidget);
    await confirmDialog(tester);

    expect(backend.requests.where((r) => r.method == 'POST' && r.uri.path.endsWith('/purchase')), hasLength(1));
    expect(find.text('Reservada'), findsOneWidget);
    expect(find.text('La reservaste tú'), findsOneWidget);
    expect(find.byKey(const Key('sale-buy')), findsNothing);
    expect(find.byKey(const Key('sale-confirm-receipt')), findsOneWidget);
  });

  testWidgets('HU05-E2: a piece taken meanwhile is reported as no longer available', (tester) async {
    final backend = backendWith(sale())
      ..json('POST', '/api/v1/sales/$saleId/purchase', {
        'status': 409,
        'detail': 'Esta pieza ya no está disponible para la compra.',
        'errorCode': 'SALE_NOT_AVAILABLE',
      }, status: 409);
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    await openPiece(app, tester);

    await tester.tap(find.byKey(const Key('sale-buy')));
    await settle(tester, 4);
    await confirmDialog(tester);
    expect(find.text('Esta pieza ya no está disponible. Mira otras parecidas más abajo.'), findsOneWidget);
  });

  testWidgets('HU05-E3: the seller of a piece is never offered to buy it, only to withdraw it', (tester) async {
    final backend = backendWith(sale(sellerId: 1), ownerId: 1)
      ..on('POST', '/api/v1/sales/$saleId/cancel', (_) => FakeReply(200, sale(sellerId: 1, status: 'cancelled')));
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    await openPiece(app, tester);

    expect(find.byKey(const Key('sale-buy')), findsNothing);
    expect(find.text('Retirar venta'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sale-cancel')));
    await settle(tester, 4);
    await confirmDialog(tester);
    expect(backend.requests.where((r) => r.method == 'POST' && r.uri.path.endsWith('/cancel')), hasLength(1));
  });

  testWidgets('a guest who taps buy is sent to sign in first', (tester) async {
    final app = await pumpApp(tester, backend: backendWith(sale()));
    await openPiece(app, tester);
    await tester.tap(find.byKey(const Key('sale-buy')));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the buyer confirms receipt; with both confirmations the piece is theirs', (tester) async {
    final backend = backendWith(sale(status: 'reserved', buyerId: 1, sellerConfirmed: true))
      ..on(
        'POST',
        '/api/v1/sales/$saleId/confirm-receipt',
        (_) => FakeReply(200, sale(status: 'completed', buyerId: 1, sellerConfirmed: true, buyerConfirmed: true)),
      );
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    await openPiece(app, tester);

    // The seller already confirmed the delivery, so the operation can no longer be called off.
    expect(find.text('Entrega confirmada por quien vende'), findsOneWidget);
    expect(find.byKey(const Key('sale-cancel')), findsNothing);
    await tester.tap(find.byKey(const Key('sale-confirm-receipt')));
    await settle(tester, 4);
    await confirmDialog(tester);
    expect(find.text('La pieza ya es tuya.'), findsOneWidget);
  });

  testWidgets('my purchases and sales list each operation with its status', (tester) async {
    final backend = Fixtures.standardBackend()
      ..on(
        'GET',
        '/api/v1/sales/mine',
        (options) => FakeReply(
          200,
          options.uri.queryParameters['role'] == 'buyer' ? [sale(status: 'reserved', buyerId: 1)] : <Object>[],
        ),
      );
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    app.container.read(routerProvider).go(Routes.mySales);
    await settle(tester);
    expect(find.text('Charizard Holo Base Set'), findsOneWidget);
    expect(find.text('Reservada'), findsOneWidget);

    await tester.tap(find.text('Ventas'));
    await settle(tester);
    expect(find.text('Aún no pusiste piezas en venta'), findsOneWidget);
  });

  testWidgets('the owner lists a free piece for sale at a fixed price', (tester) async {
    final backend = Fixtures.standardBackend()
      ..json('GET', '/api/v1/collectibles/3', {
        ...Fixtures.collectible(id: 3, name: 'Reloj Omega Seamaster 1968'),
        'ownerId': 1,
      })
      ..on('POST', '/api/v1/sales', (_) => FakeReply(201, {...sale(sellerId: 1), 'collectibleId': 3}));
    final app = await pumpApp(tester, backend: backend, signedIn: true);
    app.container.read(routerProvider).go(Routes.collectible(3));
    await settle(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester, 4);
    await tester.tap(find.text('Vender a precio fijo'));
    await settle(tester, 4);
    await tester.enterText(find.byKey(const Key('sale-price')), '700');
    await tester.tap(find.text('Publicar venta'));
    await settle(tester);

    final post = backend.requests.singleWhere((r) => r.method == 'POST' && r.uri.path == '/api/v1/sales');
    expect(post.data, {'collectibleId': 3, 'price': 700.0});
    expect(find.text('Pieza en venta.'), findsOneWidget);
  });
}
