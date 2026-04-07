import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';
import 'pair_provider.dart';

class PairScanScreen extends ConsumerStatefulWidget {
  final String? successRoute;
  const PairScanScreen({super.key, this.successRoute});

  @override
  ConsumerState<PairScanScreen> createState() => _PairScanScreenState();
}

class _PairScanScreenState extends ConsumerState<PairScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleClaim(String token) async {
    if (_processing) return;
    
    // Normalize token (if user entered just the suffix)
    String normalizedToken = token.trim();
    if (!normalizedToken.startsWith('zuno_inv_')) {
      normalizedToken = 'zuno_inv_$normalizedToken';
    }

    setState(() => _processing = true);
    await _controller.stop();

    final success = await ref.read(claimProvider.notifier).claimToken(normalizedToken);
    final claimState = ref.read(claimProvider);

    if (!mounted) return;

    if (success) {
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(claimState.message ?? 'Paired! 💚',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.tertiary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      if (context.mounted) {
        context.go(widget.successRoute ?? '/us');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(claimState.message ?? 'Something went wrong.',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final token = capture.barcodes.map((b) => b.rawValue).firstWhere(
        (v) => v != null && v.startsWith('zuno_inv_'),
        orElse: () => null);

    if (token == null) return;
    await _handleClaim(token);
  }

  void _showManualEntry() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZunoTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ManualEntrySheet(
        onClaim: (code) {
          Navigator.pop(ctx);
          _handleClaim(code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          'Connect Partner',
          style: GoogleFonts.notoSerif(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          _ScannerOverlay(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processing) ...[
                    const SizedBox(height: 8),
                    CircularProgressIndicator(color: ZunoTheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Linking accounts…',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: Colors.white.withOpacity(0.8)),
                    ),
                  ] else ...[
                    Text(
                      'Scan your partner\'s QR code',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Manual Entry Button
                    GestureDetector(
                      onTap: _showManualEntry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Enter code manually',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Recieved a code via WhatsApp or Mail?\nTap above to enter it.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntrySheet extends StatefulWidget {
  final Function(String) onClaim;
  const _ManualEntrySheet({required this.onClaim});

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ZunoTheme.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter Invite Code',
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste the code you received from your partner.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. zuno_inv_abc... or just abc...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
              ),
              filled: true,
              fillColor: ZunoTheme.surfaceContainerLowest,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                widget.onClaim(_controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZunoTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'CONNECT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scanner Overlay (dark vignette with clear square) ────────────────────────

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const cutout = 240.0;
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _OverlayPainter(cutout: cutout),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double cutout;
  const _OverlayPainter({required this.cutout});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final center = Offset(size.width / 2, size.height / 2 - 60);
    final rect = Rect.fromCenter(center: center, width: cutout, height: cutout);

    // Draw dark overlay excluding the cutout rect
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = ZunoTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const c = 22.0; // corner length
    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;

    // Top-left
    canvas.drawLine(Offset(l, t + c), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + c, t), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r - c, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + c), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(l, b - c), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + c, b), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r - c, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - c), cornerPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) => false;
}
