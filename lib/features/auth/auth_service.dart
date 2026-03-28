import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Auth State ──────────────────────────────────────────────────────────────

class AuthState {
  final String? verificationId;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.verificationId,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    String? verificationId,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        verificationId: verificationId ?? this.verificationId,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _auth = FirebaseAuth.instance;

  Future<void> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification (Android only)
        try {
          await _auth.signInWithCredential(credential);
          state = state.copyWith(isLoading: false);
        } on FirebaseAuthException catch (e) {
          state = state.copyWith(isLoading: false, error: e.message);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        state = state.copyWith(
          isLoading: false,
          error: e.message ?? 'Verification failed. Please try again.',
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        state = state.copyWith(
          isLoading: false,
          verificationId: verificationId,
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Keep verificationId fresh — user may still type the code manually
        state = state.copyWith(verificationId: verificationId);
      },
    );
  }

  Future<bool> verifyOTP(String otp) async {
    final vid = state.verificationId;
    if (vid == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    final credential = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: otp,
    );

    try {
      await _auth.signInWithCredential(credential);
      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Invalid code. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const AuthState();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
