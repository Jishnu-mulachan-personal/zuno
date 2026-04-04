import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    ZunoTheme.primaryFixed.withAlpha(25),
                    ZunoTheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo / Icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOutSine,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        'Zuno',
                        style: GoogleFonts.notoSerif(
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: ZunoTheme.primary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ZunoTheme.tertiaryFixedDim.withAlpha(100),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Subtle loader
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ZunoTheme.primary.withAlpha(100),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Preparing your space...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: ZunoTheme.onSurfaceVariant.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
