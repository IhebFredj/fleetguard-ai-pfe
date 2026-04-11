import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────

class CashFund {
  final String id;
  final String chefEmail;
  final double initialAmount;
  final double currentBalance;
  final double alertThreshold;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  CashFund({
    required this.id,
    required this.chefEmail,
    required this.initialAmount,
    required this.currentBalance,
    this.alertThreshold = 50.0,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAlert => currentBalance <= alertThreshold;
  double get totalSpent => initialAmount - currentBalance;
  double get percentRemaining =>
      initialAmount > 0 ? (currentBalance / initialAmount) * 100 : 0;

  factory CashFund.fromJson(Map<String, dynamic> json) {
    return CashFund(
      id: json['id'] as String,
      chefEmail: json['chef_email'] as String? ?? '',
      initialAmount: (json['initial_amount'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      alertThreshold: (json['alert_threshold'] as num?)?.toDouble() ?? 50.0,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class CashExpense {
  final String id;
  final String fundId;
  final String? truckId;
  final double amount;
  final String category;
  final String? description;
  final String? receiptUrl;
  final String? receiptType;
  final DateTime expenseDate;
  final String? createdBy;
  final DateTime createdAt;

  CashExpense({
    required this.id,
    required this.fundId,
    this.truckId,
    required this.amount,
    required this.category,
    this.description,
    this.receiptUrl,
    this.receiptType,
    required this.expenseDate,
    this.createdBy,
    required this.createdAt,
  });

  factory CashExpense.fromJson(Map<String, dynamic> json) {
    return CashExpense(
      id: json['id'] as String,
      fundId: json['fund_id'] as String? ?? '',
      truckId: json['truck_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? 'autre',
      description: json['description'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      receiptType: json['receipt_type'] as String?,
      expenseDate: DateTime.parse(
          json['expense_date'] as String? ?? DateTime.now().toIso8601String()),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class CashReload {
  final String id;
  final String fundId;
  final double amount;
  final String? reloadedBy;
  final String? note;
  final DateTime createdAt;

  CashReload({
    required this.id,
    required this.fundId,
    required this.amount,
    this.reloadedBy,
    this.note,
    required this.createdAt,
  });

  factory CashReload.fromJson(Map<String, dynamic> json) {
    return CashReload(
      id: json['id'] as String,
      fundId: json['fund_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reloadedBy: json['reloaded_by'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Expense Categories
// ─────────────────────────────────────────────────────────

class ExpenseCategory {
  final String key;
  final String label;
  final String emoji;
  final int colorValue;

  const ExpenseCategory({
    required this.key,
    required this.label,
    required this.emoji,
    required this.colorValue,
  });
}

const expenseCategories = [
  ExpenseCategory(key: 'carburant', label: 'Carburant', emoji: '⛽', colorValue: 0xFF10B981),
  ExpenseCategory(key: 'maintenance', label: 'Maintenance', emoji: '🔧', colorValue: 0xFF3B82F6),
  ExpenseCategory(key: 'panne', label: 'Panne', emoji: '⚠️', colorValue: 0xFFF97316),
  ExpenseCategory(key: 'amande', label: 'Amende', emoji: '📋', colorValue: 0xFFEF4444),
  ExpenseCategory(key: 'peage', label: 'Péage', emoji: '🛣️', colorValue: 0xFF6B7280),
  ExpenseCategory(key: 'lavage', label: 'Lavage', emoji: '🚿', colorValue: 0xFF06B6D4),
  ExpenseCategory(key: 'pieces', label: 'Pièces', emoji: '⚙️', colorValue: 0xFF8B5CF6),
  ExpenseCategory(key: 'assurance', label: 'Assurance', emoji: '🛡️', colorValue: 0xFF1E40AF),
  ExpenseCategory(key: 'autre', label: 'Autre', emoji: '📦', colorValue: 0xFF9CA3AF),
];

ExpenseCategory getCategoryByKey(String key) {
  return expenseCategories.firstWhere(
    (c) => c.key == key,
    orElse: () => expenseCategories.last,
  );
}

// ─────────────────────────────────────────────────────────
//  Providers
// ─────────────────────────────────────────────────────────

/// Le fond de caisse actif du Chef de Parc connecté
final cashFundProvider = FutureProvider.autoDispose<CashFund?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user?.email == null) return null;

  final result = await Supabase.instance.client
      .from('cash_funds')
      .select()
      .ilike('chef_email', user!.email!)
      .eq('status', 'active')
      .maybeSingle();

  if (result == null) return null;
  return CashFund.fromJson(result);
});

/// Les dépenses du fond de caisse actif
final cashExpensesProvider =
    FutureProvider.autoDispose<List<CashExpense>>((ref) async {
  final fund = await ref.watch(cashFundProvider.future);
  if (fund == null) return [];

  final rows = await Supabase.instance.client
      .from('cash_expenses')
      .select()
      .eq('fund_id', fund.id)
      .order('expense_date', ascending: false);

  return rows.map<CashExpense>((j) => CashExpense.fromJson(j)).toList();
});

/// Les rechargements du fond de caisse actif
final cashReloadsProvider =
    FutureProvider.autoDispose<List<CashReload>>((ref) async {
  final fund = await ref.watch(cashFundProvider.future);
  if (fund == null) return [];

  final rows = await Supabase.instance.client
      .from('cash_reloads')
      .select()
      .eq('fund_id', fund.id)
      .order('created_at', ascending: false);

  return rows.map<CashReload>((j) => CashReload.fromJson(j)).toList();
});

/// Toutes les dépenses pour le rapport admin (tous les fonds)
final allExpensesProvider =
    FutureProvider.autoDispose<List<CashExpense>>((ref) async {
  final rows = await Supabase.instance.client
      .from('cash_expenses')
      .select()
      .order('expense_date', ascending: false);

  return rows.map<CashExpense>((j) => CashExpense.fromJson(j)).toList();
});

/// Tous les fonds (pour le rapport admin)
final allFundsProvider =
    FutureProvider.autoDispose<List<CashFund>>((ref) async {
  final rows = await Supabase.instance.client
      .from('cash_funds')
      .select()
      .order('created_at', ascending: false);

  return rows.map<CashFund>((j) => CashFund.fromJson(j)).toList();
});
