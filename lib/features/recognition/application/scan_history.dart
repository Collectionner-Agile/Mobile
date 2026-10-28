import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../app/preferences.dart';
import '../domain/recognition_models.dart';

/// One past identification, kept on the device with a small thumbnail.
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.at,
    required this.detected,
    required this.status,
    this.name,
    this.category,
    this.thumbnail,
    this.collectibleId,
    this.auctionId,
    this.auctionOpen = false,
  });

  final String id;
  final DateTime at;
  final bool detected;
  final PurchaseStatus status;
  final String? name;
  final String? category;

  /// `data:image/jpeg;base64,…` of a small copy of the photo.
  final String? thumbnail;
  final int? collectibleId;
  final int? auctionId;
  final bool auctionOpen;

  factory ScanRecord.fromResult(RecognitionResult result, {String? thumbnail}) {
    final match = result.catalogMatch;
    return ScanRecord(
      id: result.analysisId.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : result.analysisId,
      at: result.analyzedAt ?? DateTime.now(),
      detected: result.detected,
      status: result.purchaseStatus,
      name: result.productName ?? match?.name,
      category: result.category ?? match?.category,
      thumbnail: thumbnail,
      collectibleId: match?.collectibleId,
      auctionId: match?.auctionId,
      auctionOpen: match?.auctionOpen ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'detected': detected,
    'status': status.name,
    'name': name,
    'category': category,
    'thumbnail': thumbnail,
    'collectibleId': collectibleId,
    'auctionId': auctionId,
    'auctionOpen': auctionOpen,
  };

  static ScanRecord? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse(raw['at'] as String? ?? '');
    final id = raw['id'];
    if (at == null || id is! String) return null;
    return ScanRecord(
      id: id,
      at: at,
      detected: raw['detected'] == true,
      status: PurchaseStatus.values.firstWhere(
        (status) => status.name == raw['status'],
        orElse: () => PurchaseStatus.requiresVerification,
      ),
      name: raw['name'] as String?,
      category: raw['category'] as String?,
      thumbnail: raw['thumbnail'] as String?,
      collectibleId: raw['collectibleId'] as int?,
      auctionId: raw['auctionId'] as int?,
      auctionOpen: raw['auctionOpen'] == true,
    );
  }
}

/// Past identifications, newest first, at most [limit] of them.
final scanHistoryProvider = NotifierProvider<ScanHistory, List<ScanRecord>>(ScanHistory.new);

class ScanHistory extends Notifier<List<ScanRecord>> {
  static const _key = 'pref.scanHistory';
  static const limit = 30;

  @override
  List<ScanRecord> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.map(ScanRecord.fromJson).whereType<ScanRecord>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  /// Adds a finished analysis with a thumbnail of [photoPath].
  Future<void> record(RecognitionResult result, {String? photoPath, int quarterTurns = 0}) async {
    String? thumbnail;
    if (photoPath != null) {
      try {
        thumbnail = await makeThumbnail(photoPath, quarterTurns: quarterTurns);
      } on Object {
        thumbnail = null;
      }
    }
    final entry = ScanRecord.fromResult(result, thumbnail: thumbnail);
    await _save([entry, ...state.where((record) => record.id != entry.id)].take(limit).toList());
  }

  Future<void> remove(String id) => _save(state.where((record) => record.id != id).toList());

  Future<void> clear() => _save(const []);

  Future<void> _save(List<ScanRecord> records) async {
    state = records;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode([for (final r in records) r.toJson()]));
  }
}

/// Small JPEG of the photo as a data URI, made on a background isolate.
Future<String> makeThumbnail(String path, {int quarterTurns = 0, int size = 160}) => Isolate.run(() {
  var image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) throw const FormatException('unreadable image');
  image = img.bakeOrientation(image);
  final turns = quarterTurns % 4;
  if (turns != 0) image = img.copyRotate(image, angle: 90 * turns);
  final square = img.copyResizeCropSquare(image, size: size);
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(square, quality: 72))}';
});
