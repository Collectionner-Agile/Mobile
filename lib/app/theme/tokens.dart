import 'package:flutter/material.dart';

/// "Midnight & Gold": navy and gold from the Collectionner mark (the album
/// with the star), with a modern indigo for actions. Semantic names, so every
/// component follows light/dark automatically.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.paper,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentStrong,
    required this.onAccent,
    required this.gold,
    required this.onGold,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.skeleton,
    required this.shadow,
  });

  /// Page background.
  final Color paper;

  /// Bars and sheets.
  final Color surface;

  /// Cards and inputs.
  final Color surfaceRaised;

  /// Quiet fills: chips, image wells, segmented controls.
  final Color surfaceMuted;
  final Color ink;
  final Color muted;
  final Color line;

  /// Primary action colour (indigo).
  final Color accent;
  final Color accentStrong;
  final Color onAccent;

  /// Brand gold: ratings, auction highlights, premium badges.
  final Color gold;
  final Color onGold;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color skeleton;
  final Color shadow;

  static const light = BrandColors(
    paper: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDEFF6),
    ink: Color(0xFF0D1330),
    muted: Color(0xFF5E6680),
    line: Color(0xFFE2E5EE),
    accent: Color(0xFF4353E0),
    accentStrong: Color(0xFF2F3DBF),
    onAccent: Color(0xFFFFFFFF),
    gold: Color(0xFFE3A32B),
    onGold: Color(0xFF2A1A00),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    skeleton: Color(0xFFE6E9F2),
    shadow: Color(0x1A0D1330),
  );

  static const dark = BrandColors(
    paper: Color(0xFF090C18),
    surface: Color(0xFF0F1426),
    surfaceRaised: Color(0xFF151B31),
    surfaceMuted: Color(0xFF1C2340),
    ink: Color(0xFFEEF0FA),
    muted: Color(0xFF9BA3BF),
    line: Color(0xFF252D49),
    accent: Color(0xFF8C99FF),
    accentStrong: Color(0xFFAAB4FF),
    onAccent: Color(0xFF0A0D1A),
    gold: Color(0xFFF4C152),
    onGold: Color(0xFF2A1A00),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    skeleton: Color(0xFF1D2440),
    shadow: Color(0x66000000),
  );

  /// Deep navy → indigo used for hero panels in both themes.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E1640), Color(0xFF26338F), Color(0xFF4353E0)],
    stops: [0, 0.6, 1],
  );

  /// Bottom scrim that keeps text legible over photos.
  static const imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x99060914)],
  );

  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -6),
  ];

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
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      accent: mix(accent, other.accent),
      accentStrong: mix(accentStrong, other.accentStrong),
      onAccent: mix(onAccent, other.onAccent),
      gold: mix(gold, other.gold),
      onGold: mix(onGold, other.onGold),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      info: mix(info, other.info),
      skeleton: mix(skeleton, other.skeleton),
      shadow: mix(shadow, other.shadow),
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
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
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

abstract final class Fonts {
  static const display = 'Sora';
  static const body = 'Inter';
}

extension BrandContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
