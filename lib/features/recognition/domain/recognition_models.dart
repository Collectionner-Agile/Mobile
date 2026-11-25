import '../../../core/utils/json.dart';

enum PurchaseStatus {
  available,
  unavailable,
  notInCatalog,
  requiresVerification,
  unsupportedProduct;

  static PurchaseStatus parse(String? raw) => switch (raw) {
    'available' => available,
    'unavailable' => unavailable,
    'not_in_catalog' => notInCatalog,
    'unsupported_product' => unsupportedProduct,
    // Unknown or missing values are never treated as purchasable.
    _ => requiresVerification,
  };
}

enum SuggestedAction {
  placeBid,
  viewRecord,
  reviewMatches,
  retakePhoto,
  registerItem;

  static SuggestedAction parse(String? raw) => switch (raw) {
    'place_bid' => placeBid,
    'view_record' => viewRecord,
    'review_matches' => reviewMatches,
    'register_item' => registerItem,
    _ => retakePhoto,
  };
}

class CatalogMatch {
  const CatalogMatch({
    required this.collectibleId,
    required this.name,
    required this.score,
    this.category,
    this.imageUrl,
    this.auctionId,
    this.auctionOpen = false,
  });

  final int collectibleId;
  final String name;
  final String? category;
  final String? imageUrl;
  final double score;
  final int? auctionId;
  final bool auctionOpen;

  factory CatalogMatch.fromJson(JsonMap json) => CatalogMatch(
    collectibleId: json.requireInt('collectible_id'),
    name: json.stringOrNull('name') ?? '',
    category: json.stringOrNull('category'),
    imageUrl: json.stringOrNull('image_url'),
    score: (json.doubleOrNull('score') ?? 0).clamp(0, 1).toDouble(),
    auctionId: json.intOrNull('auction_id'),
    auctionOpen: json.boolOr('auction_open'),
  );
}

/// Typed mirror of the backend recognition contract. Visual fields are
/// evidence from the model; [purchaseStatus] comes from catalogue rules.
class RecognitionResult {
  const RecognitionResult({
    required this.analysisId,
    required this.detected,
    required this.purchaseStatus,
    required this.suggestedAction,
    this.productName,
    this.category,
    this.catalogCategory,
    this.brand,
    this.model,
    this.attributes = const {},
    this.visibleText = const [],
    this.confidence,
    this.ambiguities = const [],
    this.catalogMatch,
    this.alternatives = const [],
    this.reasonCode,
    this.reason,
    this.modelVersion,
    this.analyzedAt,
  });

  final String analysisId;
  final bool detected;
  final String? productName;
  final String? category;
  final String? catalogCategory;
  final String? brand;
  final String? model;
  final Map<String, String> attributes;
  final List<String> visibleText;
  final double? confidence;
  final List<String> ambiguities;
  final CatalogMatch? catalogMatch;
  final List<CatalogMatch> alternatives;
  final PurchaseStatus purchaseStatus;
  final String? reasonCode;
  final String? reason;
  final SuggestedAction suggestedAction;
  final String? modelVersion;
  final DateTime? analyzedAt;

  List<CatalogMatch> get allMatches => [?catalogMatch, ...alternatives];

  factory RecognitionResult.fromJson(JsonMap json) {
    final rawAttributes = json.objectOrNull('attributes') ?? const <String, dynamic>{};
    final confidence = json.doubleOrNull('confidence');
    return RecognitionResult(
      analysisId: json.stringOrNull('analysis_id') ?? '',
      detected: json.boolOr('detected'),
      productName: json.stringOrNull('product_name'),
      category: json.stringOrNull('category'),
      catalogCategory: json.stringOrNull('catalog_category'),
      brand: json.stringOrNull('brand'),
      model: json.stringOrNull('model'),
      attributes: {
        for (final entry in rawAttributes.entries)
          if (entry.value is String) entry.key: entry.value as String,
      },
      visibleText: json.strings('visible_text'),
      confidence: confidence == null || confidence < 0 || confidence > 1 ? null : confidence,
      ambiguities: json.strings('ambiguities'),
      catalogMatch: json.objectOrNull('catalog_match') == null
          ? null
          : CatalogMatch.fromJson(json.objectOrNull('catalog_match')!),
      alternatives: json.objects('alternatives').map(CatalogMatch.fromJson).toList(growable: false),
      purchaseStatus: PurchaseStatus.parse(json.stringOrNull('purchase_status')),
      reasonCode: json.stringOrNull('reason_code'),
      reason: json.stringOrNull('reason'),
      suggestedAction: SuggestedAction.parse(json.stringOrNull('suggested_action')),
      modelVersion: json.stringOrNull('model_version'),
      analyzedAt: json.dateOrNull('analyzed_at'),
    );
  }
}

