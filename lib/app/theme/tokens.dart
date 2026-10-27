import 'package:flutter/material.dart';

/// Collectionner "Field Index" palette, taken from the web design tokens
/// (paper, ink, rust, restrained lines) and extended for dark mode.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.paper,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.rust,
    required this.rustStrong,
    required this.onRust,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.skeleton,
  });

  final Color paper;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color muted;
  final Color line;
  final Color rust;
  final Color rustStrong;
  final Color onRust;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color skeleton;

  static const light = BrandColors(
    paper: Color(0xFFE9ECE4),
    surface: Color(0xFFF4F5F0),
    surfaceRaised: Color(0xFFFBFCF8),
    ink: Color(0xFF18231F),
    muted: Color(0xFF4E5B52),
    line: Color(0xFFC9D0C6),
    rust: Color(0xFFA63B1D),
    rustStrong: Color(0xFF8F3218),
    onRust: Color(0xFFFBFCF8),
    success: Color(0xFF2D6A4F),
    warning: Color(0xFF8A5A0B),
    danger: Color(0xFFB3261E),
    info: Color(0xFF2F5D7C),
    skeleton: Color(0xFFDCE1D7),
  );

  static const dark = BrandColors(
    paper: Color(0xFF101714),
    surface: Color(0xFF17211D),
    surfaceRaised: Color(0xFF1E2A25),
    ink: Color(0xFFE6EAE1),
    muted: Color(0xFFA7B3A9),
    line: Color(0xFF2E3B35),
    rust: Color(0xFFE2805C),
    rustStrong: Color(0xFFF0A07F),
    onRust: Color(0xFF1A0F0A),
    success: Color(0xFF7FC8A0),
    warning: Color(0xFFE8B45A),
    danger: Color(0xFFF2B8B5),
    info: Color(0xFF9CC3E0),
    skeleton: Color(0xFF26332D),
  );

  @override
  BrandColors copyWith() => this;

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandColors(
      paper: mix(paper, other.paper),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      rust: mix(rust, other.rust),
      rustStrong: mix(rustStrong, other.rustStrong),
      onRust: mix(onRust, other.onRust),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      info: mix(info, other.info),
      skeleton: mix(skeleton, other.skeleton),
    );
  }
}

abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double pill = 999;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve enter = Cubic(0.2, 0.75, 0.25, 1);
  static const Curve exit = Cubic(0.4, 0, 1, 1);
  static const Curve standard = Cubic(0.2, 0.6, 0.2, 1);

  /// Honors the platform "remove animations" accessibility setting.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : duration;
}

extension BrandContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
