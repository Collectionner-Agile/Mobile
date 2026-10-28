import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import 'collectible_image.dart';
import 'motion.dart';
import 'ui.dart';

/// Flat surface with a hairline edge, like the frame of a slab; [shadow]
/// lifts it for things that float. With [onTap] it presses in like a
/// physical card and ripples above its fill.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.md),
    this.radius = Radii.md,
    this.color,
    this.gradient,
    this.shadow = false,
    this.border = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final bool shadow;
  final bool border;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border ? BorderSide(color: brand.line) : BorderSide.none,
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: content,
      );
    }
    if (gradient != null) {
      content = Ink(
        decoration: BoxDecoration(gradient: gradient),
        child: content,
      );
    }
    Widget card = Material(
      color: gradient == null ? (color ?? brand.surface) : Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    if (shadow) {
      card = DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: brand.cardShadow),
        child: card,
      );
    }
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: TapScale(child: card),
    );
  }
}

/// Rounded-square chip holding an icon, tinted with its tone.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 40, this.solid = false});
  final IconData icon;
  final Color? color;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tone = color ?? brand.ink;
    final onTone = ThemeData.estimateBrightnessForColor(tone) == Brightness.dark ? Colors.white : brand.onGold;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? tone : tone.withValues(alpha: context.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(icon, size: size * 0.5, color: solid ? onTone : tone),
    );
  }
}

/// Round icon button. [onPhoto] gives it a dark translucent disc for use over
/// images (no blur, so it stays cheap while scrolling).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.onPhoto = false,
    this.size = 44,
    this.badge = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool onPhoto;
  final double size;

  /// Small live-red dot (e.g. unread notifications).
  final bool badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final background = onPhoto ? const Color(0x73000000) : brand.surface;
    final foreground = color ?? (onPhoto ? Colors.white : brand.ink);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: TapScale(
          scale: 0.92,
          child: Material(
            color: background,
            shape: CircleBorder(side: BorderSide(color: onPhoto ? const Color(0x33FFFFFF) : brand.line)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onPressed!();
                    },
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: size * 0.45, color: foreground),
                    if (badge)
                      Positioned(
                        top: size * 0.2,
                        right: size * 0.22,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: brand.live,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: background == Colors.transparent ? brand.paper : background,
                              width: 1.5,
                            ),
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

/// Grouped list in one card, with optional small caps title above it.
class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xxs, 0, Space.xxs, Space.xs),
            child: Semantics(
              header: true,
              child: Text(
                title!.toUpperCase(),
                style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: brand.muted),
              ),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) Divider(height: 1, indent: 66, color: brand.line),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row of a [MenuGroup]: tinted icon, title, optional subtitle, chevron.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tone = destructive ? brand.danger : (color ?? brand.ink);
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          child: Row(
            children: [
              IconBadge(icon, color: tone, size: 38),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(color: destructive ? brand.danger : brand.ink),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: Space.xs), trailing!],
              if (trailing == null && onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: brand.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large page title for hub screens: optional tracked eyebrow, serif title, a
/// one-line subtitle and trailing actions.
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: brand.muted),
                  ),
                  const SizedBox(height: Space.xxs),
                ],
                Semantics(header: true, child: Text(title, style: context.text.headlineLarge)),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.xxs),
                  Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: Space.xs), action],
        ],
      ),
    );
  }
}

