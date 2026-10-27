import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/preferences.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';

/// First-run introduction on the same midnight stage as the launch scene
/// (21st.dev "Onboarding / Welcome Screen"): one photo, one idea and one
/// button per page, with the photo drifting as you swipe.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _pagesData = [
    ('assets/images/collectibles/records/star-destroyer-model.webp', AppIcons.gem),
    ('assets/images/collectibles/records/vintage-yellow-chronograph.webp', AppIcons.gavel),
    ('assets/images/collectibles/records/yellow-handheld-set.webp', AppIcons.scanLine),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({String? then}) async {
    await ref.read(onboardedProvider.notifier).complete();
    if (!mounted) return;
    context.go(Routes.home);
    if (then != null) unawaited(context.push(then));
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index == _pagesData.length - 1) {
      _finish();
    } else {
      _pages.nextPage(duration: Motion.of(context, Motion.slow), curve: Motion.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final copy = [
      (l10n.onboardingTitle1, l10n.onboardingBody1),
      (l10n.onboardingTitle2, l10n.onboardingBody2),
      (l10n.onboardingTitle3, l10n.onboardingBody3),
    ];
    final last = _index == _pagesData.length - 1;
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Brand.midnight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [Color(0xFF16244A), Brand.midnight, Brand.midnightDeep],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.xs, 0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          'assets/branding/site-icon-512.png',
                          width: 32,
                          height: 32,
                          cacheWidth: 96,
                          semanticLabel: l10n.appName,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          l10n.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fonts.display(context.text.titleMedium, weight: 660).copyWith(color: Brand.ivory),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: last ? 0 : 1,
                        duration: Motion.of(context, Motion.base),
                        child: TextButton(
                          onPressed: last ? null : _finish,
                          style: TextButton.styleFrom(foregroundColor: const Color(0xCCF5F1E7)),
                          child: Text(l10n.onboardingSkip),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _pagesData.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) => _Page(
                      controller: _pages,
                      index: index,
                      image: _pagesData[index].$1,
                      icon: _pagesData[index].$2,
                      title: copy[index].$1,
                      body: copy[index].$2,
                    ),
                  ),
                ),
                DotsIndicator(count: _pagesData.length, index: _index, onPhoto: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.md),
                  child: ContentWidth(
                    maxWidth: 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TapScale(
                          child: FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              backgroundColor: Brand.gold,
                              foregroundColor: const Color(0xFF1A1305),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: AnimatedSwitcher(
                                    duration: Motion.of(context, Motion.fast),
                                    child: Text(
                                      last ? l10n.onboardingStart : l10n.onboardingNext,
                                      key: ValueKey(last),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                                const Icon(AppIcons.arrowRight, size: 18),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: Motion.of(context, Motion.base),
                          curve: Motion.enter,
                          child: last
                              ? Padding(
                                  padding: const EdgeInsets.only(top: Space.xs),
                                  child: TextButton(
                                    onPressed: () => _finish(then: Routes.login),
                                    style: TextButton.styleFrom(foregroundColor: Brand.ivory),
                                    child: Text(l10n.onboardingHaveAccount),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.controller,
    required this.index,
    required this.image,
    required this.icon,
    required this.title,
    required this.body,
  });
  final PageController controller;
  final int index;
  final String image;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final photoHeight = (box.maxHeight * 0.58).clamp(150.0, 440.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: ContentWidth(
              maxWidth: 520,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: photoHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.xl + 4),
                            child: AnimatedBuilder(
                              animation: controller,
                              builder: (context, child) {
                                final page = controller.hasClients && controller.position.haveDimensions
                                    ? controller.page ?? index.toDouble()
                                    : index.toDouble();
                                final offset = (page - index).clamp(-1.0, 1.0);
                                return Transform.translate(
                                  offset: Offset(offset * 60, 0),
                                  child: Transform.scale(scale: 1.18, child: child),
                                );
                              },
                              child: Image.asset(image, fit: BoxFit.cover, cacheWidth: 900, excludeFromSemantics: true),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Radii.xl + 4),
                              border: Border.all(color: const Color(0x26F3DCA2)),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.55, 1],
                                colors: [Color(0x00000000), Color(0x99060A14)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: Space.md,
                          bottom: -22,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Brand.goldLight, Brand.gold]),
                              border: Border.all(color: Brand.midnight, width: 4),
                            ),
                            child: Icon(icon, color: const Color(0xFF1A1305), size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl + Space.xs),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Fonts.display(context.text.displaySmall, weight: 660).copyWith(color: Brand.ivory),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(color: const Color(0xB3F5F1E7)),
                  ),
                  const SizedBox(height: Space.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
