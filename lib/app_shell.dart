import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/vehicles/vehicles_page.dart';
import 'features/profile/profile_page.dart';
import 'features/drivers/drivers_page.dart';
import 'widgets/navigation_sidebar.dart' hide NavigationDrawer;
import 'widgets/navigation_sidebar.dart' as nav show NavigationDrawer;

/// Couleurs SHTT – Design system
class _SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const background = Color(0xFFFFFFFF);
  static const error = Color(0xFFEF4444);
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  bool _isSidebarCompact = false;

  final List<Widget> _pages = [
    const DashboardPage(),
    const Center(child: Text('Carte GPS')), // Carte GPS placeholder
    const VehiclesPage(),
    const DriversPage(), // Page de gestion des chauffeurs
    const Center(child: Text('Statistiques')), // Statistiques placeholder
    const ProfilePage(), // Paramètres/Profil
  ];

  String get _pageTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Carte GPS';
      case 2:
        return 'Véhicules';
      case 3:
        return 'Chauffeurs';
      case 4:
        return 'Statistiques';
      case 5:
        return 'Paramètres';
      default:
        return 'SHTT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 768 && screenWidth <= 1024;

    // Desktop: Always show sidebar with option to collapse
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationSidebar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              isCompact: _isSidebarCompact,
            ),
            Expanded(
              child: Column(
                children: [
                  _buildDesktopAppBar(),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tablet: Collapsible sidebar with hamburger menu
    if (isTablet) {
      return Scaffold(
        appBar: _buildMobileAppBar(showHamburger: true),
        drawer: nav.NavigationDrawer(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
        body: _pages[_selectedIndex],
      );
    }

    // Mobile: Bottom navigation with drawer option
    return Scaffold(
      appBar: _buildMobileAppBar(showHamburger: true),
      drawer: nav.NavigationDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < 5 ? _selectedIndex : 0,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: _SHTTColors.background,
        indicatorColor: _SHTTColors.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Carte',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Véhicules',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Chauffeurs',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDesktopAppBar() {
    return AppBar(
      backgroundColor: _SHTTColors.background,
      elevation: 0,
      toolbarHeight: 70,
      title: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarCompact ? Icons.chevron_right : Icons.chevron_left,
              color: _SHTTColors.textGrey,
            ),
            onPressed: () {
              setState(() {
                _isSidebarCompact = !_isSidebarCompact;
              });
            },
          ),
          const SizedBox(width: 16),
          Text(
            _pageTitle,
            style: const TextStyle(
              color: _SHTTColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: _SHTTColors.textGrey),
          onPressed: () {},
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: _SHTTColors.textGrey,
              ),
              onPressed: () {},
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _SHTTColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  PreferredSizeWidget _buildMobileAppBar({required bool showHamburger}) {
    return AppBar(
      backgroundColor: _SHTTColors.primary,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(LucideIcons.truck, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'SHTT',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }
}
