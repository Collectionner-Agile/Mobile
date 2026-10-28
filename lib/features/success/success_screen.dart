import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/ui.dart';

/// What the success screen celebrates and where its buttons lead.
class SuccessArgs {
  const SuccessArgs({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryRoute,
    this.secondaryLabel,
    this.secondaryRoute,
    this.icon = Icons.check_rounded,
  });

  final String title;
  final String message;
  final String primaryLabel;

  /// Where the primary button goes (replaces the success page).
  final String primaryRoute;
  final String? secondaryLabel;
  final String? secondaryRoute;
  final IconData icon;
}

/// Full-screen confirmation after something worth celebrating (a bid, a new
/// piece, a new community): a gold check draws itself, a ring pulses out,
/// confetti bursts once, and two plain buttons say what's next.
class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key, required this.args});
  final SuccessArgs args;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> _disc = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.35, curve: Motion.bouncy),
  );
  late final Animation<double> _check = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
  );
  late final Animation<double> _burst = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );
  late final Animation<double> _words = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 0.8, curve: Motion.enter),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      HapticFeedback.heavyImpact();
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
    final brand = context.brand;
    final args = widget.args;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(args.primaryRoute);
      },
      child: Scaffold(
        body: AmbientGlow(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(Space.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - Space.xl * 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 220,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => CustomPaint(
                            painter: _ConfettiPainter(
                              progress: _burst.value,
                              colors: [brand.ink, brand.live, brand.muted, brand.gold],
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ring that pulses out once.
                                  Opacity(
                                    opacity: (1 - _burst.value).clamp(0.0, 1.0) * 0.6,
                                    child: Container(
                                      width: 96 + 90 * _burst.value,
                                      height: 96 + 90 * _burst.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: brand.ink, width: 2),
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: _disc.value,
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: brand.ink,
                                        boxShadow: [
                                          BoxShadow(
                                            color: brand.shadow,
                                            blurRadius: 30,
                                            offset: const Offset(0, 12),
                                            spreadRadius: -6,
                                          ),
                                        ],
                                      ),
                                      child: args.icon == Icons.check_rounded
                                          ? CustomPaint(
                                              painter: _CheckPainter(progress: _check.value, color: brand.paper),
                                            )
                                          : Opacity(
                                              opacity: _check.value,
                                              child: Icon(args.icon, size: 44, color: brand.paper),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      FadeTransition(
                        opacity: _words,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(_words),
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                liveRegion: true,
                                child: Text(args.title, textAlign: TextAlign.center, style: context.text.displaySmall),
                              ),
                              const SizedBox(height: Space.sm),
                              Text(
                                args.message,
                                textAlign: TextAlign.center,
                                style: context.text.bodyLarge?.copyWith(color: brand.muted),
                              ),
                              const SizedBox(height: Space.xxl),
                              ContentWidth(
                                maxWidth: 420,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    BusyButton(
                                      label: args.primaryLabel,
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: () => context.go(args.primaryRoute),
                                    ),
                                    if (args.secondaryLabel != null && args.secondaryRoute != null) ...[
                                      const SizedBox(height: Space.sm),
                                      BusyButton(
                                        label: args.secondaryLabel!,
                                        outlined: true,
                                        onPressed: () => context.go(args.secondaryRoute!),
                                      ),
                                    ],
                                  ],
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
      ),
    );
  }
}

/// A check mark drawn stroke by stroke.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

/// One burst of confetti from the centre: pieces fly out, turn and fall.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.colors});
  final double progress;
  final List<Color> colors;

  static final _pieces = List.generate(28, (i) {
    final random = math.Random(i * 7919);
    return (
      angle: random.nextDouble() * math.pi * 2,
      distance: 0.55 + random.nextDouble() * 0.45,
      spin: random.nextDouble() * 6 - 3,
      size: 4 + random.nextDouble() * 5,
      round: random.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final reach = size.width / 2;
    for (final (i, piece) in _pieces.indexed) {
      final travel = Curves.easeOut.transform(progress) * reach * piece.distance;
      final fall = progress * progress * 40;
      final position = center + Offset(math.cos(piece.angle) * travel, math.sin(piece.angle) * travel + fall);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: (1 - progress).clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(piece.spin * progress * math.pi);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
