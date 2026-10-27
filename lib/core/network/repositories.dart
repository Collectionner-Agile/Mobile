import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../../features/auctions/domain/auction_models.dart';
import '../../features/auth/domain/user.dart';
import '../../features/catalog/domain/catalog_models.dart';
import '../../features/communities/domain/community_models.dart';
import '../../features/recognition/domain/recognition_models.dart';
import '../utils/json.dart';
import 'api_client.dart';

const _v1 = '/api/v1';

class AuthResult {
  const AuthResult(this.token, this.user);
  final String token;
  final AppUser user;
}

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Options get _anonymous => Options(extra: {'anonymous': true});

  /// Parses the backend `LoginResponse` shared by password login and the
  /// OAuth ticket exchange.
  AuthResult _loginResult(Object? data, {String fallbackUsername = ''}) => parseObject(
    data,
    (json) => AuthResult(
      json.requireString('token'),
      AppUser(
        id: json.requireInt('userId'),
        username: json.stringOrNull('username') ?? fallbackUsername,
        name: json.stringOrNull('name') ?? '',
        email: json.stringOrNull('email'),
      ),
    ),
  );

  Future<AuthResult> login(String username, String password) => _api.post(
    '$_v1/auth/login',
    (data) => _loginResult(data, fallbackUsername: username),
    body: {'username': username, 'password': password},
    options: _anonymous,
  );

  /// Which external providers the server can complete right now.
  Future<Set<String>> oauthProviders() => _api.get(
    '$_v1/auth/oauth/providers',
    (data) => data is Map<String, dynamic>
        ? {
            for (final entry in data.entries)
              if (entry.value == true) entry.key,
          }
        : const <String>{},
    options: _anonymous,
  );

  /// Trades the single-use ticket from the OAuth callback for a session.
  Future<AuthResult> exchangeOAuthTicket(String ticket) =>
      _api.post('$_v1/auth/oauth/exchange', _loginResult, body: {'ticket': ticket}, options: _anonymous);

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    required String name,
  }) => _api.post(
    '$_v1/auth/register',
    (data) => parseObject(
      data,
      (json) => AuthResult(json.requireString('token'), AppUser.fromJson(json.objectOrNull('user')!)),
    ),
    body: {'username': username, 'email': email, 'password': password, 'name': name},
    options: _anonymous,
  );

  /// [bearer] is passed explicitly right after login, before the session is stored.
  Future<AppUser> me({String? bearer}) => _api.get(
    '$_v1/auth/me',
    (data) => parseObject(data, AppUser.fromJson),
    options: bearer == null ? null : Options(extra: {'anonymous': true}, headers: {'Authorization': 'Bearer $bearer'}),
  );

  Future<String?> forgotPassword(String email) => _api.post(
    '$_v1/auth/forgot-password',
    (data) => data is Map<String, dynamic> ? data.stringOrNull('message') : null,
    body: {'email': email},
    options: _anonymous,
  );

  Future<void> resetPassword({required String username, required String token, required String newPassword}) =>
      _api.post(
        '$_v1/auth/reset-password',
        (_) {},
        body: {'username': username, 'recoveryToken': token, 'newPassword': newPassword},
        options: _anonymous,
      );

  Future<void> changePassword(String currentPassword, String newPassword) => _api.post(
    '$_v1/auth/change-password',
    (_) {},
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  Future<void> logout() => _api.post('$_v1/auth/logout', (_) {});

  Future<void> deleteAccount(String currentPassword) =>
      _api.post('$_v1/auth/delete-account', (_) {}, body: {'currentPassword': currentPassword});

  Future<AppUser> updateProfile({required String name, String? bio, String? location, String? avatarUrl}) => _api.put(
    '$_v1/users/me',
    (data) => parseObject(data, AppUser.fromJson),
    body: {'name': name, 'bio': bio, 'location': location, 'avatarUrl': avatarUrl},
  );

  Future<AppUser> publicProfile(int id) => _api.get('$_v1/users/$id', (data) => parseObject(data, AppUser.fromJson));
}

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  Future<List<Collectible>> collectibles({String? category, CancelToken? cancelToken}) => _api.get(
    '$_v1/collectibles',
    (data) => parseList(data, Collectible.fromJson),
    query: category == null ? null : {'category': category},
    cancelToken: cancelToken,
  );

  Future<Collectible> collectible(int id) =>
      _api.get('$_v1/collectibles/$id', (data) => parseObject(data, Collectible.fromJson));

  Future<Collectible> create({
    required String name,
    required String description,
    required double value,
    required int communityId,
    String? category,
    int? eraYear,
  }) => _api.post(
    '$_v1/collectibles',
    (data) => parseObject(data, Collectible.fromJson),
    body: {
      'name': name,
      'description': description,
      'value': value,
      'communityId': communityId,
      'category': ?category,
      'eraYear': ?eraYear,
    },
  );

  Future<Collectible> update(
    int id, {
    required String name,
    required String description,
    required double value,
    String? category,
    int? eraYear,
    String? primaryImageUrl,
  }) => _api.put(
    '$_v1/collectibles/$id',
    (data) => parseObject(data, Collectible.fromJson),
    body: {
      'name': name,
      'description': description,
      'value': value,
      'category': category,
      'eraYear': eraYear,
      'primaryImageUrl': primaryImageUrl,
    },
  );

  Future<void> delete(int id) => _api.delete('$_v1/collectibles/$id');

  Future<List<MediaAsset>> media(int collectibleId) => _api.get(
    '$_v1/media',
    (data) => parseList(data, MediaAsset.fromJson),
    query: {'ElementId': collectibleId, 'ElementType': 'collectible'},
  );

  Future<MediaAsset> uploadPhoto(int collectibleId, Uint8List jpegBytes, {void Function(int, int)? onProgress}) =>
      _api.post(
        '$_v1/media/upload',
        (data) => parseObject(data, MediaAsset.fromJson),
        body: {
          'mediaName': 'photo-${DateTime.now().millisecondsSinceEpoch}.jpg',
          'content': base64Encode(jpegBytes),
          'contentType': 'image/jpeg',
          'attachedToId': collectibleId,
          'attachedToType': 'collectible',
        },
        onSendProgress: onProgress,
      );

  Future<List<Comment>> comments(int collectibleId) =>
      _api.get('$_v1/collectibles/$collectibleId/comments', (data) => parseList(data, Comment.fromJson));

  Future<Comment> addComment(int collectibleId, String body) => _api.post(
    '$_v1/collectibles/$collectibleId/comments',
    (data) => parseObject(data, Comment.fromJson),
    body: {'body': body},
  );

  Future<List<Review>> reviews(int collectibleId) =>
      _api.get('$_v1/collectibles/$collectibleId/reviews', (data) => parseList(data, Review.fromJson));

  Future<Review> addReview(int collectibleId, String content, int rating) => _api.post(
    '$_v1/collectibles/$collectibleId/reviews',
    (data) => parseObject(data, Review.fromJson),
    body: {'collectibleId': collectibleId, 'content': content, 'rating': rating},
  );
}

