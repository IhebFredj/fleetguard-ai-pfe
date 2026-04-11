// lib/features/chef_parc/expenses/expense_detail_sheet.dart
// Bottom sheet détaillé pour visualiser une dépense (photo, fichier, infos)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/cash_fund_provider.dart';

// ─────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────
const _kBg = Color(0xFF0F172A);
const _kSurface = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kPrimary = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kDanger = Color(0xFFEF4444);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);
const _kBorder = Color(0xFF2D3748);

/// Affiche un BottomSheet ultra-détaillé pour une dépense
void showExpenseDetailSheet(BuildContext context, CashExpense expense) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExpenseDetailSheet(expense: expense),
  );
}

class _ExpenseDetailSheet extends StatelessWidget {
  final CashExpense expense;
  const _ExpenseDetailSheet({required this.expense});

  bool get _isImage {
    final url = expense.receiptUrl?.toLowerCase() ?? '';
    final type = expense.receiptType?.toLowerCase() ?? '';
    return type.startsWith('image') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp') ||
        url.endsWith('.gif');
  }

  bool get _isPdf {
    final url = expense.receiptUrl?.toLowerCase() ?? '';
    final type = expense.receiptType?.toLowerCase() ?? '';
    return type == 'application/pdf' || url.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final cat = getCategoryByKey(expense.category);
    final hasReceipt = expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag indicator
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kTextSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Header : catégorie + montant
                    _buildHeader(cat),

                    const SizedBox(height: 20),

                    // Infos détaillées
                    _buildInfoSection(cat),

                    const SizedBox(height: 20),

                    // Pièce jointe
                    if (hasReceipt) ...[
                      _sectionTitle('📎  Pièce jointe'),
                      const SizedBox(height: 10),
                      _buildReceiptPreview(context),
                    ] else ...[
                      _buildNoReceiptBanner(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ExpenseCategory cat) {
    return Row(
      children: [
        // Catégorie icone
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Color(cat.colorValue).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(cat.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cat.label,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              if (expense.description != null && expense.description!.isNotEmpty)
                Text(
                  expense.description!,
                  style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        // Montant
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kDanger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '-${expense.amount.toStringAsFixed(2)} DT',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kDanger,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(ExpenseCategory cat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _infoRow(LucideIcons.calendar, 'Date', _formatDate(expense.expenseDate)),
          const Divider(color: _kBorder, height: 20),
          _infoRow(LucideIcons.tag, 'Catégorie', '${cat.emoji} ${cat.label}'),
          if (expense.createdBy != null) ...[
            const Divider(color: _kBorder, height: 20),
            _infoRow(LucideIcons.user, 'Créé par', expense.createdBy!),
          ],
          if (expense.truckId != null) ...[
            const Divider(color: _kBorder, height: 20),
            _infoRow(LucideIcons.truck, 'Camion', expense.truckId!),
          ],
          const Divider(color: _kBorder, height: 20),
          _infoRow(LucideIcons.clock, 'Ajouté le', _formatDateTime(expense.createdAt)),
          if (expense.receiptType != null) ...[
            const Divider(color: _kBorder, height: 20),
            _infoRow(LucideIcons.file, 'Type fichier', expense.receiptType!),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kPrimary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptPreview(BuildContext context) {
    final url = expense.receiptUrl!;

    if (_isImage) {
      return Column(
        children: [
          // Image preview
          GestureDetector(
            onTap: () => _openFullScreenImage(context, url),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          color: _kPrimary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.imageOff, color: _kDanger, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Impossible de charger l\'image',
                            style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  LucideIcons.maximize2,
                  'Agrandir',
                  () => _openFullScreenImage(context, url),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  context,
                  LucideIcons.externalLink,
                  'Ouvrir',
                  () => _openUrl(url),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_isPdf) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kDanger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.fileText, size: 40, color: _kDanger),
                ),
                const SizedBox(height: 14),
                Text(
                  'Document PDF',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Appuyez pour ouvrir le fichier',
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(url),
              icon: const Icon(LucideIcons.externalLink, size: 18),
              label: Text(
                'Ouvrir le PDF',
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
      );
    }

    // Autre type de fichier
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.file, size: 40, color: _kPrimary),
          const SizedBox(height: 12),
          Text(
            'Fichier joint',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(url),
              icon: const Icon(LucideIcons.download, size: 18),
              label: const Text('Télécharger'),
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

  Widget _buildNoReceiptBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kTextSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.imageOff, size: 22, color: _kTextSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucune pièce jointe',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                Text(
                  'Pas de photo ni fichier pour cette dépense',
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: _kCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: _kPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _kTextPrimary,
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Justificatif', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateTime(DateTime d) {
    return '${_formatDate(d)} à ${d.hour}h${d.minute.toString().padLeft(2, '0')}';
  }
}
