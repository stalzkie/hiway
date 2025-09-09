import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/widgets/employer/job_card.dart';

/// Job List Widget - displays list of jobs with empty states
class JobList extends StatelessWidget {
  final List<JobPostModel> jobs;
  final String status;
  final Future<void> Function()? onRefresh;
  final Function(JobPostModel)? onViewJob;
  final Function(JobPostModel)? onEditJob;
  final Function(JobPostModel)? onDeleteJob;
  final VoidCallback? onCreateJob;

  const JobList({
    super.key,
    required this.jobs,
    required this.status,
    this.onRefresh,
    this.onViewJob,
    this.onEditJob,
    this.onDeleteJob,
    this.onCreateJob,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return JobEmptyState(status: status, onCreateJob: onCreateJob);
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          return JobCard(
            job: job,
            onView: () => onViewJob?.call(job),
            onEdit: () => onEditJob?.call(job),
            onDelete: () => onDeleteJob?.call(job),
          );
        },
      ),
    );
  }
}

/// Empty State Widget for Job Lists
class JobEmptyState extends StatelessWidget {
  final String status;
  final VoidCallback? onCreateJob;

  const JobEmptyState({super.key, required this.status, this.onCreateJob});

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    switch (status) {
      case 'active':
        message = 'No active job posts yet.\nCreate your first job posting!';
        icon = Icons.work_outline;
        break;
      case 'closed':
        message = 'No closed jobs.\nCompleted jobs will appear here.';
        icon = Icons.archive_outlined;
        break;
      default:
        message = 'No jobs found.';
        icon = Icons.search_off;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
          ),
          if (status == 'active' && onCreateJob != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create First Job'),
            ),
          ],
        ],
      ),
    );
  }
}
