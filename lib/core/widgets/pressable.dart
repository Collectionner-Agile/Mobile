import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Card-like tap target with a subtle press-scale feedback (disabled when the
/// platform asks to reduce motion).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.borderRadius = Radii.md,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && !reduce ? 0.975 : 1,
        duration: Motion.fast,
        curve: Motion.standard,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
