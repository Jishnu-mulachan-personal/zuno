import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../auth/user_repository.dart';
import 'onboarding_provider.dart';

class RelationshipQuestionsScreen extends ConsumerStatefulWidget {
  const RelationshipQuestionsScreen({super.key});

  @override
  ConsumerState<RelationshipQuestionsScreen> createState() =>
      _RelationshipQuestionsScreenState();
}

class _RelationshipQuestionsScreenState
    extends ConsumerState<RelationshipQuestionsScreen> {
  DateTime? _marriedOn;
  String? _distance;
  bool _isLoading = false;

  final _distances = [
    ('close', 'Close', Icons.favorite_rounded, 'We speak often'),
    ('moderate', 'Moderate', Icons.people_outline_rounded, 'Occasional touch'),
    ('distant', 'Distant', Icons.explore_outlined, 'Rarely in contact'),
  ];

  Future<void> _pickMarriedOn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _marriedOn ?? DateTime(now.year - 5),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: ZunoTheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _marriedOn = picked);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final s = ref.read(onboardingProvider);
    if (s.relationshipStatus == 'married' && _marriedOn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your marriage date')),
      );
      return;
    }
    if (_distance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select how distant the relationship is')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      
      // 1. Get current user's relationship_id
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final userRow = await Supabase.instance.client
          .from('users')
          .select('relationship_id')
          .eq('id', userId)
          .single();
      
      final relId = userRow['relationship_id'] as String;

      // 2. Update relationship details
      await userRepo.updateRelationshipDetails(
        relationshipId: relId,
        marriedOn: _marriedOn,
        relationshipDistance: _distance,
      );

      if (mounted) context.go('/onboarding/goals');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(onboardingProvider);
    final isMarried = s.relationshipStatus == 'married';

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                'Tell us more\nabout you two',
                style: GoogleFonts.notoSerif(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 32),

              if (isMarried) ...[
                Text(
                  'MARRIED ON',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: ZunoTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickMarriedOn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: ZunoTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _marriedOn != null ? ZunoTheme.primary : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ZunoTheme.onSurface.withAlpha(5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20, color: ZunoTheme.primary),
                        const SizedBox(width: 16),
                        Text(
                          _marriedOn == null
                              ? 'Select date'
                              : '${_marriedOn!.day}/${_marriedOn!.month}/${_marriedOn!.year}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: _marriedOn == null ? FontWeight.w400 : FontWeight.w600,
                            color: ZunoTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              Text(
                'RELATIONSHIP DISTANCE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: ZunoTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ..._distances.map((d) {
                final (id, label, icon, desc) = d;
                final isSel = _distance == id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _distance = id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSel
                            ? ZunoTheme.primaryFixed.withAlpha(51)
                            : ZunoTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel ? ZunoTheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZunoTheme.onSurface.withAlpha(5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: isSel ? ZunoTheme.primary : ZunoTheme.onSurfaceVariant),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                    color: ZunoTheme.onSurface,
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: ZunoTheme.onSurfaceVariant.withAlpha(153),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Icon(Icons.check_circle, color: ZunoTheme.tertiary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 48),
              _GradientCta(
                label: 'Finish Setup',
                isLoading: _isLoading,
                onTap: _isLoading ? null : _submit,
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
