import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_icons.dart';
import '../../core/widgets/ui.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/launch/launch_scene.dart';
import '../theme/tokens.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: EmptyState(
        message: context.l10n.errorNotFound,
        icon: Icons.travel_explore_outlined,
        actionLabel: context.l10n.navHome,
        onAction: () => context.go('/home'),
      ),
    ),
  );
}

/// Bottom navigation on phones, navigation rail on wide layouts (landscape,
/// tablets, foldables). Re-tapping the active tab returns to its root.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastBack;

  StatefulNavigationShell get shell => widget.shell;

  void _select(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  /// Back at a tab's root: other tabs return to Home; on Home a first press
  /// warns and a second one within two seconds plays the farewell and closes
  /// the app.
  void _onBack() {
    if (shell.currentIndex != 0) {
      _select(0);
      return;
    }
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      _lastBack = null;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      farewell(context, title: context.l10n.farewellTitle, message: context.l10n.farewellExit, exitApp: true);
      return;
    }
    _lastBack = now;
    HapticFeedback.selectionClick();
    showToast(context, context.l10n.pressBackAgain, icon: AppIcons.doorOpen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(sessionExpiredNoticeProvider, (_, expired) {
      if (expired) {
        showToast(context, l10n.sessionExpired, error: true);
        ref.read(sessionExpiredNoticeProvider.notifier).set(false);
      }
    });

    final destinations = [
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, l10n.navCatalog),
      (Icons.center_focus_weak_outlined, Icons.center_focus_strong, l10n.navScan),
      (Icons.gavel_outlined, Icons.gavel, l10n.navAuctions),
      (Icons.forum_outlined, Icons.forum, l10n.navCommunities),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          if (wide) {
            return Scaffold(
              body: Row(
                children: [
                  SafeArea(
                    right: false,
                    // Landscape phones are short: let the rail scroll instead of
                    // overflowing when labels are large.
                    child: LayoutBuilder(
                      builder: (context, rail) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: rail.maxHeight),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: shell.currentIndex,
                              onDestinationSelected: _select,
                              labelType: NavigationRailLabelType.all,
                              groupAlignment: -0.85,
                              destinations: [
                                for (final (icon, selected, label) in destinations)
                                  NavigationRailDestination(
                                    icon: Icon(icon),
                                    selectedIcon: Icon(selected),
                                    label: Text(label),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: context.brand.line),
                  Expanded(child: shell),
                ],
              ),
            );
          }
          return Scaffold(
            body: shell,
            bottomNavigationBar: _FloatingNavBar(
              index: shell.currentIndex,
              onSelect: _select,
              destinations: destinations,
            ),
          );
        },
      ),
    );
  }
}

/// Floating pill bar: the active tab expands into an ink capsule with its
/// label, the others stay as icons.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.index, required this.onSelect, required this.destinations});
  final int index;
  final ValueChanged<int> onSelect;
  final List<(IconData, IconData, String)> destinations;

  static const double _iconSlot = 52;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: brand.paper,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, Space.sm + bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: brand.line),
            boxShadow: brand.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final active = (constraints.maxWidth - _iconSlot * (destinations.length - 1)).clamp(
                  _iconSlot,
                  double.infinity,
                );
                return Row(
                  children: [
                    for (final (i, (icon, selected, label)) in destinations.indexed)
                      _NavItem(
                        width: i == index ? active : _iconSlot,
                        selected: i == index,
                        icon: i == index ? selected : icon,
                        label: label,
                        onTap: () => onSelect(i),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.width,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final double width;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final fg = selected ? brand.onAccent : brand.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: false,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.enter,
          width: width,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? brand.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: ClipRect(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: fg, size: 24),
                    if (selected) ...[
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: Fonts.label(context.text.labelLarge, weight: 680).copyWith(color: fg),
                        ),
                      ),
                    ],
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
