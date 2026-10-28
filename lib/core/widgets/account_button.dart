import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/favorites/favorites.dart';
import '../../features/notifications/notices.dart';
import 'ui.dart';

/// App-bar entry to the profile (signed in) or to sign-in (guest).
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    if (user == null) {
      return IconButton(
        tooltip: l10n.signIn,
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => context.push(Routes.login),
      );
    }
    final brand = context.brand;
    return IconButton(
      tooltip: l10n.profile,
      onPressed: () => context.push(Routes.profile),
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: brand.ink,
        child: Text(user.initial, style: context.text.labelLarge?.copyWith(color: brand.paper)),
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.settings,
    icon: const Icon(Icons.tune),
    onPressed: () => context.push(Routes.settings),
  );
}

/// Opens saved pieces; shows how many there are.
class FavoritesButton extends ConsumerWidget {
  const FavoritesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(favoritesProvider).length;
    return IconButton(
      tooltip: context.l10n.favoritesTitle,
      onPressed: () => context.push(Routes.favorites),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: context.brand.live,
        label: Text('$count'),
        child: const Icon(Icons.favorite_border_rounded),
      ),
    );
  }
}

/// Opens the notices; shows how many are unread.
class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticesProvider);
    return IconButton(
      tooltip: context.l10n.noticesTitle,
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: context.brand.live,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
