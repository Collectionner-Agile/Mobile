import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/config/app_config.dart';
import '../../app/theme/tokens.dart';
import 'app_icons.dart';

/// Renders any image reference the backend stores: bundled web asset paths
/// (`/assets/...`), inline `data:` URIs from media uploads, or remote URLs.
class CollectibleImage extends StatelessWidget {
  const CollectibleImage(this.url, {super.key, this.fit = BoxFit.cover, this.semanticLabel, this.cacheWidth});

  final String? url;
  final BoxFit fit;
  final String? semanticLabel;

  /// Decode width in logical pixels; keeps big photos from decoding at full size.
  final double? cacheWidth;

  static final _dataCache = <String, Uint8List>{};

  @override
  Widget build(BuildContext context) {
    final source = url?.trim();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = cacheWidth == null ? null : (cacheWidth! * dpr).round();
    if (source == null || source.isEmpty) return _Placeholder(label: semanticLabel);

    if (source.startsWith('/assets/') || source.startsWith('assets/')) {
      final asset = _bundledAsset(source);
      if (asset.endsWith('.svg')) {
        return SvgPicture.asset(
          asset,
          fit: fit,
          semanticsLabel: semanticLabel,
          placeholderBuilder: (_) => _Placeholder(label: semanticLabel),
        );
      }
      return Image.asset(
        asset,
        fit: fit,
        semanticLabel: semanticLabel,
        cacheWidth: decodeWidth,
        errorBuilder: (_, _, _) => _Placeholder(label: semanticLabel),
      );
    }

    if (source.startsWith('data:image/')) {
      final bytes = _decodeDataUri(source);
      if (bytes == null) return _Placeholder(label: semanticLabel);
      return Image.memory(
        bytes,
        fit: fit,
        semanticLabel: semanticLabel,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _Placeholder(label: semanticLabel),
      );
    }

    final uri = source.startsWith('http')
        ? source
        : '${AppConfig.apiBaseUrl}${source.startsWith('/') ? '' : '/'}$source';
    if (!uri.startsWith('https://') && !AppConfig.isLoopback) {
      // Never fetch cleartext images from remote hosts.
      return _Placeholder(label: semanticLabel);
    }
    return CachedNetworkImage(
      imageUrl: uri,
      fit: fit,
      memCacheWidth: decodeWidth,
      fadeInDuration: Motion.of(context, Motion.base),
      placeholder: (_, _) => const _Shimmer(),
      errorWidget: (_, _, _) => _Placeholder(label: semanticLabel),
      imageBuilder: semanticLabel == null
          ? null
          : (context, provider) => Semantics(
              image: true,
              label: semanticLabel,
              child: Image(image: provider, fit: fit),
            ),
    );
  }

  static String _bundledAsset(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    if (clean.startsWith('assets/images/')) return clean;
    return clean.replaceFirst('assets/', 'assets/images/');
  }

  static Uint8List? _decodeDataUri(String uri) {
    final cached = _dataCache[uri];
    if (cached != null) return cached;
    final comma = uri.indexOf(',');
    if (comma < 0 || !uri.substring(0, comma).endsWith(';base64')) return null;
    try {
      final bytes = base64Decode(uri.substring(comma + 1));
      if (_dataCache.length > 40) _dataCache.remove(_dataCache.keys.first);
      _dataCache[uri] = bytes;
      return bytes;
    } on FormatException {
      return null;
    }
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      label: label,
      image: true,
      child: ColoredBox(
        color: brand.surface,
        child: Center(child: Icon(AppIcons.package, color: brand.line, size: 32)),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.brand.skeleton);
}
