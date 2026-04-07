import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class OnboardingPairingScreen extends ConsumerWidget {
  const OnboardingPairingScreen({super.key});

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
                    'Connect Your Partner',
                    style: GoogleFonts.notoSerif(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Zuno is built for two. Choose how you\'d like to link your accounts.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: ZunoTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Option 1: Generate (Invite)
                  GestureDetector(
                    onTap: () => context.push('/pair/invite?isOnboarding=true'),
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
                            child: const Icon(Icons.qr_code_2_rounded,
                                color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pair with Partner',
                                  style: GoogleFonts.notoSerif(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Generate a code and let your partner scan to connect.',
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

                  // Option 2: Scan
                  GestureDetector(
                    onTap: () => context.push(
                        '/pair/scan?successRoute=${Uri.encodeComponent('/onboarding/questions')}'),
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
                            child: Icon(Icons.qr_code_scanner_rounded,
                                color: ZunoTheme.primary, size: 28),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scan Partner Code',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: ZunoTheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Already have a code? Point your camera here.',
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

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/onboarding/questions'),
                      child: Text(
                        'SKIP FOR NOW',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: ZunoTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  
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
                        Icon(Icons.auto_awesome_rounded, size: 20, color: ZunoTheme.tertiary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'One of you generates the code, and the other one scans it. Simple as that!',
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

