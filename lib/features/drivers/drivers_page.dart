import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'models/driver.dart';
import 'providers/driver_provider.dart';
import 'widgets/driver_filters_bar.dart';
import 'widgets/drivers_table.dart';
import 'widgets/driver_form_dialog.dart';
import 'widgets/driver_details_dialog.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'widgets/bulk_actions_bar.dart';
import 'widgets/driver_status_badge.dart';
import 'widgets/star_rating.dart';

/// Couleurs SHTT - Design System
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1E40AF);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const background = Color(0xFFFFFFFF);
  static const backgroundGrey = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
}

/// Page principale de gestion des chauffeurs
class DriversPage extends ConsumerStatefulWidget {
  const DriversPage({super.key});

  @override
  ConsumerState<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends ConsumerState<DriversPage> {
  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(filteredDriversProvider);
    final selectedDrivers = ref.watch(selectedDriversProvider);
    final filters = ref.watch(driverFiltersProvider);

    return Scaffold(
      backgroundColor: SHTTColors.backgroundGrey,
      body: Column(
        children: [
          // Header avec titre et boutons d'action
          _buildHeader(),

          // Barre de filtrage et recherche
          const DriverFiltersBar(),

          // Actions en masse si sélection
          if (selectedDrivers.isNotEmpty) const BulkActionsBar(),

          // Nombre de résultats
          _buildResultsCount(driversAsync),

          // Tableau des chauffeurs
          Expanded(
            child: driversAsync.when(
              data: (drivers) => DriversTable(
                drivers: drivers,
                onView: _showDriverDetails,
                onEdit: _showEditDriver,
                onDelete: _showDeleteConfirmation,
                onStatusChange: _changeDriverStatus,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: SHTTColors.primary),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: SHTTColors.critical.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: SHTTColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: SHTTColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.read(driversProvider.notifier).loadDrivers(),
                      icon: const Icon(LucideIcons.refreshCw),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SHTTColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      height: isMobile ? 45 : 60,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 20,
        vertical: isMobile ? 6 : 12,
      ),
      decoration: const BoxDecoration(
        color: SHTTColors.background,
        border: Border(bottom: BorderSide(color: SHTTColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            decoration: BoxDecoration(
              color: SHTTColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.users,
              color: SHTTColors.primary,
              size: isMobile ? 18 : 20,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isMobile ? 'Chauffeurs' : 'Gestion des Chauffeurs',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: SHTTColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (!isMobile)
                  Text(
                    'Gérez les informations de vos chauffeurs',
                    style: TextStyle(fontSize: 12, color: SHTTColors.textGrey),
                  ),
              ],
            ),
          ),
          _buildActionButtons(isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildActionButtons({required bool isMobile}) {
    return Row(
      children: [
        // Bouton Importer
        isMobile
            ? _buildIconButton(
                LucideIcons.upload,
                SHTTColors.textGrey,
                _importDrivers,
              )
            : OutlinedButton.icon(
                onPressed: _importDrivers,
                icon: const Icon(LucideIcons.upload, size: 16),
                label: const Text('Importer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SHTTColors.textGrey,
                  side: const BorderSide(color: SHTTColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
        SizedBox(width: isMobile ? 8 : 12),

        // Bouton Exporter
        isMobile
            ? _buildIconButton(
                LucideIcons.download,
                SHTTColors.textGrey,
                _exportDrivers,
              )
            : OutlinedButton.icon(
                onPressed: _exportDrivers,
                icon: const Icon(LucideIcons.download, size: 16),
                label: const Text('Exporter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SHTTColors.textGrey,
                  side: const BorderSide(color: SHTTColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
        SizedBox(width: isMobile ? 8 : 12),

        // Bouton Ajouter
        isMobile
            ? _buildIconButton(
                LucideIcons.plus,
                SHTTColors.secondary,
                _showAddDriver,
                backgroundColor: SHTTColors.secondary,
                iconColor: Colors.white,
              )
            : ElevatedButton.icon(
                onPressed: _showAddDriver,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Ajouter un chauffeur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SHTTColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildIconButton(
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Material(
      color: backgroundColor ?? color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: iconColor ?? color),
        ),
      ),
    );
  }

  Widget _buildResultsCount(AsyncValue<List<Driver>> driversAsync) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      alignment: Alignment.centerLeft,
      child: driversAsync.when(
        data: (drivers) => Text(
          'Affichage de ${drivers.length} chauffeur${drivers.length > 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12, color: SHTTColors.textGrey),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  void _showAddDriver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DriverFormDialog(
        onSave: (driver) async {
          await ref.read(driversProvider.notifier).addDriver(driver);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chauffeur ajouté avec succès'),
                backgroundColor: SHTTColors.secondary,
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditDriver(Driver driver) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DriverFormDialog(
        driver: driver,
        onSave: (updatedDriver) async {
          await ref.read(driversProvider.notifier).updateDriver(updatedDriver);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chauffeur mis à jour avec succès'),
                backgroundColor: SHTTColors.secondary,
              ),
            );
          }
        },
      ),
    );
  }

  void _showDriverDetails(Driver driver) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DriverDetailsDialog(
        driver: driver,
        onEdit: () {
          Navigator.of(context).pop();
          _showEditDriver(driver);
        },
      ),
    );
  }

  void _showDeleteConfirmation(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Supprimer le chauffeur ?',
        message:
            'Êtes-vous sûr de vouloir supprimer ${driver.fullName} ? Cette action est irréversible.',
        onConfirm: () async {
          await ref.read(driversProvider.notifier).deleteDriver(driver.id);
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chauffeur supprimé avec succès'),
                backgroundColor: SHTTColors.critical,
              ),
            );
          }
        },
      ),
    );
  }

  void _changeDriverStatus(Driver driver, DriverStatus status) {
    ref.read(driversProvider.notifier).updateDriverStatus(driver.id, status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Statut changé en "${status.display}"'),
        backgroundColor: SHTTColors.primary,
      ),
    );
  }

  void _importDrivers() {
    // TODO: Implémenter l'import
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité d\'import en cours de développement'),
      ),
    );
  }

  void _exportDrivers() {
    // TODO: Implémenter l'export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité d\'export en cours de développement'),
      ),
    );
  }
}
