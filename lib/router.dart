import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/loading_screen.dart';
import 'features/onboarding/registration_screen.dart';
import 'features/onboarding/status_screen.dart';
import 'features/onboarding/onboarding_pairing_screen.dart';
import 'features/onboarding/pairing_choice_screen.dart';
import 'features/onboarding/relationship_questions_screen.dart';
import 'features/onboarding/goals_screen.dart';
import 'features/onboarding/privacy_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/ai_chat_screen.dart';
import 'features/pairing/you_screen.dart';
import 'features/pairing/us_screen.dart';
import 'features/pairing/pair_invite_screen.dart';
import 'features/pairing/pair_scan_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/cycle_tracker/cycle_registration_screen.dart';
import 'features/cycle_tracker/cycle_calendar_screen.dart';
import 'features/pairing/dream_detail_screen.dart';
import 'features/partner_insights/partner_insights_screen.dart';
import 'core/profile_existence_provider.dart';

/// Routes that require the user to NOT be authenticated.
const _authRoutes = ['/', '/signup'];

/// Routes that are part of the onboarding flow.
const _onboardingRoutes = [
  '/onboarding/register',
  '/onboarding/status',
  '/onboarding/pair-choice',
  '/onboarding/invite',
  '/onboarding/questions',
  '/onboarding/goals',
  '/onboarding/privacy',
  '/pair/invite',
  '/pair/scan',
];

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final profileNotifier = ref.watch(profileExistenceProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: profileNotifier,
    redirect: (context, state) {
      final supabaseUser = Supabase.instance.client.auth.currentUser;

      // 1. Check if we are initializing or loading profile status
      final hasProfile = profileNotifier.hasProfile;

      // If we are authenticated but don't know the profile status yet, show the loading screen
      // instead of flashing the welcome screen.
      if (supabaseUser != null && hasProfile == null) {
        return '/loading';
      }

      // 2. Not logged in → only allow access to auth routes.
      if (supabaseUser == null) {
        if (_authRoutes.contains(state.matchedLocation)) return null;
        return '/';
      }

      final isAuthOrOnboarding = _authRoutes.contains(state.matchedLocation) ||
          state.matchedLocation == '/loading' ||
          _onboardingRoutes.any((r) => state.matchedLocation.startsWith(r));

      if (isAuthOrOnboarding) {
        // If we correspond to a pure auth route or loading...
        if (_authRoutes.contains(state.matchedLocation) || state.matchedLocation == '/loading') {
          if (hasProfile == true) return '/dashboard';
          if (hasProfile == false) return '/onboarding/register';
        }
        // Otherwise, stay on the onboarding flow (like /onboarding/status, etc.)
        return null;
      }

      // Authenticated on a main route but no profile -> Force registration
      if (hasProfile == false) {
        return '/onboarding/register';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (ctx, _) => const WelcomeScreen()),
      GoRoute(path: '/loading', builder: (ctx, _) => const LoadingScreen()),
      GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
      GoRoute(
          path: '/onboarding/register',
          builder: (ctx, _) => const RegistrationScreen()),
      GoRoute(
          path: '/onboarding/status',
          builder: (ctx, _) => const StatusScreen()),
      GoRoute(
          path: '/onboarding/pair-choice',
          builder: (ctx, _) => const OnboardingPairChoiceScreen()),
      GoRoute(
          path: '/onboarding/invite',
          builder: (ctx, _) => const OnboardingPairingScreen()),
      GoRoute(
          path: '/onboarding/questions',
          builder: (ctx, _) => const RelationshipQuestionsScreen()),
      GoRoute(
          path: '/onboarding/goals', builder: (ctx, _) => const GoalsScreen()),
      GoRoute(
          path: '/onboarding/privacy',
          builder: (ctx, _) => const PrivacyScreen()),
      GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardScreen()),
      GoRoute(path: '/insights', builder: (ctx, _) => const InsightsScreen()),
      GoRoute(path: '/ai_chat', builder: (ctx, _) => const AiChatScreen()),
      GoRoute(path: '/you', builder: (ctx, _) => const YouScreen()),
      GoRoute(path: '/us', builder: (ctx, _) => const UsScreen()),
      GoRoute(
        path: '/pair/invite',
        builder: (ctx, state) {
          final isOnboarding = state.uri.queryParameters['isOnboarding'] == 'true';
          return PairInviteScreen(isOnboarding: isOnboarding);
        },
      ),
      GoRoute(
        path: '/pair/scan',
        builder: (ctx, state) {
          final successRoute = state.uri.queryParameters['successRoute'];
          return PairScanScreen(successRoute: successRoute);
        },
      ),
      GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
      GoRoute(
          path: '/cycle_registration',
          builder: (ctx, _) => const CycleRegistrationScreen()),
      GoRoute(
          path: '/cycle_calendar',
          builder: (ctx, _) => const CycleCalendarScreen()),
      GoRoute(
          path: '/partner-insights',
          builder: (ctx, _) => const PartnerInsightsScreen()),
      GoRoute(
        path: '/us/dream/:id',
        builder: (ctx, state) {
          final id = state.pathParameters['id']!;
          return DreamDetailScreen(dreamId: id);
        },
      ),
    ],
  );
});
