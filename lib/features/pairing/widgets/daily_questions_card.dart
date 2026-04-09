import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_theme.dart';
import '../daily_questions_state.dart';

class DailyQuestionsWidget extends ConsumerStatefulWidget {
  const DailyQuestionsWidget({super.key});

  @override
  ConsumerState<DailyQuestionsWidget> createState() => _DailyQuestionsWidgetState();
}

class _DailyQuestionsWidgetState extends ConsumerState<DailyQuestionsWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionsProvider);

    if (state.isLoading && state.questions.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 200,
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: CircularProgressIndicator(color: ZunoTheme.primary),
        ),
      );
    }

    if (state.questions.isEmpty) {
      return const SizedBox.shrink();
    }

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

        // Questions Card
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page View for 3 questions
              SizedBox(
                height: 320, // Reduced from 380 to be more snug
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: state.questions.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (ctx, i) {
                    final question = state.questions[i];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), // Reduced bottom padding
                      child: _QuestionContent(
                        question: question,
                        state: state,
                      ),
                    );
                  },
                ),
              ),

              // Pagination dots
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(state.questions.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 12 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? ZunoTheme.primary : ZunoTheme.outlineVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              ),
            ],
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

// ── Inside Question ──────────────────────────────────────────────────────────

class _QuestionContent extends ConsumerStatefulWidget {
  final DailyQuestion question;
  final DailyQuestionsState state;

  const _QuestionContent({required this.question, required this.state});

  @override
  ConsumerState<_QuestionContent> createState() => _QuestionContentState();
}

class _QuestionContentState extends ConsumerState<_QuestionContent> {
  final _answerController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    if (_answerController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    await ref.read(dailyQuestionsProvider.notifier).submitAnswer(widget.question.coupleDailyQuestionId, _answerController.text);
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _submitReview(String answerId, String status) async {
    setState(() => _isSubmitting = true);
    await ref.read(dailyQuestionsProvider.notifier).submitReview(answerId, status, _commentController.text);
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final myAnswer = widget.state.getUserAnswer(widget.question.coupleDailyQuestionId, myId);
    final partnerAnswer = widget.state.getPartnerAnswer(widget.question.coupleDailyQuestionId, myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.question.questionText,
          style: GoogleFonts.notoSerif(
            fontSize: 19, // Slightly smaller
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20), // Reduced from 32

        // 1. None answered (I haven't)
        if (myAnswer == null) ...[
          TextField(
            controller: _answerController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              filled: true,
              fillColor: ZunoTheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZunoTheme.primary,
              foregroundColor: ZunoTheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: ZunoTheme.onPrimary, strokeWidth: 2))
                : Text('Submit Answer', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ] 
        // 2. I answered, partner hasn't
        else if (partnerAnswer == null) ...[
          _ReadOnlyBubble(text: myAnswer.answer, label: 'Your Answer'),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLow.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty_rounded, color: ZunoTheme.outline, size: 24),
                const SizedBox(height: 12),
                Text(
                  'Waiting for partner...',
                  style: GoogleFonts.plusJakartaSans(
                    color: ZunoTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ]
        // 3. Both answered
        else ...[
          _ReadOnlyBubble(text: myAnswer.answer, label: 'Your Answer'),
          const SizedBox(height: 16),
          _ReadOnlyBubble(text: partnerAnswer.answer, label: 'Partner\'s Answer', isPartner: true),
          
          const SizedBox(height: 32),

          // Needs my review
          if (partnerAnswer.partnerReviewStatus == null) ...[
            Text(
              'How did they do?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ZunoTheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Optional comment (e.g. I actually meant...)',
                filled: true,
                fillColor: ZunoTheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ReviewButton(icon: '💬', label: 'Let\'s talk', onTap: () => _submitReview(partnerAnswer.id, 'lets_talk'), color: Colors.orange.shade300, isSubmitting: _isSubmitting),
                const SizedBox(width: 6), // Reduced from 8
                _ReviewButton(icon: '🤔', label: 'Not exactly', onTap: () => _submitReview(partnerAnswer.id, 'not_exactly'), color: Colors.amber.shade400, isSubmitting: _isSubmitting),
                const SizedBox(width: 6), // Reduced from 8
                _ReviewButton(icon: '💚', label: 'Understood', onTap: () => _submitReview(partnerAnswer.id, 'understood'), color: Colors.green.shade400, isSubmitting: _isSubmitting),
              ],
            )
          ] else ...[
            // I have reviewed! 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getReviewColor(partnerAnswer.partnerReviewStatus!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getReviewColor(partnerAnswer.partnerReviewStatus!).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_getReviewEmoji(partnerAnswer.partnerReviewStatus!), style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You marked: ${_getReviewLabel(partnerAnswer.partnerReviewStatus!)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: _getReviewColor(
                                  partnerAnswer.partnerReviewStatus!)),
                        ),
                      ),
                    ],
                  ),
                  if (partnerAnswer.partnerReviewComment != null && partnerAnswer.partnerReviewComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${partnerAnswer.partnerReviewComment}"',
                      style: GoogleFonts.notoSerif(fontStyle: FontStyle.italic, color: ZunoTheme.onSurfaceVariant),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Maybe show partner's review on me if they did?
            if (myAnswer.partnerReviewStatus != null) ...[
               Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getReviewColor(myAnswer.partnerReviewStatus!).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_getReviewEmoji(myAnswer.partnerReviewStatus!), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Partner marked: ${_getReviewLabel(myAnswer.partnerReviewStatus!)}',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: ZunoTheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    if (myAnswer.partnerReviewComment != null && myAnswer.partnerReviewComment!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"${myAnswer.partnerReviewComment}"',
                        style: GoogleFonts.notoSerif(fontStyle: FontStyle.italic, color: ZunoTheme.onSurfaceVariant),
                      ),
                    ]
                  ],
                ),
              ),
            ] else ...[
              Text('Partner hasn\'t reviewed your answer yet.', 
                textAlign: TextAlign.center, 
                style: GoogleFonts.plusJakartaSans(color: ZunoTheme.outline, fontSize: 13)
              )
            ]
          ]
        ]
      ],
    );
  }

  String _getReviewEmoji(String status) {
    if (status == 'understood') return '💚';
    if (status == 'not_exactly') return '🤔';
    return '💬';
  }

  String _getReviewLabel(String status) {
    if (status == 'understood') return 'You understood me';
    if (status == 'not_exactly') return 'Not exactly';
    return 'Let\'s talk';
  }

  Color _getReviewColor(String status) {
    if (status == 'understood') return Colors.green;
    if (status == 'not_exactly') return Colors.amber.shade700;
    return Colors.orange.shade700;
  }
}

class _ReadOnlyBubble extends StatelessWidget {
  final String text;
  final String label;
  final bool isPartner;

  const _ReadOnlyBubble({required this.text, required this.label, this.isPartner = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isPartner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: ZunoTheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPartner ? ZunoTheme.primaryFixed.withOpacity(0.1) : ZunoTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: isPartner ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isPartner ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: Border.all(
              color: isPartner ? ZunoTheme.primaryFixedDim.withOpacity(0.3) : Colors.transparent,
            )
          ),
          child: Text(
            text,
            style: GoogleFonts.notoSerif(
              fontSize: 15,
              color: ZunoTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isSubmitting;

  const _ReviewButton({
    required this.icon, 
    required this.label, 
    required this.onTap, 
    required this.color,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: isSubmitting ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2), // Tighter padding
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)), // Slightly smaller icon
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, // Slightly smaller font
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.9).withRed(color.red ~/ 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
