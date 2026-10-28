import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';

/// Theme and language, chosen by looking: each theme is a small live
/// mock-up of the app, each language a card. Changes apply at once.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearance)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.themeTitle, style: context.text.titleLarge),
                const SizedBox(height: Space.xxs),
                Text(l10n.themeBody, style: context.text.bodySmall),
                const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, (mode, label)) in [
                      (ThemeMode.light, l10n.themeLight),
                      (ThemeMode.dark, l10n.themeDark),
                      (ThemeMode.system, l10n.themeSystem),
                    ].indexed) ...[
                      if (index > 0) const SizedBox(width: Space.sm),
                      Expanded(
                        child: Reveal(
                          index: index,
                          child: _ThemeOption(
                            mode: mode,
                            label: label,
                            selected: theme == mode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(themeModeProvider.notifier).set(mode);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Space.xl),
                Text(l10n.language, style: context.text.titleLarge),
                const SizedBox(height: Space.md),
                for (final (index, (code, label, note)) in [
                  ('es', 'Español', 'Perú'),
                  ('en', 'English', 'International'),
                  (null, l10n.languageSystem, l10n.languageSystemNote),
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Reveal(
                      index: index + 3,
                      child: _LanguageOption(
                        code: code,
                        label: label,
                        note: note,
                        selected: locale?.languageCode == code,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(localeProvider.notifier).set(code == null ? null : Locale(code));
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.mode, required this.label, required this.selected, required this.onTap});
  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final preview = switch (mode) {
      ThemeMode.light => const _MiniApp(colors: BrandColors.light),
      ThemeMode.dark => const _MiniApp(colors: BrandColors.dark),
      ThemeMode.system => const Row(
        children: [
          Expanded(child: _MiniApp(colors: BrandColors.light, clipRight: true)),
          Expanded(child: _MiniApp(colors: BrandColors.dark, clipLeft: true)),
        ],
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: TapScale(
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              AnimatedContainer(
                duration: Motion.of(context, Motion.base),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: selected ? brand.gold : brand.line, width: selected ? 2 : 1),
                  boxShadow: selected ? brand.cardShadow : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: AspectRatio(aspectRatio: 0.62, child: preview),
                ),
              ),
              const SizedBox(height: Space.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: selected
                        ? Icon(AppIcons.circleCheck, key: const ValueKey('on'), size: 16, color: brand.gold)
                        : Icon(AppIcons.circleCheck, key: const ValueKey('off'), size: 16, color: brand.line),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(label, style: context.text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tiny drawing of the app in the given colours: header, a card with a
/// photo and price, and the floating tab bar.
class _MiniApp extends StatelessWidget {
  const _MiniApp({required this.colors, this.clipLeft = false, this.clipRight = false});
  final BrandColors colors;
  final bool clipLeft;
  final bool clipRight;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, Color color, {double height = 5}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
    return ColoredBox(
      color: colors.paper,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.gold),
                ),
                const SizedBox(width: 4),
                Expanded(child: bar(double.infinity, colors.ink.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.line),
                ),
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(colors: [colors.surfaceMuted, colors.gold.withValues(alpha: 0.4)]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    bar(36, colors.ink.withValues(alpha: 0.75)),
                    const SizedBox(height: 3),
                    bar(22, colors.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.line),
              ),
              // Each mark takes a share of the width, so the half-size
              // previews of the "system" option still fit.
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      flex: i == 0 ? 2 : 1,
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: i == 0 ? 0.8 : 0.45,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == 0 ? colors.accent : colors.muted.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.note,
    required this.selected,
    required this.onTap,
  });
  final String? code;
  final String label;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      selected: selected,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        color: selected ? Color.alphaBlend(brand.gold.withValues(alpha: 0.08), brand.surface) : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? brand.gold : brand.surfaceMuted),
              child: code == null
                  ? Icon(AppIcons.smartphone, size: 18, color: selected ? brand.onGold : brand.ink)
                  : Text(
                      code!.toUpperCase(),
                      style: Fonts.label(
                        context.text.labelLarge,
                        weight: 700,
                      ).copyWith(color: selected ? brand.onGold : brand.ink),
                    ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.titleSmall),
                  Text(note, style: context.text.bodySmall),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: selected
                  ? Icon(AppIcons.circleCheck, key: const ValueKey('on'), color: brand.gold)
                  : const SizedBox(key: ValueKey('off'), width: 24),
            ),
          ],
        ),
      ),
    );
  }
}
