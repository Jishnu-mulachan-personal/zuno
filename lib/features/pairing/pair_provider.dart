import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_state.dart';

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

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

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

    if (sbUser == null) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    state = state.copyWith(isGenerating: true, error: null);

    try {
      final supabase = Supabase.instance.client;

      final userId = sbUser.id;
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
  final Ref ref;
  ClaimNotifier(this.ref) : super(const ClaimState());

  /// Validates and claims `token`, linking both users under a shared relationship_id.
  Future<bool> claimToken(String token) async {
    final sbUser = Supabase.instance.client.auth.currentUser;

    if (sbUser == null) {
      state = const ClaimState(
          status: ClaimStatus.error, message: 'Not authenticated');
      return false;
    }

    state = const ClaimState(status: ClaimStatus.loading);

    try {
      final supabase = Supabase.instance.client;

      // Fetch the current user's profile to get their preferred status
      final profile = ref.read(userProfileProvider).value;
      final currentStatus = profile?.relationshipStatus;

      // Call the secure RPC that handles cross-user updates safely
      final response = await supabase.rpc(
        'claim_pair_invite',
        params: {
          'invite_token': token,
          'p_status': currentStatus,
        },
      );

      final success = (response is Map) ? (response['success'] as bool? ?? false) : false;
      final message = (response is Map) ? (response['message'] as String? ?? 'Error') : 'Unknown error';

      if (!success) {
        state = ClaimState(status: ClaimStatus.error, message: message);
        return false;
      }

      state = ClaimState(status: ClaimStatus.success, message: message);
      return true;
    } catch (e) {
      debugPrint('[claimToken] $e');
      state = ClaimState(status: ClaimStatus.error, message: e.toString());
      return false;
    }
  }

  void reset() => state = const ClaimState();
}

final claimProvider = StateNotifierProvider<ClaimNotifier, ClaimState>((ref) {
  return ClaimNotifier(ref);
});
