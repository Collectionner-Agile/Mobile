import 'dart:math' as math;

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
/// already loading while the scene runs and is revealed through it.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<LaunchGate> {
  late bool _done = !ref.read(launchSceneEnabledProvider);

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_done) LaunchScene(onDone: () => setState(() => _done = true)),
    ],
  );
}

/// Midnight stage that continues the native splash: the album mark settles
/// and catches a gold glint, the name sharpens letter by letter (21st.dev
/// "Blur Reveal"), a gold rule draws under it, and a circle opens from the
/// mark to reveal the app. A tap skips straight to the reveal.
class LaunchScene extends StatefulWidget {
  const LaunchScene({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<LaunchScene> createState() => _LaunchSceneState();
}

class _LaunchSceneState extends State<LaunchScene> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2500);
  static const _exitStart = 0.74;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _total)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });

  late final Animation<double> _logoIn = _interval(0, 0.26, Motion.bouncy);
  late final Animation<double> _glow = _interval(0, 0.5, Curves.easeOut);
  late final Animation<double> _lift = _interval(0.2, 0.5, Motion.standard);
  late final Animation<double> _glint = _interval(0.24, 0.5, Curves.easeInOut);
  late final Animation<double> _rule = _interval(0.46, 0.66, Motion.enter);
  late final Animation<double> _tagline = _interval(0.5, 0.7, Motion.enter);
  late final Animation<double> _exit = _interval(_exitStart, 1, Motion.enter);

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
      // No choreography: a short fade straight into the app.
      _controller.value = _exitStart;
    }
    _controller.forward();
  }

  ImageProvider _logo(BuildContext context) =>
      ResizeImage(const AssetImage(_logoAsset), width: (160 * MediaQuery.devicePixelRatioOf(context)).round());

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
    final size = MediaQuery.sizeOf(context);
    final logoCenter = Offset(size.width / 2, size.height / 2);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Semantics(
        label: l10n.appName,
        button: true,
        onTapHint: l10n.skip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final exit = _exit.value;
              if (exit >= 1) return const SizedBox.shrink();
              final radius = exit * math.sqrt(size.width * size.width + size.height * size.height);
              return ClipPath(
                clipper: _HoleClipper(center: logoCenter, radius: radius),
                child: Material(
                  color: Brand.midnight,
                  child: Opacity(
                    opacity: (1 - exit * 1.6).clamp(0.0, 1.0),
                    child: Transform.scale(scale: 1 + 0.08 * exit, child: child),
                  ),
                ),
              );
            },
            child: _Stage(
              logo: _logo(context),
              logoIn: _logoIn,
              glow: _glow,
              lift: _lift,
              glint: _glint,
              rule: _rule,
              tagline: _tagline,
              name: l10n.appName,
              taglineText: l10n.launchTagline,
            ),
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.logo,
    required this.logoIn,
    required this.glow,
    required this.lift,
    required this.glint,
    required this.rule,
    required this.tagline,
    required this.name,
    required this.taglineText,
  });

  final ImageProvider logo;
  final Animation<double> logoIn;
  final Animation<double> glow;
  final Animation<double> lift;
  final Animation<double> glint;
  final Animation<double> rule;
  final Animation<double> tagline;
  final String name;
  final String taglineText;

  /// Height of everything under the logo; the logo starts this much lower
  /// (half of it) so it begins exactly centred, where the native splash
  /// showed it.
  static const double _below = 124;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep vignette: midnight at the edges, a lifted navy centre.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [Color(0xFF16244A), Brand.midnight, Brand.midnightDeep],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([logoIn, glow, lift, glint]),
                builder: (context, _) {
                  final lifted = Curves.linear.transform(lift.value);
                  final scale = (0.82 + 0.18 * logoIn.value) * (1.22 - 0.22 * lifted);
                  return Transform.translate(
                    offset: Offset(0, _below / 2 * (1 - lifted)),
                    child: SizedBox.square(
                      dimension: 132,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Gold halo that blooms behind the mark.
                          Transform.scale(
                            scale: 0.6 + 1.4 * glow.value,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Brand.gold.withValues(alpha: 0.34 * glow.value),
                                    Brand.gold.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: logoIn.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: scale,
                              child: ShaderMask(
                                blendMode: BlendMode.srcATop,
                                shaderCallback: (bounds) {
                                  final t = glint.value;
                                  return LinearGradient(
                                    begin: Alignment(-2.2 + 4 * t, -1),
                                    end: Alignment(-1.2 + 4 * t, 1),
                                    colors: const [Color(0x00FFFFFF), Color(0x80FFF2CF), Color(0x00FFFFFF)],
                                  ).createShader(bounds);
                                },
                                child: Image(image: logo, width: 132, height: 132, gaplessPlayback: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 48,
                child: BlurReveal(
                  name,
                  delay: const Duration(milliseconds: 560),
                  style: Fonts.display(
                    const TextStyle(fontSize: 36, height: 1.2, letterSpacing: -0.6),
                    weight: 640,
                  ).copyWith(color: Brand.ivory),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: rule,
                builder: (context, _) => Container(
                  width: 64 * rule.value,
                  height: 1.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x00DDB563), Brand.gold, Color(0x00DDB563)]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeTransition(
                opacity: tagline,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(tagline),
                  child: Text(
                    taglineText.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Fonts.eyebrow(const TextStyle(fontSize: 11.5))
                        .copyWith(color: Brand.gold, letterSpacing: 3.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Everything except a circle of [radius] around [center]: the app shows
/// through the hole as it grows.
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper({required this.center, required this.radius});
  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (radius > 0) path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) => oldClipper.radius != radius || oldClipper.center != center;
}

/// Closing scene: a midnight circle rises over the app, the mark returns with
/// a short line, and the scene settles. [farewell] then either leaves the app
/// or hands back to it.
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });

  late final Animation<double> _cover = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.38, curve: Motion.standard),
  );
  late final Animation<double> _mark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.55, curve: Motion.bouncy),
  );
  late final Animation<double> _words = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 0.7, curve: Motion.enter),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.82, 1, curve: Motion.exit),
  );

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
    final size = MediaQuery.sizeOf(context);
    final origin = Offset(size.width / 2, size.height);
    final full = math.sqrt(size.width * size.width / 4 + size.height * size.height);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => ClipPath(
          clipper: _CircleClipper(center: origin, radius: full * _cover.value),
          child: Material(
            color: Brand.midnight,
            child: Opacity(
              opacity: 1 - _fade.value,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _mark.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * _mark.value,
                        child: Image.asset(
                          _logoAsset,
                          width: 96,
                          height: 96,
                          cacheWidth: (96 * MediaQuery.devicePixelRatioOf(context)).round(),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    Opacity(
                      opacity: _words.value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - _words.value)),
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: Fonts.display(
                                const TextStyle(fontSize: 30, height: 1.15),
                                weight: 640,
                              ).copyWith(color: Brand.ivory),
                            ),
                            const SizedBox(height: Space.xs),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                              child: Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xB3F5F1E7)),
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
          ),
        ),
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper({required this.center, required this.radius});
  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper oldClipper) => oldClipper.radius != radius || oldClipper.center != center;
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
