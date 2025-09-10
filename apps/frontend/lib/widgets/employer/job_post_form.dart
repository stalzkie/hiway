import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/data/models/job_experience_model.dart';
import 'package:hiway_app/widgets/employer/job_experience_input.dart';

/// Job Creation/Edit Form - Following KISS and Clean Code principles
class JobPostForm extends StatefulWidget {
  final JobPostModel? existingJob;
  final VoidCallback? onCancel;
  final Function(JobPostFormData)? onSubmit;

  const JobPostForm({
    super.key,
    this.existingJob,
    this.onCancel,
    this.onSubmit,
  });

  @override
  State<JobPostForm> createState() => _JobPostFormState();
}

class _JobPostFormState extends State<JobPostForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _overviewController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _skillsController = TextEditingController();
  final _educationController = TextEditingController();
  final _licensesController = TextEditingController();

  List<JobExperienceModel> _experienceList = [];
  String _selectedSalaryType = 'monthly';
  // Removed _selectedJobType and _deadline since they don't exist in database

  final List<String> _salaryTypes = ['hourly', 'daily', 'monthly', 'yearly'];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.existingJob != null) {
      final job = widget.existingJob!;
      _titleController.text = job.jobTitle;
      _overviewController.text = job.jobOverview;
      _locationController.text = job.jobLocation;
      _salaryController.text = job.salary.amount.toString();
      _skillsController.text = job.jobSkills.join(', ');
      _experienceList = List.from(job.jobExperience);
      _educationController.text = job.jobEducation?.join(', ') ?? '';
      _licensesController.text =
          job.jobLicensesCertifications?.join(', ') ?? '';
      _selectedSalaryType = job.salary.type;
      // Removed job_type and deadline initialization since they don't exist in database
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _overviewController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _skillsController.dispose();
    _educationController.dispose();
    _licensesController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = JobPostFormData(
        jobTitle: _titleController.text.trim(),
        jobOverview: _overviewController.text.trim(),
        jobLocation: _locationController.text.trim(),
        salary: SalaryModel(
          amount: double.tryParse(_salaryController.text) ?? 0,
          currency: 'PHP',
          type: _selectedSalaryType,
        ),
        jobSkills: _parseCommaSeparated(_skillsController.text) ?? [],
        jobExperience: _experienceList,
        jobEducation: _parseCommaSeparated(_educationController.text),
        jobLicensesCertifications: _parseCommaSeparated(
          _licensesController.text,
        ),
        // Removed jobType and deadline since they don't exist in database
      );

      widget.onSubmit?.call(formData);
    }
  }

  List<String>? _parseCommaSeparated(String input) {
    final result = input
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingJob != null ? 'Edit Job' : 'Create New Job'),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: [
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildSectionHeader('Job Details', Icons.work_outline),
              const SizedBox(height: 16),

              // Job Title
              _buildFormField(
                controller: _titleController,
                label: 'Job Title *',
                hint: 'e.g., Senior Flutter Developer',
                prefixIcon: Icons.title,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Job title is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Job Location
              _buildFormField(
                controller: _locationController,
                label: 'Location *',
                hint: 'e.g., Manila, Philippines or Remote',
                prefixIcon: Icons.location_on,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Job Overview
              _buildSectionHeader('Job Description', Icons.description),
              const SizedBox(height: 16),

              _buildFormField(
                controller: _overviewController,
                label: 'Job Overview *',
                hint:
                    'Describe the role, responsibilities, and what you\'re looking for...',
                prefixIcon: Icons.description,
                maxLines: 6,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Job overview is required';
                  }
                  if (value!.length < 50) {
                    return 'Job overview should be at least 50 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Salary Section
              _buildSectionHeader(
                'Salary Information',
                Icons.payments_outlined,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildFormField(
                      controller: _salaryController,
                      label: 'Salary Amount *',
                      hint: 'e.g., 80000',
                      prefixIcon: Icons.currency_exchange,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Salary is required';
                        }
                        if (double.tryParse(value!) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      label: 'Period *',
                      value: _selectedSalaryType,
                      items: _salaryTypes,
                      onChanged: (value) =>
                          setState(() => _selectedSalaryType = value!),
                      icon: Icons.schedule,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Requirements Section
              _buildSectionHeader('Requirements', Icons.checklist),
              const SizedBox(height: 16),

              _buildFormField(
                controller: _skillsController,
                label: 'Required Skills',
                hint:
                    'Flutter, Dart, Mobile Development (separate with commas)',
                prefixIcon: Icons.psychology,
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              JobExperienceInput(
                initialExperience: _experienceList,
                onChanged: (experiences) {
                  setState(() {
                    _experienceList = experiences;
                  });
                },
              ),

              const SizedBox(height: 16),

              _buildFormField(
                controller: _educationController,
                label: 'Education Requirements (Optional)',
                hint:
                    'e.g., Bachelor\'s in Computer Science, IT-related degree (separate with commas)',
                prefixIcon: Icons.school,
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              _buildFormField(
                controller: _licensesController,
                label: 'Licenses/Certifications (Optional)',
                hint:
                    'e.g., PMP Certification, AWS Certified (separate with commas)',
                prefixIcon: Icons.verified,
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.existingJob != null ? 'Update Job' : 'Create Job',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.darkColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey.shade600)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintStyle: TextStyle(color: Colors.grey.shade600),
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.darkColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.backgroundColor,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item
                              .split('-')
                              .map(
                                (word) =>
                                    word[0].toUpperCase() + word.substring(1),
                              )
                              .join(' '),
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Data class for form submission - Following KISS principle
class JobPostFormData {
  final String jobTitle;
  final String jobOverview;
  final String jobLocation;
  final SalaryModel salary;
  final List<String> jobSkills;
  final List<JobExperienceModel> jobExperience;
  final List<String>? jobEducation;
  final List<String>? jobLicensesCertifications;
  // Removed jobType and deadline since they don't exist in database

  const JobPostFormData({
    required this.jobTitle,
    required this.jobOverview,
    required this.jobLocation,
    required this.salary,
    this.jobSkills = const [],
    this.jobExperience = const [],
    this.jobEducation,
    this.jobLicensesCertifications,
    // Removed jobType and deadline parameters
  });
}
