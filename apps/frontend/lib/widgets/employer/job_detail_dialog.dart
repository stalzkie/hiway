import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/job_post_model.dart';

/// Job Detail Dialog - Shows complete job information
class JobDetailDialog extends StatelessWidget {
  final JobPostModel job;

  const JobDetailDialog({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.jobTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkColor,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        job.jobCompany,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        job.jobLocation,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info
                    _buildInfoRow(
                      'Job Type',
                      'Full-time',
                    ), // Default since not in database
                    _buildInfoRow('Salary', job.formattedSalary),
                    // Removed deadline since it doesn't exist in database
                    _buildInfoRow(
                      'Status',
                      'Active',
                    ), // Default since not in database
                    _buildInfoRow('Posted', '${job.daysSincePosted} days ago'),

                    const SizedBox(height: 24),

                    // Job Overview
                    _buildSection('Job Overview', job.jobOverview),

                    // Skills
                    if (job.jobSkills.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        'Required Skills',
                        null,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: job.jobSkills
                              .map(
                                (skill) => Chip(
                                  label: Text(
                                    skill,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  side: BorderSide.none,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],

                    // Experience Requirements
                    if (job.jobExperience.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        'Experience Requirements',
                        job.experienceDisplayText,
                      ),
                    ],

                    // Education Requirements
                    if (job.jobEducation?.isNotEmpty == true) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        'Education Requirements',
                        job.educationDisplayText,
                      ),
                    ],

                    // Licenses/Certifications
                    if (job.jobLicensesCertifications?.isNotEmpty == true) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        'Licenses & Certifications',
                        job.certificationsDisplayText,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String? content, {Widget? child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (content != null)
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        if (child != null) child,
      ],
    );
  }
}

/// Helper function to show job detail dialog
Future<void> showJobDetailDialog(BuildContext context, JobPostModel job) {
  return showDialog(
    context: context,
    builder: (context) => JobDetailDialog(job: job),
  );
}
