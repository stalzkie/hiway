import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/profile/experience_dialog.dart';

class ExperienceSection extends StatelessWidget {
  final List<Map<String, dynamic>> experiences;
  final Function(Map<String, dynamic>) onAdd;
  final Function(int, Map<String, dynamic>) onUpdate;
  final Function(int) onRemove;

  const ExperienceSection({
    super.key,
    required this.experiences,
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
          'Work Experience',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (experiences.isEmpty)
          const Text(
            'No experience added yet',
            style: TextStyle(color: Colors.grey),
          ),
        ...experiences.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> experience = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience['title'] ?? 'No title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${experience['company']} • ${experience['start']} - ${experience['end']}',
                  ),
                  if (experience['desc'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      experience['desc'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _editExperience(context, index, experience),
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
          onPressed: () => _addExperience(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Experience'),
        ),
      ],
    );
  }

  Future<void> _addExperience(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ExperienceDialog(),
    );

    if (result != null) {
      onAdd(result);
    }
  }

  Future<void> _editExperience(
    BuildContext context,
    int index,
    Map<String, dynamic> experience,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ExperienceDialog(initialData: experience),
    );

    if (result != null) {
      onUpdate(index, result);
    }
  }
}
