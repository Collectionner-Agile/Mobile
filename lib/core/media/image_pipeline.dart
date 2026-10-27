import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/config/app_config.dart';
import '../../app/theme/tokens.dart';

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.reason);
  final ImageProcessingFailure reason;
}

enum ImageProcessingFailure { unreadable, tooLarge }

/// Decodes, fixes EXIF orientation, applies a manual rotation, downsizes and
/// re-encodes as JPEG, all on a background isolate so the UI keeps 60 fps.
/// Re-encoding also strips EXIF metadata such as GPS location.
Future<Uint8List> prepareJpeg(
  String path, {
  int quarterTurns = 0,
  int maxDimension = 1600,
  int maxBytes = AppConfig.maxUploadBytes,
}) {
  return Isolate.run(() {
    final source = File(path).readAsBytesSync();
    var image = img.decodeImage(source);
    if (image == null) throw const ImageProcessingException(ImageProcessingFailure.unreadable);
    image = img.bakeOrientation(image);
    final turns = quarterTurns % 4;
    if (turns != 0) image = img.copyRotate(image, angle: 90 * turns);

    for (final (dimension, quality) in [(maxDimension, 85), (1280, 75), (1024, 68)]) {
      final longest = image.width > image.height ? image.width : image.height;
      final resized = longest > dimension
          ? img.copyResize(
              image,
              width: image.width >= image.height ? dimension : null,
              height: image.height > image.width ? dimension : null,
              interpolation: img.Interpolation.average,
            )
          : image;
      final bytes = img.encodeJpg(resized, quality: quality);
      if (bytes.length <= maxBytes) return bytes;
    }
    throw const ImageProcessingException(ImageProcessingFailure.tooLarge);
  });
}

class PickedImage {
  const PickedImage(this.path);
  final String path;
}

enum PickFailure { permissionDenied, cancelled }

class PickException implements Exception {
  const PickException(this.reason);
  final PickFailure reason;
}

class ImageSourcePicker {
  ImageSourcePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// Requests only the permission the chosen source needs, at the moment of use.
  Future<PickedImage?> pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        // Asking for a max size makes iOS hand back JPEG instead of HEIC.
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      return file == null ? null : PickedImage(file.path);
    } on Exception catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('denied') || text.contains('permission')) {
        throw const PickException(PickFailure.permissionDenied);
      }
      rethrow;
    }
  }

  Future<List<PickedImage>> pickMany({int limit = 5}) async {
    final files = await _picker.pickMultiImage(
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
      limit: limit,
      requestFullMetadata: false,
    );
    return files.map((file) => PickedImage(file.path)).toList(growable: false);
  }
}

Future<String?> cropImage(BuildContext context, String path, {required String title}) async {
  final brand = context.brand;
  final cropped = await ImageCropper().cropImage(
    sourcePath: path,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 95,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: BrandColors.light.ink,
        toolbarWidgetColor: Colors.white,
        statusBarLight: false,
        activeControlsWidgetColor: brand.accent,
        backgroundColor: Colors.black,
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false,
        hideBottomControls: false,
      ),
      IOSUiSettings(title: title, aspectRatioLockEnabled: false),
    ],
  );
  return cropped?.path;
}
