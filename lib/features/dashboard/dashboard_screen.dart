import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../cycle_tracker/cycle_data_model.dart';
import 'dashboard_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => _buildDashboard(
          context,
          ref,
          state,
          userId: '',
          userName: '...', // Loading placeholder
          partnerName: null,
          gender: null,
          streakDays: 0,
          cycleData: null,
          isLoading: true,
        ),
        error: (err, stack) {
          // If profile fetch fails, we show the dashboard with default values
          // but maybe a small error indicator or retry button.
          debugPrint('[DashboardScreen] Profile error: $err');
          return _buildDashboard(
            context,
            ref,
            state,
            userId: '',
            userName: 'Friend',
            partnerName: null,
            gender: null,
            streakDays: 0,
            cycleData: null,
            error: err.toString(),
          );
        },
        data: (profile) => _buildDashboard(
          context,
          ref,
          state,
          userId: profile.id,
          userName: profile.displayName,
          partnerName: profile.partnerName,
          gender: profile.gender,
          streakDays: profile.streakDays,
          cycleData: profile.cycleData,
          partnerId: profile.partnerId,
          hasPartner: profile.partnerName != null,
          relationshipStatus: profile.relationshipStatus,
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    DashboardState state, {
    required String userId,
    required String userName,
    String? partnerName,
    String? gender,
    required int streakDays,
    CycleData? cycleData,
    String? partnerId,
    bool hasPartner = false,
    String relationshipStatus = 'single',
    bool isLoading = false,
    String? error,
  }) {
    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _DashboardAppBar(
              userName: userName,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DailyCheckInSection(
                    key: const ValueKey('daily_check_in_section'),
                    state: state,
                    partnerName: partnerName,
                  ),
                  const SizedBox(height: 32),
                  _StatusGrid(
                    state: state,
                    streakDays: streakDays,
                    partnerId: partnerId,
                    partnerName: partnerName,
                  ),
                  const SizedBox(height: 32),
                  _DynamicCardsSection(
                    userId: userId,
                    gender: gender,
                    cycleData: cycleData,
                    isLoading: isLoading,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Unable to load full profile data.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: ZunoTheme.error.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 120),
                ]),
              ),
            ),
          ],
        ),
        ZunoBottomNavBar(
          activeTab: ZunoTab.today,
          relationshipStatus: relationshipStatus,
        ),
      ],
    );
  }
}

