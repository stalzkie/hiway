import 'package:flutter/material.dart';

/// Job Filter Modal Widget
class JobFilters extends StatelessWidget {
  final String selectedStatusFilter;
  final Function(String) onStatusFilterChanged;

  const JobFilters({
    super.key,
    required this.selectedStatusFilter,
    required this.onStatusFilterChanged,
  });

  static void show({
    required BuildContext context,
    required String selectedStatusFilter,
    required Function(String) onStatusFilterChanged,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => JobFilters(
        selectedStatusFilter: selectedStatusFilter,
        onStatusFilterChanged: onStatusFilterChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter Jobs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Status Filter
          Text('Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(context, 'All', 'all'),
              _buildFilterChip(context, 'Active', 'active'),
              _buildFilterChip(context, 'Draft', 'draft'),
              _buildFilterChip(context, 'Closed', 'closed'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: selectedStatusFilter == value,
      onSelected: (selected) {
        onStatusFilterChanged(value);
        Navigator.pop(context);
      },
    );
  }
}

/// Job Search Dialog Widget
class JobSearchDialog extends StatefulWidget {
  final String initialQuery;
  final Function(String) onSearchChanged;

  const JobSearchDialog({
    super.key,
    required this.initialQuery,
    required this.onSearchChanged,
  });

  static void show({
    required BuildContext context,
    required String initialQuery,
    required Function(String) onSearchChanged,
  }) {
    showDialog(
      context: context,
      builder: (context) => JobSearchDialog(
        initialQuery: initialQuery,
        onSearchChanged: onSearchChanged,
      ),
    );
  }

  @override
  State<JobSearchDialog> createState() => _JobSearchDialogState();
}

class _JobSearchDialogState extends State<JobSearchDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Jobs'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter job title or location...',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: widget.onSearchChanged,
      ),
      actions: [
        TextButton(
          onPressed: () {
            _controller.clear();
            widget.onSearchChanged('');
            Navigator.pop(context);
          },
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
