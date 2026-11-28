import '../../../core/utils/json.dart';

/// Where a fixed-price sale stands (HU05). Only [active] and [reserved] keep the piece blocked.
enum SaleStatus {
  /// Listed by the owner; anyone else can buy it.
  active,

  /// A buyer took it; waiting for the seller's delivery and the buyer's receipt.
  reserved,

  /// Both sides confirmed; the piece belongs to the buyer.
  completed,

  /// Withdrawn while active, or called off before any confirmation.
  cancelled;

  static SaleStatus parse(String? value) => switch (value) {
    'reserved' => reserved,
    'completed' => completed,
    'cancelled' => cancelled,
    _ => active,
  };

  bool get isOpen => this == active || this == reserved;
}

/// What the person looking at a sale is to it.
enum SaleRole { seller, buyer, visitor }

class Sale {
  const Sale({
    required this.id,
    required this.collectibleId,
    required this.price,
    required this.status,
    this.collectibleName,
    this.collectibleImage,
    this.sellerId,
    this.sellerName,
    this.buyerId,
    this.buyerName,
    this.sellerConfirmed = false,
    this.buyerConfirmed = false,
    this.createdAt,
    this.reservedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final int id;
  final int collectibleId;
  final String? collectibleName;
  final String? collectibleImage;
  final int? sellerId;
  final String? sellerName;
  final int? buyerId;
  final String? buyerName;
  final double price;
  final SaleStatus status;
  final bool sellerConfirmed;
  final bool buyerConfirmed;
  final DateTime? createdAt;
  final DateTime? reservedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  SaleRole roleOf(int? userId) {
    if (userId == null) return SaleRole.visitor;
    if (userId == sellerId) return SaleRole.seller;
    if (userId == buyerId) return SaleRole.buyer;
    return SaleRole.visitor;
  }

  /// The seller withdraws an active sale; either side calls off a reservation until someone confirms.
  bool canCancel(SaleRole role) => switch (status) {
    SaleStatus.active => role == SaleRole.seller,
    SaleStatus.reserved => role != SaleRole.visitor && !sellerConfirmed && !buyerConfirmed,
    _ => false,
  };

  factory Sale.fromJson(JsonMap json) => Sale(
    id: json.requireInt('id'),
    collectibleId: json.requireInt('collectibleId'),
    collectibleName: json.stringOrNull('collectibleName'),
    collectibleImage: json.stringOrNull('collectibleImage'),
    sellerId: json.intOrNull('sellerId'),
    sellerName: json.stringOrNull('sellerName'),
    buyerId: json.intOrNull('buyerId'),
    buyerName: json.stringOrNull('buyerName'),
    price: json.doubleOrNull('price') ?? 0,
    status: SaleStatus.parse(json.stringOrNull('status')),
    sellerConfirmed: json.boolOr('sellerConfirmed'),
    buyerConfirmed: json.boolOr('buyerConfirmed'),
    createdAt: json.dateOrNull('createdAt'),
    reservedAt: json.dateOrNull('reservedAt'),
    completedAt: json.dateOrNull('completedAt'),
    cancelledAt: json.dateOrNull('cancelledAt'),
  );
}
