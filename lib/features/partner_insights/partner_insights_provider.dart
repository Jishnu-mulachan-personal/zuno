import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_state.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class PartnerInsightsData {
  final int cycleDay;
  final String phase;
  final bool pmsAlert;
  final int? daysUntilPeriod;
  final String summary;
  final List<String> actionItems;
  final List<String> avoidItems;
  final bool moodLogged;
  final String? lastMoodEmoji;

  const PartnerInsightsData({
    required this.cycleDay,
    required this.phase,
    required this.pmsAlert,
    this.daysUntilPeriod,
    required this.summary,
    required this.actionItems,
    required this.avoidItems,
    required this.moodLogged,
    this.lastMoodEmoji,
  });

  factory PartnerInsightsData.fromMap(Map<String, dynamic> map) {
    List<String> toStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return PartnerInsightsData(
      cycleDay:        (map['cycle_day'] as num?)?.toInt()       ?? 0,
      phase:           (map['phase']     as String?)             ?? 'None',
      pmsAlert:        (map['pms_alert'] as bool?)               ?? false,
      daysUntilPeriod: (map['days_until_period'] as num?)?.toInt(),
      summary:         (map['summary']   as String?)             ?? '',
      actionItems:     toStringList(map['action_items']),
      avoidItems:      toStringList(map['avoid_items']),
      moodLogged:      (map['mood_logged'] as bool?)             ?? true,
      lastMoodEmoji:   map['last_mood_emoji'] as String?,
    );
  }

  /// Human-friendly phase label
  String get phaseLabel {
    switch (phase) {
      case 'Menstruation': return 'Menstrual';
      case 'Follicular':   return 'Follicular';
      case 'Ovulation':    return 'Ovulatory';
      case 'Luteal':       return 'Luteal';
      case 'Delayed':      return 'Delayed';
      case 'None':         return 'None';
      default:             return phase;
    }
  }

  /// Index 0–3 for the 4-phase navigator (Delayed uses Luteal position = 3)
  int get phaseIndex {
    switch (phase) {
      case 'Menstruation': return 0;
      case 'Follicular':   return 1;
      case 'Ovulation':    return 2;
      case 'Luteal':       return 3;
      case 'Delayed':      return 3;
      default:             return 0;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final partnerInsightsProvider =
    FutureProvider<PartnerInsightsData?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);

  // Requirement: Relationship must exist
  if (profile.relationshipId == null) return null;

  debugPrint('[partnerInsightsProvider] Fetching for relationship: ${profile.relationshipId}');

  try {
    final response = await Supabase.instance.client.functions.invoke(
      'generate_partner_insights',
      body: {
        'relationship_id': profile.relationshipId,
        'force':           false,
      },
    );

    final data = response.data;
    if (data == null || data['insight'] == null) return null;

    final insight = data['insight'] as Map<String, dynamic>;
    return PartnerInsightsData.fromMap(insight);
  } catch (e) {
    debugPrint('[partnerInsightsProvider] Error: $e');
    return null;
  }
});

/// Quick bool provider: is there an active PMS alert for the male partner's dashboard badge?
final partnerPmsAlertProvider = FutureProvider<bool>((ref) async {
  final insights = await ref.watch(partnerInsightsProvider.future);
  return insights?.pmsAlert ?? false;
});

// ── Refresh helper ────────────────────────────────────────────────────────────

Future<void> refreshPartnerInsights(WidgetRef ref) async {
  final profile = await ref.read(userProfileProvider.future);
  if (profile.relationshipId == null) return;

  try {
    await Supabase.instance.client.functions.invoke(
      'generate_partner_insights',
      body: {
        'relationship_id': profile.relationshipId,
        'force':           true,
      },
    );
    ref.invalidate(partnerInsightsProvider);
  } catch (e) {
    debugPrint('[refreshPartnerInsights] Error: $e');
    rethrow;
  }
}

// ── Partner observation submission ───────────────────────────────────────────

Future<void> submitPartnerObservation({
  required WidgetRef ref,
  required String emoji,
}) async {
  final profile = await ref.read(userProfileProvider.future);
  if (profile.id.isEmpty || profile.relationshipId == null) return;

  final today = DateTime.now().toIso8601String().split('T')[0];
  await Supabase.instance.client.from('partner_observations').upsert({
    'observer_id':     profile.id,
    'relationship_id': profile.relationshipId,
    'observed_emoji':  emoji,
    'observed_on':     today,
  }, onConflict: 'observer_id, observed_on');

  debugPrint('[submitPartnerObservation] Submitted $emoji for ${profile.relationshipId}');
}
