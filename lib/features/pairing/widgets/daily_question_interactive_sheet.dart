import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app_theme.dart';
import '../../../shared/widgets/profile_avatar.dart';
import '../daily_questions_state.dart';
import '../../dashboard/dashboard_state.dart';

/// A full-screen ModalBottomSheet that allows users to answer and review questions in a chat-style UI.
class DailyQuestionInteractionSheet extends ConsumerStatefulWidget {
  final String date; // YYYY-MM-DD
  final int initialPage;

  const DailyQuestionInteractionSheet({
    super.key,
    required this.date,
    this.initialPage = 0,
  });

  @override
  ConsumerState<DailyQuestionInteractionSheet> createState() => _DailyQuestionInteractionSheetState();
}

class _DailyQuestionInteractionSheetState extends ConsumerState<DailyQuestionInteractionSheet> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyQuestionsProvider);
    final questions = state.questionsByDate[widget.date] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: ZunoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ZunoTheme.outlineVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateLabel(widget.date),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ZunoTheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Daily Chat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ZunoTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: ZunoTheme.onSurfaceVariant, size: 28),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Pager
          Expanded(
            child: questions.isEmpty
                ? Center(child: Text('No questions found.'))
                : PageView.builder(
                    controller: _pageController,
                    itemCount: questions.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (ctx, i) {
                      return _QuestionThread(
                        question: questions[i],
                        state: state,
                      );
                    },
                  ),
          ),

          // Footer Navigation
          if (questions.isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: ZunoTheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(questions.length, (i) {
                      final isComplete = _isDayComplete(questions[i], state);
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i 
                                ? ZunoTheme.primary 
                                : (isComplete ? ZunoTheme.primary.withOpacity(0.3) : ZunoTheme.outlineVariant.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  // Progress Text
                  Text(
                    'Topic ${_currentPage + 1} of ${questions.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ZunoTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isDayComplete(DailyQuestion q, DailyQuestionsState state) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return false;
    final myAnswer = state.getUserAnswer(q.coupleDailyQuestionId, myId);
    final partnerAnswer = state.getPartnerAnswer(q.coupleDailyQuestionId, myId);
    return myAnswer != null && partnerAnswer != null && partnerAnswer.partnerReviewStatus != null;
  }

  String _formatDateLabel(String dateStr) {
    if (dateStr == DateTime.now().toIso8601String().split('T')[0]) {
      return 'TODAY';
    }
    final parts = dateStr.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Question Thread (The Chat View) ──────────────────────────────────────────

class _QuestionThread extends ConsumerStatefulWidget {
  final DailyQuestion question;
  final DailyQuestionsState state;

  const _QuestionThread({required this.question, required this.state});

  @override
  ConsumerState<_QuestionThread> createState() => _QuestionThreadState();
}

class _QuestionThreadState extends ConsumerState<_QuestionThread> {
  final _answerController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _showTranslation = false;

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
    if (mounted) {
      setState(() => _isSubmitting = false);
      _answerController.clear();
    }
  }

  Future<void> _submitReview(String answerId, String status) async {
    setState(() => _isSubmitting = true);
    await ref.read(dailyQuestionsProvider.notifier).submitReview(answerId, status, _commentController.text);
    if (mounted) {
      setState(() => _isSubmitting = false);
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final myAnswer = widget.state.getUserAnswer(widget.question.coupleDailyQuestionId, myId);
    final partnerAnswer = widget.state.getPartnerAnswer(widget.question.coupleDailyQuestionId, myId);
    final profile = ref.watch(userProfileProvider).value;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // 1. The Question (Partner asking)
              _ChatBubble(
                text: (_showTranslation && widget.question.translations?[widget.state.preferredLanguage] != null)
                    ? widget.question.translations![widget.state.preferredLanguage]!
                    : widget.question.questionText,
                isMe: false,
                isQuestion: true,
                partnerName: profile?.partnerName ?? 'Partner',
                partnerAvatar: profile?.partnerAvatarUrl,
                showTranslateButton: widget.question.translations?[widget.state.preferredLanguage] != null,
                isTranslated: _showTranslation,
                onTranslate: () => setState(() => _showTranslation = !_showTranslation),
                preferredLanguage: widget.state.preferredLanguage,
              ),
              const SizedBox(height: 24),

              // 2. My Answer (Right)
              if (myAnswer != null)
                _ChatBubble(
                  text: myAnswer.answer,
                  isMe: true,
                  timestamp: myAnswer.createdAt,
                  userAvatar: profile?.avatarUrl,
                  userName: profile?.displayName,
                ),

              // 3. Partner Answer (Left)
              if (partnerAnswer != null && myAnswer != null)
                _ChatBubble(
                  text: partnerAnswer.answer,
                  isMe: false,
                  timestamp: partnerAnswer.createdAt,
                  partnerName: profile?.partnerName ?? 'Partner',
                  partnerAvatar: profile?.partnerAvatarUrl,
                )
              else if (partnerAnswer != null && myAnswer == null)
                _SystemStatus(
                  icon: Icons.lock_rounded,
                  text: '${profile?.partnerName ?? "Partner"} has answered! Submit your answer to see theirs.',
                ),

              // 4. Waiting/Review Interaction
              if (myAnswer != null && partnerAnswer == null)
                _SystemStatus(
                  icon: Icons.hourglass_empty_rounded,
                  text: 'Waiting for ${profile?.partnerName ?? "partner"} to answer...',
                ),

              if (partnerAnswer != null && partnerAnswer.partnerReviewStatus != null)
                 _ChatBubble(
                  text: 'I marked this as: ${_getReviewLabel(partnerAnswer.partnerReviewStatus!)}${partnerAnswer.partnerReviewComment != null && partnerAnswer.partnerReviewComment!.isNotEmpty ? "\n\n${partnerAnswer.partnerReviewComment}" : ""}',
                  isMe: true,
                  isSystem: true,
                  emoji: _getReviewEmoji(partnerAnswer.partnerReviewStatus!),
                  color: _getReviewColor(partnerAnswer.partnerReviewStatus!),
                  userAvatar: profile?.avatarUrl,
                  userName: profile?.displayName,
                ),

              if (myAnswer != null && myAnswer.partnerReviewStatus != null)
                _ChatBubble(
                  text: '${profile?.partnerName ?? "Partner"} marked this as: ${_getReviewLabel(myAnswer.partnerReviewStatus!)}${myAnswer.partnerReviewComment != null && myAnswer.partnerReviewComment!.isNotEmpty ? "\n\n${myAnswer.partnerReviewComment}" : ""}',
                  isMe: false,
                  isSystem: true,
                  partnerName: profile?.partnerName,
                  partnerAvatar: profile?.partnerAvatarUrl,
                  emoji: _getReviewEmoji(myAnswer.partnerReviewStatus!),
                  color: _getReviewColor(myAnswer.partnerReviewStatus!),
                ),

              // 5. Review Action (If both answered but I haven't reviewed)
              if (myAnswer != null && partnerAnswer != null && partnerAnswer.partnerReviewStatus == null) ...[
                const SizedBox(height: 24),
                _ReviewActionView(
                  partnerAnswerId: partnerAnswer.id,
                  partnerName: profile?.partnerName ?? 'Partner',
                  commentController: _commentController,
                  isSubmitting: _isSubmitting,
                  onReview: _submitReview,
                ),
              ],
            ],
          ),
        ),

        // 6. Input Bar (If I haven't answered)
        if (myAnswer == null)
          _ChatInputBar(
            controller: _answerController,
            isSubmitting: _isSubmitting,
            onSend: _submitAnswer,
          ),
      ],
    );
  }

  String _getReviewEmoji(String status) {
    if (status == 'understood') return '💚';
    if (status == 'not_exactly') return '🤔';
    return '💬';
  }

  String _getReviewLabel(String status) {
    if (status == 'understood') return 'Understood';
    if (status == 'not_exactly') return 'Not exactly';
    return 'Let\'s talk';
  }

  Color _getReviewColor(String status) {
    if (status == 'understood') return Colors.green.shade600;
    if (status == 'not_exactly') return Colors.amber.shade800;
    return Colors.orange.shade800;
  }
}

