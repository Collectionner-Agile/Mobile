import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Frosted panel laid over photography. The blur keeps text legible on any
/// image without a heavy scrim; the hairline edge separates it from bright
/// backgrounds.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md),
    this.radius = Radii.md,
    this.tint = const Color(0x33000000),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: shape,
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Dark pill for a price shown over a photo.
class PricePill extends StatelessWidget {
  const PricePill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: const Color(0xD90E0F11), borderRadius: BorderRadius.circular(Radii.pill)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Fonts.figures(Fonts.display(context.text.titleMedium, weight: 720)).copyWith(color: Colors.white),
      ),
    ),
  );
}

/// Page position dots for a photo gallery.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == index ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == index ? Colors.white : const Color(0x80FFFFFF),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        ),
    ],
  );
}
