import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Offline stand-in for the Spring backend, used only in builds made with
/// `--dart-define=DEMO_MODE=true` so the app can be explored without a server.
///
/// It serves a snapshot of the backend's development seed
/// (`assets/demo/seed.json`) and keeps writes (bids, joins, comments, new
/// pieces) in memory for the session. Nothing leaves the phone; the UI shows a
/// "demo" notice so this is never mistaken for the real service. Camera
/// recognition and photo upload need the server and answer "unavailable".
class DemoBackend implements HttpClientAdapter {
  DemoBackend({Future<String> Function()? loadSeed})
    : _loadSeed = loadSeed ?? (() => rootBundle.loadString('assets/demo/seed.json'));

  final Future<String> Function() _loadSeed;
  Map<String, dynamic>? _db;
  int _nextId = 1000;

  static const _latency = Duration(milliseconds: 280);

  Future<Map<String, dynamic>> _data() async => _db ??= jsonDecode(await _loadSeed()) as Map<String, dynamic>;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) await requestStream.drain<void>();
    await Future<void>.delayed(_latency);
    final db = await _data();
    final (status, body) = _route(db, options.method, options.uri.path, options.uri.queryParameters, options.data);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  (int, Object?) _route(
    Map<String, dynamic> db,
    String method,
    String fullPath,
    Map<String, String> query,
    Object? raw,
  ) {
    final path = fullPath.replaceFirst('/api/v1', '');
    final body = raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    int? idAt(int index) => segments.length > index ? int.tryParse(segments[index]) : null;
    final me = db['me'] as Map<String, dynamic>;

    List<dynamic> list(String key) => db[key] as List<dynamic>;
    Map<String, dynamic> map(String key) => db[key] as Map<String, dynamic>;
    Map<String, dynamic>? byId(String key, int? id) =>
        list(key).cast<Map<String, dynamic>>().where((e) => e['id'] == id).firstOrNull;
    String now() => DateTime.now().toUtc().toIso8601String();

    switch ((method, segments)) {
      // Auth: any credentials open the demo account; nothing is checked or sent.
      case ('POST', ['auth', 'login']) || ('POST', ['auth', 'register']):
        return (
          200,
          {
            'token': _demoToken(),
            'userId': me['id'],
            'username': me['username'],
            'name': me['name'],
            'email': me['email'],
            'user': me,
          },
        );
      case ('GET', ['auth', 'me']) || ('GET', ['users', 'me']):
        return (200, me);
      case ('GET', ['auth', 'oauth', 'providers']):
        return (200, {'google': false, 'github': false});
      case ('POST', ['auth', 'logout']):
        return (204, null);
      case ('GET', ['users', _]):
        final user = map('users')['${idAt(1)}'];
        return user == null ? _notFound() : (200, user);
      case ('PUT', ['users', 'me']) || ('PATCH', ['users', 'me']):
        me.addAll(body);
        return (200, me);

      // Catalogue.
      case ('GET', ['collectibles']):
        return (200, list('collectibles'));
      case ('GET', ['collectibles', _]):
        final item = byId('collectibles', idAt(1));
        return item == null ? _notFound() : (200, item);
      case ('POST', ['collectibles']):
        final item = <String, dynamic>{
          ...body,
          'id': ++_nextId,
          'ownerId': me['id'],
          'ownerName': me['username'],
          'rating': 0,
          'reviewCount': 0,
          'createdAt': now(),
          'images': const <String>[],
        };
        list('collectibles').insert(0, item);
        return (201, item);
      case ('DELETE', ['collectibles', _]):
        list('collectibles').removeWhere((e) => (e as Map)['id'] == idAt(1));
        return (204, null);
      case ('GET', ['collectibles', _, 'comments']):
        return (200, map('comments')['${idAt(1)}'] ?? const []);
      case ('POST', ['collectibles', _, 'comments']):
        final comment = _comment(me, body['body'], now());
        ((map('comments')['${idAt(1)}'] ??= <dynamic>[]) as List<dynamic>).add(comment);
        return (201, comment);
      case ('GET', ['collectibles', _, 'reviews']):
        return (200, map('reviews')['${idAt(1)}'] ?? const []);
      case ('POST', ['collectibles', _, 'reviews']):
        final review = {
          'id': ++_nextId,
          'userId': me['id'],
          'userName': me['username'],
          'collectibleId': idAt(1),
          'content': body['content'],
          'rating': body['rating'],
          'createdAt': now(),
        };
        ((map('reviews')['${idAt(1)}'] ??= <dynamic>[]) as List<dynamic>).insert(0, review);
        return (201, review);

      // Auctions.
      case ('GET', ['auctions']):
        return (200, list('auctions'));
      case ('GET', ['auctions', _]):
        final auction = byId('auctions', idAt(1));
        return auction == null ? _notFound() : (200, auction);
      case ('POST', ['auctions', 'bids']):
        final auction = byId('auctions', (body['auctionId'] as num?)?.toInt());
        if (auction == null) return _notFound();
        final amount = (body['amount'] as num).toDouble();
        final current = ((auction['currentHighestBid'] ?? auction['startingPrice']) as num).toDouble();
        if (amount <= current) {
          return (400, {'title': 'Puja inválida', 'detail': 'La puja debe superar la oferta actual.'});
        }
        final bid = {
          'id': ++_nextId,
          'auctionId': auction['id'],
          'amount': amount,
          'bidderId': me['id'],
          'bidderName': me['username'],
          'createdAt': now(),
        };
        auction['currentHighestBid'] = amount;
        auction['bidCount'] = ((auction['bidCount'] as num?) ?? 0) + 1;
        (auction['bids'] as List<dynamic>).insert(0, bid);
        return (201, bid);
      case ('POST', ['auctions']):
        final piece = byId('collectibles', (body['collectibleId'] as num?)?.toInt());
        final auction = {
          'id': ++_nextId,
          'communityId': piece?['communityId'] ?? 0,
          'auctioneerId': me['id'],
          'auctioneerName': me['username'],
          'collectibleId': body['collectibleId'],
          'collectibleName': piece?['name'],
          'collectibleImage': piece?['imageUrl'],
          'startingPrice': body['startingPrice'],
          'currentHighestBid': null,
          'bidCount': 0,
          'deadline': body['deadline'],
          'isOpen': true,
          'createdAt': now(),
          'bids': <dynamic>[],
        };
        list('auctions').insert(0, auction);
        if (piece != null) piece['auctionId'] = auction['id'];
        return (201, auction);
      case ('DELETE', ['auctions', _]):
        byId('auctions', idAt(1))?['isOpen'] = false;
        return (204, null);

      // Communities.
      case ('GET', ['communities']):
        return (200, list('communities').map((c) => _withJoined(db, c)).toList());
      case ('GET', ['communities', 'search']):
        final term = (query['SearchTerm'] ?? '').toLowerCase();
        return (
          200,
          list('communities')
              .where((c) => '${(c as Map)['name']} ${c['description']}'.toLowerCase().contains(term))
              .map((c) => _withJoined(db, c))
              .toList(),
        );
      case ('GET', ['communities', 'user', _]):
        final mine = (db['myCommunities'] as List<dynamic>).toSet();
        return (
          200,
          list('communities').where((c) => mine.contains((c as Map)['id'])).map((c) => _withJoined(db, c)).toList(),
        );
      case ('GET', ['communities', _]):
        final community = byId('communities', idAt(1));
        return community == null ? _notFound() : (200, _withJoined(db, community));
      case ('POST', ['communities']):
        final community = {
          'id': ++_nextId,
          'name': body['name'],
          'description': body['description'],
          'imageUrl': null,
          'memberCount': 1,
          'postCount': 0,
        };
        list('communities').add(community);
        (db['myCommunities'] as List<dynamic>).add(community['id']);
        return (201, _withJoined(db, community));
      case ('POST', ['communities', _, 'join']):
        final mine = db['myCommunities'] as List<dynamic>;
        if (!mine.contains(idAt(1))) {
          mine.add(idAt(1));
          final c = byId('communities', idAt(1));
          if (c != null) c['memberCount'] = ((c['memberCount'] as num?) ?? 0) + 1;
        }
        return (204, null);
      case ('DELETE', ['communities', _, 'join']):
        final mine = db['myCommunities'] as List<dynamic>;
        if (mine.remove(idAt(1))) {
          final c = byId('communities', idAt(1));
          if (c != null) c['memberCount'] = ((c['memberCount'] as num?) ?? 1) - 1;
        }
        return (204, null);
      case ('GET', ['communities', _, 'feed']):
        final term = (query['query'] ?? '').toLowerCase();
        final feed = (map('feeds')['${idAt(1)}'] as List<dynamic>?) ?? const [];
        return (
          200,
          term.isEmpty
              ? feed
              : feed.where((f) => '${(f as Map)['title']} ${f['description']}'.toLowerCase().contains(term)).toList(),
        );

      // Posts.
      case ('POST', ['posts']):
        final post = {
          'id': ++_nextId,
          'title': body['title'],
          'content': body['content'],
          'authorId': me['id'],
          'authorName': me['username'],
          'communityId': body['communityId'],
          'createdAt': now(),
          'commentsCount': 0,
        };
        map('posts')['${post['id']}'] = post;
        ((map('feeds')['${body['communityId']}'] ??= <dynamic>[]) as List<dynamic>).insert(0, {
          'id': post['id'],
          'title': post['title'],
          'description': post['content'],
          'createdAt': post['createdAt'],
          'username': me['username'],
          'userId': me['id'],
          'communityId': body['communityId'],
          'itemType': 'post',
        });
        return (201, post);
      case ('GET', ['posts', _]):
        final post = map('posts')['${idAt(1)}'];
        return post == null ? _notFound() : (200, post);
      case ('DELETE', ['posts', _]):
        map('posts').remove('${idAt(1)}');
        for (final feed in map('feeds').values) {
          (feed as List<dynamic>).removeWhere((f) => (f as Map)['id'] == idAt(1) && f['itemType'] == 'post');
        }
        return (204, null);
      case ('GET', ['posts', _, 'comments']):
        return (200, map('postComments')['${idAt(1)}'] ?? const []);
      case ('POST', ['posts', _, 'comments']):
        final comment = _comment(me, body['body'], now());
        ((map('postComments')['${idAt(1)}'] ??= <dynamic>[]) as List<dynamic>).add(comment);
        return (201, comment);

      // Needs the real server.
      case ('GET', ['recognition', 'status']):
        return (200, {'enabled': false, 'model': null});
      case (_, ['recognition', ...]) || (_, ['media', ...]):
        return (
          503,
          {'title': 'No disponible', 'detail': 'Esta función no está disponible por ahora. Inténtalo más tarde.'},
        );
    }
    return _notFound();
  }

  Map<String, dynamic> _withJoined(Map<String, dynamic> db, Object? community) {
    final c = (community as Map).cast<String, dynamic>();
    return {...c, 'isJoined': (db['myCommunities'] as List<dynamic>).contains(c['id'])};
  }

  Map<String, dynamic> _comment(Map<String, dynamic> me, Object? text, String createdAt) => {
    'id': ++_nextId,
    'authorId': me['id'],
    'authorName': me['username'],
    'body': text,
    'createdAt': createdAt,
  };

  (int, Object?) _notFound() => (404, {'title': 'No encontrado', 'detail': 'No existe o ya no está disponible.'});

  /// Unsigned token in JWT shape so the session logic (expiry check) works.
  static String _demoToken() {
    String part(Map<String, Object> value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
    return '${part({'alg': 'none'})}.${part({'sub': 'demo', 'exp': exp})}.demo';
  }
}
