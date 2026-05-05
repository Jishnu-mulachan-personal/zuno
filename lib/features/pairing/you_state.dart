import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/encryption_service.dart';
import 'us_state.dart';
import 'personal_image_service.dart';
import '../dashboard/dashboard_state.dart';

// ── Models ────────────────────────────────────────────────────────────────────

// Reusing SharedPost from us_state.dart

// ── Feed Provider ────────────────────────────────────────────────────────────

class UserPostsState {
  final List<SharedPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const UserPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  UserPostsState copyWith({
    List<SharedPost>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return UserPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UserPostsNotifier extends StateNotifier<UserPostsState> {
  UserPostsNotifier() : super(const UserPostsState()) {
    fetchInitial();
  }

  static const int _pageSize = 15;

  Future<void> fetchInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final posts = await _fetchPage();
    if (posts == null) return;

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
      // Step 1: Fetch personal posts
      var postsQuery = supabase
          .from('personal_posts')
          .select('id, user_id, caption, image_url, context_tags, created_at, updated_at')
          .eq('user_id', userId);

      if (beforeTimestamp != null) {
        postsQuery = postsQuery.lt('created_at', beforeTimestamp.toIso8601String());
      }

      final postRows = await postsQuery
          .order('created_at', ascending: false)
          .limit(_pageSize);

      // Step 2: Fetch all daily logs (not just shared ones)
      var logsFetchQuery = supabase
          .from('daily_logs')
          .select('id, user_id, journal_note, context_tags, created_at, mood_emoji')
          .eq('user_id', userId);

      if (beforeTimestamp != null) {
        logsFetchQuery = logsFetchQuery.lt('created_at', beforeTimestamp.toIso8601String());
      }

      final logRows = await logsFetchQuery
          .order('created_at', ascending: false)
          .limit(_pageSize);

      // Step 2.5: Fetch daily question answers
      var answersQuery = supabase
          .from('couple_daily_answers')
          .select('id, answer, created_at, couple_daily_questions(assigned_date, daily_questions(question_text))')
          .eq('user_id', userId);

      if (beforeTimestamp != null) {
        answersQuery = answersQuery.lt('created_at', beforeTimestamp.toIso8601String());
      }

      final answerRows = await answersQuery
          .order('created_at', ascending: false)
          .limit(_pageSize);

      if (postRows.isEmpty && logRows.isEmpty && answerRows.isEmpty) return [];

      // Step 3: Fetch user profile for display info
      final profile = await supabase
          .from('users')
          .select('display_name, avatar_url')
          .eq('id', userId)
          .single();

      final displayName = profile['display_name'] as String? ?? 'Me';
      final avatarUrl = profile['avatar_url'] as String?;

      // Step 4: Merge and decrypt
      final List<SharedPost> allPosts = [];

      // Add personal posts
      for (final r in postRows) {
        allPosts.add(SharedPost(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          userDisplayName: displayName,
          avatarUrl: avatarUrl,
          caption: r['caption'] as String? ?? '',
          imageUrl: r['image_url'] as String?,
          contextTags: List<String>.from(r['context_tags'] ?? []),
          createdAt: DateTime.parse(r['created_at'] as String),
          updatedAt: DateTime.parse(r['updated_at'] as String),
          type: SharedPostType.post,
        ));
      }

      // Add daily logs
      for (final l in logRows) {
        String decryptedNote = '';
        if (l['journal_note'] != null) {
          try {
            final dynamic jn = l['journal_note'];
            if (jn is List) {
              decryptedNote = EncryptionService.decrypt(List<int>.from(jn)) ?? '';
            } else if (jn is String) {
              if (jn.startsWith('\\x')) {
                final hexStr = jn.substring(2);
                final asciiBytes = <int>[];
                for (int i = 0; i < hexStr.length; i += 2) {
                  asciiBytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
                }
                final inner = String.fromCharCodes(asciiBytes);
                if (inner.startsWith('[')) {
                  final stripped = inner.substring(1, inner.length - 1).trim();
                  if (stripped.isNotEmpty) {
                    final parsedBytes = stripped.split(',').map((e) => int.parse(e.trim())).toList();
                    try {
                      decryptedNote = EncryptionService.decrypt(parsedBytes) ?? '';
                    } catch (_) {
                      decryptedNote = String.fromCharCodes(parsedBytes);
                    }
                  }
                } else {
                  decryptedNote = EncryptionService.decrypt(asciiBytes) ?? '';
                }
              } else if (jn.startsWith('[')) {
                final stripped = jn.substring(1, jn.length - 1).trim();
                if (stripped.isNotEmpty) {
                  final codeUnits = stripped.split(',').map((e) => int.parse(e.trim())).toList();
                  decryptedNote = String.fromCharCodes(codeUnits);
                }
              } else {
                decryptedNote = jn;
              }
            }
          } catch (e) {
            debugPrint('[UserPostsNotifier] journal_note decrypt error: $e');
          }
        }

        allPosts.add(SharedPost(
          id: l['id'] as String,
          userId: l['user_id'] as String,
          userDisplayName: displayName,
          avatarUrl: avatarUrl,
          caption: decryptedNote,
          imageUrl: null,
          contextTags: List<String>.from(l['context_tags'] ?? []),
          createdAt: DateTime.parse(l['created_at'] as String),
          updatedAt: DateTime.parse(l['created_at'] as String),
          type: SharedPostType.dailyLog,
          moodEmoji: l['mood_emoji'] as String?,
        ));
      }

      // Add daily question answers
      for (final a in answerRows) {
        final qData = a['couple_daily_questions'] as Map?;
        final dqData = qData?['daily_questions'] as Map?;
        final questionText = dqData?['question_text'] as String? ?? 'Daily Question';
        final answerText = a['answer'] as String? ?? '';

        allPosts.add(SharedPost(
          id: a['id'] as String,
          userId: userId,
          userDisplayName: displayName,
          avatarUrl: avatarUrl,
          caption: 'Q: $questionText\nA: $answerText',
          contextTags: [],
          createdAt: DateTime.parse(a['created_at'] as String),
          updatedAt: DateTime.parse(a['created_at'] as String),
          type: SharedPostType.dailyLog, // Use dailyLog as fallback type
        ));
      }

      // Sort combined list by createdAt descending
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allPosts.take(_pageSize).toList();

    } catch (e) {
      debugPrint('[UserPostsNotifier] ERROR: $e');
      state = state.copyWith(error: e.toString(), isLoading: false, isLoadingMore: false);
      return null;
    }
  }
}

final userPostsProvider =
    StateNotifierProvider<UserPostsNotifier, UserPostsState>((ref) {
  return UserPostsNotifier();
});

// ── Compose / Edit / Delete state ────────────────────────────────────────────

class UserPostState {
  final bool isSubmitting;
  final String? editingPostId;
  final String? error;

