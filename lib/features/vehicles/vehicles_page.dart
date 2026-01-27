import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleetguard/core/providers.dart';
import 'package:fleetguard/widgets/tunisian_plate.dart';
import 'package:fleetguard/screens/obd_live_screen.dart';

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trucks = ref.watch(trucksProvider);

    // Return a plain list to fit into AppShell's Scaffold body
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: trucks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = trucks[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTruckOptions(context, t.plate, t.id),
          child: TunisianPlate(
            plate: t.plate,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        );
      },
    );
  }
}

void _showTruckOptions(BuildContext context, String plate, String id) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 20),
                    const SizedBox(width: 8),
                    Text('Options — $plate', style: textTheme.titleMedium),
                    const Spacer(),
                    Text('#$id', style: textTheme.bodySmall?.copyWith(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 12),

                // Categorie: Informations
                Text('Informations', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                _OptionTile(
                  icon: Icons.info_outline,
                  title: 'Détails du camion',
                  subtitle: 'Modèle, statut, documents',
                  onTap: () => _toast(ctx, 'Détails – $plate'),
                ),
                _OptionTile(
                  icon: Icons.assignment_outlined,
                  title: 'Historique',
                  subtitle: 'Interventions, incidents, amendes',
                  onTap: () => _toast(ctx, 'Historique – $plate'),
                ),
                const Divider(height: 20),

                // Categorie: Exploitation
                Text('Exploitation', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                _OptionTile(
                  icon: Icons.route,
                  title: 'Trajets',
                  subtitle: 'Derniers trajets et planification',
                  onTap: () => _toast(ctx, 'Trajets – $plate'),
                ),
                _OptionTile(
                  icon: Icons.speed,
                  title: 'OBD2 Live Monitor',
                  subtitle: 'Suivi moteur en temps réel',
                  onTap: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => OBDLiveScreen(camionId: id, plate: plate),
                      ),
                    );
                  },
                ),
                _OptionTile(
                  icon: Icons.engineering_outlined,
                  title: 'Maintenance',
                  subtitle: 'Préventive et corrective',
                  onTap: () => _toast(ctx, 'Maintenance – $plate'),
                ),
                _OptionTile(
                  icon: Icons.location_searching,
                  title: 'Localisation',
                  subtitle: 'Voir sur la carte',
                  onTap: () => _toast(ctx, 'Localisation – $plate'),
                ),
                const Divider(height: 20),

                // Categorie: Partage & admin
                Text('Partage & Administration', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                _OptionTile(
                  icon: Icons.share_outlined,
                  title: 'Partager',
                  subtitle: 'Envoyer le lien/rapport',
                  onTap: () => _toast(ctx, 'Partager – $plate'),
                ),
                _OptionTile(
                  icon: Icons.delete_outline,
                  title: 'Retirer du parc',
                  subtitle: 'Désactiver ou supprimer',
                  danger: true,
                  onTap: () => _toast(ctx, 'Retirer – $plate'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Colors.black87;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
