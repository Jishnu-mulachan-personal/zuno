import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import 'you_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import '../../shared/widgets/profile_avatar.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme changes to trigger rebuild
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final logsAsync = ref.watch(userLogsProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: ZunoTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _YouAppBar(displayName: profile.displayName),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileHero(profile: profile),
                      const SizedBox(height: 32),
                      Text(
                        'YOUR TIMELINE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...logsAsync.when(
                        data: (logs) {
                          if (logs.isEmpty) {
                            return [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    'No journal entries yet. Check in today!',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: ZunoTheme.onSurfaceVariant
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              )
                            ];
                          }
                          return logs
                              .map((log) => _TimelineCard(log: log))
                              .toList();
                        },
                        loading: () => [
                          Center(
                            child: CircularProgressIndicator(
                                color: ZunoTheme.primary),
                          )
                        ],
                        error: (e, _) => [
                          Center(
                            child: Text(
                              'Error loading timeline: $e',
                              style: GoogleFonts.plusJakartaSans(
                                  color: ZunoTheme.error),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
              ],
            ),
            ZunoBottomNavBar(
              activeTab: ZunoTab.you,
              relationshipStatus: profile.relationshipStatus,
            ),
          ],
        ),
      ),
    );
  }
}

class _YouAppBar extends StatelessWidget {
  final String displayName;
  const _YouAppBar({required this.displayName});

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
            context.go('/dashboard');
          }
        },
      ),
      title: Text(
        'You',
        style: GoogleFonts.notoSerif(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ZunoTheme.primary,
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ZunoTheme.primary.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ProfileAvatar(
            url: profile.avatarUrl,
            radius: 44,
            name: profile.displayName,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.displayName,
          style: GoogleFonts.notoSerif(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department_rounded,
                size: 14, color: ZunoTheme.primary),
            const SizedBox(width: 4),
            Text(
              '${profile.streakDays}-day streak',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final DailyLog log;
  const _TimelineCard({required this.log});

  Map<String, String>? _parseReflection(String? note) {
    if (note == null) return null;
    final regex = RegExp(r'Answered Daily Question: "(.*)" -> "(.*)"');
    final match = regex.firstMatch(note);
    if (match != null && match.groupCount == 2) {
      return {
        'question': match.group(1) ?? '',
        'answer': match.group(2) ?? '',
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reflection = _parseReflection(log.journalNote);
    if (reflection != null) {
      return _QuestionReflectionCard(
        log: log,
        question: reflection['question']!,
        answer: reflection['answer']!,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                log.moodEmoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.date} at ${log.createdTime}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ],
          ),
          if (log.contextTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: log.contextTags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: ZunoTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ZunoTheme.onSurfaceVariant,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (log.journalNote != null && log.journalNote!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZunoTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: ZunoTheme.onSurface.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '"${log.journalNote!}"',
                style: GoogleFonts.notoSerif(
                  fontSize: 15,
                  color: ZunoTheme.onSurface,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionReflectionCard extends StatelessWidget {
  final DailyLog log;
  final String question;
  final String answer;

  const _QuestionReflectionCard({
    required this.log,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withOpacity(0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and date
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ZunoTheme.tertiary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: ZunoTheme.tertiary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY REFLECTION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: ZunoTheme.tertiary,
                      ),
                    ),
                    Text(
                      '${log.date} at ${log.createdTime}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(log.moodEmoji, style: const TextStyle(fontSize: 24)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Question text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              question,
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ZunoTheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Answer bubble
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ZunoTheme.tertiary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ZunoTheme.tertiary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR ANSWER',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  answer,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ZunoTheme.tertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