// ── AppBar ──────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  final String userName;
  const _DashboardAppBar({required this.userName});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: ZunoTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZunoTheme.primaryFixed,
              border:
                  Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.2)),
            ),
            child: Icon(Icons.person, color: ZunoTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hey, $userName 👋',
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: ZunoTheme.primary,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(Icons.settings_outlined, color: ZunoTheme.primary),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Mood data ────────────────────────────────────────────────────────────────

class _MoodOption {
  final String emoji;
  final String label;
  final Color color;
  const _MoodOption(this.emoji, this.label, this.color);
}

final _moods = [
  _MoodOption('✨', 'Amazing', const Color(0xFFF9A825)),
  _MoodOption('😌', 'Calm', const Color(0xFF26A69A)),
  _MoodOption('😊', 'Happy', const Color(0xFF43A047)),
  _MoodOption('😕', 'Meh', const Color(0xFF9E9E9E)),
  _MoodOption('😔', 'Sad', const Color(0xFF7B8CC8)),
  _MoodOption('😤', 'Frustrated', const Color(0xFFE64A19)),
  _MoodOption('😡', 'Angry', const Color(0xFFD32F2F)),
];

// ── Daily Check-In ──────────────────────────────────────────────────────────

class _DailyCheckInSection extends ConsumerStatefulWidget {
  final DashboardState state;
  final String? partnerName;

  const _DailyCheckInSection({
    super.key,
    required this.state,
    this.partnerName,
  });

  @override
  ConsumerState<_DailyCheckInSection> createState() => _DailyCheckInSectionState();
}

class _DailyCheckInSectionState extends ConsumerState<_DailyCheckInSection> {
  late TextEditingController _journalController;
  late FocusNode _journalFocusNode;
  final GlobalKey _saveButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: widget.state.journalNote);
    _journalFocusNode = FocusNode();
    _journalFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_journalFocusNode.hasFocus) {
      // Small delay to allow the keyboard to show up
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _saveButtonKey.currentContext != null) {
          Scrollable.ensureVisible(
            _saveButtonKey.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _journalController.dispose();
    _journalFocusNode.removeListener(_onFocusChange);
    _journalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state resets to clear the text controller
    ref.listen<DashboardState>(dashboardProvider, (prev, next) {
      if (next.journalNote.isEmpty && _journalController.text.isNotEmpty) {
        _journalController.clear();
      }
    });

    final state = widget.state;
    final partnerName = widget.partnerName;

    final tags = [
      'Work',
      'Partner',
      'Health',
      'Home',
      'Social',
      'Family',
      'Tired',
      'Grateful'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY CHECK-IN',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How is your heart today?',
          style: GoogleFonts.notoSerif(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        // Scrollable mood row
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final m = _moods[i];
              final isSelected = state.selectedMood == m.emoji;
              return GestureDetector(
                onTap: () =>
                    ref.read(dashboardProvider.notifier).setMood(m.emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? m.color.withOpacity(0.12)
                        : ZunoTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? m.color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        m.emoji,
                        style: TextStyle(
                          fontSize: isSelected ? 28 : 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? m.color
                              : ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        // Connection & Tags Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (partnerName != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Feeling connected to $partnerName?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ToggleButton(
                      value: state.isConnected,
                      onChanged:
                          ref.read(dashboardProvider.notifier).toggleConnection,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'CONTEXT TAGS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 10),
              // Horizontally scrollable tags
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = tags[i];
                    final isSelected = state.selectedTags.contains(t);
                    return GestureDetector(
                      onTap: () =>
                          ref.read(dashboardProvider.notifier).toggleTag(t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ZunoTheme.tertiaryFixed
                              : ZunoTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: isSelected
                                ? ZunoTheme.tertiary.withOpacity(0.15)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          t,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? ZunoTheme.onTertiaryFixedVariant
                                : ZunoTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Journal note
              Text(
                'JOURNAL NOTE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _journalController,
                focusNode: _journalFocusNode,
                autofocus: false,
                onChanged: (v) =>
                    ref.read(dashboardProvider.notifier).setJournalNote(v),
                maxLines: 3,
                maxLength: 300,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: ZunoTheme.onSurface,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind today…',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.35),
                  ),
                  counterStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.3),
                  ),
                  filled: true,
                  fillColor: ZunoTheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: ZunoTheme.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ZunoTheme.tertiary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 12, color: ZunoTheme.tertiary),
                    const SizedBox(width: 6),
                    Text(
                      'PRIVATE & END-TO-END ENCRYPTED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ZunoTheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SaveCheckInButton(
                key: _saveButtonKey,
                enabled: state.selectedMood != null || state.journalNote.trim().isNotEmpty,
                isSaving: state.isSaving,
                onTap: (state.selectedMood == null && state.journalNote.trim().isEmpty) || state.isSaving
                    ? null
                    : () async {
                        final success = await ref
                            .read(dashboardProvider.notifier)
                            .saveLog();
                        if (context.mounted) {
                          _showFeedbackSnackbar(context, success);
                        }
                      },
              ),
              if (state.lastSaved != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 14, color: ZunoTheme.tertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Last saved at ${_formatTime(state.lastSaved!)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showFeedbackSnackbar(BuildContext context, bool success) {
    final msg = success ? 'Check-in saved! 💚' : 'Could not save. Try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: success ? ZunoTheme.tertiary : ZunoTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Save Check-In Button ─────────────────────────────────────────────────────

class _SaveCheckInButton extends StatelessWidget {
  final bool enabled;
  final bool isSaving;
  final VoidCallback? onTap;

  const _SaveCheckInButton({
    super.key,
    required this.enabled,
    required this.isSaving,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: enabled ? ZunoTheme.primaryGradient : null,
          color: enabled ? null : ZunoTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ZunoTheme.primary.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: Center(
          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'SAVE CHECK-IN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? Colors.white
                        : ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                    letterSpacing: 2.0,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Status Grid ─────────────────────────────────────────────────────────────

class _StatusGrid extends ConsumerWidget {
  final DashboardState state;
  final int streakDays;
  final String? partnerId;
  final String? partnerName;

  const _StatusGrid({
    required this.state,
    required this.streakDays,
    this.partnerId,
    this.partnerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String partnerStatusValue = 'Partner feels\nYet to sync';
    if (partnerId != null) {
      final partnerMoodAsync = ref.watch(partnerMoodProvider(partnerId!));
      partnerMoodAsync.whenData((emoji) {
        if (emoji != null) {
          partnerStatusValue = '$partnerName feels\n$emoji';
        }
      });
    }

    return Row(
      children: [
        if (partnerName != null && partnerId != null) ...[
          Expanded(
            child: _StatusCard(
              icon: Icons.favorite_rounded,
              label: 'PARTNER',
              value: partnerStatusValue,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _StatusCard(
            icon: Icons.local_fire_department_rounded,
            label: 'STREAK',
            value: '$streakDays-day\nStreak',
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ZunoTheme.primary, size: 26),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dynamic Cards ───────────────────────────────────────────────────────────

class _DynamicCardsSection extends ConsumerWidget {
  final String? userId;
  final String? gender;
  final CycleData? cycleData;
  final bool isLoading;

  const _DynamicCardsSection({
    this.userId,
    this.gender,
    this.cycleData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return Column(
      children: [
        if (state.isLoadingInsight)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: CircularProgressIndicator(color: ZunoTheme.primary),
            ),
          )
        else if (state.dailyInsight != null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ZunoTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ZunoTheme.primary.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY INSIGHT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '"${state.dailyInsight!}"',
                  style: GoogleFonts.notoSerif(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () =>
                      ref.read(dashboardProvider.notifier).refreshInsights(),
                  child: Row(
                    children: [
                      Text(
                        'REGENERATE INSIGHT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (state.dailyInsight != null && gender == 'Female')
          const SizedBox(height: 16),
        if (gender == 'Female') ...[
          if (cycleData != null && cycleData!.shouldShowConfirmationCard) ...[
            _CycleConfirmationCard(userId: userId!, cycle: cycleData!),
            const SizedBox(height: 16),
          ],
          if (cycleData == null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/cycle_registration'),
              child: const _PromoCard(
                icon: Icons.refresh_rounded,
                title: 'Track Your Cycle',
                subtitle: 'Get personalized insights for your body.',
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/cycle_calendar'),
              child: _DashboardSmartCard(
                icon: Icons.calendar_month_rounded,
                tag: 'CYCLE TRACKER',
                title: cycleData!.isPeriodDelayed 
                    ? 'Cycle Delayed' 
                    : 'Day ${cycleData!.currentCycleDay}',
                subtitle: cycleData!.phaseSubtitle,
                insight: state.cycleInsight,
                isLoadingInsight: state.isLoadingCycleInsight,
                accentColor: ZunoTheme.tertiary,
                showChevron: true,
              ),
            ),
          ],
        ],
        if (isLoading && gender == null)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: _LoadingSmartCard(),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Coming Soon! 🚀',
                    style: GoogleFonts.plusJakartaSans()),
                backgroundColor: ZunoTheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: const _PromoCard(
            icon: Icons.child_care_rounded,
            title: 'Pregnancy Planning',
            subtitle: 'Unlock personalized guidance for your journey.',
          ),
        ),
      ],
    );
  }
}

class _DashboardSmartCard extends StatelessWidget {
  final IconData icon;
  final String tag;
  final String title;
  final String subtitle;
  final String? insight;
  final bool isLoadingInsight;
  final Color accentColor;
  final bool showChevron;

  const _DashboardSmartCard({
    required this.icon,
    required this.tag,
    required this.title,
    required this.subtitle,
    this.insight,
    this.isLoadingInsight = false,
    required this.accentColor,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: accentColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.notoSerif(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
                if (isLoadingInsight) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor.withOpacity(0.5),
                    ),
                  ),
                ] else if (insight != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    insight!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ZunoTheme.onSurface.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (showChevron)
            Icon(Icons.chevron_right_rounded,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.3), size: 28)
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: accentColor.withOpacity(0.2), width: 3),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: accentColor, size: 22),
            ),
        ],
      ),
    );
  }
}

class _CycleConfirmationCard extends ConsumerWidget {
  final String userId;
  final CycleData cycle;

  const _CycleConfirmationCard({
    required this.userId,
    required this.cycle,
  });

  Future<void> _pickStartDate(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final first = now.subtract(const Duration(days: 90));

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: first,
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
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
      await ref
          .read(dashboardProvider.notifier)
          .updateCycleStartDate(userId, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZunoTheme.primary,
            ZunoTheme.primaryContainer.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.water_drop, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cycle.confirmationCardTitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Keep your tracking accurate by confirming the start of your period.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await ref
                        .read(dashboardProvider.notifier)
                        .updateCycleStartDate(userId, DateTime.now());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Started Today',
                      style: GoogleFonts.plusJakartaSans(
                        color: ZunoTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickStartDate(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Started Earlier',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingSmartCard extends StatelessWidget {
  const _LoadingSmartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ZunoTheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 140,
                  height: 24,
                  decoration: BoxDecoration(
                    color: ZunoTheme.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: ZunoTheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZunoTheme.onSurface.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PromoCard(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ZunoTheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: ZunoTheme.outlineVariant),
        ],
      ),
    );
  }
}

// ── Toggle ──────────────────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
              label: 'Yes', selected: value, onTap: () => onChanged(true)),
          _ToggleItem(
              label: 'No', selected: !value, onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleItem(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ZunoTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: ZunoTheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : ZunoTheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}


