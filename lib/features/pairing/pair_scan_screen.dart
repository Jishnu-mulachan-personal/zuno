import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';
import 'pair_provider.dart';

class PairScanScreen extends ConsumerStatefulWidget {
  const PairScanScreen({super.key});

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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final token = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.startsWith('zuno_inv_'),
            orElse: () => null);

    if (token == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    final success =
        await ref.read(claimProvider.notifier).claimToken(token);
    final claimState = ref.read(claimProvider);

    if (!mounted) return;

    if (success) {
      // Invalidate profile so dashboard refreshes with partner name
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(claimState.message ?? 'Paired! 💚',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.tertiary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      // Pop back to the You screen
      if (context.mounted) context.go('/you');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(claimState.message ?? 'Something went wrong.',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      // Allow another scan attempt
      setState(() => _processing = false);
      await _controller.start();
    }
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Scan Partner\'s Code',
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
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with cutout
          _ScannerOverlay(),
          // Bottom instruction card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24,
                  MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processing) ...[
                    const SizedBox(height: 8),
                    const CircularProgressIndicator(color: ZunoTheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Linking accounts…',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8)),
                    ),
                  ] else ...[
                    Text(
                      'Point your camera at\nyour partner\'s QR code',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The code is valid for 10 minutes and one use only.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
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
    final rect = Rect.fromCenter(
        center: center, width: cutout, height: cutout);

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
