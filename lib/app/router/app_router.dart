import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_screen.dart';
import '../../features/auctions/presentation/auction_detail_screen.dart';
import '../../features/auctions/presentation/auctions_screen.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/collectible_detail_screen.dart';
import '../../features/catalog/presentation/publish_collectible_screen.dart';
import '../../features/communities/presentation/communities_screen.dart';
import '../../features/communities/presentation/community_detail_screen.dart';
import '../../features/communities/presentation/community_forms.dart';
import '../../features/communities/presentation/post_detail_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screens.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/recognition/presentation/scan_result_screen.dart';
import '../../features/recognition/presentation/scan_screen.dart';
import '../../features/search/search_screen.dart';
import '../preferences.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const home = '/home';
  static const onboarding = '/onboarding';
  static const favorites = '/favorites';
  static const activity = '/activity';
  static const search = '/search';
  static const catalog = '/catalog';
  static const scan = '/scan';
  static const scanResult = '/scan/result';
  static const auctions = '/auctions';
  static const communities = '/communities';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const changePassword = '/settings/change-password';
  static const publishCollectible = '/catalog/new';
  static const newCommunity = '/communities/new';

  static String collectible(int id) => '/catalog/item/$id';
  static String auction(int id) => '/auctions/$id';
  static String community(int id) => '/communities/$id';
  static String newPost(int communityId) => '/communities/$communityId/post';
  static String post(int id) => '/posts/$id';

  /// Paths that need a session; the user is sent to login and brought back.
  static bool isProtected(String location) =>
      location.startsWith(profile) ||
      location == publishCollectible ||
      location == newCommunity ||
      RegExp(r'^/communities/\d+/post$').hasMatch(location) ||
      location == changePassword;
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: ref.read(onboardedProvider) ? Routes.home : Routes.onboarding,
    refreshListenable: refresh,
    restorationScopeId: 'router',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      if (session.isLoading && !session.hasValue) return null;
      final signedIn = session.value != null;
      final location = state.matchedLocation;
      if (!signedIn && Routes.isProtected(location)) {
        return Uri(path: Routes.login, queryParameters: {'from': state.uri.toString()}).toString();
      }
      if (signedIn && (location == Routes.login || location == Routes.register)) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') ? from : Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.home),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.favorites, builder: (_, _) => const FavoritesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.activity, builder: (_, _) => const ActivityScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.search, builder: (_, _) => const SearchScreen()),
      // Full-screen flows above the tab bar. Declared before the shell so that
      // literal paths such as /communities/new win over /communities/:id.
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.scanResult, builder: (_, _) => const ScanResultScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.publishCollectible,
        builder: (_, state) =>
            PublishCollectibleScreen(prefill: state.extra is PublishPrefill ? state.extra! as PublishPrefill : null),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.newCommunity,
        builder: (_, _) => const CreateCommunityScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/communities/:id/post',
        builder: (_, state) => CreatePostScreen(communityId: _id(state)),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/posts/:id',
        builder: (_, state) => PostDetailScreen(id: _id(state)),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.login,
        builder: (_, state) => LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.register,
        builder: (_, state) => RegisterScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.resetPassword, builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.catalog,
                builder: (_, _) => const CatalogScreen(),
                routes: [
                  GoRoute(
                    path: 'item/:id',
                    builder: (_, state) => CollectibleDetailScreen(id: _id(state)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.scan, builder: (_, _) => const ScanScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.auctions,
                builder: (_, _) => const AuctionsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => AuctionDetailScreen(id: _id(state)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.communities,
                builder: (_, _) => const CommunitiesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => CommunityDetailScreen(id: _id(state)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});

int _id(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
