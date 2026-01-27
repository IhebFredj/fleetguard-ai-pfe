import 'package:flutter/material.dart';

class TravelVoucherNewPage extends StatelessWidget {
  const TravelVoucherNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bon de voyage')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Formulaire Bon de voyage - Placeholder'),
        ),
      ),
    );
  }
}
