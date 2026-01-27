import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptVoucherNewPage extends StatefulWidget {
  const ReceiptVoucherNewPage({super.key});

  @override
  State<ReceiptVoucherNewPage> createState() => _ReceiptVoucherNewPageState();
}

class _ReceiptVoucherNewPageState extends State<ReceiptVoucherNewPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _saving = false;

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

  Future<void> _saveAttachment() async {
    if (_imageBytes == null) return;
    setState(() {
      _saving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo attachée au bon de réception')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bon de réception')),
      body: SafeArea(
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
                                : Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                  ),
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
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Enregistrement…' : 'Attacher au bon'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
