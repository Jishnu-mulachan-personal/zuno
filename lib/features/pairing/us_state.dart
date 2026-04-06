import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'us_image_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class SharedPost {
  final String id;
  final String userId;
  final String userDisplayName;
  final String caption;
  final String? imageUrl;
  final List<String> contextTags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedPost({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.caption,
    this.imageUrl,
    required this.contextTags,
    required this.createdAt,
    required this.updatedAt,
  });

  SharedPost copyWith({
    String? caption,
    List<String>? contextTags,
  }) {
    return SharedPost(
      id: id,
      userId: userId,
      userDisplayName: userDisplayName,
      caption: caption ?? this.caption,
      imageUrl: imageUrl,
      contextTags: contextTags ?? this.contextTags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory SharedPost.fromRow(Map<String, dynamic> row) {
    return SharedPost(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      userDisplayName: (row['users'] as Map?)?['display_name'] as String? ?? 'Partner',
      caption: row['caption'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      contextTags: List<String>.from(row['context_tags'] ?? []),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}

// ── Feed provider ────────────────────────────────────────────────────────────

final sharedPostsProvider = FutureProvider<List<SharedPost>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    debugPrint('[sharedPostsProvider] No authenticated user');
    return [];
  }

  try {
    // Step 1: Resolve this user's relationship_id
    final userRow = await supabase
        .from('users')
        .select('relationship_id')
        .eq('id', userId)
        .maybeSingle();

    final relationshipId = userRow?['relationship_id'] as String?;
    debugPrint('[sharedPostsProvider] relationshipId=$relationshipId');
    if (relationshipId == null) return [];

    // Step 2: Fetch posts — use explicit FK hint to avoid PostgREST ambiguity
    final rows = await supabase
        .from('shared_posts')
        .select('id, user_id, caption, image_url, context_tags, created_at, updated_at')
        .eq('relationship_id', relationshipId)
        .order('created_at', ascending: false)
        .limit(50);

    debugPrint('[sharedPostsProvider] Fetched ${rows.length} posts');

    if (rows.isEmpty) return [];

    // Step 3: Fetch display names for all authors in one query
    final authorIds = (rows as List)
        .map((r) => r['user_id'] as String)
        .toSet()
        .toList();

    final nameRows = await supabase
        .from('users')
        .select('id, display_name')
        .inFilter('id', authorIds);

    final nameMap = <String, String>{
      for (final n in nameRows)
        n['id'] as String: (n['display_name'] as String?) ?? 'Partner',
    };

    debugPrint('[sharedPostsProvider] Name map: $nameMap');

    return rows.map((r) {
      return SharedPost(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        userDisplayName: nameMap[r['user_id'] as String] ?? 'Partner',
        caption: r['caption'] as String? ?? '',
        imageUrl: r['image_url'] as String?,
        contextTags: List<String>.from(r['context_tags'] ?? []),
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
    }).toList();
  } catch (e, st) {
    debugPrint('[sharedPostsProvider] ERROR: $e');
    debugPrint('[sharedPostsProvider] StackTrace: $st');
    rethrow; // surface to UI error state instead of hiding behind []
  }
});


// ── Compose / Edit / Delete state ────────────────────────────────────────────

class UsPostState {
  final bool isSubmitting;
  final String? editingPostId;
  final String? error;

  const UsPostState({
    this.isSubmitting = false,
    this.editingPostId,
    this.error,
  });

  UsPostState copyWith({
    bool? isSubmitting,
    String? editingPostId,
    bool clearEditing = false,
    String? error,
    bool clearError = false,
  }) {
    return UsPostState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      editingPostId: clearEditing ? null : (editingPostId ?? this.editingPostId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UsPostNotifier extends StateNotifier<UsPostState> {
  final Ref ref;

  UsPostNotifier(this.ref) : super(const UsPostState());

  // ── Submit a new post ──────────────────────────────────────────────────────

  Future<bool> submitPost({
    required String caption,
    File? imageFile,
    required List<String> contextTags,
    required String relationshipId,
  }) async {
    if (caption.trim().isEmpty && imageFile == null) return false;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await UsImageService.compressAndUpload(
          image: imageFile,
          relationshipId: relationshipId,
        );
      }

      await supabase.from('shared_posts').insert({
        'user_id': userId,
        'relationship_id': relationshipId,
        'caption': caption.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
        'context_tags': contextTags,
      });

      ref.invalidate(sharedPostsProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[UsPostNotifier.submitPost] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  // ── Edit an existing post (caption + tags only, not image) ────────────────

  Future<bool> editPost({
    required String postId,
    required String newCaption,
    required List<String> newTags,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('shared_posts').update({
        'caption': newCaption.trim(),
        'context_tags': newTags,
      }).eq('id', postId);

      ref.invalidate(sharedPostsProvider);
      state = state.copyWith(isSubmitting: false, clearEditing: true);
      return true;
    } catch (e) {
      debugPrint('[UsPostNotifier.editPost] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  // ── Delete a post (and its storage image if present) ─────────────────────

  Future<bool> deletePost({
    required String postId,
    String? imageUrl,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;

      // Delete storage image first (best-effort)
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await UsImageService.deleteByUrl(imageUrl);
      }

      await supabase.from('shared_posts').delete().eq('id', postId);

      ref.invalidate(sharedPostsProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[UsPostNotifier.deletePost] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void setEditing(String? postId) =>
      state = state.copyWith(editingPostId: postId, clearEditing: postId == null);
}

final usPostNotifierProvider =
    StateNotifierProvider<UsPostNotifier, UsPostState>((ref) {
  return UsPostNotifier(ref);
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Extract #hashtag words from arbitrary text.
List<String> extractHashtags(String text) {
  final re = RegExp(r'#(\w+)');
  return re.allMatches(text).map((m) => '#${m.group(1)!}').toSet().toList();
}

/// Strip #hashtags from text (used to store clean caption).
String stripHashtags(String text) =>
    text.replaceAll(RegExp(r'#\w+'), '').replaceAll(RegExp(r' +'), ' ').trim();

/// Human-friendly relative time (e.g. "2 h ago", "just now").
String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
