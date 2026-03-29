import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/encryption_service.dart';
import '../pairing/you_state.dart';

// ── User profile data loaded from Supabase ─────────────────────────────────

class UserProfile {
  final String displayName;
  final String? partnerName;
  final int streakDays;

  const UserProfile({
    required this.displayName,
    this.partnerName,
    this.streakDays = 0,
  });
}

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
  if (phone == null) {
    return const UserProfile(displayName: 'Friend');
  }

  final supabase = Supabase.instance.client;

  // Fetch current user + their relationship
  final userRow = await supabase
      .from('users')
      .select('id, display_name, relationship_id')
      .eq('phone', phone)
      .maybeSingle();

  if (userRow == null) return const UserProfile(displayName: 'Friend');

  final displayName = (userRow['display_name'] as String?) ?? 'Friend';
  final relationshipId = userRow['relationship_id'];

  String? partnerName;
  int streakDays = 0;

  if (relationshipId != null) {
    final userId = userRow['id'];

    // Fetch partner (the other person in the relationship)
    final partnerRow = await supabase
        .from('users')
        .select('display_name')
        .eq('relationship_id', relationshipId)
        .neq('id', userId)
        .maybeSingle();

    partnerName = partnerRow?['display_name'] as String?;

    // Streak: count consecutive days with a daily_logs entry
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

  return UserProfile(
    displayName: displayName,
    partnerName: partnerName,
    streakDays: streakDays,
  );
});

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

    final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null) return;

    state = state.copyWith(isLoadingInsight: true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate_daily_insight',
        body: {
          'phone': phone,
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
    final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null || state.selectedMood == null) return false;

    state = state.copyWith(isSaving: true);

    try {
      final supabase = Supabase.instance.client;

      final userRow = await supabase
          .from('users')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();

      if (userRow == null) {
        state = state.copyWith(isSaving: false);
        return false;
      }

      final userId = userRow['id'];

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
        body: {'phone': phone},
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
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