  const UserPostState({
    this.isSubmitting = false,
    this.editingPostId,
    this.error,
  });

  UserPostState copyWith({
    bool? isSubmitting,
    String? editingPostId,
    bool clearEditing = false,
    String? error,
    bool clearError = false,
  }) {
    return UserPostState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      editingPostId: clearEditing ? null : (editingPostId ?? this.editingPostId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UserPostNotifier extends StateNotifier<UserPostState> {
  final Ref ref;

  UserPostNotifier(this.ref) : super(const UserPostState());

  Future<bool> submitPost({
    required String caption,
    File? imageFile,
    required List<String> contextTags,
  }) async {
    if (caption.trim().isEmpty && imageFile == null) return false;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await PersonalImageService.compressAndUpload(
          image: imageFile,
          userId: userId,
        );
      }

      await supabase.from('personal_posts').insert({
        'user_id': userId,
        'caption': caption.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
        'context_tags': contextTags,
      });

      ref.invalidate(userPostsProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[UserPostNotifier.submitPost] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> editPost({
    required String postId,
    required String newCaption,
    required List<String> newTags,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('personal_posts').update({
        'caption': newCaption.trim(),
        'context_tags': newTags,
      }).eq('id', postId);

      ref.invalidate(userPostsProvider);
      state = state.copyWith(isSubmitting: false, clearEditing: true);
      return true;
    } catch (e) {
      debugPrint('[UserPostNotifier.editPost] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deletePost({
    required String postId,
    String? imageUrl,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('personal_posts')
          .delete()
          .eq('id', postId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Post not found or you do not have permission to delete it.');
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        await PersonalImageService.deleteByUrl(imageUrl);
      }

      ref.invalidate(userPostsProvider);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      debugPrint('[UserPostNotifier.deletePost] Error: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void setEditing(String? postId) =>
      state = state.copyWith(editingPostId: postId, clearEditing: postId == null);
}

final userPostNotifierProvider =
    StateNotifierProvider<UserPostNotifier, UserPostState>((ref) {
  return UserPostNotifier(ref);
});

// ── Legacy / Helper Compatibility ─────────────────────────────────────────────

class DailyLog {
  final String date;
  final String createdTime;
  final String moodEmoji;
  final List<String> contextTags;
  final String? journalNote;
  final bool shareWithPartner;

  DailyLog({
    required this.date,
    required this.createdTime,
    required this.moodEmoji,
    required this.contextTags,
    this.journalNote,
    this.shareWithPartner = false,
  });
}

// userLogsProvider is kept for compatibility if needed, but the new UI uses userPostsProvider
final userLogsProvider = FutureProvider<List<DailyLog>>((ref) async {
  final sbUser = Supabase.instance.client.auth.currentUser;
  if (sbUser == null) return [];

  final userId = sbUser.id;
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('daily_logs')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  if (response is! List) return [];
  
  return response.map((row) {
    String? noteStr;
    if (row['journal_note'] != null) {
      try {
        final dynamic jn = row['journal_note'];
        if (jn is List) {
          noteStr = EncryptionService.decrypt(List<int>.from(jn));
        } else if (jn is String) {
          if (jn.startsWith('\\x')) {
            final hexStr = jn.substring(2);
            final asciiBytes = <int>[];
            for (int i = 0; i < hexStr.length; i += 2) {
              asciiBytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
            }
            final inner = String.fromCharCodes(asciiBytes);
            if (inner.startsWith('[')) {
              final stripped = inner.substring(1, inner.length - 1).trim();
              if (stripped.isNotEmpty) {
                final parsedBytes = stripped.split(',').map((e) => int.parse(e.trim())).toList();
                try {
                  noteStr = EncryptionService.decrypt(parsedBytes);
                } catch (_) {
                  noteStr = String.fromCharCodes(parsedBytes);
                }
              }
            } else {
              noteStr = EncryptionService.decrypt(asciiBytes);
            }
          } else if (jn.startsWith('[')) {
            final stripped = jn.substring(1, jn.length - 1).trim();
            if (stripped.isNotEmpty) {
              final codeUnits = stripped.split(',').map((e) => int.parse(e.trim())).toList();
              noteStr = String.fromCharCodes(codeUnits);
            }
          } else {
            noteStr = jn;
          }
        }
      } catch (e) {
        debugPrint('[you_state] journal_note decode error: $e');
        noteStr = null;
      }
    }
    
    DateTime? createdTime;
    if (row['created_at'] != null) {
      createdTime = DateTime.tryParse(row['created_at'].toString())?.toLocal();
    }
    String timeStr = '';
    if (createdTime != null) {
      timeStr = '${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';
    }
    
    return DailyLog(
      date: row['log_date'] as String? ?? '',
      createdTime: timeStr,
      moodEmoji: row['mood_emoji'] as String? ?? '😊',
      contextTags: List<String>.from(row['context_tags'] ?? []),
      journalNote: noteStr,
      shareWithPartner: row['share_with_partner'] as bool? ?? false,
    );
  }).toList();
});
// ── Timeline Filtering ────────────────────────────────────────────────────────
enum TimelineFilter { all, reflectionsOnly }

final timelineFilterProvider = StateProvider<TimelineFilter>((ref) => TimelineFilter.reflectionsOnly);
