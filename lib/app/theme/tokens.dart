import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// "Slab": the visual language of a graded collectible. A cool grey ground
/// like a case on a desk, black ink for structure and actions, and one
/// lacquer red reserved for what is live (auctions, bids, countdowns).
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

  /// Bars, sheets and slab labels.
  final Color surface;

  /// Inputs and raised panels.
  final Color surfaceRaised;

  /// Image wells (the inside of the slab).
  final Color surfaceMuted;
  final Color ink;
  final Color muted;
  final Color line;

  /// Primary actions and selection: ink, so the red stays meaningful.
  final Color accent;
  final Color accentStrong;
  final Color onAccent;

  /// Lacquer red: live auctions, bids, countdowns. Nothing else.
  final Color live;
  final Color onLive;

  /// Ratings and earned badges.
  final Color gold;

  /// Quiet fill behind gold marks.
  final Color goldSoft;
  final Color onGold;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color skeleton;
  final Color shadow;

  static const light = BrandColors(
    paper: Color(0xFFF1F2F4),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE4E6EA),
    ink: Color(0xFF0F1012),
    muted: Color(0xFF5B616B),
    line: Color(0xFFD5D8DE),
    accent: Color(0xFF0F1012),
    accentStrong: Color(0xFF000000),
    onAccent: Color(0xFFFFFFFF),
    live: Color(0xFFD42A3A),
    onLive: Color(0xFFFFFFFF),
    gold: Color(0xFFB7791F),
    goldSoft: Color(0xFFF4EBDD),
    onGold: Color(0xFF241500),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFC81E1E),
    info: Color(0xFF1D4ED8),
    skeleton: Color(0xFFE2E4E8),
    shadow: Color(0x140F1012),
  );

  static const dark = BrandColors(
    paper: Color(0xFF0E0F11),
    surface: Color(0xFF17181B),
    surfaceRaised: Color(0xFF1C1E22),
    surfaceMuted: Color(0xFF23262B),
    ink: Color(0xFFF2F3F5),
    muted: Color(0xFF9AA0AA),
    line: Color(0xFF2E3137),
    accent: Color(0xFFF2F3F5),
    accentStrong: Color(0xFFFFFFFF),
    onAccent: Color(0xFF0E0F11),
    live: Color(0xFFFF5263),
    onLive: Color(0xFF1A0004),
    gold: Color(0xFFF2C14E),
    goldSoft: Color(0xFF2A2416),
    onGold: Color(0xFF241500),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFF6B6B),
    info: Color(0xFF7CA8FF),
    skeleton: Color(0xFF24272C),
    shadow: Color(0x66000000),
  );

  /// Bottom scrim that keeps text legible over photos.
  static const imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xA6000000)],
  );

  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -4),
  ];

  /// Deeper shadow for things that float above the page (bars, sheets).
  List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: shadow.withValues(alpha: math.min(1, shadow.a * 1.8)),
      blurRadius: 28,
      offset: const Offset(0, 10),
      spreadRadius: -6,
    ),
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

/// Colors that do not follow the theme: the launch and farewell scenes, the
/// camera and photo viewers always sit on the dark slab.
abstract final class Brand {
  static const ink = Color(0xFF0F1012);
  static const inkDeep = Color(0xFF08090A);
  static const chalk = Color(0xFFF2F3F5);
  static const live = Color(0xFFFF5263);
  static const gold = Color(0xFFF2C14E);
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
  static const double navClearance = 96;
}

abstract final class Radii {
  static const double xs = 4;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// A curve that follows a damped spring from 0 to 1, so implicit animations
/// (AnimatedContainer, AnimatedScale…) can settle like a physical object
/// without an explicit physics controller.
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
    final simulation = SpringSimulation(SpringDescription(mass: mass, stiffness: stiffness, damping: damping), 0, 1, 0);
    return simulation.x(t * settleSeconds);
  }
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration slower = Duration(milliseconds: 560);
  static const Curve enter = Cubic(0.16, 1, 0.3, 1);
  static const Curve exit = Cubic(0.4, 0, 1, 1);
  static const Curve standard = Cubic(0.2, 0.6, 0.2, 1);

  /// Settles without bouncing: selection capsules, sheets.
  static const SpringCurve spring = SpringCurve();

  /// A hint of overshoot for things that pop in.
  static const SpringCurve bouncy = SpringCurve(stiffness: 300, damping: 26);

  static Duration springDuration(SpringCurve curve) => Duration(milliseconds: (curve.settleSeconds * 1000).round());

  /// Honors the platform "remove animations" accessibility setting.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Two voices: Fraunces, a soft editorial serif (auction-catalogue feel), for
/// titles, prices and figures; Archivo at its normal width for everything you
/// read or tap.
abstract final class Fonts {
  static const family = 'Archivo';
  static const displayFamily = 'Fraunces';

  /// Archivo axes (width 62–125, weight 100–900).
  static List<FontVariation> axes({required double width, required double weight}) => [
    FontVariation('wdth', width),
    FontVariation('wght', weight),
  ];

  /// Fraunces display voice. [weight] keeps the 100–900 scale callers already
  /// use; it is eased down because the serif reads heavier than the sans.
  /// Optical size follows the font size so small and large titles both stay
  /// crisp.
  static TextStyle display(TextStyle? base, {double weight = 760}) {
    final style = base ?? const TextStyle();
    final size = style.fontSize ?? 24;
    return style.copyWith(
      fontFamily: displayFamily,
      fontVariations: [
        FontVariation('wght', (weight * 0.8).clamp(420, 720)),
        FontVariation('opsz', size.clamp(9, 144)),
        const FontVariation('SOFT', 50),
        const FontVariation('WONK', 0),
      ],
    );
  }

  /// Nearest [FontWeight] for a 100–900 weight.
  static FontWeight weightOf(double weight) => FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];

  /// Archivo at a given weight.
  static TextStyle sans(TextStyle? base, {double weight = 500}) => (base ?? const TextStyle()).copyWith(
    fontFamily: family,
    fontWeight: weightOf(weight),
    fontVariations: axes(width: 100, weight: weight),
  );

  /// Small labels: Archivo at normal width, a touch heavier and tracked.
  static TextStyle label(TextStyle? base, {double weight = 620}) => (base ?? const TextStyle()).copyWith(
    fontFamily: family,
    fontVariations: axes(width: 100, weight: weight),
    letterSpacing: 0.25,
  );

  /// Small tracked line above a title.
  static TextStyle eyebrow(TextStyle? base) => label(base, weight: 700).copyWith(letterSpacing: 1.2, fontSize: 11);

  /// Figures that do not jump while a countdown or bid changes.
  static TextStyle figures(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

extension BrandContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
