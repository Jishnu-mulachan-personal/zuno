import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class OnboardingPairChoiceScreen extends ConsumerWidget {
  const OnboardingPairChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.5),
                  radius: 1.0,
                  colors: [
                    ZunoTheme.primaryContainer.withOpacity(0.15),
                    ZunoTheme.surface,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Progress + logo
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Zuno',
                          style: GoogleFonts.notoSerif(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: ZunoTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _ProgressDots(active: 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 54),
                  Text(
                    'Ready to connect\nwith your partner?',
                    style: GoogleFonts.notoSerif(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Zuno works best when shared. You can pair now to see each other\'s moods and insights, or skip and do it later.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: ZunoTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Option 1: Connect Now
                  GestureDetector(
                    onTap: () => context.push('/onboarding/invite'),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: ZunoTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: ZunoTheme.primary.withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.favorite_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YES, CONNECT NOW',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Link your profiles to stay in sync.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Option 2: Maybe Later
                  GestureDetector(
                    onTap: () => context.go('/onboarding/questions'),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ZunoTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: ZunoTheme.outlineVariant.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: ZunoTheme.primaryFixed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.access_time_rounded,
                                color: ZunoTheme.primary, size: 28),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MAYBE LATER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: ZunoTheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Finish setup first, pair anytime later.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: ZunoTheme.outlineVariant, size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  // Info Tip
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ZunoTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: ZunoTheme.tertiary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Pairing allows you to share moods, cycle phases, and get AI insights about your relationship dynamics.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: ZunoTheme.onSurfaceVariant.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int active;
  const _ProgressDots({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0 == active),
        const SizedBox(width: 6),
        _dot(1 == active),
        const SizedBox(width: 6),
        _dot(2 == active),
      ],
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? ZunoTheme.primary : ZunoTheme.outlineVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

