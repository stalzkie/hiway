import 'package:flutter/material.dart';

class EducationDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const EducationDialog({super.key, this.initialData});

  @override
  State<EducationDialog> createState() => _EducationDialogState();
}

class _EducationDialogState extends State<EducationDialog> {
  late final TextEditingController _degreeController;
  late final TextEditingController _schoolController;
  late final TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    _degreeController = TextEditingController();
    _schoolController = TextEditingController();
    _yearController = TextEditingController();

    // Populate with existing data if editing
    if (widget.initialData != null) {
      _degreeController.text = widget.initialData!['degree'] ?? '';
      _schoolController.text = widget.initialData!['school'] ?? '';
      _yearController.text = widget.initialData!['year']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _degreeController.dispose();
    _schoolController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _degreeController.text.trim().isNotEmpty &&
        _schoolController.text.trim().isNotEmpty &&
        _yearController.text.trim().isNotEmpty &&
        int.tryParse(_yearController.text.trim()) != null;
  }

  Map<String, dynamic>? get _educationData {
    if (!_isValid) return null;

    return {
      'degree': _degreeController.text.trim(),
      'school': _schoolController.text.trim(),
      'year': int.parse(_yearController.text.trim()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Education' : 'Add Education'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _degreeController,
              decoration: const InputDecoration(
                labelText: 'Degree/Course *',
                hintText: 'e.g., BS Computer Science',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolController,
              decoration: const InputDecoration(
                labelText: 'School/University *',
                hintText: 'e.g., University of St. La Salle',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year Graduated *',
                hintText: 'e.g., 2024',
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
              ? () => Navigator.pop(context, _educationData)
              : null,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
