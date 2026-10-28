import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/network/api_exception.dart';
import '../domain/recognition_models.dart';
import 'scan_history.dart';

enum ScanStage { idle, preview, preparing, uploading, analyzing, done, failed }

class ScanState {
  const ScanState({
    this.stage = ScanStage.idle,
    this.imagePath,
    this.quarterTurns = 0,
    this.uploadProgress = 0,
    this.result,
    this.error,
  });

  final ScanStage stage;
  final String? imagePath;
  final int quarterTurns;
  final double uploadProgress;
  final RecognitionResult? result;
  final Object? error;

  bool get isBusy => stage == ScanStage.preparing || stage == ScanStage.uploading || stage == ScanStage.analyzing;

  ScanState copyWith({
    ScanStage? stage,
    String? imagePath,
    int? quarterTurns,
    double? uploadProgress,
    RecognitionResult? result,
    Object? error,
    bool clearError = false,
  }) => ScanState(
    stage: stage ?? this.stage,
    imagePath: imagePath ?? this.imagePath,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    result: result ?? this.result,
    error: clearError ? null : (error ?? this.error),
  );
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(ScanController.new);

final recognitionEnabledProvider = FutureProvider<bool>((ref) => ref.watch(recognitionRepositoryProvider).isEnabled());

/// Drives the photo → preview → upload → result flow. Nothing leaves the device
/// until [analyze] is called after the user confirms.
class ScanController extends Notifier<ScanState> {
  CancelToken? _cancel;
  String? _idempotencyKey;

  @override
  ScanState build() {
    ref.onDispose(() => _cancel?.cancel());
    return const ScanState();
  }

  void usePhoto(String path) {
    _idempotencyKey = null;
    state = ScanState(stage: ScanStage.preview, imagePath: path);
  }

  void replacePhoto(String path) {
    _idempotencyKey = null;
    state = state.copyWith(imagePath: path, quarterTurns: 0, stage: ScanStage.preview, clearError: true);
  }

  void rotate() {
    _idempotencyKey = null;
    state = state.copyWith(quarterTurns: (state.quarterTurns + 1) % 4);
  }

  void reset() {
    _cancel?.cancel();
    _idempotencyKey = null;
    state = const ScanState();
  }

  void cancel() {
    _cancel?.cancel();
    state = state.copyWith(stage: ScanStage.preview, uploadProgress: 0, clearError: true);
  }

  Future<void> analyze() async {
    final path = state.imagePath;
    if (path == null || state.isBusy) return;
    // A retry of the same photo reuses the key, so the server can return the
    // earlier result instead of paying for a second analysis.
    _idempotencyKey ??= _newKey();
    _cancel = CancelToken();
    state = state.copyWith(stage: ScanStage.preparing, uploadProgress: 0, clearError: true);
    try {
      final bytes = await prepareJpeg(path, quarterTurns: state.quarterTurns);
      if (_cancel!.isCancelled) return;
      state = state.copyWith(stage: ScanStage.uploading);
      final result = await ref
          .read(recognitionRepositoryProvider)
          .analyze(
            bytes,
            idempotencyKey: _idempotencyKey!,
            cancelToken: _cancel,
            onProgress: (sent, total) {
              if (total <= 0) return;
              final progress = sent / total;
              state = state.copyWith(
                uploadProgress: progress,
                stage: progress >= 1 ? ScanStage.analyzing : ScanStage.uploading,
              );
            },
          );
      state = state.copyWith(stage: ScanStage.done, result: result);
      // Keep it in the on-device history; a failure there never affects the result.
      unawaited(
        ref
            .read(scanHistoryProvider.notifier)
            .record(result, photoPath: path, quarterTurns: state.quarterTurns)
            .catchError((Object _) {}),
      );
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.cancelled) return;
      state = state.copyWith(stage: ScanStage.failed, error: error);
    } on ImageProcessingException catch (error) {
      state = state.copyWith(stage: ScanStage.failed, error: error);
    }
  }

  static String _newKey() {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(32, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }
}
