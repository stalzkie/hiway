import 'package:flutter/material.dart';
import 'package:hiway_app/core/utils/validators.dart';
import 'package:hiway_app/widgets/profile/experience_section.dart';
import 'package:hiway_app/widgets/profile/education_section.dart';
import 'package:hiway_app/widgets/profile/license_section.dart';

class JobSeekerForm extends StatelessWidget {
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController skillsController;
  final List<Map<String, dynamic>> experienceList;
  final List<Map<String, dynamic>> educationList;
  final List<Map<String, dynamic>> licensesList;
  final Function(Map<String, dynamic>) onAddExperience;
  final Function(int, Map<String, dynamic>) onUpdateExperience;
  final Function(int) onRemoveExperience;
  final Function(Map<String, dynamic>) onAddEducation;
  final Function(int, Map<String, dynamic>) onUpdateEducation;
  final Function(int) onRemoveEducation;
  final Function(Map<String, dynamic>) onAddLicense;
  final Function(int, Map<String, dynamic>) onUpdateLicense;
  final Function(int) onRemoveLicense;
  final bool isLoading;

  const JobSeekerForm({
    super.key,
    required this.fullNameController,
    required this.phoneController,
    required this.addressController,
    required this.skillsController,
    required this.experienceList,
    required this.educationList,
    required this.licensesList,
    required this.onAddExperience,
    required this.onUpdateExperience,
    required this.onRemoveExperience,
    required this.onAddEducation,
    required this.onUpdateEducation,
    required this.onRemoveEducation,
    required this.onAddLicense,
    required this.onUpdateLicense,
    required this.onRemoveLicense,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        // Full Name
        TextFormField(
          controller: fullNameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            prefixIcon: Icon(Icons.person),
          ),
          validator: Validators.validateFullName,
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Phone
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone),
            helperText: 'Format: +639123456789 or 09123456789',
          ),
          validator: Validators.validatePhoneNumber,
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Address
        TextFormField(
          controller: addressController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.location_on),
            helperText: 'Your current address',
          ),
          validator: (value) =>
              Validators.validateOptionalText(value, 'Address', maxLength: 200),
          enabled: !isLoading,
        ),

        const SizedBox(height: 24),

        Text(
          'Professional Information (Optional)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        Text(
          'Adding this information helps employers find you better.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),

        // Skills
        TextFormField(
          controller: skillsController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Skills',
            prefixIcon: Icon(Icons.psychology),
            helperText:
                'Separate skills with commas (e.g., Communication, Leadership)',
          ),
          validator: (value) =>
              Validators.validateOptionalText(value, 'Skills'),
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Experience Section
        ExperienceSection(
          experiences: experienceList,
          onAdd: onAddExperience,
          onUpdate: onUpdateExperience,
          onRemove: onRemoveExperience,
        ),

        const SizedBox(height: 16),

        // Education Section
        EducationSection(
          educations: educationList,
          onAdd: onAddEducation,
          onUpdate: onUpdateEducation,
          onRemove: onRemoveEducation,
        ),

        const SizedBox(height: 16),

        // Licenses Section
        LicenseSection(
          licenses: licensesList,
          onAdd: onAddLicense,
          onUpdate: onUpdateLicense,
          onRemove: onRemoveLicense,
        ),
      ],
    );
  }
}
