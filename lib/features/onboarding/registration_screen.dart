import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../auth/user_repository.dart';

// ── Occupation options ────────────────────────────────────────────────────────

const _kOccupations = [
  'Student',
  'Teacher / Educator',
  'Engineer',
  'Doctor / Healthcare',
  'Lawyer',
  'Accountant / Finance',
  'Business Owner',
  'Artist / Designer',
  'Writer / Journalist',
  'Software Developer',
  'Homemaker',
  'Retired',
  'Other',
];

const _kGenders = [
  'Male',
  'Female',
  'Non-binary',
  'Prefer not to say',
];

// ── State ─────────────────────────────────────────────────────────────────────

class _RegState {
  final String name;
  final DateTime? dateOfBirth;
  final String occupation; // selected from list OR 'Other'
  final String customOccupation; // typed value when occupation == 'Other'
  final DateTime? marriedOn;
  final String gender;
  final String relationshipDistance;
  final bool isLoading;
  final String? error;

  const _RegState({
    this.name = '',
    this.dateOfBirth,
    this.occupation = '',
    this.customOccupation = '',
    this.marriedOn,
    this.gender = '',
    this.relationshipDistance = 'moderate',
    this.isLoading = false,
    this.error,
  });

  _RegState copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? occupation,
    String? customOccupation,
    DateTime? marriedOn,
    bool? clearMarriedOn,
    String? gender,
    String? relationshipDistance,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return _RegState(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      occupation: occupation ?? this.occupation,
      customOccupation: customOccupation ?? this.customOccupation,
      marriedOn:
          (clearMarriedOn == true) ? null : (marriedOn ?? this.marriedOn),
      gender: gender ?? this.gender,
      relationshipDistance: relationshipDistance ?? this.relationshipDistance,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  String get effectiveOccupation =>
      occupation == 'Other' ? customOccupation : occupation;

  bool get isValid {
    return name.trim().isNotEmpty &&
        dateOfBirth != null &&
        gender.isNotEmpty &&
        effectiveOccupation.trim().isNotEmpty &&
        marriedOn != null;
  }
}

class _RegNotifier extends StateNotifier<_RegState> {
  final UserRepository _userRepo;
  
  _RegNotifier(this._userRepo) : super(const _RegState());

  void setName(String v) => state = state.copyWith(name: v, clearError: true);
  void setDOB(DateTime v) =>
      state = state.copyWith(dateOfBirth: v, clearError: true);
  void setOccupation(String v) =>
      state = state.copyWith(occupation: v, clearError: true);
  void setCustomOccupation(String v) =>
      state = state.copyWith(customOccupation: v, clearError: true);
  void setMarriedOn(DateTime v) =>
      state = state.copyWith(marriedOn: v, clearError: true);
  void setGender(String v) => state = state.copyWith(gender: v, clearError: true);
  void setRelationshipDistance(String v) =>
      state = state.copyWith(relationshipDistance: v);

