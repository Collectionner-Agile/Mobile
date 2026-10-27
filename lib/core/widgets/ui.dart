import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import '../utils/formatters.dart';
import 'app_icons.dart';
import 'motion.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get languageCode => Localizations.localeOf(this).languageCode;
  String money(num value) => formatMoney(value, languageCode);
}

/// Quiet secondary label (counts, metadata).
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
/// "see all" pill.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.note, this.actionLabel, this.onAction});
  final String title;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter - Space.xxs, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TapScale(
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  foregroundColor: brand.ink,
                  textStyle: context.text.labelMedium,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(actionLabel!), const SizedBox(width: 2), const Icon(AppIcons.chevronRight, size: 16)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder block with a soft highlight sweeping across it. Static when
/// reduce-motion is on.
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
    final shine = Color.lerp(base, brand.surface, 0.75)!;
    return ExcludeSemantics(
      child: RepaintBoundary(
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
      ),
    );
  }
}

/// Centered message for empty, error and gated states: a soft halo around the
/// icon, a short title, an optional line and one action.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tone,
    this.actionIcon,
  });
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final color = tone ?? brand.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: context.isDark ? 0.22 : 0.16),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brand.surface,
                  border: Border.all(color: brand.line),
                  boxShadow: brand.cardShadow,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
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
            const SizedBox(height: Space.lg),
            TapScale(
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? AppIcons.arrowRight, size: 18),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
              ),
            ),
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
    icon: AppIcons.wifiOff,
    tone: context.brand.danger,
    title: describeError(error, context.l10n),
    actionLabel: context.l10n.retry,
    actionIcon: AppIcons.refreshCw,
    onAction: onRetry,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.body,
    this.icon = AppIcons.package,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final String? body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) =>
      StateMessage(icon: icon, title: message, body: body, actionLabel: actionLabel, onAction: onAction);
}

/// Renders an [AsyncValue] with consistent loading / error / data states and
/// a cross-fade between them. The data side opens a [RevealWindow], so list
/// items stagger in once when the data first arrives.
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
      child = RevealWindow(key: const ValueKey('data'), child: data(value.requireValue));
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
              child: Padding(padding: EdgeInsets.all(Space.xxl), child: CircularProgressIndicator(strokeWidth: 2.4)),
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
        : (ThemeData.estimateBrightnessForColor(color!) == Brightness.dark ? Colors.white : brand.onGold);
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
                if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: Space.xs)],
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
    final brand = context.brand;
    return Semantics(
      label: context.l10n.ratingOutOfFive(rating.toStringAsFixed(1)),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final fill = (rating - index).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(right: 1),
              child: Stack(
                children: [
                  Icon(AppIcons.star, size: size, color: brand.line),
                  ClipRect(
                    clipper: _FractionClipper(fill),
                    child: Icon(AppIcons.star, size: size, color: brand.gold),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper oldClipper) => oldClipper.fraction != fraction;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: context.isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: tone), const SizedBox(width: 4)],
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

/// Floating confirmation above the tab bar, with an icon in its tone.
void showToast(BuildContext context, String message, {bool error = false, IconData? icon}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final brand = context.brand;
  final light = !context.isDark;
  final foreground = light ? brand.onAccent : brand.ink;
  if (error) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (error ? brand.danger : brand.gold).withValues(alpha: 0.22),
              ),
              child: Icon(
                icon ?? (error ? AppIcons.circleAlert : AppIcons.circleCheck),
                color: error
                    ? (light ? const Color(0xFFFFB4B4) : brand.danger)
                    : (light ? Brand.goldLight : brand.gold),
                size: 16,
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(message, style: context.text.bodyMedium?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
}

/// Asks before a consequential action, as a bottom sheet with the decision
/// in plain words and two clear buttons.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) {
      final brand = context.brand;
      final tone = destructive ? brand.danger : brand.gold;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: 0.12)),
                child: Icon(icon ?? (destructive ? AppIcons.triangleAlert : AppIcons.circleHelp), color: tone),
              ),
              const SizedBox(height: Space.md),
              Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Space.xs),
              Text(
                body,
                style: context.text.bodyMedium?.copyWith(color: brand.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: FilledButton(
                      style: destructive
                          ? FilledButton.styleFrom(backgroundColor: brand.danger, foregroundColor: Colors.white)
                          : null,
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
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
            Icon(AppIcons.star, size: 13, color: brand.gold),
            const SizedBox(width: 3),
            Text(rating.toStringAsFixed(1), style: Fonts.figures(context.text.labelMedium).copyWith(color: brand.ink)),
          ],
        ),
      ),
    );
  }
}

/// Midnight panel for the one strong moment on a screen, with a whisper of
/// gold light in its corner.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(Space.lg)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A4D), Brand.midnight, Color(0xFF0A1020)],
        ),
        border: context.isDark ? Border.all(color: brand.line) : null,
        boxShadow: brand.floatingShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -60,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Brand.gold.withValues(alpha: 0.28), Brand.gold.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Foreground color for content inside a [HeroPanel].
Color heroForeground(BuildContext context) => Brand.ivory;

/// Search field decoration used by list screens.
InputDecoration searchDecoration(BuildContext context, String hint) {
  final brand = context.brand;
  final pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.pill),
    borderSide: BorderSide(color: brand.line),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: brand.surface,
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
      child: Icon(AppIcons.search, color: brand.muted, size: 20),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 44),
    contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 15),
    border: pill,
    enabledBorder: pill,
    focusedBorder: pill.copyWith(borderSide: BorderSide(color: brand.accent, width: 1.6)),
  );
}
