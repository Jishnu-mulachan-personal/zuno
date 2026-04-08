import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<void> createUserProfile({
    required String name,
    required DateTime dateOfBirth,
    required String occupation,
    required String gender,
    required String relationshipStatus,
    DateTime? marriedOn,
    String? relationshipDistance,
  }) async {
    final sbUser = _supabase.auth.currentUser;

    if (sbUser == null) {
      throw Exception('User is not authenticated.');
    }

    final userId = sbUser.id;
    final email = sbUser.email;

    // 1. Insert the user in the `users` table using their Auth UUID
    await _supabase
        .from('users')
        .insert({
          'id': userId,
          if (email != null) 'email': email,
          'display_name': name,
          'gender': gender,
          'date_of_birth': dateOfBirth.toIso8601String(),
          'occupation': occupation,
        });

    // 2. Insert relationship details into `relationships`
    final relResponse = await _supabase
        .from('relationships')
        .insert({
          'status': relationshipStatus, 
          'distance': relationshipDistance ?? 'moderate',
          if (marriedOn != null) 'anniversary_date': marriedOn.toIso8601String(),
          'partner_a_id': userId,
        })
        .select('id')
        .single();

    final relId = relResponse['id'];

    // 3. Update the user record to link the new relationship_id
    await _supabase.from('users').update({
      'relationship_id': relId,
    }).eq('id', userId);

    // 4. Initialize user_settings with default privacy_preference
    await _supabase.from('user_settings').upsert({
      'user_id': userId,
      'privacy_preference': 'balanced',
    });
  }

  Future<void> updateRelationshipDetails({
    required String relationshipId,
    String? status,
    DateTime? marriedOn,
    String? relationshipDistance,
    String? usPhotoUrl,
  }) async {
    await _supabase.from('relationships').update({
      if (status != null) 'status': status,
      if (marriedOn != null) 'anniversary_date': marriedOn.toIso8601String(),
      if (relationshipDistance != null) 'distance': relationshipDistance,
      if (usPhotoUrl != null) 'us_photo_url': usPhotoUrl,
    }).eq('id', relationshipId);
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final sbUser = _supabase.auth.currentUser;
    if (sbUser == null) throw Exception('Not authenticated');

    await _supabase.from('users').update({
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', sbUser.id);
  }


  Future<void> updateUserSettings({
    String? privacyPreference,
    bool? journalNotePrivate,
    List<String>? goals,
  }) async {
    final sbUser = _supabase.auth.currentUser;
    if (sbUser == null) throw Exception('Not authenticated');

    await _supabase.from('user_settings').upsert({
      'user_id': sbUser.id,
      if (privacyPreference != null) 'privacy_preference': privacyPreference,
      if (journalNotePrivate != null) 'journal_note_private': journalNotePrivate,
      if (goals != null) 'goals': goals,
    });
  }

  /// Returns true if the currently authenticated user already has
  /// a profile in the Supabase `users` table.
  Future<bool> isUserRegistered() async {
    final sbUser = _supabase.auth.currentUser;
    if (sbUser == null) return false;

    final response = await _supabase
        .from('users')
        .select('id')
        .eq('id', sbUser.id)
        .maybeSingle();
    
    return response != null;
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    Supabase.instance.client,
  );
});
