import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_theme.dart';
import '../daily_questions_state.dart';
import 'daily_question_interactive_sheet.dart';

class DailyQuestionsHistory extends ConsumerWidget {
  const DailyQuestionsHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyQuestionsProvider);
    final history = state.questionsByDate;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Remove today from history as it's in the teaser card
    final historyDates = history.keys.where((d) => d != today).toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending by date

    if (historyDates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16, top: 8),
          child: Text(
            'QUESTION HISTORY',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: historyDates.length,
          itemBuilder: (ctx, index) {
            final date = historyDates[index];
            final questions = history[date]!;
            return _HistoryDayItem(date: date, questions: questions);
          },
        ),
      ],
    );
  }
}

class _HistoryDayItem extends ConsumerStatefulWidget {
  final String date;
  final List<DailyQuestion> questions;

  const _HistoryDayItem({required this.date, required this.questions});

  @override
  ConsumerState<_HistoryDayItem> createState() => _HistoryDayItemState();
}

class _HistoryDayItemState extends ConsumerState<_HistoryDayItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionsProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    // Logic to calculate progress could go here in the future
    // for now we just show total count of questions assigned that day.

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZunoTheme.outlineVariant.withOpacity(_isExpanded ? 0.3 : 0.1),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          onExpansionChanged: (val) => setState(() => _isExpanded = val),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ZunoTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_today_rounded, size: 18, color: ZunoTheme.secondary),
          ),
          title: Text(
            _formatFriendlyDate(widget.date),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: ZunoTheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${widget.questions.length} questions answered',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          children: [
            const Divider(indent: 20, endIndent: 20, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: widget.questions.map((q) {
                  final myAnswer = state.getUserAnswer(q.coupleDailyQuestionId, myId ?? '');
                  final partnerAnswer = state.getPartnerAnswer(q.coupleDailyQuestionId, myId ?? '');
                  
                  return _HistoryQuestionTile(
                    question: q,
                    myAnswer: myAnswer,
                    partnerAnswer: partnerAnswer,
                    onTap: () {
                       showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => DailyQuestionInteractionSheet(
                          date: widget.date,
                          initialPage: widget.questions.indexOf(q),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFriendlyDate(String dateStr) {
    final parts = dateStr.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    if (dateStr == yesterday.toIso8601String().split('T')[0]) {
      return 'Yesterday';
    }
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _HistoryQuestionTile extends StatelessWidget {
  final DailyQuestion question;
  final DailyAnswer? myAnswer;
  final DailyAnswer? partnerAnswer;
  final VoidCallback onTap;

  const _HistoryQuestionTile({
    required this.question,
    required this.myAnswer,
    required this.partnerAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String statusLabel = 'Incomplete';
    IconData statusIcon = Icons.pending_rounded;
    Color statusColor = ZunoTheme.outline;

    if (myAnswer != null && partnerAnswer != null) {
      if (partnerAnswer!.partnerReviewStatus != null) {
        statusLabel = 'Reviewed';
        statusIcon = Icons.check_circle_rounded;
        statusColor = Colors.green;
      } else {
        statusLabel = 'Awaiting Review';
        statusIcon = Icons.rate_review_rounded;
        statusColor = Colors.amber.shade700;
      }
    } else if (myAnswer != null || partnerAnswer != null) {
      statusLabel = 'Partial';
      statusIcon = Icons.hourglass_bottom_rounded;
      statusColor = ZunoTheme.primary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.questionText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerif(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ZunoTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ZunoTheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}
