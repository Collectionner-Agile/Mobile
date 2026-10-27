import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeReply {
  const FakeReply(this.status, [this.body, this.headers = const {}]);
  final int status;
  final Object? body;
  final Map<String, String> headers;
}

typedef FakeHandler = FakeReply Function(RequestOptions request);

/// In-memory HTTP layer for tests. Routes are keyed "METHOD /path" (query
/// string excluded). Unknown routes answer 404 so missing stubs are visible.
class FakeBackend implements HttpClientAdapter {
  FakeBackend([Map<String, FakeHandler>? routes]) : routes = routes ?? {};

  final Map<String, FakeHandler> routes;
  final List<RequestOptions> requests = [];
  bool offline = false;

  void on(String method, String path, FakeHandler handler) => routes['$method $path'] = handler;
  void json(String method, String path, Object? body, {int status = 200}) =>
      on(method, path, (_) => FakeReply(status, body));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) await requestStream.drain<void>();
    if (offline) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, error: 'offline');
    }
    final handler = routes['${options.method} ${options.uri.path}'];
    final reply = handler == null ? const FakeReply(404, {'detail': 'not stubbed'}) : handler(options);
    final payload = reply.body == null ? '' : jsonEncode(reply.body);
    return ResponseBody.fromString(
      payload,
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final entry in reply.headers.entries) entry.key: [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Minimal valid HS256-shaped JWT with a far-future `exp`.
String fakeJwt({DateTime? expires}) {
  String part(Map<String, Object> value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final exp = (expires ?? DateTime.now().add(const Duration(days: 1))).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'sub': '1', 'exp': exp})}.signature';
}

abstract final class Fixtures {
  static Map<String, Object?> user({int id = 1}) => {
    'id': id,
    'username': 'collector_prime',
    'email': 'diego@collectioneer.art',
    'name': 'Diego Collector',
    'bio': 'Custodio de consolas retro.',
    'location': 'Lima, Perú',
    'memberSince': '2024-01-10T00:00:00Z',
    'hasLocalPassword': true,
  };