  Future<void> submit() async {
    if (!state.isValid) {
      state = state.copyWith(
          error: 'Please complete all fields before continuing.');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      await _userRepo.createUserProfile(
        name: state.name,
        dateOfBirth: state.dateOfBirth!,
        occupation: state.effectiveOccupation,
        marriedOn: state.marriedOn!,
        relationshipDistance: state.relationshipDistance,
        gender: state.gender,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final _regProvider = StateNotifierProvider.autoDispose<_RegNotifier, _RegState>(
  (ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    return _RegNotifier(userRepo);
  },
);

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
          colorScheme: const ColorScheme.light(
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
          dialogTheme: const DialogThemeData(
            backgroundColor: ZunoTheme.surfaceContainerLowest,
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final current = ref.read(_regProvider).dateOfBirth;
    final picked = await _pickDate(
      initialDate: current ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5, now.month, now.day),
    );
    if (picked != null) ref.read(_regProvider.notifier).setDOB(picked);
  }

  Future<void> _pickMarriedOn() async {
    final now = DateTime.now();
    final current = ref.read(_regProvider).marriedOn;
    final picked = await _pickDate(
      initialDate: current ?? DateTime(now.year - 5),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) ref.read(_regProvider.notifier).setMarriedOn(picked);
  }

  void _showOccupationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OccupationSheet(
        current: ref.read(_regProvider).occupation,
        onSelected: (val) {
          ref.read(_regProvider.notifier).setOccupation(val);
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
        current: ref.read(_regProvider).gender,
        onSelected: (val) {
          ref.read(_regProvider.notifier).setGender(val);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final notifier = ref.read(_regProvider.notifier);
    await notifier.submit();
    if (!mounted) return;
    final err = ref.read(_regProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err, style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      context.go('/onboarding/invite');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_regProvider);

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
                        const Icon(Icons.arrow_back, color: ZunoTheme.primary),
                    onPressed: () => context.go('/otp'),
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
                    onChanged: ref.read(_regProvider.notifier).setName,
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
                          ref.read(_regProvider.notifier).setCustomOccupation,
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

              const SizedBox(height: 16),

              // ── Card 2: Married On ─────────────────────────────────────
              _SectionCard(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_border_rounded,
                          size: 16, color: ZunoTheme.primary),
                      const SizedBox(width: 8),
                      _FieldLabel('MARRIED ON'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When did you tie the knot?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: ZunoTheme.onSurfaceVariant.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateTile(
                    date: s.marriedOn,
                    hint: 'Select your marriage date',
                    onTap: _pickMarriedOn,
                    trailingIcon: Icons.calendar_month_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Card 3: Relationship Distance ──────────────────────────
              _SectionCard(
                children: [
                  _FieldLabel('HOW DISTANT IS THE RELATIONSHIP?'),
                  const SizedBox(height: 6),
                  Text(
                    'Select how closely connected you feel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: ZunoTheme.onSurfaceVariant.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _RelationshipDistancePicker(
                    selected: s.relationshipDistance,
                    onChanged:
                        ref.read(_regProvider.notifier).setRelationshipDistance,
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // ── CTA ────────────────────────────────────────────────────
              _GradientCta(
                label: 'Save & Continue',
                isLoading: s.isLoading,
                onTap: s.isLoading ? null : _submit,
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
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
  List<String> _filtered = _kOccupations;

  void _onSearch(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _filtered = query.isEmpty
          ? _kOccupations
          : _kOccupations
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
      decoration: const BoxDecoration(
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
                    prefixIcon: const Icon(Icons.search,
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
                          const Icon(Icons.check_circle_rounded,
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
      decoration: const BoxDecoration(
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
            itemCount: _kGenders.length,
            itemBuilder: (_, i) {
              final item = _kGenders[i];
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
                        const Icon(Icons.check_circle_rounded,
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

// ── Relationship Distance ─────────────────────────────────────────────────────

const _kDistances = [
  ('close', 'Close', Icons.favorite_rounded, 'We speak often'),
  ('moderate', 'Moderate', Icons.people_outline_rounded, 'Occasional touch'),
  ('distant', 'Distant', Icons.explore_outlined, 'Rarely in contact'),
];

class _RelationshipDistancePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RelationshipDistancePicker(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kDistances.map((d) {
        final (id, label, icon, desc) = d;
        final isSelected = selected == id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => onChanged(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? ZunoTheme.primaryFixed.withAlpha(153)
                    : ZunoTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: isSelected
                    ? Border.all(
                        color: ZunoTheme.primary.withAlpha(76), width: 1.5)
                    : Border.all(color: Colors.transparent, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ZunoTheme.primary.withAlpha(31)
                          : ZunoTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 20,
                        color: isSelected
                            ? ZunoTheme.primary
                            : ZunoTheme.onSurfaceVariant.withAlpha(127)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? ZunoTheme.primary
                                : ZunoTheme.onSurface,
                          ),
                        ),
                        Text(
                          desc,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: ZunoTheme.onSurfaceVariant.withAlpha(153),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 20, color: ZunoTheme.tertiary),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
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
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2.2,
                  ),
                ),
        ),
      ),
    );
  }
}
