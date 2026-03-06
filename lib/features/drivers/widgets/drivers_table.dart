import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver.dart';
import '../providers/driver_provider.dart';
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

/// Tableau des chauffeurs
class DriversTable extends ConsumerWidget {
  final List<Driver> drivers;
  final Function(Driver) onView;
  final Function(Driver) onEdit;
  final Function(Driver) onDelete;
  final Function(Driver, DriverStatus) onStatusChange;

  const DriversTable({
    super.key,
    required this.drivers,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  void _callDriver(String phoneNumber) async {
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _smsDriver(String phoneNumber) async {
    final Uri url = Uri.parse('sms:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDrivers = ref.watch(selectedDriversProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    if (drivers.isEmpty) {
      return _buildEmptyState();
    }

    // Liste pour tous les formats d'écran
    return _buildList(ref, selectedDrivers, isDesktop);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.users,
            size: 64,
            color: SHTTColors.textGrey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun chauffeur trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SHTTColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres ou ajoutez un nouveau chauffeur',
            style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    WidgetRef ref,
    Set<String> selectedDrivers,
    bool isDesktop,
  ) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final isSelected = selectedDrivers.contains(driver.id);

        return _buildCard(context, ref, driver, isSelected, isDesktop);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    Driver driver,
    bool isSelected,
    bool isDesktop,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
      elevation: isDesktop ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? SHTTColors.primary : SHTTColors.border,
        ),
      ),
      child: InkWell(
        onTap: () => onView(driver),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          child: isDesktop
              ? _buildDesktopCardContent(context, ref, driver, isSelected)
              : _buildMobileCardContent(context, ref, driver, isSelected),
        ),
      ),
    );
  }

  Widget _buildMobileCardContent(
    BuildContext context,
    WidgetRef ref,
    Driver driver,
    bool isSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) {
                ref
                    .read(selectedDriversProvider.notifier)
                    .toggleSelection(driver.id);
              },
              activeColor: SHTTColors.primary,
            ),
            _buildAvatar(driver),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    driver.driverId,
                    style: TextStyle(fontSize: 12, color: SHTTColors.textGrey),
                  ),
                ],
              ),
            ),
            DriverStatusBadge(status: driver.status, size: 'small'),
          ],
        ),
        const Divider(height: 24),
        _buildInfoRow(LucideIcons.phone, driver.phone),
        const SizedBox(height: 8),
        _buildInfoRow(LucideIcons.mail, driver.email),
        const SizedBox(height: 8),
        _buildInfoRow(LucideIcons.clock, driver.experience),
        const SizedBox(height: 8),
        Row(
          children: [
            StarRating(
              rating: driver.rating,
              count: driver.ratingCount,
              size: 14,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (driver.assignedVehicle != null)
          _buildInfoRow(
            LucideIcons.truck,
            driver.assignedVehicle!.plate,
            color: SHTTColors.primary,
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(
              LucideIcons.phone,
              SHTTColors.secondary,
              () => _callDriver(driver.phone),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              LucideIcons.messageSquare,
              SHTTColors.primary,
              () => _smsDriver(driver.phone),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              LucideIcons.eye,
              SHTTColors.textGrey,
              () => onView(driver),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              LucideIcons.pencil,
              SHTTColors.accent,
              () => onEdit(driver),
            ),
            const SizedBox(width: 8),
            _buildMoreMenu(context, driver),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopCardContent(
    BuildContext context,
    WidgetRef ref,
    Driver driver,
    bool isSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) {
                ref
                    .read(selectedDriversProvider.notifier)
                    .toggleSelection(driver.id);
              },
              activeColor: SHTTColors.primary,
            ),
            _buildAvatar(driver),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    driver.driverId,
                    style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildInfoRow(LucideIcons.phone, driver.phone),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildInfoRow(LucideIcons.mail, driver.email),
            ),
            const SizedBox(width: 16),
            DriverStatusBadge(status: driver.status),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: StarRating(
                rating: driver.rating,
                count: driver.ratingCount,
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            _buildActionButtons(context, driver),
          ],
        ),
        if (driver.assignedVehicle != null) ...[
          const Divider(height: 20),
          Row(
            children: [
              const SizedBox(width: 72),
              Icon(LucideIcons.truck, size: 16, color: SHTTColors.primary),
              const SizedBox(width: 8),
              Text(
                'Véhicule assigné: ${driver.assignedVehicle!.brand} ${driver.assignedVehicle!.model} - ${driver.assignedVehicle!.plate}',
                style: const TextStyle(
                  fontSize: 14,
                  color: SHTTColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? SHTTColors.textGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: color ?? SHTTColors.textDark),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(Driver driver) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: SHTTColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: driver.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                driver.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(driver),
              ),
            )
          : _buildInitials(driver),
    );
  }

  Widget _buildInitials(Driver driver) {
    return Center(
      child: Text(
        driver.initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SHTTColors.primary,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Driver driver) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          LucideIcons.phone,
          SHTTColors.secondary,
          () => _callDriver(driver.phone),
        ),
        const SizedBox(width: 4),
        _buildActionButton(
          LucideIcons.messageSquare,
          SHTTColors.primary,
          () => _smsDriver(driver.phone),
        ),
        const SizedBox(width: 4),
        _buildActionButton(
          LucideIcons.eye,
          SHTTColors.textGrey,
          () => onView(driver),
        ),
        const SizedBox(width: 4),
        _buildActionButton(
          LucideIcons.pencil,
          SHTTColors.accent,
          () => onEdit(driver),
        ),
        const SizedBox(width: 4),
        _buildMoreMenu(context, driver),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, Driver driver) {
    return PopupMenuButton<String>(
      icon: Icon(
        LucideIcons.moreVertical,
        size: 16,
        color: SHTTColors.textGrey,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'call',
          child: Row(
            children: [
              Icon(LucideIcons.phone, size: 16, color: SHTTColors.secondary),
              const SizedBox(width: 8),
              const Text('Appeler'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sms',
          child: Row(
            children: [
              Icon(
                LucideIcons.messageSquare,
                size: 16,
                color: SHTTColors.primary,
              ),
              const SizedBox(width: 8),
              const Text('Envoyer SMS'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(LucideIcons.eye, size: 16, color: SHTTColors.primary),
              const SizedBox(width: 8),
              const Text('Voir détails'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 16, color: SHTTColors.accent),
              const SizedBox(width: 8),
              const Text('Éditer'),
            ],
          ),
        ),
        if (driver.status != DriverStatus.suspended)
          PopupMenuItem(
            value: 'suspend',
            child: Row(
              children: [
                Icon(
                  LucideIcons.pauseCircle,
                  size: 16,
                  color: SHTTColors.critical,
                ),
                const SizedBox(width: 8),
                const Text('Suspendre'),
              ],
            ),
          ),
        if (driver.status == DriverStatus.suspended ||
            driver.status == DriverStatus.inactive)
          PopupMenuItem(
            value: 'activate',
            child: Row(
              children: [
                Icon(
                  LucideIcons.playCircle,
                  size: 16,
                  color: SHTTColors.secondary,
                ),
                const SizedBox(width: 8),
                const Text('Réactiver'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(LucideIcons.trash2, size: 16, color: SHTTColors.critical),
              const SizedBox(width: 8),
              const Text(
                'Supprimer',
                style: TextStyle(color: SHTTColors.critical),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'call':
            _callDriver(driver.phone);
            break;
          case 'sms':
            _smsDriver(driver.phone);
            break;
          case 'view':
            onView(driver);
            break;
          case 'edit':
            onEdit(driver);
            break;
          case 'suspend':
            onStatusChange(driver, DriverStatus.suspended);
            break;
          case 'activate':
            onStatusChange(driver, DriverStatus.active);
            break;
          case 'delete':
            onDelete(driver);
            break;
        }
      },
    );
  }
}
