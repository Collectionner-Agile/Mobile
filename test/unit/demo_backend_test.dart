import 'dart:io';

import 'package:collectionner/core/demo/demo_backend.dart';
import 'package:collectionner/core/network/api_client.dart';
import 'package:collectionner/core/network/api_exception.dart';
import 'package:collectionner/core/network/repositories.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ApiClient api;

  setUp(() {
    final seed = File('assets/demo/seed.json').readAsStringSync();
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.invalid'))
      ..httpClientAdapter = DemoBackend(loadSeed: () async => seed);
    api = ApiClient(dio: dio, readToken: () => null, readLanguage: () => 'es', onUnauthorized: () {});
  });

  test('serves the bundled catalogue, auctions and communities', () async {
    expect(await CatalogRepository(api).collectibles(), isNotEmpty);
    expect(await AuctionRepository(api).auctions(), isNotEmpty);
    expect(await CommunityRepository(api).communities(), isNotEmpty);
  });

  test('a bid above the current price updates the auction in memory', () async {
    final auctions = AuctionRepository(api);
    final before = (await auctions.auctions()).first;
    await auctions.placeBid(before.id, before.currentPrice + 10);
    final after = await auctions.auction(before.id);
    expect(after.currentPrice, before.currentPrice + 10);
    expect(after.bidCount, before.bidCount + 1);
    await expectLater(auctions.placeBid(before.id, before.currentPrice), throwsA(isA<ApiException>()));
  });

  test('joining and leaving a community toggles membership', () async {
    final communities = CommunityRepository(api);
    final target = (await communities.communities()).firstWhere((c) => !c.isJoined);
    await communities.join(target.id);
    expect((await communities.community(target.id)).isJoined, isTrue);
    await communities.leave(target.id);
    expect((await communities.community(target.id)).isJoined, isFalse);
  });

  test('recognition reports unavailable instead of pretending to analyse', () async {
    expect(await RecognitionRepository(api).isEnabled(), isFalse);
  });
}
