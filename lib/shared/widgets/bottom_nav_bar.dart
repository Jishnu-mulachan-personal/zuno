import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';

enum ZunoTab { today, insights, us, you }

class ZunoBottomNavBar extends StatelessWidget {
  final ZunoTab activeTab;
  final String relationshipStatus;

  const ZunoBottomNavBar({
    super.key,
    required this.activeTab,
    required this.relationshipStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: ZunoTheme.surface.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: ZunoTheme.outlineVariant.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.onSurface.withOpacity(0.04),
              blurRadius: 40,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavTab(
              icon: Icons.calendar_today_rounded,
              label: 'Today',
              active: activeTab == ZunoTab.today,
              onTap: () => context.go('/dashboard'),
            ),
            _NavTab(
              icon: Icons.analytics_outlined,
              label: 'Insights',
              active: activeTab == ZunoTab.insights,
              onTap: () => context.go('/insights'),
            ),
            if (relationshipStatus != 'single')
              _NavTab(
                icon: Icons.favorite_outline_rounded,
                label: 'Us',
                active: activeTab == ZunoTab.us,
                onTap: () => context.go('/us'),
              ),
            _NavTab(
              icon: Icons.person_outline_rounded,
              label: 'You',
              active: activeTab == ZunoTab.you,
              onTap: () => context.go('/you'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? ZunoTheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active
                  ? ZunoTheme.primary
                  : ZunoTheme.onSurface.withOpacity(0.4),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: active
                    ? ZunoTheme.primary
                    : ZunoTheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
