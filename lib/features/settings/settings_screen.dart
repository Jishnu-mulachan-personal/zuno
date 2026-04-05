import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final hasParter = profile?.partnerName != null;

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      appBar: AppBar(
        backgroundColor: ZunoTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: ZunoTheme.primary, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.notoSerif(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // ── Account ───────────────────────────────────────────────────────
          const _SectionHeader(label: 'ACCOUNT'),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.person_outline_rounded,
            label: 'Display Name',
            value: profile?.displayName ?? '—',
            iconBg: ZunoTheme.primaryFixed,
            iconColor: ZunoTheme.primary,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.translate_rounded,
            label: 'Zuno AI Language',
            value: profile?.preferredLanguage ?? 'English',
            iconBg: ZunoTheme.secondaryContainer,
            iconColor: ZunoTheme.secondary,
            onTap: () => _showLanguageSelector(context, ref),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.favorite_border_rounded,
            label: 'Relationship Status',
            value: _capitalize(profile?.relationshipStatus ?? 'single'),
            iconBg: ZunoTheme.tertiaryFixed,
            iconColor: ZunoTheme.tertiary,
            onTap: () => _showStatusSelector(context, ref),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.security_rounded,
            label: 'Privacy Preference',
            value: _capitalize(profile?.privacyPreference ?? 'balanced'),
            iconBg: ZunoTheme.secondaryContainer,
            iconColor: ZunoTheme.secondary,
            onTap: () => _showPrivacySelector(context, ref),
          ),
          const SizedBox(height: 32),

          // ── Partner ───────────────────────────────────────────────────────
          const _SectionHeader(label: 'PARTNER'),
          const SizedBox(height: 10),
          if (hasParter) ...[
            _InfoTile(
              icon: Icons.favorite_rounded,
              label: 'Paired with',
              value: profile!.partnerName!,
              iconBg: ZunoTheme.primaryFixed,
              iconColor: ZunoTheme.primary,
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.link_off_rounded,
              label: 'Unpair Partner',
              subtitle: 'Disconnect your partner',
              tileColor: const Color(0xFFE65100),
              onTap: () => _confirmAction(
                context: context,
                icon: Icons.link_off_rounded,
                iconColor: const Color(0xFFE65100),
                title: 'Unpair Partner?',
                body:
                    'This will disconnect you and your partner. You can re-pair at any time.',
                confirmLabel: 'Unpair',
                confirmColor: const Color(0xFFE65100),
                onConfirm: () async {
                  final ok =
                      await ref.read(settingsProvider.notifier).unpairPartner();
                  if (context.mounted) {
                    if (ok) {
                      context.go('/dashboard');
                      _snack(context, true, success: 'Partner unpaired 👋');
                    } else {
                      _snack(context, false,
                          failure:
                              ref.read(settingsProvider).message ?? 'Error');
                    }
                  }
                },
              ),
            ),
          ] else ...[
            _InfoTile(
              icon: Icons.person_search_rounded,
              label: 'No partner connected',
              value: 'Tap to pair',
              iconBg: ZunoTheme.surfaceContainerHigh,
              iconColor: ZunoTheme.onSurfaceVariant,
              onTap: () => context.push('/us'),
            ),
          ],
          const SizedBox(height: 32),

          // ── Session ───────────────────────────────────────────────────────
          const _SectionHeader(label: 'SESSION'),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            subtitle: 'Return to the welcome screen',
            tileColor: ZunoTheme.onSurfaceVariant,
            onTap: () => _confirmAction(
              context: context,
              icon: Icons.logout_rounded,
              iconColor: ZunoTheme.onSurfaceVariant,
              title: 'Sign Out?',
              body: 'You will be returned to the welcome screen.',
              confirmLabel: 'Sign Out',
              confirmColor: ZunoTheme.onSurface,
              onConfirm: () async {
                await Supabase.instance.client.auth.signOut();
                try {
                  await GoogleSignIn().signOut();
                } catch (_) {}
                if (context.mounted) context.go('/');
              },
            ),
          ),
          const SizedBox(height: 32),

          // ── Danger zone ───────────────────────────────────────────────────
          const _SectionHeader(label: 'DANGER ZONE'),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.delete_forever_rounded,
            label: 'Delete Account',
            subtitle: 'Permanently remove all your data',
            tileColor: ZunoTheme.error,
            onTap: () => _confirmAction(
              context: context,
              icon: Icons.delete_forever_rounded,
              iconColor: ZunoTheme.error,
              title: 'Delete Account?',
              body:
                  'All your logs, insights, and history will be permanently deleted. This cannot be undone.',
              confirmLabel: 'Delete my account',
              confirmColor: ZunoTheme.error,
              onConfirm: () async {
                final ok =
                    await ref.read(settingsProvider.notifier).deleteAccount();
                if (context.mounted) {
                  if (ok) {
                    context.go('/');
                  } else {
                    _snack(context, false,
                        failure:
                            ref.read(settingsProvider).message ?? 'Error');
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void _snack(BuildContext context, bool ok,
    {String success = 'Done', String failure = 'Something went wrong'}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(ok ? success : failure,
        style: GoogleFonts.plusJakartaSans()),
    backgroundColor: ok ? ZunoTheme.tertiary : ZunoTheme.error,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

void _confirmAction({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String body,
  required String confirmLabel,
  required Color confirmColor,
  required Future<void> Function() onConfirm,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ZunoTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _ConfirmSheet(
      icon: icon,
      iconColor: iconColor,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
      onConfirm: () async {
        Navigator.pop(ctx);
        await onConfirm();
      },
    ),
  );
}

void _showLanguageSelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ZunoTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => const _LanguageSelectorSheet(),
  );
}

void _showStatusSelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ZunoTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => const _StatusSelectorSheet(),
  );
}

void _showPrivacySelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ZunoTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => const _PrivacySelectorSheet(),
  );
}

