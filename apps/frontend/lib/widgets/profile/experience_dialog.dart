import 'package:flutter/material.dart';

class ExperienceDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const ExperienceDialog({super.key, this.initialData});

  @override
  State<ExperienceDialog> createState() => _ExperienceDialogState();
}

class _ExperienceDialogState extends State<ExperienceDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _companyController = TextEditingController();
    _startController = TextEditingController();
    _endController = TextEditingController();
    _descController = TextEditingController();

    // Populate with existing data if editing
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _companyController.text = widget.initialData!['company'] ?? '';
      _startController.text = widget.initialData!['start'] ?? '';
      _endController.text = widget.initialData!['end'] ?? '';
      _descController.text = widget.initialData!['desc'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _startController.dispose();
    _endController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final isValidResult =
        _titleController.text.trim().isNotEmpty &&
        _companyController.text.trim().isNotEmpty &&
        _startController.text.trim().isNotEmpty &&
        _endController.text.trim().isNotEmpty;
    return isValidResult;
  }

  Map<String, dynamic> get _experienceData {
    return {
      'title': _titleController.text.trim(),
      'company': _companyController.text.trim(),
      'start': _startController.text.trim(),
      'end': _endController.text.trim(),
      'desc': _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Work Experience' : 'Add Work Experience'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Job Title *',
                hintText: 'e.g., Software Engineer',
              ),
              onChanged: (value) =>
                  setState(() {}), // Trigger rebuild to update button state
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company *',
                hintText: 'e.g., Acme Corp',
              ),
              onChanged: (value) =>
                  setState(() {}), // Trigger rebuild to update button state
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startController,
                    decoration: const InputDecoration(
                      labelText: 'Start Date *',
                      hintText: 'YYYY-MM',
                    ),
                    onChanged: (value) => setState(
                      () {},
                    ), // Trigger rebuild to update button state
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endController,
                    decoration: const InputDecoration(
                      labelText: 'End Date *',
                      hintText: 'YYYY-MM or Present',
                    ),
                    onChanged: (value) => setState(
                      () {},
                    ), // Trigger rebuild to update button state
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Describe your responsibilities and achievements',
              ),
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
              ? () {
                  Navigator.pop(context, _experienceData);
                }
              : null,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