/// Pill segmented control: an ink capsule (the same one the tab bar uses)
/// springs between segments.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged, this.icons});
  final List<String> labels;
  final List<IconData>? icons;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: brand.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.of(context, Motion.springDuration(Motion.spring)),
                curve: Motion.spring,
                left: segment * index,
                width: segment,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: brand.accent, borderRadius: BorderRadius.circular(Radii.pill)),
                ),
              ),
              Row(
                children: [
                  for (final (i, label) in labels.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          onTap: () {
                            if (i == index) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xs),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icons != null) ...[
                                    Icon(icons![i], size: 16, color: i == index ? brand.onAccent : brand.muted),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: AnimatedDefaultTextStyle(
                                      duration: Motion.of(context, Motion.fast),
                                      style: context.text.labelLarge!.copyWith(
                                        color: i == index ? brand.onAccent : brand.muted,
                                        fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
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
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Icon tile with a label under it, for the row of shortcuts on hub screens.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.highlight = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// Solid accent tile for the primary shortcut.
  final bool highlight;

  /// Small count shown on the tile's corner.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tone = color ?? brand.ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: TapScale(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: highlight ? brand.accent : brand.surface,
                        borderRadius: BorderRadius.circular(Radii.md + 2),
                        border: highlight ? null : Border.all(color: brand.line),
                      ),
                      child: Icon(icon, size: 24, color: highlight ? brand.onAccent : tone),
                    ),
                    if (badge != null && badge! > 0) Positioned(top: -4, right: -4, child: _CountBubble(count: badge!)),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  label,
                  style: context.text.labelMedium?.copyWith(color: brand.ink),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: brand.live,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: brand.paper, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: Fonts.figures(context.text.labelSmall).copyWith(color: brand.onLive, fontSize: 10.5, height: 1.2),
      ),
    );
  }
}

/// A figure with its label: serif number, quiet caption.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.icon, this.color, this.alignment});
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final CrossAxisAlignment? alignment;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: alignment ?? CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: color ?? brand.muted), const SizedBox(height: Space.xs)],
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Fonts.figures(context.text.headlineMedium).copyWith(color: brand.ink),
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
      ],
    );
  }
}

