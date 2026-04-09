import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class DailyQuestion {
  final String coupleDailyQuestionId;
  final String questionId;
  final String questionText;
  final DateTime assignedDate;

  const DailyQuestion({
    required this.coupleDailyQuestionId,
    required this.questionId,
    required this.questionText,
    required this.assignedDate,
  });

  factory DailyQuestion.fromRow(Map<String, dynamic> row) {
    return DailyQuestion(
      coupleDailyQuestionId: row['couple_daily_question_id'] as String,
      questionId: row['question_id'] as String,
      questionText: row['question_text'] as String,
      assignedDate: DateTime.parse(row['assigned_date'] as String),
    );
  }
}

class DailyAnswer {
  final String id;
  final String coupleDailyQuestionId;
  final String userId;
  final String answer;
  final String? partnerReviewStatus;
  final String? partnerReviewComment;
  final DateTime? createdAt;

  const DailyAnswer({
    required this.id,
    required this.coupleDailyQuestionId,
    required this.userId,
    required this.answer,
    this.partnerReviewStatus,
    this.partnerReviewComment,
    this.createdAt,
  });

  factory DailyAnswer.fromRow(Map<String, dynamic> row) {
    return DailyAnswer(
      id: row['id'] as String,
      coupleDailyQuestionId: row['couple_daily_question_id'] as String,
      userId: row['user_id'] as String,
      answer: row['answer'] as String,
      partnerReviewStatus: row['partner_review_status'] as String?,
      partnerReviewComment: row['partner_review_comment'] as String?,
      createdAt: row['created_at'] != null ? DateTime.parse(row['created_at'] as String) : null,
    );
  }
}

// ── State ────────────────────────────────────────────────────────────────────

class DailyQuestionsState {
  final List<DailyQuestion> questions;
  final List<DailyAnswer> answers;
  final int gameScore;
  final int gameStreak;
  final bool isLoading;
  final bool isLoadingHistory;
  final String? error;

  const DailyQuestionsState({
    this.questions = const [],
    this.answers = const [],
    this.gameScore = 0,
    this.gameStreak = 0,
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.error,
  });

  DailyQuestionsState copyWith({
    List<DailyQuestion>? questions,
    List<DailyAnswer>? answers,
    int? gameScore,
    int? gameStreak,
    bool? isLoading,
    bool? isLoadingHistory,
    String? error,
    bool clearError = false,
  }) {
    return DailyQuestionsState(
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      gameScore: gameScore ?? this.gameScore,
      gameStreak: gameStreak ?? this.gameStreak,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      error: clearError ? null : (error ?? this.error),
    );
  }

  // Helpers to get specific data
  DailyAnswer? getUserAnswer(String coupleDailyQuestionId, String currentUserId) {
    try {
      return answers.firstWhere(
          (a) => a.coupleDailyQuestionId == coupleDailyQuestionId && a.userId == currentUserId);
    } catch (_) {
      return null;
    }
  }

  DailyAnswer? getPartnerAnswer(String coupleDailyQuestionId, String currentUserId) {
    try {
      return answers.firstWhere(
          (a) => a.coupleDailyQuestionId == coupleDailyQuestionId && a.userId != currentUserId);
    } catch (_) {
      return null;
    }
  }

