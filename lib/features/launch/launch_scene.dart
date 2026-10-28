import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';

/// Whether the launch scene plays on a cold start. Tests turn it off.
final launchSceneEnabledProvider = Provider<bool>((ref) => true);

const _logoAsset = 'assets/branding/site-icon-512.png';

/// Plays [LaunchScene] above the app on a cold start, then gets out of the
/// way. The app builds underneath from the first frame, so its data is
/// already loading while the scene runs; as the scene lifts away the app
/// settles from a slight zoom into place.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<LaunchGate> {
  late bool _done = !ref.read(launchSceneEnabledProvider);
  late final _reveal = ValueNotifier<double>(_done ? 1 : 0);

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  // The tree keeps the same shape before and after the scene so the app
  // underneath is never rebuilt from scratch.
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ValueListenableBuilder<double>(
        valueListenable: _reveal,
        child: widget.child,
        builder: (context, reveal, child) => Transform.scale(scale: 0.94 + 0.06 * reveal, child: child),
      ),
      if (!_done) LaunchScene(reveal: _reveal, onDone: () => setState(() => _done = true)),
    ],
  );
}

/// Continues the native splash on the same ground: the mark settles, the
/// hairline frame of a graded slab draws itself around it, the lot label
/// drops in with the live dot, and the name sharpens letter by letter. The
/// scene then lifts like the lid of a case while the app zooms in under it.
/// A tap skips straight to the lift.
class LaunchScene extends StatefulWidget {
  const LaunchScene({super.key, required this.onDone, this.reveal});
  final VoidCallback onDone;

  /// Driven from 0 to 1 while the scene lifts away.
  final ValueNotifier<double>? reveal;

  @override
  State<LaunchScene> createState() => _LaunchSceneState();
}

