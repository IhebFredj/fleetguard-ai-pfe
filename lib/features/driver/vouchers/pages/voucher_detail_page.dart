import 'package:flutter/material.dart';

class VoucherDetailPage extends StatelessWidget {
  final String id;
  const VoucherDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bon $id')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Détails du bon - Placeholder'),
        ),
      ),
    );
  }
}
