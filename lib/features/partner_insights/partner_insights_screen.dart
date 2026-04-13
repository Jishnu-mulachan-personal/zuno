import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'partner_insights_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

class PartnerInsightsScreen extends ConsumerStatefulWidget {
  const PartnerInsightsScreen({super.key});

  @override
  ConsumerState<PartnerInsightsScreen> createState() =>
      _PartnerInsightsScreenState();
}

class _PartnerInsightsScreenState
    extends ConsumerState<PartnerInsightsScreen> {
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await refreshPartnerInsights(ref);
    } catch (_) {}
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final insightsAsync = ref.watch(partnerInsightsProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => _buildLoading(),
        error:   (e, _) => _buildError(e.toString()),
        data: (profile) {
          return Stack(
            children: [
              RefreshIndicator(
                color: ZunoTheme.primary,
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    _PartnerInsightsAppBar(
                      partnerName: profile.partnerName,
                      onRefresh: _onRefresh,
                      isRefreshing: _isRefreshing,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          insightsAsync.when(
                            loading: () => _buildLoading(),
                            error:   (e, _) => _buildError(e.toString()),
                            data: (insights) {
                              if (insights == null) {
                                return _NoDataCard(
                                  partnerName: profile.partnerName,
                                );
                              }
                              return _PartnerInsightsBody(
                                insights: insights,
                                partnerName: profile.partnerName,
                              );
                            },
                          ),
                          const SizedBox(height: 120),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              ZunoBottomNavBar(
                activeTab: ZunoTab.today,
                relationshipStatus: profile.relationshipStatus,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoading() => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: ZunoTheme.primary),
              const SizedBox(height: 20),
              Text(
                'Generating insights…',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildError(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: ZunoTheme.error, size: 40),
              const SizedBox(height: 12),
              Text(
                'Something went wrong',
                style: GoogleFonts.notoSerif(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _PartnerInsightsAppBar extends StatelessWidget {
  final String? partnerName;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const _PartnerInsightsAppBar({
    this.partnerName,
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: ZunoTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: ZunoTheme.primary),
        onPressed: () => context.pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partnerName != null
                ? '${partnerName}\'s World'
                : 'Partner Insights',
            style: GoogleFonts.notoSerif(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          Text(
            'Daily AI Insight',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        ],
      ),
      actions: [
        AnimatedRotation(
          turns: isRefreshing ? 1 : 0,
          duration: const Duration(milliseconds: 800),
          child: IconButton(
            icon: Icon(Icons.refresh_rounded, color: ZunoTheme.primary),
            onPressed: isRefreshing ? null : onRefresh,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── No-data placeholder ───────────────────────────────────────────────────────

class _NoDataCard extends StatelessWidget {
  final String? partnerName;
  const _NoDataCard({this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLowest,
              shape: BoxShape.circle,
              border: Border.all(
                  color: ZunoTheme.outlineVariant.withOpacity(0.15)),
            ),
            child: Icon(Icons.spa_outlined,
                color: ZunoTheme.primary.withOpacity(0.5), size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'No cycle data yet',
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            partnerName != null
                ? '$partnerName hasn\'t set up cycle tracking yet.'
                : 'Your partner hasn\'t set up cycle tracking yet.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Main content body (all 5 cards) ──────────────────────────────────────────

class _PartnerInsightsBody extends ConsumerWidget {
  final PartnerInsightsData insights;
  final String? partnerName;

  const _PartnerInsightsBody({
    required this.insights,
    this.partnerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Card 1: Phase Navigator ──────────────────────────────────────
        if (insights.phase != 'None') ...[
          _CardLabel(label: 'CYCLE STATUS'),
          const SizedBox(height: 12),
          _PhaseNavigatorCard(insights: insights),
          const SizedBox(height: 20),
        ],

        // ── Card 2: PMS Alert (conditional) ─────────────────────────────
        if (insights.pmsAlert) ...[
          _PmsAlertCard(insights: insights),
          const SizedBox(height: 20),
        ],

        // ── Card 3: Today's Pulse ────────────────────────────────────────
        _CardLabel(label: 'TODAY\'S PULSE'),
        const SizedBox(height: 12),
        _TodaysPulseCard(insights: insights, partnerName: partnerName),

        const SizedBox(height: 20),

        // ── Card 4: Support & Avoid ──────────────────────────────────────
        _CardLabel(label: 'YOUR GUIDE FOR TODAY'),
        const SizedBox(height: 12),
        _SupportAvoidCard(insights: insights),

        const SizedBox(height: 20),

        // ── Card 5: Observation Check-in (if no mood logged) ─────────────
        if (!insights.moodLogged) ...[
          _CardLabel(label: 'OBSERVATION CHECK-IN'),
          const SizedBox(height: 12),
          _ObservationCheckInCard(
            partnerName: partnerName,
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Card helpers ──────────────────────────────────────────────────────────────

class _CardLabel extends StatelessWidget {
  final String label;
  const _CardLabel({required this.label});

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

// ── Card 1: Phase Navigator ───────────────────────────────────────────────────

class _PhaseNavigatorCard extends StatelessWidget {
  static const _phases = ['Menstrual', 'Follicular', 'Ovulatory', 'Luteal'];
  static const _phaseIcons = [
    Icons.water_drop_rounded,
    Icons.local_florist_rounded,
    Icons.wb_sunny_rounded,
    Icons.nights_stay_rounded,
  ];
  static const _phaseColors = [
    Color(0xFFD81B60), // menstrual — deep rose
    Color(0xFF039BE5), // follicular — sky
    Color(0xFFFFB300), // ovulatory — amber
    Color(0xFF8E24AA), // luteal — violet
  ];

  final PartnerInsightsData insights;
  const _PhaseNavigatorCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final activeIdx = insights.phaseIndex;
    final isDelayed = insights.phase == 'Delayed';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Phase dots row
          Row(
            children: List.generate(4, (i) {
              final isActive = i == activeIdx;
              final isPast   = i < activeIdx;
              final color    = _phaseColors[i];

              return Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(left: i == 0 ? 0 : 4, right: i == 3 ? 0 : 4),
                  child: Column(
                    children: [
                      // Dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        height: isActive ? 48 : 36,
                        width:  isActive ? 48 : 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? color
                              : isPast
                                  ? color.withOpacity(0.25)
                                  : ZunoTheme.surfaceContainerLow,
                          border: isActive
                              ? Border.all(
                                  color: color.withOpacity(0.4), width: 3)
                              : null,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          _phaseIcons[i],
                          color: isActive
                              ? Colors.white
                              : isPast
                                  ? color.withOpacity(0.7)
                                  : ZunoTheme.onSurfaceVariant.withOpacity(0.3),
                          size: isActive ? 22 : 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Label
                      Text(
                        _phases[i],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isActive
                              ? color
                              : ZunoTheme.onSurfaceVariant.withOpacity(
                                  isPast ? 0.5 : 0.3),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          // Progress connector line
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (activeIdx + 1) / 4,
              minHeight: 4,
              backgroundColor:
                  ZunoTheme.outlineVariant.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                _phaseColors[activeIdx],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Day status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PhaseChip(
                label: isDelayed
                    ? 'Cycle Delayed'
                    : '${insights.phaseLabel} Phase',
                color: _phaseColors[activeIdx],
              ),
              _PhaseChip(
                label: isDelayed
                    ? 'Day ${insights.cycleDay}+'
                    : 'Day ${insights.cycleDay}',
                color: ZunoTheme.primary,
              ),
              if (!isDelayed && insights.daysUntilPeriod != null)
                _PhaseChip(
                  label: insights.daysUntilPeriod == 0
                      ? 'Period Due Today'
                      : '${insights.daysUntilPeriod}d to Period',
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PhaseChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Card 2: PMS Alert ─────────────────────────────────────────────────────────

class _PmsAlertCard extends StatelessWidget {
  final PartnerInsightsData insights;
  const _PmsAlertCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    // Muted amber palette — adapts for dark mode automatically
    const ambBg     = Color(0xFFFFF8E1);
    const ambBgDark = Color(0xFF2D2200);
    const ambBorder = Color(0xFFFFCC02);
    const ambText   = Color(0xFF7A5200);
    const ambTextDk = Color(0xFFFFD966);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? ambBgDark : ambBg;
    final text   = isDark ? ambTextDk : ambText;

    final daysLabel = (insights.daysUntilPeriod != null &&
            insights.daysUntilPeriod! > 0)
        ? ' (${insights.daysUntilPeriod} day${insights.daysUntilPeriod! == 1 ? '' : 's'} away)'
        : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ambBorder.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ambBorder.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: ambBorder, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PMS WINDOW$daysLabel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: text.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PMS Window Expected soon. Energy levels may dip; patience and extra care recommended.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: text,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card 3: Today's Pulse ─────────────────────────────────────────────────────

class _TodaysPulseCard extends StatelessWidget {
  final PartnerInsightsData insights;
  final String? partnerName;

  const _TodaysPulseCard({required this.insights, this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZunoTheme.primary,
            ZunoTheme.primary.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.primary.withOpacity(0.25),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  partnerName != null
                      ? 'How ${partnerName} feels today'
                      : 'Their inner weather today',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (insights.lastMoodEmoji != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    insights.lastMoodEmoji!,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '"${insights.summary}"',
            style: GoogleFonts.notoSerif(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card 4: Support & Avoid ───────────────────────────────────────────────────

class _SupportAvoidCard extends StatelessWidget {
  final PartnerInsightsData insights;
  const _SupportAvoidCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Support Block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ZunoTheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ZunoTheme.primary.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZunoTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_rounded,
                        color: ZunoTheme.primary, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'HOW TO SUPPORT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: ZunoTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...insights.actionItems.map((item) =>
                  _BulletItem(text: item, color: ZunoTheme.primary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Avoid Block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ZunoTheme.error.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ZunoTheme.error.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZunoTheme.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.block_rounded,
                        color: ZunoTheme.error, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'WHAT TO AVOID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: ZunoTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...insights.avoidItems.map((item) =>
                  _BulletItem(text: item, color: ZunoTheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}


class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color.withOpacity(0.4), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ZunoTheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Card 5: Observation Check-in ──────────────────────────────────────────────

class _ObservationCheckInCard extends ConsumerStatefulWidget {
  final String? partnerName;

  const _ObservationCheckInCard({this.partnerName});

  @override
  ConsumerState<_ObservationCheckInCard> createState() =>
      _ObservationCheckInCardState();
}

class _ObservationCheckInCardState
    extends ConsumerState<_ObservationCheckInCard> {
  String? _selectedEmoji;
  bool _submitted = false;
  bool _isSaving  = false;

  static const _options = [
    _EmojiOption('😊', 'Happy'),
    _EmojiOption('😌', 'Calm'),
    _EmojiOption('😕', 'Meh'),
    _EmojiOption('😔', 'Low'),
    _EmojiOption('😤', 'Frustrated'),
  ];

  Future<void> _submit() async {
    if (_selectedEmoji == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await submitPartnerObservation(ref: ref, emoji: _selectedEmoji!);
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save observation.',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SubmittedThanks();

    final partnerName = widget.partnerName;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.15)),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZunoTheme.tertiary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove_red_eye_outlined,
                    color: ZunoTheme.tertiary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  partnerName != null
                      ? '$partnerName hasn\'t logged today.'
                      : 'She hasn\'t logged today.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              'How does her mood seem to you?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.65),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _options.map((opt) {
              final isSelected = _selectedEmoji == opt.emoji;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = opt.emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 68,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ZunoTheme.tertiary.withOpacity(0.12)
                            : ZunoTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? ZunoTheme.tertiary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(opt.emoji,
                              style: TextStyle(
                                  fontSize: isSelected ? 26 : 22)),
                          const SizedBox(height: 4),
                          Text(
                            opt.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? ZunoTheme.tertiary
                                  : ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          AnimatedOpacity(
            opacity: _selectedEmoji != null ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _selectedEmoji != null ? _submit : null,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _selectedEmoji != null
                      ? LinearGradient(
                          colors: [
                            ZunoTheme.tertiary,
                            ZunoTheme.tertiary.withOpacity(0.75),
                          ],
                        )
                      : null,
                  color: _selectedEmoji == null
                      ? ZunoTheme.surfaceContainerLow
                      : null,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'SHARE OBSERVATION',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: _selectedEmoji != null
                                ? Colors.white
                                : ZunoTheme.onSurfaceVariant.withOpacity(0.3),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedThanks extends StatelessWidget {
  const _SubmittedThanks();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: ZunoTheme.tertiary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: ZunoTheme.tertiary.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: ZunoTheme.tertiary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Observation saved!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your note helps Zuno better support both of you.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiOption {
  final String emoji;
  final String label;
  const _EmojiOption(this.emoji, this.label);
}