class _LaunchSceneState extends State<LaunchScene> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2600);
  static const _exitStart = 0.76;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _total)
    ..addListener(() => widget.reveal?.value = _exit.value)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });

  late final _slab = SlabAnimations(
    mark: _interval(0, 0.22, Motion.bouncy),
    frame: _interval(0.12, 0.44, Motion.standard),
    fill: _interval(0.3, 0.5, Curves.easeOut),
    label: _interval(0.4, 0.58, Motion.enter),
  );
  late final Animation<double> _tagline = _interval(0.52, 0.72, Motion.enter);
  late final Animation<double> _exit = _interval(_exitStart, 1, Curves.easeInOutCubic);

  bool _started = false;

  Animation<double> _interval(double begin, double end, Curve curve) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    precacheImage(_logo(context), context);
    if (Motion.reduced(context)) {
      // No choreography: a short lift straight into the app.
      _controller.value = _exitStart;
    }
    _controller.forward();
  }

  ImageProvider _logo(BuildContext context) =>
      ResizeImage(const AssetImage(_logoAsset), width: (120 * MediaQuery.devicePixelRatioOf(context)).round());

  void _skip() {
    if (_controller.value < _exitStart) {
      _controller.value = _exitStart;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final height = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Semantics(
        label: l10n.appName,
        button: true,
        onTapHint: l10n.skip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: AnimatedBuilder(
            animation: _exit,
            builder: (context, child) {
              final exit = _exit.value;
              if (exit >= 1) return const SizedBox.shrink();
              // The lid rises with a soft edge shadow; the slab rides a little
              // ahead of it.
              return Transform.translate(
                offset: Offset(0, -height * exit),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: brand.paper, boxShadow: exit > 0 ? brand.floatingShadow : null),
                  child: Transform.translate(offset: Offset(0, -80 * exit), child: child),
                ),
              );
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SlabMark(logo: _logo(context), animations: _slab, lot: l10n.lotRef('0001')),
                  const SizedBox(height: Space.xl),
                  SizedBox(
                    height: 46,
                    child: BlurReveal(
                      l10n.appName,
                      delay: const Duration(milliseconds: 1000),
                      style: Fonts.display(
                        const TextStyle(fontSize: 34, height: 1.2, letterSpacing: -0.6),
                        weight: 760,
                      ).copyWith(color: brand.ink),
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  FadeTransition(
                    opacity: _tagline,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(_tagline),
                      child: Text(
                        l10n.launchTagline,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(color: brand.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four beats of the slab drawing itself.
class SlabAnimations {
  const SlabAnimations({required this.mark, required this.frame, required this.fill, required this.label});

  /// The mark pops into place.
  final Animation<double> mark;

  /// The hairline frame traces from the top centre round to the bottom.
  final Animation<double> frame;

  /// The case fills in behind the mark.
  final Animation<double> fill;

  /// The lot label drops into its strip.
  final Animation<double> label;
}

/// The app's mark cased like a graded collectible: a hairline frame, a label
/// strip with the lot number and the live dot, and the mark in the well.
class SlabMark extends StatelessWidget {
  const SlabMark({super.key, required this.logo, required this.animations, required this.lot});
  final ImageProvider logo;
  final SlabAnimations animations;
  final String lot;

  static const double _width = 168;
  static const double _label = 30;
  static const double _height = 214;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final a = animations;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([a.mark, a.frame, a.fill, a.label]),
        builder: (context, _) => SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            children: [
              // Case body.
              Positioned.fill(
                child: Opacity(
                  opacity: a.fill.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: brand.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      boxShadow: brand.cardShadow,
                    ),
                  ),
                ),
              ),
              // Label strip: lot number and the live dot.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _label,
                child: ClipRect(
                  child: Opacity(
                    opacity: a.label.value,
                    child: Transform.translate(
                      offset: Offset(0, -_label * (1 - a.label.value)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: brand.line)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lot,
                                  maxLines: 1,
                                  style: Fonts.figures(Fonts.label(context.text.labelSmall, weight: 700))
                                      .copyWith(color: brand.ink, fontSize: 11.5),
                                ),
                              ),
                              PulseDot(color: brand.live, size: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The mark in the well.
              Positioned(
                left: 0,
                right: 0,
                top: _label,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: a.mark.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * a.mark.value,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        child: Image(image: logo, width: 120, height: 120, gaplessPlayback: true),
                      ),
                    ),
                  ),
                ),
              ),
              // Hairline frame, drawn last so it sits on the case edge.
              Positioned.fill(
                child: CustomPaint(
                  painter: _FramePainter(progress: a.frame.value, color: brand.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded frame that traces both ways from the top centre and closes at
/// the bottom centre.
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const inset = 0.75;
    const r = Radii.md;
    final w = size.width - inset;
    final h = size.height - inset;
    const corner = Radius.circular(r);
    final path = Path()
      ..moveTo(size.width / 2, inset)
      ..lineTo(w - r, inset)
      ..arcToPoint(Offset(w, inset + r), radius: corner)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: corner)
      ..lineTo(inset + r, h)
      ..arcToPoint(Offset(inset, h - r), radius: corner)
      ..lineTo(inset, inset + r)
      ..arcToPoint(const Offset(inset + r, inset), radius: corner)
      ..close();
    final metric = path.computeMetrics().first;
    final length = metric.length;
    final half = length * progress.clamp(0.0, 1.0) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas
      ..drawPath(metric.extractPath(0, half), paint)
      ..drawPath(metric.extractPath(length - half, length), paint);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.progress != progress || old.color != color;
}

/// Closing scene: the page ground drops over the app like a lid, the slab
/// draws itself around the mark with a short goodbye, and everything fades.
/// [farewell] then either leaves the app or hands back to it.
class FarewellScene extends StatefulWidget {
  const FarewellScene({super.key, required this.title, required this.message, required this.onFinished});
  final String title;
  final String message;
  final VoidCallback onFinished;

  @override
  State<FarewellScene> createState() => _FarewellSceneState();
}

class _FarewellSceneState extends State<FarewellScene> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });

  Animation<double> _interval(double begin, double end, Curve curve) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: curve),
  );

  late final Animation<double> _cover = _interval(0, 0.3, Curves.easeInOutCubic);
  late final _slab = SlabAnimations(
    mark: _interval(0.22, 0.42, Motion.bouncy),
    frame: _interval(0.24, 0.52, Motion.standard),
    fill: _interval(0.3, 0.46, Curves.easeOut),
    label: _interval(0.4, 0.56, Motion.enter),
  );
  late final Animation<double> _words = _interval(0.42, 0.66, Motion.enter);
  late final Animation<double> _fade = _interval(0.84, 1, Motion.exit);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    HapticFeedback.mediumImpact();
    if (Motion.reduced(context)) {
      _controller.duration = const Duration(milliseconds: 400);
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final height = MediaQuery.sizeOf(context).height;
    final logo = ResizeImage(
      const AssetImage(_logoAsset),
      width: (120 * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: AnimatedBuilder(
        animation: Listenable.merge([_cover, _fade]),
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -height * (1 - _cover.value)),
          child: DecoratedBox(
            decoration: BoxDecoration(color: brand.paper, boxShadow: brand.floatingShadow),
            child: Opacity(opacity: 1 - _fade.value, child: child),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SlabMark(logo: logo, animations: _slab, lot: context.l10n.lotRef('0001')),
              const SizedBox(height: Space.xl),
              FadeTransition(
                opacity: _words,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(_words),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: Fonts.display(
                          const TextStyle(fontSize: 30, height: 1.15),
                          weight: 760,
                        ).copyWith(color: brand.ink),
                      ),
                      const SizedBox(height: Space.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(color: brand.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays the farewell over everything. With [exitApp] the app closes when it
/// ends; otherwise the scene is removed and [then] runs (e.g. after signing
/// out, to land on the home screen as a guest).
Future<void> farewell(
  BuildContext context, {
  required String title,
  required String message,
  bool exitApp = false,
  VoidCallback? then,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
      pageBuilder: (routeContext, _, _) => PopScope(
        canPop: false,
        child: FarewellScene(
          title: title,
          message: message,
          onFinished: () {
            if (exitApp) {
              SystemNavigator.pop();
            } else {
              Navigator.of(routeContext).pop();
              then?.call();
            }
          },
        ),
      ),
    ),
  );
}
