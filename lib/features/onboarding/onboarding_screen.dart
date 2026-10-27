import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/preferences.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';

/// First-run introduction: three full-bleed pages with parallax photography,
/// copy on glass, animated progress pills and a skip action.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _images = [
    'assets/images/collectibles/records/star-destroyer-model.webp',
    'assets/images/collectibles/records/vintage-yellow-chronograph.webp',
    'assets/images/collectibles/records/yellow-handheld-set.webp',
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardedProvider.notifier).complete();
    if (mounted) context.go(Routes.home);
  }

  void _next() {
    if (_index == _images.length - 1) {
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
    final last = _index == _images.length - 1;
    return Scaffold(
      backgroundColor: BrandColors.dark.paper,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: _images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final page = _pages.hasClients && _pages.position.haveDimensions
                    ? _pages.page ?? _index.toDouble()
                    : _index.toDouble();
                final delta = index - page;
                // Photo moves slower than the page for depth.
                return ClipRect(
                  child: Transform.translate(
                    offset: Offset(-delta * MediaQuery.sizeOf(context).width * 0.35, 0),
                    child: Transform.scale(scale: 1.08, child: child),
                  ),
                );
              },
              child: Image.asset(_images[index], fit: BoxFit.cover, excludeFromSemantics: true),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.35, 1],
                  colors: [Color(0x66000000), Color(0x00000000), Color(0xF2000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.xs),
                        child: Image.asset(
                          'assets/branding/site-icon-512.png',
                          width: 30,
                          height: 30,
                          cacheWidth: 90,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          l10n.appName,
                          style: Fonts.display(context.text.titleMedium, weight: 800).copyWith(color: Colors.white),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: last ? 0 : 1,
                        duration: Motion.of(context, Motion.fast),
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: last ? null : _finish,
                          child: Text(l10n.onboardingSkip),
                        ),
                      ),
                    ],
                  ),
                  // Bottom-anchored; scrolls instead of overflowing on short
                  // (landscape) screens or with large text.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(
                        reverse: true,
                        child: GlassPanel(
                          padding: const EdgeInsets.all(Space.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: Motion.of(context, Motion.base),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0, 0.15),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(parent: animation, curve: Motion.enter)),
                                    child: child,
                                  ),
                                ),
                                layoutBuilder: (current, previous) =>
                                    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                                child: Column(
                                  key: ValueKey(_index),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      liveRegion: true,
                                      child: Text(
                                        copy[_index].$1,
                                        style: context.text.headlineMedium?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: Space.xs),
                                    Text(
                                      copy[_index].$2,
                                      style: context.text.bodyLarge?.copyWith(color: const Color(0xD9FFFFFF)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: Space.lg),
                              Row(
                                children: [
                                  for (var i = 0; i < _images.length; i++)
                                    AnimatedContainer(
                                      duration: Motion.of(context, Motion.base),
                                      curve: Motion.enter,
                                      margin: const EdgeInsets.only(right: 6),
                                      width: i == _index ? 28 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: i == _index ? Colors.white : const Color(0x66FFFFFF),
                                        borderRadius: BorderRadius.circular(Radii.pill),
                                      ),
                                    ),
                                  const Spacer(),
                                  Flexible(
                                    child: TapScale(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: BrandColors.light.ink,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                                        ),
                                        onPressed: _next,
                                        child: AnimatedSwitcher(
                                          duration: Motion.of(context, Motion.fast),
                                          child: Row(
                                            key: ValueKey(last),
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  last ? l10n.onboardingStart : l10n.onboardingNext,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: Space.xs),
                                              Icon(last ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
