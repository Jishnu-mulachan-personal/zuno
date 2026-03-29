import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import '../dashboard/dashboard_state.dart';
import 'you_state.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final logsAsync = ref.watch(userLogsProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: ZunoTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _YouAppBar(displayName: profile.displayName),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'No journal entries yet. Check in today!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                                ),
                              ),
                            ),
                          )
                        ];
                      }
                      return logs.map((log) => _TimelineCard(log: log)).toList();
                    },
                    loading: () => [
                      const Center(
                        child: CircularProgressIndicator(color: ZunoTheme.primary),
                      )
                    ],
                    error: (e, _) => [
                      Center(
                        child: Text(
                          'Error loading timeline: $e',
                          style: GoogleFonts.plusJakartaSans(color: ZunoTheme.error),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
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
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: ZunoTheme.primary, size: 18),
        onPressed: () => context.pop(),
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
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ZunoTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: ZunoTheme.primary.withOpacity(0.25),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.person_rounded,
              color: Colors.white, size: 42),
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

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      log.connectionFelt ? 'Felt connected' : 'Felt disconnected',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: log.connectionFelt ? ZunoTheme.tertiary : ZunoTheme.error,
                      ),
                    ),
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
              children: log.contextTags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              )).toList(),
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
                border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.1)),
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