// ── Chat Bubble Widget ──────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool isSystem;
  final bool isQuestion;
  final DateTime? timestamp;
  final String? partnerName;
  final String? partnerAvatar;
  final String? userAvatar; // NEW
  final String? userName; // NEW
  final String? emoji;
  final Color? color;
  final VoidCallback? onTranslate;
  final bool showTranslateButton;
  final bool isTranslated;
  final String? preferredLanguage;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    this.isSystem = false,
    this.isQuestion = false,
    this.timestamp,
    this.partnerName,
    this.partnerAvatar,
    this.userAvatar,
    this.userName,
    this.emoji,
    this.color,
    this.onTranslate,
    this.showTranslateButton = false,
    this.isTranslated = false,
    this.preferredLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            ProfileAvatar(url: partnerAvatar, radius: 18, name: partnerName ?? 'P'),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe 
                    ? (isSystem ? (color?.withOpacity(0.1) ?? ZunoTheme.primaryFixed) : ZunoTheme.primary)
                    : (isSystem ? (color?.withOpacity(0.1) ?? ZunoTheme.surfaceContainerHigh) : ZunoTheme.surfaceContainerHigh),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                  bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
                border: isSystem ? Border.all(color: color?.withOpacity(0.3) ?? Colors.transparent) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (emoji != null) ...[
                    Text(emoji!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isQuestion ? 16 : 15,
                      fontWeight: isQuestion ? FontWeight.bold : FontWeight.w500,
                      height: 1.4,
                      color: isMe 
                        ? (isSystem ? (color ?? ZunoTheme.primary) : ZunoTheme.onPrimary)
                        : (isSystem ? (color ?? ZunoTheme.onSurface) : ZunoTheme.onSurface),
                    ),
                  ),
                  if (showTranslateButton) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onTranslate,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 14,
                            color: ZunoTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTranslated ? 'Show Original' : 'Translate',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ZunoTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            ProfileAvatar(url: userAvatar, radius: 18, name: userName ?? 'M'),
          ],
        ],
      ),
    );
  }
}

