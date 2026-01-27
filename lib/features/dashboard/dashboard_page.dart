import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Dashboard flotte (carte, KPI, alertes) - Placeholder',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
