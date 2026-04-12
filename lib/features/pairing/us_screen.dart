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
import 'us_image_service.dart';
import 'us_state.dart';
import '../settings/profile_image_service.dart';
import '../../shared/widgets/profile_avatar.dart';
import 'widgets/daily_questions_card.dart';
import 'widgets/daily_questions_history.dart';
import 'widgets/our_dreams_section.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class UsScreen extends ConsumerStatefulWidget {
  const UsScreen({super.key});

  @override
  ConsumerState<UsScreen> createState() => _UsScreenState();
}

class _UsScreenState extends ConsumerState<UsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dreamsKey = GlobalKey();
  final GlobalKey _chatKey = GlobalKey();
  final GlobalKey _feedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Handle deep-link scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeeplinkScroll();
    });
  }

  void _handleDeeplinkScroll() {
    if (!mounted) return;
    
    final section = GoRouterState.of(context).uri.queryParameters['section'];
    if (section == null) return;

    debugPrint('[UsScreen] Handling deeplink scroll to section: $section');

    GlobalKey? targetKey;
    if (section == 'dreams') targetKey = _dreamsKey;
    else if (section == 'chat') targetKey = _chatKey;
    else if (section == 'feed') targetKey = _feedKey;

    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(sharedPostsProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme changes to trigger rebuild
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: profileAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: ZunoTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final isPaired =
              profile.partnerName != null && profile.relationshipId != null;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => ref.read(sharedPostsProvider.notifier).refresh(),
                color: ZunoTheme.primary,
                backgroundColor: ZunoTheme.surface,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  slivers: [
                    _UsAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                            if (isPaired) ...[
                              _PairedHeader(profile: profile),
                              const SizedBox(height: 24),
                              OurDreamsSection(key: _dreamsKey),
                              const SizedBox(height: 28),
                              DailyQuestionsWidget(key: _chatKey),
                              const DailyQuestionsHistory(),
                              SizedBox(key: _feedKey, height: 1),
                            ] else ...[

                            _PairCard(),
                            const SizedBox(height: 24),
                            _UnpairedTimelineNote(),
                            const SizedBox(height: 120),
                          ],
                        ]),
                      ),
                    ),
                    if (isPaired)
                      _SharedFeed(
                        relationshipId: profile.relationshipId!,
                        currentUserId: profile.id,
                      ),
                    if (isPaired)
                      const SliverToBoxAdapter(child: SizedBox(height: 160)),
                  ],
                ),
              ),
              ZunoBottomNavBar(
                activeTab: ZunoTab.us,
                relationshipStatus: profile.relationshipStatus,
              ),
              if (isPaired)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 80, // above bottom nav
                  child: _ComposeBar(
                    relationshipId: profile.relationshipId!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _UsAppBar extends StatelessWidget {
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
        'Us',
        style: GoogleFonts.notoSerif(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ZunoTheme.primary,
        ),
      ),
    );
  }
}

// ─── Paired hero header ───────────────────────────────────────────────────────

class _PairedHeader extends ConsumerWidget {
  final UserProfile profile;
  const _PairedHeader({required this.profile});

  Future<void> _updatePhoto(WidgetRef ref, BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image == null) return;

