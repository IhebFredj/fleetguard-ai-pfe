import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/dashboard_theme.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String trend;
  final Color backgroundColor;
  final Color iconColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.trend,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
            child: Container(
              padding: const EdgeInsets.all(DashboardTheme.s12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DashboardTheme.radiusCard),
                boxShadow: DashboardTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 24),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: DashboardTheme.s8),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: DashboardTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: DashboardTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trend,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 280.ms,
        );
  }
}
