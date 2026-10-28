import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../utils/formatters.dart';
import 'motion.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get languageCode => Localizations.localeOf(this).languageCode;
  String money(num value) => formatMoney(value, languageCode);
}

/// Condensed secondary label (counts, metadata). Never sits above a heading.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Fonts.label(context.text.labelMedium).copyWith(color: color ?? context.brand.muted),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

/// Section title with an optional one-line note under it and a trailing
/// text action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.note, this.actionLabel, this.onAction});
  final String title;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.xs, Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: context.text.bodySmall?.copyWith(color: context.brand.muted)),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Animated pulse used for skeleton loaders. Static when reduce-motion is on.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = Radii.xs});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
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
    final brand = context.brand;
    final base = brand.skeleton;
    final shine = Color.lerp(base, brand.surface, 0.7)!;
    // A soft highlight sweeps across the block (static when motion is reduced).
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 - 0.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + 2 * t - 0.6, -0.2),
                end: Alignment(-1 + 2 * t + 0.6, 0.2),
                colors: [base, shine, base],
              ),
            ),
          );
        },
      ),
    );
  }
}

class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: brand.line),
              color: brand.surfaceRaised,
            ),
            child: Icon(icon, color: tone ?? brand.muted),
          ),
          const SizedBox(height: Space.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              body!,
              style: context.text.bodyMedium?.copyWith(color: brand.muted),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StateMessage(
    icon: Icons.cloud_off_outlined,
    tone: context.brand.danger,
    title: describeError(error, context.l10n),
    actionLabel: context.l10n.retry,
    onAction: onRetry,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.body,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String message;

  /// One line under the title saying what will show up here.
  final String? body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) =>
      StateMessage(icon: icon, title: message, body: body, actionLabel: actionLabel, onAction: onAction);
}

/// Renders an [AsyncValue] with consistent loading / error / data states and
/// a cross-fade between them.
class AsyncSwitch<T> extends StatelessWidget {
  const AsyncSwitch({super.key, required this.value, required this.data, required this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (value.hasValue) {
      child = KeyedSubtree(key: const ValueKey('data'), child: data(value.requireValue));
    } else if (value.hasError) {
      child = KeyedSubtree(
        key: const ValueKey('error'),
        child: ErrorState(error: value.error!, onRetry: onRetry),
      );
    } else {
      child = KeyedSubtree(
        key: const ValueKey('loading'),
        child:
            loading ??
            const Center(
              child: Padding(padding: EdgeInsets.all(Space.xxl), child: CircularProgressIndicator()),
            ),
      );
    }
    return AnimatedSwitcher(duration: Motion.of(context, Motion.base), child: child);
  }
}

/// Primary action that shows progress and blocks double submission.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.outlined = false,
    this.color,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool outlined;

  /// Background override for the filled variant (e.g. live red for bids).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final onColor = color == null
        ? brand.onAccent
        : (ThemeData.estimateBrightnessForColor(color!) == Brightness.dark ? Colors.white : brand.ink);
    final child = AnimatedSwitcher(
      duration: Motion.of(context, Motion.fast),
      child: busy
          ? SizedBox(
              key: const ValueKey('busy'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: outlined ? brand.ink : onColor),
            )
          : Row(
              key: const ValueKey('idle'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: Space.xs)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
              ],
            ),
    );
    final action = busy || onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };
    return Semantics(
      button: true,
      label: busy ? null : label,
      liveRegion: busy,
      child: TapScale(
        child: outlined
            ? OutlinedButton(onPressed: action, child: child)
            : FilledButton(
                onPressed: action,
                style: color == null ? null : FilledButton.styleFrom(backgroundColor: color, foregroundColor: onColor),
                child: child,
              ),
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.brand.accent;
    return Semantics(
      label: context.l10n.ratingOutOfFive(rating.toStringAsFixed(1)),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final fill = (rating - index).clamp(0.0, 1.0);
            final icon = fill >= 0.75
                ? Icons.star_rounded
                : fill >= 0.25
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded;
            return Icon(icon, size: size, color: color);
          }),
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.brand.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tone.withValues(alpha: 0.08), context.brand.surfaceRaised),
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: tone), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: tone),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false, IconData? icon}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final brand = context.brand;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (error ? Icons.error_outline : Icons.check_circle_outline),
              color: context.isDark ? brand.ink : brand.paper,
              size: 20,
            ),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: context.brand.danger) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Constrains content width on tablets / landscape so lines stay readable.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Compact star rating used in metadata lines.
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      label: context.l10n.ratingOutOfFive(rating.toStringAsFixed(1)),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: brand.gold),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1), style: Fonts.figures(context.text.labelMedium).copyWith(color: brand.ink)),
          ],
        ),
      ),
    );
  }
}

/// Solid ink panel for the one strong moment on a screen. No gradient, no glow.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(Space.lg)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? brand.surfaceRaised : brand.ink,
        borderRadius: BorderRadius.circular(Radii.md),
        border: dark ? Border.all(color: brand.line) : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Foreground color for content inside a [HeroPanel].
Color heroForeground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? context.brand.ink : context.brand.paper;

/// Search field decoration used by list screens used by list screens.
InputDecoration searchDecoration(BuildContext context, String hint) {
  final brand = context.brand;
  final pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.sm),
    borderSide: BorderSide(color: brand.line),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: brand.surfaceRaised,
    prefixIcon: Icon(Icons.search_rounded, color: brand.muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
    border: pill,
    enabledBorder: pill,
    focusedBorder: pill.copyWith(borderSide: BorderSide(color: brand.accent, width: 1.6)),
  );
}
