import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FuelVoucherNewPage extends StatefulWidget {
  const FuelVoucherNewPage({super.key});

  @override
  State<FuelVoucherNewPage> createState() => _FuelVoucherNewPageState();
}

class _FuelVoucherNewPageState extends State<FuelVoucherNewPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllerNumero = TextEditingController();
  final _controllerMontant = TextEditingController();
  final _controllerLitres = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _controllerNumero.dispose();
    _controllerMontant.dispose();
    _controllerLitres.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _imageBytes = bytes;
    });
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _imageBytes = bytes;
    });
  }

  void _removePhoto() {
    setState(() {
      _imageBytes = null;
    });
  }

  Future<void> _saveManual() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bon de gasoil enregistré')),
    );
  }

  Future<void> _saveAttachment() async {
    if (_imageBytes == null) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo attachée au bon de gasoil')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bon de gasoil'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Manuel'),
              Tab(text: 'Photo'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            _ManualForm(),
            _PhotoCapture(),
          ],
        ),
      ),
    );
  }
}

class _ManualForm extends StatefulWidget {
  const _ManualForm();

  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllerDate = TextEditingController();
  final _controllerNumero = TextEditingController();
  final _controllerMontant = TextEditingController();
  final _controllerLitres = TextEditingController();
  final _controllerQiosque = TextEditingController();
  final _controllerMatricule = TextEditingController();
  final _controllerChauffeur = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controllerDate.dispose();
    _controllerNumero.dispose();
    _controllerMontant.dispose();
    _controllerLitres.dispose();
    _controllerQiosque.dispose();
    _controllerMatricule.dispose();
    _controllerChauffeur.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bon de gasoil (manuel) enregistré')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _controllerDate,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) {
                    _controllerDate.text = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                  }
                },
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _controllerNumero,
                decoration: const InputDecoration(labelText: 'Numéro du bon'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              
              TextFormField(
                controller: _controllerQiosque,
                decoration: const InputDecoration(labelText: 'Qiosque'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _controllerMontant,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controllerLitres,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Litres'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              
              TextFormField(
                controller: _controllerMatricule,
                decoration: const InputDecoration(labelText: 'Matricule'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controllerChauffeur,
                decoration: const InputDecoration(labelText: 'Numéro de chauffeur'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),

              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCapture extends StatefulWidget {
  const _PhotoCapture();

  @override
  State<_PhotoCapture> createState() => _PhotoCaptureState();
}

class _PhotoCaptureState extends State<_PhotoCapture> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _saving = false;

  Future<void> _captureFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  void _removePhoto() {
    setState(() => _imageBytes = null);
  }

  Future<void> _saveAttachment() async {
    if (_imageBytes == null) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo attachée au bon de gasoil')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _captureFromCamera,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Prendre une photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Depuis la galerie'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imageBytes != null)
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _imageBytes == null
                              ? const SizedBox.shrink()
                              : Image.memory(_imageBytes!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _captureFromCamera,
                              icon: const Icon(Icons.replay),
                              label: const Text('Reprendre'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _removePhoto,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Supprimer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _imageBytes == null || _saving ? null : _saveAttachment,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Enregistrement…' : 'Attacher au bon'),
            ),
          ],
        ),
      ),
    );
  }
}