// ── UI Widgets ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurface)),
                  Text(value,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color:
                              ZunoTheme.onSurfaceVariant.withOpacity(0.6))),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: ZunoTheme.outlineVariant, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tileColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tileColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tileColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tileColor.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: tileColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: tileColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tileColor)),
                  Text(subtitle,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: tileColor.withOpacity(0.6))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: tileColor, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Confirm Bottom Sheet ──────────────────────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  final Future<void> Function() onConfirm;

  const _ConfirmSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 28, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: ZunoTheme.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(99)),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: widget.iconColor.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(widget.icon, color: widget.iconColor, size: 30),
          ),
          const SizedBox(height: 20),
          Text(widget.title,
              style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(widget.body,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
                  height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          // Confirm button
          GestureDetector(
            onTap: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    await widget.onConfirm();
                    if (mounted) setState(() => _loading = false);
                  },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                  color: widget.confirmColor,
                  borderRadius: BorderRadius.circular(99)),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(widget.confirmLabel,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Cancel
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99)),
              child: Center(
                child: Text('Cancel',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ZunoTheme.onSurfaceVariant)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelectorSheet extends ConsumerWidget {
  const _LanguageSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final current = profile?.preferredLanguage ?? 'English';
    final languages = ['English', 'Hindi', 'Malayalam', 'Kannada'];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: ZunoTheme.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(99)),
          ),
          Text('Select Language',
              style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface)),
          const SizedBox(height: 8),
          Text('AI insights will be generated in your selected language.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 24),
          ...languages.map((lang) {
            final isSelected = current == lang;
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                if (isSelected) return;
                final ok =
                    await ref.read(settingsProvider.notifier).updateLanguage(lang);
                if (context.mounted) {
                  _snack(context, ok,
                      success: 'Language switched to $lang');
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZunoTheme.primary.withOpacity(0.08)
                      : ZunoTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? ZunoTheme.primary.withOpacity(0.3)
                        : ZunoTheme.outlineVariant.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Text(lang,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? ZunoTheme.primary
                                : ZunoTheme.onSurface)),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: ZunoTheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatusSelectorSheet extends ConsumerWidget {
  const _StatusSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final current = profile?.relationshipStatus ?? 'single';
    final statuses = ['single', 'committed', 'engaged', 'married'];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: ZunoTheme.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(99)),
          ),
          Text('Relationship Status',
              style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface)),
          const SizedBox(height: 8),
          Text('Change your relationship status.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 24),
          ...statuses.map((status) {
            final isSelected = current == status;
            final label = status[0].toUpperCase() + status.substring(1);
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                if (isSelected) return;
                final ok = await ref
                    .read(settingsProvider.notifier)
                    .updateRelationshipStatus(status);
                if (context.mounted) {
                  _snack(
                    context, 
                    ok,
                    success: 'Status updated to $label',
                    failure: ref.read(settingsProvider).message ?? 'Error',
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZunoTheme.primary.withOpacity(0.08)
                      : ZunoTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? ZunoTheme.primary.withOpacity(0.3)
                        : ZunoTheme.outlineVariant.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Text(label,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? ZunoTheme.primary
                                : ZunoTheme.onSurface)),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: ZunoTheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PrivacySelectorSheet extends ConsumerWidget {
  const _PrivacySelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final current = profile?.privacyPreference ?? 'balanced';
    final options = [
      {
        'id': 'private',
        'title': 'Mostly private',
        'sub': 'Keep almost everything to myself'
      },
      {
        'id': 'balanced',
        'title': 'Balanced',
        'sub': 'Share essential moods and trends'
      },
      {
        'id': 'shared',
        'title': 'Mostly shared',
        'sub': 'Open transparency with partner'
      },
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: ZunoTheme.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(99)),
          ),
          Text('Privacy Preference',
              style: GoogleFonts.notoSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface)),
          const SizedBox(height: 8),
          Text('Choose how much you share with your partner.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 24),
          ...options.map((opt) {
            final isSelected = current == opt['id'];
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                if (isSelected) return;
                final ok = await ref
                    .read(settingsProvider.notifier)
                    .updatePrivacyPreference(opt['id']!);
                if (context.mounted) {
                  _snack(context, ok,
                      success: 'Privacy updated to ${opt['title']}',
                      failure: ref.read(settingsProvider).message ?? 'Error');
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZunoTheme.primary.withOpacity(0.08)
                      : ZunoTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? ZunoTheme.primary.withOpacity(0.3)
                        : ZunoTheme.outlineVariant.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt['title']!,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? ZunoTheme.primary
                                      : ZunoTheme.onSurface)),
                          Text(opt['sub']!,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: ZunoTheme.onSurfaceVariant
                                      .withOpacity(0.6))),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: ZunoTheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
