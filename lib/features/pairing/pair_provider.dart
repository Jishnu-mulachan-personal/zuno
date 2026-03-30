import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Token generation helper ─────────────────────────────────────────────────

const _chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const _tokenTtlMinutes = 10;

String _generateToken() {
  final rand = Random.secure();
  final suffix =
      List.generate(12, (_) => _chars[rand.nextInt(_chars.length)]).join();
  return 'zuno_inv_$suffix';
}

// ── Invite state ─────────────────────────────────────────────────────────────

class InviteState {
  final String? token;
  final DateTime? expiresAt;
  final bool isGenerating;
  final String? error;

  const InviteState({
    this.token,
    this.expiresAt,
    this.isGenerating = false,
    this.error,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  InviteState copyWith({
    String? token,
    DateTime? expiresAt,
    bool? isGenerating,
    String? error,
  }) {
    return InviteState(
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

// ── InviteNotifier ────────────────────────────────────────────────────────────

class InviteNotifier extends StateNotifier<InviteState> {
  InviteNotifier() : super(const InviteState());

  /// Generates a new one-time invite token, stores it in `partner_invites`.
  Future<void> generateToken() async {
    final sbUser = Supabase.instance.client.auth.currentUser;
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    final identifier = sbUser?.email ?? fbUser?.phoneNumber;

    if (identifier == null) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    state = state.copyWith(isGenerating: true, error: null);

    try {
      final supabase = Supabase.instance.client;

      // Resolve current user's id
      final column = identifier.contains('@') ? 'email' : 'phone';
      final userRow = await supabase
          .from('users')
          .select('id')
          .eq(column, identifier)
          .maybeSingle();

      if (userRow == null) {
        state = state.copyWith(
            isGenerating: false, error: 'User profile not found');
        return;
      }

      final userId = userRow['id'] as String;
      final token = _generateToken();
      final expiresAt =
          DateTime.now().toUtc().add(const Duration(minutes: _tokenTtlMinutes));

      await supabase.from('partner_invites').insert({
        'token': token,
        'created_by': userId,
        'expires_at': expiresAt.toIso8601String(),
      });

      state = InviteState(
        token: token,
        expiresAt: expiresAt.toLocal(),
        isGenerating: false,
      );
    } catch (e) {
      debugPrint('[generateToken] $e');
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }
}

final inviteProvider =
    StateNotifierProvider<InviteNotifier, InviteState>((ref) {
  return InviteNotifier();
});

// ── Claim state ───────────────────────────────────────────────────────────────

enum ClaimStatus { idle, loading, success, error }

class ClaimState {
  final ClaimStatus status;
  final String? message;

  const ClaimState({this.status = ClaimStatus.idle, this.message});
}

class ClaimNotifier extends StateNotifier<ClaimState> {
  ClaimNotifier() : super(const ClaimState());

  /// Validates and claims `token`, linking both users under a shared relationship_id.
  Future<bool> claimToken(String token) async {
    final sbUser = Supabase.instance.client.auth.currentUser;
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    final identifier = sbUser?.email ?? fbUser?.phoneNumber;

    if (identifier == null) {
      state = const ClaimState(
          status: ClaimStatus.error, message: 'Not authenticated');
      return false;
    }

    state = const ClaimState(status: ClaimStatus.loading);

    try {
      final supabase = Supabase.instance.client;

      // 1. Look up the invite row
      final invite = await supabase
          .from('partner_invites')
          .select('id, created_by, used, expires_at')
          .eq('token', token)
          .maybeSingle();

      if (invite == null) {
        state = const ClaimState(
            status: ClaimStatus.error, message: 'Invite not found');
        return false;
      }

      final alreadyUsed = (invite['used'] as bool?) ?? false;
      final expiresAt =
          DateTime.parse(invite['expires_at'] as String).toLocal();

      if (alreadyUsed) {
        state = const ClaimState(
            status: ClaimStatus.error,
            message: 'Invite already used or expired');
        return false;
      }
      if (DateTime.now().isAfter(expiresAt)) {
        state = const ClaimState(
            status: ClaimStatus.error, message: 'Invite has expired');
        return false;
      }

      // 2. Resolve claimer's user id
      final column = identifier.contains('@') ? 'email' : 'phone';
      final claimerRow = await supabase
          .from('users')
          .select('id, relationship_id')
          .eq(column, identifier)
          .maybeSingle();

      if (claimerRow == null) {
        state = const ClaimState(
            status: ClaimStatus.error, message: 'Your profile was not found');
        return false;
      }

      final claimerId = claimerRow['id'] as String;
      final creatorId = invite['created_by'] as String;

      if (claimerId == creatorId) {
        state = const ClaimState(
            status: ClaimStatus.error,
            message: 'You cannot pair with yourself');
        return false;
      }

      // 3. Find or create the relationships row
      //    Strategy: use creator's existing relationship_id if they have one,
      //    otherwise create a new row with partner_a_id = creatorId.
      final creatorRow = await supabase
          .from('users')
          .select('relationship_id')
          .eq('id', creatorId)
          .maybeSingle();

      final existingRelId = creatorRow?['relationship_id'] as String?;

      String relationshipId;

      if (existingRelId != null) {
        // Creator already has a relationship row — update partner_b_id on it
        await supabase
            .from('relationships')
            .update({'partner_b_id': claimerId})
            .eq('id', existingRelId);

        relationshipId = existingRelId;
      } else {
        // No relationship row yet — create one with both partners
        final inserted = await supabase
            .from('relationships')
            .insert({
              'partner_a_id': creatorId,
              'partner_b_id': claimerId,
              'status': 'dating',  // sensible default
            })
            .select('id')
            .single();

        relationshipId = inserted['id'] as String;
      }

      // 4. Point both user rows at the relationship
      await supabase
          .from('users')
          .update({'relationship_id': relationshipId}).eq('id', creatorId);

      await supabase
          .from('users')
          .update({'relationship_id': relationshipId}).eq('id', claimerId);

      // 5. Mark invite as used
      await supabase
          .from('partner_invites')
          .update({'used': true, 'used_by': claimerId})
          .eq('token', token);

      state = const ClaimState(
          status: ClaimStatus.success,
          message: 'Paired successfully! 💚');
      return true;
    } catch (e) {
      debugPrint('[claimToken] $e');
      state = ClaimState(status: ClaimStatus.error, message: e.toString());
      return false;
    }
  }

  void reset() => state = const ClaimState();
}

final claimProvider =
    StateNotifierProvider<ClaimNotifier, ClaimState>((ref) {
  return ClaimNotifier();
});
