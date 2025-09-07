import 'package:flutter/material.dart';

class LicenseDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const LicenseDialog({super.key, this.initialData});

  @override
  State<LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends State<LicenseDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _issuerController;
  late final TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _issuerController = TextEditingController();
    _yearController = TextEditingController();

    // Populate with existing data if editing
    if (widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _issuerController.text = widget.initialData!['issuer'] ?? '';
      _yearController.text = widget.initialData!['year']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _issuerController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _nameController.text.trim().isNotEmpty &&
        _issuerController.text.trim().isNotEmpty &&
        _yearController.text.trim().isNotEmpty &&
        int.tryParse(_yearController.text.trim()) != null;
  }

  Map<String, dynamic>? get _licenseData {
    if (!_isValid) return null;

    return {
      'name': _nameController.text.trim(),
      'issuer': _issuerController.text.trim(),
      'year': int.parse(_yearController.text.trim()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit License/Certification' : 'Add License/Certification',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'License/Certification Name *',
                hintText: 'e.g., AWS Cloud Practitioner',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerController,
              decoration: const InputDecoration(
                labelText: 'Issuing Organization *',
                hintText: 'e.g., Amazon, TESDA',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year Obtained *',
                hintText: 'e.g., 2023',
              ),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid
              ? () => Navigator.pop(context, _licenseData)
              : null,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
