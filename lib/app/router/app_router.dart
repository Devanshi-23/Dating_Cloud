import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/presentation/developer_tools_view.dart';
import '../../features/auth/domain/legal.dart';
import '../../features/auth/presentation/viewmodels/session_view_model.dart';
import '../../features/auth/presentation/views/legal_view.dart';
import '../../features/auth/presentation/views/sign_in_view.dart';
import '../../features/auth/presentation/views/splash_view.dart';
import '../../features/auth/presentation/views/welcome_view.dart';
import '../../features/chat/presentation/views/conversation_view.dart';
import '../../features/chat/presentation/views/conversations_view.dart';
import '../../features/discovery/presentation/views/discover_view.dart';
import '../../features/matches/presentation/views/matches_view.dart';
import '../../features/onboarding/presentation/views/onboarding_view.dart';
import '../../features/settings/presentation/views/me_view.dart';
import '../config/app_config.dart';
import 'home_shell.dart';
import 'route_guards.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  final sessionChanges = ValueNotifier<int>(0);
  ref
    ..listen(sessionViewModelProvider, (_, _) => sessionChanges.value++)
    ..onDispose(sessionChanges.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    refreshListenable: sessionChanges,
    redirect: (context, state) => redirectFor(
      session: ref.read(sessionViewModelProvider),
      location: state.matchedLocation,
      developerToolsEnabled: config.showDeveloperTools,
    ),
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (_, _) => const SplashView()),
      GoRoute(path: RoutePaths.welcome, builder: (_, _) => const WelcomeView()),
      GoRoute(path: RoutePaths.signIn, builder: (_, _) => const SignInView()),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (_, _) => const OnboardingView(),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (_, _) => const LegalView(document: LegalDocument.terms),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (_, _) => const LegalView(document: LegalDocument.privacy),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.discover,
                builder: (_, _) => const DiscoverView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.matches,
                builder: (_, _) => const MatchesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.chats,
                builder: (_, _) => const ConversationsView(),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => ConversationView(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.me,
                builder: (_, _) => const MeView(),
                routes: [
                  GoRoute(
                    path: 'developer',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const DeveloperToolsView(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
