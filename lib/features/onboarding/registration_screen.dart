import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import 'onboarding_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _customOccupationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _customOccupationController.dispose();
    super.dispose();
  }

  // ── Date picker helper ────────────────────────────────────────────────────

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: ZunoTheme.primary,
            onPrimary: Colors.white,
            surface: ZunoTheme.surfaceContainerLowest,
            onSurface: ZunoTheme.onSurface,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: ZunoTheme.primary,
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: ZunoTheme.surfaceContainerLowest,
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final current = ref.read(onboardingProvider).dateOfBirth;
    final picked = await _pickDate(
      initialDate: current ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5, now.month, now.day),
    );
    if (picked != null) ref.read(onboardingProvider.notifier).setDOB(picked);
  }

  void _showOccupationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OccupationSheet(
        current: ref.read(onboardingProvider).occupation,
        onSelected: (val) {
          ref.read(onboardingProvider.notifier).setOccupation(val);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GenderSheet(
        current: ref.read(onboardingProvider).gender,
        onSelected: (val) {
          ref.read(onboardingProvider.notifier).setGender(val);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  void _continue() {
    FocusScope.of(context).unfocus();
    final s = ref.read(onboardingProvider);
    if (!s.isPersonalInfoValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all fields before continuing.',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    context.go('/onboarding/status');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Top bar ────────────────────────────────────────────────
              Row(
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.arrow_back, color: ZunoTheme.primary),
                    onPressed: () => context.go('/signup'),
                  ),
                  const Spacer(),
                  Text(
                    'Zuno',
                    style: GoogleFonts.notoSerif(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: ZunoTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 40),

              // ── Hero ───────────────────────────────────────────────────
              Text(
                'Tell us\nabout you',
                style: GoogleFonts.notoSerif(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'YOUR STORY, YOUR CIRCLE.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: ZunoTheme.onSurfaceVariant.withAlpha(178),
                ),
              ),
              const SizedBox(height: 36),

              // ── Card 1: Personal Info ──────────────────────────────────
              _SectionCard(
                children: [
                  // Name
                  _FieldLabel('FULL NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: ref.read(onboardingProvider.notifier).setName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ZunoTheme.onSurface,
                    ),
                    decoration: _inputDecoration('e.g. Amara Singh'),
                  ),
                  const SizedBox(height: 24),

                  // Date of Birth
                  _FieldLabel('DATE OF BIRTH'),
                  const SizedBox(height: 8),
                  _DateTile(
                    date: s.dateOfBirth,
                    hint: 'Select your birth date',
                    onTap: _pickDOB,
                    trailingIcon: Icons.cake_outlined,
                  ),
                  const SizedBox(height: 24),

                  // Gender select
                  _FieldLabel('GENDER'),
                  const SizedBox(height: 8),
                  _DropdownTile(
                    value: s.gender.isEmpty ? null : s.gender,
                    hint: 'Select gender',
                    onTap: _showGenderPicker,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 24),

                  // Occupation dropdown
                  _FieldLabel('OCCUPATION'),
                  const SizedBox(height: 8),
                  _DropdownTile(
                    value: s.occupation.isEmpty ? null : s.occupation,
                    hint: 'Select occupation',
                    onTap: _showOccupationPicker,
                  ),

                  // Custom occupation field — shown when "Other" selected
                  if (s.occupation == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customOccupationController,
                      textCapitalization: TextCapitalization.words,
                      onChanged:
                          ref.read(onboardingProvider.notifier).setCustomOccupation,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: ZunoTheme.onSurface,
                      ),
                      decoration: _inputDecoration('Describe your occupation…'),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 36),

              // ── CTA ────────────────────────────────────────────────────
              _GradientCta(
                label: 'Continue',
                isLoading: s.isLoading,
                onTap: s.isLoading ? null : _continue,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 13, color: ZunoTheme.tertiary),
                  const SizedBox(width: 6),
                  Text(
                    'YOUR DATA STAYS PRIVATE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: ZunoTheme.onSurfaceVariant.withAlpha(127),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: ZunoTheme.onSurfaceVariant.withAlpha(89),
          fontWeight: FontWeight.w400,
        ),
      );
}

// ── Occupation Bottom Sheet ───────────────────────────────────────────────────

class _OccupationSheet extends StatefulWidget {
  final String? current;
  final ValueChanged<String> onSelected;
  const _OccupationSheet({this.current, required this.onSelected});

  @override
  State<_OccupationSheet> createState() => _OccupationSheetState();
}

class _OccupationSheetState extends State<_OccupationSheet> {
  final _searchController = TextEditingController();
  List<String> _filtered = kOccupations;

  void _onSearch(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _filtered = query.isEmpty
          ? kOccupations
          : kOccupations
              .where((o) => o.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ZunoTheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OCCUPATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: ZunoTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, color: ZunoTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        color: ZunoTheme.onSurfaceVariant.withAlpha(102)),
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: ZunoTheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final isSelected = item == widget.current;
                return GestureDetector(
                  onTap: () => widget.onSelected(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ZunoTheme.primaryFixed.withAlpha(178)
                          : ZunoTheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: ZunoTheme.primary.withAlpha(76),
                              width: 1.5)
                          : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? ZunoTheme.primary
                                  : ZunoTheme.onSurface,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              size: 18, color: ZunoTheme.tertiary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gender Bottom Sheet ───────────────────────────────────────────────────────

class _GenderSheet extends StatelessWidget {
  final String? current;
  final ValueChanged<String> onSelected;
  const _GenderSheet({this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ZunoTheme.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'SELECT GENDER',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: ZunoTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: kGenders.length,
            itemBuilder: (_, i) {
              final item = kGenders[i];
              final isSelected = item == current;
              return GestureDetector(
                onTap: () => onSelected(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ZunoTheme.primaryFixed.withAlpha(178)
                        : ZunoTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: ZunoTheme.primary.withAlpha(76), width: 1.5)
                        : Border.all(color: Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        item,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? ZunoTheme.primary
                              : ZunoTheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            size: 20, color: ZunoTheme.tertiary),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withAlpha(10),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.8,
        color: ZunoTheme.onSurfaceVariant,
      ),
    );
  }
}

/// A tappable row that shows a date or a placeholder hint.
class _DateTile extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final VoidCallback onTap;
  final IconData trailingIcon;
  const _DateTile(
      {this.date,
      required this.hint,
      required this.onTap,
      required this.trailingIcon});

  String _format(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: hasDate
              ? Border.all(color: ZunoTheme.primary.withAlpha(76), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              trailingIcon,
              size: 16,
              color: hasDate
                  ? ZunoTheme.primary
                  : ZunoTheme.onSurfaceVariant.withAlpha(127),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasDate ? _format(date!) : hint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                  color: hasDate
                      ? ZunoTheme.onSurface
                      : ZunoTheme.onSurfaceVariant.withAlpha(114),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ZunoTheme.onSurfaceVariant.withAlpha(102),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable "dropdown" tile that opens the occupation bottom sheet.
class _DropdownTile extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final IconData icon;
  const _DropdownTile({
    this.value,
    required this.hint,
    required this.onTap,
    this.icon = Icons.work_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: hasValue
              ? Border.all(color: ZunoTheme.primary.withAlpha(76), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: hasValue
                  ? ZunoTheme.primary
                  : ZunoTheme.onSurfaceVariant.withAlpha(127),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? value! : hint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue
                      ? ZunoTheme.onSurface
                      : ZunoTheme.onSurfaceVariant.withAlpha(114),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: ZunoTheme.onSurfaceVariant.withAlpha(153),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient CTA ──────────────────────────────────────────────────────────────

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
          boxShadow: [
            if (onTap != null)
              BoxShadow(
                color: ZunoTheme.primary.withAlpha(51),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
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

