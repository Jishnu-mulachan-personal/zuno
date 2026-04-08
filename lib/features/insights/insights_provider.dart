import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoodTrendPoint {
  final DateTime date;
  final double value;
  final String emoji;

  MoodTrendPoint({required this.date, required this.value, required this.emoji});
}

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

