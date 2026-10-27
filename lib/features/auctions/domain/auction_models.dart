import '../../../core/utils/json.dart';

class Bid {
  const Bid({required this.id, required this.amount, this.bidderId, this.bidderName, this.createdAt});

  final int id;
  final double amount;
  final int? bidderId;
  final String? bidderName;
  final DateTime? createdAt;

  factory Bid.fromJson(JsonMap json) => Bid(
    id: json.requireInt('id'),
    amount: json.doubleOrNull('amount') ?? 0,
    bidderId: json.intOrNull('bidderId'),
    bidderName: json.stringOrNull('bidderName'),
    createdAt: json.dateOrNull('createdAt'),
  );
}

class Auction {
  const Auction({
    required this.id,
    required this.communityId,
    required this.auctioneerId,
    required this.collectibleId,
    required this.startingPrice,
    required this.isOpen,
    this.auctioneerName,
    this.collectibleName,
    this.collectibleImage,
    this.currentHighestBid,
    this.bidCount = 0,
    this.deadline,
    this.bids = const [],
  });

  final int id;
  final int communityId;
  final int auctioneerId;
  final String? auctioneerName;
  final int collectibleId;
  final String? collectibleName;
  final String? collectibleImage;
  final double startingPrice;
  final double? currentHighestBid;
  final int bidCount;
  final DateTime? deadline;
  final bool isOpen;
  final List<Bid> bids;

  /// Highest amount on record, or the starting price before any bid.
  double get currentPrice => currentHighestBid ?? startingPrice;

  bool isLive(DateTime now) => isOpen && deadline != null && deadline!.isAfter(now);

  /// The backend requires a bid strictly above [currentPrice]; the UI proposes
  /// the smallest round step above it.
  double minimumNextBid() {
    final step = currentPrice < 100
        ? 1
        : currentPrice < 1000
        ? 10
        : 50;
    return ((currentPrice / step).floor() + 1) * step.toDouble();
  }

  factory Auction.fromJson(JsonMap json) => Auction(
    id: json.requireInt('id'),
    communityId: json.intOrNull('communityId') ?? 0,
    auctioneerId: json.intOrNull('auctioneerId') ?? 0,
    auctioneerName: json.stringOrNull('auctioneerName'),
    collectibleId: json.intOrNull('collectibleId') ?? 0,
    collectibleName: json.stringOrNull('collectibleName'),
    collectibleImage: json.stringOrNull('collectibleImage'),
    startingPrice: json.doubleOrNull('startingPrice') ?? 0,
    currentHighestBid: json.doubleOrNull('currentHighestBid'),
    bidCount: json.intOrNull('bidCount') ?? 0,
    deadline: json.dateOrNull('deadline'),
    isOpen: json.boolOr('isOpen', fallback: json.boolOr('open')),
    bids: json.objects('bids').map(Bid.fromJson).toList(growable: false)..sort((a, b) => b.amount.compareTo(a.amount)),
  );
}
