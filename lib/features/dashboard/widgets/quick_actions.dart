import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/dashboard_theme.dart';

class QuickActionsBar extends StatelessWidget {
  final VoidCallback? onNewTrip;
  final VoidCallback? onFuel;
  final VoidCallback? onReport;
  final VoidCallback? onExport;

  const QuickActionsBar({
    super.key,
    this.onNewTrip,
    this.onFuel,
    this.onReport,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.navigation,
            label: 'Nouveau voyage',
            onTap: onNewTrip,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.fuel,
            label: 'Carburant',
            onTap: onFuel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.fileText,
            label: 'Rapport',
            onTap: onReport,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.download,
            label: 'Exporter',
            onTap: onExport,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardTheme.primary,
      borderRadius: BorderRadius.circular(DashboardTheme.radiusButton),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(DashboardTheme.radiusButton),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
