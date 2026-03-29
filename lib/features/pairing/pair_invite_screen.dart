import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';
import 'pair_provider.dart';

class PairInviteScreen extends ConsumerStatefulWidget {
  const PairInviteScreen({super.key});

  @override
  ConsumerState<PairInviteScreen> createState() => _PairInviteScreenState();
}

class _PairInviteScreenState extends ConsumerState<PairInviteScreen> {
  Timer? _countdownTimer;
  Timer? _pollTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    await ref.read(inviteProvider.notifier).generateToken();
    final state = ref.read(inviteProvider);
    if (state.expiresAt != null && state.token != null) {
      _startCountdown(state.expiresAt!);
      _startPollForClaim(state.token!);
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = expiresAt.difference(DateTime.now());
      if (!mounted) return;
      if (remaining.isNegative) {
        setState(() => _remaining = Duration.zero);
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        // Auto-refresh with a new token
        _generate();
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  /// Poll Supabase every 3 s to check if partner B has claimed the token.
  void _startPollForClaim(String token) {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final row = await Supabase.instance.client
            .from('partner_invites')
            .select('used')
            .eq('token', token)
            .maybeSingle();

        final used = (row?['used'] as bool?) ?? false;
        if (used && mounted) {
          _countdownTimer?.cancel();
          _pollTimer?.cancel();
          // Refresh User A's profile so the dashboard shows the partner name
          ref.invalidate(userProfileProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Partner connected!',
                    style: GoogleFonts.plusJakartaSans()),
                backgroundColor: ZunoTheme.tertiary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
            // Navigate back to You screen
            context.go('/you');
          }
        }
      } catch (e) {
        // Silently ignore poll errors — the countdown will still expire/refresh
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _countdownText {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }


  @override
  Widget build(BuildContext context) {
    final invite = ref.watch(inviteProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      appBar: AppBar(
        backgroundColor: ZunoTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: ZunoTheme.primary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Invite Partner',
          style: GoogleFonts.notoSerif(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Headline
              Text(
                'Share this with your partner',
                style: GoogleFonts.notoSerif(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ask them to open Zuno and tap "Scan Partner\'s Code".',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // QR Code card
              _QrCard(invite: invite, countdownText: _countdownText),
              const SizedBox(height: 24),
              // Refresh button
              if (!invite.isGenerating)
                _RefreshButton(onTap: _generate),
              const SizedBox(height: 16),
              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: ZunoTheme.onSurfaceVariant
                                .withOpacity(0.4))),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              // Scan instead
              _ScanInsteadButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── QR Card ──────────────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  final InviteState invite;
  final String countdownText;

  const _QrCard({required this.invite, required this.countdownText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (invite.isGenerating || invite.token == null)
            const SizedBox(
              width: 200,
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: ZunoTheme.primary),
              ),
            )
          else if (invite.error != null)
            SizedBox(
              width: 200,
              height: 200,
              child: Center(
                child: Text(invite.error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        color: ZunoTheme.error, fontSize: 13)),
              ),
            )
          else ...[
            // QR code
            QrImageView(
              data: invite.token!,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: ZunoTheme.onSurface,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: ZunoTheme.onSurface,
              ),
              embeddedImage: null,
            ),
            const SizedBox(height: 20),
            // Token text (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: invite.token!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Code copied!',
                        style: GoogleFonts.plusJakartaSans()),
                    backgroundColor: ZunoTheme.tertiary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      invite.token!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ZunoTheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded,
                        size: 14, color: ZunoTheme.outline),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Countdown
          _CountdownBadge(countdown: countdownText, isExpired: invite.isExpired),
        ],
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final String countdown;
  final bool isExpired;

  const _CountdownBadge({required this.countdown, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final color = isExpired ? ZunoTheme.error : ZunoTheme.tertiary;
    final label = isExpired ? 'Expired — refreshing…' : 'Expires in $countdown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refresh Button ───────────────────────────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(99),
          border:
              Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded,
                size: 16, color: ZunoTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Generate new code',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan Instead ─────────────────────────────────────────────────────────────

class _ScanInsteadButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/pair/scan'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner_rounded,
                size: 18, color: ZunoTheme.primary),
            const SizedBox(width: 10),
            Text(
              'Scan my partner\'s code instead',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
