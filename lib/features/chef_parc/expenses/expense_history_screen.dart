// lib/features/chef_parc/expenses/expense_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/cash_fund_provider.dart';
import 'expense_detail_sheet.dart';

// Colors
const _kPrimary = Color(0xFF3B82F6);
const _kDanger = Color(0xFFEF4444);
const _kSurface = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  String _filterCategory = 'all';
  String _filterPeriod = 'all';

  List<CashExpense> _applyFilters(List<CashExpense> expenses) {
    var filtered = expenses;

    // Category filter
    if (_filterCategory != 'all') {
      filtered = filtered.where((e) => e.category == _filterCategory).toList();
    }

    // Period filter
    final now = DateTime.now();
    switch (_filterPeriod) {
      case 'today':
        filtered = filtered
            .where((e) =>
                e.expenseDate.day == now.day &&
                e.expenseDate.month == now.month &&
                e.expenseDate.year == now.year)
            .toList();
        break;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered =
            filtered.where((e) => e.expenseDate.isAfter(weekAgo)).toList();
        break;
      case 'month':
        filtered = filtered
            .where((e) =>
                e.expenseDate.month == now.month &&
                e.expenseDate.year == now.year)
            .toList();
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(cashExpensesProvider);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: Text('Historique des dépenses',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _kCard,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () => ref.invalidate(cashExpensesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filters ──
          _buildFilters(),

          // ── List ──
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                final filtered = _applyFilters(expenses);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.searchX,
                            color: _kTextSecondary.withValues(alpha: 0.4),
                            size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune dépense trouvée',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Summarize
                final total =
                    filtered.fold(0.0, (sum, e) => sum + e.amount);

                return Column(
                  children: [
                    // Total bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      color: _kCard,
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} dépense${filtered.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _kTextSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Total: ${total.toStringAsFixed(2)} DT',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDanger,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expense list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(filtered[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kPrimary),
              ),
              error: (e, _) => Center(
                child: Text('Erreur: $e',
                    style: GoogleFonts.inter(color: _kDanger)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Filters bar
  // ─────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _kCard.withValues(alpha: 0.5),
      child: Column(
        children: [
          // Period filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'Tout', _filterPeriod,
                    (v) => setState(() => _filterPeriod = v)),
                _filterChip('today', 'Aujourd\'hui', _filterPeriod,
                    (v) => setState(() => _filterPeriod = v)),
                _filterChip('week', 'Semaine', _filterPeriod,
                    (v) => setState(() => _filterPeriod = v)),
                _filterChip('month', 'Ce mois', _filterPeriod,
                    (v) => setState(() => _filterPeriod = v)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Category filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip('all', '📋', 'Toutes'),
                ...expenseCategories.map((cat) =>
                    _categoryChip(cat.key, cat.emoji, cat.label)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String value, String label, String current, Function(String) onTap) {
    final isSelected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _kPrimary : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? _kPrimary : _kTextSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : _kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String key, String emoji, String label) {
    final isSelected = _filterCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterCategory = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? _kPrimary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _kPrimary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? _kPrimary : _kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Expense Card
  // ─────────────────────────────────────────────────────────
  Widget _buildExpenseCard(CashExpense expense) {
    final cat = getCategoryByKey(expense.category);
    final date = expense.expenseDate;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kDanger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer la dépense ?'),
            content: Text(
                'Le montant de ${expense.amount.toStringAsFixed(2)} DT sera remis dans le fond de caisse.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: _kDanger),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteExpense(expense),
      child: GestureDetector(
        onTap: () => showExpenseDetailSheet(context, expense),
        child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(cat.colorValue).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cat.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
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
                  if (expense.description != null &&
                      expense.description!.isNotEmpty)
                    Text(
                      expense.description!,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _kTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _kTextSecondary),
                  ),
                ],
              ),
            ),
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
                if (expense.truckId != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.truck,
                          size: 12, color: _kPrimary),
                      const SizedBox(width: 4),
                      Text(
                        expense.truckId!.length > 8
                            ? expense.truckId!.substring(0, 8)
                            : expense.truckId!,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _kPrimary),
                      ),
                    ],
                  ),
              ],
            ),
            if (expense.receiptUrl != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showReceipt(expense.receiptUrl!),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.paperclip,
                      size: 16, color: _kPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────
  Future<void> _deleteExpense(CashExpense expense) async {
    try {
      // Delete expense
      await Supabase.instance.client
          .from('cash_expenses')
          .delete()
          .eq('id', expense.id);

      // Restore balance
      final fund = await ref.read(cashFundProvider.future);
      if (fund != null) {
        await Supabase.instance.client
            .from('cash_funds')
            .update({
              'current_balance': fund.currentBalance + expense.amount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', fund.id);
      }

      ref.invalidate(cashFundProvider);
      ref.invalidate(cashExpensesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${expense.amount.toStringAsFixed(2)} DT restaurés dans le fond'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _kDanger),
        );
      }
    }
  }

  void _showReceipt(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
