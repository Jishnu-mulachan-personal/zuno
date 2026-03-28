import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/onboarding/invite_screen.dart';
import 'features/onboarding/goals_screen.dart';
import 'features/onboarding/privacy_screen.dart';
import 'features/onboarding/registration_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

/// Routes that require the user to NOT be authenticated.
const _authRoutes = ['/', '/signup', '/otp'];

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
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;

    // Not logged in → only allow access to auth routes.
    if (firebaseUser == null) {
      if (_authRoutes.contains(state.matchedLocation)) return null;
      return '/';
    }

    final phone = firebaseUser.phoneNumber;
    final isAuthOrOnboarding = _authRoutes.contains(state.matchedLocation) ||
        _onboardingRoutes.any((r) => state.matchedLocation.startsWith(r));

    // Already authenticated → check if profile exists in Supabase.
    if (isAuthOrOnboarding) {
      if (phone == null || phone.isEmpty) return null;

      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();

      if (response != null) {
        // Profile found → skip to dashboard.
        return '/dashboard';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (ctx, _) => const WelcomeScreen()),
    GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
    GoRoute(
      path: '/otp',
      builder: (ctx, state) {
        final phone = state.extra as String? ?? '';
        return OtpScreen(phoneNumber: phone);
      },
    ),
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
  ],
);
