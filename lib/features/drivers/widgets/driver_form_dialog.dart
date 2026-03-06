import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/driver.dart';
import '../../../core/providers.dart';
import '../../../core/models/truck.dart';

/// Couleurs SHTT
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1E40AF);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const background = Color(0xFFFFFFFF);
  static const backgroundGrey = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
}

/// Dialog de formulaire d'ajout/édition de chauffeur
class DriverFormDialog extends ConsumerStatefulWidget {
  final Driver? driver;
  final Function(Driver) onSave;

  const DriverFormDialog({super.key, this.driver, required this.onSave});

  @override
  ConsumerState<DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends ConsumerState<DriverFormDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _salaryController = TextEditingController();

  // Dates
  DateTime? _birthDate;
  DateTime? _hireDate;
  DateTime? _licenseExpiryDate;

  // Valeurs sélectionnées
  String _selectedCountry = 'Tunisie';
  LicenseCategory _selectedLicenseCategory = LicenseCategory.c;
  DriverStatus _selectedStatus = DriverStatus.active;
  Truck? _selectedTruck; // Camion sélectionné

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.driver != null) {
      _initializeWithDriver(widget.driver!);
    } else {
      _hireDate = DateTime.now();
      _birthDate = DateTime.now().subtract(const Duration(days: 365 * 25));
      _licenseExpiryDate = DateTime.now().add(const Duration(days: 365 * 2));
    }
    // Charger la liste des camions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trucksProvider);
    });
  }

  void _initializeWithDriver(Driver driver) {
    _firstNameController.text = driver.firstName;
    _lastNameController.text = driver.lastName;
    _emailController.text = driver.email;
    _phoneController.text = driver.phone;
    _addressController.text = driver.address;
    _cityController.text = driver.city;
    _postalCodeController.text = driver.postalCode;
    _licenseNumberController.text = driver.licenseNumber;
    _salaryController.text = driver.monthlySalary.toString();

    _birthDate = driver.birthDate;
    _hireDate = driver.hireDate;
    _licenseExpiryDate = driver.licenseExpiryDate;

    _selectedCountry = driver.country;
    _selectedLicenseCategory = driver.licenseCategory;
    _selectedStatus = driver.status;

    // Charger le camion assigné si existe
    if (driver.assignedVehicle != null) {
      _selectedTruck = Truck(
        id: driver.assignedVehicle!.id,
        plate: driver.assignedVehicle!.plate,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _licenseNumberController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.driver != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Plein écran sur mobile
    if (isMobile) {
      return Scaffold(
        backgroundColor: SHTTColors.background,
        appBar: AppBar(
          backgroundColor: SHTTColors.background,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.arrowLeft, color: SHTTColors.textDark),
          ),
          title: Text(
            isEditing ? 'Éditer le chauffeur' : 'Ajouter un chauffeur',
            style: const TextStyle(
              color: SHTTColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: SHTTColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: SHTTColors.primary,
            unselectedLabelColor: SHTTColors.textGrey,
            indicatorColor: SHTTColors.primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Personnel', icon: Icon(LucideIcons.user, size: 18)),
              Tab(
                text: 'Professionnel',
                icon: Icon(LucideIcons.briefcase, size: 18),
              ),
              Tab(
                text: 'Documents',
                icon: Icon(LucideIcons.fileText, size: 18),
              ),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalInfoTab(isMobile: true),
              _buildProfessionalTab(isMobile: true),
              _buildDocumentsTab(isMobile: true),
            ],
          ),
        ),
      );
    }

    // Dialog sur desktop
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: SHTTColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(isEditing),

            // TabBar
            TabBar(
              controller: _tabController,
              labelColor: SHTTColors.primary,
              unselectedLabelColor: SHTTColors.textGrey,
              indicatorColor: SHTTColors.primary,
              tabs: const [
                Tab(text: 'Personnel', icon: Icon(LucideIcons.user, size: 18)),
                Tab(
                  text: 'Professionnel',
                  icon: Icon(LucideIcons.briefcase, size: 18),
                ),
                Tab(
                  text: 'Documents',
                  icon: Icon(LucideIcons.fileText, size: 18),
                ),
              ],
            ),

            // Content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPersonalInfoTab(isMobile: false),
                    _buildProfessionalTab(isMobile: false),
                    _buildDocumentsTab(isMobile: false),
                  ],
                ),
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SHTTColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Éditer le chauffeur' : 'Ajouter un chauffeur',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SHTTColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remplissez les informations ci-dessous',
                  style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, color: SHTTColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations personnelles'),
          const SizedBox(height: 16),
          isMobile
              ? Column(
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Prénom *',
                      hint: 'Prénom',
                      icon: LucideIcons.user,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Nom *',
                      hint: 'Nom',
                      icon: LucideIcons.user,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Champ requis' : null,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'Prénom *',
                        hint: 'Prénom',
                        icon: LucideIcons.user,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Champ requis' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Nom *',
                        hint: 'Nom',
                        icon: LucideIcons.user,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Champ requis' : null,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email *',
            hint: 'email@exemple.com',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Champ requis';
              if (!value!.contains('@')) return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneController,
            label: 'Téléphone *',
            hint: '+216 XX XXX XXX',
            icon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          _buildDateField(
            label: 'Date de naissance *',
            value: _birthDate,
            onSelect: (date) => setState(() => _birthDate = date),
            icon: LucideIcons.calendar,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Adresse'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            label: 'Adresse *',
            hint: 'Rue, numéro',
            icon: LucideIcons.mapPin,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          isMobile
              ? Column(
                  children: [
                    _buildTextField(
                      controller: _cityController,
                      label: 'Ville *',
                      hint: 'Ville',
                      icon: LucideIcons.building,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _postalCodeController,
                      label: 'Code postal *',
                      hint: 'Code postal',
                      icon: LucideIcons.hash,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Champ requis' : null,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _cityController,
                        label: 'Ville *',
                        hint: 'Ville',
                        icon: LucideIcons.building,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Champ requis' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _postalCodeController,
                        label: 'Code postal *',
                        hint: 'Code postal',
                        icon: LucideIcons.hash,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Champ requis' : null,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Pays *',
            value: _selectedCountry,
            items: const ['Tunisie', 'France', 'Algérie', 'Maroc', 'Libye'],
            onChanged: (value) => setState(() => _selectedCountry = value!),
            icon: LucideIcons.globe,
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations professionnelles'),
          const SizedBox(height: 16),
          _buildDateField(
            label: 'Date d\'embauche *',
            value: _hireDate,
            onSelect: (date) => setState(() => _hireDate = date),
            icon: LucideIcons.calendar,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Catégorie de licence *',
            value: _selectedLicenseCategory.index.toString(),
            items: const ['0', '1', '2', '3', '4'],
            itemLabels: const ['A', 'B', 'C', 'D', 'E'],
            onChanged: (value) => setState(
              () => _selectedLicenseCategory =
                  LicenseCategory.values[int.parse(value!)],
            ),
            icon: LucideIcons.contact,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _licenseNumberController,
            label: 'Numéro de licence *',
            hint: 'Numéro de licence',
            icon: LucideIcons.creditCard,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Champ requis' : null,
          ),
          const SizedBox(height: 16),
          _buildDateField(
            label: 'Date d\'expiration licence *',
            value: _licenseExpiryDate,
            onSelect: (date) => setState(() => _licenseExpiryDate = date),
            icon: LucideIcons.calendarClock,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _salaryController,
            label: 'Salaire mensuel (TND) *',
            hint: '0.00',
            icon: LucideIcons.banknote,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Champ requis';
              if (double.tryParse(value!) == null) return 'Nombre invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Statut *',
            value: _selectedStatus.index.toString(),
            items: const ['0', '1', '2', '3'],
            itemLabels: const ['Actif', 'Inactif', 'En congé', 'Suspendu'],
            onChanged: (value) => setState(
              () => _selectedStatus = DriverStatus.values[int.parse(value!)],
            ),
            icon: LucideIcons.activity,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Véhicule assigné'),
          const SizedBox(height: 16),
          _buildTruckSelector(),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Documents du chauffeur'),
          const SizedBox(height: 16),
          _buildUploadField(
            label: 'Permis de conduire',
            icon: LucideIcons.fileText,
            acceptedTypes: 'PDF, JPG, PNG (max 5MB)',
          ),
          const SizedBox(height: 16),
          _buildUploadField(
            label: 'Assurance',
            icon: LucideIcons.shield,
            acceptedTypes: 'PDF (max 5MB)',
          ),
          const SizedBox(height: 16),
          _buildUploadField(
            label: 'Certificat médical',
            icon: LucideIcons.heartPulse,
            acceptedTypes: 'PDF (max 5MB)',
          ),
          const SizedBox(height: 16),
          _buildUploadField(
            label: 'Photo d\'identité',
            icon: LucideIcons.image,
            acceptedTypes: 'JPG, PNG (max 2MB)',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: SHTTColors.textDark,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SHTTColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: SHTTColors.textGrey.withOpacity(0.5)),
            prefixIcon: Icon(icon, size: 18, color: SHTTColors.textGrey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.critical),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function(DateTime) onSelect,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SHTTColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (date != null) onSelect(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: SHTTColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: SHTTColors.textGrey),
                const SizedBox(width: 12),
                Text(
                  value != null
                      ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                      : 'Sélectionner une date',
                  style: TextStyle(
                    color: value != null
                        ? SHTTColors.textDark
                        : SHTTColors.textGrey.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    List<String>? itemLabels,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SHTTColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: SHTTColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                prefixIcon: Icon(icon, size: 18, color: SHTTColors.textGrey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              items: items.asMap().entries.map((entry) {
                final index = entry.key;
                final itemValue = entry.value;
                final label = itemLabels != null
                    ? itemLabels[index]
                    : itemValue;
                return DropdownMenuItem(value: itemValue, child: Text(label));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadField({
    required String label,
    required IconData icon,
    required String acceptedTypes,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: SHTTColors.border),
        borderRadius: BorderRadius.circular(8),
        color: SHTTColors.backgroundGrey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: SHTTColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: SHTTColors.textDark,
                      ),
                    ),
                    Text(
                      acceptedTypes,
                      style: TextStyle(
                        fontSize: 12,
                        color: SHTTColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implémenter l'upload
            },
            icon: const Icon(LucideIcons.upload, size: 16),
            label: const Text('Choisir un fichier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.background,
              foregroundColor: SHTTColors.primary,
              elevation: 0,
              side: const BorderSide(color: SHTTColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckSelector() {
    final trucks = ref.watch(trucksProvider);

    if (trucks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: SHTTColors.border),
          borderRadius: BorderRadius.circular(8),
          color: SHTTColors.backgroundGrey,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.truck, size: 18, color: SHTTColors.textGrey),
            const SizedBox(width: 12),
            Text(
              'Aucun camion disponible',
              style: TextStyle(color: SHTTColors.textGrey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: SHTTColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<Truck?>(
              value: _selectedTruck,
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  LucideIcons.truck,
                  size: 18,
                  color: SHTTColors.textGrey,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              hint: Text(
                'Sélectionner un camion',
                style: TextStyle(color: SHTTColors.textGrey.withOpacity(0.5)),
              ),
              items: [
                const DropdownMenuItem<Truck?>(
                  value: null,
                  child: Text('Aucun camion'),
                ),
                ...trucks.map((truck) {
                  return DropdownMenuItem<Truck?>(
                    value: truck,
                    child: Text('${truck.plate}'),
                  );
                }).toList(),
              ],
              onChanged: (value) => setState(() => _selectedTruck = value),
            ),
          ),
        ),
        if (_selectedTruck != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SHTTColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SHTTColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.truck, size: 16, color: SHTTColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Camion assigné: ${_selectedTruck!.plate}',
                    style: TextStyle(
                      fontSize: 13,
                      color: SHTTColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _selectedTruck = null),
                  child: Icon(
                    LucideIcons.x,
                    size: 16,
                    color: SHTTColors.critical,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SHTTColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: SHTTColors.textGrey,
              side: const BorderSide(color: SHTTColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.save, size: 16),
            label: Text(_isLoading ? 'Enregistrement...' : 'Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final driver = Driver(
        id:
            widget.driver?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        birthDate: _birthDate!,
        address: _addressController.text,
        city: _cityController.text,
        postalCode: _postalCodeController.text,
        country: _selectedCountry,
        hireDate: _hireDate!,
        licenseCategory: _selectedLicenseCategory,
        licenseNumber: _licenseNumberController.text,
        licenseExpiryDate: _licenseExpiryDate!,
        monthlySalary: double.parse(_salaryController.text),
        status: _selectedStatus,
        assignedVehicle: _selectedTruck != null
            ? AssignedVehicle(
                id: _selectedTruck!.id,
                plate: _selectedTruck!.plate,
                brand: 'N/A',
                model: 'N/A',
                year: DateTime.now().year,
                mileage: 0.0,
                status: 'active',
              )
            : null,
        createdAt: widget.driver?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.onSave(driver);
    }
  }
}
