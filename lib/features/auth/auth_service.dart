import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    bool clearError = false,
  }) =>
      AuthState(
        verificationId: verificationId ?? this.verificationId,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _auth = FirebaseAuth.instance;

  Future<void> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

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

    state = state.copyWith(isLoading: true, clearError: true);

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

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
      // Web client ID is required
      if (webClientId == null) {
        throw 'Google Client ID not found in environment.';
      }

      final gsign.GoogleSignIn googleSignIn = gsign.GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return false; // User dismissed sign in
      }
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Missing Google Auth Tokens.';
      }

      await supabase.Supabase.instance.client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() => state = const AuthState();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
