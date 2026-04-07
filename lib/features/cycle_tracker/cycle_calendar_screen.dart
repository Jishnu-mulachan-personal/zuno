import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';
import 'cycle_data_model.dart';

class CycleCalendarScreen extends ConsumerStatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  ConsumerState<CycleCalendarScreen> createState() =>
      _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends ConsumerState<CycleCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); // Default to today
  bool _isSnoozed = false;

  Future<void> _handlePeriodConfirmation(
      String userId, CycleData cycle, bool started) async {
    if (!started) {
      setState(() => _isSnoozed = true);
      return;
    }

    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final nextP =
        DateTime(cycle.nextPeriodDate.year, cycle.nextPeriodDate.month, cycle.nextPeriodDate.day);
    final initial = nextP.isAfter(now) ? now : nextP;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 90)), // Allow up to 90 days back
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

    if (picked != null && mounted) {
      // Show some basic local feedback/loading if needed
      await ref
          .read(dashboardProvider.notifier)
          .updateCycleStartDate(userId, picked);
      
      // Explicitly refresh so the value is absolutely latest
      ref.refresh(userProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    var cycleData = profile?.cycleData;

    // Watch historical periods
    final historyState = profile != null
        ? ref.watch(cycleHistoryNotifierProvider(profile.id))
        : CycleHistoryState();

    // Inject history into cycleData for calendar display
    if (cycleData != null && historyState.historicalPeriods.isNotEmpty) {
      cycleData = cycleData.copyWith(
          historicalPeriods: historyState.historicalPeriods);
    }

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: cycleData == null
          ? const Center(child: Text('No cycle data available.'))
          : Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      title: Text(
                        'Cycle Calendar',
                        style: GoogleFonts.notoSerif(
                          color: ZunoTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                      centerTitle: true,
                      backgroundColor: ZunoTheme.onPrimary,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: ZunoTheme.primary),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                      ),
                    ),
                    if (cycleData.shouldShowConfirmationCard && !_isSnoozed)
                      SliverToBoxAdapter(
                        child: _buildConfirmationCard(profile!.id, cycleData),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverToBoxAdapter(
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 10, 16),
                          lastDay: DateTime.utc(2030, 3, 14),
                          focusedDay: _focusedDay,
                          availableGestures: AvailableGestures
                              .horizontalSwipe, // Enable vertical scroll to pass through
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() => _focusedDay = focusedDay);

                            // Detect if we need to load more history
                            // If user swiped back to a date earlier than our earliest loaded record
                            if (historyState.earliestLoaded != null &&
                                focusedDay.isBefore(historyState.earliestLoaded!
                                    .subtract(const Duration(days: 30)))) {
                              ref
                                  .read(cycleHistoryNotifierProvider(profile!.id)
                                      .notifier)
                                  .loadMore();
                            }
                          },
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ZunoTheme.onSurface,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) =>
                                _buildCalendarDay(day, cycleData!),
                            selectedBuilder: (context, day, focusedDay) =>
                                _buildSelectedDay(day, cycleData!),
                            todayBuilder: (context, day, focusedDay) =>
                                _buildToday(day, cycleData!),
                            outsideBuilder: (context, day, focusedDay) =>
                                _buildOutsideDay(day),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ZunoTheme.onSurfaceVariant,
                            ),
                            weekendStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 16, bottom: 32),
                      sliver: SliverToBoxAdapter(
                        child: _buildDayDetails(_selectedDay, cycleData),
                      ),
                    ),
                    _buildHistoryGraph(ref),
                  ],
                ),
                if (historyState.isLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: ZunoTheme.primary,
                      minHeight: 2,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHistoryGraph(WidgetRef ref) {
    debugPrint('[_buildHistoryGraph] Watching cycleHistoryProvider...');
    final historyAsync = ref.watch(cycleHistoryProvider);
    
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 48),
      sliver: SliverToBoxAdapter(
        child: historyAsync.when(
          data: (data) {
            debugPrint('[_buildHistoryGraph] Data received. History length: ${data.history.length}');
            return data.history.isEmpty
                ? const SizedBox.shrink()
                : _CycleHistoryGraph(data: data);
          },
          loading: () {
            debugPrint('[_buildHistoryGraph] Loading history...');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: ZunoTheme.primary),
              ),
            );
          },
          error: (e, st) {
            debugPrint('[_buildHistoryGraph] ERROR in provider: $e');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading history: $e', 
                  style: const TextStyle(color: Colors.red)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayDetails(DateTime day, CycleData cycle) {
    final type = cycle.getDayType(day);
    String title;
    String subtitle;
    IconData icon;
    Color color;

    switch (type) {
      case 'period':
        title = 'Menstruation';
        subtitle = 'Your period is active. Prioritize rest and hydration.';
        icon = Icons.water_drop_rounded;
        color = Colors.red.shade400;
        break;
      case 'fertile':
        title = 'High Fertility';
        subtitle = 'You are in your peak fertile window.';
        icon = Icons.auto_awesome_rounded;
        color = Colors.green.shade400;
        break;
      case 'maybe_fertile':
        title = 'Potential Fertility';
        subtitle = 'Light chances of conception. Energy may be rising.';
        icon = Icons.favorite_rounded;
        color = Colors.green.shade200;
        break;
      case 'next_period':
        title = 'Expected Period';
        subtitle = 'Your next cycle is predicted to start today.';
        icon = Icons.event_repeat_rounded;
        color = Colors.red;
        break;
      default:
        title = 'Regular Day';
        subtitle = 'Standard phase of your cycle. Keep tracking daily.';
        icon = Icons.wb_sunny_rounded;
        color = ZunoTheme.onSurfaceVariant.withOpacity(0.5);
    }

    final dateStr = '${_getMonthName(day.month)} ${day.day}, ${day.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
                if (type != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      title.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
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
                        style: GoogleFonts.notoSerif(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: ZunoTheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildConfirmationCard(String userId, CycleData cycle) {
    final bool isDelayed = cycle.isPeriodDelayed;
    final List<Color> gradientColors = isDelayed
        ? [
            const Color(0xFFD32F2F).withOpacity(0.9), // Material Red 700
            const Color(0xFFB71C1C).withOpacity(0.8), // Material Red 900
          ]
        : [
            ZunoTheme.primary.withOpacity(0.9),
            ZunoTheme.primaryContainer.withOpacity(0.8),
          ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
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
                child: Icon(
                  isDelayed ? Icons.warning_amber_rounded : Icons.water_drop,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cycle.confirmationCardTitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Keep your predictions accurate by logging the exact start date of your cycle.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      _handlePeriodConfirmation(userId, cycle, true),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ZunoTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Yes, started',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      _handlePeriodConfirmation(userId, cycle, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Not yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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


  Widget _buildCalendarDay(DateTime day, CycleData cycle, {bool isToday = false}) {
    final type = cycle.getDayType(day);
    final prevType = cycle.getDayType(day.subtract(const Duration(days: 1)));
    final nextType = cycle.getDayType(day.add(const Duration(days: 1)));

    final isConnectedLeft =
        type != 'normal' && type != 'next_period' && prevType == type;
    final isConnectedRight =
        type != 'normal' && type != 'next_period' && nextType == type;

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isConnectedLeft ? 0 : 4,
        right: isConnectedRight ? 0 : 4,
      ),
      decoration: _getBoxDecoration(day, cycle, isToday: isToday),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: GoogleFonts.plusJakartaSans(
              color: _getTextColor(day, cycle, isToday: isToday),
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          if (type == 'next_period')
            Positioned(
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDay(DateTime day, CycleData cycle) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: _getBoxDecoration(day, cycle, isSelected: true),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildToday(DateTime day, CycleData cycle) {
    return _buildCalendarDay(day, cycle, isToday: true);
  }

  Widget _buildOutsideDay(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: GoogleFonts.plusJakartaSans(
          color: ZunoTheme.onSurfaceVariant.withOpacity(0.3),
        ),
      ),
    );
  }

  BoxDecoration? _getBoxDecoration(DateTime day, CycleData cycle,
      {bool isSelected = false, bool isToday = false}) {
    if (isSelected) {
      return BoxDecoration(
        color: ZunoTheme.primary,
        shape: BoxShape.circle,
      );
    }

    final type = cycle.getDayType(day);
    if (type == 'normal' || type == 'next_period') {
      if (isToday) {
        return BoxDecoration(
          border: Border.all(color: ZunoTheme.primary, width: 2),
          shape: BoxShape.circle,
        );
      }
      return null;
    }

    final prevType = cycle.getDayType(day.subtract(const Duration(days: 1)));
    final nextType = cycle.getDayType(day.add(const Duration(days: 1)));

    final isStart = prevType != type;
    final isEnd = nextType != type;

    Color color;
    if (type == 'period') {
      color = Colors.red.shade400.withOpacity(0.8);
    } else if (type == 'fertile') {
      color = Colors.green.shade400.withOpacity(0.8);
    } else if (type == 'maybe_fertile') {
      color = Colors.green.shade200.withOpacity(0.6);
    } else {
      return null;
    }

    return BoxDecoration(
      color: color,
      border: isToday ? Border.all(color: Colors.black, width: 2) : null,
      borderRadius: BorderRadius.horizontal(
        left: isStart ? const Radius.circular(20) : Radius.zero,
        right: isEnd ? const Radius.circular(20) : Radius.zero,
      ),
    );
  }

  Color _getTextColor(DateTime day, CycleData cycle, {bool isToday = false}) {
    final type = cycle.getDayType(day);
    if (type == 'period' || type == 'fertile') {
      return Colors.white;
    }
    if (type == 'maybe_fertile') {
      return Colors.green.shade900;
    }
    return isToday ? ZunoTheme.primary : ZunoTheme.onSurface;
  }
}

class _CycleHistoryGraph extends StatelessWidget {
  final HistoryData data;

  const _CycleHistoryGraph({required this.data});

  @override
  Widget build(BuildContext context) {
    // We'll show up to the last 12 cycles and make it scrollable
    final recentHistory = data.history.length > 12
        ? data.history.sublist(data.history.length - 12)
        : data.history;

    const double graphHeight = 150;
    // Dynamically calculate max scale based on data, minimum 40 days
    final int maxDaysInHistory = recentHistory.isEmpty 
        ? 40 
        : recentHistory.map((h) => h.durationDays).reduce((a, b) => a > b ? a : b);
    final int maxDays = maxDaysInHistory > 40 ? maxDaysInHistory + 5 : 40;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CYCLE HISTORY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recent Cycles',
                  style: GoogleFonts.notoSerif(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: graphHeight + 120,
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // Average line (dashed paint) - Stays fixed in background
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (data.averageDays / maxDays) * graphHeight + 25,
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(color: ZunoTheme.primary.withOpacity(0.3)),
                  ),
                ),
                // Average label - Stays fixed
                Positioned(
                  right: 16,
                  bottom: (data.averageDays / maxDays) * graphHeight + 30,
                  child: Text(
                    'Avg: ${data.averageDays.toStringAsFixed(1)}d',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ZunoTheme.primary.withOpacity(0.5),
                    ),
                  ),
                ),
                // Bars - Scrollable
                Positioned.fill(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: recentHistory.map((h) {
                        final double barHeight = (h.durationDays / maxDays) * graphHeight;
                        return Container(
                          width: 45, // Consistent width for each column
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${h.durationDays}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ZunoTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 24,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: ZunoTheme.primary.withOpacity(0.8),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                h.monthLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: ZunoTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
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

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    var max = size.width;
    var dashWidth = 5;
    var dashSpace = 3;
    double startX = 0;
    while (startX < max) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


