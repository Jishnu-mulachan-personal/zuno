import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A simple notifier to keep track of whether the current user has a profile
/// in the 'users' table. This is cached to avoid expensive lookups during
/// every router redirect.
class ProfileExistenceNotifier extends ChangeNotifier {
  bool? _hasProfile;
  bool _isLoading = false;

  bool? get hasProfile => _hasProfile;
  bool get isLoading => _isLoading;

  ProfileExistenceNotifier() {
    // Listen for auth changes to reset/refresh the cache
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        checkProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _hasProfile = null;
        notifyListeners();
      }
    });

    // Initial check if we are already logged in
    if (Supabase.instance.client.auth.currentUser != null) {
      checkProfile();
    }
  }

  Future<void> checkProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _hasProfile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // If we already have a result, don't fetch again unless forced
    // (We might want a 'force' parameter later if we delete accounts)
    if (_hasProfile != null && !_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userRow = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      _hasProfile = userRow != null;
    } catch (e) {
      debugPrint('[ProfileExistenceNotifier] Error checking profile: $e');
      _hasProfile = false; // Assume false on error to allow registration
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Call this after a successful registration to update the cache instantly
  void setHasProfile(bool value) {
    _hasProfile = value;
    notifyListeners();
  }
}

final profileExistenceProvider =
    ChangeNotifierProvider<ProfileExistenceNotifier>((ref) {
  return ProfileExistenceNotifier();
});
