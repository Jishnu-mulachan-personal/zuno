import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class DashboardStub extends StatelessWidget {
  const DashboardStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: ZunoTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 32),
              Text(
                'Zuno',
                style: GoogleFonts.notoSerif(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: ZunoTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your home screen is coming soon. ✨',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  color: ZunoTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w300,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Onboarding complete!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ZunoTheme.tertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