  // Grouped by date for history
  Map<String, List<DailyQuestion>> get questionsByDate {
    final Map<String, List<DailyQuestion>> map = {};
    for (var q in questions) {
      final dateKey = q.assignedDate.toIso8601String().split('T')[0];
      map.putIfAbsent(dateKey, () => []).add(q);
    }
    return map;
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class DailyQuestionsNotifier extends StateNotifier<DailyQuestionsState> {
  final Ref ref;
  RealtimeChannel? _channel;

  DailyQuestionsNotifier(this.ref) : super(const DailyQuestionsState()) {
    refresh();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> refresh() async {
    await fetchToday();
  }

  Future<void> fetchToday() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final userRow = await supabase
          .from('users')
          .select('relationship_id')
          .eq('id', userId)
          .maybeSingle();

      final relationshipId = userRow?['relationship_id'] as String?;
      if (relationshipId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      // ── Realtime Setup ─────────────────────────────────────────────────────
      if (_channel == null) {
        debugPrint('[DailyQuestionsNotifier] Setting up Realtime subscription...');
        _channel = supabase
            .channel('daily_answers_realtime')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'couple_daily_answers',
              callback: (payload) {
                debugPrint('[DailyQuestionsNotifier] Realtime event received: ${payload.eventType}');
                fetchToday();
              },
            )
            .subscribe((status, [error]) {
              debugPrint('[DailyQuestionsNotifier] Subscription status: $status');
              if (error != null) {
                debugPrint('[DailyQuestionsNotifier] Subscription error: $error');
              }
            });
      }

      // Format today local date (YYYY-MM-DD):
      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      // 1. Fetch score and streak
      final relRow = await supabase
          .from('relationships')
          .select('game_score, game_streak')
          .eq('id', relationshipId)
          .maybeSingle();
      
      final int gameScore = relRow?['game_score'] as int? ?? 0;
      final int gameStreak = relRow?['game_streak'] as int? ?? 0;

      // 2. Fetch or assign today's questions using RPC
      await supabase.rpc(
        'assign_daily_questions',
        params: {
          'p_relationship_id': relationshipId,
          'p_date': todayStr,
        },
      );

      // 3. Fetch History (including today)
      // We'll fetch all assigned questions for this couple
      final historyResponse = await supabase
          .from('couple_daily_questions')
          .select('id, question_id, assigned_date, daily_questions(question_text)')
          .eq('relationship_id', relationshipId)
          .order('assigned_date', ascending: false);

      final List<DailyQuestion> allQuestions = (historyResponse as List).map((r) {
        return DailyQuestion(
          coupleDailyQuestionId: r['id'] as String,
          questionId: r['question_id'] as String,
          questionText: (r['daily_questions'] as Map)['question_text'] as String,
          assignedDate: DateTime.parse(r['assigned_date'] as String),
        );
      }).toList();

      final questionIds = allQuestions.map((q) => q.coupleDailyQuestionId).toList();

      // 4. Fetch all answers for these questions
      List<DailyAnswer> answers = [];
      if (questionIds.isNotEmpty) {
        final answersResponse = await supabase
            .from('couple_daily_answers')
            .select('*')
            .inFilter('couple_daily_question_id', questionIds);

        answers = (answersResponse as List)
            .map((r) => DailyAnswer.fromRow(r as Map<String, dynamic>))
            .toList();
      }

      state = state.copyWith(
        questions: allQuestions, // Now contains everything
        answers: answers,
        gameScore: gameScore,
        gameStreak: gameStreak,
        isLoading: false,
      );

    } catch (e) {
      debugPrint('[DailyQuestionsNotifier.fetchToday] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> submitAnswer(String coupleDailyQuestionId, String answerText) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase.from('couple_daily_answers').insert({
        'couple_daily_question_id': coupleDailyQuestionId,
        'user_id': user.id,
        'answer': answerText.trim(),
      });

      // Trigger partner notification via Edge Function
      final identifier = user.email ?? user.phone;
      if (identifier != null) {
        supabase.functions.invoke(
          'notify_partner',
          body: {
            'identifier': identifier,
            'type': 'daily_question_answer',
          },
        ).ignore();
      }

      // Refresh to update local state
      await fetchToday();
      return true;
    } catch (e) {
      debugPrint('[DailyQuestionsNotifier.submitAnswer] Error: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> submitReview(String answerId, String reviewStatus, String comment) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      
      final userRow = await supabase
          .from('users')
          .select('relationship_id')
          .eq('id', userId)
          .maybeSingle();

      final relationshipId = userRow?['relationship_id'] as String?;
      if (relationshipId == null) throw Exception('No relationship');

      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      await supabase.rpc('submit_partner_review', params: {
        'p_answer_id': answerId,
        'p_relationship_id': relationshipId,
        'p_review_status': reviewStatus,
        'p_review_comment': comment.trim(),
        'p_local_date': todayStr,
      });

      // Refresh to get new score and review statuses
      await fetchToday();
      return true;
    } catch (e) {
      debugPrint('[DailyQuestionsNotifier.submitReview] Error: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final dailyQuestionsProvider =
    StateNotifierProvider<DailyQuestionsNotifier, DailyQuestionsState>((ref) {
  return DailyQuestionsNotifier(ref);
});