// ── Chat Input Bar ───────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.isSubmitting,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: ZunoTheme.surface,
        border: Border(top: BorderSide(color: ZunoTheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: GoogleFonts.plusJakartaSans(color: ZunoTheme.outline),
                fillColor: ZunoTheme.surfaceContainerLow,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isSubmitting ? null : onSend,
            style: IconButton.styleFrom(backgroundColor: ZunoTheme.primary, foregroundColor: ZunoTheme.onPrimary),
            icon: isSubmitting 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

// ── Review View ──────────────────────────────────────────────────────────────

class _ReviewActionView extends StatelessWidget {
  final String partnerAnswerId;
  final String partnerName;
  final TextEditingController commentController;
  final bool isSubmitting;
  final Function(String, String) onReview;

  const _ReviewActionView({
    required this.partnerAnswerId,
    required this.partnerName,
    required this.commentController,
    required this.isSubmitting,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'How did $partnerName do?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: ZunoTheme.onSurface),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: commentController,
          decoration: InputDecoration(
            hintText: 'Add an optional comment...',
            fillColor: ZunoTheme.surfaceContainerLow,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ReviewChip(icon: '💬', label: 'Let\'s talk', color: Colors.orange.shade400, onTap: () => onReview(partnerAnswerId, 'lets_talk')),
            const SizedBox(width: 8),
            _ReviewChip(icon: '🤔', label: 'Not exactly', color: Colors.amber.shade400, onTap: () => onReview(partnerAnswerId, 'not_exactly')),
            const SizedBox(width: 8),
            _ReviewChip(icon: '💚', label: 'Understood', color: Colors.green.shade400, onTap: () => onReview(partnerAnswerId, 'understood')),
          ],
        ),
      ],
    );
  }
}

class _ReviewChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReviewChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: color.withRed(color.red ~/ 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemStatus extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SystemStatus({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: ZunoTheme.outline, size: 24),
          const SizedBox(height: 8),
          Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ZunoTheme.outline, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
