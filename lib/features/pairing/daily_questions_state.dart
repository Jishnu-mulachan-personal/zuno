import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class DailyQuestion {
  final String coupleDailyQuestionId;
  final String questionId;
  final String questionText;
  final Map<String, String>? translations;
  final DateTime assignedDate;

  const DailyQuestion({
    required this.coupleDailyQuestionId,
    required this.questionId,
    required this.questionText,
    this.translations,
    required this.assignedDate,
  });

  factory DailyQuestion.fromRow(Map<String, dynamic> row) {
    return DailyQuestion(
      coupleDailyQuestionId: row['couple_daily_question_id'] as String,
      questionId: row['question_id'] as String,
      questionText: row['question_text'] as String,
      translations: row['translations'] != null ? Map<String, String>.from(row['translations'] as Map) : null,
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
  final String preferredLanguage;
  final bool isLoading;
  final bool isLoadingHistory;
  final bool isLoadingMoreHistory; // NEW
  final bool hasMoreHistory; // NEW
  final String? error;

  const DailyQuestionsState({
    this.questions = const [],
    this.answers = const [],
    this.gameScore = 0,
    this.gameStreak = 0,
    this.preferredLanguage = 'English',
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.isLoadingMoreHistory = false,
    this.hasMoreHistory = true,
    this.error,
  });

  DailyQuestionsState copyWith({
    List<DailyQuestion>? questions,
    List<DailyAnswer>? answers,
    int? gameScore,
    int? gameStreak,
    String? preferredLanguage,
    bool? isLoading,
    bool? isLoadingHistory,
    bool? isLoadingMoreHistory,
    bool? hasMoreHistory,
    String? error,
    bool clearError = false,
  }) {
    return DailyQuestionsState(
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      gameScore: gameScore ?? this.gameScore,
      gameStreak: gameStreak ?? this.gameStreak,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isLoading: isLoading ?? this.isLoading,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isLoadingMoreHistory: isLoadingMoreHistory ?? this.isLoadingMoreHistory,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
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
    _init();
  }

  void _init() async {
    await fetchToday();
    await fetchHistoryInitial();
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

      // 1.5. Fetch preferred language
      final langRow = await supabase
          .from('user_settings')
          .select('preferred_language')
          .eq('user_id', userId)
          .maybeSingle();
      final preferredLanguage = langRow?['preferred_language'] as String? ?? 'English';

      // 2. Fetch or assign today's questions using RPC
      await supabase.rpc(
        'assign_daily_questions',
        params: {
          'p_relationship_id': relationshipId,
          'p_date': todayStr,
        },
      );

      // 3. Fetch ONLY TODAY's pairs (question + answer)
      // This keeps the "Today" card accurate without loading all history
      final todayResponse = await supabase
          .from('couple_daily_questions')
          .select('id, question_id, assigned_date, daily_questions(question_text, translations)')
          .eq('relationship_id', relationshipId)
          .eq('assigned_date', todayStr);

      final List<DailyQuestion> todayQuestions = (todayResponse as List).map((r) {
        return DailyQuestion(
          coupleDailyQuestionId: r['id'] as String,
          questionId: r['question_id'] as String,
          questionText: (r['daily_questions'] as Map)['question_text'] as String,
          translations: (r['daily_questions'] as Map)['translations'] != null 
              ? Map<String, String>.from((r['daily_questions'] as Map)['translations'] as Map)
              : null,
          assignedDate: DateTime.parse(r['assigned_date'] as String),
        );
      }).toList();

      final todayQuestionIds = todayQuestions.map((q) => q.coupleDailyQuestionId).toList();

      // 4. Fetch answers for today only
      List<DailyAnswer> todayAnswers = [];
      if (todayQuestionIds.isNotEmpty) {
        final answersResponse = await supabase
            .from('couple_daily_answers')
            .select('*')
            .inFilter('couple_daily_question_id', todayQuestionIds);

        todayAnswers = (answersResponse as List)
            .map((r) => DailyAnswer.fromRow(r as Map<String, dynamic>))
            .toList();
      }

      // Merge with existing state (to preserve previously loaded history)
      final Set<String> newIds = todayQuestions.map((q) => q.coupleDailyQuestionId).toSet();
      final List<DailyQuestion> updatedQuestions = [
        ...todayQuestions,
        ...state.questions.where((q) => !newIds.contains(q.coupleDailyQuestionId)),
      ];
      
      final Set<String> newAnswerIds = todayAnswers.map((a) => a.id).toSet();
      final List<DailyAnswer> updatedAnswers = [
        ...todayAnswers,
        ...state.answers.where((a) => !newAnswerIds.contains(a.id)),
      ];

      state = state.copyWith(
        questions: updatedQuestions,
        answers: updatedAnswers,
        gameScore: gameScore,
        gameStreak: gameStreak,
        preferredLanguage: preferredLanguage,
        isLoading: false,
      );

    } catch (e) {
      debugPrint('[DailyQuestionsNotifier.fetchToday] Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchHistoryInitial() async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    final questions = await _fetchHistoryPage();
    if (questions == null) return;

    final questionIds = questions.map((q) => q.coupleDailyQuestionId).toList();
    List<DailyAnswer> answers = [];
    if (questionIds.isNotEmpty) {
      final supabase = Supabase.instance.client;
      final answersResponse = await supabase
          .from('couple_daily_answers')
          .select('*')
          .inFilter('couple_daily_question_id', questionIds);

      answers = (answersResponse as List)
          .map((r) => DailyAnswer.fromRow(r as Map<String, dynamic>))
          .toList();
    }

    // Merge with existing (mostly just today's questions)
    final Set<String> existingIds = state.questions.map((q) => q.coupleDailyQuestionId).toSet();
    final Set<String> existingAnswerIds = state.answers.map((a) => a.id).toSet();

    state = state.copyWith(
      questions: [...state.questions, ...questions.where((q) => !existingIds.contains(q.coupleDailyQuestionId))],
      answers: [...state.answers, ...answers.where((a) => !existingAnswerIds.contains(a.id))],
      isLoadingHistory: false,
      hasMoreHistory: questions.length >= 15,
    );
  }

  Future<void> fetchHistoryMore() async {
    if (state.isLoadingMoreHistory || !state.hasMoreHistory || state.questions.isEmpty) return;

    state = state.copyWith(isLoadingMoreHistory: true);
    
    // Find the earliest date currently loaded in history (excluding today)
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final historyOnly = state.questions.where((q) => q.assignedDate.toIso8601String().split('T')[0] != todayStr).toList();
    
    DateTime? lastDate;
    if (historyOnly.isNotEmpty) {
      historyOnly.sort((a, b) => a.assignedDate.compareTo(b.assignedDate));
      lastDate = historyOnly.first.assignedDate;
    }

    final questions = await _fetchHistoryPage(beforeDate: lastDate);
    if (questions == null) {
      state = state.copyWith(isLoadingMoreHistory: false);
      return;
    }

    final questionIds = questions.map((q) => q.coupleDailyQuestionId).toList();
    List<DailyAnswer> answers = [];
    if (questionIds.isNotEmpty) {
      final supabase = Supabase.instance.client;
      final answersResponse = await supabase
          .from('couple_daily_answers')
          .select('*')
          .inFilter('couple_daily_question_id', questionIds);

      answers = (answersResponse as List)
          .map((r) => DailyAnswer.fromRow(r as Map<String, dynamic>))
          .toList();
    }

    state = state.copyWith(
      questions: [...state.questions, ...questions],
      answers: [...state.answers, ...answers],
      isLoadingMoreHistory: false,
      hasMoreHistory: questions.length >= 15,
    );
  }

  Future<List<DailyQuestion>?> _fetchHistoryPage({DateTime? beforeDate}) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final userRow = await supabase
          .from('users')
          .select('relationship_id')
          .eq('id', userId)
          .maybeSingle();

      final relationshipId = userRow?['relationship_id'] as String?;
      if (relationshipId == null) return [];

      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      var query = supabase
          .from('couple_daily_questions')
          .select('id, question_id, assigned_date, daily_questions(question_text, translations)')
          .eq('relationship_id', relationshipId)
          .neq('assigned_date', todayStr); // Exclude today as it's fetched separately

      if (beforeDate != null) {
        query = query.lt('assigned_date', beforeDate.toIso8601String().split('T')[0]);
      }

      final response = await query
          .order('assigned_date', ascending: false)
          .limit(15);

      return (response as List).map((r) {
        return DailyQuestion(
          coupleDailyQuestionId: r['id'] as String,
          questionId: r['question_id'] as String,
          questionText: (r['daily_questions'] as Map)['question_text'] as String,
          translations: (r['daily_questions'] as Map)['translations'] != null 
              ? Map<String, String>.from((r['daily_questions'] as Map)['translations'] as Map)
              : null,
          assignedDate: DateTime.parse(r['assigned_date'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('[DailyQuestionsNotifier._fetchHistoryPage] Error: $e');
      return null;
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