    final ok = await ref.read(usPostNotifierProvider.notifier).updateUsPhoto(
          relationshipId: profile.relationshipId!,
          imageFile: File(image.path),
          oldPath: profile.usPhotoUrl,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Us photo updated! ✨' : 'Failed to update photo'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? ZunoTheme.tertiary : ZunoTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = profile.usPhotoUrl != null && profile.usPhotoUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: ZunoTheme.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Background Image
          if (hasPhoto)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: FutureBuilder<String>(
                  future: ProfileImageService.createSignedUrl(
                    ProfileImageService.bucketUsPhotos,
                    profile.usPhotoUrl!,
                  ),
                  builder: (ctx, snap) {
                    if (snap.hasData) {
                      return Image.network(
                        snap.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(color: ZunoTheme.surfaceContainerHigh);
                  },
                ),
              ),
            ),

          // Gradient overlay for readability
          if (hasPhoto)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
          // Fallback UI when no photo
          if (!hasPhoto)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    color: ZunoTheme.primary.withValues(alpha: 0.25),
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add a cover photo of you both ✨',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: hasPhoto ? Colors.white : ZunoTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sharing moments with ${profile.partnerName}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: hasPhoto ? Colors.white : ZunoTheme.primary,
                        shadows: hasPhoto
                            ? [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Edit Button
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => _updatePhoto(ref, context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (hasPhoto ? Colors.black : ZunoTheme.primary)
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      hasPhoto ? 'Edit' : 'Add',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Unpaired state ───────────────────────────────────────────────────────────

class _UnpairedTimelineNote extends StatelessWidget {
  const _UnpairedTimelineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: ZunoTheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text('🌿', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text(
            'Your shared timeline will appear here once you\'re connected.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: 15,
              color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.6),
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pair card (for unpaired) ─────────────────────────────────────────────────

class _PairCard extends StatelessWidget {
  const _PairCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONNECT YOUR PARTNER',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/pair/invite'),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ZunoTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ZunoTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pair with Partner',
                        style: GoogleFonts.notoSerif(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate a QR code and let your\npartner scan to connect.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.push('/pair/scan'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: ZunoTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: ZunoTheme.outlineVariant.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ZunoTheme.primaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded,
                      color: ZunoTheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Partner\'s Code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                      Text(
                        'Already have a code? Scan it here.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color:
                              ZunoTheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: ZunoTheme.outlineVariant, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared Feed ──────────────────────────────────────────────────────────────

class _SharedFeed extends ConsumerWidget {
  final String relationshipId;
  final String currentUserId;

  const _SharedFeed({
    required this.relationshipId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sharedPostsProvider);

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
              'Could not load posts:\n${state.error}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: ZunoTheme.error),
            ),
          ),
        ),
      );
    }

    if (state.posts.isEmpty) {
      return SliverToBoxAdapter(child: _EmptyState());
    }

    // Group posts by Month/Year
    final Map<String, List<SharedPost>> groups = {};
    for (final p in state.posts) {
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
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: ZunoTheme.outlineVariant.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.onSurface.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar
                  ProfileAvatar(
                    url: post.avatarUrl,
                    radius: 19,
                    name: post.userDisplayName,
                  ),

                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userDisplayName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ZunoTheme.onSurface,
                          ),
                        ),
                        Text(
                          relativeTime(post.createdAt),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: ZunoTheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOwn)
                    GestureDetector(
                      onTap: () => _showPostOptions(context, ref),
                      child: Icon(Icons.more_horiz_rounded,
                          color:
                              ZunoTheme.onSurfaceVariant.withValues(alpha: 0.4),
                          size: 20),
                    ),
                ],
              ),
            ),

