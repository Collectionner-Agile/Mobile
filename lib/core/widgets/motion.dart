import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Marks when a list's data first appeared. [Reveal]s inside it animate only
/// during the first moments, so items that scroll into view later (or are
/// rebuilt by a lazy list) show up instantly instead of fading in late.
class RevealWindow extends StatefulWidget {
  const RevealWindow({super.key, required this.child, this.window = const Duration(milliseconds: 900)});
  final Widget child;
  final Duration window;

  static bool isOpen(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    if (scope == null) return true;
    return DateTime.now().difference(scope.start) < scope.window;
  }

  @override
  State<RevealWindow> createState() => _RevealWindowState();
}

class _RevealWindowState extends State<RevealWindow> {
  final DateTime _start = DateTime.now();

  @override
  Widget build(BuildContext context) => _RevealScope(start: _start, window: widget.window, child: widget.child);
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({required this.start, required this.window, required super.child});
  final DateTime start;
  final Duration window;

  @override
  bool updateShouldNotify(_RevealScope oldWidget) => start != oldWidget.start;
}

/// Entrance for list and grid items: fades in, rises a few pixels and settles
/// from 97 % scale, each item a beat after the previous one. Plays once per
/// mount; skipped when the platform asks to reduce motion. The stagger lives
/// in the curve (no timers), so nothing is left pending after disposal.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 18});
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
  static const _step = Duration(milliseconds: 45);
  static const _run = Duration(milliseconds: 520);

  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _decided = false;

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
    if (_decided) return;
    _decided = true;
    if (_reduceMotion(context) || !RevealWindow.isOpen(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Same tree before and after the animation, so a later rebuild never
  // remounts the child (at full opacity no layer is pushed).
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) {
          final t = _progress.value;
          return Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Press feedback for any control: shrinks slightly while a finger is down
/// and springs back on release (21st.dev `whileTap: scale 0.97`). Listens to
/// raw pointers so it never steals the tap from the button inside.
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, this.scale = 0.97});
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
      duration: _down ? Motion.fast : Motion.springDuration(Motion.bouncy),
      curve: _down ? Curves.easeOut : Motion.bouncy,
      child: widget.child,
    ),
  );
}

/// Number that rolls from its previous value to the new one: counts up on
/// first show, and moves (instead of jumping) when a bid raises a price.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
  });
  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final text = Text(format(value), style: style, maxLines: 1);
    if (_reduceMotion(context)) return text;
    return Semantics(
      label: format(value),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: duration,
          curve: Motion.enter,
          builder: (context, current, _) => Text(format(current), style: style, maxLines: 1),
        ),
      ),
    );
  }
}

/// Text that appears character by character, each one sharpening from a blur
/// while it rises into place. Port of the 21st.dev "Blur Reveal" component
/// (tom_ui): 20 ms stagger, 0.6 s per character, blur 12 → 0, y 10 → 0.
class BlurReveal extends StatefulWidget {
  const BlurReveal(
    this.text, {
    super.key,
    this.style,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 20),
    this.charDuration = const Duration(milliseconds: 600),
    this.textAlign = TextAlign.center,
  });
  final String text;
  final TextStyle? style;
  final Duration delay;
  final Duration stagger;
  final Duration charDuration;
  final TextAlign textAlign;

  @override
  State<BlurReveal> createState() => _BlurRevealState();
}

class _BlurRevealState extends State<BlurReveal> with SingleTickerProviderStateMixin {
  late final List<String> _chars = widget.text.characters.toList();
  late final Duration _total = widget.delay + widget.stagger * _chars.length + widget.charDuration;
  late final AnimationController _controller = AnimationController(vsync: this, duration: _total);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _charProgress(int index) {
    final start = widget.delay + widget.stagger * index;
    final elapsed = _controller.value * _total.inMicroseconds - start.inMicroseconds;
    return Curves.easeOut.transform((elapsed / widget.charDuration.inMicroseconds).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.isCompleted) {
                return Text(widget.text, style: style, textAlign: widget.textAlign);
              }
              return Wrap(
                alignment: switch (widget.textAlign) {
                  TextAlign.left || TextAlign.start => WrapAlignment.start,
                  TextAlign.right || TextAlign.end => WrapAlignment.end,
                  _ => WrapAlignment.center,
                },
                children: [
                  for (final (index, char) in _chars.indexed)
                    Builder(
                      builder: (context) {
                        final t = _charProgress(index);
                        final glyph = Text(char == ' ' ? ' ' : char, style: style);
                        if (t >= 1) return glyph;
                        final sigma = 6 * (1 - t);
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - t)),
                            child: sigma < 0.2
                                ? glyph
                                : ImageFiltered(
                                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                                    child: glyph,
                                  ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Small dot that breathes, marking something live.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size * 2.2,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_controller.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size * (1 + 1.2 * t),
                  height: size * (1 + 1.2 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cross-fade with a slight zoom, for swapping states in place.
class FadeSwitch extends StatelessWidget {
  const FadeSwitch({super.key, required this.child, this.duration = Motion.base});
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, duration),
    switchInCurve: Motion.enter,
    switchOutCurve: Motion.exit,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(animation), child: child),
    ),
    child: child,
  );
}

/// Page transition shared by every route: the new page glides in a short
/// distance while fading, the old one drifts back and dims a little. Built
/// from transitions (not Opacity in a builder) so the fade stays a cheap
/// composited layer.
class SoftSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftSlidePageTransitionsBuilder();

  static final _inOffset = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero);
  static final _outOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.05, 0));

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
    return SlideTransition(
      position: _outOffset.animate(outgoing),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(position: _inOffset.animate(incoming), child: child),
      ),
    );
  }
}
