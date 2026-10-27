import '../../../core/utils/json.dart';

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.memberCount = 0,
    this.postCount = 0,
    this.isJoined = false,
  });

  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final int memberCount;
  final int postCount;
  final bool isJoined;

  Community copyWith({bool? isJoined, int? memberCount}) => Community(
    id: id,
    name: name,
    description: description,
    imageUrl: imageUrl,
    memberCount: memberCount ?? this.memberCount,
    postCount: postCount,
    isJoined: isJoined ?? this.isJoined,
  );

  factory Community.fromJson(JsonMap json) => Community(
    id: json.requireInt('id'),
    name: json.stringOrNull('name') ?? '',
    description: json.stringOrNull('description') ?? '',
    imageUrl: json.stringOrNull('imageUrl'),
    memberCount: json.intOrNull('memberCount') ?? 0,
    postCount: json.intOrNull('postCount') ?? 0,
    isJoined: json.boolOr('isJoined', fallback: json.boolOr('joined')),
  );
}

enum FeedItemType { collectible, post, auction, other }

class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.username,
    this.userId,
    this.communityId,
    this.imageUrl,
    this.value,
    this.rating,
    this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final FeedItemType type;
  final String? username;
  final int? userId;
  final int? communityId;
  final String? imageUrl;
  final double? value;
  final double? rating;
  final DateTime? createdAt;

  factory FeedItem.fromJson(JsonMap json) => FeedItem(
    id: json.requireInt('id'),
    title: json.stringOrNull('title') ?? '',
    description: json.stringOrNull('description') ?? '',
    type: switch (json.stringOrNull('itemType')) {
      'collectible' => FeedItemType.collectible,
      'post' => FeedItemType.post,
      'auction' => FeedItemType.auction,
      _ => FeedItemType.other,
    },
    username: json.stringOrNull('username'),
    userId: json.intOrNull('userId'),
    communityId: json.intOrNull('communityId'),
    imageUrl: json.stringOrNull('imageUrl'),
    value: json.doubleOrNull('value'),
    rating: json.doubleOrNull('rating'),
    createdAt: json.dateOrNull('createdAt'),
  );
}

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    this.communityId,
    this.createdAt,
    this.commentsCount = 0,
  });

  final int id;
  final String title;
  final String content;
  final int authorId;
  final String? authorName;
  final String? authorAvatar;
  final int? communityId;
  final DateTime? createdAt;
  final int commentsCount;

  factory Post.fromJson(JsonMap json) => Post(
    id: json.requireInt('id'),
    title: json.stringOrNull('title') ?? '',
    content: json.stringOrNull('content') ?? '',
    authorId: json.intOrNull('authorId') ?? 0,
    authorName: json.stringOrNull('authorName'),
    authorAvatar: json.stringOrNull('authorAvatar'),
    communityId: json.intOrNull('communityId'),
    createdAt: json.dateOrNull('createdAt'),
    commentsCount: json.intOrNull('commentsCount') ?? 0,
  );
}
