import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/widgets/employer/job_detail_dialog.dart';

/// Job Card Widget - displays individual job post information
class JobCard extends StatelessWidget {
  final JobPostModel job;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const JobCard({
    super.key,
    required this.job,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onView ?? () => showJobDetailDialog(context, job),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.jobTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkColor,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job.jobLocation,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const JobStatusChip(
                    status: 'active',
                  ), // Default to active since status doesn't exist in database
                ],
              ),

              const SizedBox(height: 12),

              // Overview (first 100 characters)
              Text(
                job.jobOverview.length > 100
                    ? '${job.jobOverview.substring(0, 100)}...'
                    : job.jobOverview,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Details Row
              Row(
                children: [
                  Icon(Icons.work, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    job.jobType
                        .split('-')
                        .map(
                          (word) => word[0].toUpperCase() + word.substring(1),
                        )
                        .join(' '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    job.formattedSalary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${job.daysSincePosted} days ago',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Requirements Section
              if (job.jobExperience.isNotEmpty ||
                  (job.jobEducation?.isNotEmpty == true) ||
                  (job.jobLicensesCertifications?.isNotEmpty == true)) ...[
                const Divider(),
                const SizedBox(height: 8),
                _buildRequirementsSection(context),
                const SizedBox(height: 12),
              ],

              // Action Buttons
              Row(
                children: [
                  if (onEdit != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primaryColor),
                          foregroundColor: AppTheme.primaryColor,
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                  if (onEdit != null && onDelete != null)
                    const SizedBox(width: 8),
                  if (onDelete != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                ],
              ),

              // Removed deadline warning since deadline doesn't exist in database
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementsSection(BuildContext context) {
    final requirements = <Widget>[];

    // Experience
    if (job.jobExperience.isNotEmpty) {
      requirements.add(
        _buildRequirementItem(
          context,
          Icons.work_history,
          'Experience',
          job.experienceDisplayText,
        ),
      );
    }

    // Education
    if (job.jobEducation?.isNotEmpty == true) {
      requirements.add(
        _buildRequirementItem(
          context,
          Icons.school,
          'Education',
          job.educationDisplayText,
        ),
      );
    }

    // Certifications
    if (job.jobLicensesCertifications?.isNotEmpty == true) {
      requirements.add(
        _buildRequirementItem(
          context,
          Icons.verified,
          'Certifications',
          job.certificationsDisplayText,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requirements',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        ...requirements,
      ],
    );
  }

  Widget _buildRequirementItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Job Status Chip Widget
class JobStatusChip extends StatelessWidget {
  final String status;

  const JobStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        displayText = 'Active';
        break;
      case 'draft':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        displayText = 'Draft';
        break;
      case 'closed':
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        displayText = 'Closed';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Deadline Warning Widget
class DeadlineWarning extends StatelessWidget {
  const DeadlineWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'Application deadline is approaching',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
