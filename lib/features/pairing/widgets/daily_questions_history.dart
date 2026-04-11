import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_theme.dart';
import '../daily_questions_state.dart';
import 'daily_question_interactive_sheet.dart';

class DailyQuestionsHistory extends ConsumerStatefulWidget {
  const DailyQuestionsHistory({super.key});

  @override
  ConsumerState<DailyQuestionsHistory> createState() => _DailyQuestionsHistoryState();
}

class _DailyQuestionsHistoryState extends ConsumerState<DailyQuestionsHistory> {
  bool _isSectionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionsProvider);
    final questionsByDate = state.questionsByDate;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Remove today from history
    final historyDates = questionsByDate.keys.where((d) => d != today).toList()
      ..sort((a, b) => b.compareTo(a)); 

    if (historyDates.isEmpty && !state.hasMoreHistory) return const SizedBox.shrink();

    // Grouping by Month/Year
    final Map<String, List<String>> monthsMap = {};
    for (var date in historyDates) {
      final monthKey = _formatMonthYear(date);
      monthsMap.putIfAbsent(monthKey, () => []).add(date);
    }
    
    final sortedMonthKeys = monthsMap.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isSectionExpanded = !_isSectionExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 16, top: 40),
            child: Row(
              children: [
                Text(
                  'CHAT HISTORY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isSectionExpanded 
                      ? Icons.keyboard_arrow_up_rounded 
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
                const Spacer(),
                if (!_isSectionExpanded && sortedMonthKeys.isNotEmpty)
                  Text(
                    '${sortedMonthKeys.length} months',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        if (_isSectionExpanded) ...[
          if (state.isLoadingHistory && monthsMap.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedMonthKeys.length,
              itemBuilder: (ctx, index) {
                final monthKey = sortedMonthKeys[index];
                final datesInMonth = monthsMap[monthKey]!;
                return _MonthHistoryGroup(
                  monthLabel: monthKey,
                  dates: datesInMonth,
                  isInitiallyExpanded: index == 0, // Auto-expand latest month
                );
              },
            ),
            
          if (state.hasMoreHistory)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Center(
                child: TextButton(
                  onPressed: state.isLoadingMoreHistory 
                      ? null 
                      : () => ref.read(dailyQuestionsProvider.notifier).fetchHistoryMore(),
                  child: state.isLoadingMoreHistory
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Load Earlier Months',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ZunoTheme.primary,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _formatMonthYear(String dateStr) {
    final parts = dateStr.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _MonthHistoryGroup extends StatefulWidget {
  final String monthLabel;
  final List<String> dates;
  final bool isInitiallyExpanded;

  const _MonthHistoryGroup({
    required this.monthLabel,
    required this.dates,
    this.isInitiallyExpanded = false,
  });

  @override
  State<_MonthHistoryGroup> createState() => _MonthHistoryGroupState();
}

class _MonthHistoryGroupState extends State<_MonthHistoryGroup> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            child: Row(
              children: [
                Text(
                  widget.monthLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: ZunoTheme.outlineVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: ZunoTheme.outlineVariant.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (_isExpanded)
          Consumer(
            builder: (context, ref, _) {
              final history = ref.watch(dailyQuestionsProvider).questionsByDate;
              return Column(
                children: widget.dates.map((date) {
                  return _HistoryDayItem(
                    date: date,
                    questions: history[date] ?? [],
                  );
                }).toList(),
              );
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
  bool _isTileExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionsProvider);
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZunoTheme.outlineVariant.withOpacity(_isTileExpanded ? 0.3 : 0.1),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          onExpansionChanged: (val) => setState(() => _isTileExpanded = val),
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
            '${widget.questions.length} messages exchanged',
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

