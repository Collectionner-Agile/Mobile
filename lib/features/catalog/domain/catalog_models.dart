import '../../../core/media/artwork.dart';
import '../../../core/utils/json.dart';

class MediaAsset {
  const MediaAsset({required this.id, required this.url, this.name, this.uploaderId, this.createdAt});

  final int id;
  final String url;
  final String? name;
  final int? uploaderId;
  final DateTime? createdAt;

  factory MediaAsset.fromJson(JsonMap json) => MediaAsset(
    id: json.requireInt('id'),
    url: json.requireString('mediaURL'),
    name: json.stringOrNull('mediaName'),
    uploaderId: json.intOrNull('uploaderId'),
    createdAt: json.dateOrNull('createdAt'),
  );
}

class Collectible {
  const Collectible({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.value,
    required this.description,
    this.ownerName,
    this.category,
    this.eraYear,
    this.rating = 0,
    this.reviewCount = 0,
    this.isLinkedToProcess = false,
    this.auctionId,
    this.primaryImageUrl,
    this.media = const [],
    this.conditionEstimated,
    this.completeness = const [],
    this.createdAt,
  });

  final int id;
  final String name;
  final int ownerId;
  final String? ownerName;
  final double value;
  final String description;
  final String? category;
  final int? eraYear;
  final double rating;
  final int reviewCount;
  final bool isLinkedToProcess;
  final int? auctionId;
  final String? primaryImageUrl;
  final List<MediaAsset> media;
  final double? conditionEstimated;
  final List<String> completeness;
  final DateTime? createdAt;

  /// Cover image: the explicit primary image, else the first uploaded photo.
  String? get coverUrl => primaryImageUrl ?? (media.isNotEmpty ? media.first.url : null);

  List<String> get galleryUrls {
    final urls = <String>[?primaryImageUrl, for (final item in media) item.url];
    return galleryFor(name: name, category: category, urls: urls.toSet().toList(growable: false));
  }

  /// Image for cards: a real photo when there is one, else curated artwork.
  String get artwork => artworkFor(name: name, category: category, url: coverUrl);

  factory Collectible.fromJson(JsonMap json) => Collectible(
    id: json.requireInt('id'),
    name: json.stringOrNull('name') ?? '',
    ownerId: json.intOrNull('ownerId') ?? 0,
    ownerName: json.stringOrNull('ownerName'),
    value: json.doubleOrNull('value') ?? 0,
    description: json.stringOrNull('description') ?? '',
    category: json.stringOrNull('category'),
    eraYear: json.intOrNull('eraYear'),
    rating: json.doubleOrNull('rating') ?? 0,
    reviewCount: json.intOrNull('reviewCount') ?? 0,
    isLinkedToProcess: json.boolOr('isLinkedToProcess'),
    auctionId: json.intOrNull('auctionId'),
    primaryImageUrl: json.stringOrNull('primaryImageUrl'),
    media: json.objects('media').map(MediaAsset.fromJson).toList(growable: false),
    conditionEstimated: json.doubleOrNull('conditionEstimated'),
    completeness: json.strings('completeness'),
    createdAt: json.dateOrNull('createdAt'),
  );
}

class Comment {
  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    this.avatarUrl,
    this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorName;
  final String body;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory Comment.fromJson(JsonMap json) => Comment(
    id: json.requireInt('id'),
    authorId: json.intOrNull('authorId') ?? 0,
    authorName: json.stringOrNull('authorName') ?? '',
    body: json.stringOrNull('body') ?? '',
    avatarUrl: json.stringOrNull('profileURI'),
    createdAt: json.dateOrNull('createdAt'),
  );
}

class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.rating,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String userName;
  final String content;
  final int rating;
  final DateTime? createdAt;

  factory Review.fromJson(JsonMap json) => Review(
    id: json.requireInt('id'),
    userId: json.intOrNull('userId') ?? 0,
    userName: json.stringOrNull('userName') ?? '',
    content: json.stringOrNull('content') ?? '',
    rating: (json.intOrNull('rating') ?? 0).clamp(0, 5),
    createdAt: json.dateOrNull('createdAt'),
  );
}

enum CatalogSort { recent, priceLow, priceHigh, rating }

/// Pure, testable catalogue query applied on the client (the backend only
/// filters by category).
List<Collectible> applyCatalogQuery(
  List<Collectible> items, {
  String search = '',
  String? category,
  CatalogSort sort = CatalogSort.recent,
}) {
  final needle = _fold(search.trim());
  final filtered = items.where((item) {
    if (category != null && item.category != category) return false;
    if (needle.isEmpty) return true;
    final haystack = _fold('${item.name} ${item.category ?? ''} ${item.eraYear ?? ''} ${item.description}');
    return needle.split(RegExp(r'\s+')).every(haystack.contains);
  }).toList();
  int byDate(Collectible a, Collectible b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
  switch (sort) {
    case CatalogSort.recent:
      filtered.sort(byDate);
    case CatalogSort.priceLow:
      filtered.sort((a, b) => a.value.compareTo(b.value));
    case CatalogSort.priceHigh:
      filtered.sort((a, b) => b.value.compareTo(a.value));
    case CatalogSort.rating:
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
  }
  return filtered;
}

String _fold(String value) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}