/// Small rounded label, tinted (or solid) in its tone.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.icon, this.color, this.solid = false, this.onPhoto = false});
  final String label;
  final IconData? icon;
  final Color? color;
  final bool solid;

  /// Dark translucent pill for use over images.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tone = color ?? brand.ink;
    final Color background;
    final Color foreground;
    if (onPhoto) {
      background = const Color(0x8C000000);
      foreground = Colors.white;
    } else if (solid) {
      background = tone;
      foreground = ThemeData.estimateBrightnessForColor(tone) == Brightness.dark ? Colors.white : brand.onGold;
    } else {
      background = tone.withValues(alpha: context.isDark ? 0.16 : 0.09);
      foreground = tone;
    }
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 4, 10, 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.label(context.text.labelSmall, weight: 650).copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live-red pill with a breathing dot.
class LivePill extends StatelessWidget {
  const LivePill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
      decoration: BoxDecoration(color: brand.live, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulseDot(color: Colors.white, size: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.label(context.text.labelSmall, weight: 700).copyWith(color: brand.onLive),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds once per second with the time left until [deadline]. Pauses while
/// its route or tab is not visible (TickerMode off) and stops at zero.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.deadline, required this.builder});
  final DateTime? deadline;
  final Widget Function(BuildContext context, Duration remaining) builder;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _visible = true;

  Duration _left() {
    final deadline = widget.deadline;
    if (deadline == null) return Duration.zero;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _sync() {
    _timer?.cancel();
    _remaining = _left();
    if (_visible && _remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = _left();
        if (left == Duration.zero) _timer?.cancel();
        if (mounted) setState(() => _remaining = left);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible || _timer == null) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

/// Countdown as rounded tiles whose digits roll as they change (21st.dev
/// "Animated Countdown", nexus-ui).
class CountdownTiles extends StatelessWidget {
  const CountdownTiles({super.key, required this.deadline, this.onPhoto = false, this.compact = false});
  final DateTime? deadline;
  final bool onPhoto;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Countdown(
      deadline: deadline,
      builder: (context, left) {
        final units = [
          if (left.inDays > 0) (left.inDays, l10n.unitDays),
          (left.inHours % 24, l10n.unitHours),
          (left.inMinutes % 60, l10n.unitMinutes),
          if (left.inDays == 0) (left.inSeconds % 60, l10n.unitSeconds),
        ];
        return Semantics(
          label: formatDurationLabel(left, l10n),
          // Fixed-size tiles: digits may grow a little with the user's text
          // size, never enough to push the tiles off a card.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.25,
            child: ExcludeSemantics(
              // Shrinks as a whole on very narrow cards instead of clipping.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, (value, label)) in units.indexed) ...[
                      if (i > 0) SizedBox(width: compact ? 4 : 6),
                      _TimeTile(value: value, label: label, onPhoto: onPhoto, compact: compact),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.value, required this.label, required this.onPhoto, required this.compact});
  final int value;
  final String label;
  final bool onPhoto;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final foreground = onPhoto ? Colors.white : brand.ink;
    final digits = value.toString().padLeft(2, '0');
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 40 : 52),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 5 : 8),
      decoration: BoxDecoration(
        color: onPhoto ? const Color(0x66000000) : brand.surface,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: onPhoto ? const Color(0x33FFFFFF) : brand.line),
        boxShadow: onPhoto ? null : brand.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, digit) in digits.characters.indexed)
                _RollingDigit(
                  key: ValueKey(i),
                  digit: digit,
                  style: Fonts.figures(
                    Fonts.display(compact ? context.text.titleMedium : context.text.titleLarge, weight: 700),
                  ).copyWith(color: foreground, height: 1.1),
                ),
            ],
          ),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            style: Fonts.eyebrow(context.text.labelSmall).copyWith(
              fontSize: compact ? 8.5 : 9,
              letterSpacing: 0.8,
              color: onPhoto ? const Color(0xCCFFFFFF) : brand.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RollingDigit extends StatelessWidget {
  const _RollingDigit({super.key, required this.digit, required this.style});
  final String digit;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: Motion.of(context, const Duration(milliseconds: 380)),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(digit);
        final slide = Tween<Offset>(
          begin: incoming ? const Offset(0, 0.7) : const Offset(0, -0.7),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: Text(digit, key: ValueKey(digit), style: style),
    ),
  );
}

/// Price in the serif display voice with steady figures; optionally rolls to
/// a new value.
class PriceText extends StatelessWidget {
  const PriceText(this.amount, {super.key, this.style, this.animate = false, this.color});
  final double amount;
  final TextStyle? style;
  final bool animate;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = Fonts.figures(Fonts.display(style ?? context.text.titleLarge, weight: 700))
        .copyWith(color: color ?? context.brand.ink);
    if (animate) return AnimatedNumber(value: amount, format: context.money, style: resolved);
    return Text(context.money(amount), style: resolved, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// Avatar: the photo when there is one, else the initial on an ink disc, the
/// same mark the account button shows.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.size = 40, this.ring = false});
  final String name;
  final String? url;
  final double size;

  /// Hairline ring around the avatar, for the owner of a page.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initial = name.trim().isEmpty ? '?' : String.fromCharCode(name.trim().runes.first).toUpperCase();
    final hasPhoto = url != null && url!.trim().isNotEmpty;
    final face = hasPhoto
        ? ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: CollectibleImage(url, cacheWidth: size, semanticLabel: name),
            ),
          )
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: brand.ink),
            child: Text(
              initial,
              style: Fonts.display(
                TextStyle(fontSize: size * 0.42, height: 1),
                weight: 680,
              ).copyWith(color: brand.paper),
            ),
          );
    if (!ring) {
      return Semantics(
        label: name,
        image: true,
        child: ExcludeSemantics(child: face),
      );
    }
    return Semantics(
      label: name,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: brand.paper,
            border: Border.all(color: brand.line, width: 1.5),
          ),
          child: face,
        ),
      ),
    );
  }
}

/// Sticky action bar at the foot of detail screens.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(top: BorderSide(color: brand.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.sm),
        child: child,
      ),
    );
  }
}

