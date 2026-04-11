// lib/features/chef_parc/dashboard/chef_parc_dashboard.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth.dart';
import '../providers/cash_fund_provider.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expense_history_screen.dart';

// ─────────────────────────────────────────────────────────
//  Color palette
// ─────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kDanger = Color(0xFFEF4444);
const _kWarning = Color(0xFFF97316);
const _kSurface = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kCardLight = Color(0xFF2D3348);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);

class ChefParcDashboard extends ConsumerStatefulWidget {
  const ChefParcDashboard({super.key});

  @override
  ConsumerState<ChefParcDashboard> createState() => _ChefParcDashboardState();
}

class _ChefParcDashboardState extends ConsumerState<ChefParcDashboard> {
  @override
  Widget build(BuildContext context) {
    final fundAsync = ref.watch(cashFundProvider);
    final expensesAsync = ref.watch(cashExpensesProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cashFundProvider);
            ref.invalidate(cashExpensesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                _buildHeader(user),
                const SizedBox(height: 24),

                // ── Balance Card ──
                fundAsync.when(
                  data: (fund) {
                    if (fund == null) return _buildNoFundCard();
                    return _buildBalanceCard(fund);
                  },
                  loading: () => _buildLoadingCard(),
                  error: (e, _) => _buildErrorCard(e.toString()),
                ),
                const SizedBox(height: 20),

                // ── Quick Actions ──
                _buildQuickActions(),
                const SizedBox(height: 24),

                // ── Recent Expenses ──
                Text(
                  'Dépenses récentes',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) return _buildNoExpensesCard();
                    final recent = expenses.take(5).toList();
                    return Column(
                      children: recent
                          .map((e) => _buildExpenseItem(e))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: _kPrimary),
                    ),
                  ),
                  error: (e, _) => _buildErrorCard(e.toString()),
                ),
                const SizedBox(height: 16),

                // ── Category Summary ──
                expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) return const SizedBox.shrink();
                    return _buildCategorySummary(expenses);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Header
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader(User? user) {
    final greeting = _getGreeting();
    final name = user?.displayName ?? 'Chef de Parc';

    return Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_kPrimary, Color(0xFF8B5CF6)],
            ),
            image: user?.photoURL != null
                ? DecorationImage(
                    image: NetworkImage(user!.photoURL!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: user?.photoURL == null
              ? Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting 👋',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _kTextSecondary,
                ),
              ),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Admin Mode Shortcut / Back Button (for Developer testing)
        if (ref.watch(userRoleProvider).value == UserRole.developer)
          IconButton(
            tooltip: 'Retour mode Admin',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(LucideIcons.shield, color: _kPrimary, size: 22),
          ),
        
        // Logout / Quit Button
        IconButton(
          onPressed: () async {
            // Pour le Développeur : Retourner au tableau de bord principal au lieu de déconnecter complètement
            if (ref.read(userRoleProvider).value == UserRole.developer) {
              Navigator.of(context).maybePop();
              return;
            }

            // Déconnexion normale pour les autres
            await GoogleSignIn().signOut();
            await FirebaseAuth.instance.signOut();
          },
          icon: Icon(
            ref.watch(userRoleProvider).value == UserRole.developer 
                ? LucideIcons.chevronLeft
                : LucideIcons.logOut, 
            color: _kTextSecondary, 
            size: 22
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  // ─────────────────────────────────────────────────────────
  //  Balance Card (Glassmorphism)
  // ─────────────────────────────────────────────────────────
  Widget _buildBalanceCard(CashFund fund) {
    final percent = fund.percentRemaining.clamp(0, 100).toDouble();
    final balanceColor = fund.isAlert
        ? _kDanger
        : percent < 30
            ? _kWarning
            : _kAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kCard,
            _kCardLight.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: fund.isAlert
              ? _kDanger.withValues(alpha: 0.5)
              : _kPrimary.withValues(alpha: 0.15),
          width: fund.isAlert ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (fund.isAlert ? _kDanger : _kPrimary).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(LucideIcons.wallet, color: balanceColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Fond de Caisse',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextSecondary,
                ),
              ),
              const Spacer(),
              if (fund.isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kDanger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kDanger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: _kDanger, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Solde faible !',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kDanger,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Balance amount
          Text(
            '${fund.currentBalance.toStringAsFixed(2)} DT',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: balanceColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'sur ${fund.initialAmount.toStringAsFixed(0)} DT attribués',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _kTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: _kSurface.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(balanceColor),
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _miniStat('Dépensé', '${fund.totalSpent.toStringAsFixed(0)} DT',
                  _kDanger),
              const SizedBox(width: 24),
              _miniStat('Reste', '${percent.toStringAsFixed(0)}%', balanceColor),
              const SizedBox(width: 24),
              _miniStat(
                  'Alerte', '< ${fund.alertThreshold.toStringAsFixed(0)} DT',
                  _kWarning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Quick Actions
  // ─────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: LucideIcons.plusCircle,
            title: 'Ajouter\nDépense',
            color: _kPrimary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddExpenseScreen()),
              ).then((_) {
                ref.invalidate(cashFundProvider);
                ref.invalidate(cashExpensesProvider);
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: LucideIcons.history,
            title: 'Historique\nDépenses',
            color: _kAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ExpenseHistoryScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: LucideIcons.refreshCw,
            title: 'Actualiser\nSolde',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              ref.invalidate(cashFundProvider);
              ref.invalidate(cashExpensesProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Expense Item
  // ─────────────────────────────────────────────────────────
  Widget _buildExpenseItem(CashExpense expense) {
    final cat = getCategoryByKey(expense.category);
    final date = expense.expenseDate;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Color(cat.colorValue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expense.description ?? dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _kTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${expense.amount.toStringAsFixed(2)} DT',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kDanger,
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary),
              ),
            ],
          ),
          if (expense.receiptUrl != null) ...[
            const SizedBox(width: 8),
            Icon(LucideIcons.paperclip, size: 14, color: _kPrimary),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Category Summary
  // ─────────────────────────────────────────────────────────
  Widget _buildCategorySummary(List<CashExpense> expenses) {
    // Group by category
    final Map<String, double> totals = {};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalSpent = totals.values.fold(0.0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Répartition par catégorie',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.map((entry) {
          final cat = getCategoryByKey(entry.key);
          final percent =
              totalSpent > 0 ? (entry.value / totalSpent * 100) : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 5,
                          backgroundColor: _kSurface,
                          valueColor: AlwaysStoppedAnimation(
                              Color(cat.colorValue)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${entry.value.toStringAsFixed(0)} DT',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(cat.colorValue),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Placeholder cards
  // ─────────────────────────────────────────────────────────
  Widget _buildNoFundCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kWarning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.walletCards, color: _kWarning, size: 48),
          const SizedBox(height: 16),
          Text(
            'Aucun fond de caisse',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'L\'administrateur n\'a pas encore créé de fond de caisse pour votre compte. Contactez-le pour commencer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoExpensesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.receipt, color: _kTextSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            'Aucune dépense enregistrée',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _kPrimary),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDanger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.alertCircle, color: _kDanger, size: 32),
          const SizedBox(height: 8),
          Text(
            'Erreur: $error',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }
}
