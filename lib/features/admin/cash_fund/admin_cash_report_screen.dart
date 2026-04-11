// lib/features/admin/cash_fund/admin_cash_report_screen.dart
// Écran admin : rapport des dépenses Chef de Parc + rechargement du fond

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chef_parc/providers/cash_fund_provider.dart';
import '../../chef_parc/expenses/expense_detail_sheet.dart';

// ─────────────────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────────────────
const _kBg = Color(0xFF0F172A);
const _kSurface = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kPrimary = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kDanger = Color(0xFFEF4444);
const _kWarning = Color(0xFFF59E0B);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);
const _kBorder = Color(0xFF2D3748);

class AdminCashReportScreen extends ConsumerStatefulWidget {
  const AdminCashReportScreen({super.key});

  @override
  ConsumerState<AdminCashReportScreen> createState() =>
      _AdminCashReportScreenState();
}

class _AdminCashReportScreenState
    extends ConsumerState<AdminCashReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fundsAsync = ref.watch(allFundsProvider);
    final expensesAsync = ref.watch(allExpensesProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        title: Text(
          'Gestion Fond de Caisse',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kPrimary,
          labelColor: _kPrimary,
          unselectedLabelColor: _kTextSecondary,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(LucideIcons.barChart2, size: 16), text: 'Rapport'),
            Tab(icon: Icon(LucideIcons.listOrdered, size: 16), text: 'Historique'),
            Tab(icon: Icon(LucideIcons.refreshCcw, size: 16), text: 'Recharger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportTab(fundsAsync, expensesAsync),
          _buildHistoryTab(expensesAsync),
          _buildReloadTab(fundsAsync),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  TAB 1 : Rapport Global
  // ═══════════════════════════════════════
  Widget _buildReportTab(
    AsyncValue<List<CashFund>> fundsAsync,
    AsyncValue<List<CashExpense>> expensesAsync,
  ) {
    return fundsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: _kDanger))),
      data: (funds) {
        if (funds.isEmpty) {
          return _emptyState('Aucun fond de caisse trouvé', LucideIcons.wallet);
        }

        // Global stats
        final totalInitial = funds.fold(0.0, (s, f) => s + f.initialAmount);
        final totalBalance = funds.fold(0.0, (s, f) => s + f.currentBalance);
        final totalSpent = totalInitial - totalBalance;
        final alertFunds = funds.where((f) => f.isAlert).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Global KPI cards
              Row(
                children: [
                  Expanded(child: _kpiCard('Fond Total', '${totalInitial.toStringAsFixed(0)} DT', LucideIcons.wallet, _kPrimary)),
                  const SizedBox(width: 12),
                  Expanded(child: _kpiCard('Dépensé', '${totalSpent.toStringAsFixed(0)} DT', LucideIcons.arrowUpRight, _kWarning)),
                  const SizedBox(width: 12),
                  Expanded(child: _kpiCard('Restant', '${totalBalance.toStringAsFixed(0)} DT', LucideIcons.piggyBank, _kAccent)),
                ],
              ),
              const SizedBox(height: 16),

              // Alert banner
              if (alertFunds.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _kDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kDanger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: _kDanger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${alertFunds.length} fond(s) en alerte (solde ≤ 50 DT) !',
                          style: GoogleFonts.inter(
                            color: _kDanger,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _tabController.animateTo(2),
                        child: const Text('Recharger', style: TextStyle(color: _kDanger)),
                      ),
                    ],
                  ),
                ),

              // Per-fund cards
              _sectionTitle('Par Chef de Parc'),
              const SizedBox(height: 8),
              ...funds.map((fund) => _fundCard(fund)),

              // Expenses by category
              const SizedBox(height: 16),
              expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
                error: (e, _) => const SizedBox.shrink(),
                data: (expenses) => _buildCategoryChart(expenses),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _fundCard(CashFund fund) {
    final pct = fund.percentRemaining.clamp(0, 100) / 100;
    final barColor = fund.isAlert
        ? _kDanger
        : pct < 0.3
            ? _kWarning
            : _kAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fund.isAlert ? _kDanger.withValues(alpha: 0.4) : _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.userCheck, color: barColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fund.chefEmail,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${fund.currentBalance.toStringAsFixed(2)} DT / ${fund.initialAmount.toStringAsFixed(2)} DT',
                      style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                    ),
                  ],
                ),
              ),
              if (fund.isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Alerte',
                    style: TextStyle(color: _kDanger, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: _kBg,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${fund.percentRemaining.toStringAsFixed(1)}% restant',
                style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary),
              ),
              Text(
                'Dépensé: ${fund.totalSpent.toStringAsFixed(2)} DT',
                style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(List<CashExpense> expenses) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    // Group by category
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    final total = map.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Répartition par catégorie'),
        const SizedBox(height: 8),
        ...sorted.map((entry) {
          final cat = getCategoryByKey(entry.key);
          final pct = entry.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: GoogleFonts.inter(fontSize: 13, color: _kTextPrimary),
                      ),
                    ),
                    Text(
                      '${entry.value.toStringAsFixed(2)} DT (${(pct * 100).toStringAsFixed(1)}%)',
                      style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: _kBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(cat.colorValue)),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════
  //  TAB 2 : Historique complet
  // ═══════════════════════════════════════
  Widget _buildHistoryTab(AsyncValue<List<CashExpense>> expensesAsync) {
    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: _kDanger))),
      data: (expenses) {
        if (expenses.isEmpty) {
          return _emptyState('Aucune dépense enregistrée', LucideIcons.receipt);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: expenses.length,
          itemBuilder: (context, i) {
            final e = expenses[i];
            final cat = getCategoryByKey(e.category);
            return GestureDetector(
              onTap: () => showExpenseDetailSheet(context, e),
              child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(cat.colorValue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description ?? cat.label,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(e.expenseDate),
                          style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary),
                        ),
                        if (e.createdBy != null)
                          Text(
                            'Par: ${e.createdBy}',
                            style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '-${e.amount.toStringAsFixed(2)} DT',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kDanger,
                        ),
                      ),
                      if (e.receiptUrl != null)
                        const Icon(LucideIcons.paperclip, size: 12, color: _kTextSecondary),
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════
  //  TAB 3 : Recharger un Fond
  // ═══════════════════════════════════════
  Widget _buildReloadTab(AsyncValue<List<CashFund>> fundsAsync) {
    return fundsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: _kDanger))),
      data: (funds) {
        if (funds.isEmpty) {
          return _emptyState('Aucun fond de caisse trouvé', LucideIcons.wallet);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Alert funds first
            if (funds.any((f) => f.isAlert)) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _kDanger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kDanger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.bell, color: _kDanger, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Fonds en alerte — rechargement urgent',
                      style: GoogleFonts.inter(
                        color: _kDanger,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ...funds.map((fund) => _ReloadCardWidget(
                  key: ValueKey(fund.id),
                  fund: fund,
                  onReload: (amount, note) => _doReload(fund, amount, note),
                )),
          ],
        );
      },
    );
  }

  Future<void> _doReload(CashFund fund, double amount, String? note) async {
    try {
      final newBalance = fund.currentBalance + amount;
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'admin';

      await Supabase.instance.client.from('cash_reloads').insert({
        'fund_id': fund.id,
        'amount': amount,
        'reloaded_by': adminEmail,
        'note': (note == null || note.isEmpty) ? null : note,
      });

      await Supabase.instance.client.from('cash_funds').update({
        'current_balance': newBalance,
        'initial_amount': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', fund.id);

      _showSnack(
        '✅ +${amount.toStringAsFixed(2)} DT rechargés ! Nouveau solde: ${newBalance.toStringAsFixed(2)} DT',
        _kAccent,
      );

      ref.invalidate(allFundsProvider);
      ref.invalidate(cashFundProvider);
    } catch (e) {
      _showSnack('Erreur: $e', _kDanger);
    }
  }

  // ═══════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════
  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kTextSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: _kTextSecondary),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 15)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour}h${d.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  _ReloadCardWidget — StatefulWidget avec gestion propre des controllers
// ─────────────────────────────────────────────────────────
class _ReloadCardWidget extends StatefulWidget {
  final CashFund fund;
  final Future<void> Function(double amount, String? note) onReload;

  const _ReloadCardWidget({
    super.key,
    required this.fund,
    required this.onReload,
  });

  @override
  State<_ReloadCardWidget> createState() => _ReloadCardWidgetState();
}

class _ReloadCardWidgetState extends State<_ReloadCardWidget> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un montant valide'), backgroundColor: _kDanger),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await widget.onReload(amount, _noteCtrl.text.trim());
      _amountCtrl.clear();
      _noteCtrl.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fund = widget.fund;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fund.isAlert ? _kDanger.withValues(alpha: 0.4) : _kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.user, color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fund.chefEmail,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fund.isAlert ? _kDanger.withValues(alpha: 0.12) : _kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${fund.currentBalance.toStringAsFixed(2)} DT',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: fund.isAlert ? _kDanger : _kAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _kTextPrimary),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: GoogleFonts.poppins(fontSize: 20, color: _kTextSecondary.withValues(alpha: 0.3)),
              suffixText: 'DT',
              labelText: 'Montant à recharger',
              labelStyle: GoogleFonts.inter(color: _kTextSecondary, fontSize: 13),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            style: GoogleFonts.inter(fontSize: 13, color: _kTextPrimary),
            decoration: InputDecoration(
              hintText: 'Note / Motif de rechargement',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: _kSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.refreshCcw, size: 18),
              label: Text(
                _isLoading ? 'Rechargement...' : 'Recharger le fond',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