/// What the user told us about an analysis. Sent to the backend so confirmed
/// and corrected scans become labelled training data.
enum FeedbackVerdict {
  /// The identification (and its catalogue match, if any) is right.
  correct('correct'),

  /// The user picked one of the proposed matches.
  choseMatch('chose_match'),

  /// The identification is wrong; the correction fields may say what it is.
  incorrect('incorrect');

  const FeedbackVerdict(this.wire);
  final String wire;
}

class RecognitionFeedback {
  const RecognitionFeedback({
    required this.verdict,
    this.collectibleId,
    this.correctedName,
    this.correctedCategory,
    this.correctedCategorySlug,
    this.implicit = false,
  });

  final FeedbackVerdict verdict;

  /// Catalogue piece the user confirmed or chose.
  final int? collectibleId;
  final String? correctedName;
  final String? correctedCategory;

  /// Taxonomy slug the user picked; the server prefers it over the free text.
  final String? correctedCategorySlug;

  /// True when inferred from what the user did (e.g. continuing with a match)
  /// rather than answered explicitly; the backend can weight it lower.
  final bool implicit;

  Map<String, Object?> toJson() {
    String? clean(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
    return {
      'verdict': verdict.wire,
      'collectible_id': ?collectibleId,
      'corrected_name': ?clean(correctedName),
      'corrected_category': ?clean(correctedCategory),
      'corrected_category_slug': ?clean(correctedCategorySlug),
      'implicit': implicit,
    };
  }
}

/// One of the user's own analyses as the server remembers it
/// (`GET /api/v1/recognition/history`). Photos are never returned.
class RecognitionHistoryItem {
  const RecognitionHistoryItem({
    required this.analysisId,
    required this.detected,
    required this.purchaseStatus,
    this.productName,
    this.category,
    this.catalogCategory,
    this.matchedCollectibleId,
    this.publishedCollectibleId,
    this.analyzedAt,
    this.trainingConsent = false,
    this.photoKept = false,
    this.verdict,
  });

  final String analysisId;
  final bool detected;
  final PurchaseStatus purchaseStatus;
  final String? productName;
  final String? category;
  final String? catalogCategory;
  final int? matchedCollectibleId;
  final int? publishedCollectibleId;
  final DateTime? analyzedAt;
  final bool trainingConsent;

  /// Whether the server still keeps the photo for training.
  final bool photoKept;

  /// The user's answer to "¿Acertamos?", if any.
  final FeedbackVerdict? verdict;

  factory RecognitionHistoryItem.fromJson(JsonMap json) {
    final verdict = json.objectOrNull('feedback')?.stringOrNull('verdict');
    return RecognitionHistoryItem(
      analysisId: json.requireString('analysis_id'),
      detected: json.boolOr('detected'),
      purchaseStatus: PurchaseStatus.parse(json.stringOrNull('purchase_status')),
      productName: json.stringOrNull('product_name'),
      category: json.stringOrNull('category'),
      catalogCategory: json.stringOrNull('catalog_category'),
      matchedCollectibleId: json.intOrNull('matched_collectible_id'),
      publishedCollectibleId: json.intOrNull('published_collectible_id'),
      analyzedAt: json.dateOrNull('analyzed_at'),
      trainingConsent: json.boolOr('training_consent'),
      photoKept: json.boolOr('photo_kept'),
      verdict: FeedbackVerdict.values.where((v) => v.wire == verdict).firstOrNull,
    );
  }
}

class RecognitionHistoryPage {
  const RecognitionHistoryPage({required this.items, required this.hasMore});

  final List<RecognitionHistoryItem> items;
  final bool hasMore;

  factory RecognitionHistoryPage.fromJson(JsonMap json) => RecognitionHistoryPage(
    items: json.objects('items').map(RecognitionHistoryItem.fromJson).toList(growable: false),
    hasMore: json.boolOr('has_more'),
  );
}

/// What withdrawing training consent removed on the server.
class TrainingDataDeletion {
  const TrainingDataDeletion({required this.photos, required this.feedback});

  final int photos;
  final int feedback;

  factory TrainingDataDeletion.fromJson(JsonMap json) =>
      TrainingDataDeletion(photos: json.intOrNull('deleted_photos') ?? 0, feedback: json.intOrNull('deleted_feedback') ?? 0);
}
