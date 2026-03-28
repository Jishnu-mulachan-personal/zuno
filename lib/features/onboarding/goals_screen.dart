import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';

// ── State ──────────────────────────────────────────────────────────────────

final goalsProvider = StateProvider<Set<String>>((_) => {});

// ── Screen ─────────────────────────────────────────────────────────────────

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  static const _goals = [
    _Goal('communication', 'forum', 'Improve communication', false),
    _Goal('moods', 'mood', 'Track moods', false),
    _Goal('pregnancy', 'child_care', 'Plan pregnancy', false),
    _Goal('patterns', 'insights', 'Understand patterns', false),
    _Goal('connected', 'favorite', 'Stay connected', true), // full-width
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(goalsProvider);
    final canContinue = selected.isNotEmpty;

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: Stack(
        children: [
          // Hearth glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.0, -0.7),
                  radius: 1.2,
                  colors: [
                    ZunoTheme.secondaryContainer.withOpacity(0.5),
                    ZunoTheme.surface,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: ZunoTheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'PERSONALIZATION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: ZunoTheme.onTertiary.withOpacity(0.0) == Colors.transparent
                                  ? const Color(0xFF004F4F)
                                  : const Color(0xFF004F4F),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Headline
                        Text(
                          'What are\nyour goals?',
                          style: GoogleFonts.notoSerif(
                            fontSize: 42,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: ZunoTheme.onSurface,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Select the areas you'd like to focus on. We'll tailor your experience to support your unique journey.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: ZunoTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Goal cards grid (2 col × 2 rows + 1 full)
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95,
                          children: _goals
                              .where((g) => !g.fullWidth)
                              .map((g) => _GoalCard(goal: g, selected: selected.contains(g.id)))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        // Full-width card
                        _GoalCard(
                          goal: _goals.last,
                          selected: selected.contains(_goals.last.id),
                          fullWidth: true,
                        ),
                        // Editorial accent
                        const SizedBox(height: 48),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 1,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    ZunoTheme.primary.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                'DESIGNED FOR YOUR PRIVACY. YOUR GOALS ARE KEPT SECURE WITH END-TO-END ENCRYPTION.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.8,
                                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                                  height: 1.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sticky footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [ZunoTheme.surface, ZunoTheme.surface.withOpacity(0)],
                ),
              ),
              child: Column(
                children: [
                  AnimatedOpacity(
                    opacity: canContinue ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: canContinue ? () => context.go('/onboarding/privacy') : null,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: ZunoTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: ZunoTheme.primary.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CONTINUE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'STEP 2 OF 4',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal Card ──────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  final _Goal goal;
  final bool selected;
  final bool fullWidth;

  const _GoalCard({required this.goal, required this.selected, this.fullWidth = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        final set = Set<String>.from(ref.read(goalsProvider));
        if (set.contains(goal.id)) {
          set.remove(goal.id);
        } else {
          set.add(goal.id);
        }
        ref.read(goalsProvider.notifier).state = set;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(fullWidth ? 20 : 20),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ZunoTheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.onSurface.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: fullWidth
            ? Row(
                children: [
                  _iconBadge(selected),
                  const SizedBox(width: 16),
                  Text(
                    goal.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _checkCircle(selected),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _iconBadge(selected),
                      const Spacer(),
                      _checkCircle(selected),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    goal.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _iconBadge(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: selected ? ZunoTheme.primary : ZunoTheme.primaryFixed.withOpacity(0.5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Icon(
        _iconData(goal.iconName),
        color: selected ? Colors.white : ZunoTheme.primary,
        size: 22,
      ),
    );
  }

  Widget _checkCircle(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? ZunoTheme.primary : Colors.transparent,
        border: Border.all(
          color: selected ? ZunoTheme.primary : ZunoTheme.outlineVariant,
          width: 2,
        ),
        shape: BoxShape.circle,
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }

  IconData _iconData(String name) {
    return switch (name) {
      'forum' => Icons.forum_outlined,
      'mood' => Icons.mood,
      'child_care' => Icons.child_care,
      'insights' => Icons.insights,
      'favorite' => Icons.favorite_border,
      _ => Icons.star_border,
    };
  }
}

class _Goal {
  final String id, iconName, label;
  final bool fullWidth;
  const _Goal(this.id, this.iconName, this.label, this.fullWidth);
}
