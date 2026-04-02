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
  DateTime? _selectedDay;
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
          colorScheme: const ColorScheme.light(
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
      ref.read(dashboardProvider.notifier).updateCycleStartDate(userId, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final cycleData = profile?.cycleData;

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      appBar: AppBar(
        title: Text(
          'Cycle Calendar',
          style: GoogleFonts.notoSerif(
            color: ZunoTheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: ZunoTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ZunoTheme.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: cycleData == null
          ? const Center(child: Text('No cycle data available.'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (cycleData.shouldShowConfirmationCard && !_isSnoozed)
                    _buildConfirmationCard(profile!.id, cycleData),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
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
                            _buildCalendarDay(day, cycleData),
                        selectedBuilder: (context, day, focusedDay) =>
                            _buildSelectedDay(day, cycleData),
                        todayBuilder: (context, day, focusedDay) =>
                            _buildToday(day, cycleData),
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
                  const SizedBox(height: 32),
                  _buildLegend(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
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

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _LegendItem(color: Colors.red.shade400, label: 'Menstruation'),
            const SizedBox(height: 8),
            _LegendItem(color: Colors.green.shade400, label: 'Fertile Window'),
            const SizedBox(height: 8),
            _LegendItem(color: Colors.green.shade200, label: 'Maybe Fertile'),
            const SizedBox(height: 8),
            const _LegendItem(color: Colors.red, label: 'Predicted Period', isDot: true),
          ],
        ),
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
      return const BoxDecoration(
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDot;

  const _LegendItem(
      {required this.color, required this.label, this.isDot = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: isDot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isDot ? null : BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: ZunoTheme.onSurface,
          ),
        ),
      ],
    );
  }
}
