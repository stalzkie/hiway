import 'package:flutter/material.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/data/services/job_post_service.dart';
import 'package:hiway_app/widgets/employer/job_post_form.dart';

/// Job Actions Mixin - provides CRUD operations for job posts
mixin JobActionsMixin<T extends StatefulWidget> on State<T> {
  final JobPostService _jobPostService = JobPostService();

  /// Show success message
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error message
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show create job form
  Future<bool?> showCreateJobForm() async {
    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JobPostForm(
          onSubmit: handleJobSubmission,
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Show edit job form
  Future<bool?> showEditJobForm(JobPostModel job) async {
    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JobPostForm(
          existingJob: job,
          onSubmit: (formData) => handleJobUpdate(job.jobPostId, formData),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Handle job submission (create)
  Future<void> handleJobSubmission(JobPostFormData formData) async {
    try {
      await _jobPostService.createJobPost(
        jobTitle: formData.jobTitle,
        jobOverview: formData.jobOverview,
        jobLocation: formData.jobLocation,
        salary: formData.salary,
        jobSkills: formData.jobSkills,
        jobExperience: formData.jobExperience,
        jobEducation: formData.jobEducation,
        jobLicensesCertifications: formData.jobLicensesCertifications,
        // Removed jobType and deadline since they don't exist in database
      );

      if (mounted) {
        Navigator.pop(context, true);
        showSuccessSnackBar('Job posted successfully!');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar('Failed to create job: ${e.toString()}');
      }
    }
  }

  /// Handle job update
  Future<void> handleJobUpdate(String jobId, JobPostFormData formData) async {
    try {
      await _jobPostService.updateJobPost(
        jobPostId: jobId,
        jobTitle: formData.jobTitle,
        jobOverview: formData.jobOverview,
        jobLocation: formData.jobLocation,
        salary: formData.salary,
        jobSkills: formData.jobSkills,
        jobExperience: formData.jobExperience,
        jobEducation: formData.jobEducation,
        jobLicensesCertifications: formData.jobLicensesCertifications,
        // Removed jobType and deadline since they don't exist in database
      );

      if (mounted) {
        Navigator.pop(context, true);
        showSuccessSnackBar('Job updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar('Failed to update job: ${e.toString()}');
      }
    }
  }

  /// Show delete confirmation dialog
  Future<void> showDeleteConfirmation(JobPostModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Post'),
        content: Text(
          'Are you sure you want to delete "${job.jobTitle}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteJob(job.jobPostId);
    }
  }

  /// Delete job
  Future<void> deleteJob(String jobId) async {
    try {
      await _jobPostService.deleteJobPost(jobId);
      showSuccessSnackBar('Job deleted successfully');
    } catch (e) {
      showErrorSnackBar('Failed to delete job: ${e.toString()}');
    }
  }
}
