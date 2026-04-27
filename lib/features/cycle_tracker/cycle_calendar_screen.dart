import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

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
  late ScrollController _calendarController;
  bool _isDismissedPeriodCard = false;

  @override
  void initState() {
    super.initState();
    // 90 days back, 90 forward. Today is index 90.
    // Item width is 58.
    _calendarController = ScrollController();

    _calendarController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_calendarController.hasClients) {
        final screenWidth = MediaQuery.of(context).size.width;
        final targetOffset = (90 * 58.0) - (screenWidth / 2) + 29;
        _calendarController.jumpTo(targetOffset);
      }
    });
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

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
                          child: Builder(builder: (context) {
                            final historyState = ref.watch(
                                cycleHistoryNotifierProvider(profile.id));
                            final cycleWithHistory = cycleData.copyWith(
                              historicalPeriods: historyState.historicalPeriods,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(profile, textTheme),
                                const SizedBox(height: 16),
                                _buildPhaseCard(
                                    cycleWithHistory, colorScheme, textTheme),
                                const SizedBox(height: 32),
                                _buildPeriodConfirmationCard(cycleWithHistory,
                                    colorScheme, textTheme, ref),
                                _buildHorizontalCalendar(
                                    cycleWithHistory, colorScheme, textTheme),
                                _buildSelectedDayDetail(
                                    cycleWithHistory, colorScheme, textTheme),
                                const SizedBox(height: 32),
                                _buildEnergyCard(
                                  state.energyCategory,
                                  state.energyMessage,
                                  state.energyImageName,
                                  state.energySignedUrl,
                                  colorScheme,
                                  textTheme,
                                ),
                                const SizedBox(height: 32),
                                _buildUnifiedLogBlock(state, colorScheme, textTheme),
                                const SizedBox(height: 32),
                                _buildAIInsight(
                                    state.cycleInsight, colorScheme, textTheme),
                                const SizedBox(height: 32),
                                _buildHistorySection(colorScheme, textTheme),
                                const SizedBox(height: 32),
                                _buildUpcomingSection(
                                    cycleWithHistory, colorScheme, textTheme),
                                const SizedBox(height: 120),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildSelectedDayDetail(
      CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
    if (_isToday(_selectedDate)) return const SizedBox.shrink();

    final type = cycle.getDayType(_selectedDate);
    final dayProgress = cycle.getDayProgress(_selectedDate);

    String phaseName = "Follicular Phase";
    Color accentColor = colorScheme.secondary;
    if (type == 'period') {
      phaseName = "Menstruation";
      accentColor = colorScheme.primary;
    } else if (type == 'fertile' || type == 'maybe_fertile') {
      phaseName = "Ovulation Window";
      accentColor = colorScheme.tertiary;
    } else if (type == 'delayed' || type == 'next_period') {
      phaseName = "Upcoming Period";
      accentColor = colorScheme.primary;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_getMonthName(_selectedDate.month)} ${_selectedDate.day}",
                  style: textTheme.labelLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: accentColor),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              phaseName,
              style: textTheme.headlineSmall?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (dayProgress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dayProgress,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _getPhaseInsight(phaseName),
              style: textTheme.bodySmall?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPhaseInsight(String phase) {
    if (phase == "Menstruation") {
      return "Focus on gentle movement and nourishing foods. Your body is in a state of release.";
    } else if (phase == "Ovulation Window") {
      return "Energy and confidence are at their peak. A great time for social activities and meaningful work.";
    } else if (phase == "Upcoming Period") {
      return "You might notice a shift in energy. Start winding down and prioritize quality sleep.";
    } else if (phase == "Luteal Phase") {
      return "Progesterone is high, urging you to turn inward. It's perfectly okay to decline social invitations.";
    }
    return "Estrogen is rising, helping you feel more outgoing and productive. Harness this creative spark.";
  }

  Widget _buildHeader(UserProfile profile, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
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

  Widget _buildPhaseCard(
      CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You are in your',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayName,
                    style: textTheme.headlineSmall?.copyWith(
                      color: mainColor,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
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
          const SizedBox(width: 8),
          // Progress Indicator Unit
          Center(
            child: SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(90, 90),
                    painter: _RingPainter(
                      progress: progress,
                      gradientStart: gradientStart,
                      gradientEnd: mainColor,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayProgress',
                        style: textTheme.headlineMedium?.copyWith(
                          color: mainColor,
                          height: 1.1,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'of $totalDays',
                        style: textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodConfirmationCard(CycleData cycle, ColorScheme colorScheme,
      TextTheme textTheme, WidgetRef ref) {
    if (!cycle.shouldShowConfirmationCard || _isDismissedPeriodCard) {
      return const SizedBox.shrink();
    }

    final isDelayed = cycle.isPeriodDelayed;
    final subtitle = isDelayed
        ? 'Your period was expected a while ago. Has it started?'
        : 'Your period is expected soon. Has it started?';

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: colorScheme.primary.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.water_drop_rounded,
                        color: colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cycle.confirmationCardTitle,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Started Today
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      ref
                          .read(dashboardProvider.notifier)
                          .updateCycleStartDate(cycle.userId, DateTime.now());
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('Started Today'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Started Earlier
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 14)),
                        lastDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: colorScheme,
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(dashboardProvider.notifier)
                            .updateCycleStartDate(cycle.userId, picked);
                      }
                    },
                    icon: Icon(Icons.calendar_today_outlined,
                        size: 16, color: colorScheme.primary),
                    label: Text('Started Earlier',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        )),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Not Yet
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isDismissedPeriodCard = true);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Not yet',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalCalendar(
      CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
    final today = DateTime.now();
    final dates = List.generate(181,
        (i) => today.subtract(const Duration(days: 90)).add(Duration(days: i)));

    final scrollOffset = _calendarController.hasClients
        ? _calendarController.offset
        : (90 * 58.0) - (MediaQuery.of(context).size.width / 2) + 29;

    final visibleWidth = MediaQuery.of(context).size.width - 48;
    final leftIndex = (scrollOffset / 58.0).floor().clamp(0, dates.length - 1);
    final rightIndex = ((scrollOffset + visibleWidth) / 58.0)
        .floor()
        .clamp(0, dates.length - 1);

    final leftDate = dates[leftIndex];
    final rightDate = dates[rightIndex];

    String headerText = _getMonthName(leftDate.month).toUpperCase();
    if (leftDate.month != rightDate.month) {
      headerText =
          "${_getMonthName(leftDate.month).toUpperCase()} - ${_getMonthName(rightDate.month).toUpperCase()}";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            headerText,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            controller: _calendarController,
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
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDate = date;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 11, // Adjusted to perfectly bisect the 6px dot
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
                                color: isSelected
                                    ? colorScheme.onTertiary
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${date.day}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.onTertiary
                                    : colorScheme.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.onTertiary
                                    : dotColor,
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
      ],
    );
  }

  Widget _buildEnergyCard(String? category, String? message, String? imageName,
      String? signedUrl, ColorScheme colorScheme, TextTheme textTheme) {
    if (signedUrl != null && signedUrl.isNotEmpty) {
      debugPrint('[EnergyCard] Loading character from signed URL: $signedUrl');
    }

    final energyTitle = category ?? "Radiant";
    final energyDesc = message ??
        "High energy and sociability.\nA great day for connection and creativity.";

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
              child: signedUrl != null && signedUrl.isNotEmpty
                  ? Image.network(
                      signedUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) {
                        debugPrint(
                            '[EnergyCard] Network image failed to load: $err');
                        return Image.asset(
                          'assets/images/energy_character.png',
                          fit: BoxFit.contain,
                        );
                      },
                    )
                  : Image.asset(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      energyTitle,
                      style: textTheme.headlineLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    // const SizedBox(width: 12),
                    // Icon(
                    //     category == 'Unplugged'
                    //         ? Icons.battery_charging_full_rounded
                    //         : category == 'Calm'
                    //             ? Icons.self_improvement_rounded
                    //             : category == 'Balanced'
                    //                 ? Icons.balance_rounded
                    //                 : category == 'Sparkling'
                    //                     ? Icons.auto_awesome
                    //                     : Icons.wb_sunny_outlined,
                    //     color: colorScheme.primary,
                    //     size: 30),
                  ],
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.55,
                  child: Text(
                    energyDesc,
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

  Widget _buildUnifiedLogBlock(
      DashboardState state, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.predictedPhysical.isNotEmpty ||
              state.predictedMood.isNotEmpty) ...[
            _buildPredictedSection(state, colorScheme, textTheme),
            const SizedBox(height: 32),
            Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 24),
          ],
          _buildLogQuickActions(colorScheme, textTheme),
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
              onPressed: () => context.push('/log_feel'),
              child: Text(
                "Log now",
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem(
              Icons.water_drop_outlined,
              "Body",
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.primary,
              textTheme,
              onTap: () => context.push('/log_feel'),
            ),
            _buildActionItem(
              Icons.sentiment_satisfied_outlined,
              "Mood",
              colorScheme.tertiaryContainer.withOpacity(0.2),
              colorScheme.tertiary,
              textTheme,
              onTap: () => context.push('/log_feel'),
            ),
            _buildActionItem(
              Icons.vaccines_outlined,
              "Flow",
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.primary,
              textTheme,
              onTap: () => context.push('/log_feel'),
            ),
            _buildActionItem(
              Icons.edit_outlined,
              "Notes",
              colorScheme.surfaceContainerHighest,
              colorScheme.onSurfaceVariant,
              textTheme,
              onTap: () => context.push('/log_feel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color bgColor,
      Color iconColor, TextTheme textTheme,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Icon(icon, size: 24, color: iconColor),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictedSection(
      DashboardState state, ColorScheme colorScheme, TextTheme textTheme) {
    final physical = state.predictedPhysical.take(3).toList();
    final moods = state.predictedMood.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  "Zuno Predicted",
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (physical.isNotEmpty) ...[
          Text(
            "Potential Symptoms",
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: physical.map((tag) {
              final label = tag.split(':').last.replaceAll('_', ' ');
              return _buildPredictedChip(
                  label, colorScheme.primary, colorScheme);
            }).toList(),
          ),
        ],
        if (moods.isNotEmpty) ...[
          if (physical.isNotEmpty) const SizedBox(height: 16),
          Text(
            "Likely Moods",
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: moods.map((tag) {
              final label = tag.split(':').last.replaceAll('_', ' ');
              return _buildPredictedChip(
                  label, colorScheme.tertiary, colorScheme);
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPredictedChip(String label, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAIInsight(
      String? genericInsight, ColorScheme colorScheme, TextTheme textTheme) {
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
              Icon(Icons.auto_awesome, size: 16, color: colorScheme.tertiary),
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

  Widget _buildHistorySection(ColorScheme colorScheme, TextTheme textTheme) {
    return GestureDetector(
      onTap: () => context.push('/cycle_history'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.history_rounded,
                  color: colorScheme.tertiary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cycle History",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "View your past cycles and trends",
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection(
      CycleData cycle, ColorScheme colorScheme, TextTheme textTheme) {
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
              _buildUpcomingCard("Feb 11 – 12", "Peak Fertility",
                  colorScheme.tertiary, true, colorScheme, textTheme),
              const SizedBox(width: 12),
              _buildUpcomingCard("Feb 13 – 15", "Ovulation",
                  colorScheme.primary, false, colorScheme, textTheme),
              const SizedBox(width: 12),
              _buildUpcomingCard("Feb 16 – 20", "Energy Shift",
                  colorScheme.secondary, true, colorScheme, textTheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(String dateRange, String title, Color accentColor,
      bool isWave, ColorScheme colorScheme, TextTheme textTheme) {
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
    final radius = (size.width / 2) - 8;
    const totalSegments = 30; // High segment count for a smooth premium look
    const gapAngle = 0.04;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final totalAngle = 2 * math.pi;
    final totalGap = gapAngle * totalSegments;
    final usableAngle = totalAngle - totalGap;
    final segmentAngle = usableAngle / totalSegments;

    final filledAngle = usableAngle * progress;

    // 1. Prepare Paints
    // Solid background track for better visibility of the full circle
    final trackPaint = Paint()
      ..color = backgroundColor.withOpacity(0.1)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final progressGradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [gradientStart, gradientEnd],
      stops: const [0.0, 1.0],
    );

    final progressPaint = Paint()
      ..shader = progressGradient.createShader(rect)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw a continuous light track underneath the segments
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    double currentAngle = -math.pi / 2;

    // 2. Draw Segments
    for (int i = 0; i < totalSegments; i++) {
      // Draw background segment highlights (optional, adds depth)
      canvas.drawArc(
        rect,
        currentAngle,
        segmentAngle,
        false,
        trackPaint..color = backgroundColor.withOpacity(0.08),
      );

      // Draw filled segment part
      if (filledAngle > 0) {
        final remaining = filledAngle - (i * segmentAngle);

        if (remaining > 0) {
          final drawAngle =
              remaining >= segmentAngle ? segmentAngle : remaining;

          canvas.drawArc(
            rect,
            currentAngle,
            drawAngle,
            false,
            progressPaint,
          );
        }
      }

      currentAngle += segmentAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
