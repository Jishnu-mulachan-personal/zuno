import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─── Auth State ──────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final String? error;
  final bool needsVerification;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.needsVerification = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? needsVerification,
    bool clearError = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        needsVerification: needsVerification ?? this.needsVerification,
      );
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _supabase = supabase.Supabase.instance.client;

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true, needsVerification: false);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'zuno://login-callback/',
      );
      
      // session is null if email confirmation is required
      final needsVerification = response.session == null;
      
      state = state.copyWith(
        isLoading: false,
        needsVerification: needsVerification,
      );
      return true;
    } on supabase.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true, needsVerification: false);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on supabase.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true, needsVerification: false);
    print('DEBUG: Starting Google Sign-In...');

    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
      
      print('DEBUG: Web Client ID present: ${webClientId != null}');
      print('DEBUG: iOS Client ID present: ${iosClientId != null}');
      
      if (webClientId == null) {
        print('DEBUG ERROR: Google Client ID not found in environment.');
        throw 'Google Client ID not found in environment.';
      }

      final gsign.GoogleSignIn googleSignIn = gsign.GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      
      print('DEBUG: Attempting googleSignIn.signIn()...');
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('DEBUG: googleSignIn.signIn() returned null (user canceled or error occurred)');
        state = state.copyWith(isLoading: false);
        return false;
      }
      
      print('DEBUG: User signed in: ${googleUser.email}');
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      print('DEBUG: Access Token present: ${accessToken != null}');
      print('DEBUG: ID Token present: ${idToken != null}');

      if (accessToken == null || idToken == null) {
        print('DEBUG ERROR: Missing Google Auth Tokens.');
        throw 'Missing Google Auth Tokens.';
      }

      print('DEBUG: Attempting Supabase signInWithIdToken...');
      await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('DEBUG: Supabase sign-in successful!');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      print('DEBUG ERROR: Google Sign-In Exception: $e');
      print('DEBUG STACKTRACE: $stack');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _supabase.auth.signOut();
    try { await gsign.GoogleSignIn().signOut(); } catch (_) {}
    state = const AuthState();
  }

  void reset() => state = const AuthState();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
