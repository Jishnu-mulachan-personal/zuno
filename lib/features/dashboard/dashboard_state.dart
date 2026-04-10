import 'dart:async';
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
  final String? avatarUrl;
  final String? relationshipId;
  final String? usPhotoUrl;
  final String? partnerId;
  final String? partnerName;
  final String? partnerAvatarUrl;
  final int streakDays;
  final DateTime? lastLoginAt;
  final String? gender;
  final CycleData? cycleData;
  final String preferredLanguage;
  final String relationshipStatus;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.relationshipId,
    this.usPhotoUrl,
    this.partnerId,
    this.partnerName,
    this.partnerAvatarUrl,
    this.streakDays = 0,
    this.lastLoginAt,
    this.gender,
    this.cycleData,
    this.preferredLanguage = 'English',
    this.relationshipStatus = 'single',
    this.privacyPreference = 'balanced',
    this.journalNotePrivate = false,
    this.shareJournalWithPartner = false,
    this.goals = const [],
  });
  
  final String privacyPreference;
  final bool journalNotePrivate;
  final bool shareJournalWithPartner;
  final List<String> goals;
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
    // Fetch current user + their relationship + settings
    final userRow = await supabase
        .from('users')
        .select('*, user_settings(preferred_language, privacy_preference, journal_note_private, share_journal_with_partner, goals), current_relationship:relationships!users_relationship_id_fkey(status, us_photo_url)')
        .eq('id', sbUser.id)
        .maybeSingle();

    if (userRow == null) {
      debugPrint(
          '[userProfileProvider] userRow is NULL (User not found in DB)');
      return const UserProfile(id: '', displayName: 'Friend');
    }

    debugPrint('[userProfileProvider] userRow found: $userRow');

    final displayName = (userRow['display_name'] as String?) ?? 'Friend';
    final avatarUrl = userRow['avatar_url'] as String?;
    final relationshipId = userRow['relationship_id'];
    final gender = userRow['gender'] as String?;
    final userId = userRow['id'];
    final userSettings = userRow['user_settings'] as Map<String, dynamic>?;
    final preferredLanguage = userSettings?['preferred_language'] as String? ?? 'English';
    final privacyPreference = userSettings?['privacy_preference'] as String? ?? 'balanced';
    final journalNotePrivate = userSettings?['journal_note_private'] as bool? ?? false;
    final shareJournalWithPartner = userSettings?['share_journal_with_partner'] as bool? ?? false;
    final goals = List<String>.from(userSettings?['goals'] ?? []);
    
    // Relationship status from joined table (using the alias)
    final relationshipData = userRow['current_relationship'] as Map<String, dynamic>?;
    final relationshipStatus = relationshipData?['status'] as String? ?? 'single';
    final usPhotoUrl = relationshipData?['us_photo_url'] as String?;
    
    // Streak data from Users table
    int streakDays = (userRow['streak_count'] as int?) ?? 0;
    final lastLoginAtStr = userRow['last_login_at'] as String?;
    DateTime? lastLoginAt = lastLoginAtStr != null ? DateTime.parse(lastLoginAtStr) : null;

    // Daily Reset Logic: If missed "yesterday", reset streak to 0 in DB
    if (lastLoginAt != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastLogDate = DateTime(lastLoginAt.year, lastLoginAt.month, lastLoginAt.day);
      final daysDiff = today.difference(lastLogDate).inDays;

      if (daysDiff > 1) {
        debugPrint('[userProfileProvider] Streak broken ($daysDiff days since last log). Resetting to 0.');
        streakDays = 0;
        await supabase.from('users').update({
          'streak_count': 0,
        }).eq('id', userId);
      }
    }

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

    String? partnerId;
    String? partnerName;
    String? partnerAvatarUrl;

    if (relationshipId != null) {
      debugPrint(
          '[userProfileProvider] Fetching partner for relationship: $relationshipId');
      // Fetch partner (the other person in the relationship)
      final partnerRow = await supabase
          .from('users')
          .select('id, display_name, avatar_url')
          .eq('relationship_id', relationshipId)
          .neq('id', userId)
          .limit(1) // Safety
          .maybeSingle();

      partnerId = partnerRow?['id'] as String?;
      partnerName = partnerRow?['display_name'] as String?;
      partnerAvatarUrl = partnerRow?['avatar_url'] as String?;
      debugPrint('[userProfileProvider] Partner found: $partnerName (ID: $partnerId)');
    }

    debugPrint('[userProfileProvider] Profile fetch complete. Streak: $streakDays');
    return UserProfile(
      id: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      relationshipId: relationshipId,
      usPhotoUrl: usPhotoUrl,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAvatarUrl: partnerAvatarUrl,
      streakDays: streakDays,
      lastLoginAt: lastLoginAt,
      gender: gender,
      cycleData: cycleData,
      preferredLanguage: preferredLanguage,
      relationshipStatus: relationshipStatus,
      privacyPreference: privacyPreference,
      journalNotePrivate: journalNotePrivate,
      shareJournalWithPartner: shareJournalWithPartner,
      goals: goals,
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

final partnerMoodProvider =
    FutureProvider.family<String?, String>((ref, partnerId) async {
  debugPrint('[partnerMoodProvider] Fetching mood for partner $partnerId');
  final supabase = Supabase.instance.client;
  final today = DateTime.now().toIso8601String().split('T')[0];

  try {
    final response = await supabase
        .from('daily_logs')
        .select('mood_emoji')
        .eq('user_id', partnerId)
        .eq('log_date', today)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final emoji = response?['mood_emoji'] as String?;
    debugPrint('[partnerMoodProvider] Found emoji: $emoji');
    return emoji;
  } catch (e) {
    debugPrint('[partnerMoodProvider] Error: $e');
    return null;
  }
});

class HistoryData {
  final List<CycleHistory> history;
  final double averageDays;

  HistoryData({required this.history, required this.averageDays});
}

// ── Paginated Cycle History for Calendar ────────────────────────────────────

class CycleHistoryState {
  final List<DateTime> historicalPeriods;
  final bool isLoading;
  final DateTime? earliestLoaded;

  CycleHistoryState({
    this.historicalPeriods = const [],
    this.isLoading = false,
    this.earliestLoaded,
  });

  CycleHistoryState copyWith({
    List<DateTime>? historicalPeriods,
    bool? isLoading,
    DateTime? earliestLoaded,
  }) {
    return CycleHistoryState(
      historicalPeriods: historicalPeriods ?? this.historicalPeriods,
      isLoading: isLoading ?? this.isLoading,
      earliestLoaded: earliestLoaded ?? this.earliestLoaded,
    );
  }
}

class CycleHistoryNotifier extends StateNotifier<CycleHistoryState> {
  final String userId;
  CycleHistoryNotifier(this.userId) : super(CycleHistoryState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true);
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('cycle_periods')
          .select('start_date')
          .eq('user_id', userId)
          .order('start_date', ascending: false)
          .limit(10); // Start with ~10 months

      final dates =
          (rows as List).map((r) => DateTime.parse(r['start_date'])).toList();
      state = state.copyWith(
        historicalPeriods: dates,
        isLoading: false,
        earliestLoaded: dates.isEmpty ? null : dates.last,
      );
    } catch (e) {
      debugPrint('[CycleHistoryNotifier] loadInitial error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.earliestLoaded == null) return;

    debugPrint(
        '[CycleHistoryNotifier] Loading more before ${state.earliestLoaded}');
    state = state.copyWith(isLoading: true);
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('cycle_periods')
          .select('start_date')
          .eq('user_id', userId)
          .lt('start_date',
              state.earliestLoaded!.toIso8601String().split('T')[0])
          .order('start_date', ascending: false)
          .limit(6);

      final dates =
          (rows as List).map((r) => DateTime.parse(r['start_date'])).toList();
      if (dates.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(
        historicalPeriods: [...state.historicalPeriods, ...dates],
        isLoading: false,
        earliestLoaded: dates.last,
      );
    } catch (e) {
      debugPrint('[CycleHistoryNotifier] loadMore error: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

final cycleHistoryNotifierProvider = StateNotifierProvider.family<
    CycleHistoryNotifier, CycleHistoryState, String>((ref, userId) {
  return CycleHistoryNotifier(userId);
});

// ── Graph History Provider ──────────────────────────────────────────────────

final cycleHistoryProvider = FutureProvider<HistoryData>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    debugPrint('[cycleHistoryProvider] No user found in Supabase Auth');
    return HistoryData(history: [], averageDays: 0);
  }

  try {
    debugPrint(
        '[cycleHistoryProvider] Querying cycle_periods for userId: ${user.id}');
    final rows = await supabase
        .from('cycle_periods')
        .select('start_date')
        .eq('user_id', user.id)
        .order('start_date', ascending: true);

    debugPrint(
        '[cycleHistoryProvider] Found ${rows.length} records in cycle_periods');

    if (rows.isEmpty || rows.length < 2) {
      debugPrint(
          '[cycleHistoryProvider] Not enough records for history (need at least 2)');
      return HistoryData(history: [], averageDays: 0);
    }

    final List<CycleHistory> history = [];
    double totalDays = 0;

    for (int i = 0; i < rows.length - 1; i++) {
      final startStr = rows[i]['start_date'];
      final nextStr = rows[i + 1]['start_date'];
      debugPrint(
          '[cycleHistoryProvider] Processing interval: $startStr to $nextStr');

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
    debugPrint(
        '[cycleHistoryProvider] Successfully processed ${history.length} cycles. Avg: $avg');

    return HistoryData(
      history: history,
      averageDays: avg,
    );
  } catch (e) {
    debugPrint('[cycleHistoryProvider] ERROR: $e');
    if (e is PostgrestException) {
      debugPrint(
          '[cycleHistoryProvider] PostgrestException DETAILS: ${e.message}, ${e.details}, ${e.hint}');
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
  final bool shareWithPartner;
  final String? cycleInsight;
  final bool isLoadingCycleInsight;

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
    this.shareWithPartner = false,
    this.cycleInsight,
    this.isLoadingCycleInsight = false,
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
    bool? shareWithPartner,
    String? cycleInsight,
    bool? isLoadingCycleInsight,
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
      shareWithPartner: shareWithPartner ?? this.shareWithPartner,
      cycleInsight: cycleInsight ?? this.cycleInsight,
      isLoadingCycleInsight:
          isLoadingCycleInsight ?? this.isLoadingCycleInsight,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref ref;

  DashboardNotifier(this.ref) : super(const DashboardState()) {
    _init();
  }

  void _init() {
    fetchDailyInsight();

    // Watch profile changes and trigger cycle insight when ready
    ref.listen<AsyncValue<UserProfile>>(userProfileProvider, (prev, next) {
      final profile = next.value;
      debugPrint(
          '[DashboardNotifier] profile listener: gender=${profile?.gender}, hasCycleData=${profile?.cycleData != null}');
      if (profile?.gender == 'Female' && profile?.cycleData != null) {
        fetchCycleInsight();
      }
      if (profile != null) {
        state = state.copyWith(shareWithPartner: profile.shareJournalWithPartner);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchDailyInsight({bool force = false}) async {
    if (!force && state.dailyInsight != null) return;

    final sbUser = Supabase.instance.client.auth.currentUser;
    final identifier = sbUser?.email;
    if (identifier == null) return;

    state = state.copyWith(isLoadingInsight: true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate_daily_insight',
        body: {
          'identifier': identifier,
          'force': force,
        },
      );
      final insight = response.data['insight'] as String?;
      state = state.copyWith(isLoadingInsight: false, dailyInsight: insight);
    } catch (e) {
      debugPrint('[fetchDailyInsight] Error: $e');
      state = state.copyWith(isLoadingInsight: false);
    }
  }

  Future<void> fetchCycleInsight({bool force = false}) async {
    if (!force && state.cycleInsight != null) return;

    final sbUser = Supabase.instance.client.auth.currentUser;
    debugPrint('[fetchCycleInsight] start for ${sbUser?.id}');
    if (sbUser == null) return;

    state = state.copyWith(isLoadingCycleInsight: true);
    try {
      debugPrint('[fetchCycleInsight] invoking edge function...');
      final response = await Supabase.instance.client.functions.invoke(
        'generate_cycle_insight',
        body: {
          'userId': sbUser.id,
          'force': force,
        },
      );
      final insight = response.data['insight'] as String?;
      debugPrint('[fetchCycleInsight] Result: $insight');
      state =
          state.copyWith(isLoadingCycleInsight: false, cycleInsight: insight);
    } catch (e) {
      debugPrint('[fetchCycleInsight] Error: $e');
      state = state.copyWith(isLoadingCycleInsight: false);
    }
  }

  Future<void> refreshInsights() async {
    // Clear and set loading so UI reflects it immediately
    state = state.copyWith(
      dailyInsight: null,
      cycleInsight: null,
      isLoadingInsight: true,
      isLoadingCycleInsight: true,
    );

    // Call both concurrently to speed up refresh
    await Future.wait([
      fetchDailyInsight(force: true),
      fetchCycleInsight(force: true),
    ]);
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
  
  void toggleShareWithPartner(bool val) => state = state.copyWith(shareWithPartner: val);

  Future<bool> saveLog() async {
    final sbUser = Supabase.instance.client.auth.currentUser;
    final identifier = sbUser?.email;

    if (identifier == null || (state.selectedMood == null && state.journalNote.trim().isEmpty)) {
      return false;
    }

    state = state.copyWith(isSaving: true);

    final userId = sbUser!.id;

    state = state.copyWith(isSaving: true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Insert a new log entry
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final profile = ref.read(userProfileProvider).value;
      final isNotePrivate = profile?.journalNotePrivate ?? false;

      await supabase.from('daily_logs').insert({
        'user_id': userId,
        'mood_emoji': state.selectedMood,
        'connection_felt': state.isConnected,
        'context_tags': state.selectedTags,
        'log_date': todayStr,
        'is_note_private': isNotePrivate,
        'share_with_partner': state.shareWithPartner,
        if (state.journalNote.trim().isNotEmpty)
          'journal_note': EncryptionService.encrypt(state.journalNote.trim()),
      });

      // 2. Update Streak Logic
      if (profile != null) {
        int newStreak = profile.streakDays;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        DateTime? lastLog;
        if (profile.lastLoginAt != null) {
          lastLog = DateTime(profile.lastLoginAt!.year, profile.lastLoginAt!.month, profile.lastLoginAt!.day);
        }

        if (lastLog == null) {
          newStreak = 1;
        } else if (lastLog.isBefore(today)) {
          final diff = today.difference(lastLog).inDays;
          if (diff == 1) {
            newStreak += 1;
          } else {
            newStreak = 1;
          }
        }
        // If lastLog == today, streak remains the same

        await supabase.from('users').update({
          'streak_count': newStreak,
          'last_login_at': now.toIso8601String(),
        }).eq('id', userId);
      }

      // 3. Trigger partner notification
      supabase.functions.invoke(
        'notify_partner',
        body: {'identifier': identifier},
      ).ignore();

      state = state.copyWith(
        isSaving: false,
        lastSaved: DateTime.now(),
        selectedMood: null,
        journalNote: '',
        selectedTags: const [],
      );
      
      // Invalidate both logs and profile to refresh streak in UI
      ref.invalidate(userLogsProvider);
      ref.invalidate(userProfileProvider);

      fetchDailyInsight(force: true);

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

      // Force regenerate the cycle insight to reflect the newly logged period date
      await fetchCycleInsight(force: true);
    } catch (e) {
      debugPrint('[updateCycleStartDate] Error: $e');
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
