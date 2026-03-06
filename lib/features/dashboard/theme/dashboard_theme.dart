import 'package:flutter/material.dart';

/// Design system SHTT pour le dashboard.
abstract class DashboardTheme {
  // Couleurs
  static const Color primary = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF1E40AF);
  static const Color accent = Color(0xFF10B981);
  static const Color alert = Color(0xFFF97316);
  static const Color critical = Color(0xFFEF4444);
  static const Color text = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);

  // Cartes KPI - fonds
  static const Color cardGreen = Color(0xFFD1FAE5);
  static const Color cardBlue = Color(0xFFDBEAFE);
  static const Color cardOrange = Color(0xFFFED7AA);
  static const Color cardRed = Color(0xFFFECACA);

  // Spacing (base 4)
  static const double s4 = 4, s8 = 8, s12 = 12, s16 = 16;
  static const double s24 = 24, s32 = 32, s48 = 48, s64 = 64;

  static const double radiusCard = 12;
  static const double radiusButton = 8;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
