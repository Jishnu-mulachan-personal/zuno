import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../features/settings/profile_image_service.dart';
import 'zuno_image.dart';

class ProfileAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String name;

  const ProfileAvatar({
    super.key,
    this.url,
    required this.radius,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: ZunoTheme.primaryFixed.withOpacity(0.5),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: radius * 0.6,
            fontWeight: FontWeight.w700,
            color: ZunoTheme.primary,
          ),
        ),
      );
    }

    return ZunoImage(
      pathOrUrl: url!,
      bucket: ProfileImageService.bucketAvatars,
      width: radius * 2,
      height: radius * 2,
      borderRadius: radius * 2, // Large enough to be circular
      isAvatar: true,
    );
  }
}
