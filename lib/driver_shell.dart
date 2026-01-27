import 'package:flutter/material.dart';
import 'features/driver/vouchers/pages/vouchers_home_page.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  final _pages = const [
    _DriverTodayTripsPage(),
    VouchersHomePage(),
    _DriverProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SHTT Chauffeur')),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Trajets'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Bons'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _DriverTodayTripsPage extends StatelessWidget {
  const _DriverTodayTripsPage();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Trajets du jour - Placeholder'),
      ),
    );
  }
}

class _DriverProfilePage extends StatelessWidget {
  const _DriverProfilePage();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Profil chauffeur et notifications - Placeholder'),
      ),
    );
  }
}

