import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';

/// The "You" tab — shown when the user hasn't paired yet,
/// or a coupled status view once a partner is linked.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: ZunoTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _YouAppBar(displayName: profile.displayName),
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHero(profile: profile),
                  const SizedBox(height: 32),
                  if (profile.partnerName != null)
                    _CoupledCard(partnerName: profile.partnerName!)
                  else
                    _PairCard(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Bar ──────────────────────────────────────────────────────────────────

class _YouAppBar extends StatelessWidget {
  final String displayName;
  const _YouAppBar({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: ZunoTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: ZunoTheme.primary, size: 18),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'You',
        style: GoogleFonts.notoSerif(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ZunoTheme.primary,
        ),
      ),
    );
  }
}

// ── Profile Hero ─────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ZunoTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: ZunoTheme.primary.withOpacity(0.25),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.person_rounded,
              color: Colors.white, size: 42),
        ),
        const SizedBox(height: 16),
        Text(
          profile.displayName,
          style: GoogleFonts.notoSerif(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department_rounded,
                size: 14, color: ZunoTheme.primary),
            const SizedBox(width: 4),
            Text(
              '${profile.streakDays}-day streak',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Pairing Card (no partner yet) ─────────────────────────────────────────────

class _PairCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONNECT YOUR PARTNER',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 12),
        // Main CTA card
        GestureDetector(
          onTap: () => context.push('/pair/invite'),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ZunoTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ZunoTheme.primary.withOpacity(0.25),
                  blurRadius: 28,
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
                        'Generate a QR code and let your\npartner scan to connect.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.4,
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
        const SizedBox(height: 16),
        // Secondary — scan instead
        GestureDetector(
          onTap: () => context.push('/pair/scan'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: ZunoTheme.outlineVariant.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ZunoTheme.primaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded,
                      color: ZunoTheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Partner\'s Code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                      Text(
                        'Already have a code? Scan it here.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: ZunoTheme.outlineVariant, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _InfoTip(),
      ],
    );
  }
}

class _InfoTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ZunoTheme.tertiaryFixed.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: ZunoTheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Each QR code expires after 10 minutes and can only be used once.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: ZunoTheme.onTertiaryFixedVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coupled card (partner is linked) ─────────────────────────────────────────

class _CoupledCard extends StatelessWidget {
  final String partnerName;
  const _CoupledCard({required this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite_rounded,
              color: ZunoTheme.primary, size: 36),
          const SizedBox(height: 14),
          Text(
            'Connected with',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            partnerName,
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💚 You\'re paired — keep the hearth warm.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
