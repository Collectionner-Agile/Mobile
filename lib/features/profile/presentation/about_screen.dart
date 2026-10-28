import 'package:flutter/material.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import 'settings_screen.dart' show appVersion;

/// About the app: the mark and version, what is new in this version, how
/// your data is treated, and the credits.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final news = [
      (AppIcons.palette, l10n.whatsNewDesign),
      (AppIcons.camera, l10n.whatsNewCamera),
      (AppIcons.bell, l10n.whatsNewNotices),
      (AppIcons.calendarDays, l10n.whatsNewCalendar),
      (AppIcons.trophy, l10n.whatsNewAchievements),
      (AppIcons.sparkles, l10n.whatsNewMotion),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
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
                Reveal(
                  child: HeroPanel(
                    child: Column(
                      children: [
                        ShineSweep(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/branding/site-icon-512.png',
                              width: 88,
                              height: 88,
                              cacheWidth: 264,
                              semanticLabel: l10n.appName,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Text(
                          l10n.appName,
                          style: Fonts.display(context.text.headlineLarge, weight: 660).copyWith(color: Brand.ivory),
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          l10n.launchTagline,
                          style: Fonts.eyebrow(context.text.labelSmall).copyWith(color: Brand.gold, letterSpacing: 2),
                        ),
                        const SizedBox(height: Space.md),
                        Tag(
                          AppConfig.demoMode
                              ? '${l10n.versionLabel(appVersion)} · ${l10n.demoBadge}'
                              : l10n.versionLabel(appVersion),
                          onPhoto: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text(l10n.whatsNewTitle, style: context.text.titleLarge),
                const SizedBox(height: Space.sm),
                AppCard(
                  child: Column(
                    children: [
                      for (final (index, (icon, text)) in news.indexed)
                        Reveal(
                          index: index + 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: Space.xs),
                            child: Row(
                              children: [
                                IconBadge(icon, color: brand.gold, size: 36),
                                const SizedBox(width: Space.sm),
                                Expanded(child: Text(text, style: context.text.bodyMedium)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text(l10n.privacyTitle, style: context.text.titleLarge),
                const SizedBox(height: Space.sm),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(AppIcons.shieldCheck, color: brand.success, size: 36),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.privacySummary, style: context.text.bodyMedium),
                            const SizedBox(height: Space.xs),
                            Text(
                              AppConfig.demoMode ? l10n.demoServerLabel : l10n.serverLabel(AppConfig.apiBaseUrl),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.xl),
                Text(l10n.creditsTitle, style: context.text.titleLarge),
                const SizedBox(height: Space.sm),
                MenuGroup(
                  children: [
                    MenuTile(icon: AppIcons.swatchBook, title: l10n.creditsDesign, subtitle: '21st.dev'),
                    MenuTile(icon: AppIcons.stars, title: l10n.creditsIcons, subtitle: 'Lucide · ISC'),
                    MenuTile(
                      icon: AppIcons.bookOpen,
                      title: l10n.creditsFonts,
                      subtitle: 'Fraunces · Archivo · SIL OFL',
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Text(l10n.aboutFooter, textAlign: TextAlign.center, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
