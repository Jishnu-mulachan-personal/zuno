import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class _CycleRegState {
  final DateTime? lastPeriodDate;
  final int cycleLength;
  final int periodDuration;
  final bool isLoading;
  final String? error;

  const _CycleRegState({
    this.lastPeriodDate,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.isLoading = false,
    this.error,
  });

  _CycleRegState copyWith({
    DateTime? lastPeriodDate,
    int? cycleLength,
    int? periodDuration,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return _CycleRegState(
      lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodDuration: periodDuration ?? this.periodDuration,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isValid => lastPeriodDate != null;
}

class _CycleRegNotifier extends StateNotifier<_CycleRegState> {
  final Ref ref;
  _CycleRegNotifier(this.ref) : super(const _CycleRegState());

  void setLastPeriodDate(DateTime v) =>
      state = state.copyWith(lastPeriodDate: v, clearError: true);
  void setCycleLength(double v) =>
      state = state.copyWith(cycleLength: v.toInt());
  void setPeriodDuration(double v) =>
      state = state.copyWith(periodDuration: v.toInt());

  Future<void> submit(String userId) async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please select your last period date.');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;

      final dateStr = state.lastPeriodDate!.toIso8601String().split('T')[0];

      // 1. Add to cycle_data table (prediction anchor)
      await supabase.from('cycle_data').upsert({
        'user_id': userId,
        'last_period_date': dateStr,
        'cycle_length': state.cycleLength,
        'period_duration': state.periodDuration,
        'is_tracking': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // 2. Add to cycle_periods (historical log)
      await supabase.from('cycle_periods').upsert({
        'user_id': userId,
        'start_date': dateStr,
      }, onConflict: 'user_id, start_date');

      state = state.copyWith(isLoading: false);
      // Invalidate dashboard provider so it fetches the new cycle data
      ref.invalidate(userProfileProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final _cycleRegProvider =
    StateNotifierProvider.autoDispose<_CycleRegNotifier, _CycleRegState>(
  (ref) => _CycleRegNotifier(ref),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class CycleRegistrationScreen extends ConsumerStatefulWidget {
  const CycleRegistrationScreen({super.key});

  @override
  ConsumerState<CycleRegistrationScreen> createState() =>
      _CycleRegistrationScreenState();
}

class _CycleRegistrationScreenState
    extends ConsumerState<CycleRegistrationScreen> {
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final first = now.subtract(const Duration(days: 90));
    final current = ref.read(_cycleRegProvider).lastPeriodDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: first.isAfter(current) ? current : first,
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: ZunoTheme.primary,
            onPrimary: Colors.white,
            surface: ZunoTheme.surfaceContainerLowest,
            onSurface: ZunoTheme.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(_cycleRegProvider.notifier).setLastPeriodDate(picked);
    }
  }

  Future<void> _submit() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      _showError('Profile not loaded. Please try again.');
      return;
    }

    final notifier = ref.read(_cycleRegProvider.notifier);
    try {
      await notifier.submit(profile.id);
      if (!mounted) return;
      final err = ref.read(_cycleRegProvider).error;
      if (err != null) {
        _showError(err);
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: ZunoTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(_cycleRegProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ZunoTheme.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Track your\ncycle',
                style: GoogleFonts.notoSerif(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PERSONALIZED INSIGHTS FOR YOUR BODY.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: ZunoTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // Date Picker
              _Label('LAST PERIOD DATE'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: ZunoTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        s.lastPeriodDate != null
                            ? '${s.lastPeriodDate!.day}/${s.lastPeriodDate!.month}/${s.lastPeriodDate!.year}'
                            : 'Select date',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: s.lastPeriodDate != null
                              ? ZunoTheme.onSurface
                              : ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_month,
                          color: ZunoTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Cycle Length
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Label('CYCLE LENGTH (DAYS)'),
                  Text(
                    '${s.cycleLength}',
                    style: GoogleFonts.notoSerif(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ZunoTheme.primary),
                  ),
                ],
              ),
              Slider(
                value: s.cycleLength.toDouble(),
                min: 21,
                max: 35,
                divisions: 14,
                activeColor: ZunoTheme.primary,
                inactiveColor: ZunoTheme.surfaceContainerHighest,
                onChanged: ref.read(_cycleRegProvider.notifier).setCycleLength,
              ),
              const SizedBox(height: 24),

              // Period Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Label('PERIOD DURATION (DAYS)'),
                  Text(
                    '${s.periodDuration}',
                    style: GoogleFonts.notoSerif(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ZunoTheme.primary),
                  ),
                ],
              ),
              Slider(
                value: s.periodDuration.toDouble(),
                min: 2,
                max: 10,
                divisions: 8,
                activeColor: ZunoTheme.primary,
                inactiveColor: ZunoTheme.surfaceContainerHighest,
                onChanged:
                    ref.read(_cycleRegProvider.notifier).setPeriodDuration,
              ),

              const SizedBox(height: 48),
              GestureDetector(
                onTap: s.isLoading ? null : _submit,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: ZunoTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: ZunoTheme.primary.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Center(
                    child: s.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Save & Continue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}
