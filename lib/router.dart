import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/onboarding/invite_screen.dart';
import 'features/onboarding/goals_screen.dart';
import 'features/onboarding/privacy_screen.dart';
import 'features/onboarding/registration_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/ai_chat_screen.dart';
import 'features/pairing/you_screen.dart';
import 'features/pairing/us_screen.dart';
import 'features/pairing/pair_invite_screen.dart';
import 'features/pairing/pair_scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/cycle_tracker/cycle_registration_screen.dart';
import 'features/cycle_tracker/cycle_calendar_screen.dart';

/// Routes that require the user to NOT be authenticated.
const _authRoutes = ['/', '/signup'];

/// Routes that are part of the onboarding flow.
const _onboardingRoutes = [
  '/onboarding/register',
  '/onboarding/invite',
  '/onboarding/goals',
  '/onboarding/privacy',
];

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;

    // 1. Not logged in → only allow access to auth routes.
    if (supabaseUser == null) {
      if (_authRoutes.contains(state.matchedLocation)) return null;
      return '/';
    }

    // 2. Check if profile exists in Supabase — using the Auth ID directly
    final userRow = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('id', supabaseUser.id)
        .maybeSingle();

    final hasProfile = userRow != null;

    final isAuthOrOnboarding = _authRoutes.contains(state.matchedLocation) ||
        _onboardingRoutes.any((r) => state.matchedLocation.startsWith(r));

    if (isAuthOrOnboarding) {
      // Skip onboarding if profile already exists
      if (hasProfile) return '/dashboard';
      return null;
    }

    // Authenticated on a main route but no profile -> Force registration
    if (!hasProfile) {
      return '/onboarding/register';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (ctx, _) => const WelcomeScreen()),
    GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
    GoRoute(
        path: '/onboarding/register',
        builder: (ctx, _) => const RegistrationScreen()),
    GoRoute(
        path: '/onboarding/invite', builder: (ctx, _) => const InviteScreen()),
    GoRoute(
        path: '/onboarding/goals', builder: (ctx, _) => const GoalsScreen()),
    GoRoute(
        path: '/onboarding/privacy',
        builder: (ctx, _) => const PrivacyScreen()),
    GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardScreen()),
    GoRoute(path: '/ai_chat', builder: (ctx, _) => const AiChatScreen()),
    GoRoute(path: '/you', builder: (ctx, _) => const YouScreen()),
    GoRoute(path: '/us', builder: (ctx, _) => const UsScreen()),
    GoRoute(
        path: '/pair/invite', builder: (ctx, _) => const PairInviteScreen()),
    GoRoute(path: '/pair/scan', builder: (ctx, _) => const PairScanScreen()),
    GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
    GoRoute(
        path: '/cycle_registration',
        builder: (ctx, _) => const CycleRegistrationScreen()),
    GoRoute(
        path: '/cycle_calendar',
        builder: (ctx, _) => const CycleCalendarScreen()),
  ],
);
