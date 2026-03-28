import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class UserRepository {
  final SupabaseClient _supabase;
  final fb.FirebaseAuth _firebaseAuth;

  UserRepository(this._supabase, this._firebaseAuth);

  Future<void> createUserProfile({
    required String name,
    required DateTime dateOfBirth,
    required String occupation,
    required DateTime marriedOn,
    required String relationshipDistance,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated via Firebase.');
    }

    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) {
      throw Exception('No phone number found for authenticated user.');
    }

    // 1. Insert or update the user in the `users` table
    final userResponse = await _supabase
        .from('users')
        .upsert({
          'email': user.email, // May be null for phone auth
          'phone': phone,
          'display_name': name,
          'date_of_birth': dateOfBirth.toIso8601String(),
          'occupation': occupation,
        }, onConflict: 'phone')
        .select('id')
        .single();

    final userId = userResponse['id'];

    // 2. Insert relationship details into `relationships`
    final relResponse = await _supabase
        .from('relationships')
        .insert({
          'status': 'dating', // Standard default until user updates later
          'distance': relationshipDistance,
          'anniversary_date': marriedOn.toIso8601String(),
          'partner_a_id': userId,
          'privacy_preference': 'balanced', // Default
        })
        .select('id')
        .single();

    final relId = relResponse['id'];

    // 3. Update the user record to link the new relationship_id
    await _supabase.from('users').update({
      'relationship_id': relId,
    }).eq('id', userId);
  }

  /// Returns true if the currently authenticated Firebase user already has
  /// a profile in the Supabase `users` table.
  Future<bool> isUserRegistered() async {
    final phone = _firebaseAuth.currentUser?.phoneNumber;
    if (phone == null || phone.isEmpty) return false;
    final response = await _supabase
        .from('users')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    return response != null;
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    Supabase.instance.client,
    fb.FirebaseAuth.instance,
  );
});
