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
    // Watch theme changes to trigger rebuild
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: ZunoTheme.primary),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) {
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
                        _WeeklyReportSection(profile: profile),
                        const SizedBox(height: 24),
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
          );
        },
      ),
    );
  }
}

class _WeeklyReportSection extends ConsumerWidget {
  final UserProfile profile;
  
  const _WeeklyReportSection({required this.profile});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyInsightAsync = ref.watch(weeklyInsightProvider);

    return weeklyInsightAsync.when(
      data: (insight) {
        if (insight == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MOOD SYNC ──
            _MoodTrendHeader(
              title: 'THE MOOD SYNC WAVE',
              subtitle: 'Last 7 days',
            ),
            const SizedBox(height: 24),
            if (insight.patternData != null)
              Container(
                height: 320,
                padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
                decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
                ),
                child: _MoodSyncWave(data: insight.patternData!, profile: profile),
              ),
            const SizedBox(height: 20),
            _AIInsightContainer(
              content: insight.pattern,
              color: ZunoTheme.primary,
              icon: Icons.auto_awesome_rounded,
            ),

            const SizedBox(height: 48),

            // ── SHARED VALUES ──
            _MoodTrendHeader(
              title: 'SHARED VALUES ALIGNMENT',
              subtitle: 'Synergy from your Daily Q&A',
            ),
            const SizedBox(height: 24),
            if (insight.alignmentData != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
                ),
                child: _SharedValuesRadar(data: insight.alignmentData!),
              ),
            const SizedBox(height: 20),
            _AIInsightContainer(
              content: insight.alignment,
              color: ZunoTheme.secondary,
              icon: Icons.sync_rounded,
            ),

            const SizedBox(height: 48),

            // ── WEEKLY THEME ──
            _MoodTrendHeader(
              title: 'WEEKLY THEME',
              subtitle: 'The emotional current',
            ),
            const SizedBox(height: 20),
            _AIInsightContainer(
              content: insight.theme,
              color: ZunoTheme.tertiary,
              icon: Icons.favorite_rounded,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => const SizedBox.shrink(),
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

    return Column(
      children: [
        // Legend with avatars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AvatarLegendItem(
              name: 'You',
              url: profile.avatarUrl,
              color: ZunoTheme.primary,
            ),
            const SizedBox(width: 24),
            _AvatarLegendItem(
              name: profile.partnerName ?? 'Partner',
              url: profile.partnerAvatarUrl,
              color: ZunoTheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: ZunoTheme.outlineVariant.withOpacity(0.1),
                  strokeWidth: 1,
                ),
              ),
              minY: 0,
              maxY: 5.5,
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 36,
                    getTitlesWidget: (val, meta) {
                      String label = '';
                      switch (val.toInt()) {
                        case 1: label = 'Sad'; break;
                        case 3: label = 'Calm'; break;
                        case 5: label = 'Great'; break;
                      }
                      if (label.isEmpty) return const SizedBox.shrink();
                      return Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _formatDayLabel(rawDay),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _buildLine(isPartnerA: true),
                _buildLine(isPartnerA: false),
              ],
              lineTouchData: LineTouchData(
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
          ),
        ),
      ],
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
      barWidth: 3,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.1),
      ),
    );
  }

  String _formatDayLabel(String input) {
    if (input.isEmpty) return '';
    
    // If it's already a 3-letter string, assume it's the short day name (e.g., "Mon")
    if (input.length == 3) return input;

    try {
      // Try to parse as a full date (e.g., "2024-04-11")
      final date = DateTime.parse(input);
      switch (date.weekday) {
        case 1: return 'Mon';
        case 2: return 'Tue';
        case 3: return 'Wed';
        case 4: return 'Thu';
        case 5: return 'Fri';
        case 6: return 'Sat';
        case 7: return 'Sun';
      }
    } catch (_) {
      // If parsing fails, it might be "Monday", "Tuesday", etc.
      if (input.toLowerCase().startsWith('mon')) return 'Mon';
      if (input.toLowerCase().startsWith('tue')) return 'Tue';
      if (input.toLowerCase().startsWith('wed')) return 'Wed';
      if (input.toLowerCase().startsWith('thu')) return 'Thu';
      if (input.toLowerCase().startsWith('fri')) return 'Fri';
      if (input.toLowerCase().startsWith('sat')) return 'Sat';
      if (input.toLowerCase().startsWith('sun')) return 'Sun';
      
      // Last resort: just take 3 chars but avoid known month prefixes if possible
      if (input.length > 3) return input.substring(0, 3);
    }
    return input;
  }
}

class _SharedValuesRadar extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SharedValuesRadar({required this.data});

  @override
  Widget build(BuildContext context) {
    final categories = data.keys.toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 240,
      margin: const EdgeInsets.only(top: 24),
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.circle,
          getTitle: (index, angle) {
            return RadarChartTitle(
              text: categories[index],
              angle: angle,
            );
          },
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
          ),
          tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          gridBorderData: BorderSide(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
          dataSets: [
            _buildRadarSet(isPartnerA: true, categories: categories),
            _buildRadarSet(isPartnerA: false, categories: categories),
          ],
        ),
      ),
    );
  }

  RadarDataSet _buildRadarSet({required bool isPartnerA, required List<String> categories}) {
    final color = isPartnerA ? ZunoTheme.primary : ZunoTheme.tertiary;
    return RadarDataSet(
      fillColor: color.withOpacity(0.2),
      borderColor: color,
      entryRadius: 3,
      dataEntries: categories.map((cat) {
        final val = isPartnerA 
            ? (data[cat]['partnerA'] as num).toDouble() 
            : (data[cat]['partnerB'] as num).toDouble();
        return RadarEntry(value: val);
      }).toList(),
    );
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: ProfileAvatar(url: url, radius: 10, name: name),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AIInsightContainer extends StatelessWidget {
  final String content;
  final Color color;
  final IconData icon;

  const _AIInsightContainer({
    required this.content,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  content,
                  style: GoogleFonts.notoSerif(
                    fontSize: 16,
                    height: 1.6,
                    color: ZunoTheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
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
  final String title;
  final String subtitle;

  const _MoodTrendHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
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

