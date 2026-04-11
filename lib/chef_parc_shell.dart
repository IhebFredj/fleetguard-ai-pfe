// lib/chef_parc_shell.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'features/chef_parc/dashboard/chef_parc_dashboard.dart';
import 'features/chef_parc/expenses/add_expense_screen.dart';
import 'features/chef_parc/expenses/expense_history_screen.dart';
import 'features/profile/profile_page.dart';

// ─────────────────────────────────────────────────────────
//  Color palette
// ─────────────────────────────────────────────────────────
const _kSurface = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kPrimary = Color(0xFF3B82F6);
const _kTextSecondary = Color(0xFF94A3B8);

class ChefParcShell extends StatefulWidget {
  const ChefParcShell({super.key});

  @override
  State<ChefParcShell> createState() => _ChefParcShellState();
}

class _ChefParcShellState extends State<ChefParcShell> {
  int _index = 0;

  final _pages = <Widget>[
    const ChefParcDashboard(),
    const AddExpenseScreen(),
    const ExpenseHistoryScreen(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(
          top: BorderSide(
            color: _kPrimary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, LucideIcons.home, 'Accueil'),
              _navItem(1, LucideIcons.plusCircle, 'Dépense'),
              _navItem(2, LucideIcons.history, 'Historique'),
              _navItem(3, LucideIcons.user, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _index == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _index = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? _kPrimary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isActive ? _kPrimary : _kTextSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? _kPrimary : _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
