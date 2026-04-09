import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_theme.dart';
import '../daily_questions_state.dart';
import 'daily_question_interactive_sheet.dart';

class DailyQuestionsWidget extends ConsumerWidget {
  const DailyQuestionsWidget({super.key});

  void _openInteraction(BuildContext context, String date, int initialPage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DailyQuestionInteractionSheet(
        date: date,
        initialPage: initialPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyQuestionsProvider);
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayQuestions = state.questionsByDate[today] ?? [];
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (state.isLoading && state.questions.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: CircularProgressIndicator(color: ZunoTheme.primary),
        ),
      );
    }

    if (todayQuestions.isEmpty) return const SizedBox.shrink();

    // Count progress for today
    int answeredCount = 0;
    if (myId != null) {
      for (var q in todayQuestions) {
        if (state.getUserAnswer(q.coupleDailyQuestionId, myId) != null) {
          answeredCount++;
        }
      }
    }

    final bool allAnswered = answeredCount == todayQuestions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Metrics Row Outside
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_rounded, color: ZunoTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Questions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: ZunoTheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _MetricBadge(icon: '🔥', value: '${state.gameStreak}'),
                  const SizedBox(width: 8),
                  _MetricBadge(icon: '✨', value: '${state.gameScore} pts'),
                ],
              ),
            ],
          ),
        ),

        // Questions Teaser Card
        GestureDetector(
          onTap: () => _openInteraction(context, today, 0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: allAnswered 
                ? LinearGradient(
                    colors: [ZunoTheme.primary.withOpacity(0.05), ZunoTheme.tertiary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
              color: allAnswered ? null : ZunoTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: allAnswered ? ZunoTheme.tertiary.withOpacity(0.2) : ZunoTheme.outlineVariant.withOpacity(0.2),
                width: allAnswered ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: allAnswered ? ZunoTheme.tertiary.withOpacity(0.1) : ZunoTheme.primaryFixed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    allAnswered ? Icons.check_circle_rounded : Icons.question_answer_rounded,
                    color: allAnswered ? ZunoTheme.tertiary : ZunoTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allAnswered ? 'Today\'s Questions Finished' : 'Answer Today\'s Questions',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        allAnswered 
                          ? 'Review your partner\'s answers!'
                          : '$answeredCount of ${todayQuestions.length} answered',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: ZunoTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ZunoTheme.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String icon;
  final String value;
  const _MetricBadge({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ZunoTheme.primaryFixed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ZunoTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
