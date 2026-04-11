// lib/features/chef_parc/expenses/add_expense_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../providers/cash_fund_provider.dart';

// ─────────────────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kDanger = Color(0xFFEF4444);
const _kSurface = Color(0xFF1B1F2B);
const _kCard = Color(0xFF242938);
const _kTextPrimary = Color(0xFFF1F5F9);
const _kTextSecondary = Color(0xFF94A3B8);

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'carburant';
  // ── FIX 1 : Support multi-sélection de camions ──
  List<String> _selectedTruckIds = [];
  DateTime _selectedDate = DateTime.now();
  File? _receiptFile;
  String? _receiptType;
  bool _isLoading = false;

  // Trucks list
  List<Map<String, dynamic>> _trucks = [];

  @override
  void initState() {
    super.initState();
    _loadTrucks();
  }

  Future<void> _loadTrucks() async {
    try {
      final rows = await Supabase.instance.client
          .from('trucks')
          .select('id, plate')
          .order('plate');
      if (mounted) {
        setState(() => _trucks = List<Map<String, dynamic>>.from(rows));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Pick receipt
  // ─────────────────────────────────────────────────────────
  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (img != null) {
      setState(() {
        _receiptFile = File(img.path);
        _receiptType = 'camera';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) {
      setState(() {
        _receiptFile = File(img.path);
        _receiptType = 'photo';
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _receiptFile = File(result.files.single.path!);
        _receiptType = 'document';
      });
    }
  }

  // ─────────────────────────────────────────────────────────
  //  FIX 3 : Upload receipt robuste avec gestion d'erreur
  // ─────────────────────────────────────────────────────────
  Future<String?> _uploadReceipt(File file) async {
    try {
      final ext = p.extension(file.path).replaceAll('.', '');
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await file.readAsBytes();

      // Upload les bytes au lieu du File (plus fiable sur mobile)
      await Supabase.instance.client.storage
          .from('expense-receipts')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(
                contentType: ext == 'pdf'
                    ? 'application/pdf'
                    : 'image/$ext',
              ));

      final url = Supabase.instance.client.storage
          .from('expense-receipts')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');
      // Si le bucket n'existe pas ou erreur storage, 
      // on continue sans le fichier mais on prévient
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Le fichier n\'a pas pu être uploadé: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }



  // ─────────────────────────────────────────────────────────
  //  FIX 2 : Notification admin quand solde <= 50 DT
  // ─────────────────────────────────────────────────────────
  Future<void> _notifyAdminsLowBalance(double newBalance, String chefEmail) async {
    try {
      // Insérer une notification dans la table 'notifications' pour les admins
      final admins = await Supabase.instance.client
          .from('user_roles')
          .select('email')
          .inFilter('role', ['admin', 'developer']);

      for (final admin in admins) {
        if (admin['email'] == null) continue;
        await Supabase.instance.client.from('notifications').insert({
          'recipient_email': admin['email'],
          'title': '⚠️ Fond de caisse faible',
          'message':
              'Le fond de caisse de $chefEmail est à ${newBalance.toStringAsFixed(2)} DT. Rechargement nécessaire !',
          'type': 'cash_alert',
          'is_read': false,
        });
      }
      debugPrint('Notifications envoyées aux admins');
    } catch (e) {
      debugPrint('Notification admin error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Submit expense
  // ─────────────────────────────────────────────────────────
  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final fund = await ref.read(cashFundProvider.future);
    if (fund == null) {
      _showError('Aucun fond de caisse actif trouvé.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showError('Le montant doit être supérieur à 0.');
      return;
    }
    if (amount > fund.currentBalance) {
      _showError(
          'Solde insuffisant ! Disponible: ${fund.currentBalance.toStringAsFixed(2)} DT');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload receipt if present (FIX 3)
      String? receiptUrl;
      if (_receiptFile != null) {
        receiptUrl = await _uploadReceipt(_receiptFile!);
      }

      final email = FirebaseAuth.instance.currentUser?.email ?? '';

      // Prépare le truck_id (rejoint les IDs si multi-sélection)
      final truckIdStr = _selectedTruckIds.isEmpty
          ? null
          : _selectedTruckIds.join(',');

      // Insert expense
      await Supabase.instance.client.from('cash_expenses').insert({
        'fund_id': fund.id,
        'truck_id': truckIdStr,
        'amount': amount,
        'category': _selectedCategory,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'receipt_url': receiptUrl,
        'receipt_type': _receiptType,
        'expense_date': _selectedDate.toIso8601String(),
        'created_by': email,
      });

      // Update balance
      final newBalance = fund.currentBalance - amount;
      await Supabase.instance.client
          .from('cash_funds')
          .update({
            'current_balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', fund.id);

      if (mounted) {
        if (newBalance <= fund.alertThreshold) {
          // Envoyer notification aux admins
          _notifyAdminsLowBalance(newBalance, email);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ ALERTE : Solde restant ${newBalance.toStringAsFixed(2)} DT ! Les administrateurs ont été notifiés.',
              ),
              backgroundColor: _kDanger,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Dépense de ${amount.toStringAsFixed(2)} DT enregistrée. Reste: ${newBalance.toStringAsFixed(2)} DT',
              ),
              backgroundColor: _kAccent,
            ),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _kDanger),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: Text('Ajouter une dépense',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _kCard,
        foregroundColor: _kTextPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Amount ──
              _sectionTitle('Montant'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 28,
                    color: _kTextSecondary.withValues(alpha: 0.3),
                  ),
                  suffixText: 'DT',
                  suffixStyle: GoogleFonts.inter(
                    fontSize: 18,
                    color: _kTextSecondary,
                  ),
                  filled: true,
                  fillColor: _kCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Montant requis';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Category ──
              _sectionTitle('Catégorie'),
              const SizedBox(height: 10),
              _buildCategoryGrid(),
              const SizedBox(height: 24),

              // ── FIX 1 : Multi-Truck Selection ──
              _sectionTitle('Camion(s) concerné(s)'),
              const SizedBox(height: 8),
              _buildTruckMultiSelect(),
              const SizedBox(height: 24),

              // ── Description ──
              _sectionTitle('Description / Motif'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: GoogleFonts.inter(color: _kTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Ex: Vidange moteur camion TN-1234',
                  hintStyle: GoogleFonts.inter(
                    color: _kTextSecondary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: _kCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),

              // ── Date ──
              _sectionTitle('Date de la dépense'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar,
                          color: _kPrimary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: _kTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Receipt ──
              _sectionTitle('Justificatif / Reçu'),
              const SizedBox(height: 10),
              _buildReceiptSection(),
              const SizedBox(height: 32),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitExpense,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(LucideIcons.checkCircle),
                  label: Text(
                    _isLoading ? 'Enregistrement...' : 'Enregistrer la dépense',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  UI Helpers
  // ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _kTextSecondary,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: expenseCategories.map((cat) {
        final isSelected = _selectedCategory == cat.key;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Color(cat.colorValue).withValues(alpha: 0.2)
                  : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Color(cat.colorValue)
                    : Colors.transparent,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Color(cat.colorValue)
                        : _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  FIX 1 : Multi-Truck Selector (Chips)
  // ─────────────────────────────────────────────────────────
  Widget _buildTruckMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected chips
        if (_selectedTruckIds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _selectedTruckIds.map((id) {
              final truck = _trucks.firstWhere(
                (t) => t['id'].toString() == id,
                orElse: () => {'plate': id},
              );
              return Chip(
                avatar: const Icon(LucideIcons.truck, size: 14, color: _kPrimary),
                label: Text(
                  truck['plate'] ?? id,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                deleteIcon: const Icon(LucideIcons.x, size: 14, color: _kDanger),
                onDeleted: () {
                  setState(() => _selectedTruckIds.remove(id));
                },
                backgroundColor: _kPrimary.withValues(alpha: 0.12),
                side: BorderSide(color: _kPrimary.withValues(alpha: 0.3)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],

        // Add truck button
        GestureDetector(
          onTap: () => _showTruckPicker(),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.plusCircle, color: _kPrimary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedTruckIds.isEmpty
                      ? 'Sélectionner un ou plusieurs camions'
                      : 'Ajouter un autre camion',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTruckPicker() {
    // Filter out already selected trucks
    final available = _trucks
        .where((t) => !_selectedTruckIds.contains(t['id'].toString()))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les camions sont déjà sélectionnés'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Choisir un camion',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ),
              const Divider(height: 1, color: _kSurface),
              // Option "Dépense générale" (aucun camion)
              ListTile(
                leading: const Icon(LucideIcons.packageOpen, color: _kTextSecondary),
                title: Text('Dépense générale (aucun camion)',
                    style: GoogleFonts.inter(color: _kTextSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Clear all to set "general"
                  setState(() => _selectedTruckIds.clear());
                },
              ),
              const Divider(height: 1, color: _kSurface),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final truck = available[index];
                    return ListTile(
                      leading: const Icon(LucideIcons.truck,
                          color: _kPrimary, size: 20),
                      title: Text(
                        truck['plate'] ?? truck['id'].toString(),
                        style: GoogleFonts.inter(color: _kTextPrimary),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedTruckIds.add(truck['id'].toString());
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    return Column(
      children: [
        // 3 pick buttons
        Row(
          children: [
            _receiptBtn(
              icon: LucideIcons.camera,
              label: 'Caméra',
              onTap: _pickFromCamera,
            ),
            const SizedBox(width: 10),
            _receiptBtn(
              icon: LucideIcons.image,
              label: 'Galerie',
              onTap: _pickFromGallery,
            ),
            const SizedBox(width: 10),
            _receiptBtn(
              icon: LucideIcons.file,
              label: 'Fichier',
              onTap: _pickFile,
            ),
          ],
        ),
        // Preview
        if (_receiptFile != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _receiptFile!.path.endsWith('.pdf')
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.fileText,
                                  color: _kPrimary, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'PDF sélectionné',
                                style: GoogleFonts.inter(
                                    color: _kTextSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : Image.file(
                          _receiptFile!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _receiptFile = null;
                      _receiptType = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _kDanger,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.x,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _receiptBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: _kPrimary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
