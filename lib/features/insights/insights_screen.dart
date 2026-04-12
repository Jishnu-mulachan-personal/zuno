import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'insights_provider.dart';

import '../../shared/widgets/profile_avatar.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _InsightsAppBar(),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 12),
                            _InsightsHeaderSection(insight: insight),
                            const SizedBox(height: 32),
                            if (insight != null) ...[
                              _WeeklyReportSection(profile: profile, insight: insight),
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
            fontSize: 40,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
            color: ZunoTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Understanding the delicate currents of your connection.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: ZunoTheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _StatusItem(
                icon: Icons.calendar_today_rounded,
                label: 'Report Generated: $reportDateStr',
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
              ),
              const SizedBox(height: 8),
              _StatusItem(
                icon: Icons.event_repeat_rounded,
                label: 'Next Insight expected: $nextDateStr',
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WeeklyReportSection extends ConsumerStatefulWidget {
  final UserProfile profile;
  final WeeklyInsight insight;

  const _WeeklyReportSection({required this.profile, required this.insight});

  @override
  ConsumerState<_WeeklyReportSection> createState() => _WeeklyReportSectionState();
}

class _WeeklyReportSectionState extends ConsumerState<_WeeklyReportSection> {
  bool _isRegenerating = false;

  Future<void> _handleRegenerate() async {
    setState(() => _isRegenerating = true);
    try {
      await regenerateWeeklyInsight(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report regeneration started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e')),
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
        const SizedBox(height: 16),
        _AITrendInsightCard(content: widget.insight.moodHarmonyInsight),

        const SizedBox(height: 48),

        // ── EMOTIONAL CURRENTS (Shared Vibe) ──
        _SectionHeader(
          label: 'Emotional Currents',
          title: 'Shared Vibe',
        ),
        const SizedBox(height: 16),
        _SharedVibeCard(insight: widget.insight),

        const SizedBox(height: 48),

        // ── WEEKLY HIGHLIGHTS ──
        _WeeklyHighlightsSection(insight: widget.insight, profile: widget.profile),

        const SizedBox(height: 64),
        
        // ── REGENERATE BUTTON ──
        Center(
          child: TextButton.icon(
            onPressed: _isRegenerating ? null : _handleRegenerate,
            icon: _isRegenerating 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _isRegenerating ? 'REGENERATING...' : 'REGENERATE REPORT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: ZunoTheme.primary.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: ZunoTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.notoSerif(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: ZunoTheme.onSurface,
          ),
        ),
      ],
    );
  }
}

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
        // Legend with avatars
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _AvatarLegendItem(
              name: 'You',
              url: profile.avatarUrl,
              color: ZunoTheme.primary,
            ),
            const SizedBox(width: 16),
            _AvatarLegendItem(
              name: profile.partnerName ?? 'Partner',
              url: profile.partnerAvatarUrl,
              color: ZunoTheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          height: 300,
          padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 24,
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

class _AITrendInsightCard extends StatelessWidget {
  final String? content;

  const _AITrendInsightCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: ZunoTheme.primary, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, color: ZunoTheme.primary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                content ?? 'Your weekly patterns are being analyzed. Keep checking in daily to unlock more insights.',
                style: GoogleFonts.notoSerif(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: ZunoTheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodSyncWave extends StatelessWidget {
  final List<dynamic> data;
  final UserProfile profile;

  const _MoodSyncWave({required this.data, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minY: 1,
        maxY: 5,
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 60,
              getTitlesWidget: (val, meta) {
                String label = '';
                if (val == 1) label = 'LOW';
                if (val == 3) label = 'STABLE';
                if (val == 5) label = 'RADIANT';
                
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.35),
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
                if (val < 0 || val >= data.length) return const SizedBox.shrink();
                final rawDay = data[val.toInt()]['day'] ?? '';
                final label = _formatDayInitial(rawDay);
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
        ),
        lineBarsData: [
          _buildLine(isPartnerA: false), // Draw partner first (underneath)
          _buildLine(isPartnerA: true),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => ZunoTheme.surfaceContainerHigh.withOpacity(0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  GoogleFonts.plusJakartaSans(
                    color: spot.bar.color,
                    fontWeight: FontWeight.bold,
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
      curveSmoothness: 0.35,
      barWidth: isPartnerA ? 4 : 3,
      color: isPartnerA ? color : color.withOpacity(0.6),
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(isPartnerA ? 0.15 : 0.05),
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
    if (input.toLowerCase().startsWith('th')) return 'T';
    if (input.toLowerCase().startsWith('f')) return 'F';
    if (input.toLowerCase().startsWith('sa')) return 'S';
    if (input.toLowerCase().startsWith('su')) return 'S';
    return input.substring(0, 1).toUpperCase();
  }
}



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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(url: url, radius: 10, name: name),
          const SizedBox(width: 8),
          Text(
            name.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ZunoTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

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
          colors: [ZunoTheme.primary, ZunoTheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -20,
            right: -20,
            child: Opacity(
              opacity: 0.15,
              child: _WaveVisual(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.waves_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insight.vibeTitle ?? 'Steady & Warm',
                        style: GoogleFonts.notoSerif(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  insight.vibeText ?? 'Your emotional connection is finding its unique rhythm. Continue sharing your day to unlock a more defined vibe.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.6,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (insight.recommendation != null) ...[
                  const SizedBox(height: 24),
                  Divider(color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 24),
                  Text(
                    'WEEKEND RECOMMENDATION',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.recommendation!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'PLAN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ZunoTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
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
    path.quadraticBezierTo(size.width * 0.5, 0, size.width * 0.8, size.height * 0.2);
    path.quadraticBezierTo(size.width, size.height * 0.4, size.width * 0.9, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.7, size.height, size.width * 0.3, size.height * 0.9);
    path.quadraticBezierTo(0, size.height * 0.6, size.width * 0.1, size.height * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeeklyHighlightsSection extends StatelessWidget {
  final WeeklyInsight insight;
  final UserProfile profile;

  const _WeeklyHighlightsSection({required this.insight, required this.profile});

  @override
  Widget build(BuildContext context) {
    final highlights = insight.highlights ?? {};
    final cycleNote = highlights['cycle_note'] as String?;
    final partnerPeaks = highlights['partner_peaks'] as List<dynamic>? ?? [];
    final lookingAhead = highlights['looking_ahead'] as String?;

    final hasHighlights = cycleNote != null || partnerPeaks.isNotEmpty || lookingAhead != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'WEEKLY HIGHLIGHTS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!hasHighlights)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLow.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.05)),
            ),
            child: Text(
              'Stay tuned, Zuno is learning about you. Share more daily moments to unlock your weekly highlights.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          )
        else ...[
          if (cycleNote != null) ...[
            _HighlightCard(
              title: 'Cycle Note',
              subtitle: cycleNote,
              icon: Icons.water_drop_rounded,
              color: ZunoTheme.primary,
              label: 'NOTED',
            ),
            const SizedBox(height: 12),
          ],
          for (var peak in partnerPeaks) ...[
            _PeakHighlightCard(
              name: peak['name'] ?? 'Partner',
              moment: peak['peak_moment'] ?? 'Special moment shared',
              isYou: peak['name'] == 'You' || peak['name'] == profile.displayName,
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
              trailingIcon: Icons.arrow_forward_rounded,
            ),
        ],
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? label;
  final IconData? trailingIcon;

  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.label,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: ZunoTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (label != null)
            Text(
              label!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color.withOpacity(0.6),
              ),
            ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: color, size: 18),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(url: avatarUrl, radius: 20, name: name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${name.toUpperCase()}'S PEAK",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  moment,
                  style: GoogleFonts.notoSerif(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ZunoTheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.favorite_rounded, color: color.withOpacity(0.3), size: 24),
        ],
      ),
    );
  }
}



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
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ZunoTheme.primary,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: ZunoTheme.onSurfaceVariant),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        const ProfileAvatar(radius: 16, name: 'You'),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ComingSoonSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZunoTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: ZunoTheme.primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            'More Insights Coming Soon',
            style: GoogleFonts.notoSerif(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Our AI is learning your patterns to provide deeper relationship analysis and cycle-mood connections.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'UPCOMING: CYCLE PATTERNS • SYNC LOGS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: ZunoTheme.primary.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

