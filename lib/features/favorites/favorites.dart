import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/ui.dart';

/// Pieces the user saved, kept on the device (no account needed).
final favoritesProvider = NotifierProvider<FavoritesController, Set<int>>(FavoritesController.new);

class FavoritesController extends Notifier<Set<int>> {
  static const _key = 'pref.favorites';

  @override
  Set<int> build() =>
      (ref.read(sharedPreferencesProvider).getStringList(_key) ?? const []).map(int.tryParse).whereType<int>().toSet();

  Future<void> toggle(int id) async {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    await ref.read(sharedPreferencesProvider).setStringList(_key, [for (final id in state) '$id']);
  }
}

/// Heart toggle with a pop and a burst of sparks when a piece is saved
/// ("Like Burst" reference). Sits on photos, so it draws its own glass disc.
class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({super.key, required this.id, this.size = 40, this.onPhoto = true});
  final int id;
  final double size;

  /// Glass disc for use over images; plain icon elsewhere.
  final bool onPhoto;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.35, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.92, end: 1).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 40,
    ),
  ]).animate(_burst);

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _toggle() {
    final saving = !ref.read(favoritesProvider).contains(widget.id);
    ref.read(favoritesProvider.notifier).toggle(widget.id);
    HapticFeedback.lightImpact();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (saving && !reduce) _burst.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final saved = ref.watch(favoritesProvider).contains(widget.id);
    final idle = widget.onPhoto ? Colors.white : brand.ink;
    final icon = AnimatedBuilder(
      animation: _burst,
      builder: (context, _) => SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _SparksPainter(progress: _burst.value, color: brand.live),
          child: Center(
            child: Transform.scale(
              scale: _burst.isAnimating ? _pop.value : 1,
              child: Icon(
                // Lucide has no filled heart; Material's rounded one matches its shape.
                saved ? Icons.favorite_rounded : AppIcons.heart,
                size: widget.size * (saved ? 0.5 : 0.45),
                color: saved ? brand.live : idle,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      toggled: saved,
      label: saved ? l10n.removeFavorite : l10n.addFavorite,
      child: Tooltip(
        message: saved ? l10n.removeFavorite : l10n.addFavorite,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: widget.onPhoto
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x40FFFFFF)),
                  ),
                  child: icon,
                )
              : icon,
        ),
      ),
    );
  }
}

class _SparksPainter extends CustomPainter {
  const _SparksPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final t = Curves.easeOut.transform(progress);
    final radius = size.width * (0.28 + 0.42 * t);
    final paint = Paint()..color = color.withValues(alpha: (1 - progress).clamp(0, 1));
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      final dot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(dot, 2.6 * (1 - t) + 0.8, paint);
    }
    final ring = Paint()
      ..color = color.withValues(alpha: 0.35 * (1 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size.width * (0.2 + 0.32 * t), ring);
  }

  @override
  bool shouldRepaint(_SparksPainter oldDelegate) => oldDelegate.progress != progress;
}
