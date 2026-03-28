import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  String? _selectedStatus;

  static const _statuses = [
    _RelStatus('dating', 'Dating', 'Exploring together'),
    _RelStatus('engaged', 'Engaged', 'Building the future'),
    _RelStatus('married', 'Married', 'Lifelong commitment'),
    _RelStatus('growing', 'Growing', 'Trying for a baby'),
  ];

  Future<void> _inviteViaWhatsApp() async {
    const message =
        "Join me on Zuno – our private relationship companion! 💑 Here's your invite link: https://zuno.app/join";
    final uri =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Stack(
        children: [
          // Hearth glow bg
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.5),
                  radius: 1.0,
                  colors: [
                    ZunoTheme.primaryContainer.withOpacity(0.15),
                    ZunoTheme.surface,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Progress + logo
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Zuno',
                          style: GoogleFonts.notoSerif(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: ZunoTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ProgressDots(active: 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Hero image
                  // ClipRRect(
                  //   borderRadius: BorderRadius.circular(32),
                  //   child: AspectRatio(
                  //     aspectRatio: 4 / 3,
                  //     child: Stack(
                  //       fit: StackFit.expand,
                  //       children: [
                  //         Image.network(
                  //           'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=600&q=80',
                  //           fit: BoxFit.cover,
                  //           errorBuilder: (_, __, ___) =>
                  //               Container(color: ZunoTheme.primaryFixed),
                  //         ),
                  //         Center(
                  //           child: Container(
                  //             padding: const EdgeInsets.all(24),
                  //             decoration: BoxDecoration(
                  //               color: ZunoTheme.surface.withOpacity(0.82),
                  //               shape: BoxShape.circle,
                  //               boxShadow: [
                  //                 BoxShadow(
                  //                   color:
                  //                       ZunoTheme.onSurface.withOpacity(0.05),
                  //                   blurRadius: 20,
                  //                 ),
                  //               ],
                  //             ),
                  //             child: const Icon(
                  //               Icons.favorite,
                  //               color: ZunoTheme.primary,
                  //               size: 48,
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 28),
                  Text(
                    'Invite Your Person',
                    style: GoogleFonts.notoSerif(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Zuno works solo, but it\'s built for two. Invite your partner to start your shared journey.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: ZunoTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Relationship status
                  Text(
                    'RELATIONSHIP STATUS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: ZunoTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: _statuses.map((s) {
                      final selected = _selectedStatus == s.value;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStatus = s.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selected
                                ? ZunoTheme.surfaceContainerLowest
                                : ZunoTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? ZunoTheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          ZunoTheme.primary.withOpacity(0.08),
                                      blurRadius: 12,
                                    )
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (selected)
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: ZunoTheme.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    s.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: ZunoTheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.subtitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: ZunoTheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w300,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  // Invite CTA
                  GestureDetector(
                    onTap: _inviteViaWhatsApp,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: ZunoTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: ZunoTheme.primary.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'INVITE VIA WHATSAPP',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/onboarding/goals'),
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: ZunoTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Feel closer. Every day.',
                      style: GoogleFonts.notoSerif(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: ZunoTheme.primary.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelStatus {
  final String value, label, subtitle;
  const _RelStatus(this.value, this.label, this.subtitle);
}

class _ProgressDots extends StatelessWidget {
  final int active;
  const _ProgressDots({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0 == active, narrow: true),
        const SizedBox(width: 4),
        _dot(1 == active),
        const SizedBox(width: 4),
        _dot(2 == active, narrow: true),
      ],
    );
  }

  Widget _dot(bool active, {bool narrow = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : (narrow ? 16 : 16),
      height: 4,
      decoration: BoxDecoration(
        color: active
            ? ZunoTheme.primary
            : ZunoTheme.outlineVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
