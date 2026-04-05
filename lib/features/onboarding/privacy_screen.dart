import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../core/profile_existence_provider.dart';
import '../auth/user_repository.dart';

// ── State ──────────────────────────────────────────────────────────────────

enum PrivacyLevel { private, balanced, shared }

final privacyProvider =
    StateProvider<PrivacyLevel>((_) => PrivacyLevel.balanced);

// ── Screen ─────────────────────────────────────────────────────────────────

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(privacyProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Stack(
        children: [
          // Hearth glow blobs
          Positioned(
            top: -80,
            left: -80,
            child: _glowBlob(ZunoTheme.primary, 320, 0.05),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: _glowBlob(ZunoTheme.tertiary, 280, 0.05),
          ),
          SafeArea(
            child: Column(
              children: [
                // Glass header
                _GlassHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Your Privacy, ',
                                style: GoogleFonts.notoSerif(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  color: ZunoTheme.onSurface,
                                  height: 1.15,
                                ),
                              ),
                              TextSpan(
                                text: 'Your Control',
                                style: GoogleFonts.notoSerif(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  color: ZunoTheme.primary,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Choose how much of your inner world you'd like to mirror back into the shared space.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: ZunoTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Trust chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _TrustChip(
                                  icon: Icons.verified_user,
                                  label: 'End-to-end Encrypted'),
                              const SizedBox(width: 8),
                              _TrustChip(
                                  icon: Icons.visibility_off,
                                  label: 'Zero-Knowledge Storage'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Options
                        _PrivacyCard(
                          icon: Icons.lock_outline,
                          title: 'Mostly private',
                          subtitle: 'Keep almost everything to myself',
                          level: PrivacyLevel.private,
                          selected: selected == PrivacyLevel.private,
                        ),
                        const SizedBox(height: 12),
                        _PrivacyCard(
                          icon: Icons.balance,
                          title: 'Balanced',
                          subtitle: 'Share essential moods and trends',
                          level: PrivacyLevel.balanced,
                          selected: selected == PrivacyLevel.balanced,
                          recommended: true,
                        ),
                        const SizedBox(height: 12),
                        _PrivacyCard(
                          icon: Icons.group_outlined,
                          title: 'Mostly shared',
                          subtitle: 'Open transparency with partner',
                          level: PrivacyLevel.shared,
                          selected: selected == PrivacyLevel.shared,
                        ),
                        // Quote
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 1,
                                color:
                                    ZunoTheme.outlineVariant.withOpacity(0.3),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '"Vulnerability is the birthplace of connection."',
                                style: GoogleFonts.notoSerif(
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                  color: ZunoTheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sticky footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [ZunoTheme.surface, ZunoTheme.surface.withOpacity(0)],
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      try {
                        final userRepo = ref.read(userRepositoryProvider);
                        final level = ref.read(privacyProvider);
                        
                        await userRepo.updateUserSettings(
                            privacyPreference: level.name);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: ZunoTheme.tertiaryFixed),
                                  const SizedBox(width: 10),
                                  Text(
                                    "You're all set! Let's begin ✨",
                                    style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              backgroundColor: ZunoTheme.onSurface,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          Future.delayed(const Duration(seconds: 1), () {
                            if (context.mounted) {
                              ref
                                  .read(profileExistenceProvider)
                                  .setHasProfile(true);
                              context.go('/dashboard');
                            }
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
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
                            'COMPLETE SETUP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'YOU CAN CHANGE THESE SETTINGS ANYTIME IN PROFILE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(Color color, double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}

// ── Components ────────────────────────────────────────────────────────────

class _GlassHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 40,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: ZunoTheme.primary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          Text(
            'Zuno',
            style: GoogleFonts.notoSerif(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: ZunoTheme.primary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ZunoTheme.tertiary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ZunoTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends ConsumerWidget {
  final IconData icon;
  final String title, subtitle;
  final PrivacyLevel level;
  final bool selected;
  final bool recommended;

  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.selected,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(privacyProvider.notifier).state = level,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ZunoTheme.primaryContainer : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.onSurface.withOpacity(0.04),
              blurRadius: selected ? 12 : 4,
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? ZunoTheme.primaryFixed
                    : ZunoTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: ZunoTheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ZunoTheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ZunoTheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: const Color(0xFF002020),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: ZunoTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? ZunoTheme.primary : Colors.transparent,
                border: Border.all(
                  color:
                      selected ? ZunoTheme.primary : ZunoTheme.outlineVariant,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: selected
                  ? const Icon(Icons.circle, color: Colors.white, size: 8)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
