import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';

/// Three short guides (scan, bid, publish), each as numbered steps on a
/// line, ending with a button that starts doing it.
class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key, this.initial = 0});
  final int initial;

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  late int _guide = widget.initial.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final guides = [
      (
        label: l10n.navScan,
        icon: AppIcons.scanLine,
        steps: [
          (AppIcons.camera, l10n.guideScan1Title, l10n.guideScan1Body),
          (AppIcons.crop, l10n.guideScan2Title, l10n.guideScan2Body),
          (AppIcons.sparkles, l10n.guideScan3Title, l10n.guideScan3Body),
        ],
        action: l10n.openCamera,
        route: Routes.scan,
      ),
      (
        label: l10n.guideBid,
        icon: AppIcons.gavel,
        steps: [
          (AppIcons.search, l10n.guideBid1Title, l10n.guideBid1Body),
          (AppIcons.handCoins, l10n.guideBid2Title, l10n.guideBid2Body),
          (AppIcons.bellRing, l10n.guideBid3Title, l10n.guideBid3Body),
        ],
        action: l10n.navAuctions,
        route: Routes.auctions,
      ),
      (
        label: l10n.quickPublish,
        icon: AppIcons.imagePlus,
        steps: [
          (AppIcons.images, l10n.guidePublish1Title, l10n.guidePublish1Body),
          (AppIcons.fileText, l10n.guidePublish2Title, l10n.guidePublish2Body),
          (AppIcons.gavel, l10n.guidePublish3Title, l10n.guidePublish3Body),
        ],
        action: l10n.publishItem,
        route: Routes.publishCollectible,
      ),
    ];
    final guide = guides[_guide];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.howItWorksTitle)),
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
                SegmentedTabs(
                  labels: [for (final g in guides) g.label],
                  index: _guide,
                  onChanged: (index) => setState(() => _guide = index),
                ),
                const SizedBox(height: Space.xl),
                FadeSwitch(
                  child: RevealWindow(
                    key: ValueKey(_guide),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, (icon, title, body)) in guide.steps.indexed)
                          Reveal(
                            index: index,
                            child: _Step(
                              number: index + 1,
                              icon: icon,
                              title: title,
                              body: body,
                              last: index == guide.steps.length - 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.lg),
                BusyButton(label: guide.action, icon: guide.icon, onPressed: () => context.go(guide.route)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.icon, required this.title, required this.body, required this.last});
  final int number;
  final IconData icon;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Brand.goldLight, Brand.gold]),
                  ),
                  child: Text(
                    '$number',
                    style: Fonts.figures(Fonts.display(context.text.titleMedium, weight: 700))
                        .copyWith(color: const Color(0xFF1A1305)),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: Space.xxs),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [brand.gold, brand.line],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Space.lg),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.text.titleMedium),
                          const SizedBox(height: Space.xxs),
                          Text(body, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    IconBadge(icon, color: brand.gold),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
