import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import 'cycle_data_model.dart';

class CycleHistoryScreen extends ConsumerStatefulWidget {
  const CycleHistoryScreen({super.key});

  @override
  ConsumerState<CycleHistoryScreen> createState() =>
      _CycleHistoryScreenState();
}

class _CycleHistoryScreenState extends ConsumerState<CycleHistoryScreen> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    if (nextMonth.isAfter(DateTime(now.year, now.month))) return;
    HapticFeedback.lightImpact();
    setState(() {
      _displayedMonth = nextMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final cycleData = profile?.cycleData;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Cycle Calendar',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: cycleData == null
                  ? const Center(
                      heightFactor: 8,
                      child: CircularProgressIndicator(),
                    )
                  : _buildBody(profile!, cycleData, colorScheme, textTheme),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────

  Widget _buildBody(UserProfile profile, CycleData cycleData,
      ColorScheme colorScheme, TextTheme textTheme) {
    final historyState =
        ref.watch(cycleHistoryNotifierProvider(profile.id));

    // Merge all known period starts: historical list + lastPeriodDate
    final allPeriods = <DateTime>{
      ...historyState.historicalPeriods,
      DateTime(cycleData.lastPeriodDate.year, cycleData.lastPeriodDate.month,
          cycleData.lastPeriodDate.day),
    }.toList()
      ..sort((a, b) => a.compareTo(b)); // ascending

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(colorScheme, textTheme),
        const SizedBox(height: 24),
        _buildCalendarCard(cycleData, allPeriods, colorScheme, textTheme),
        const SizedBox(height: 16),
        // Cycle stats strip for the displayed month
        _buildMonthStatsStrip(
            _displayedMonth, allPeriods, cycleData, colorScheme, textTheme),
        const SizedBox(height: 32),
        _buildHistorySection(
            profile.id, cycleData, allPeriods, colorScheme, textTheme),
      ],
    );
  }

  // ── Legend ──────────────────────────────────────────────────────────────────

  Widget _buildLegend(ColorScheme colorScheme, TextTheme textTheme) {
    final items = [
      (_legendDot(colorScheme.primary), 'Period'),
      (_legendDot(colorScheme.tertiary), 'Fertile'),
      (_legendDot(colorScheme.tertiary.withOpacity(0.4)), 'Maybe Fertile'),
      (_legendDot(colorScheme.onSurfaceVariant.withOpacity(0.12)), 'Normal'),
    ];
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: items
          .map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  e.$1,
                  const SizedBox(width: 6),
                  Text(e.$2,
                      style: textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ))
          .toList(),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ── Calendar card ────────────────────────────────────────────────────────────

  Widget _buildCalendarCard(CycleData cycle, List<DateTime> allPeriods,
      ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMonthHeader(colorScheme, textTheme),
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.4)),
          _buildWeekdayLabels(colorScheme, textTheme),
          _buildCalendarGrid(cycle, allPeriods, colorScheme, textTheme),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(ColorScheme colorScheme, TextTheme textTheme) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final canGoNext =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1)
            .isBefore(
                DateTime(DateTime.now().year, DateTime.now().month + 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: _prevMonth,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 4),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: canGoNext ? _nextMonth : null,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels(ColorScheme colorScheme, TextTheme textTheme) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(CycleData cycle, List<DateTime> allPeriods,
      ColorScheme colorScheme, TextTheme textTheme) {
    final firstDay =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: List.generate(rows, (rowIdx) {
          return Row(
            children: List.generate(7, (colIdx) {
              final cellIdx = rowIdx * 7 + colIdx;
              final dayNumber = cellIdx - startOffset + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 46));
              }

              final date = DateTime(
                  _displayedMonth.year, _displayedMonth.month, dayNumber);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isFuture = date.isAfter(today);

              // Use enhanced historical phase detection
              final phase = isFuture
                  ? 'future'
                  : _getHistoricalDayType(date, cycle, allPeriods);

              return Expanded(
                  child: _buildDayCell(
                      date, dayNumber, phase, isToday, colorScheme, textTheme));
            }),
          );
        }),
      ),
    );
  }

  /// Compute the phase for any historical date using the full list of period
  /// starts (sorted ascending). For months that fall between two logged period
  /// starts we can calculate fertile/ovulation windows accurately.
  String _getHistoricalDayType(
      DateTime date, CycleData cycle, List<DateTime> allPeriods) {
    final t = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayMid = DateTime(today.year, today.month, today.day);

    // Find the period start that is <= t (the cycle that t belongs to)
    DateTime? cycleStart;
    DateTime? nextCycleStart;

    for (int i = 0; i < allPeriods.length; i++) {
      final s = DateTime(
          allPeriods[i].year, allPeriods[i].month, allPeriods[i].day);
      if (!s.isAfter(t)) {
        cycleStart = s;
        if (i + 1 < allPeriods.length) {
          nextCycleStart = DateTime(allPeriods[i + 1].year,
              allPeriods[i + 1].month, allPeriods[i + 1].day);
        }
      }
    }

    if (cycleStart == null) {
      // Before any known period — delegate to cycle model
      return cycle.getDayType(date);
    }

    final dayOfCycle = t.difference(cycleStart).inDays + 1;

    // Period days
    if (dayOfCycle <= cycle.periodDuration) return 'period';

    // Determine cycle length for this cycle:
    // If we have a confirmed next period, use actual gap; else use typical length.
    final effectiveCycleLength = nextCycleStart != null
        ? nextCycleStart.difference(cycleStart).inDays
        : cycle.cycleLength;

    // Ovulation is ~14 days before next period, fertile window is ±5 days
    final ovDay = effectiveCycleLength - 14;
    final minLimit = cycle.periodDuration + 1;

    // Safety: if cycle is too short, fertile window logic isn't applicable
    if (effectiveCycleLength < minLimit) {
      return 'normal';
    }

    final fwStartDay = (ovDay - 5).clamp(minLimit, effectiveCycleLength);
    final fwEndDay = (ovDay + 1).clamp(minLimit, effectiveCycleLength);
    final maybeFwStartDay = (fwStartDay - 2).clamp(minLimit, effectiveCycleLength);
    final maybeFwEndDay = (fwEndDay + 1).clamp(minLimit, effectiveCycleLength);

    if (dayOfCycle >= fwStartDay && dayOfCycle <= fwEndDay) return 'fertile';
    if (dayOfCycle >= maybeFwStartDay && dayOfCycle <= maybeFwEndDay) {
      return 'maybe_fertile';
    }

    // Days past cycle length but before today (delayed / current cycle)
    if (dayOfCycle > effectiveCycleLength) {
      if (!t.isAfter(todayMid)) return 'delayed';
      return 'future';
    }

    return 'normal';
  }

  Widget _buildDayCell(DateTime date, int day, String phase, bool isToday,
      ColorScheme colorScheme, TextTheme textTheme) {
    Color bgColor = Colors.transparent;
    Color textColor = colorScheme.onSurface;
    Color? dotColor;

    switch (phase) {
      case 'period':
        bgColor = colorScheme.primary.withOpacity(0.15);
        textColor = colorScheme.primary;
        dotColor = colorScheme.primary;
        break;
      case 'fertile':
        bgColor = colorScheme.tertiary.withOpacity(0.12);
        textColor = colorScheme.tertiary;
        dotColor = colorScheme.tertiary;
        break;
      case 'maybe_fertile':
        bgColor = colorScheme.tertiary.withOpacity(0.06);
        textColor = colorScheme.tertiary.withOpacity(0.7);
        dotColor = colorScheme.tertiary.withOpacity(0.4);
        break;
      case 'next_period':
      case 'delayed':
        bgColor = colorScheme.primary.withOpacity(0.07);
        textColor = colorScheme.primary.withOpacity(0.7);
        dotColor = colorScheme.primary.withOpacity(0.4);
        break;
      case 'future':
        textColor = colorScheme.onSurfaceVariant.withOpacity(0.35);
        break;
      default:
        textColor = colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isToday
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (dotColor != null) ...[
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Month Stats Strip ───────────────────────────────────────────────────────

  /// Shows "X period days" and "Cycle length: Y days" for the displayed month.
  Widget _buildMonthStatsStrip(
      DateTime month,
      List<DateTime> allPeriods,
      CycleData cycle,
      ColorScheme cs,
      TextTheme tt) {
    // Count period days in this month
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    int periodDayCount = 0;
    int fertileDayCount = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final phase = _getHistoricalDayType(date, cycle, allPeriods);
      if (phase == 'period') periodDayCount++;
      if (phase == 'fertile' || phase == 'maybe_fertile') fertileDayCount++;
    }

    // Find the cycle that started in or just before this month
    DateTime? cycleStartForMonth;
    DateTime? nextCycleStart;
    for (int i = 0; i < allPeriods.length; i++) {
      final s = allPeriods[i];
      final monthEnd = DateTime(month.year, month.month + 1, 0);
      if (!s.isAfter(monthEnd)) {
        cycleStartForMonth = s;
        if (i + 1 < allPeriods.length) {
          nextCycleStart = allPeriods[i + 1];
        }
      }
    }

    int? cycleLength;
    if (cycleStartForMonth != null && nextCycleStart != null) {
      cycleLength = nextCycleStart.difference(cycleStartForMonth).inDays;
    }

    final stats = <_MonthStat>[
      _MonthStat(
        icon: Icons.water_drop_rounded,
        label: 'Period Days',
        value: '$periodDayCount',
        color: cs.primary,
      ),
      _MonthStat(
        icon: Icons.local_florist_outlined,
        label: 'Fertile Days',
        value: '$fertileDayCount',
        color: cs.tertiary,
      ),
      _MonthStat(
        icon: Icons.loop_rounded,
        label: 'Cycle Length',
        value: cycleLength != null ? '${cycleLength}d' : '~${cycle.cycleLength}d',
        color: cs.secondary,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(s.icon, color: s.color, size: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  s.value,
                  style: tt.titleMedium?.copyWith(
                    color: s.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.label,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── History Section ─────────────────────────────────────────────────────────

  Widget _buildHistorySection(
      String userId,
      CycleData cycleData,
      List<DateTime> allPeriods,
      ColorScheme colorScheme,
      TextTheme textTheme) {
    final historyState = ref.watch(cycleHistoryNotifierProvider(userId));
    final notifier =
        ref.read(cycleHistoryNotifierProvider(userId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Period History',
          style:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Your past cycle start dates',
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (historyState.isLoading &&
            historyState.historicalPeriods.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator()))
        else if (historyState.historicalPeriods.isEmpty)
          _buildEmptyHistory(colorScheme, textTheme)
        else ...[
          ...historyState.historicalPeriods
              .asMap()
              .entries
              .map((entry) => _buildHistoryItem(
                  entry.key,
                  entry.value,
                  historyState.historicalPeriods,
                  cycleData.cycleLength,
                  colorScheme,
                  textTheme))
              .toList(),
          if (!historyState.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => notifier.loadMore(),
                  icon: Icon(Icons.expand_more_rounded,
                      color: colorScheme.primary, size: 18),
                  label: Text('Load more',
                      style: textTheme.labelMedium
                          ?.copyWith(color: colorScheme.primary)),
                ),
              ),
            )
          else
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator())),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyHistory(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded,
              size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No period history yet',
              style: textTheme.titleSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Your tracked cycles will appear here.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
      int index,
      DateTime startDate,
      List<DateTime> allPeriods,
      int typicalCycleLength,
      ColorScheme colorScheme,
      TextTheme textTheme) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    // Compute actual cycle length to the NEXT period (desc sorted → prev index = later date)
    int? actualLength;
    if (index > 0) {
      final prev = allPeriods[index - 1];
      actualLength = prev.difference(startDate).inDays;
    }

    final diff = actualLength ?? typicalCycleLength;
    final lengthLabel =
        actualLength != null ? '$diff days' : '~$diff days';
    final lengthColor = (actualLength == null)
        ? colorScheme.onSurfaceVariant
        : (diff < typicalCycleLength - 3 || diff > typicalCycleLength + 3)
            ? colorScheme.error
            : colorScheme.tertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${startDate.day}',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  monthNames[startDate.month - 1],
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary.withOpacity(0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${monthNames[startDate.month - 1]} ${startDate.day}, ${startDate.year}',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cycle started',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: lengthColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              lengthLabel,
              style: textTheme.labelSmall?.copyWith(
                color: lengthColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper model ──────────────────────────────────────────────────────────────

class _MonthStat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MonthStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
}

// ── Nav Button ────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _NavButton(
      {required this.icon, required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.onSurfaceVariant.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withOpacity(0.3),
        ),
      ),
    );
  }
}
