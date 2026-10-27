import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// "Vitrina": the app dresses like the display case of a collection. Warm
/// ivory paper and midnight-navy ink in light mode, midnight with ivory text
/// in dark mode, and the champagne gold of the app icon for the few moments
/// that deserve it. Red is reserved for what is live (auctions, bids).
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
    required this.live,
    required this.onLive,
    required this.gold,
    required this.goldSoft,
    required this.onGold,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.skeleton,
    required this.shadow,
  });

  /// Page ground.
  final Color paper;

  /// Cards, bars and sheets.
  final Color surface;

  /// Inputs and panels raised above a card.
  final Color surfaceRaised;

  /// Image wells and quiet fills.
  final Color surfaceMuted;
  final Color ink;
  final Color muted;
  final Color line;

  /// Primary actions: navy on ivory, gold on midnight.
  final Color accent;
  final Color accentStrong;
  final Color onAccent;

  /// Live auctions, bids and countdowns. Nothing else.
  final Color live;
  final Color onLive;

  /// Champagne gold: highlights, achievements, ratings.
  final Color gold;

  /// Gold-tinted fill behind gold icons.
  final Color goldSoft;
  final Color onGold;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color skeleton;
  final Color shadow;

  static const light = BrandColors(
    paper: Color(0xFFF5F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFECE9E2),
    ink: Color(0xFF121826),
    muted: Color(0xFF686F80),
    line: Color(0xFFE5E1D8),
    accent: Color(0xFF14213D),
    accentStrong: Color(0xFF0B1428),
    onAccent: Color(0xFFFFFFFF),
    live: Color(0xFFE5484D),
    onLive: Color(0xFFFFFFFF),
    gold: Color(0xFFB4842F),
    goldSoft: Color(0xFFF5ECDA),
    onGold: Color(0xFF241A06),
    success: Color(0xFF1C9A60),
    warning: Color(0xFFBF7212),
    danger: Color(0xFFD63636),
    info: Color(0xFF2F5BD3),
    skeleton: Color(0xFFEAE7E0),
    shadow: Color(0x1F14213D),
  );

  static const dark = BrandColors(
    paper: Color(0xFF080C15),
    surface: Color(0xFF0F1729),
    surfaceRaised: Color(0xFF152038),
    surfaceMuted: Color(0xFF1A2540),
    ink: Color(0xFFF3EFE6),
    muted: Color(0xFF98A1B5),
    line: Color(0xFF222D45),
    accent: Color(0xFFE3BC67),
    accentStrong: Color(0xFFF0CD80),
    onAccent: Color(0xFF1A1305),
    live: Color(0xFFFF6B6E),
    onLive: Color(0xFF1A0004),
    gold: Color(0xFFE3BC67),
    goldSoft: Color(0xFF2A2414),
    onGold: Color(0xFF1A1305),
    success: Color(0xFF43D18A),
    warning: Color(0xFFF2B33D),
    danger: Color(0xFFFF6B6B),
    info: Color(0xFF85A8FF),
    skeleton: Color(0xFF16203A),
    shadow: Color(0x80000000),
  );

  /// Bottom scrim that keeps text legible over photos.
  static const imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 1],
    colors: [Color(0x00000000), Color(0xB3000000)],
  );

  /// Soft two-layer shadow: a wide ambient glow and a tight contact shadow.
  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -10),
    BoxShadow(color: shadow.withValues(alpha: shadow.a * 0.5), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  List<BoxShadow> get floatingShadow => [
    BoxShadow(color: shadow.withValues(alpha: math.min(1, shadow.a * 1.6)), blurRadius: 36, offset: const Offset(0, 16), spreadRadius: -8),
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
      live: mix(live, other.live),
      onLive: mix(onLive, other.onLive),
      gold: mix(gold, other.gold),
      goldSoft: mix(goldSoft, other.goldSoft),
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

/// Colors that do not follow the theme: the launch and farewell scenes are
/// always midnight, like the native splash.
abstract final class Brand {
  static const midnight = Color(0xFF0B1222);
  static const midnightDeep = Color(0xFF060A14);
  static const gold = Color(0xFFDDB563);
  static const goldLight = Color(0xFFF3DCA2);
  static const ivory = Color(0xFFF5F1E7);
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

  /// Room the floating tab bar takes at the bottom of a tab's scroll view.
  static const double navClearance = 104;
}

abstract final class Radii {
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// A curve that follows a damped spring from 0 to 1, so implicit animations
/// (AnimatedContainer, AnimatedScale…) can move like the springs in the
/// 21st.dev references without an explicit physics controller.
class SpringCurve extends Curve {
  const SpringCurve({this.stiffness = 350, this.damping = 32, this.mass = 1});
  final double stiffness;
  final double damping;
  final double mass;

  /// Seconds the spring needs to settle; implicit animations using this curve
  /// should run for about this long (see [Motion.springDuration]).
  double get settleSeconds {
    final ratio = damping / (2 * math.sqrt(stiffness * mass));
    final omega = math.sqrt(stiffness / mass);
    // Time for the envelope to decay below 0.5 %.
    return (5.3 / (ratio.clamp(0.2, 1.0) * omega)).clamp(0.2, 1.4);
  }

  @override
  double transformInternal(double t) {
    final simulation = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0,
      1,
      0,
    );
    return simulation.x(t * settleSeconds);
  }
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration slower = Duration(milliseconds: 620);

  /// Emphasized decelerate: things arriving.
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);

  /// Emphasized accelerate: things leaving.
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// 21st.dev bottom-nav label spring (stiffness 350, damping 32).
  static const SpringCurve spring = SpringCurve();

  /// 21st.dev bottom-nav entrance spring (stiffness 300, damping 26): a hint
  /// of overshoot.
  static const SpringCurve bouncy = SpringCurve(stiffness: 300, damping: 26);

  static Duration springDuration(SpringCurve curve) =>
      Duration(milliseconds: (curve.settleSeconds * 1000).round());

  /// Honors the platform "remove animations" accessibility setting.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Two voices: Fraunces, a soft editorial serif (auction-catalogue feel), for
/// big titles, prices and figures; Archivo for everything you read or tap.
abstract final class Fonts {
  static const family = 'Archivo';
  static const displayFamily = 'Fraunces';

  /// Archivo axes (width 62–125, weight 100–900).
  static List<FontVariation> axes({required double width, required double weight}) => [
    FontVariation('wdth', width),
    FontVariation('wght', weight),
  ];

  /// Fraunces display voice. [weight] keeps the 100–900 scale; it is eased
  /// down because the serif reads heavier than the sans. Optical size follows
  /// the font size so small and large titles both stay crisp.
  static TextStyle display(TextStyle? base, {double weight = 700}) {
    final style = base ?? const TextStyle();
    final size = style.fontSize ?? 24;
    return style.copyWith(
      fontFamily: displayFamily,
      fontVariations: [
        FontVariation('wght', (weight * 0.8).clamp(380, 720)),
        FontVariation('opsz', size.clamp(9, 144)),
        const FontVariation('SOFT', 100),
        const FontVariation('WONK', 0),
      ],
    );
  }

  /// Nearest [FontWeight]; Flutter maps it onto the variable fonts' `wght`
  /// axis, so later `copyWith(fontWeight: …)` calls keep working.
  static FontWeight weightOf(double weight) => FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];

  /// Archivo at a given weight.
  static TextStyle sans(TextStyle? base, {double weight = 500}) =>
      (base ?? const TextStyle()).copyWith(fontFamily: family, fontWeight: weightOf(weight));

  /// Small labels: a touch heavier and tracked.
  static TextStyle label(TextStyle? base, {double weight = 620}) =>
      (base ?? const TextStyle()).copyWith(fontFamily: family, fontWeight: weightOf(weight), letterSpacing: 0.3);

  /// Uppercase eyebrow above a title.
  static TextStyle eyebrow(TextStyle? base) =>
      label(base, weight: 680).copyWith(letterSpacing: 1.4, fontSize: 11);

  /// Figures that do not jump while a countdown or bid changes.
  static TextStyle figures(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

extension BrandContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
