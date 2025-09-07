import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/profile/license_dialog.dart';

class LicenseSection extends StatelessWidget {
  final List<Map<String, dynamic>> licenses;
  final Function(Map<String, dynamic>) onAdd;
  final Function(int, Map<String, dynamic>) onUpdate;
  final Function(int) onRemove;

  const LicenseSection({
    super.key,
    required this.licenses,
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
          'Licenses & Certifications',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (licenses.isEmpty)
          const Text(
            'No licenses/certifications added yet',
            style: TextStyle(color: Colors.grey),
          ),
        ...licenses.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> license = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    license['name'] ?? 'No name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${license['issuer']} • ${license['year']}'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _editLicense(context, index, license),
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
          onPressed: () => _addLicense(context),
          icon: const Icon(Icons.add),
          label: const Text('Add License/Certification'),
        ),
      ],
    );
  }

  Future<void> _addLicense(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const LicenseDialog(),
    );

    if (result != null) {
      onAdd(result);
    }
  }

  Future<void> _editLicense(
    BuildContext context,
    int index,
    Map<String, dynamic> license,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LicenseDialog(initialData: license),
    );

    if (result != null) {
      onUpdate(index, result);
    }
  }
}
