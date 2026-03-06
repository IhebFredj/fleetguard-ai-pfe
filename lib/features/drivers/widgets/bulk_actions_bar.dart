import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/driver.dart';
import '../providers/driver_provider.dart';
import 'driver_status_badge.dart';

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

/// Barre d'actions en masse
class BulkActionsBar extends ConsumerWidget {
  const BulkActionsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDrivers = ref.watch(selectedDriversProvider);
    final count = selectedDrivers.length;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SHTTColors.primary.withOpacity(0.05),
        border: Border.all(color: SHTTColors.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SHTTColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count sélectionné${count > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SHTTColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const VerticalDivider(),
          const SizedBox(width: 16),

          // Bouton Exporter
          _buildActionButton(
            icon: LucideIcons.download,
            label: 'Exporter',
            color: SHTTColors.primary,
            onPressed: () {
              // TODO: Exporter les chauffeurs sélectionnés
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Export de $count chauffeur${count > 1 ? 's' : ''} en cours...',
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Bouton Changer statut
          _buildActionButton(
            icon: LucideIcons.edit,
            label: 'Changer statut',
            color: SHTTColors.accent,
            onPressed: () =>
                _showStatusChangeDialog(context, ref, selectedDrivers),
          ),
          const SizedBox(width: 12),

          // Bouton Supprimer
          _buildActionButton(
            icon: LucideIcons.trash2,
            label: 'Supprimer',
            color: SHTTColors.critical,
            onPressed: () =>
                _showDeleteConfirmation(context, ref, selectedDrivers),
          ),

          const Spacer(),

          // Bouton Tout sélectionner / Annuler
          TextButton.icon(
            onPressed: () {
              ref.read(selectedDriversProvider.notifier).clearSelection();
            },
            icon: const Icon(LucideIcons.x, size: 16),
            label: const Text('Annuler'),
            style: TextButton.styleFrom(foregroundColor: SHTTColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  void _showStatusChangeDialog(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le statut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DriverStatus.values.map((status) {
            return ListTile(
              leading: DriverStatusBadge(status: status, size: 'small'),
              title: Text(status.display),
              onTap: () {
                ref
                    .read(driversProvider.notifier)
                    .updateDriversStatus(selectedIds, status);
                ref.read(selectedDriversProvider.notifier).clearSelection();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Statut mis à jour pour ${selectedIds.length} chauffeur${selectedIds.length > 1 ? 's' : ''}',
                    ),
                    backgroundColor: SHTTColors.primary,
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer les chauffeurs ?'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ${selectedIds.length} chauffeur${selectedIds.length > 1 ? 's' : ''} ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(driversProvider.notifier).deleteDrivers(selectedIds);
              ref.read(selectedDriversProvider.notifier).clearSelection();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${selectedIds.length} chauffeur${selectedIds.length > 1 ? 's' : ''} supprimé${selectedIds.length > 1 ? 's' : ''}',
                  ),
                  backgroundColor: SHTTColors.critical,
                ),
              );
            },
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.critical,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
