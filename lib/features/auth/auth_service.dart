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

// ─── Auth Service ─────────────────────────────────────────────────────────────
//
// TODO: To enable real Firebase OTP:
// 1. Add your google-services.json to android/app/
// 2. Add GoogleService-Info.plist to ios/Runner/
// 3. Run: flutterfire configure
// 4. Uncomment the Firebase imports and replace the stub implementations below.
//
// import 'package:firebase_auth/firebase_auth.dart';
//
// final _auth = FirebaseAuth.instance;

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    // ── STUB: Replace with real Firebase call ──────────────────────────────
    // await _auth.verifyPhoneNumber(
    //   phoneNumber: phoneNumber,
    //   verificationCompleted: (credential) async {
    //     await _auth.signInWithCredential(credential);
    //   },
    //   verificationFailed: (e) {
    //     state = state.copyWith(isLoading: false, error: e.message);
    //   },
    //   codeSent: (verificationId, _) {
    //     state = state.copyWith(isLoading: false, verificationId: verificationId);
    //   },
    //   codeAutoRetrievalTimeout: (verificationId) {
    //     state = state.copyWith(verificationId: verificationId);
    //   },
    // );

    // Stub: simulate a 1.5s network call and advance
    await Future.delayed(const Duration(milliseconds: 1500));
    state = state.copyWith(isLoading: false, verificationId: 'stub-verification-id');
  }

  Future<bool> verifyOTP(String otp) async {
    if (state.verificationId == null) return false;
    state = state.copyWith(isLoading: true, error: null);

    // ── STUB: Replace with real Firebase call ──────────────────────────────
    // final credential = PhoneAuthProvider.credential(
    //   verificationId: state.verificationId!,
    //   smsCode: otp,
    // );
    // try {
    //   await _auth.signInWithCredential(credential);
    //   state = state.copyWith(isLoading: false);
    //   return true;
    // } on FirebaseAuthException catch (e) {
    //   state = state.copyWith(isLoading: false, error: e.message);
    //   return false;
    // }

    await Future.delayed(const Duration(milliseconds: 1500));
    // Stub: any 6-digit code passes
    if (otp.length == 6) {
      state = state.copyWith(isLoading: false);
      return true;
    }
    state = state.copyWith(isLoading: false, error: 'Invalid code. Please try again.');
    return false;
  }

  void reset() => state = const AuthState();
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
