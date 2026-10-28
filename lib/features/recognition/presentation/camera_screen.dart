import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';

/// Lists the device cameras. Overridden in tests, where there is no camera.
final availableCamerasProvider = Provider<Future<List<CameraDescription>> Function()>((ref) => availableCameras);

/// In-app camera for scanning: a live viewfinder with breathing corner
/// brackets and a sweeping beam, tap to focus, pinch or 1×/2× to zoom, flash,
/// a gallery shortcut and a shutter that flashes the screen. Pops with the
/// path of the photo taken (or picked), or null.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

enum _CameraIssue { none, denied, unavailable }

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  _CameraIssue _issue = _CameraIssue.none;
  bool _capturing = false;
  FlashMode _flash = FlashMode.off;
  double _zoom = 1;
  double _maxZoom = 1;
  double _pinchStart = 1;
  Offset? _focus;

  late final AnimationController _focusRing = AnimationController(vsync: this, duration: Motion.slow);
  late final AnimationController _shutterFlash = AnimationController(vsync: this, duration: Motion.base);
  late final AnimationController _beam = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _beam.stop();
    } else if (!_beam.isAnimating) {
      _beam.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _focusRing.dispose();
    _shutterFlash.dispose();
    _beam.dispose();
    super.dispose();
  }

  /// The camera is released while the app is in the background and reopened
  /// when it returns, as Android requires.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      if (mounted) setState(() {});
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed && controller == null && _issue == _CameraIssue.none) {
      unawaited(_open());
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await ref.read(availableCamerasProvider)();
    } catch (_) {
      _cameras = const [];
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() {
        _issue = _CameraIssue.unavailable;
      });
      return;
    }
    final back = _cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.back);
    _cameraIndex = back < 0 ? 0 : back;
    await _open();
  }

  Future<void> _open() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash).catchError((Object _) {});
      _maxZoom = (await controller.getMaxZoomLevel().catchError((Object _) => 1.0)).clamp(1.0, 8.0);
      _zoom = 1;
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _issue = _CameraIssue.none;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      if (!mounted) return;
      final denied = error.code.contains('AccessDenied') || error.code.contains('ermission');
      setState(() {
        _issue = denied ? _CameraIssue.denied : _CameraIssue.unavailable;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    unawaited(HapticFeedback.selectionClick());
    final old = _controller;
    setState(() {
      _controller = null;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    await old?.dispose();
    await _open();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    unawaited(HapticFeedback.selectionClick());
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException {
      // Front cameras usually have no flash: keep the button state as is.
    }
  }

  Future<void> _setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null) return;
    final level = zoom.clamp(1.0, _maxZoom);
    setState(() => _zoom = level);
    await controller.setZoomLevel(level).catchError((Object _) {});
  }

  Future<void> _focusAt(TapUpDetails details, BoxConstraints box) async {
    final controller = _controller;
    if (controller == null) return;
    final point = Offset(
      (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / box.maxHeight).clamp(0.0, 1.0),
    );
    unawaited(HapticFeedback.selectionClick());
    setState(() => _focus = details.localPosition);
    _focusRing.forward(from: 0);
    await controller.setFocusPoint(point).catchError((Object _) {});
    await controller.setExposurePoint(point).catchError((Object _) {});
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) return;
    setState(() => _capturing = true);
    unawaited(HapticFeedback.mediumImpact());
    _shutterFlash.forward(from: 0);
    try {
      final photo = await controller.takePicture();
      if (_flash == FlashMode.torch) await controller.setFlashMode(FlashMode.off).catchError((Object _) {});
      if (mounted) Navigator.of(context).pop(photo.path);
    } on CameraException {
      if (mounted) showToast(context, context.l10n.cameraCaptureFailed, error: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final l10n = context.l10n;
    // Release the live camera first so the system camera can use it.
    if (source == ImageSource.camera) {
      final old = _controller;
      setState(() => _controller = null);
      await old?.dispose();
    }
    try {
      final picked = await ImageSourcePicker().pick(source);
      if (!mounted) return;
      if (picked != null) {
        Navigator.of(context).pop(picked.path);
        return;
      }
    } on PickException {
      if (mounted) {
        showToast(
          context,
          source == ImageSource.camera ? l10n.permissionCameraDenied : l10n.permissionGalleryDenied,
          error: true,
        );
      }
    } catch (_) {
      if (mounted) showToast(context, l10n.imageUnreadable, error: true);
    }
    if (mounted && source == ImageSource.camera && _issue == _CameraIssue.none) await _open();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  onTapUp: (details) => _focusAt(details, box),
                  onScaleStart: (_) => _pinchStart = _zoom,
                  onScaleUpdate: (details) {
                    if (details.pointerCount > 1) _setZoom(_pinchStart * details.scale);
                  },
                  child: ClipRect(child: _CoverPreview(controller: controller)),
                ),
              )
            else if (_issue != _CameraIssue.none)
              _CameraProblem(
                issue: _issue,
                onRetry: _start,
                onSystemCamera: () => _pick(ImageSource.camera),
                onGallery: () => _pick(ImageSource.gallery),
              )
            else
              const Center(child: CircularProgressIndicator(color: Brand.chalk, strokeWidth: 2.4)),
            if (ready) ...[
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _beam,
                  builder: (context, _) => CustomPaint(painter: _FramePainter(progress: _beam.value)),
                ),
              ),
              if (_focus != null)
                Positioned(
                  left: _focus!.dx - 36,
                  top: _focus!.dy - 36,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _focusRing,
                      builder: (context, _) {
                        final t = Curves.easeOut.transform(_focusRing.value);
                        return Opacity(
                          opacity: (1.4 - t).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 1.4 - 0.4 * t,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Brand.chalk, width: 1.5),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
            // White flash when the shutter fires.
            IgnorePointer(
              child: FadeTransition(
                opacity: TweenSequence<double>([
                  TweenSequenceItem(tween: Tween(begin: 0, end: 0.85), weight: 25),
                  TweenSequenceItem(tween: Tween(begin: 0.85, end: 0), weight: 75),
                ]).animate(_shutterFlash),
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.close_rounded,
                          tooltip: l10n.close,
                          onPhoto: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (ready) ...[
                          CircleIconButton(
                            icon: _flash == FlashMode.off ? Icons.flash_off_rounded : Icons.flash_on_rounded,
                            tooltip: l10n.cameraFlash,
                            onPhoto: true,
                            color: _flash == FlashMode.off ? Colors.white : Brand.chalk,
                            onPressed: _toggleFlash,
                          ),
                          if (_cameras.length > 1) ...[
                            const SizedBox(width: Space.xs),
                            CircleIconButton(
                              icon: Icons.cameraswitch_outlined,
                              tooltip: l10n.cameraSwitch,
                              onPhoto: true,
                              onPressed: _switchCamera,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  if (ready) Tag(l10n.cameraHint, icon: Icons.center_focus_strong_outlined, onPhoto: true),
                  const Spacer(),
                  if (ready && _maxZoom >= 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final level in [1.0, 2.0])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _ZoomChip(
                                label: '${level.toStringAsFixed(0)}×',
                                selected: (_zoom - level).abs() < 0.5 || (level == 2 && _zoom > 1.5),
                                onTap: () => _setZoom(level),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.photo_library_outlined,
                          tooltip: l10n.scanGallery,
                          onPhoto: true,
                          size: 52,
                          onPressed: () => _pick(ImageSource.gallery),
                        ),
                        Expanded(
                          child: Center(
                            child: _Shutter(busy: _capturing, enabled: ready, onTap: _capture),
                          ),
                        ),
                        const SizedBox(width: 52),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera preview scaled to cover the screen without distortion.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    // previewSize is reported in landscape; the app runs in portrait.
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: portrait ? size.height : size.width,
        height: portrait ? size.width : size.height,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// Corner brackets that breathe and a gold beam sweeping inside them.
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width * 0.78, size.height * 0.5);
    final center = Offset(size.width / 2, size.height * 0.46);
    final breathe = 1 + 0.025 * math.sin(progress * math.pi * 2);
    final rect = Rect.fromCenter(center: center, width: side * breathe, height: side * 1.15 * breathe);

    // Dim everything outside the frame a little.
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(28)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = const Color(0x59000000));

    final bracket = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    const r = 22.0;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(corner.dx, corner.dy + arm * dy)
        ..lineTo(corner.dx, corner.dy + r * dy)
        ..quadraticBezierTo(corner.dx, corner.dy, corner.dx + r * dx, corner.dy)
        ..lineTo(corner.dx + arm * dx, corner.dy);
      canvas.drawPath(path, bracket);
    }

    // Ping-pong from top to bottom and back.
    final sweep = Curves.easeInOut.transform(progress < 0.5 ? progress * 2 : 2 - progress * 2);
    final y = rect.top + rect.height * (0.08 + 0.84 * sweep);
    final beam = Rect.fromLTWH(rect.left + 18, y - 1, rect.width - 36, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(beam.inflate(10), const Radius.circular(12)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Brand.chalk.withValues(alpha: 0),
            Brand.chalk.withValues(alpha: 0.28),
            Brand.chalk.withValues(alpha: 0),
          ],
        ).createShader(beam.inflate(10)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beam, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x00F3DCA2), Brand.chalk, Color(0x00F3DCA2)]).createShader(beam),
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.progress != progress;
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.enabled, required this.onTap});
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.cameraShutter,
      child: TapScale(
        scale: 0.88,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: busy ? Brand.live : Colors.white.withValues(alpha: enabled ? 1 : 0.4),
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xCC000000) : const Color(0x66000000),
        border: Border.all(color: selected ? Brand.chalk : const Color(0x33FFFFFF)),
      ),
      child: Text(
        label,
        style: Fonts.label(
          context.text.labelMedium,
          weight: 700,
        ).copyWith(color: selected ? Brand.chalk : Colors.white),
      ),
    ),
  );
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.issue,
    required this.onRetry,
    required this.onSystemCamera,
    required this.onGallery,
  });
  final _CameraIssue issue;
  final VoidCallback onRetry;
  final VoidCallback onSystemCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final denied = issue == _CameraIssue.denied;
    return Theme(
      data: Theme.of(context).copyWith(extensions: [BrandColors.dark]),
      child: Builder(
        builder: (context) => ColoredBox(
          color: Brand.ink,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StateMessage(
                    icon: denied ? Icons.lock_outline_rounded : Icons.photo_camera_outlined,
                    tone: Brand.chalk,
                    title: denied ? l10n.cameraDeniedTitle : l10n.cameraUnavailableTitle,
                    body: denied ? l10n.cameraDeniedBody : l10n.cameraUnavailableBody,
                  ),
                  FilledButton.icon(
                    onPressed: onSystemCamera,
                    style: FilledButton.styleFrom(backgroundColor: Brand.chalk, foregroundColor: Brand.ink),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(l10n.cameraUseSystem),
                  ),
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    onPressed: onGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Brand.chalk,
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0x40F5F1E7)),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l10n.scanGallery),
                  ),
                  if (denied) ...[
                    const SizedBox(height: Space.sm),
                    TextButton.icon(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(foregroundColor: Brand.chalk),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
