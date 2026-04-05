import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/profile_existence_provider.dart';
import '../auth/user_repository.dart';
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
    _setLoading();
    final ok = await _internalUnpair();
    if (ok) {
      _ref.invalidate(userProfileProvider);
      _setSuccess('Partner unpaired');
    }
    return ok;
  }

  Future<bool> _internalUnpair() async {
    final sbUser = Supabase.instance.client.auth.currentUser;
    if (sbUser == null) {
      _setError('Not authenticated');
      return false;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'unpair_partner',
        body: {'userId': sbUser.id},
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Unpair failed';
        _setError(errorMsg);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[_internalUnpair] $e');
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
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) {
        // Already gone — just sign out
        _setSuccess('Account deleted');
        return true;
      }

      // 2. Delete the user row
      // (The DB migration 20260404_fix_delete_cascade.sql handles:
      //  - SET NULL on relationships.partner_a_id/partner_b_id
      //  - SET NULL on users.relationship_id
      //  - CASCADE on daily_logs, cycle_data, etc.)
      await supabase.from('users').delete().eq('id', userId);

      // 3. Clear the profile existence cache
      _ref.read(profileExistenceProvider).setHasProfile(false);

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
      _ref.read(dashboardProvider.notifier).refreshInsights();
      
      _setSuccess('Language updated to $lang');
      return true;
    } catch (e) {
      debugPrint('[updateLanguage] $e');
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updatePrivacyPreference(String level) async {
    _setLoading();
    try {
      final userRepo = _ref.read(userRepositoryProvider);
      await userRepo.updateUserSettings(privacyPreference: level);
      _ref.invalidate(userProfileProvider);
      _setSuccess('Privacy preference updated');
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updateGoals(List<String> goals) async {
    _setLoading();
    try {
      final userRepo = _ref.read(userRepositoryProvider);
      await userRepo.updateUserSettings(goals: goals);
      _ref.invalidate(userProfileProvider);
      _setSuccess('Goals updated');
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updateRelationshipStatus(String status) async {
    final profile = _ref.read(userProfileProvider).value;
    if (profile == null) return false;

    _setLoading();
    try {
      final supabase = Supabase.instance.client;
      final userId = profile.id;
      String? relId = profile.relationshipId;

      // 1. If user doesn't have a relationship_id, create one first
      if (relId == null) {
        debugPrint('[updateRelationshipStatus] No relationshipId found, creating one...');
        final relResponse = await supabase
            .from('relationships')
            .insert({
              'status': status,
              'partner_a_id': userId,
              'distance': 'moderate',
            })
            .select('id')
            .single();
        
        relId = relResponse['id'] as String;

        // Link it to the user
        await supabase.from('users').update({
          'relationship_id': relId,
        }).eq('id', userId);
        
        debugPrint('[updateRelationshipStatus] Created and linked relationshipId: $relId');
      } else {
        // 2. Update the status in the existing database row
        final userRepo = _ref.read(userRepositoryProvider);
        await userRepo.updateRelationshipDetails(
          relationshipId: relId,
          status: status,
        );
      }

      // 3. If new status is 'single', also unpair the partner
      if (status == 'single' && profile.partnerId != null) {
        await _internalUnpair();
      }

      _ref.invalidate(userProfileProvider);
      _setSuccess('Relationship status updated to $status');
      return true;
    } catch (e) {
      debugPrint('[updateRelationshipStatus] Error: $e');
      _setError(e.toString());
      return false;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
