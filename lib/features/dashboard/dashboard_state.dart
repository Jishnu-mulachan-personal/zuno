import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  const DashboardState({
    this.selectedMood,
    this.isConnected = true,
    this.selectedTags = const [],
    this.partnerMood = '😊',
  });

  DashboardState copyWith({
    String? selectedMood,
    bool? isConnected,
    List<String>? selectedTags,
    String? partnerMood,
  }) {
    return DashboardState(
      selectedMood: selectedMood ?? this.selectedMood,
      isConnected: isConnected ?? this.isConnected,
      selectedTags: selectedTags ?? this.selectedTags,
      partnerMood: partnerMood ?? this.partnerMood,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  void setMood(String mood) => state = state.copyWith(selectedMood: mood);

  void toggleConnection(bool connected) =>
      state = state.copyWith(isConnected: connected);

  void toggleTag(String tag) {
    final tags = List<String>.from(state.selectedTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(selectedTags: tags);
  }

  Future<void> saveLog() async {
    final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null || state.selectedMood == null) return;

    final supabase = Supabase.instance.client;

    // Fetch the user row
    final userRow = await supabase
        .from('users')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();

    if (userRow == null) return;

    final userId = userRow['id'];

    // Upsert a daily log entry for today
    await supabase.from('daily_logs').upsert({
      'user_id': userId,
      'mood_emoji': state.selectedMood,
      'connection_felt': state.isConnected,
      'context_tags': state.selectedTags,
      'log_date': DateTime.now().toIso8601String().split('T')[0],
    }, onConflict: 'user_id,log_date');
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
