import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/driver.dart';
import 'driver_status_badge.dart';
import 'star_rating.dart';

/// Couleurs SHTT
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

/// Dialog des détails du chauffeur
class DriverDetailsDialog extends StatelessWidget {
  final Driver driver;
  final VoidCallback onEdit;

  const DriverDetailsDialog({
    super.key,
    required this.driver,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Plein écran sur mobile
    if (isMobile) {
      return Scaffold(
        backgroundColor: SHTTColors.background,
        appBar: AppBar(
          backgroundColor: SHTTColors.background,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft, color: SHTTColors.textDark),
          ),
          title: const Text(
            'Détails du chauffeur',
            style: TextStyle(
              color: SHTTColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                onEdit();
              },
              icon: const Icon(LucideIcons.pencil, color: SHTTColors.primary),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile: true),
              const SizedBox(height: 24),
              _buildPersonalInfoSection(isMobile: true),
              const SizedBox(height: 24),
              _buildProfessionalInfoSection(),
              const SizedBox(height: 24),
              if (driver.assignedVehicle != null) ...[
                _buildVehicleSection(),
                const SizedBox(height: 24),
              ],
              _buildStatisticsSection(isMobile: true),
              const SizedBox(height: 24),
              _buildDocumentsSection(),
              const SizedBox(height: 24),
              _buildTripHistorySection(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SHTTColors.backgroundGrey,
                    foregroundColor: SHTTColors.textDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Dialog sur desktop
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: SHTTColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header avec photo et infos principales
            _buildHeader(isMobile: false),

            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPersonalInfoSection(isMobile: false),
                    const SizedBox(height: 24),
                    _buildProfessionalInfoSection(),
                    const SizedBox(height: 24),
                    if (driver.assignedVehicle != null) ...[
                      _buildVehicleSection(),
                      const SizedBox(height: 24),
                    ],
                    _buildStatisticsSection(isMobile: false),
                    const SizedBox(height: 24),
                    _buildDocumentsSection(),
                    const SizedBox(height: 24),
                    _buildTripHistorySection(),
                  ],
                ),
              ),
            ),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: SHTTColors.background,
        border: const Border(bottom: BorderSide(color: SHTTColors.border)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: isMobile ? 60 : 80,
            height: isMobile ? 60 : 80,
            decoration: BoxDecoration(
              color: SHTTColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: driver.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      driver.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildInitials(),
                    ),
                  )
                : _buildInitials(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: SHTTColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  driver.driverId,
                  style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
                ),
                const SizedBox(height: 8),
                DriverStatusBadge(status: driver.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        driver.initials,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: SHTTColors.primary,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: SHTTColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: SHTTColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    bool isLink = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: SHTTColors.textGrey),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color ?? SHTTColors.textGrey),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          color ??
                          (isLink ? SHTTColors.primary : SHTTColors.textDark),
                      decoration: isLink ? TextDecoration.underline : null,
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

  Widget _buildPersonalInfoSection({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informations personnelles'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHTTColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildInfoRow('Prénom', driver.firstName),
              _buildInfoRow('Nom', driver.lastName),
              _buildInfoRow(
                'Email',
                driver.email,
                icon: LucideIcons.mail,
                isLink: true,
              ),
              _buildInfoRow(
                'Téléphone',
                driver.phone,
                icon: LucideIcons.phone,
                isLink: true,
              ),
              _buildInfoRow(
                'Date de naissance',
                '${driver.birthDate.day.toString().padLeft(2, '0')}/${driver.birthDate.month.toString().padLeft(2, '0')}/${driver.birthDate.year}',
              ),
              _buildInfoRow(
                'Adresse',
                driver.address,
                icon: LucideIcons.mapPin,
              ),
              _buildInfoRow('Ville', driver.city),
              _buildInfoRow('Code postal', driver.postalCode),
              _buildInfoRow('Pays', driver.country, icon: LucideIcons.globe),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalInfoSection() {
    final licenseStatus = driver.isLicenseValid
        ? ('Valide', SHTTColors.secondary)
        : ('Expirée', SHTTColors.critical);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Informations professionnelles'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHTTColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                'Date d\'embauche',
                '${driver.hireDate.day.toString().padLeft(2, '0')}/${driver.hireDate.month.toString().padLeft(2, '0')}/${driver.hireDate.year}',
                icon: LucideIcons.calendar,
              ),
              _buildInfoRow(
                'Expérience',
                driver.experience,
                icon: LucideIcons.clock,
              ),
              _buildInfoRow(
                'Licence',
                driver.licenseCategoryDisplay,
                icon: LucideIcons.contact,
              ),
              _buildInfoRow(
                'N° licence',
                driver.licenseNumber,
                icon: LucideIcons.creditCard,
              ),
              _buildInfoRow(
                'Expiration licence',
                '${driver.licenseExpiryDate.day.toString().padLeft(2, '0')}/${driver.licenseExpiryDate.month.toString().padLeft(2, '0')}/${driver.licenseExpiryDate.year}',
                icon: LucideIcons.calendarClock,
              ),
              _buildInfoRow(
                'Statut licence',
                licenseStatus.$1,
                icon: LucideIcons.shield,
                color: licenseStatus.$2,
              ),
              _buildInfoRow(
                'Salaire mensuel',
                '${driver.monthlySalary.toStringAsFixed(2)} TND',
                icon: LucideIcons.banknote,
              ),
              _buildInfoRow(
                'Statut',
                driver.statusDisplay,
                icon: LucideIcons.activity,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSection() {
    final vehicle = driver.assignedVehicle!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Camion assigné'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHTTColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                'Immatriculation',
                vehicle.plate,
                icon: LucideIcons.truck,
                isLink: true,
              ),
              _buildInfoRow(
                'Marque/Modèle',
                '${vehicle.brand} ${vehicle.model}',
              ),
              _buildInfoRow('Année', vehicle.year.toString()),
              _buildInfoRow(
                'Kilométrage',
                '${vehicle.mileage.toStringAsFixed(0)} km',
              ),
              _buildInfoRow('État', vehicle.status),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Statistiques'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHTTColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              isMobile
                  ? Column(
                      children: [
                        _buildStatCard(
                          'Total voyages',
                          driver.totalTrips.toString(),
                          LucideIcons.navigation,
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          'Ce mois',
                          driver.monthlyTrips.toString(),
                          LucideIcons.calendar,
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          'Cette semaine',
                          driver.weeklyTrips.toString(),
                          LucideIcons.clock,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total voyages',
                            driver.totalTrips.toString(),
                            LucideIcons.navigation,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Ce mois',
                            driver.monthlyTrips.toString(),
                            LucideIcons.calendar,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Cette semaine',
                            driver.weeklyTrips.toString(),
                            LucideIcons.clock,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 12),
              isMobile
                  ? Column(
                      children: [
                        _buildStatCard(
                          'Kilométrage total',
                          '${driver.totalMileage.toStringAsFixed(0)} km',
                          LucideIcons.gauge,
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          'Ce mois',
                          '${driver.monthlyMileage.toStringAsFixed(0)} km',
                          LucideIcons.gauge,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Kilométrage total',
                            '${driver.totalMileage.toStringAsFixed(0)} km',
                            LucideIcons.gauge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Ce mois',
                            '${driver.monthlyMileage.toStringAsFixed(0)} km',
                            LucideIcons.gauge,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 12),
              isMobile
                  ? Column(
                      children: [
                        _buildStatCard(
                          'Revenu total',
                          '${driver.totalRevenue.toStringAsFixed(0)} TND',
                          LucideIcons.banknote,
                        ),
                        const SizedBox(height: 8),
                        _buildStatCard(
                          'Ce mois',
                          '${driver.monthlyRevenue.toStringAsFixed(0)} TND',
                          LucideIcons.banknote,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Revenu total',
                            '${driver.totalRevenue.toStringAsFixed(0)} TND',
                            LucideIcons.banknote,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Ce mois',
                            '${driver.monthlyRevenue.toStringAsFixed(0)} TND',
                            LucideIcons.banknote,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SHTTColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Notation moyenne:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    StarRating(
                      rating: driver.rating,
                      count: driver.ratingCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SHTTColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: SHTTColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SHTTColors.textDark,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: SHTTColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Documents'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHTTColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: driver.documents.isEmpty
              ? Center(
                  child: Text(
                    'Aucun document disponible',
                    style: TextStyle(color: SHTTColors.textGrey),
                  ),
                )
              : Column(
                  children: driver.documents.map((doc) {
                    return ListTile(
                      leading: Icon(
                        LucideIcons.fileText,
                        color: SHTTColors.primary,
                      ),
                      title: Text(doc.name),
                      subtitle: Text(
                        '${doc.type} • ${_formatDate(doc.uploadDate)}',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          LucideIcons.download,
                          color: SHTTColors.textGrey,
                        ),
                        onPressed: () {
                          // TODO: Télécharger le document
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTripHistorySection() {
    final trips = driver.tripHistory.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Historique des voyages récents'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHTTColors.backgroundGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: trips.isEmpty
              ? Center(
                  child: Text(
                    'Aucun voyage enregistré',
                    style: TextStyle(color: SHTTColors.textGrey),
                  ),
                )
              : Column(
                  children: trips.map((trip) {
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SHTTColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.navigation,
                          color: SHTTColors.primary,
                          size: 16,
                        ),
                      ),
                      title: Text(trip.destination),
                      subtitle: Text(
                        '${trip.vehiclePlate ?? 'N/A'} • ${_formatDate(trip.date)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${trip.revenue.toStringAsFixed(0)} TND',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: SHTTColors.secondary,
                            ),
                          ),
                          Text(
                            '${trip.mileage.toStringAsFixed(0)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: SHTTColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SHTTColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Télécharger le rapport
              Navigator.of(context).pop();
            },
            icon: const Icon(LucideIcons.download, size: 16),
            label: const Text('Télécharger rapport'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SHTTColors.textGrey,
              side: const BorderSide(color: SHTTColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const Icon(LucideIcons.pencil, size: 16),
            label: const Text('Éditer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.backgroundGrey,
              foregroundColor: SHTTColors.textDark,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
