import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_theme.dart';
import '../../core/tts_service.dart';

// Dummy data structure for the list and details
class DreamMilestone {
  final String id;
  final String title;
  bool isCompleted;

  DreamMilestone({required this.id, required this.title, this.isCompleted = false});
}

class DreamModel {
  final String id;
  final String title;
  final String targetDate;
  final String icon;
  final String why;
  final List<DreamMilestone> milestones;

  DreamModel({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.icon,
    required this.why,
    required this.milestones,
  });

  double get progress {
    if (milestones.isEmpty) return 0;
    final comp = milestones.where((m) => m.isCompleted).length;
    return comp / milestones.length;
  }
}

// Dummy data for our dreams
final List<DreamModel> mockDreams = [
  DreamModel(
    id: 'dream_1',
    title: 'Build our dream home',
    targetDate: 'Dec 2028',
    icon: '🏠',
    why: 'A space of our own to grow our family and build lifelong memories, designed exactly how we imagined our sanctuary to be.',
    milestones: [
      DreamMilestone(id: 'm1', title: 'Save first 1 Lakh', isCompleted: true),
      DreamMilestone(id: 'm2', title: 'Talk to bank for loan options', isCompleted: true),
      DreamMilestone(id: 'm3', title: 'Explore areas & neighborhoods', isCompleted: false),
      DreamMilestone(id: 'm4', title: 'Finalize architect', isCompleted: false),
      DreamMilestone(id: 'm5', title: 'Start construction', isCompleted: false),
    ],
  ),
  DreamModel(
    id: 'dream_2',
    title: 'Europe Backpacking',
    targetDate: 'May 2027',
    icon: '✈️',
    why: 'To experience different cultures, taste the world, and go on a romantic adventure before settling down.',
    milestones: [
      DreamMilestone(id: 'm1', title: 'Create rough itinerary', isCompleted: true),
      DreamMilestone(id: 'm2', title: 'Open dedicated travel fund', isCompleted: true),
      DreamMilestone(id: 'm3', title: 'Book flights', isCompleted: false),
      DreamMilestone(id: 'm4', title: 'Apply for Schengen Visas', isCompleted: false),
    ],
  ),
];

class DreamDetailScreen extends ConsumerStatefulWidget {
  final String dreamId;

  const DreamDetailScreen({super.key, required this.dreamId});

  @override
  ConsumerState<DreamDetailScreen> createState() => _DreamDetailScreenState();
}

class _DreamDetailScreenState extends ConsumerState<DreamDetailScreen> {
  late DreamModel dream;

  @override
  void initState() {
    super.initState();
    // In a real app we'd fetch this from a provider or DB.
    dream = mockDreams.firstWhere((d) => d.id == widget.dreamId, orElse: () => mockDreams.first);
  }

  void _toggleMilestone(DreamMilestone milestone, bool? value) {
    if (value == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      milestone.isCompleted = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _DreamAppBar(title: dream.icon),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _DreamHeader(dream: dream),
                const SizedBox(height: 32),
                _TheWhySection(why: dream.why),
                const SizedBox(height: 32),
                _AINudgePlaceholder(),
                const SizedBox(height: 32),
                Text(
                  'The Roadmap',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ...dream.milestones.map((m) => _MilestoneTile(
                  milestone: m,
                  onChanged: (val) => _toggleMilestone(m, val),
                )),
                const SizedBox(height: 80),
              ]),
            ),
          )
        ],
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _DreamAppBar extends StatelessWidget {
  final String title;
  const _DreamAppBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: ZunoTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: ZunoTheme.primary, size: 18),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/us');
          }
        },
      ),
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _DreamHeader extends StatelessWidget {
  final DreamModel dream;

  const _DreamHeader({required this.dream});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dream.title,
          style: GoogleFonts.notoSerif(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: ZunoTheme.primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: ZunoTheme.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZunoTheme.tertiary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, 
                   size: 16, color: ZunoTheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'Target: ${dream.targetDate}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ZunoTheme.tertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ZunoTheme.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'EXPERIMENTAL',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ZunoTheme.secondary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Big Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: dream.progress,
            minHeight: 8,
            backgroundColor: ZunoTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(ZunoTheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(dream.progress * 100).toInt()}% completed',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ─── The Why Section ─────────────────────────────────────────────────────────

class _TheWhySection extends StatelessWidget {
  final String why;

  const _TheWhySection({required this.why});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZunoTheme.primaryFixed.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, 
                   color: ZunoTheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'The Why',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ZunoTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            why,
            style: GoogleFonts.notoSerif(
              fontSize: 16,
              height: 1.6,
              color: ZunoTheme.onSurface,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Nudge ────────────────────────────────────────────────────────────────

class _AINudgePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZunoTheme.secondary.withValues(alpha: 0.1),
            ZunoTheme.tertiary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZunoTheme.tertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZunoTheme.tertiary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, 
                        color: ZunoTheme.tertiary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zuno\'s Advice',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ZunoTheme.tertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Both of you have great energy today, maybe spend 10 minutes looking at house listings!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.4,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TtsButton(
                      text: 'Both of you have great energy today, maybe spend 10 minutes looking at house listings!',
                      color: ZunoTheme.tertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Milestone Tile ──────────────────────────────────────────────────────────

class _MilestoneTile extends StatelessWidget {
  final DreamMilestone milestone;
  final ValueChanged<bool?> onChanged;

  const _MilestoneTile({required this.milestone, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDone = milestone.isCompleted;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone 
            ? ZunoTheme.primaryFixed.withValues(alpha: 0.2)
            : ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone 
              ? ZunoTheme.primary.withValues(alpha: 0.2)
              : ZunoTheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: isDone ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(!isDone),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isDone,
                    onChanged: onChanged,
                    activeColor: ZunoTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    milestone.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                      color: isDone 
                          ? ZunoTheme.onSurface.withValues(alpha: 0.5) 
                          : ZunoTheme.onSurface,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: ZunoTheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _TtsButton extends ConsumerWidget {
  final String text;
  final Color color;

  const _TtsButton({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsProvider);
    final isSpeakingThis = ttsState.isSpeaking && ttsState.currentText == text;

    return GestureDetector(
      onTap: () => ref.read(ttsProvider.notifier).speak(text),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            isSpeakingThis ? Icons.stop_rounded : Icons.volume_up_rounded,
            key: ValueKey(isSpeakingThis),
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }
}
