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
    final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    state = state.copyWith(isGenerating: true, error: null);

    try {
      final supabase = Supabase.instance.client;

      // Resolve current user's id
      final userRow = await supabase
          .from('users')
          .select('id')
          .eq('phone', phone)
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
    final phone = fb.FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null) {
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
      final claimerRow = await supabase
          .from('users')
          .select('id, relationship_id')
          .eq('phone', phone)
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

      // 3. Find or create a relationship_id (use creator's existing one, or
      //    claimer's, or generate a new UUID)
      final creatorRow = await supabase
          .from('users')
          .select('relationship_id')
          .eq('id', creatorId)
          .maybeSingle();

      String relationshipId = creatorRow?['relationship_id'] as String? ??
          claimerRow['relationship_id'] as String? ??
          _generateUuid();

      // 4. Update both users
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

// ── Tiny UUID helper (without depending on uuid package) ────────────────────

String _generateUuid() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int n) => n.toRadixString(16).padLeft(2, '0');
  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
      '-${hex(bytes[4])}${hex(bytes[5])}'
      '-${hex(bytes[6])}${hex(bytes[7])}'
      '-${hex(bytes[8])}${hex(bytes[9])}'
      '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}
