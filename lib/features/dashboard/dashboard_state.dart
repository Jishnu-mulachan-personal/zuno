import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/encryption_service.dart';
import '../pairing/you_state.dart';
import '../cycle_tracker/cycle_data_model.dart';

// ── User profile data loaded from Supabase ─────────────────────────────────

class UserProfile {
  final String id;
  final String displayName;
  final String? partnerName;
  final int streakDays;
  final String? gender;
  final CycleData? cycleData;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.partnerName,
    this.streakDays = 0,
    this.gender,
    this.cycleData,
  });
}

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  debugPrint('[userProfileProvider] Start fetching profile...');
  final sbUser = Supabase.instance.client.auth.currentUser;

  debugPrint(
      '[userProfileProvider] sbUser: ${sbUser?.id}, email: ${sbUser?.email}');

  final identifier = sbUser?.email;
  debugPrint('[userProfileProvider] Resolved identifier: $identifier');

  if (identifier == null) {
    debugPrint('[userProfileProvider] No identifier found, returning default');
    return const UserProfile(id: '', displayName: 'Friend');
  }

  final supabase = Supabase.instance.client;

  try {
    debugPrint(
        '[userProfileProvider] Querying users table by id = ${sbUser!.id}');
    // Fetch current user + their relationship
    final userRow = await supabase
        .from('users')
        .select('id, display_name, relationship_id, gender')
        .eq('id', sbUser.id)
        .maybeSingle();

    if (userRow == null) {
      debugPrint(
          '[userProfileProvider] userRow is NULL (User not found in DB)');
      return const UserProfile(id: '', displayName: 'Friend');
    }

    debugPrint('[userProfileProvider] userRow found: $userRow');

    final displayName = (userRow['display_name'] as String?) ?? 'Friend';
    final relationshipId = userRow['relationship_id'];
    final gender = userRow['gender'] as String?;
    final userId = userRow['id'];

    CycleData? cycleData;
    if (gender == 'Female') {
      debugPrint(
          '[userProfileProvider] Fetching cycle data for userId: $userId');
      final cycleRow = await supabase
          .from('cycle_data')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (cycleRow != null) {
        cycleData = CycleData.fromMap(cycleRow);
        debugPrint(
            '[userProfileProvider] Cycle data found: ${cycleData.currentCycleDay}');
      } else {
        debugPrint('[userProfileProvider] No cycle data row found');
      }
    }

    String? partnerName;
    int streakDays = 0;

    if (relationshipId != null) {
      debugPrint(
          '[userProfileProvider] Fetching partner for relationship: $relationshipId');
      // Fetch partner (the other person in the relationship)
      final partnerRow = await supabase
          .from('users')
          .select('display_name')
          .eq('relationship_id', relationshipId)
          .neq('id', userId)
          .limit(1) // Safety
          .maybeSingle();

      partnerName = partnerRow?['display_name'] as String?;
      debugPrint('[userProfileProvider] Partner found: $partnerName');

      // Streak calculation...
      final logs = await supabase
          .from('daily_logs')
          .select('log_date')
          .eq('user_id', userId)
          .order('log_date', ascending: false)
          .limit(60);

      if (logs is List && logs.isNotEmpty) {
        final today = DateTime.now();
        var streak = 0;
        for (var i = 0; i < logs.length; i++) {
          final dt = DateTime.parse(logs[i]['log_date'] as String);
          final diff = today.difference(dt).inDays;
          if (diff == i) {
            streak++;
          } else {
            break;
          }
        }
        streakDays = streak;
      }
    }

    debugPrint('[userProfileProvider] Profile fetch complete.');
    return UserProfile(
      id: userId,
      displayName: displayName,
      partnerName: partnerName,
      streakDays: streakDays,
      gender: gender,
      cycleData: cycleData,
    );
  } catch (e) {
    debugPrint('[userProfileProvider] ERROR: $e');
    if (e is PostgrestException) {
      debugPrint(
          '[userProfileProvider] PostgrestException DETAILS: ${e.message}, ${e.details}, ${e.hint}');
    }
    // Re-throw so the FutureProvider enters an error state that the UI can handle
    rethrow;
  }
});

class HistoryData {
  final List<CycleHistory> history;
  final double averageDays;

  HistoryData({required this.history, required this.averageDays});
}

final cycleHistoryProvider = FutureProvider<HistoryData>((ref) async {
  debugPrint('[cycleHistoryProvider] Fetching cycle history...');
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) {
    debugPrint('[cycleHistoryProvider] No user found in Supabase Auth');
    return HistoryData(history: [], averageDays: 0);
  }

  try {
    debugPrint('[cycleHistoryProvider] Querying cycle_periods for userId: ${user.id}');
    final rows = await supabase
        .from('cycle_periods')
        .select('start_date')
        .eq('user_id', user.id)
        .order('start_date', ascending: true);

    debugPrint('[cycleHistoryProvider] Found ${rows.length} records in cycle_periods');
    
    if (rows.isEmpty || rows.length < 2) {
      debugPrint('[cycleHistoryProvider] Not enough records for history (need at least 2)');
      return HistoryData(history: [], averageDays: 0);
    }

    final List<CycleHistory> history = [];
    double totalDays = 0;

    for (int i = 0; i < rows.length - 1; i++) {
      final startStr = rows[i]['start_date'];
      final nextStr = rows[i + 1]['start_date'];
      debugPrint('[cycleHistoryProvider] Processing interval: $startStr to $nextStr');
      
      final start = DateTime.parse(startStr);
      final next = DateTime.parse(nextStr);
      final duration = next.difference(start).inDays;

      debugPrint('[cycleHistoryProvider] Calculated duration: $duration days');
      history.add(CycleHistory(
        startDate: start,
        durationDays: duration,
        monthLabel: _getMonthName(start.month),
      ));
      totalDays += duration;
    }

    final avg = totalDays / history.length;
    debugPrint('[cycleHistoryProvider] Successfully processed ${history.length} cycles. Avg: $avg');
    
    return HistoryData(
      history: history,
      averageDays: avg,
    );
  } catch (e) {
    debugPrint('[cycleHistoryProvider] ERROR: $e');
    if (e is PostgrestException) {
      debugPrint('[cycleHistoryProvider] PostgrestException DETAILS: ${e.message}, ${e.details}, ${e.hint}');
    }
    return HistoryData(history: [], averageDays: 0);
  }
});

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

