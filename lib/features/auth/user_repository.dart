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
    required String gender,
  }) async {
    final sbUser = _supabase.auth.currentUser;
    final fbUser = _firebaseAuth.currentUser;

    if (sbUser == null && fbUser == null) {
      throw Exception('User is not authenticated.');
    }

    final email = sbUser?.email ?? fbUser?.email;
    final phone = fbUser?.phoneNumber;

    // 1. Insert the user in the `users` table
    final userResponse = await _supabase
        .from('users')
        .insert({
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          'display_name': name,
          'gender': gender,
          'date_of_birth': dateOfBirth.toIso8601String(),
          'occupation': occupation,
        })
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

  /// Returns true if the currently authenticated user already has
  /// a profile in the Supabase `users` table.
  Future<bool> isUserRegistered() async {
    final sbUser = _supabase.auth.currentUser;
    if (sbUser != null && sbUser.email != null) {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('email', sbUser.email!)
          .maybeSingle();
      if (response != null) return true;
    }

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
