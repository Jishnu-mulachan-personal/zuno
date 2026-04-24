import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import '../../core/theme_provider.dart';
import '../dashboard/dashboard_state.dart';
import 'cycle_data_model.dart';

class CycleCalendarScreen extends ConsumerStatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  ConsumerState<CycleCalendarScreen> createState() =>
      _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends ConsumerState<CycleCalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final cycleData = profile?.cycleData;
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Light warm background
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : cycleData == null
              ? const Center(child: Text('No cycle data available.'))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(profile),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            _buildPhaseCard(cycleData),
                            const SizedBox(height: 32),
                            _buildHorizontalCalendar(cycleData),
                            const SizedBox(height: 32),
                            _buildEnergyCard(),
                            const SizedBox(height: 32),
                            _buildLogQuickActions(),
                            const SizedBox(height: 32),
                            _buildAIInsight(state.cycleInsight),
                            const SizedBox(height: 32),
                            _buildUpcomingSection(cycleData),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  SliverAppBar _buildAppBar(UserProfile profile) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      pinned: true, // Keep "Zuno" visible on scroll if desired
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black87),
        onPressed: () {},
      ),
      title: Text(
        'Zuno',
        style: GoogleFonts.notoSerif(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFC04A3C), // Terracotta
          fontStyle: FontStyle.italic,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${profile.displayName.split(' ').first}',
                style: GoogleFonts.notoSerif(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Let's tune into your body's rhythm",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseCard(CycleData cycle) {
    final phase = cycle.currentPhase;

    String displayName = 'Follicular Phase';
    Color mainColor = const Color(0xFF4DB6AC);
    Color gradientStart = const Color(0xFFF3C0A4);
    String badgeText = "Potential Fertility";

    if (phase == 'Ovulation') {
      displayName = 'Ovulation Window';
      mainColor = const Color(0xFF2C7475); // Dark teal
      gradientStart = const Color(0xFFE27C65); // Terracotta/Orange
      badgeText = "High Fertility";
    } else if (phase == 'Menstruation') {
      displayName = 'Menstruation';
      mainColor = const Color(0xFFC04A3C);
      gradientStart = const Color(0xFFD68A81);
      badgeText = "Self Care";
    } else if (phase == 'Luteal') {
      displayName = 'Luteal Phase';
      gradientStart = const Color(0xFF759D9E);
      mainColor = const Color(0xFF4DB6AC);
      badgeText = "Rest & Reset";
    }

    final dayProgress = cycle.currentCycleDay;
    final totalDays = cycle.cycleLength;
    final progress = (dayProgress / totalDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are in your',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  style: GoogleFonts.notoSerif(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: mainColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Day $dayProgress  •  ${_getMonthName(DateTime.now().month)} ${DateTime.now().day}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 14, color: mainColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(100, 100),
                  painter: _RingPainter(
                    progress: progress,
                    gradientStart: gradientStart,
                    gradientEnd: mainColor,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dayProgress',
                        style: GoogleFonts.notoSerif(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: mainColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'of $totalDays',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(CycleData cycle) {
    final today = DateTime.now();
    // Build list representing standard view (~21 days)
    final dates = List.generate(21,
        (i) => today.subtract(const Duration(days: 4)).add(Duration(days: i)));

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = date.day == _selectedDate.day &&
                  date.month == _selectedDate.month;

              const dayNames = [
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
                'SUN'
              ];
              // DateTime.weekday is 1 (Mon) to 7 (Sun)
              final dayName = dayNames[date.weekday - 1];

              final phase = cycle.getDayType(date);
              Color dotColor = Colors.transparent;
              if (phase == 'period') {
                dotColor = const Color(0xFFC04A3C);
              } else if (phase == 'fertile' || phase == 'maybe_fertile') {
                dotColor = const Color(0xFF4DB6AC);
              } else {
                dotColor = Colors.black12;
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: const Color(0xFF2C7475),
                          borderRadius: BorderRadius.circular(24),
                        )
                      : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${date.day}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 0),
          child: Divider(color: Colors.black12, height: 1),
        ),
      ],
    );
  }

  Widget _buildEnergyCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9E8DE), // Beige
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: 0,
            child: SizedBox(
              height: 200,
              child: Image.asset(
                'assets/images/radiant_energy.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const SizedBox(), // fallback
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Today's Energy",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline,
                        size: 14, color: Colors.black54),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Radiant",
                  style: GoogleFonts.notoSerif(
                    fontSize: 32,
                    color: const Color(0xFFC04A3C),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(Icons.wb_sunny_outlined,
                    color: Color(0xFFC04A3C), size: 30),
                const SizedBox(height: 48),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.55,
                  child: Text(
                    "High energy and sociability.\nA great day for connection and creativity.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Log how you feel",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "View all",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C7475),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionItem(Icons.water_drop_outlined, "Body",
                const Color(0xFFFCEBE8), const Color(0xFFC04A3C)),
            _buildActionItem(Icons.sentiment_satisfied_outlined, "Mood",
                const Color(0xFFE2EFEF), const Color(0xFF2C7475)),
            _buildActionItem(Icons.vaccines_outlined, "Flow",
                const Color(0xFFFCEBE8), const Color(0xFFC04A3C)),
            _buildActionItem(Icons.edit_outlined, "Notes",
                const Color(0xFFF4EEE5), const Color(0xFF7D7268)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionItem(
      IconData icon, String label, Color bgColor, Color iconColor) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Icon(icon, size: 28, color: iconColor),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildAIInsight(String? genericInsight) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: Color(0xFF2C7475)),
              const SizedBox(width: 8),
              Text(
                "AI Insight",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C7475),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  genericInsight ??
                      "Estrogen is rising, which may enhance your mood and energy. Stay hydrated and enjoy this vibrant phase!",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF9C86), Color(0xFFD67362)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(CycleData cycle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Upcoming",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                "Next 7 days",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C7475),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _buildUpcomingCard(
                  "Feb 11 – 12", "Peak Fertility", const Color(0xFF2C7475), true),
              const SizedBox(width: 12),
              _buildUpcomingCard(
                  "Feb 13 – 15", "Ovulation", const Color(0xFFC04A3C), false),
              const SizedBox(width: 12),
              _buildUpcomingCard(
                  "Feb 16 – 20", "Energy Shift", const Color(0xFFE27C65), true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(
      String dateRange, String title, Color accentColor, bool isWave) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            dateRange,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          isWave
              ? Icon(Icons.waves, size: 24, color: accentColor)
              : Icon(Icons.radio_button_checked, size: 20, color: accentColor),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color gradientStart;
  final Color gradientEnd;

  _RingPainter(
      {required this.progress,
      required this.gradientStart,
      required this.gradientEnd});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 4;

    final bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    double startAngle = -math.pi / 2;
    double dashWidth = 0.08;
    double dashSpace = 0.12;
    double totalAngles = 2 * math.pi;
    for (double i = 0; i < totalAngles; i += dashWidth + dashSpace) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i,
        dashWidth,
        false,
        bgPaint,
      );
    }

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [gradientStart, gradientEnd],
      stops: const [0.0, 1.0],
    );

    final highlightPaint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
