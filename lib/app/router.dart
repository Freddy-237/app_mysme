import 'package:go_router/go_router.dart';
import 'package:mysme/features/splash/splash_screen.dart';
import 'package:mysme/features/onboarding/onboarding_screen.dart';
import 'package:mysme/features/identity/identity_screen.dart';
import 'package:mysme/features/home/home_screen.dart';
import 'package:mysme/features/discussions/discussions_page.dart';
import 'package:mysme/features/chat/chat_screen.dart';
import 'package:mysme/features/deeplink/deeplink_welcome_screen.dart';
import 'package:mysme/features/paywall/paywall_screen.dart';
import 'package:mysme/features/profile/profile_screen.dart';
import 'package:mysme/features/settings/settings_page.dart';

/// Named-route path constants (same values as AppRoutes for easy migration).
abstract class RoutePaths {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const identity = '/identity';
  static const home = '/home';
  static const discussions = '/discussions';
  static const chat = '/chat/:conversationId';
  static const deepLinkWelcome = '/deeplink-welcome';
  static const paywall = '/paywall';
  static const profile = '/profile';
  static const settings = '/settings';
}

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: RoutePaths.identity,
      name: 'identity',
      builder: (context, state) => const IdentityScreen(),
    ),
    GoRoute(
      path: RoutePaths.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: RoutePaths.discussions,
      name: 'discussions',
      builder: (context, state) => const DiscussionsPage(),
    ),
    GoRoute(
      path: RoutePaths.chat,
      name: 'chat',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId']!;
        return ChatScreen(conversationId: conversationId);
      },
    ),
    GoRoute(
      path: RoutePaths.deepLinkWelcome,
      name: 'deeplink-welcome',
      builder: (context, state) {
        final conversationId =
            state.uri.queryParameters['conversationId'] ?? '';
        final pseudo = state.uri.queryParameters['pseudo'];
        final targetName = state.uri.queryParameters['target'];

        if (conversationId.isEmpty) {
          return const HomeScreen();
        }

        return DeepLinkWelcomeScreen(
          conversationId: conversationId,
          pseudo: pseudo,
          targetName: targetName,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.paywall,
      name: 'paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: RoutePaths.profile,
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: RoutePaths.settings,
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
