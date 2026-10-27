import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Entrance for list and grid items: fades in and rises a few pixels, each
/// item a beat after the previous one. Plays once per mount; skipped when the
/// platform asks to reduce motion. The stagger lives in the curve (no timers),
/// so it never leaves work pending after the widget is gone.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 24});
  final Widget child;

  /// Position in the list; later items start later (capped so long lists do
  /// not keep the user waiting).
  final int index;

  /// Rise distance in logical pixels.
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 55);
  static const _run = Duration(milliseconds: 460);

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final delay = _step * widget.index.clamp(0, 8);
    final total = delay + _run;
    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: Motion.enter),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(offset: Offset(0, widget.offset * (1 - _progress.value)), child: child),
    ),
    child: widget.child,
  );
}

/// Press feedback for any control: shrinks slightly while a finger is down
/// and springs back on release. Listens to raw pointers so it never steals
/// the tap from the button inside.
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, this.scale = 0.96});
  final Widget child;
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down && !_reduceMotion(context) ? widget.scale : 1,
      duration: _down ? Motion.fast : Motion.base,
      curve: _down ? Curves.easeOut : Curves.elasticOut,
      child: widget.child,
    ),
  );
}

/// Number that rolls from its previous value to the new one: counts up on
/// first show, and moves (instead of jumping) when a bid raises a price.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.format, this.style});
  final double value;
  final String Function(double value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = Text(format(value), style: style, maxLines: 1);
    if (_reduceMotion(context)) return text;
    return Semantics(
      label: format(value),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 900),
          curve: Motion.enter,
          builder: (context, current, _) => Text(format(current), style: style, maxLines: 1),
        ),
      ),
    );
  }
}

/// Page transition shared by every route: the new page slides in a short
/// distance while fading, the old one drifts the other way.
class SoftSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reduceMotion(context)) return child;
    final incoming = CurvedAnimation(parent: animation, curve: Motion.enter, reverseCurve: Motion.exit);
    final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: Motion.standard);
    return AnimatedBuilder(
      animation: Listenable.merge([incoming, outgoing]),
      builder: (context, child) {
        final inX = 36 * (1 - incoming.value);
        final outX = -28 * outgoing.value;
        return Opacity(
          opacity: incoming.value.clamp(0, 1),
          child: Transform.translate(offset: Offset(inX + outX, 0), child: child),
        );
      },
      child: child,
    );
  }
}
