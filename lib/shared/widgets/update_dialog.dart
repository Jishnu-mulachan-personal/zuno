import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';

class UpdateDialog extends StatelessWidget {
  final String latestVersion;
  final String updateUrl;
  final String? releaseNotes;
  final VoidCallback onRemindLater;

  const UpdateDialog({
    super.key,
    required this.latestVersion,
    required this.updateUrl,
    required this.onRemindLater,
    this.releaseNotes,
  });

  Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(updateUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $updateUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: ZunoTheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: ZunoTheme.primary.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.primary.withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon header
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ZunoTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: ZunoTheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Update Available!',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: ZunoTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Version info
            Text(
              'A newer version ($latestVersion) is available with improvements and new features.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.5,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),

            if (releaseNotes != null && releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New:",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: ZunoTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      releaseNotes!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.5,
                        color: ZunoTheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Primary action: Update
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _launchUpdateUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZunoTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  'Update Now',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary action: Remind later
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () {
                  onRemindLater();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  'Remind Later',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

