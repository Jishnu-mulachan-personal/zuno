import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import 'cycle_data_model.dart';

class CycleCalendarScreen extends ConsumerStatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  ConsumerState<CycleCalendarScreen> createState() =>
      _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends ConsumerState<CycleCalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final cycleData = profile?.cycleData;
    final state = ref.watch(dashboardProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : cycleData == null
              ? const Center(child: Text('No cycle data available.'))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverSafeArea(
                      sliver: SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(profile, textTheme),
                              const SizedBox(height: 16),
                              _buildPhaseCard(cycleData, colorScheme, textTheme),
                              const SizedBox(height: 32),
                              _buildHorizontalCalendar(cycleData, colorScheme, textTheme),
                              const SizedBox(height: 32),
                              _buildEnergyCard(colorScheme, textTheme),
                              const SizedBox(height: 32),
                              _buildLogQuickActions(colorScheme, textTheme),
                              const SizedBox(height: 32),
                              _buildAIInsight(state.cycleInsight, colorScheme, textTheme),
                              const SizedBox(height: 32),
                              _buildUpcomingSection(cycleData, colorScheme, textTheme),
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader(UserProfile profile, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.menu, color: textTheme.bodyLarge?.color?.withOpacity(0.8)),
              onPressed: () {},
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: textTheme.bodyLarge?.color?.withOpacity(0.1),
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null
                  ? Icon(Icons.person, color: textTheme.bodyLarge?.color?.withOpacity(0.5))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Hello, ${profile.displayName.split(' ').first}',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Let's tune into your body's rhythm",
          style: textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPhaseCard(CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
    final phase = cycle.currentPhase;

    String displayName = 'Follicular Phase';
    Color mainColor = colorScheme.secondary;
    Color gradientStart = colorScheme.secondaryContainer;
    String badgeText = "Potential Fertility";

    if (phase == 'Ovulation') {
      displayName = 'Ovulation Window';
      mainColor = colorScheme.tertiary; // Dark teal in Hearth
      gradientStart = colorScheme.primaryContainer; // Terracotta/Orange
      badgeText = "High Fertility";
    } else if (phase == 'Menstruation') {
      displayName = 'Menstruation';
      mainColor = colorScheme.primary;
      gradientStart = colorScheme.primaryFixed;
      badgeText = "Self Care";
    } else if (phase == 'Luteal') {
      displayName = 'Luteal Phase';
      gradientStart = colorScheme.tertiaryFixed;
      mainColor = colorScheme.tertiary;
      badgeText = "Rest & Reset";
    }

    final dayProgress = cycle.currentCycleDay;
    final totalDays = cycle.cycleLength;
    final progress = (dayProgress / totalDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are in your',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  style: textTheme.headlineSmall?.copyWith(
                    color: mainColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Day $dayProgress  •  ${_getMonthName(DateTime.now().month)} ${DateTime.now().day}',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 14, color: mainColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: textTheme.labelSmall?.copyWith(
                          color: mainColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(100, 100),
                  painter: _RingPainter(
                    progress: progress,
                    gradientStart: gradientStart,
                    gradientEnd: mainColor,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayProgress',
                        style: textTheme.headlineMedium?.copyWith(
                          color: mainColor,
                          height: 1.1,
                          fontSize: 26,
                        ),
                      ),
                      Text(
                        'of $totalDays',
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
    final today = DateTime.now();
    final dates = List.generate(21,
        (i) => today.subtract(const Duration(days: 4)).add(Duration(days: i)));

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = date.day == _selectedDate.day &&
                  date.month == _selectedDate.month;

              const dayNames = [
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
                'SUN'
              ];
              final dayName = dayNames[date.weekday - 1];

              final phase = cycle.getDayType(date);
              Color dotColor = Colors.transparent;
              if (phase == 'period') {
                dotColor = colorScheme.primary;
              } else if (phase == 'fertile' || phase == 'maybe_fertile') {
                dotColor = colorScheme.tertiary;
              } else {
                dotColor = colorScheme.onSurfaceVariant.withOpacity(0.2);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: SizedBox(
                  width: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: colorScheme.tertiary,
                                borderRadius: BorderRadius.circular(24),
                              )
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayName,
                              style: textTheme.labelSmall?.copyWith(
                                color: isSelected ? colorScheme.onTertiary : colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${date.day}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? colorScheme.onTertiary : colorScheme.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.onTertiary : dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 0),
          child: Divider(color: colorScheme.outlineVariant, height: 1),
        ),
      ],
    );
  }

  Widget _buildEnergyCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: AssetImage('assets/images/energy_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: SizedBox(
              height: 190,
              child: Image.asset(
                'assets/images/energy_character.png',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const SizedBox(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Today's Energy",
                      style: textTheme.labelMedium,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline,
                        size: 14, color: colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Radiant",
                  style: textTheme.headlineLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Icon(Icons.wb_sunny_outlined,
                    color: colorScheme.primary, size: 30),
                const SizedBox(height: 48),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.55,
                  child: Text(
                    "High energy and sociability.\nA great day for connection and creativity.",
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogQuickActions(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Log how you feel",
              style: textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "View all",
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem(Icons.water_drop_outlined, "Body",
                colorScheme.primaryContainer.withOpacity(0.2), colorScheme.primary, textTheme),
            _buildActionItem(Icons.sentiment_satisfied_outlined, "Mood",
                colorScheme.tertiaryContainer.withOpacity(0.2), colorScheme.tertiary, textTheme),
            _buildActionItem(Icons.vaccines_outlined, "Flow",
                colorScheme.primaryContainer.withOpacity(0.2), colorScheme.primary, textTheme),
            _buildActionItem(Icons.edit_outlined, "Notes",
                colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant, textTheme),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, Color bgColor, Color iconColor, TextTheme textTheme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Icon(icon, size: 28, color: iconColor),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildAIInsight(String? genericInsight, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 16, color: colorScheme.tertiary),
              const SizedBox(width: 8),
              Text(
                "AI Insight",
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  genericInsight ??
                      "Estrogen is rising, which may enhance your mood and energy. Stay hydrated and enjoy this vibrant phase!",
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colorScheme.primaryContainer, colorScheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Upcoming",
              style: textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "Next 7 days",
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _buildUpcomingCard(
                  "Feb 11 – 12", "Peak Fertility", colorScheme.tertiary, true, colorScheme, textTheme),
              const SizedBox(width: 12),
              _buildUpcomingCard(
                  "Feb 13 – 15", "Ovulation", colorScheme.primary, false, colorScheme, textTheme),
              const SizedBox(width: 12),
              _buildUpcomingCard(
                  "Feb 16 – 20", "Energy Shift", colorScheme.secondary, true, colorScheme, textTheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(
      String dateRange, String title, Color accentColor, bool isWave, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            dateRange,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          isWave
              ? Icon(Icons.waves, size: 24, color: accentColor)
              : Icon(Icons.radio_button_checked, size: 20, color: accentColor),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color gradientStart;
  final Color gradientEnd;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.gradientStart,
    required this.gradientEnd,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 4;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    double startAngle = -math.pi / 2;
    double dashWidth = 0.08;
    double dashSpace = 0.12;
    double totalAngles = 2 * math.pi;
    for (double i = 0; i < totalAngles; i += dashWidth + dashSpace) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i,
        dashWidth,
        false,
        bgPaint,
      );
    }

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [gradientStart, gradientEnd],
      stops: const [0.0, 1.0],
    );

    final highlightPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
