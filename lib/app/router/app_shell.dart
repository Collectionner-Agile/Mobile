import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_icons.dart';
import '../../core/widgets/motion.dart';
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
        icon: AppIcons.compass,
        actionLabel: context.l10n.navHome,
        onAction: () => context.go('/home'),
      ),
    ),
  );
}

/// One destination of the main navigation.
typedef _Destination = ({IconData icon, String label});

/// Floating pill bar on phones (21st.dev "Bottom Nav Bar": the active tab
/// widens on a spring into a tinted capsule with its label) with the scan
/// button raised in the middle; a navigation rail on wide layouts. Tabs
/// cross-fade, and re-tapping the active tab returns to its root.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  /// Index of the scan tab, drawn as the raised centre button.
  static const scanIndex = 2;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastBack;

  StatefulNavigationShell get shell => widget.shell;

  void _select(int index) {
    if (index != shell.currentIndex) HapticFeedback.selectionClick();
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

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

    final List<_Destination> destinations = [
      (icon: AppIcons.house, label: l10n.navHome),
      (icon: AppIcons.compass, label: l10n.navExplore),
      (icon: AppIcons.scanLine, label: l10n.navScan),
      (icon: AppIcons.gavel, label: l10n.navAuctions),
      (icon: AppIcons.circleUserRound, label: l10n.profile),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 720) {
            return Scaffold(
              body: Row(
                children: [
                  SafeArea(
                    right: false,
                    // Landscape phones are short: let the rail scroll instead
                    // of overflowing when labels are large.
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
                                for (final destination in destinations)
                                  NavigationRailDestination(
                                    icon: Icon(destination.icon),
                                    label: Text(destination.label),
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
            extendBody: true,
            body: shell,
            bottomNavigationBar: _PillNavBar(index: shell.currentIndex, onSelect: _select, destinations: destinations),
          );
        },
      ),
    );
  }
}

class _PillNavBar extends StatelessWidget {
  const _PillNavBar({required this.index, required this.onSelect, required this.destinations});
  final int index;
  final ValueChanged<int> onSelect;
  final List<_Destination> destinations;

  static const double _slot = 52;
  static const double _scan = 60;
  static const double _height = 64;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // The bar is a fixed control: let labels grow a little with the user's
    // text size, never enough to break the pill.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Content fades out under the floating bar instead of colliding
          // with it.
          Positioned.fill(
            top: -28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [brand.paper.withValues(alpha: 0), brand.paper.withValues(alpha: 0.92)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.sm + bottom),
            child: _Entrance(
              child: Container(
                height: _height,
                decoration: BoxDecoration(
                  color: brand.surface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: brand.line),
                  boxShadow: brand.floatingShadow,
                ),
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final inner = constraints.maxWidth;
                    final regular = destinations.length - 1;
                    final scanActive = index == AppShell.scanIndex;
                    final even = (inner - _scan) / regular;
                    final active = (inner - _scan - _slot * (regular - 1)).clamp(_slot, double.infinity);
                    final showLabel = active >= 104;
                    return Row(
                      children: [
                        for (final (i, destination) in destinations.indexed)
                          if (i == AppShell.scanIndex)
                            _ScanButton(
                              label: destination.label,
                              icon: destination.icon,
                              selected: scanActive,
                              onTap: () => onSelect(i),
                            )
                          else
                            _NavItem(
                              width: scanActive ? even : (i == index ? active : _slot),
                              selected: i == index,
                              showLabel: showLabel && i == index,
                              icon: destination.icon,
                              label: destination.label,
                              onTap: () => onSelect(i),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar springs in once when the shell first appears (scale 0.9 → 1).
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.springDuration(Motion.bouncy),
      curve: Motion.bouncy,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: child,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.width,
    required this.selected,
    required this.showLabel,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final double width;
  final bool selected;
  final bool showLabel;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tint = context.isDark ? brand.gold : brand.accent;
    final foreground = selected ? tint : brand.muted;
    final spring = Motion.of(context, Motion.springDuration(Motion.spring));
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: TapScale(
          child: AnimatedContainer(
            duration: spring,
            curve: Motion.spring,
            width: width,
            height: 52,
            decoration: BoxDecoration(
              color: selected ? tint.withValues(alpha: context.isDark ? 0.16 : 0.08) : Colors.transparent,
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
                      AnimatedScale(
                        scale: selected ? 1.06 : 1,
                        duration: spring,
                        curve: Motion.bouncy,
                        child: Icon(icon, color: foreground, size: 22),
                      ),
                      Flexible(
                        child: AnimatedSize(
                          duration: spring,
                          curve: Motion.spring,
                          alignment: Alignment.centerLeft,
                          child: AnimatedOpacity(
                            opacity: showLabel ? 1 : 0,
                            duration: Motion.of(context, const Duration(milliseconds: 190)),
                            child: showLabel
                                ? Padding(
                                    padding: const EdgeInsets.only(left: Space.xs),
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: Fonts.label(
                                        context.text.labelLarge,
                                        weight: 680,
                                      ).copyWith(color: foreground),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Raised circular scan button in the middle of the bar.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final dark = context.isDark;
    final colors = dark ? [brand.accentStrong, brand.accent] : [const Color(0xFF263A66), brand.accent];
    return SizedBox(
      width: _PillNavBar._scan,
      height: 52,
      child: OverflowBox(
        maxHeight: 80,
        alignment: Alignment.bottomCenter,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: TapScale(
              scale: 0.9,
              child: Transform.translate(
                offset: const Offset(0, -12),
                child: GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.base),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                      border: Border.all(color: brand.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: (dark ? brand.gold : brand.accent).withValues(alpha: selected ? 0.5 : 0.32),
                          blurRadius: selected ? 22 : 16,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: brand.onAccent, size: 25),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds the tab navigators: only the current one is painted and ticking, and
/// it fades up when you switch to it. Wrappers stay identical for every
/// branch, so switching never rebuilds a tab's navigator.
class BranchContainer extends StatefulWidget {
  const BranchContainer({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<BranchContainer> createState() => _BranchContainerState();
}

class _BranchContainerState extends State<BranchContainer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.base, value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Motion.enter);
  late final Animation<double> _scale = Tween<double>(begin: 0.985, end: 1).animate(_fade);

  @override
  void didUpdateWidget(BranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !Motion.reduced(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in widget.children.indexed)
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index ? _fade : kAlwaysCompleteAnimation,
              child: ScaleTransition(scale: i == widget.index ? _scale : const AlwaysStoppedAnimation(1), child: child),
            ),
          ),
        ),
    ],
  );
}
