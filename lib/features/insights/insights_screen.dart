import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'insights_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme changes to trigger rebuild
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final moodTrendAsync = ref.watch(moodTrendProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: ZunoTheme.primary),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) => Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _InsightsAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _MoodTrendHeader(),
                      const SizedBox(height: 24),
                      _MoodChartSection(moodTrendAsync: moodTrendAsync),
                      const SizedBox(height: 40),
                      _ComingSoonSection(),
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
        ),
      ),
    );
  }
}

class _InsightsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: ZunoTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Insights',
        style: GoogleFonts.notoSerif(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ZunoTheme.primary,
        ),
      ),
      centerTitle: false,
    );
  }
}

class _MoodTrendHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR MOOD TREND',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The last 7 days',
          style: GoogleFonts.notoSerif(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _MoodChartSection extends StatelessWidget {
  final AsyncValue<List<MoodTrendPoint>> moodTrendAsync;

  const _MoodChartSection({required this.moodTrendAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
      ),
      child: moodTrendAsync.when(
        data: (points) {
          if (points.isEmpty) {
            return Center(
              child: Text(
                'No logs found for this week.\nKeep checking in to see your trends! ✨',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            );
          }
          return LineChart(_buildChartData(points));
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: ZunoTheme.primary),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  LineChartData _buildChartData(List<MoodTrendPoint> points) {
    // Generate dates for the last 7 days for the X-axis labels
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: ZunoTheme.outlineVariant.withOpacity(0.1),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              String label = '';
              switch (value.toInt()) {
                case 1: label = 'Sad'; break;
                case 3: label = 'Calm'; break;
                case 5: label = 'Great'; break;
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
              if (value < 0 || value >= 7) return const SizedBox.shrink();
              final date = last7Days[value.toInt()];
              final label = _getWeekdayLabel(date.weekday);
              final isToday = date.day == now.day && date.month == now.month;

              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday
                        ? ZunoTheme.primary
                        : ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: 5.5,
      lineBarsData: [
        LineChartBarData(
          spots: points.map((p) {
              // Map date to index 0-6
              final dayIndex = 6 - now.difference(p.date).inDays;
              return FlSpot(dayIndex.toDouble(), p.value);
          }).toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          gradient: LinearGradient(
            colors: [ZunoTheme.primary, ZunoTheme.secondary],
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: ZunoTheme.primary,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ZunoTheme.primary.withOpacity(0.2),
                ZunoTheme.primary.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => ZunoTheme.primary.withOpacity(0.8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                _getMoodLabel(spot.y),
                GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  String _getWeekdayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  String _getMoodLabel(double val) {
    if (val >= 4.5) return '✨ Amazing';
    if (val >= 3.5) return '😊 Happy';
    if (val >= 2.5) return '😌 Calm';
    if (val >= 1.5) return '😕 Meh';
    return '😔 Sad';
  }
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

