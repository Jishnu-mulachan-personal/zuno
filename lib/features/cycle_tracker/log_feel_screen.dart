import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _FeelingOption {
  final String label;
  final String emoji;
  final IconData icon;

  const _FeelingOption(this.label, this.emoji, this.icon);
}

const _feelings = [
  _FeelingOption('Radiant', '☀️', Icons.wb_sunny_outlined),
  _FeelingOption('Calm', '🌿', Icons.spa_outlined),
  _FeelingOption('Balanced', '⚖️', Icons.self_improvement_outlined),
  _FeelingOption('Tired', '😴', Icons.bedtime_outlined),
  _FeelingOption('Sensitive', '🌊', Icons.favorite_outline),
  _FeelingOption('Anxious', '💭', Icons.psychology_outlined),
  _FeelingOption('Energised', '⚡', Icons.bolt_outlined),
  _FeelingOption('Hopeful', '🌸', Icons.local_florist_outlined),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class LogFeelScreen extends ConsumerStatefulWidget {
  const LogFeelScreen({super.key});

  @override
  ConsumerState<LogFeelScreen> createState() => _LogFeelScreenState();
}

class _LogFeelScreenState extends ConsumerState<LogFeelScreen>
    with TickerProviderStateMixin {
  int _selectedFeelingIndex = 0;
  double _intensity = 0.5;
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

  String get _intensityLabel {
    if (_intensity < 0.33) return 'Low';
    if (_intensity < 0.66) return 'Medium';
    return 'High';
  }

  Future<void> _saveLog() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        await ref.read(dashboardProvider.notifier).saveLog();
      }
    } catch (_) {}

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
    final now = DateTime.now();

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Log Your Feel',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Date label ──────────────────────────────────────
                    Text(
                      'Select date',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${monthNames[now.month - 1]} ${now.year}',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── How are you feeling ─────────────────────────────
                    _buildSectionTitle('How are you feeling today?', cs, tt),
                    const SizedBox(height: 4),
                    Text(
                      'You can select multiple',
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),

                    // Energy / Feeling label
                    Text(
                      'Energy / Feeling',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Horizontal feeling selector
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _feelings.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) =>
                            _buildFeelingCard(i, cs, tt),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Intensity slider ────────────────────────────────
                    Text(
                      'Intensity',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildIntensitySlider(cs, tt),
                    const SizedBox(height: 28),

                    // ── Notes ───────────────────────────────────────────
                    Text(
                      'Add quick notes',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '(optional)',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNotesField(cs, tt),
                    const SizedBox(height: 40),

                    // ── Save button ─────────────────────────────────────
                    _buildSaveButton(cs, tt),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      String text, ColorScheme cs, TextTheme tt) {
    return Text(
      text,
      style: tt.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }

  Widget _buildFeelingCard(int index, ColorScheme cs, TextTheme tt) {
    final feeling = _feelings[index];
    final isSelected = _selectedFeelingIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFeelingIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withOpacity(0.1)
              : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: cs.primary, width: 2)
              : Border.all(
                  color: cs.outlineVariant.withOpacity(0.4), width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              feeling.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              feeling.label,
              style: tt.labelSmall?.copyWith(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle_rounded,
                  size: 14, color: cs.primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntensitySlider(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.surfaceContainerHighest,
            thumbColor: cs.primary,
            overlayColor: cs.primary.withOpacity(0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 6,
          ),
          child: Slider(
            value: _intensity,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _intensity = v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              Text('Medium',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
              Text('High',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _intensityLabel,
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(ColorScheme cs, TextTheme tt) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          TextField(
            controller: _notesController,
            maxLines: 4,
            style: tt.bodyMedium,
            decoration: InputDecoration(
              hintText: 'How would you describe your day?',
              hintStyle: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 48, 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.edit_outlined,
                size: 18, color: cs.onSurfaceVariant.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs, TextTheme tt) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: cs.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save Log'),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_outlined, color: cs.onPrimary, size: 24),
        ),
      ],
    );
  }
}