// ── Dashboard interaction state ─────────────────────────────────────────────

class DashboardState {
  final String? selectedMood;
  final bool isConnected;
  final List<String> selectedTags;
  final String partnerMood;
  final bool isSaving;
  final DateTime? lastSaved;
  final String journalNote;
  final String? dailyInsight;
  final bool isLoadingInsight;

  const DashboardState({
    this.selectedMood,
    this.isConnected = true,
    this.selectedTags = const [],
    this.partnerMood = '😊',
    this.isSaving = false,
    this.lastSaved,
    this.journalNote = '',
    this.dailyInsight,
    this.isLoadingInsight = false,
  });

  DashboardState copyWith({
    String? selectedMood,
    bool? isConnected,
    List<String>? selectedTags,
    String? partnerMood,
    bool? isSaving,
    DateTime? lastSaved,
    String? journalNote,
    String? dailyInsight,
    bool? isLoadingInsight,
  }) {
    return DashboardState(
      selectedMood: selectedMood ?? this.selectedMood,
      isConnected: isConnected ?? this.isConnected,
      selectedTags: selectedTags ?? this.selectedTags,
      partnerMood: partnerMood ?? this.partnerMood,
      isSaving: isSaving ?? this.isSaving,
      lastSaved: lastSaved ?? this.lastSaved,
      journalNote: journalNote ?? this.journalNote,
      dailyInsight: dailyInsight ?? this.dailyInsight,
      isLoadingInsight: isLoadingInsight ?? this.isLoadingInsight,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref ref;
  DashboardNotifier(this.ref) : super(const DashboardState()) {
    fetchDailyInsight();
  }

  Future<void> fetchDailyInsight() async {
    if (state.dailyInsight != null) return;

    final sbUser = Supabase.instance.client.auth.currentUser;
    final identifier = sbUser?.email;
    if (identifier == null) return;

    state = state.copyWith(isLoadingInsight: true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate_daily_insight',
        body: {
          'identifier': identifier,
        },
      );
      final insight = response.data['insight'] as String?;
      state = state.copyWith(isLoadingInsight: false, dailyInsight: insight);
    } catch (e) {
      debugPrint('[fetchDailyInsight] Error: $e');
      state = state.copyWith(isLoadingInsight: false);
    }
  }

  void setMood(String mood) => state = state.copyWith(selectedMood: mood);

  void toggleConnection(bool connected) =>
      state = state.copyWith(isConnected: connected);

  void setJournalNote(String note) => state = state.copyWith(journalNote: note);

  void toggleTag(String tag) {
    final tags = List<String>.from(state.selectedTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(selectedTags: tags);
  }

  Future<bool> saveLog() async {
    final sbUser = Supabase.instance.client.auth.currentUser;
    final identifier = sbUser?.email;

    if (identifier == null || state.selectedMood == null) return false;

    state = state.copyWith(isSaving: true);

    final userId = sbUser!.id;

    state = state.copyWith(isSaving: true);

    try {
      final supabase = Supabase.instance.client;

      // Insert a new log entry — multiple check-ins per day are allowed
      await supabase.from('daily_logs').insert({
        'user_id': userId,
        'mood_emoji': state.selectedMood,
        'connection_felt': state.isConnected,
        'context_tags': state.selectedTags,
        'log_date': DateTime.now().toIso8601String().split('T')[0],
        if (state.journalNote.trim().isNotEmpty)
          'journal_note': EncryptionService.encrypt(state.journalNote.trim()),
      });

      // Trigger partner notification via Edge Function
      supabase.functions.invoke(
        'notify_partner',
        body: {'identifier': identifier},
      ).ignore();

      state = state.copyWith(isSaving: false, lastSaved: DateTime.now());
      ref.invalidate(userLogsProvider);
      return true;
    } catch (e) {
      debugPrint('[saveLog] Error: $e');
      state = state.copyWith(isSaving: false);
      return false;
    }
  }

  Future<void> updateCycleStartDate(String userId, DateTime date) async {
    final supabase = Supabase.instance.client;
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      // 1. Update the prediction anchor
      await supabase.from('cycle_data').update({
        'last_period_date': dateStr,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // 2. Log to history table for future graphing
      // Note: UPSERT here handles the case where user changes their mind on the same day
      await supabase.from('cycle_periods').upsert({
        'user_id': userId,
        'start_date': dateStr,
      }, onConflict: 'user_id, start_date');

      // Refresh the profile to update cycle calculations
      ref.invalidate(userProfileProvider);
    } catch (e) {
      debugPrint('[updateCycleStartDate] Error: $e');
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
