import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'personal_image_service.dart';
import 'us_state.dart'; // For SharedPost model and related logic
import 'you_state.dart';
import '../settings/profile_image_service.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/zuno_image.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(userPostsProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: ZunoTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => ref.read(userPostsProvider.notifier).refresh(),
                color: ZunoTheme.primary,
                backgroundColor: ZunoTheme.surface,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  slivers: [
                    _YouAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
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
                        ]),
                      ),
                    ),
                    _UserFeed(currentUserId: profile.id),
                    const SliverToBoxAdapter(child: SizedBox(height: 160)),
                  ],
                ),
              ),
              ZunoBottomNavBar(
                activeTab: ZunoTab.you,
                relationshipStatus: profile.relationshipStatus,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 80, // above bottom nav
                child: _UserComposeBar(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _YouAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(timelineFilterProvider);

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
      actions: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(timelineFilterProvider.notifier).state =
                filter == TimelineFilter.all
                    ? TimelineFilter.reflectionsOnly
                    : TimelineFilter.all;
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: filter == TimelineFilter.reflectionsOnly
                  ? ZunoTheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filter == TimelineFilter.reflectionsOnly
                  ? Icons.auto_awesome_mosaic_rounded
                  : Icons.filter_list_rounded,
              color: ZunoTheme.primary,
              size: 20,
            ),
          ),
          tooltip: filter == TimelineFilter.reflectionsOnly
              ? 'Showing Reflections'
              : 'Filter Timeline',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─── Profile Hero ────────────────────────────────────────────────────────────

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

// ─── User Feed ───────────────────────────────────────────────────────────────

class _UserFeed extends ConsumerWidget {
  final String currentUserId;

