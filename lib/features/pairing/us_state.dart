import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'us_image_service.dart';
import '../settings/profile_image_service.dart';
import '../auth/user_repository.dart';
import '../dashboard/dashboard_state.dart';


// ── Model ─────────────────────────────────────────────────────────────────────

class SharedPost {
  final String id;
  final String userId;
  final String userDisplayName;
  final String? avatarUrl;
  final String caption;
  final String? imageUrl;
  final List<String> contextTags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedPost({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.avatarUrl,
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
      avatarUrl: avatarUrl,
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
      avatarUrl: (row['users'] as Map?)?['avatar_url'] as String?,
      caption: row['caption'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      contextTags: List<String>.from(row['context_tags'] ?? []),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}


// ── Feed provider ────────────────────────────────────────────────────────────

// ── Feed provider ────────────────────────────────────────────────────────────

class SharedPostsState {
  final List<SharedPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const SharedPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  SharedPostsState copyWith({
    List<SharedPost>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return SharedPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SharedPostsNotifier extends StateNotifier<SharedPostsState> {
  SharedPostsNotifier() : super(const SharedPostsState()) {
    fetchInitial();
  }

  static const int _pageSize = 15;

  Future<void> fetchInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final posts = await _fetchPage();
    if (posts == null) return; // Error handled inside _fetchPage

    state = state.copyWith(
      posts: posts,
      isLoading: false,
      hasMore: posts.length >= _pageSize,
    );
  }

  Future<void> fetchMore() async {
    if (state.isLoadingMore || !state.hasMore || state.posts.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);
    final lastTimestamp = state.posts.last.createdAt;
    final posts = await _fetchPage(beforeTimestamp: lastTimestamp);

    if (posts == null) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }

    state = state.copyWith(
      posts: [...state.posts, ...posts],
      isLoadingMore: false,
      hasMore: posts.length >= _pageSize,
    );
  }

  Future<void> refresh() => fetchInitial();

  Future<List<SharedPost>?> _fetchPage({DateTime? beforeTimestamp}) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // Step 1: Resolve relationship_id
      final userRow = await supabase
          .from('users')
          .select('relationship_id')
          .eq('id', userId)
          .maybeSingle();

      final relationshipId = userRow?['relationship_id'] as String?;
      if (relationshipId == null) return [];

      // Step 2: Fetch posts with pagination
      var query = supabase
          .from('shared_posts')
          .select('id, user_id, caption, image_url, context_tags, created_at, updated_at')
          .eq('relationship_id', relationshipId);

      if (beforeTimestamp != null) {
        query = query.lt('created_at', beforeTimestamp.toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(_pageSize);
      if (rows.isEmpty) return [];

      // Step 3: Fetch display names
      final authorIds = (rows as List)
          .map((r) => r['user_id'] as String)
          .toSet()
          .toList();

      final nameRows = await supabase
          .from('users')
          .select('id, display_name, avatar_url')
          .inFilter('id', authorIds);

      final userDataMap = <String, (String, String?)>{
        for (final n in nameRows)
          n['id'] as String: (
            (n['display_name'] as String?) ?? 'Partner',
            n['avatar_url'] as String?
          ),
      };

      return rows.map((r) {
        final userData = userDataMap[r['user_id'] as String];
        return SharedPost(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          userDisplayName: userData?.$1 ?? 'Partner',
          avatarUrl: userData?.$2,
          caption: r['caption'] as String? ?? '',
          imageUrl: r['image_url'] as String?,
          contextTags: List<String>.from(r['context_tags'] ?? []),
          createdAt: DateTime.parse(r['created_at'] as String),
          updatedAt: DateTime.parse(r['updated_at'] as String),
        );
      }).toList();

    } catch (e) {
      debugPrint('[SharedPostsNotifier] ERROR: $e');
      state = state.copyWith(error: e.toString(), isLoading: false, isLoadingMore: false);
      return null;
    }
  }
}

final sharedPostsProvider =
    StateNotifierProvider<SharedPostsNotifier, SharedPostsState>((ref) {
  return SharedPostsNotifier();
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

      // Trigger partner notification
      final sbUser = supabase.auth.currentUser;
      final identifier = sbUser?.email;
      if (identifier != null) {
        supabase.functions.invoke(
          'notify_partner',
          body: {
            'identifier': identifier,
            'type': 'shared_post',
          },
        ).ignore();
      }

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

      // Step 1: Delete database record
      // We use .select().maybeSingle() to verify that the row was actually 
      // deleted (which confirms the ID exists AND the user has RLS permission).
      final response = await supabase
          .from('shared_posts')
          .delete()
          .eq('id', postId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Post not found or you do not have permission to delete it.');
      }

      // Step 2: Delete storage image (best-effort)
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await UsImageService.deleteByUrl(imageUrl);
      }

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

  // ── Update relationship photo ──────────────────────────────────────────────

  Future<bool> updateUsPhoto({
    required String relationshipId,
    required File imageFile,
    String? oldPath,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      // 1. Upload
      final newPath = await ProfileImageService.compressAndUpload(
        image: imageFile,
        bucketName: ProfileImageService.bucketUsPhotos,
        folderId: relationshipId,
      );

      // 2. Update DB
      await ref.read(userRepositoryProvider).updateRelationshipDetails(
        relationshipId: relationshipId,
        usPhotoUrl: newPath,
      );

      // 3. Cleanup old
      if (oldPath != null && oldPath.isNotEmpty) {
        ProfileImageService.deleteByUrl(ProfileImageService.bucketUsPhotos, oldPath).ignore();
      }

      ref.invalidate(userProfileProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[UsPostNotifier.updateUsPhoto] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
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
