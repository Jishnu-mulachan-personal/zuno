import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/encryption_service.dart';
import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _LogOption {
  final String label;
  final IconData? icon;
  final Widget? customIcon;
  final String? id;

  const _LogOption(this.label, {this.icon, this.customIcon, this.id});
}

const _physicalOptions = [
  _LogOption('Cramps', icon: Icons.waves_rounded, id: 'physical:cramps'),
  _LogOption('Bloating', icon: Icons.water_drop_outlined, id: 'physical:bloating'),
  _LogOption('Headache', icon: Icons.psychology_outlined, id: 'physical:headache'),
  _LogOption('Back Pain', icon: Icons.accessibility_new_rounded, id: 'physical:back_pain'),
  _LogOption('Tender Breasts', icon: Icons.favorite_border_rounded, id: 'physical:tender_breasts'),
  _LogOption('Fatigue', icon: Icons.bedtime_outlined, id: 'physical:fatigue'),
  _LogOption('Acne', icon: Icons.face_rounded, id: 'physical:acne'),
  _LogOption('Other', icon: Icons.more_horiz_rounded, id: 'physical:other'),
];

const _flowOptions = [
  _LogOption('Light', icon: Icons.water_drop_outlined, id: 'flow:light'),
  _LogOption('Medium', customIcon: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.water_drop_outlined, size: 16),
      Icon(Icons.water_drop_outlined, size: 16),
    ],
  ), id: 'flow:medium'),
  _LogOption('Heavy', customIcon: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.water_drop_outlined, size: 14),
      Icon(Icons.water_drop_outlined, size: 14),
      Icon(Icons.water_drop_outlined, size: 14),
    ],
  ), id: 'flow:heavy'),
  _LogOption('Spotting', icon: Icons.grain_rounded, id: 'flow:spotting'),
];

