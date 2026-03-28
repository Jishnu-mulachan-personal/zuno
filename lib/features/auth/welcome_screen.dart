import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Stack(
        children: [
          // ── Background image ────────────────────────────────────────────
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.6),
              colorBlendMode: BlendMode.lighten,
              errorBuilder: (_, __, ___) => Container(color: ZunoTheme.primaryFixed.withOpacity(0.3)),
            ),
          ),
          // ── Gradient overlays ───────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ZunoTheme.surface,
                    ZunoTheme.surface.withOpacity(0.1),
                    ZunoTheme.surface,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // ── Hearth glow blobs ───────────────────────────────────────────
          Positioned(
            bottom: -60,
            left: -60,
            child: _glowBlob(ZunoTheme.tertiaryFixed, 220),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: _glowBlob(ZunoTheme.primaryFixed, 220),
          ),
          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Logo
                const SizedBox(height: 32),
                _ZunoLogo(),
                const Spacer(),
                // Hero text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Feel closer.',
                        style: GoogleFonts.notoSerif(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurface,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Every day.',
                        style: GoogleFonts.notoSerif(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: ZunoTheme.primary,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A private space to understand your relationship, together.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          color: ZunoTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w300,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // CTAs
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    children: [
                      // Primary button
                      _GradientButton(
                        label: 'Get Started',
                        icon: Icons.arrow_forward,
                        onTap: () => context.go('/signup'),
                      ),
                      const SizedBox(height: 16),
                      // Glass panel
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: ZunoTheme.surfaceContainerLowest.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ZunoTheme.outlineVariant.withOpacity(0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'START YOUR JOURNEY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.0,
                                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.go('/signup'),
                                child: Text(
                                  'Already have an account? Log in',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ZunoTheme.primary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'BUILT FOR INTIMACY  •  PRIVACY FIRST',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.5,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
      ),
    );
  }
}

class _ZunoLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Zuno',
          style: GoogleFonts.notoSerif(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: ZunoTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: ZunoTheme.tertiaryFixedDim.withOpacity(0.6),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

// ── Shared gradient button ─────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _GradientButton({required this.label, this.icon, required this.onTap});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: ZunoTheme.primaryGradient,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: ZunoTheme.primary.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 8),
                Icon(widget.icon, color: Colors.white, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

