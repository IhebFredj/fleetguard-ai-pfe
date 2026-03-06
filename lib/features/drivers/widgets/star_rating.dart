import 'package:flutter/material.dart';

/// Couleurs SHTT
class SHTTColors {
  static const accent = Color(0xFFF97316);
  static const textGrey = Color(0xFF6B7280);
}

/// Widget d'affichage d'étoiles pour la notation
class StarRating extends StatelessWidget {
  final double rating;
  final int? count;
  final double size;
  final bool showCount;
  final MainAxisAlignment alignment;

  const StarRating({
    super.key,
    required this.rating,
    this.count,
    this.size = 16,
    this.showCount = true,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;
          Color color;

          if (rating >= starValue) {
            icon = Icons.star;
            color = SHTTColors.accent;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half;
            color = SHTTColors.accent;
          } else {
            icon = Icons.star_border;
            color = SHTTColors.textGrey.withOpacity(0.3);
          }

          return Icon(icon, size: size, color: color);
        }),
        if (showCount && count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(fontSize: size * 0.75, color: SHTTColors.textGrey),
          ),
        ],
      ],
    );
  }
}
