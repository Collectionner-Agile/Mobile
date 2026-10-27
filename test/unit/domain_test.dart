import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/core/network/api_exception.dart';
import 'package:collectionner/core/utils/formatters.dart';
import 'package:collectionner/core/utils/jwt.dart';
import 'package:collectionner/core/utils/validators.dart';
import 'package:collectionner/features/auctions/domain/auction_models.dart';
import 'package:collectionner/features/catalog/domain/catalog_models.dart';
import 'package:collectionner/features/recognition/domain/recognition_models.dart';
import 'package:collectionner/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

void main() {
  group('Catalogue model and query', () {
    final items = Fixtures.catalogue().map(Collectible.fromJson).toList();

    test('parses backend JSON including BigDecimal values and media', () {
      final item = items.first;
      expect(item.value, 1420);
      expect(item.coverUrl, '/assets/collectibles/games/retro-console.webp');
      expect(item.galleryUrls, hasLength(1));
      expect(items[3].auctionId, 7);
    });

    test('search is accent- and case-insensitive and matches every word', () {
      expect(applyCatalogQuery(items, search: 'relojeria omega').map((i) => i.id), [3]);
      expect(applyCatalogQuery(items, search: 'ZELDA 1998').map((i) => i.id), [1]);
      expect(applyCatalogQuery(items, search: 'zelda omega'), isEmpty);
    });

    test('category filter and sort orders', () {
      expect(applyCatalogQuery(items, category: 'TCG & Cartas').single.id, 2);
      expect(applyCatalogQuery(items, sort: CatalogSort.priceLow).first.value, 640);
      expect(applyCatalogQuery(items, sort: CatalogSort.priceHigh).first.value, 2310);
    });

    test('missing optional fields do not throw', () {
      final item = Collectible.fromJson({'id': 9});
      expect(item.name, '');
      expect(item.galleryUrls, [
        '/assets/editorial/archival-instrument.webp',
      ], reason: 'curated artwork stands in for missing photos');
    });
  });

  group('Auction rules', () {
    test('minimum next bid is strictly above current price', () {
      final auction = Auction.fromJson(Fixtures.auction());
      expect(auction.currentPrice, 780);
      expect(auction.minimumNextBid(), greaterThan(780));
      expect(auction.bids.first.amount, 780, reason: 'history sorted by highest first');
    });

    test('closed or past-deadline auctions are not live', () {
      expect(Auction.fromJson(Fixtures.auction(open: false)).isLive(DateTime.now()), isFalse);
      expect(Auction.fromJson(Fixtures.auction()).isLive(DateTime.now()), isTrue);
    });
  });

  group('Recognition contract', () {
    test('parses a full result', () {
      final result = RecognitionResult.fromJson(Fixtures.recognition(withAlternatives: true));
      expect(result.purchaseStatus, PurchaseStatus.available);
      expect(result.suggestedAction, SuggestedAction.placeBid);
      expect(result.allMatches, hasLength(2));
      expect(result.attributes['packaging'], 'sealed box');
    });

    test('unknown or missing status is never treated as purchasable', () {
      final json = Fixtures.recognition()..['purchase_status'] = 'buy_now';
      expect(RecognitionResult.fromJson(json).purchaseStatus, PurchaseStatus.requiresVerification);
      final missing = Fixtures.recognition()..remove('purchase_status');
      expect(RecognitionResult.fromJson(missing).purchaseStatus, PurchaseStatus.requiresVerification);
    });

    test('out-of-range confidence is dropped', () {
      final json = Fixtures.recognition()..['confidence'] = 3.2;
      expect(RecognitionResult.fromJson(json).confidence, isNull);
    });
  });

  group('API error mapping', () {
    test('ProblemDetail fields are preserved', () {
      final error = ApiClient.fromResponse(400, {
        'detail': 'Los datos enviados no superaron las validaciones requeridas.',
        'errorCode': 'VALIDATION_FAILED',
        'validationErrors': [
          {'field': 'name', 'message': 'El nombre es obligatorio.'},
        ],
      }, null);
      expect(error.kind, ApiErrorKind.validation);
      expect(error.fieldErrors['name'], 'El nombre es obligatorio.');
      expect(error.hasUserFacingDetail, isTrue);
    });

    test('status codes map to kinds, 429 carries Retry-After', () {
      expect(ApiClient.fromResponse(401, null, null).kind, ApiErrorKind.unauthorized);
      expect(ApiClient.fromResponse(403, null, null).kind, ApiErrorKind.forbidden);
      expect(ApiClient.fromResponse(404, null, null).kind, ApiErrorKind.notFound);
      expect(ApiClient.fromResponse(413, null, null).kind, ApiErrorKind.tooLarge);
      expect(ApiClient.fromResponse(500, null, null).kind, ApiErrorKind.server);
      final limited = ApiClient.fromResponse(429, {'errorCode': 'RATE_LIMIT_EXCEEDED'}, '120');
      expect(limited.kind, ApiErrorKind.rateLimited);
      expect(limited.retryAfter, const Duration(minutes: 2));
    });

    test('messages are localized; 5xx details are never shown', () {
      final l10n = AppLocalizationsEs();
      expect(describeError(const ApiException(ApiErrorKind.network), l10n), l10n.errorNetwork);
      expect(
        describeError(const ApiException(ApiErrorKind.server, detail: 'NullPointerException at ...'), l10n),
        l10n.errorServer,
      );
      expect(
        describeError(const ApiException(ApiErrorKind.unavailable, errorCode: 'AI_NOT_CONFIGURED'), l10n),
        l10n.scanUnavailable,
      );
      expect(describeError(StateError('x'), l10n), l10n.errorUnknown);
    });
  });

  group('Validators and formatters', () {
    final validators = Validators(AppLocalizationsEs());

    test('amount parsing accepts local formats', () {
      expect(Validators.parseAmount('1200'), 1200);
      expect(Validators.parseAmount('1200,50'), 1200.5);
      expect(Validators.parseAmount('1.200,50'), 1200.5);
      expect(Validators.parseAmount('1,200.50'), 1200.5);
      expect(Validators.parseAmount('abc'), isNull);
    });

    test('mirror backend validation rules', () {
      expect(validators.email('a@b.co'), isNull);
      expect(validators.email('nope'), isNotNull);
      expect(validators.username('ab'), isNotNull);
      expect(validators.username('collector_prime'), isNull);
      expect(validators.password('12345'), isNotNull);
      expect(validators.optionalYear(''), isNull);
      expect(validators.optionalYear('1700'), isNotNull);
      expect(validators.positiveAmount('0'), isNotNull);
      expect(validators.nonNegativeAmount('0'), isNull);
    });

    test('money uses soles and remaining time is compact', () {
      expect(formatMoney(850, 'es'), 'S/ 850');
      expect(formatMoney(1200, 'en'), 'S/ 1,200');
      expect(formatMoney(1200.5, 'en'), 'S/ 1,200.50');
      expect(formatMoney(3200, 'es'), startsWith('S/ 3'));
      expect(formatRemaining(const Duration(days: 2, hours: 3)), '2 d 3 h');
      expect(formatRemaining(const Duration(minutes: 5, seconds: 2)), '5 min 2 s');
      expect(formatRemaining(const Duration(seconds: -5)), '0 s');
    });

    test('JWT expiry is read from the payload', () {
      expect(isJwtExpired(fakeJwt()), isFalse);
      expect(isJwtExpired(fakeJwt(expires: DateTime.now().subtract(const Duration(minutes: 1)))), isTrue);
      expect(isJwtExpired('garbage'), isTrue);
    });
  });
}