const _moodOptions = [
  _LogOption('Calm', icon: Icons.spa_outlined, id: 'mood:calm'),
  _LogOption('Happy', icon: Icons.wb_sunny_outlined, id: 'mood:happy'),
  _LogOption('Social', icon: Icons.groups_outlined, id: 'mood:social'),
  _LogOption('Irritable', icon: Icons.cloud_outlined, id: 'mood:irritable'),
  _LogOption('Anxious', icon: Icons.psychology_rounded, id: 'mood:anxious'),
  _LogOption('Sensitive', icon: Icons.favorite_rounded, id: 'mood:sensitive'),
  _LogOption('Motivated', icon: Icons.star_border_rounded, id: 'mood:motivated'),
  _LogOption('Other', icon: Icons.more_horiz_rounded, id: 'mood:other'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class LogFeelScreen extends ConsumerStatefulWidget {
  const LogFeelScreen({super.key});

  @override
  ConsumerState<LogFeelScreen> createState() => _LogFeelScreenState();
}

class _LogFeelScreenState extends ConsumerState<LogFeelScreen>
    with TickerProviderStateMixin {
  final Set<String> _selectedPhysical = {};
  String? _selectedFlow;
  final Set<String> _selectedMoods = {};
  final _notesController = TextEditingController();
  bool _isSaving = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      
      // Collect all tags
      final List<String> tags = [
        ..._selectedPhysical,
        if (_selectedFlow != null) _selectedFlow!,
        ..._selectedMoods,
      ];

      // Use first mood as mood_emoji if available
      if (_selectedMoods.isNotEmpty) {
        // We could map labels to emojis if we wanted to preserve the mood_emoji field
      }

      final profile = ref.read(userProfileProvider).value;
      final isNotePrivate = profile?.journalNotePrivate ?? false;
      final shareWithPartner = profile?.shareJournalWithPartner ?? false;

      // Direct insert for cycle-specific detail log
      await supabase.from('daily_logs').insert({
        'user_id': user.id,
        'log_date': todayStr,
        'context_tags': tags,
        'journal_note': _notesController.text.trim().isNotEmpty 
            ? EncryptionService.encrypt(_notesController.text.trim()) 
            : null,
        'is_note_private': isNotePrivate,
        'share_with_partner': shareWithPartner,
      });

      // Synchronize dashboard state if needed
      ref.read(dashboardProvider.notifier).refreshInsights();

    } catch (e) {
      debugPrint('[LogFeelScreen] Error saving log: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFCF9F6), // Digital Hearth Cream
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Custom Header ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'How is your body\nfeeling today?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          textStyle: tt.headlineMedium?.copyWith(
                            color: const Color(0xFF2D2D2D),
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC05E44).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Log Card Container ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFFE5E2DF).withOpacity(0.5),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Physical Section ──
                        _buildSectionHeader(
                          'Physical',
                          Icons.favorite_border_rounded,
                          const Color(0xFFC05E44),
                          tt,
                        ),
                        const SizedBox(height: 16),
                        _buildGrid(
                          _physicalOptions,
                          _selectedPhysical,
                          (id) {
                            setState(() {
                              if (_selectedPhysical.contains(id)) {
                                _selectedPhysical.remove(id);
                              } else {
                                _selectedPhysical.add(id);
                              }
                            });
                          },
                          const Color(0xFFC05E44),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(height: 1, color: Color(0xFFF3F1EE)),
                        ),

                        // ── Flow Section ──
                        _buildSectionHeader(
                          'Flow',
                          Icons.water_drop_outlined,
                          const Color(0xFFC05E44),
                          tt,
                        ),
                        const SizedBox(height: 16),
                        _buildGrid(
                          _flowOptions,
                          _selectedFlow != null ? {_selectedFlow!} : {},
                          (id) {
                            setState(() {
                              if (_selectedFlow == id) {
                                _selectedFlow = null;
                              } else {
                                _selectedFlow = id;
                              }
                            });
                          },
                          const Color(0xFFC05E44),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(height: 1, color: Color(0xFFF3F1EE)),
                        ),

                        // ── Mood Section ──
                        _buildSectionHeader(
                          'Mood',
                          Icons.emoji_emotions_outlined,
                          const Color(0xFF528A7A), // Teal
                          tt,
                        ),
                        const SizedBox(height: 16),
                        _buildGrid(
                          _moodOptions,
                          _selectedMoods,
                          (id) {
                            setState(() {
                              if (_selectedMoods.contains(id)) {
                                _selectedMoods.remove(id);
                              } else {
                                _selectedMoods.add(id);
                              }
                            });
                          },
                          const Color(0xFF528A7A),
                        ),

                        const SizedBox(height: 32),

                        // ── Notes Section ──
                        Text(
                          'Add a note (optional)',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF54433E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNotesField(cs, tt),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Save Button ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 60),
                  child: _buildSaveButton(cs, tt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, TextTheme tt) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(
    List<_LogOption> options,
    Set<String> selection,
    Function(String) onToggle,
    Color activeColor,
  ) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - (3 * 12)) / 4;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: options.map((opt) {
          final isSelected = selection.contains(opt.id);
          return _buildOptionCard(opt, isSelected, onToggle, activeColor, width);
        }).toList(),
      );
    });
  }

  Widget _buildOptionCard(
    _LogOption opt,
    bool isSelected,
    Function(String) onToggle,
    Color activeColor,
    double size,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle(opt.id!);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size * 1.1,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFFCF9F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE5E2DF).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: isSelected ? Colors.white : const Color(0xFF54433E).withOpacity(0.7),
                  ),
                  child: opt.customIcon ?? Icon(
                    opt.icon,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    opt.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF54433E),
                    ),
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 10, color: activeColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField(ColorScheme cs, TextTheme tt) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E2DF).withOpacity(0.5)),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: tt.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Feeling super connected with myself...',
              hintStyle: tt.bodyMedium?.copyWith(color: const Color(0xFF8B8B8B).withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.eco_outlined,
              size: 20,
              color: const Color(0xFFC05E44).withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs, TextTheme tt) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC05E44),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'Save Log',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