            // ── Image ───────────────────────────────────────────────────────
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                // Constrain max height so portrait photos don't require too much scrolling,
                // while landscape images can be their natural shorter height.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    minHeight: 200,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _AuthenticatedImage(
                      url: post.imageUrl!,
                    ),
                  ),
                ),
              ),

            // ── Caption ─────────────────────────────────────────────────────
            if (post.caption.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  post.caption,
                  style: GoogleFonts.notoSerif(
                    fontSize: 15,
                    height: 1.55,
                    color: ZunoTheme.onSurface,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // ── Context tags ────────────────────────────────────────────────
            if (post.contextTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: post.contextTags
                      .map((tag) => _TagChip(label: tag))
                      .toList(),
                ),
              )
            else if (post.caption.isEmpty && post.imageUrl != null)
              const SizedBox(height: 14),
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
    final bgColor = ZunoTheme.tertiary.withValues(alpha: 0.04);
    final borderColor = ZunoTheme.tertiary.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: ZunoTheme.tertiary.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                ProfileAvatar(
                  url: post.avatarUrl,
                  radius: 19,
                  name: post.userDisplayName,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userDisplayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ZunoTheme.onSurface,
                        ),
                      ),
                      Text(
                        '${relativeTime(post.createdAt)} • Partner Journal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: ZunoTheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.moodEmoji != null)
                  Text(
                    post.moodEmoji!,
                    style: const TextStyle(fontSize: 22),
                  ),
              ],
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  post.caption,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: ZunoTheme.onSurface,
                  ),
                ),
              ),
            ),
          if (post.contextTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: post.contextTags.map((tag) => _TagChip(label: tag)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Authenticated Image ──────────────────────────────────────────────────────
// Uses a Supabase signed URL so images load from private Storage buckets.
// Accepts both plain storage paths and legacy full public URLs.
// Size is controlled by the parent SizedBox; this widget always fills it.

class _AuthenticatedImage extends StatelessWidget {
  final String url;

  const _AuthenticatedImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UsImageService.createSignedUrl(url),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: 300,
            color: ZunoTheme.surfaceContainerHigh,
            child: Center(
              child: CircularProgressIndicator(
                  color: ZunoTheme.primary, strokeWidth: 2),
            ),
          );
        }

        if (snap.hasError || !snap.hasData) {
          debugPrint(
              '[_AuthenticatedImage] Signed URL error for $url: ${snap.error}');
          return Container(
            width: double.infinity,
            height: 300,
            color: ZunoTheme.surfaceContainerHigh,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: ZunoTheme.outlineVariant),
            ),
          );
        }

        return Image.network(
          snap.data!,
          width: double.infinity,
          fit: BoxFit.cover, // crops to fill only if constrained by max height
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: double.infinity,
              height: 300,
              color: ZunoTheme.surfaceContainerHigh,
              child: Center(
                child: CircularProgressIndicator(
                    color: ZunoTheme.primary, strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (ctx, error, __) {
            debugPrint('[_AuthenticatedImage] Network load error: $error');
            return Container(
              width: double.infinity,
              height: 300,
              color: ZunoTheme.surfaceContainerHigh,
              child: Center(
                child: Icon(Icons.broken_image_outlined,
                    color: ZunoTheme.outlineVariant),
              ),
            );
          },
        );
      },
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
          // Handle
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
                    'This moment will be removed for both of you.',
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
                // Pop the bottom sheet first so it's gone
                navigator.pop();

                final success = await ref
                    .read(usPostNotifierProvider.notifier)
                    .deletePost(postId: post.id, imageUrl: post.imageUrl);

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text('Post deleted successfully'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: ZunoTheme.onSurface,
                    ),
                  );
                } else {
                  final error = ref.read(usPostNotifierProvider).error ??
                      'Unknown error occurred';
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $error'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: ZunoTheme.error,
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
    // Rebuild the raw text from caption + tags
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
    final notifier = ref.read(usPostNotifierProvider.notifier);
    final state = ref.watch(usPostNotifierProvider);
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
            // Handle
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

// ─── Compose Bar ──────────────────────────────────────────────────────────────

class _ComposeBar extends ConsumerStatefulWidget {
  final String relationshipId;
  const _ComposeBar({required this.relationshipId});

  @override
  ConsumerState<_ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends ConsumerState<_ComposeBar> {
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
    final state = ref.read(usPostNotifierProvider);
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
    final notifier = ref.read(usPostNotifierProvider.notifier);
    final caption = stripHashtags(_ctrl.text);

    final ok = await notifier.submitPost(
      caption: caption,
      imageFile: _pickedImage,
      contextTags: _tags,
      relationshipId: widget.relationshipId,
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
            heroTag: 'us_compose_fab',
            onPressed: () => setState(() => _isExpanded = true),
            backgroundColor: ZunoTheme.primary,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      );
    }

    final state = ref.watch(usPostNotifierProvider);
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
          // ── Header Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Post',
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

          // Image preview
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

          // Input + action row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Photo picker button (Unified)
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

              // Text field
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
                    hintText: 'Share a moment… #tag to add context',
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

              // Send button
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

          // Parsed tags preview
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
            Text('✨', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              'No shared moments yet.',
              style: GoogleFonts.notoSerif(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ZunoTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to share something with each other.',
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
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
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
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
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
        // ── Month Header ──
        GestureDetector(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
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
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
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

        // ── Posts (Timeline Axis) ──
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                // Dashed line
                Positioned(
                  left: 10, // Center of the 20px marker area
                  top: 0,
                  bottom: widget.isLastGroup ? 30 : 0, // Cut off nicely at end
                  child: CustomPaint(
                    painter: _DashedLinePainter(
                      color: ZunoTheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),

                // Post Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.posts.map((post) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dot Marker (Aligned with card avatar center)
                          // Avatar gets 14 top padding + 38 height = center is 33
                          // Dot size is 10px, so top padding = 33 - 5 = 28
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: SizedBox(
                              width: 20, // Matches `left: 10` center line above
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: ZunoTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ZunoTheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Post Card
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

