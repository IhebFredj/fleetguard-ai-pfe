import 'package:flutter/material.dart';
import '../models/driver.dart';

/// Couleurs SHTT
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
}

/// Widget badge de statut du chauffeur
class DriverStatusBadge extends StatelessWidget {
  final DriverStatus status;
  final String? size;

  const DriverStatusBadge({
    super.key,
    required this.status,
    this.size = 'normal',
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    final isSmall = size == 'small';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.display,
        style: TextStyle(
          color: colors.text,
          fontSize: isSmall ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  _StatusColors _getColors() {
    switch (status) {
      case DriverStatus.active:
        return _StatusColors(
          background: SHTTColors.secondary.withOpacity(0.1),
          text: SHTTColors.secondary,
        );
      case DriverStatus.inactive:
        return _StatusColors(
          background: SHTTColors.textGrey.withOpacity(0.1),
          text: SHTTColors.textGrey,
        );
      case DriverStatus.onLeave:
        return _StatusColors(
          background: SHTTColors.primary.withOpacity(0.1),
          text: SHTTColors.primary,
        );
      case DriverStatus.suspended:
        return _StatusColors(
          background: SHTTColors.critical.withOpacity(0.1),
          text: SHTTColors.critical,
        );
    }
  }
}

class _StatusColors {
  final Color background;
  final Color text;

  _StatusColors({required this.background, required this.text});
}
