import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/profile/education_dialog.dart';

class EducationSection extends StatelessWidget {
  final List<Map<String, dynamic>> educations;
  final Function(Map<String, dynamic>) onAdd;
  final Function(int, Map<String, dynamic>) onUpdate;
  final Function(int) onRemove;

  const EducationSection({
    super.key,
    required this.educations,
    required this.onAdd,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Education',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (educations.isEmpty)
          const Text(
            'No education added yet',
            style: TextStyle(color: Colors.grey),
          ),
        ...educations.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> education = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    education['degree'] ?? 'No degree',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${education['school']} • ${education['year']}'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _editEducation(context, index, education),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => onRemove(index),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => _addEducation(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Education'),
        ),
      ],
    );
  }

  Future<void> _addEducation(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const EducationDialog(),
    );

    if (result != null) {
      onAdd(result);
    }
  }

  Future<void> _editEducation(
    BuildContext context,
    int index,
    Map<String, dynamic> education,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EducationDialog(initialData: education),
    );

    if (result != null) {
      onUpdate(index, result);
    }
  }
}
