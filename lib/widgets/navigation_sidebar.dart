import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/auth_state.dart';
import '../core/auth.dart';
import '../features/auth/presentation/login_page.dart';
import 'registration_dialog.dart';

/// Couleurs SHTT - Design system
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1E40AF);
  static const accent = Color(0xFF10B981);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const textLightGrey = Color(0xFF9CA3AF);
  static const background = Color(0xFFFFFFFF);
  static const backgroundGrey = Color(0xFFF9FAFB);
  static const borderGrey = Color(0xFFE5E7EB);
  static const error = Color(0xFFEF4444);
  static const online = Color(0xFF10B981);
  static const offline = Color(0xFF9CA3AF);
}

/// Navigation item model
class NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
  final int? badgeCount;

  const NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.index,
    this.badgeCount,
  });
}

/// Navigation Sidebar Widget
class NavigationSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool isCompact;

  const NavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isCompact = false,
  });

  @override
  ConsumerState<NavigationSidebar> createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends ConsumerState<NavigationSidebar> {
  bool _isHovered = false;

  final List<NavigationItem> _navItems = const [
    NavigationItem(
      label: 'Dashboard',
      icon: LucideIcons.layoutDashboard,
      selectedIcon: LucideIcons.layoutDashboard,
      index: 0,
    ),
    NavigationItem(
      label: 'Carte GPS',
      icon: LucideIcons.map,
      selectedIcon: LucideIcons.map,
      index: 1,
      badgeCount: 3,
    ),
    NavigationItem(
      label: 'Véhicules',
      icon: LucideIcons.truck,
      selectedIcon: LucideIcons.truck,
      index: 2,
    ),
    NavigationItem(
      label: 'Chauffeurs',
      icon: LucideIcons.users,
      selectedIcon: LucideIcons.users,
      index: 3,
      badgeCount: 5,
    ),
    NavigationItem(
      label: 'Statistiques',
      icon: LucideIcons.barChart3,
      selectedIcon: LucideIcons.barChart3,
      index: 4,
    ),
    NavigationItem(
      label: 'Paramètres',
      icon: LucideIcons.settings,
      selectedIcon: LucideIcons.settings,
      index: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userRole = ref.watch(roleProvider);

    return Container(
      width: widget.isCompact ? 80 : 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: SHTTColors.background,
        border: Border(
          right: BorderSide(color: SHTTColors.borderGrey, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header with Logo
          _buildHeader(),

          // Profile Section
          if (!widget.isCompact) _buildProfileSection(user, userRole),

          const Divider(height: 1, color: SHTTColors.borderGrey),

          // Navigation Menu
          Expanded(child: _buildNavigationMenu()),

          const Divider(height: 1, color: SHTTColors.borderGrey),

          // Registration Section
          if (!widget.isCompact) _buildRegistrationSection(),

          if (!widget.isCompact)
            const Divider(height: 1, color: SHTTColors.borderGrey),

          // Logout Button
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: SHTTColors.background,
        border: Border(bottom: BorderSide(color: SHTTColors.borderGrey)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SHTTColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.truck,
              color: SHTTColors.primary,
              size: 24,
            ),
          ),
          if (!widget.isCompact) ...[
            const SizedBox(width: 12),
            const Text(
              'SHTT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: SHTTColors.primaryDark,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileSection(dynamic user, UserRole role) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered ? SHTTColors.borderGrey : SHTTColors.backgroundGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: SHTTColors.primary.withOpacity(0.1),
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl)
                      : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          user?.initials ?? 'U',
                          style: const TextStyle(
                            color: SHTTColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: user?.isOnline ?? false
                          ? SHTTColors.online
                          : SHTTColors.offline,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SHTTColors.background,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: SHTTColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SHTTColors.textGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SHTTColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role == UserRole.admin ? 'Administrateur' : 'Chauffeur',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SHTTColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationMenu() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _navItems.length,
      itemBuilder: (context, index) {
        final item = _navItems[index];
        final isSelected = widget.selectedIndex == item.index;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onDestinationSelected(item.index),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCompact ? 12 : 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SHTTColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: isSelected
                        ? const BorderSide(color: SHTTColors.primary, width: 3)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      size: 20,
                      color: isSelected
                          ? SHTTColors.primary
                          : SHTTColors.textGrey,
                    ),
                    if (!widget.isCompact) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? SHTTColors.primary
                                : SHTTColors.textDark,
                          ),
                        ),
                      ),
                      if (item.badgeCount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SHTTColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegistrationSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajouter un compte',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SHTTColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enregistrer un nouvel utilisateur',
            style: TextStyle(fontSize: 11, color: SHTTColors.textGrey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _showRegistrationDialog(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Nouvel enregistrement',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SHTTColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () => _showLogoutConfirmation(context),
          icon: const Icon(LucideIcons.logOut, size: 18),
          label: widget.isCompact
              ? const SizedBox.shrink()
              : const Text(
                  'Se déconnecter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: SHTTColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  void _showRegistrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RegistrationDialog(),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: SHTTColors.error),
            SizedBox(width: 12),
            Text('Confirmation'),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: SHTTColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Non',
              style: TextStyle(color: SHTTColors.textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performLogout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    final authNotifier = ref.read(authStateProvider.notifier);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await authNotifier.signOut();

    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déconnexion réussie'),
          backgroundColor: SHTTColors.accent,
        ),
      );

      // Navigate to login page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }
}

/// Mobile Drawer version of the sidebar
class NavigationDrawer extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const NavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      width: 280,
      child: NavigationSidebar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          onDestinationSelected(index);
          Navigator.of(context).pop(); // Close drawer
        },
      ),
    );
  }
}
