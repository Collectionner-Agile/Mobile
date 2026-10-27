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