  static Map<String, Object?> collectible({
    int id = 1,
    String name = 'The Legend of Zelda: Ocarina of Time',
    String category = 'Videojuegos Retro',
    num value = 1420,
    int ownerId = 2,
    int? auctionId,
  }) => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'ownerName': 'galaxy_builder',
    'value': value,
    'description': 'Cartucho original con caja y manual en muy buen estado.',
    'isLinkedToProcess': auctionId != null,
    'auctionId': auctionId,
    'rating': 4.5,
    'reviewCount': 2,
    'createdAt': '2026-10-0${id % 9 + 1}T10:00:00Z',
    'category': category,
    'eraYear': 1998,
    'media': <Object>[],
    'primaryImageUrl': '/assets/collectibles/games/retro-console.webp',
  };

  static List<Map<String, Object?>> catalogue() => [
    collectible(),
    collectible(id: 2, name: 'Charizard Holo Base Set', category: 'TCG & Cartas', value: 2310),
    collectible(id: 3, name: 'Reloj Omega Seamaster 1968', category: 'Relojería Vintage', value: 640),
    collectible(id: 4, name: 'Lego Millennium Falcon 75192', category: 'Lego & Sets', value: 890, auctionId: 7),
  ];

  static Map<String, Object?> auction({int id = 7, bool open = true, int auctioneerId = 2}) => {
    'id': id,
    'communityId': 1,
    'auctioneerId': auctioneerId,
    'auctioneerName': 'galaxy_builder',
    'collectibleId': 4,
    'collectibleName': 'Lego Millennium Falcon 75192',
    'collectibleImage': '/assets/collectibles/records/star-destroyer-model.webp',
    'startingPrice': 500,
    'currentHighestBid': 780,
    'bidCount': 2,
    'deadline': DateTime.now().toUtc().add(Duration(hours: open ? 30 : -1)).toIso8601String(),
    'isOpen': open,
    'createdAt': '2026-10-01T10:00:00Z',
    'updatedAt': '2026-10-01T10:00:00Z',
    'bids': [
      {
        'id': 1,
        'auctionId': id,
        'amount': 700,
        'bidderId': 3,
        'bidderName': 'poke_vault',
        'createdAt': '2026-10-02T10:00:00Z',
      },
      {
        'id': 2,
        'auctionId': id,
        'amount': 780,
        'bidderId': 1,
        'bidderName': 'collector_prime',
        'createdAt': '2026-10-03T10:00:00Z',
      },
    ],
  };

  static Map<String, Object?> community({int id = 1, bool joined = false}) => {
    'id': id,
    'name': id == 1 ? 'Retro Gaming Preservation' : 'Lego Builders Guild',
    'description': 'Conservación de consolas, cartuchos y cajas originales.',
    'imageUrl': null,
    'memberCount': 128,
    'postCount': 14,
    'isJoined': joined,
  };

  static Map<String, Object?> recognition({
    String status = 'available',
    String action = 'place_bid',
    double confidence = 0.86,
    bool withAlternatives = false,
  }) => {
    'analysis_id': 'a1',
    'detected': true,
    'product_name': 'Lego Millennium Falcon',
    'category': 'construction set',
    'catalog_category': 'Lego & Sets',
    'brand': 'LEGO',
    'model': '75192',
    'attributes': {'packaging': 'sealed box'},
    'visible_text': ['LEGO', 'STAR WARS', '75192'],
    'confidence': confidence,
    'ambiguities': ['edition not visible'],
    'catalog_match': {
      'collectible_id': 4,
      'name': 'Lego Millennium Falcon 75192',
      'category': 'Lego & Sets',
      'image_url': null,
      'score': 0.82,
      'auction_id': 7,
      'auction_open': true,
    },
    'alternatives': withAlternatives
        ? [
            {'collectible_id': 9, 'name': 'Lego Falcon 7965', 'score': 0.74, 'auction_open': false},
          ]
        : <Object>[],
    'purchase_status': status,
    'reason_code': 'OPEN_AUCTION',
    'reason': 'La pieza coincidente está en una subasta abierta.',
    'suggested_action': action,
    'model_version': 'gemini-3.8-flash',
    'analyzed_at': '2026-10-27T10:00:00Z',
  };

  /// Stubs every read the main screens perform.
  static FakeBackend standardBackend() {
    final backend = FakeBackend();
    backend
      ..json('GET', '/api/v1/collectibles', catalogue())
      ..json('GET', '/api/v1/auctions', [auction()])
      ..json('GET', '/api/v1/communities', [community(), community(id: 2, joined: true)])
      ..json('GET', '/api/v1/communities/search', [community()])
      ..json('GET', '/api/v1/recognition/status', {'enabled': true, 'model': 'gemini-3.8-flash'})
      ..json('GET', '/api/v1/auth/me', user())
      ..json('GET', '/api/v1/communities/user/1', [community(id: 2, joined: true)]);
    for (final item in catalogue()) {
      final id = item['id']! as int;
      backend
        ..json('GET', '/api/v1/collectibles/$id', item)
        ..json('GET', '/api/v1/collectibles/$id/reviews', [
          {
            'id': 1,
            'userId': 3,
            'userName': 'poke_vault',
            'collectibleId': id,
            'content': 'Pieza impecable.',
            'rating': 5,
            'createdAt': '2026-10-04T10:00:00Z',
          },
        ])
        ..json('GET', '/api/v1/collectibles/$id/comments', [
          {
            'id': 1,
            'authorId': 3,
            'authorName': 'poke_vault',
            'body': '¿Incluye manual?',
            'createdAt': '2026-10-04T10:00:00Z',
          },
        ]);
    }
    backend
      ..json('GET', '/api/v1/auctions/7', auction())
      ..json('GET', '/api/v1/communities/1', community())
      ..json('GET', '/api/v1/communities/1/feed', [
        {
          'id': 1,
          'title': 'Zelda OoT',
          'description': 'Cartucho',
          'createdAt': '2026-10-01T10:00:00Z',
          'username': 'collector_prime',
          'userId': 1,
          'communityId': 1,
          'communityName': 'Retro',
          'itemType': 'collectible',
          'value': 1420,
        },
        {
          'id': 5,
          'title': 'Cómo limpiar contactos',
          'description': 'Alcohol isopropílico',
          'createdAt': '2026-10-02T10:00:00Z',
          'username': 'poke_vault',
          'userId': 3,
          'communityId': 1,
          'communityName': 'Retro',
          'itemType': 'post',
        },
      ]);
    return backend;
  }
}