  const _UserFeed({required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userPostsProvider);

    if (state.isLoading && state.posts.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            _SkeletonCard(),
            const SizedBox(height: 16),
            _SkeletonCard(),
          ]),
        ),
      );
    }

    if (state.error != null && state.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Text(
              'Could not load timeline:\n${state.error}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: ZunoTheme.error),
            ),
          ),
        ),
      );
    }

    // Filter posts if needed
    final filter = ref.watch(timelineFilterProvider);
    final posts = filter == TimelineFilter.all
        ? state.posts
        : state.posts.where((p) {
            final caption = p.caption;
            final isQA = (caption.startsWith('Q: ') && caption.contains('\nA: ')) ||
                caption.contains(' -> ') ||
                caption.contains('->');
            return !isQA;
          }).toList();

    if (posts.isEmpty && !state.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            children: [
              Icon(Icons.filter_list_off_rounded, 
                  size: 48, color: ZunoTheme.onSurfaceVariant.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                'No reflections found matching your filter',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group posts by Month/Year
    final Map<String, List<SharedPost>> groups = {};
    for (final p in posts) {
      final groupKey = _formatMonthYear(p.createdAt);
      groups.putIfAbsent(groupKey, () => []).add(p);
    }

    final groupKeys = groups.keys.toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final key = groupKeys[i];
              return _TimelineMonthGroup(
                title: key,
                posts: groups[key]!,
                currentUserId: currentUserId,
                isInitiallyExpanded: i == 0,
                isLastGroup: i == groupKeys.length - 1 && !state.hasMore,
              );
            },
            childCount: groupKeys.length,
          ),
        ),
        if (state.isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ZunoTheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final SharedPost post;
  final bool isOwn;

  const _PostCard({required this.post, required this.isOwn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (post.type == SharedPostType.dailyLog) {
      return _JournalCard(post: post, isOwn: isOwn);
    }

    return GestureDetector(
      onLongPress: isOwn ? () => _showPostOptions(context, ref) : null,
      child: Container(
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: ZunoTheme.outlineVariant.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.onSurface.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Subtle Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    relativeTime(post.createdAt).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  if (isOwn)
                    GestureDetector(
                      onTap: () => _showPostOptions(context, ref),
                      child: Icon(Icons.more_horiz_rounded,
                          color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.3),
                          size: 18),
                    ),
                ],
              ),
            ),

            // ── Image ───────────────────────────────────────────────────────
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 320,
                      minHeight: 180,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ZunoImage(
                        pathOrUrl: post.imageUrl!,
                        bucket: 'personal-posts',
                        borderRadius: 16,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Caption ─────────────────────────────────────────────────────
            if (post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  post.caption,
                  style: GoogleFonts.notoSerif(
                    fontSize: 15,
                    height: 1.6,
                    color: ZunoTheme.onSurface.withValues(alpha: 0.9),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // ── Context tags ────────────────────────────────────────────────
            if (post.contextTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: post.contextTags
                      .map((tag) => _TagChip(label: tag, small: true))
                      .toList(),
                ),
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostOptionsSheet(post: post),
    );
  }
}

// ─── Journal Card ─────────────────────────────────────────────────────────────

class _JournalCard extends ConsumerWidget {
  final SharedPost post;
  final bool isOwn;

  const _JournalCard({required this.post, required this.isOwn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = post.caption;
    
    bool isQA = false;
    String question = '';
    String answer = '';

    // Parsing logic: support both old 'Q: \nA: ' and new '->' formats
    if (caption.startsWith('Q: ') && caption.contains('\nA: ')) {
      isQA = true;
      final parts = caption.split('\nA: ');
      question = parts[0].substring(3);
      answer = parts.length > 1 ? parts[1] : '';
    } else if (caption.contains(' -> ')) {
      isQA = true;
      final parts = caption.split(' -> ');
      question = parts[0].trim();
      // Join remaining parts in case there are multiple '->'
      answer = parts.sublist(1).join(' -> ').trim();
    } else if (caption.contains('->')) {
      // Handle cases without spaces around ->
      isQA = true;
      final parts = caption.split('->');
      question = parts[0].trim();
      answer = parts.sublist(1).join('->').trim();
    }

    return Container(
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: ZunoTheme.primary.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Subtle Background Gradient Accent
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZunoTheme.primary.withValues(alpha: 0.08),
                      ZunoTheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      _buildMoodOrIcon(isQA),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isQA ? 'JOURNAL Q&A' : 'DAILY REFLECTION',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                                color: ZunoTheme.primary.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              relativeTime(post.createdAt),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwn)
                        GestureDetector(
                          onTap: () => _showPostOptions(context, ref),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (isQA) ...[
                    // Clean Question presentation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        question,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: ZunoTheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Answer Section
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 2,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  ZunoTheme.secondary.withValues(alpha: 0.4),
                                  ZunoTheme.secondary.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'THE RESPONSE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: ZunoTheme.secondary.withValues(alpha: 0.7),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  answer,
                                  style: GoogleFonts.notoSerif(
                                    fontSize: 16,
                                    height: 1.7,
                                    fontStyle: FontStyle.italic,
                                    color: ZunoTheme.onSurface.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Standard Reflection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        post.caption,
                        style: GoogleFonts.notoSerif(
                          fontSize: 17,
                          color: ZunoTheme.onSurface.withValues(alpha: 0.85),
                          height: 1.75,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  
                  if (post.contextTags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.contextTags
                          .map((tag) => _TagChip(label: tag, small: true))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodOrIcon(bool isQA) {
    if (post.moodEmoji != null && !isQA) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ZunoTheme.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          post.moodEmoji!,
          style: const TextStyle(fontSize: 22),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZunoTheme.primary,
            ZunoTheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        isQA ? Icons.auto_awesome_rounded : Icons.format_quote_rounded,
        color: ZunoTheme.onPrimary,
        size: 20,
      ),
    );
  }

  void _showPostOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostOptionsSheet(post: post),
    );
  }
}


// ─── Post options sheet (edit / delete) ──────────────────────────────────────

class _PostOptionsSheet extends ConsumerWidget {
  final SharedPost post;

  const _PostOptionsSheet({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ZunoTheme.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _OptionTile(
            icon: Icons.edit_outlined,
            label: 'Edit post',
            color: ZunoTheme.primary,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _EditPostSheet(post: post),
              );
            },
          ),
          Divider(
              height: 1,
              color: ZunoTheme.outlineVariant.withValues(alpha: 0.15),
              indent: 56,
              endIndent: 16),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete post',
            color: ZunoTheme.error,
            onTap: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ZunoTheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text('Delete post?',
                      style: GoogleFonts.notoSerif(
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurface)),
                  content: Text(
                    'This moment will be removed from your timeline.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: ZunoTheme.onSurfaceVariant),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: GoogleFonts.plusJakartaSans(
                                color: ZunoTheme.onSurfaceVariant))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Delete',
                            style: GoogleFonts.plusJakartaSans(
                                color: ZunoTheme.error,
                                fontWeight: FontWeight.w700))),
                  ],
                ),
              );

              if (confirm == true) {
                navigator.pop();
                final success = await ref
                    .read(userPostNotifierProvider.notifier)
                    .deletePost(postId: post.id, imageUrl: post.imageUrl);

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Post deleted successfully'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: ZunoTheme.onSurface,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Post Sheet ──────────────────────────────────────────────────────────

class _EditPostSheet extends ConsumerStatefulWidget {
  final SharedPost post;
  const _EditPostSheet({required this.post});

  @override
  ConsumerState<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<_EditPostSheet> {
  late final TextEditingController _ctrl;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    final tagsText = widget.post.contextTags.join(' ');
    final raw =
        [widget.post.caption, tagsText].where((s) => s.isNotEmpty).join(' ');
    _ctrl = TextEditingController(text: raw);
    _tags = List<String>.from(widget.post.contextTags);
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    setState(() {
      _tags = extractHashtags(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(userPostNotifierProvider.notifier);
    final state = ref.watch(userPostNotifierProvider);
    final clean = stripHashtags(_ctrl.text);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ZunoTheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit post',
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              autofocus: true,
              style: GoogleFonts.notoSerif(
                fontSize: 15,
                color: ZunoTheme.onSurface,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Share a moment… #tag to add context',
                hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.4)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: ZunoTheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _tags.map((t) => _TagChip(label: t)).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color:
                              ZunoTheme.outlineVariant.withValues(alpha: 0.3)),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ZunoTheme.onSurfaceVariant)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            final ok = await notifier.editPost(
                              postId: widget.post.id,
                              newCaption: clean,
                              newTags: _tags,
                            );
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZunoTheme.primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Save',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── User Compose Bar ─────────────────────────────────────────────────────────

class _UserComposeBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_UserComposeBar> createState() => _UserComposeBarState();
}

class _UserComposeBarState extends ConsumerState<_UserComposeBar> {
  final _ctrl = TextEditingController();
  File? _pickedImage;
  List<String> _tags = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() => _tags = extractHashtags(_ctrl.text));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _showImagePicker(BuildContext context) async {
    final state = ref.read(userPostNotifierProvider);
    if (state.isSubmitting) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ZunoTheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              color: ZunoTheme.primary,
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            Divider(
              height: 1,
              color: ZunoTheme.outlineVariant.withValues(alpha: 0.15),
              indent: 56,
              endIndent: 16,
            ),
            _OptionTile(
              icon: Icons.image_outlined,
              label: 'Choose from Gallery',
              color: ZunoTheme.primary,
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source);
    if (xFile != null) {
      setState(() => _pickedImage = File(xFile.path));
    }
  }

  Future<void> _submit() async {
    final notifier = ref.read(userPostNotifierProvider.notifier);
    final caption = stripHashtags(_ctrl.text);

    final ok = await notifier.submitPost(
      caption: caption,
      imageFile: _pickedImage,
      contextTags: _tags,
    );

    if (ok) {
      _ctrl.clear();
      setState(() {
        _pickedImage = null;
        _tags = [];
        _isExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 24),
          child: FloatingActionButton(
            heroTag: 'you_compose_fab',
            onPressed: () => setState(() => _isExpanded = true),
            backgroundColor: ZunoTheme.primary,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      );
    }

    final state = ref.watch(userPostNotifierProvider);
    final hasContent = _ctrl.text.trim().isNotEmpty || _pickedImage != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: ZunoTheme.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personal Moment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ZunoTheme.primary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  setState(() {
                    _pickedImage = null;
                    _tags = [];
                    _isExpanded = false;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.close_rounded, size: 20, color: ZunoTheme.outlineVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_pickedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    _pickedImage!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _pickedImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          if (_pickedImage != null) const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: state.isSubmitting ? null : () => _showImagePicker(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: ZunoTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    size: 18,
                    color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  minLines: 1,
                  enabled: !state.isSubmitting,
                  style: GoogleFonts.notoSerif(
                    fontSize: 14,
                    color: ZunoTheme.onSurface,
                    fontStyle: FontStyle.italic,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share a personal moment…',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color:
                            ZunoTheme.onSurfaceVariant.withValues(alpha: 0.35)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedOpacity(
                opacity: hasContent ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: (hasContent && !state.isSubmitting) ? _submit : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: ZunoTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: state.isSubmitting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),

          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  _tags.map((t) => _TagChip(label: t, small: true)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tag Chip ─────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final bool small;
  const _TagChip({required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: ZunoTheme.primaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: ZunoTheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: ZunoTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: ZunoTheme.outlineVariant.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text('🌿', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              'Your personal timeline.',
              style: GoogleFonts.notoSerif(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Moments and logs shared only with yourself will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton Card ────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          height: 130,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ZunoTheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 100,
                          height: 12,
                          decoration: BoxDecoration(
                            color: ZunoTheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          )),
                      const SizedBox(height: 6),
                      Container(
                          width: 60,
                          height: 10,
                          decoration: BoxDecoration(
                            color: ZunoTheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 180,
                height: 12,
                decoration: BoxDecoration(
                  color: ZunoTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Timeline Feed Utilities / Widgets ───────────────────────────────────────

String _formatMonthYear(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

class _TimelineMonthGroup extends StatefulWidget {
  final String title;
  final List<SharedPost> posts;
  final String currentUserId;
  final bool isInitiallyExpanded;
  final bool isLastGroup;

  const _TimelineMonthGroup({
    required this.title,
    required this.posts,
    required this.currentUserId,
    this.isInitiallyExpanded = false,
    this.isLastGroup = false,
  });

  @override
  State<_TimelineMonthGroup> createState() => _TimelineMonthGroupState();
}

class _TimelineMonthGroupState extends State<_TimelineMonthGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ZunoTheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: ZunoTheme.outlineVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: ZunoTheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: widget.isLastGroup ? 30 : 0,
                  child: CustomPaint(
                    painter: _DashedLinePainter(
                      color: ZunoTheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.posts.map((post) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: SizedBox(
                              width: 20,
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: ZunoTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: ZunoTheme.surface, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PostCard(
                              post: post,
                              isOwn: post.userId == widget.currentUserId,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
