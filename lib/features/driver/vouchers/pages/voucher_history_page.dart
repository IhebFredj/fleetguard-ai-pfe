import 'package:flutter/material.dart';
import 'voucher_detail_page.dart';

class VoucherHistoryPage extends StatelessWidget {
  const VoucherHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des bons'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text('Bon #${index + 1}'),
              subtitle: const Text('Type: Voyage | Statut: En attente'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => VoucherDetailPage(id: 'demo-${index + 1}')),
              ),
            ),
          );
        },
      ),
    );
  }
}
