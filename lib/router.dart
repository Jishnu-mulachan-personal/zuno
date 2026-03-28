import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/onboarding/invite_screen.dart';
import 'features/onboarding/goals_screen.dart';
import 'features/onboarding/privacy_screen.dart';
import 'features/onboarding/registration_screen.dart';
import 'features/onboarding/dashboard_stub.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
    GoRoute(path: '/onboarding/register', builder: (ctx, _) => const RegistrationScreen()),
    GoRoute(path: '/onboarding/invite', builder: (ctx, _) => const InviteScreen()),
    GoRoute(path: '/onboarding/goals', builder: (ctx, _) => const GoalsScreen()),
    GoRoute(path: '/onboarding/privacy', builder: (ctx, _) => const PrivacyScreen()),
    GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardStub()),
  ],
);
