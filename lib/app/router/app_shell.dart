import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/ui.dart';
import '../../features/auth/application/session_controller.dart';
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
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _select(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return LayoutBuilder(
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
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.brand.line)),
            ),
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label, tooltip: label),
              ],
            ),
          ),
        );
      },
    );
  }
}
