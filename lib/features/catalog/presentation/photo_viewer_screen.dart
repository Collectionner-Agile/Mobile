import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/ui.dart';

/// Full-screen photo viewer: swipe between photos, pinch or double-tap to
/// zoom, drag down to close, and a strip of thumbnails to jump around.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.urls, this.initial = 0, this.heroTag, this.title});
  final List<String> urls;
  final int initial;

  /// Shared-element tag of the first photo, so it flies in from the page.
  final String? heroTag;
  final String? title;

  /// Opens the viewer over everything with a fade, keeping the page behind
  /// visible while the photo is dragged away.
  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initial = 0,
    String? heroTag,
    String? title,
  }) {
    HapticFeedback.selectionClick();
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Motion.base,
        reverseTransitionDuration: Motion.base,
        pageBuilder: (_, _, _) => PhotoViewerScreen(urls: urls, initial: initial, heroTag: heroTag, title: title),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  late final List<TransformationController> _zooms = [for (final _ in widget.urls) TransformationController()];
  late final AnimationController _zoomAnimation = AnimationController(vsync: this, duration: Motion.base);
  Animation<Matrix4>? _zoomTween;
  TapDownDetails? _doubleTap;
  double _drag = 0;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoomAnimation.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _zooms[_index].value = tween.value;
    });
    for (final controller in _zooms) {
      controller.addListener(_onZoomChanged);
    }
  }

  void _onZoomChanged() {
    final zoomed = _zooms[_index].value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  void dispose() {
    _pages.dispose();
    _zoomAnimation.dispose();
    for (final controller in _zooms) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleZoom() {
    final controller = _zooms[_index];
    final position = _doubleTap?.localPosition ?? Offset.zero;
    final Matrix4 target;
    if (controller.value.getMaxScaleOnAxis() > 1.01) {
      target = Matrix4.identity();
    } else {
      const scale = 2.6;
      target = Matrix4.identity()
        ..translateByDouble(-position.dx * (scale - 1), -position.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    HapticFeedback.selectionClick();
    _zoomTween = Matrix4Tween(
      begin: controller.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoomAnimation, curve: Motion.standard));
    _zoomAnimation.forward(from: 0);
  }

  void _jump(int index) {
    HapticFeedback.selectionClick();
    _pages.animateToPage(index, duration: Motion.of(context, Motion.base), curve: Motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final fade = (1 - (_drag.abs() / (size.height * 0.4))).clamp(0.0, 1.0);
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: fade),
        body: Stack(
          children: [
            GestureDetector(
              onVerticalDragUpdate: _zoomed ? null : (details) => setState(() => _drag += details.delta.dy),
              onVerticalDragEnd: _zoomed
                  ? null
                  : (details) {
                      if (_drag.abs() > 120 || details.velocity.pixelsPerSecond.dy.abs() > 900) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() => _drag = 0);
                      }
                    },
              child: AnimatedContainer(
                duration: _drag == 0 ? Motion.of(context, Motion.base) : Duration.zero,
                curve: Motion.standard,
                transform: Matrix4.translationValues(0, _drag, 0),
                child: PageView.builder(
                  controller: _pages,
                  physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                  itemCount: widget.urls.length,
                  onPageChanged: (index) => setState(() {
                    _index = index;
                    _zoomed = false;
                  }),
                  itemBuilder: (context, index) {
                    Widget photo = CollectibleImage(
                      widget.urls[index],
                      fit: BoxFit.contain,
                      cacheWidth: 1400,
                      semanticLabel: widget.title,
                    );
                    if (index == widget.initial && widget.heroTag != null) {
                      photo = Hero(tag: widget.heroTag!, child: photo);
                    }
                    return GestureDetector(
                      onDoubleTapDown: (details) => _doubleTap = details,
                      onDoubleTap: _toggleZoom,
                      child: InteractiveViewer(
                        transformationController: _zooms[index],
                        minScale: 1,
                        maxScale: 5,
                        child: SizedBox.expand(child: photo),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: fade,
                duration: Duration.zero,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: AppIcons.x,
                          tooltip: l10n.close,
                          onPhoto: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (widget.urls.length > 1) Tag(l10n.photoCount(_index + 1, widget.urls.length), onPhoto: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _zoomed ? 0 : fade,
                  duration: Motion.of(context, Motion.fast),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                        itemCount: widget.urls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                        itemBuilder: (context, index) => Semantics(
                          button: true,
                          selected: index == _index,
                          label: l10n.photoCount(index + 1, widget.urls.length),
                          child: GestureDetector(
                            onTap: () => _jump(index),
                            child: AnimatedContainer(
                              duration: Motion.of(context, Motion.fast),
                              width: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(Radii.sm),
                                border: Border.all(
                                  color: index == _index ? Brand.gold : const Color(0x33FFFFFF),
                                  width: index == _index ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(Radii.sm - 2),
                                child: Opacity(
                                  opacity: index == _index ? 1 : 0.6,
                                  child: CollectibleImage(widget.urls[index], cacheWidth: 112),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
