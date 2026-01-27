import 'package:flutter/material.dart';
import 'travel_voucher_new_page.dart';
import 'receipt_voucher_new_page.dart';
import 'fuel_voucher_new_page.dart';
import 'voucher_history_page.dart';

class VouchersHomePage extends StatelessWidget {
  const VouchersHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardAction(
          icon: Icons.directions_car_filled,
          title: 'Bon de voyage',
          subtitle: "Créer un bon pour le trajet (GPS + photo + signature)",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TravelVoucherNewPage()),
          ),
        ),
        const SizedBox(height: 12),
        _CardAction(
          icon: Icons.assignment_turned_in,
          title: 'Bon de réception',
          subtitle: "Ajouter la réception chez le client (poids livré, photo)",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReceiptVoucherNewPage()),
          ),
        ),
        const SizedBox(height: 12),
        _CardAction(
          icon: Icons.local_gas_station,
          title: 'Bon de gasoil',
          subtitle: "Saisir un plein avec ticket et position",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FuelVoucherNewPage()),
          ),
        ),
        const SizedBox(height: 24),
        _CardAction(
          icon: Icons.history,
          title: 'Historique',
          subtitle: "Consulter, filtrer et partager les bons",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VoucherHistoryPage()),
          ),
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
