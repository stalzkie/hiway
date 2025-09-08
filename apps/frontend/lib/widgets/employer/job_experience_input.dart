import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/job_experience_model.dart';

class JobExperienceInput extends StatefulWidget {
  final List<JobExperienceModel> initialExperience;
  final Function(List<JobExperienceModel>) onChanged;

  const JobExperienceInput({
    super.key,
    this.initialExperience = const [],
    required this.onChanged,
  });

  @override
  State<JobExperienceInput> createState() => _JobExperienceInputState();
}

class _JobExperienceInputState extends State<JobExperienceInput> {
  List<JobExperienceModel> _experiences = [];

  @override
  void initState() {
    super.initState();
    _experiences = List.from(widget.initialExperience);
    if (_experiences.isEmpty) {
      _experiences.add(const JobExperienceModel(years: 0, domain: ''));
    }
  }

  void _addExperience() {
    setState(() {
      _experiences.add(const JobExperienceModel(years: 0, domain: ''));
    });
  }

  void _removeExperience(int index) {
    if (_experiences.length > 1) {
      setState(() {
        _experiences.removeAt(index);
        widget.onChanged(_experiences);
      });
    }
  }

  void _updateExperience(int index, JobExperienceModel experience) {
    setState(() {
      _experiences[index] = experience;
      widget.onChanged(_experiences);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.work_history,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Experience Requirements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _addExperience,
              icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
              tooltip: 'Add Experience',
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_experiences.length, (index) {
          return _ExperienceEntry(
            key: ValueKey('experience_$index'),
            experience: _experiences[index],
            onChanged: (experience) => _updateExperience(index, experience),
            onRemove: _experiences.length > 1
                ? () => _removeExperience(index)
                : null,
          );
        }),
      ],
    );
  }
}

class _ExperienceEntry extends StatefulWidget {
  final JobExperienceModel experience;
  final Function(JobExperienceModel) onChanged;
  final VoidCallback? onRemove;

  const _ExperienceEntry({
    super.key,
    required this.experience,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_ExperienceEntry> createState() => _ExperienceEntryState();
}

class _ExperienceEntryState extends State<_ExperienceEntry> {
  late TextEditingController _yearsController;
  late TextEditingController _domainController;

  @override
  void initState() {
    super.initState();
    _yearsController = TextEditingController(
      text: widget.experience.years > 0
          ? widget.experience.years.toString()
          : '',
    );
    _domainController = TextEditingController(text: widget.experience.domain);
  }

  @override
  void dispose() {
    _yearsController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _updateExperience() {
    final years = int.tryParse(_yearsController.text) ?? 0;
    final domain = _domainController.text.trim();
    widget.onChanged(JobExperienceModel(years: years, domain: domain));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.backgroundColor,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _yearsController,
                  decoration: InputDecoration(
                    labelText: 'Years *',
                    hintText: 'e.g., 3',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.timer),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateExperience(),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Years required';
                    if (int.tryParse(value!) == null) {
                      return 'Enter valid number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _domainController,
                  decoration: InputDecoration(
                    labelText: 'Domain/Field *',
                    hintText: 'e.g., frontend development',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.domain),
                  ),
                  onChanged: (_) => _updateExperience(),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Domain required';
                    return null;
                  },
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  tooltip: 'Remove',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
