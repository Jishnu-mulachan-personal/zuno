import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../dashboard/dashboard_state.dart';

// ── Settings actions state ────────────────────────────────────────────────────

enum SettingsActionStatus { idle, loading, success, error }

class SettingsState {
  final SettingsActionStatus status;
  final String? message;

  const SettingsState({
    this.status = SettingsActionStatus.idle,
    this.message,
  });
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  SettingsNotifier(this._ref) : super(const SettingsState());

  void _setLoading() =>
      state = const SettingsState(status: SettingsActionStatus.loading);

  void _setError(String msg) =>
      state = SettingsState(status: SettingsActionStatus.error, message: msg);

  void _setSuccess(String msg) =>
      state = SettingsState(status: SettingsActionStatus.success, message: msg);

  // ── Unpair Partner ──────────────────────────────────────────────────────────

  /// Clears partner_b_id from the relationships row and clears the claimer's
  /// (i.e., the user who was NOT the creator) relationship_id from users.
  /// User A keeps the relationship row (for their history), but it becomes
  /// unpaired — partner_b_id = NULL.
  Future<bool> unpairPartner() async {
    final sbUser = Supabase.instance.client.auth.currentUser;

    if (sbUser == null) {
      _setError('Not authenticated');
      return false;
    }

    _setLoading();

    try {
      final supabase = Supabase.instance.client;

      // Pass the Auth ID to the Edge Function — it should handle it as a direct UUID identifier
      final response = await supabase.functions.invoke(
        'unpair_partner',
        body: {'userId': sbUser.id},
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Unpair failed';
        _setError(errorMsg);
        return false;
      }

      // Invalidate & force a fresh re-fetch so UI reflects the change
      _ref.invalidate(userProfileProvider);
      _setSuccess('Partner unpaired');
      return true;
    } catch (e) {
      debugPrint('[unpairPartner] $e');
      _setError(e.toString());
      return false;
    }
  }

  // ── Delete Account ──────────────────────────────────────────────────────────

  /// Deletes the Supabase user row (cascades to daily_logs, etc.) then signs
  /// out from Supabase.
  Future<bool> deleteAccount() async {
    final sbUser = Supabase.instance.client.auth.currentUser;

    if (sbUser == null) {
      _setError('Not authenticated');
      return false;
    }

    _setLoading();

    try {
      final supabase = Supabase.instance.client;
      final userId = sbUser.id;

      // 1. Check if profile exists
      final userRow = await supabase
          .from('users')
          .select('id, relationship_id')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) {
        // Already gone — just sign out
        _setSuccess('Account deleted');
        return true;
      }

      // 2. Clear user from ANY relationship they might be part of
      // (This is more robust than just relying on userRow['relationship_id'])
      final activeRels = await supabase
          .from('relationships')
          .select('id, partner_a_id, partner_b_id')
          .or('partner_a_id.eq.$userId,partner_b_id.eq.$userId');

      for (final rel in activeRels) {
        final relId = rel['id'] as String;
        final partnerAId = rel['partner_a_id'] as String?;
        final partnerBId = rel['partner_b_id'] as String?;

        if (partnerAId == userId) {
          // Current user is A — clear their reference and nullify partner_b
          await supabase
              .from('relationships')
              .update({'partner_a_id': null, 'partner_b_id': null})
              .eq('id', relId);

          if (partnerBId != null) {
            await supabase
                .from('users')
                .update({'relationship_id': null}).eq('id', partnerBId);
          }
        } else if (partnerBId == userId) {
          // Current user is B — just clear partner_b_id
          await supabase
              .from('relationships')
              .update({'partner_b_id': null}).eq('id', relId);

          if (partnerAId != null) {
            await supabase
                .from('users')
                .update({'relationship_id': null}).eq('id', partnerAId);
          }
        }
      }

      // 3. Delete the user row (ON DELETE CASCADE handles daily_logs, etc.)
      await supabase.from('users').delete().eq('id', userId);

      // 4. Sign out completely
      await supabase.auth.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      _setSuccess('Account deleted');
      return true;
    } catch (e) {
      debugPrint('[deleteAccount] $e');
      _setError(e.toString());
      return false;
    }
  }

  void reset() => state = const SettingsState();

  // ── Update Language ─────────────────────────────────────────────────────────

  Future<bool> updateLanguage(String lang) async {
    final sbUser = Supabase.instance.client.auth.currentUser;
    if (sbUser == null) return false;

    _setLoading();
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('user_settings').upsert({
        'user_id': sbUser.id,
        'preferred_language': lang,
      });

      _ref.invalidate(userProfileProvider);
      // Wait a tiny bit for the invalidation to propagate if needed, 
      // but calling refreshInsights immediately should be fine too.
      _ref.read(dashboardProvider.notifier).refreshInsights();
      
      _setSuccess('Language updated to $lang');
      return true;
    } catch (e) {
      debugPrint('[updateLanguage] $e');
      _setError(e.toString());
      return false;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
