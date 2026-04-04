import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import 'onboarding_provider.dart';

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  static const _statuses = [
    ('single', 'Single', 'Focusing on myself'),
    ('committed', 'Committed', 'Building something special'),
    ('engaged', 'Engaged', 'Planning our future'),
    ('married', 'Married', 'Sharing a life together'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(onboardingProvider);
    final selected = s.relationshipStatus;

    Future<void> handleContinue() async {
      if (selected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select your status',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: ZunoTheme.error,
          ),
        );
        return;
      }

      try {
        final currentStatus = ref.read(onboardingProvider).relationshipStatus;
        await ref.read(onboardingProvider.notifier).submitProfile();
        
        if (context.mounted) {
          if (currentStatus == 'single') {
            context.go('/onboarding/goals');
          } else {
            context.go('/onboarding/pair-choice');
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}',
                  style: GoogleFonts.plusJakartaSans()),
              backgroundColor: ZunoTheme.error,
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.arrow_back, color: ZunoTheme.primary),
                onPressed: () => context.go('/onboarding/register'),
              ),
              const SizedBox(height: 32),
              Text(
                'What\'s your\nstatus?',
                style: GoogleFonts.notoSerif(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: _statuses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final (id, label, desc) = _statuses[i];
                    final isSelected = selected == id;

                    return GestureDetector(
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .setRelationshipStatus(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ZunoTheme.primaryFixed.withAlpha(51)
                              : ZunoTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? ZunoTheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ZunoTheme.onSurface.withAlpha(10),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: ZunoTheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    desc,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: ZunoTheme.onSurfaceVariant
                                          .withAlpha(153),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: ZunoTheme.tertiary, size: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _GradientCta(
                label: 'Continue',
                isLoading: s.isLoading,
                onTap: s.isLoading ? null : handleContinue,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  const _GradientCta({required this.label, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? ZunoTheme.primaryGradient
              : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade300]),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