/// Circular progress that sweeps to [value] (0–1) when it appears.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 56, this.stroke = 5, this.color, this.child});
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Motion.of(context, const Duration(milliseconds: 1200)),
      curve: Motion.enter,
      builder: (context, progress, child) => CustomPaint(
        painter: _RingPainter(progress: progress, color: color ?? brand.ink, track: brand.surfaceMuted, stroke: stroke),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.track, required this.stroke});
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(inner, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(inner, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

/// Smooth area chart that draws itself in (21st.dev "Balance Chart"): the
/// line follows the values, a soft gradient fills below it and the last
/// point glows.
class AreaChart extends StatelessWidget {
  const AreaChart({super.key, required this.values, this.color, this.height = 150});
  final List<double> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.brand.ink;
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 1400)),
        curve: Motion.enter,
        builder: (context, progress, _) => CustomPaint(
          size: Size.infinite,
          painter: _AreaPainter(values: values, progress: progress, color: tone, grid: context.brand.line),
        ),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  const _AreaPainter({required this.values, required this.progress, required this.color, required this.grid});
  final List<double> values;
  final double progress;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0) return;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = (high - low).abs() < 1e-9 ? 1.0 : high - low;
    const top = 12.0;
    final bottom = size.height - 6;
    Offset point(int i) =>
        Offset(size.width * i / (values.length - 1), bottom - (values[i] - low) / span * (bottom - top));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + (bottom - top) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final p0 = point(math.max(0, i - 1));
      final p1 = point(i);
      final p2 = point(i + 1);
      final p3 = point(math.min(values.length - 1, i + 2));
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    if (progress <= 0.01) return;
    final metric = line.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    final end = metric.getTangentForOffset(metric.length * progress)?.position ?? point(values.length - 1);

    final fill = Path.from(drawn)
      ..lineTo(end.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas
      ..drawCircle(end, 9, Paint()..color = color.withValues(alpha: 0.18))
      ..drawCircle(end, 4.5, Paint()..color = color)
      ..drawCircle(end, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.progress != progress || old.color != color || old.values != values || old.grid != grid;
}

/// Page position dots: the current one stretches into a pill.
class DotsIndicator extends StatelessWidget {
  const DotsIndicator({super.key, required this.count, required this.index, this.onPhoto = false});
  final int count;
  final int index;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final active = onPhoto ? Colors.white : brand.accent;
    final idle = onPhoto ? const Color(0x80FFFFFF) : brand.line;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.of(context, Motion.springDuration(Motion.spring)),
            curve: Motion.spring,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index ? active : idle,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
      ],
    );
  }
}

/// Faint shading painted behind a hero area so it reads as a lit case rather
/// than a flat page. Radial gradients only: no blur filter.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key, required this.child, this.colors});
  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tones = colors ?? [brand.surface, brand.surfaceMuted, brand.surface];
    return CustomPaint(painter: _GlowPainter(tones, context.isDark ? 0.5 : 0.9), child: child);
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.colors, this.strength);
  final List<Color> colors;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      (Offset(size.width * 0.1, size.height * 0.1), size.width * 0.7),
      (Offset(size.width * 0.95, size.height * 0.3), size.width * 0.6),
      (Offset(size.width * 0.5, size.height * 1.05), size.width * 0.75),
    ];
    for (final (i, (center, radius)) in spots.indexed) {
      final color = colors[i % colors.length];
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.strength != strength || old.colors != colors;
}

/// A soft highlight that sweeps across [child] every [period] (logo shine).
class ShineSweep extends StatefulWidget {
  const ShineSweep({super.key, required this.child, this.period = const Duration(milliseconds: 2600)});
  final Widget child;
  final Duration period;

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeInOut.transform((_controller.value * 1.6).clamp(0.0, 1.0));
      return ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.6 + 3.2 * t, -0.6),
          end: Alignment(-0.6 + 3.2 * t, 0.6),
          colors: const [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
        ).createShader(bounds),
        child: child,
      );
    },
  );
}

/// Accessible text for a remaining time, e.g. "2 días 4 h 10 min".
String formatDurationLabel(Duration left, AppLocalizations l10n) {
  final days = left.inDays;
  final hours = left.inHours % 24;
  final minutes = left.inMinutes % 60;
  return [if (days > 0) '$days ${l10n.unitDays}', '$hours ${l10n.unitHours}', '$minutes ${l10n.unitMinutes}'].join(' ');
}
