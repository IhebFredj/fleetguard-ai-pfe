import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Couleurs SHTT
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const background = Color(0xFFFFFFFF);
  static const backgroundGrey = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
}

/// Dialog de confirmation de suppression
class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SHTTColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône d'alerte
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: SHTTColors.critical.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertTriangle,
                color: SHTTColors.critical,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),

            // Titre
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SHTTColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Boutons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SHTTColors.textGrey,
                    side: const BorderSide(color: SHTTColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SHTTColors.critical,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