class AuctionRepository {
  AuctionRepository(this._api);
  final ApiClient _api;

  Future<List<Auction>> auctions() => _api.get('$_v1/auctions', (data) => parseList(data, Auction.fromJson));

  Future<Auction> auction(int id) => _api.get('$_v1/auctions/$id', (data) => parseObject(data, Auction.fromJson));

  /// The backend files the auction under the collectible's own community.
  Future<Auction> create({required int collectibleId, required double startingPrice, required DateTime deadline}) =>
      _api.post(
        '$_v1/auctions',
        (data) => parseObject(data, Auction.fromJson),
        body: {
          'collectibleId': collectibleId,
          'startingPrice': startingPrice,
          'deadline': deadline.toUtc().toIso8601String(),
        },
      );

  Future<Bid> placeBid(int auctionId, double amount) => _api.post(
    '$_v1/auctions/bids',
    (data) => parseObject(data, Bid.fromJson),
    body: {'auctionId': auctionId, 'amount': amount},
  );

  Future<void> cancel(int auctionId) => _api.delete('$_v1/auctions/$auctionId');
}

class CommunityRepository {
  CommunityRepository(this._api);
  final ApiClient _api;

  Future<List<Community>> communities() => _api.get('$_v1/communities', (data) => parseList(data, Community.fromJson));

  Future<List<Community>> search(String term) =>
      _api.get('$_v1/communities/search', (data) => parseList(data, Community.fromJson), query: {'SearchTerm': term});

  Future<List<Community>> joinedBy(int userId) =>
      _api.get('$_v1/communities/user/$userId', (data) => parseList(data, Community.fromJson));

  Future<Community> community(int id) =>
      _api.get('$_v1/communities/$id', (data) => parseObject(data, Community.fromJson));

  Future<Community> create(String name, String description) => _api.post(
    '$_v1/communities',
    (data) => parseObject(data, Community.fromJson),
    body: {'name': name, 'description': description},
  );

  Future<void> join(int id) => _api.post('$_v1/communities/$id/join', (_) {});

  Future<void> leave(int id) => _api.delete('$_v1/communities/$id/join');

  Future<List<FeedItem>> feed(int id, {String? query}) => _api.get(
    '$_v1/communities/$id/feed',
    (data) => parseList(data, FeedItem.fromJson),
    query: query == null || query.trim().isEmpty ? null : {'query': query.trim()},
  );

  Future<Post> createPost({required int communityId, required String title, required String content}) => _api.post(
    '$_v1/posts',
    (data) => parseObject(data, Post.fromJson),
    body: {'communityId': communityId, 'title': title, 'content': content},
  );

  Future<Post> post(int id) => _api.get('$_v1/posts/$id', (data) => parseObject(data, Post.fromJson));

  Future<void> deletePost(int id) => _api.delete('$_v1/posts/$id');

  Future<List<Comment>> postComments(int postId) =>
      _api.get('$_v1/posts/$postId/comments', (data) => parseList(data, Comment.fromJson));

  Future<Comment> addPostComment(int postId, String body) =>
      _api.post('$_v1/posts/$postId/comments', (data) => parseObject(data, Comment.fromJson), body: {'body': body});
}

class RecognitionRepository {
  RecognitionRepository(this._api);
  final ApiClient _api;

  Future<bool> isEnabled() =>
      _api.get('$_v1/recognition/status', (data) => data is Map<String, dynamic> && data.boolOr('enabled'));

  Future<RecognitionResult> analyze(
    Uint8List jpegBytes, {
    required String idempotencyKey,
    CancelToken? cancelToken,
    void Function(int, int)? onProgress,
  }) => _api.post(
    '$_v1/recognition/analyze',
    (data) => parseObject(data, RecognitionResult.fromJson),
    body: FormData.fromMap({
      'image': MultipartFile.fromBytes(jpegBytes, filename: 'scan.jpg', contentType: DioMediaType('image', 'jpeg')),
    }),
    options: Options(
      headers: {'Idempotency-Key': idempotencyKey},
      sendTimeout: AppConfig.recognitionTimeout,
      receiveTimeout: AppConfig.recognitionTimeout,
    ),
    cancelToken: cancelToken,
    onSendProgress: onProgress,
  );
}
