import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'insights_provider.dart';

import '../../shared/widgets/profile_avatar.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeeplinkScroll();
    });
  }

  void _handleDeeplinkScroll() {
    if (!mounted) return;
    final section = GoRouterState.of(context).uri.queryParameters['section'];
    if (section == 'report') {
      if (_reportKey.currentContext != null) {
        Scrollable.ensureVisible(
          _reportKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutQuart,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final weeklyInsightAsync = ref.watch(weeklyInsightProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: ZunoTheme.primary),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) {
          return weeklyInsightAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: ZunoTheme.primary),
            ),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (insight) {
              return Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _InsightsAppBar(),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 12),
                            _InsightsHeaderSection(insight: insight),
                            const SizedBox(height: 32),
                            if (insight != null) ...[
                              _WeeklyReportSection(
                                  key: _reportKey,
                                  profile: profile, 
                                  insight: insight),
                            ] else ...[
                              _ComingSoonSection(),
                            ],
                            const SizedBox(height: 120),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  ZunoBottomNavBar(
                    activeTab: ZunoTab.insights,
                    relationshipStatus: profile.relationshipStatus,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _InsightsHeaderSection extends StatelessWidget {
  final WeeklyInsight? insight;

  const _InsightsHeaderSection({this.insight});

  @override
  Widget build(BuildContext context) {
    final reportDate = insight?.createdAt ?? DateTime.now();
    final nextDate = reportDate.add(const Duration(days: 7));

    final reportDateStr = _formatDate(reportDate);
    final nextDateStr = _formatDate(nextDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: GoogleFonts.notoSerif(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Understanding the currents of your connection.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              _StatusItem(
                icon: Icons.calendar_today_rounded,
                label: 'INSIGHT GENERATED: $reportDateStr',
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: ZunoTheme.outlineVariant.withOpacity(0.1),
              ),
              const SizedBox(height: 10),
              _StatusItem(
                icon: Icons.event_repeat_rounded,
                label: 'NEXT INSIGHT: $nextDateStr',
                color: ZunoTheme.primary.withOpacity(0.8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Weekly Report Section ────────────────────────────────────────────────────

class _WeeklyReportSection extends ConsumerStatefulWidget {
  final UserProfile profile;
  final WeeklyInsight insight;

  const _WeeklyReportSection({
    super.key,
    required this.profile,
    required this.insight,
  });

  @override
  ConsumerState<_WeeklyReportSection> createState() =>
      _WeeklyReportSectionState();
}

class _WeeklyReportSectionState extends ConsumerState<_WeeklyReportSection> {
  bool _isRegenerating = false;

  Future<void> _handleRegenerate() async {
    setState(() => _isRegenerating = true);
    try {
      await regenerateWeeklyInsight(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Regenerating your report...',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: ZunoTheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate: $e',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: ZunoTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── MOOD HARMONY ──
        _SectionHeader(
          label: 'Mood Harmony',
          title: 'Last 7 Days',
        ),
        const SizedBox(height: 16),
        _MoodHarmonyGraph(insight: widget.insight, profile: widget.profile),
        const SizedBox(height: 12),
        _AITrendInsightCard(content: widget.insight.moodHarmonyInsight),

        const SizedBox(height: 40),

        // ── EMOTIONAL CURRENTS (Shared Vibe) ──
        _SectionHeader(
          label: 'Emotional Currents',
          title: 'Shared Vibe',
        ),
        const SizedBox(height: 16),
        _SharedVibeCard(insight: widget.insight),

        if (widget.insight.recommendation != null) ...[
          const SizedBox(height: 12),
          _RecommendationCard(recommendation: widget.insight.recommendation!),
        ],

        const SizedBox(height: 40),

        // ── WEEKLY HIGHLIGHTS ──
        _WeeklyHighlightsSection(
            insight: widget.insight, profile: widget.profile),

        const SizedBox(height: 48),

        // ── REGENERATE BUTTON ──
        Center(
          child: TextButton.icon(
            onPressed: _isRegenerating ? null : _handleRegenerate,
            icon: _isRegenerating
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ZunoTheme.primary))
                : Icon(Icons.refresh_rounded,
                    size: 16, color: ZunoTheme.primary.withOpacity(0.6)),
            label: Text(
              _isRegenerating ? 'REGENERATING...' : 'REGENERATE REPORT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: ZunoTheme.primary.withOpacity(0.6),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(
                    color: ZunoTheme.outlineVariant.withOpacity(0.2)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String title;

  const _SectionHeader({required this.label, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.notoSerif(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Mood Harmony Graph ───────────────────────────────────────────────────────

class _MoodHarmonyGraph extends StatelessWidget {
  final WeeklyInsight insight;
  final UserProfile profile;

  const _MoodHarmonyGraph({required this.insight, required this.profile});

  @override
  Widget build(BuildContext context) {
    final data = insight.patternData ?? [];
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _AvatarLegendItem(
              name: 'You',
              url: profile.avatarUrl,
              color: ZunoTheme.primary,
            ),
            const SizedBox(width: 12),
            _AvatarLegendItem(
              name: profile.partnerName ?? 'Partner',
              url: profile.partnerAvatarUrl,
              color: ZunoTheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 260,
          padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: ZunoTheme.onSurface.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _MoodSyncWave(data: data, profile: profile),
        ),
      ],
    );
  }
}

// ── AI Trend Insight Card ────────────────────────────────────────────────────

class _AITrendInsightCard extends StatelessWidget {
  final String? content;

  const _AITrendInsightCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZunoTheme.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ZunoTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: ZunoTheme.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content ??
                  'Your weekly patterns are being analyzed. Keep checking in daily to unlock more insights.',
              style: GoogleFonts.notoSerifAhom(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: ZunoTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mood Sync Wave Chart ─────────────────────────────────────────────────────

class _MoodSyncWave extends StatelessWidget {
  final List<dynamic> data;
  final UserProfile profile;

  const _MoodSyncWave({required this.data, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (val) => FlLine(
            color: ZunoTheme.outlineVariant.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 1,
        maxY: 5,
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 56,
              getTitlesWidget: (val, meta) {
                String label = '';
                if (val == 1) label = 'LOW';
                if (val == 3) label = 'STABLE';
                if (val == 5) label = 'RADIANT';

                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                if (val < 0 || val >= data.length)
                  return const SizedBox.shrink();
                final rawDay = data[val.toInt()]['day'] ?? '';
                final label = _formatDayInitial(rawDay);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
        ),
        lineBarsData: [
          _buildLine(isPartnerA: false),
          _buildLine(isPartnerA: true),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) =>
                ZunoTheme.surfaceContainerHigh.withOpacity(0.95),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(0),
                  GoogleFonts.plusJakartaSans(
                    color: spot.bar.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLine({required bool isPartnerA}) {
    final color = isPartnerA ? ZunoTheme.primary : ZunoTheme.tertiary;
    return LineChartBarData(
      spots: data.asMap().entries.map((e) {
        final val = isPartnerA
            ? (e.value['partnerA'] as num).toDouble()
            : (e.value['partnerB'] as num).toDouble();
        return FlSpot(e.key.toDouble(), val);
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.4,
      barWidth: isPartnerA ? 3.5 : 2.5,
      color: color.withOpacity(isPartnerA ? 0.8 : 0.5),
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(isPartnerA ? 0.12 : 0.04),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }

  String _formatDayInitial(String input) {
    if (input.isEmpty) return '';
    if (input.toLowerCase().startsWith('m')) return 'M';
    if (input.toLowerCase().startsWith('tu')) return 'T';
    if (input.toLowerCase().startsWith('w')) return 'W';
    if (input.toLowerCase().startsWith('th')) return 'Th';
    if (input.toLowerCase().startsWith('f')) return 'F';
    if (input.toLowerCase().startsWith('sa')) return 'S';
    if (input.toLowerCase().startsWith('su')) return 'S';
    return input.substring(0, 1).toUpperCase();
  }
}

// ── Avatar Legend ────────────────────────────────────────────────────────────

class _AvatarLegendItem extends StatelessWidget {
  final String name;
  final String? url;
  final Color color;

  const _AvatarLegendItem({
    required this.name,
    this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          ProfileAvatar(url: url, radius: 9, name: name),
          const SizedBox(width: 6),
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Vibe Card ─────────────────────────────────────────────────────────

class _SharedVibeCard extends StatelessWidget {
  final WeeklyInsight insight;

  const _SharedVibeCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -24,
            right: -24,
            child: Opacity(
              opacity: 0.12,
              child: _WaveVisual(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.waves_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insight.vibeTitle ?? 'Steady & Warm',
                        style: GoogleFonts.notoSerif(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  insight.vibeText ??
                      'Your emotional connection is finding its unique rhythm. Share more daily moments to unlock a more defined vibe.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.88),
                    height: 1.6,
                    fontWeight: FontWeight.w400,
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

// ── Weekend Recommendation Card ──────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final String recommendation;

  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ZunoTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.celebration_rounded,
                color: ZunoTheme.secondary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEKEND RECOMMENDATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recommendation,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: ZunoTheme.onSurface,
                    height: 1.6,
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

// ── Wave Visual (bg decoration) ──────────────────────────────────────────────

class _WaveVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _BlobPainter(),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.1);
    path.quadraticBezierTo(
        size.width * 0.5, 0, size.width * 0.8, size.height * 0.2);
    path.quadraticBezierTo(
        size.width, size.height * 0.4, size.width * 0.9, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.7, size.height, size.width * 0.3, size.height * 0.9);
    path.quadraticBezierTo(
        0, size.height * 0.6, size.width * 0.1, size.height * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Weekly Highlights Section ────────────────────────────────────────────────

class _WeeklyHighlightsSection extends StatelessWidget {
  final WeeklyInsight insight;
  final UserProfile profile;

  const _WeeklyHighlightsSection(
      {required this.insight, required this.profile});

  @override
  Widget build(BuildContext context) {
    final highlights = insight.highlights ?? {};
    final cycleNote = highlights['cycle_note'] as String?;
    final partnerPeaks = highlights['partner_peaks'] as List<dynamic>? ?? [];
    final lookingAhead = highlights['looking_ahead'] as String?;

    final hasHighlights =
        cycleNote != null || partnerPeaks.isNotEmpty || lookingAhead != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WEEKLY HIGHLIGHTS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This Week\'s Moments',
          style: GoogleFonts.notoSerif(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (!hasHighlights)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: ZunoTheme.primary.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Stay tuned',
                  style: GoogleFonts.notoSerif(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zuno is learning about you. Share more daily moments to unlock your weekly highlights.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (cycleNote != null) ...[
            _HighlightCard(
              title: 'Cycle Note',
              subtitle: cycleNote,
              icon: Icons.water_drop_rounded,
              color: ZunoTheme.primary,
              labelIcon: Icons.check_circle_rounded,
            ),
            const SizedBox(height: 12),
          ],
          for (var peak in partnerPeaks) ...[
            _PeakHighlightCard(
              name: peak['name'] ?? 'Partner',
              moment: peak['peak_moment'] ?? 'Special moment shared',
              isYou:
                  peak['name'] == 'You' || peak['name'] == profile.displayName,
              profile: profile,
            ),
            const SizedBox(height: 12),
          ],
          if (lookingAhead != null)
            _HighlightCard(
              title: 'Looking ahead',
              subtitle: lookingAhead,
              icon: Icons.celebration_rounded,
              color: ZunoTheme.secondary,
              trailingIcon: Icons.arrow_forward_ios_rounded,
            ),
        ],
      ],
    );
  }
}

// ── Highlight Card ───────────────────────────────────────────────────────────

class _HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final IconData? labelIcon;
  final IconData? trailingIcon;

  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.labelIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: ZunoTheme.onSurface,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          if (labelIcon != null)
            Icon(
              labelIcon,
              size: 20,
              color: color.withOpacity(0.4),
            ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: ZunoTheme.outlineVariant, size: 14),
        ],
      ),
    );
  }
}

// ── Peak Highlight Card ──────────────────────────────────────────────────────

class _PeakHighlightCard extends StatelessWidget {
  final String name;
  final String moment;
  final bool isYou;
  final UserProfile profile;

  const _PeakHighlightCard({
    required this.name,
    required this.moment,
    required this.isYou,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = isYou ? profile.avatarUrl : profile.partnerAvatarUrl;
    final color = isYou ? ZunoTheme.primary : ZunoTheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProfileAvatar(url: avatarUrl, radius: 19, name: name),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${name.toUpperCase()}'S PEAK",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  moment,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: ZunoTheme.onSurface,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.favorite_rounded,
              color: color.withOpacity(0.25), size: 20),
        ],
      ),
    );
  }
}

// ── App Bar ──────────────────────────────────────────────────────────────────

class _InsightsAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: ZunoTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Weekly Insights',
        style: GoogleFonts.notoSerif(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ZunoTheme.primary,
        ),
      ),
      centerTitle: false,
      actions: [
        // IconButton(
        //   icon: Icon(Icons.notifications_none_rounded,
        //       color: ZunoTheme.onSurfaceVariant),
        //   onPressed: () {},
        // ),
        // const SizedBox(width: 8),
        // const ProfileAvatar(radius: 16, name: 'You'),
        // const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ── Coming Soon Section ──────────────────────────────────────────────────────

class _ComingSoonSection extends ConsumerStatefulWidget {
  const _ComingSoonSection({super.key});

  @override
  ConsumerState<_ComingSoonSection> createState() => _ComingSoonSectionState();
}

class _ComingSoonSectionState extends ConsumerState<_ComingSoonSection> {
  bool _isGenerating = false;

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Analyzing your connection... ✨',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: ZunoTheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      
      await regenerateWeeklyInsight(ref);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your first report is ready! 🌸',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: ZunoTheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate: $e',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: ZunoTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZunoTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: ZunoTheme.primary, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Insight is Coming',
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep logging your daily check-ins. Your first weekly report will be ready at the end of the week, or you can try generating it now if you have enough data.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          
          // GENERATE NOW BUTTON
          TextButton.icon(
            onPressed: _isGenerating ? null : _handleGenerate,
            icon: _isGenerating
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ZunoTheme.primary))
                : Icon(Icons.bolt_rounded,
                    size: 16, color: ZunoTheme.primary),
            label: Text(
              _isGenerating ? 'ANALYZING...' : 'GENERATE ANALYSIS NOW',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: ZunoTheme.primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              backgroundColor: ZunoTheme.primary.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(
                    color: ZunoTheme.primary.withOpacity(0.2)),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'UPCOMING: CYCLE PATTERNS • SYNC LOGS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
