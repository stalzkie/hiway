import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/data/models/job_experience_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Job Post Service - CRUD operations for job posts
/// Following Single Responsibility and Clean Code principles
class JobPostService {
  static final JobPostService _instance = JobPostService._internal();
  factory JobPostService() => _instance;
  JobPostService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  static const String _tableName = 'job_post';

  /// Create a new job post
  Future<JobPostModel> createJobPost({
    required String jobTitle,
    required String jobOverview,
    required String jobLocation,
    required SalaryModel salary,
    List<String> jobSkills = const [],
    List<JobExperienceModel> jobExperience = const [],
    List<String>? jobEducation,
    List<String>? jobLicensesCertifications,
    String jobType = 'full-time',
    DateTime? deadline,
  }) async {
    try {
      // Get current employer
      final employer = await _authService.getEmployerProfile();
      if (employer == null) {
        throw AuthException(
          'No employer profile found. Please complete your profile first.',
        );
      }

      final jobData = {
        'posted_by': employer.employerId,
        'job_title': jobTitle.trim(),
        'job_company': employer.company ?? '',
        'job_location': jobLocation.trim(),
        'job_overview': jobOverview.trim(),
        'job_skills': jobSkills,
        'job_experience': jobExperience.map((e) => e.toJson()).toList(),
        'job_education': jobEducation?.isEmpty == true ? null : jobEducation,
        'job_licenses_certifications':
            jobLicensesCertifications?.isEmpty == true
            ? null
            : jobLicensesCertifications,
        'salary': salary.toJson(),
        // Removed job_type, deadline, and status as they don't exist in the database schema
      };

      final response = await _client
          .from(_tableName)
          .insert(jobData)
          .select()
          .single();

      return JobPostModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to create job post: ${e.message}');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to create job post: $e');
    }
  }

  /// Get all jobs posted by a specific employer
  Future<List<JobPostModel>> getJobsByEmployer(String employerId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('posted_by', employerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => JobPostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        'Failed to get jobs by employer: ${e.toString()}',
      );
    }
  }

  /// Update an existing job post
  Future<JobPostModel> updateJobPost({
    required String jobPostId,
    String? jobTitle,
    String? jobOverview,
    String? jobLocation,
    SalaryModel? salary,
    List<String>? jobSkills,
    List<JobExperienceModel>? jobExperience,
    List<String>? jobEducation,
    List<String>? jobLicensesCertifications,
    String? jobType,
    DateTime? deadline,
  }) async {
    try {
      // Verify ownership
      await _verifyJobOwnership(jobPostId);

      final updateData = <String, dynamic>{};

      if (jobTitle != null) updateData['job_title'] = jobTitle.trim();
      if (jobOverview != null) updateData['job_overview'] = jobOverview.trim();
      if (jobLocation != null) updateData['job_location'] = jobLocation.trim();
      if (salary != null) updateData['salary'] = salary.toJson();
      if (jobSkills != null) updateData['job_skills'] = jobSkills;
      if (jobExperience != null) {
        updateData['job_experience'] = jobExperience
            .map((e) => e.toJson())
            .toList();
      }
      if (jobEducation != null) updateData['job_education'] = jobEducation;
      if (jobLicensesCertifications != null) {
        updateData['job_licenses_certifications'] = jobLicensesCertifications;
      }
      // Removed job_type and deadline updates as they don't exist in database

      if (updateData.isEmpty) {
        throw ValidationException('No fields to update');
      }

      final response = await _client
          .from(_tableName)
          .update(updateData)
          .eq('job_post_id', jobPostId)
          .select()
          .single();

      return JobPostModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Job post not found');
      }
      throw DatabaseException('Failed to update job post: ${e.message}');
    } catch (e) {
      if (e is AuthException ||
          e is NotFoundException ||
          e is ValidationException) {
        rethrow;
      }
      throw DatabaseException('Failed to update job post: $e');
    }
  }

  /// Delete a job post
  Future<void> deleteJobPost(String jobPostId) async {
    try {
      // Verify ownership
      await _verifyJobOwnership(jobPostId);

      await _client.from(_tableName).delete().eq('job_post_id', jobPostId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Job post not found');
      }
      throw DatabaseException('Failed to delete job post: ${e.message}');
    } catch (e) {
      if (e is AuthException || e is NotFoundException) {
        rethrow;
      }
      throw DatabaseException('Failed to delete job post: $e');
    }
  }

  /// Get a single job post by ID
  Future<JobPostModel?> getJobPostById(String jobPostId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_post_id', jobPostId)
          .maybeSingle();

      if (response == null) return null;
      return JobPostModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to fetch job post: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to fetch job post: $e');
    }
  }

  /// Get all job posts by current employer
  Future<List<JobPostModel>> getEmployerJobPosts({
    int? limit = 50,
    int? offset = 0,
  }) async {
    try {
      final employer = await _authService.getEmployerProfile();
      if (employer == null) {
        throw AuthException('No employer profile found');
      }

      var query = _client
          .from(_tableName)
          .select()
          .eq('posted_by', employer.employerId)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null && offset > 0) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }

      final response = await query;

      return (response as List)
          .map((job) => JobPostModel.fromJson(job as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to fetch employer job posts: ${e.message}',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to fetch employer job posts: $e');
    }
  }

  /// Search job posts with filters
  Future<List<JobPostModel>> searchJobPosts({
    String? searchQuery,
    String? location,
    List<String>? skills,
    SalaryModel? minSalary,
    SalaryModel? maxSalary,
    String? jobType,
    int? limit = 50,
    int? offset = 0,
  }) async {
    try {
      var query = _client.from(_tableName).select();

      // Add search conditions
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'job_title.ilike.%$searchQuery%,job_overview.ilike.%$searchQuery%,job_company.ilike.%$searchQuery%',
        );
      }

      if (location != null && location.isNotEmpty) {
        query = query.ilike('job_location', '%$location%');
      }

      if (jobType != null && jobType.isNotEmpty) {
        query = query.eq('job_type', jobType);
      }

      // Skills filter - check if job_skills array contains any of the specified skills
      if (skills != null && skills.isNotEmpty) {
        final skillsFilter = skills
            .map((skill) => 'job_skills.cs.["$skill"]')
            .join(',');
        query = query.or(skillsFilter);
      }

      // Salary filters (simplified - would need more complex logic for different currency/types)
      if (minSalary != null) {
        query = query.gte('salary->amount', minSalary.amount);
      }

      if (maxSalary != null) {
        query = query.lte('salary->amount', maxSalary.amount);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit ?? 50)
          .range(offset ?? 0, (offset ?? 0) + (limit ?? 50) - 1);

      return (response as List)
          .map((job) => JobPostModel.fromJson(job as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to search job posts: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to search job posts: $e');
    }
  }

  /// Get recent job posts (for dashboard/feed)
  Future<List<JobPostModel>> getRecentJobPosts({int limit = 20}) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((job) => JobPostModel.fromJson(job as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to fetch recent job posts: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to fetch recent job posts: $e');
    }
  }

  /// Get job posts count for employer dashboard
  Future<Map<String, int>> getEmployerJobStats() async {
    try {
      final employer = await _authService.getEmployerProfile();
      if (employer == null) {
        return {'total': 0, 'active': 0, 'expired': 0};
      }

      final jobs = await getEmployerJobPosts();
      final now = DateTime.now();

      int total = jobs.length;
      int active = jobs
          .where((job) => job.deadline == null || job.deadline!.isAfter(now))
          .length;
      int expired = jobs
          .where((job) => job.deadline != null && job.deadline!.isBefore(now))
          .length;

      return {'total': total, 'active': active, 'expired': expired};
    } catch (e) {
      return {'total': 0, 'active': 0, 'expired': 0};
    }
  }

  /// Verify that the current user owns the job post
  Future<void> _verifyJobOwnership(String jobPostId) async {
    final employer = await _authService.getEmployerProfile();
    if (employer == null) {
      throw AuthException('No employer profile found');
    }

    final job = await getJobPostById(jobPostId);
    if (job == null) {
      throw NotFoundException('Job post not found');
    }

    if (job.postedBy != employer.employerId) {
      throw AuthException('You do not have permission to modify this job post');
    }
  }

  /// Batch operations for efficiency
  Future<List<JobPostModel>> createMultipleJobPosts(
    List<Map<String, dynamic>> jobsData,
  ) async {
    try {
      final employer = await _authService.getEmployerProfile();
      if (employer == null) {
        throw AuthException('No employer profile found');
      }

      // Add employer info to all jobs
      final enrichedJobsData = jobsData.map((jobData) {
        return {
          ...jobData,
          'posted_by': employer.employerId,
          'job_company': employer.company ?? '',
        };
      }).toList();

      final response = await _client
          .from(_tableName)
          .insert(enrichedJobsData)
          .select();

      return (response as List)
          .map((job) => JobPostModel.fromJson(job as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to create job posts: ${e.message}');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to create job posts: $e');
    }
  }

  /// Update multiple job posts
  Future<void> updateMultipleJobPosts(
    List<String> jobPostIds,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Verify ownership of all jobs
      for (final jobId in jobPostIds) {
        await _verifyJobOwnership(jobId);
      }

      await _client
          .from(_tableName)
          .update(updates)
          .inFilter('job_post_id', jobPostIds);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to update job posts: ${e.message}');
    } catch (e) {
      if (e is AuthException || e is NotFoundException) {
        rethrow;
      }
      throw DatabaseException('Failed to update job posts: $e');
    }
  }

  /// Delete multiple job posts
  Future<void> deleteMultipleJobPosts(List<String> jobPostIds) async {
    try {
      // Verify ownership of all jobs
      for (final jobId in jobPostIds) {
        await _verifyJobOwnership(jobId);
      }

      await _client
          .from(_tableName)
          .delete()
          .inFilter('job_post_id', jobPostIds);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to delete job posts: ${e.message}');
    } catch (e) {
      if (e is AuthException || e is NotFoundException) {
        rethrow;
      }
      throw DatabaseException('Failed to delete job posts: $e');
    }
  }
}
