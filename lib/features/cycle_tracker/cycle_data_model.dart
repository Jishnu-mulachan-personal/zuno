

class CycleData {
  final String id;
  final String userId;
  final DateTime lastPeriodDate;
  final int cycleLength;
  final int periodDuration;
  final bool isTracking;

  CycleData({
    required this.id,
    required this.userId,
    required this.lastPeriodDate,
    required this.cycleLength,
    required this.periodDuration,
    required this.isTracking,
  });

  /// The day of the current cycle (1 to cycleLength)
  int get currentCycleDay {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final lastMidnight =
        DateTime(lastPeriodDate.year, lastPeriodDate.month, lastPeriodDate.day);

    final diff = todayMidnight.difference(lastMidnight).inDays;
    
    // Day 1 is the first day of the period
    int day = diff + 1;

    // Modulo if user hasn't synced
    if (day > cycleLength && day > 0) {
      day = (day - 1) % cycleLength + 1;
    } else if (day <= 0) {
      day = 1;
    }
    return day;
  }

  /// Calculates the start date of the current cycle interval
  DateTime get currentCycleStart {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final lastMidnight =
        DateTime(lastPeriodDate.year, lastPeriodDate.month, lastPeriodDate.day);

    final diff = todayMidnight.difference(lastMidnight).inDays;
    final cycleNum = diff >= 0 ? diff ~/ cycleLength : 0;
    
    return lastMidnight.add(Duration(days: cycleNum * cycleLength));
  }

  /// Next predicted period
  DateTime get nextPeriodDate {
    return currentCycleStart.add(Duration(days: cycleLength));
  }

  /// Predicted ovulation date
  DateTime get ovulationDate {
    return nextPeriodDate.subtract(const Duration(days: 14));
  }

  /// Phase categorization
  String get currentPhase {
    final day = currentCycleDay;
    if (day <= periodDuration) return 'Menstruation';
    
    // If standard 28 day cycle, ov is 14. 
    // Fertile window starts 5 days before, ends 1 day after.
    final ovDay = cycleLength - 14; 
    final fwStartDay = ovDay - 5;
    final fwEndDay = ovDay + 1;

    if (day < fwStartDay) return 'Follicular';
    if (day >= fwStartDay && day <= fwEndDay) return 'Ovulation';
    return 'Luteal';
  }

  /// Provide a predictable default mood emoji based on phase
  String get predictedMood {
    switch (currentPhase) {
      case 'Menstruation':
        return '😌'; // Calm or Tired
      case 'Follicular':
        return '✨'; // Amazing/Energetic
      case 'Ovulation':
        return '😊'; // Happy
      case 'Luteal':
      default:
        return '😕'; // Meh/Sensitive 
    }
  }

  /// Helpful text to show in Dashboard card
  String get phaseSubtitle {
    switch (currentPhase) {
      case 'Menstruation':
        return 'Take it easy, rest up.';
      case 'Follicular':
        return 'Energy is rising. A great time to be active!';
      case 'Ovulation':
        return 'High chance of conception today.';
      case 'Luteal':
      default:
        return 'Nesting phase. You might feel more sensitive.';
    }
  }

  /// Check what a generic date is (for Calendar markers)
  String getDayType(DateTime target) {
    // Normalise to 00:00:00
    final t = DateTime(target.year, target.month, target.day);
    final lastMidnight =
        DateTime(lastPeriodDate.year, lastPeriodDate.month, lastPeriodDate.day);
    final diff = t.difference(lastMidnight).inDays;

    if (diff < 0) return 'normal';

    final dayOfCycle = (diff % cycleLength) + 1;
    final cycleStartForTarget = t.subtract(Duration(days: dayOfCycle - 1));
    final nextPForTarget = cycleStartForTarget.add(Duration(days: cycleLength));
    final ovForTarget = nextPForTarget.subtract(const Duration(days: 14));
    final fwStart = ovForTarget.subtract(const Duration(days: 5));
    final fwEnd = ovForTarget.add(const Duration(days: 1));
    
    // Maybe fertile window (2 days before and 1 day after main window)
    final maybeFwStart = fwStart.subtract(const Duration(days: 2));
    final maybeFwEnd = fwEnd.add(const Duration(days: 1));

    if (dayOfCycle <= periodDuration) return 'period';
    if (!t.isBefore(fwStart) && !t.isAfter(fwEnd)) return 'fertile';
    if (!t.isBefore(maybeFwStart) && !t.isAfter(maybeFwEnd)) return 'maybe_fertile';
    if (t.isAtSameMomentAs(nextPForTarget)) return 'next_period';

    return 'normal';
  }

  factory CycleData.fromMap(Map<String, dynamic> map) {
    return CycleData(
      id: map['id'],
      userId: map['user_id'],
      lastPeriodDate: DateTime.parse(map['last_period_date']),
      cycleLength: map['cycle_length'] ?? 28,
      periodDuration: map['period_duration'] ?? 5,
      isTracking: map['is_tracking'] ?? true,
    );
  }
}
