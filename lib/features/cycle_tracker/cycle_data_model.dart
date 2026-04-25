

class CycleData {
  final String id;
  final String userId;
  final DateTime lastPeriodDate;
  final int cycleLength;
  final int periodDuration;
  final bool isTracking;
  final List<DateTime> historicalPeriods;

  CycleData({
    required this.id,
    required this.userId,
    required this.lastPeriodDate,
    required this.cycleLength,
    required this.periodDuration,
    required this.isTracking,
    this.historicalPeriods = const [],
  });

  /// The day of the current cycle (days since last period)
  int get currentCycleDay {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final lastMidnight = currentCycleStart;

    final diff = todayMidnight.difference(lastMidnight).inDays;
    
    return diff >= 0 ? diff + 1 : 1;
  }

  /// Calculates the start date of the current cycle interval (last actual period)
  DateTime get currentCycleStart {
    return DateTime(lastPeriodDate.year, lastPeriodDate.month, lastPeriodDate.day);
  }



  /// Next predicted period
  DateTime get nextPeriodDate {
    return currentCycleStart.add(Duration(days: cycleLength));
  }

  /// Predicted ovulation date
  DateTime get ovulationDate {
    return nextPeriodDate.subtract(const Duration(days: 14));
  }

  /// Whether the period is currently delayed
  bool get isPeriodDelayed {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final npMidnight =
        DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day);
    return todayMidnight.isAfter(npMidnight) &&
        currentPhase != 'Menstruation';
  }

  /// Whether the period is predicted to start soon (within 2 days)
  bool get isUpcomingPeriod {
    if (currentPhase == 'Menstruation') return false;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final npMidnight =
        DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day);
    final diff = npMidnight.difference(todayMidnight).inDays;
    return diff >= 0 && diff <= 2;
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
      case 'Delayed':
        final diff = DateTime.now().difference(nextPeriodDate).inDays;
        if (diff > 0) return 'Cycle delayed by $diff ${diff == 1 ? 'day' : 'days'}.';
        return 'Your cycle might be delayed.';
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

    if (diff < 0) {
      for (final start in historicalPeriods) {
        final s = DateTime(start.year, start.month, start.day);
        final diffH = t.difference(s).inDays;
        if (diffH >= 0 && diffH < periodDuration) return 'period';
      }
      return 'normal';
    }

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final nextPMidnight =
        DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day);

    // If within the active logged cycle (diff < cycleLength)
    if (diff < cycleLength) {
      final dayOfCycle = diff + 1;
      final ovForTarget = nextPMidnight.subtract(const Duration(days: 14));
      final fwStart = ovForTarget.subtract(const Duration(days: 5));
      final fwEnd = ovForTarget.add(const Duration(days: 1));
      final maybeFwStart = fwStart.subtract(const Duration(days: 2));
      final maybeFwEnd = fwEnd.add(const Duration(days: 1));

      if (dayOfCycle <= periodDuration) return 'period';
      if (!t.isBefore(fwStart) && !t.isAfter(fwEnd)) return 'fertile';
      if (!t.isBefore(maybeFwStart) && !t.isAfter(maybeFwEnd)) return 'maybe_fertile';
      return 'normal';
    }

    // Past the expected next period start
    final diffToday = todayMidnight.difference(nextPMidnight).inDays;
    
    if (diffToday >= 0) {
      if (t.isAtSameMomentAs(nextPMidnight)) {
         return 'next_period'; // The projected exact first day
      }
      
      if (t.isAfter(nextPMidnight) && !t.isAfter(todayMidnight)) {
         return 'delayed'; // Days elapsed while period hasn't arrived
      }
      
      // If t is in the future, don't show fake predictions if currently delayed
      return 'normal';
    }

    // If we are NOT delayed (today is before nextPMidnight), but t is in the future
    final dayOfCycle = (diff % cycleLength) + 1;
    if (dayOfCycle == 1) return 'next_period';
    
    final cycleStartForTarget = t.subtract(Duration(days: dayOfCycle - 1));
    final nextPForTarget = cycleStartForTarget.add(Duration(days: cycleLength));
    final ovForTarget = nextPForTarget.subtract(const Duration(days: 14));
    final fwStart = ovForTarget.subtract(const Duration(days: 5));
    final fwEnd = ovForTarget.add(const Duration(days: 1));
    final maybeFwStart = fwStart.subtract(const Duration(days: 2));
    final maybeFwEnd = fwEnd.add(const Duration(days: 1));

    if (dayOfCycle <= periodDuration) return 'period';
    if (!t.isBefore(fwStart) && !t.isAfter(fwEnd)) return 'fertile';
    if (!t.isBefore(maybeFwStart) && !t.isAfter(maybeFwEnd)) return 'maybe_fertile';

    return 'normal';
  }

  /// Get the string representation of day progress, e.g., 'Day 5 / 28'
  String getDayProgress(DateTime target) {
    final t = DateTime(target.year, target.month, target.day);
    final lastMidnight = currentCycleStart;
    final diff = t.difference(lastMidnight).inDays;

    if (diff < 0) return '';

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final nextPMidnight =
        DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day);

    if (diff < cycleLength) {
      return 'Day ${diff + 1} / $cycleLength';
    }

    if (todayMidnight.isAfter(nextPMidnight) || todayMidnight.isAtSameMomentAs(nextPMidnight)) {
      if ((t.isAfter(nextPMidnight) || t.isAtSameMomentAs(nextPMidnight)) && 
          (t.isBefore(todayMidnight) || t.isAtSameMomentAs(todayMidnight))) {
        return 'Day ${diff + 1} / $cycleLength';
      }
      if (t.isAfter(todayMidnight)) {
        return ''; 
      }
    }

    final dayOfCycle = (diff % cycleLength) + 1;
    return 'Day $dayOfCycle / $cycleLength';
  }

  /// Whether to show the confirmation card (1 day before, day of, or up to 5 days late)
  bool get shouldShowConfirmationCard {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final nextPMidnight =
        DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day);

    final diff = todayMidnight.difference(nextPMidnight).inDays;

    return diff >= -1 && diff <= 5;
  }

  /// User-friendly text for the confirmation card
  String get confirmationCardTitle {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final nextPMidnight =
        DateTime(nextPeriodDate.year, nextPeriodDate.month, nextPeriodDate.day);

    final diff = todayMidnight.difference(nextPMidnight).inDays;

    if (diff == -1) return "Expected period starts tomorrow";
    if (diff == 0) return "Expected period starts today";
    if (diff > 0) {
      return "Your cycle is delayed by $diff ${diff == 1 ? 'day' : 'days'}";
    }
    return "Is your period late?";
  }

  factory CycleData.fromMap(Map<String, dynamic> map) {
    return CycleData(
      id: map['id'],
      userId: map['user_id'],
      lastPeriodDate: DateTime.parse(map['last_period_date']),
      cycleLength: map['cycle_length'] ?? 28,
      periodDuration: map['period_duration'] ?? 5,
      isTracking: map['is_tracking'] ?? true,
      historicalPeriods: const [],
    );
  }

  CycleData copyWith({
    List<DateTime>? historicalPeriods,
  }) {
    return CycleData(
      id: id,
      userId: userId,
      lastPeriodDate: lastPeriodDate,
      cycleLength: cycleLength,
      periodDuration: periodDuration,
      isTracking: isTracking,
      historicalPeriods: historicalPeriods ?? this.historicalPeriods,
    );
  }
}

class CycleHistory {
  final DateTime startDate;
  final int durationDays;
  final String monthLabel;

  CycleHistory({
    required this.startDate,
    required this.durationDays,
    required this.monthLabel,
  });
}
