import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_state.dart';

class MoodTrendPoint {
  final DateTime date;
  final double value;
  final String emoji;

  MoodTrendPoint({required this.date, required this.value, required this.emoji});
}

class WeeklyInsight {
  final String id;
  final String relationshipId;
  final String pattern;
  final String alignment;
  final Map<String, dynamic>? alignmentData;
  final String theme;
  final List<dynamic>? patternData;
  final DateTime createdAt;

  WeeklyInsight({
    required this.id,
    required this.relationshipId,
    required this.pattern,
    this.alignmentData,
    required this.alignment,
    required this.theme,
    this.patternData,
    required this.createdAt,
  });

  factory WeeklyInsight.fromMap(Map<String, dynamic> map) {
    return WeeklyInsight(
      id: map['id'],
      relationshipId: map['relationship_id'],
      pattern: map['pattern_text'],
      patternData: map['pattern_data'] as List<dynamic>?,
      alignment: map['alignment_text'],
      alignmentData: map['alignment_data'] as Map<String, dynamic>?,
      theme: map['theme_text'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

final weeklyInsightProvider = FutureProvider<WeeklyInsight?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  // Get relationship_id from the user's profile
  final profile = await ref.watch(userProfileProvider.future);
  final relId = profile.relationshipId;
  if (relId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('weekly_insights')
        .select('*')
        .eq('relationship_id', relId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return WeeklyInsight.fromMap(response);
  } catch (e) {
    return null;
  }
});

final moodTrendProvider = FutureProvider<List<MoodTrendPoint>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  return _fetchMoodTrendData(user.id);
});

final partnerMoodTrendProvider = FutureProvider.family<List<MoodTrendPoint>, String>((ref, partnerId) async {
  return _fetchMoodTrendData(partnerId);
});

Future<List<MoodTrendPoint>> _fetchMoodTrendData(String userId) async {
  final supabase = Supabase.instance.client;
  final today = DateTime.now();
  final sevenDaysAgo = today.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];

  try {
    final response = await supabase
        .from('daily_logs')
        .select('mood_emoji, log_date')
        .eq('user_id', userId)
        .gte('log_date', sevenDaysAgo)
        .order('log_date', ascending: true);

    final List<dynamic> rows = response as List<dynamic>;

    // Group by date and take the average value if multiple logs exist for one day
    final Map<String, List<double>> groupedValues = {};
    final Map<String, String> latestEmoji = {};

    for (final row in rows) {
      final dateStr = row['log_date'] as String;
      final emoji = row['mood_emoji'] as String?;
      if (emoji == null) continue;

      final val = _mapMoodToValue(emoji);
      groupedValues.putIfAbsent(dateStr, () => []).add(val);
      latestEmoji[dateStr] = emoji; 
    }

    // Generate the last 7 days list to ensure we have placeholders for missing days
    final List<MoodTrendPoint> points = [];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final ds = d.toIso8601String().split('T')[0];

      if (groupedValues.containsKey(ds)) {
        final vals = groupedValues[ds]!;
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        points.add(MoodTrendPoint(date: d, value: avg, emoji: latestEmoji[ds]!));
      }
    }

    return points;
  } catch (e) {
    return [];
  }
}

double _mapMoodToValue(String emoji) {
  switch (emoji) {
    case '✨': return 5.0; // Amazing
    case '😊': return 4.0; // Happy
    case '😌': return 3.0; // Calm
    case '😕': return 2.0; // Meh
    case '😔': return 1.0; // Sad
    case '😤': return 1.0; // Frustrated
    case '😡': return 0.5; // Angry
    default: return 3.0;
  }
}

