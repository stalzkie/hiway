import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/layout_widgets.dart';
import 'package:hiway_app/widgets/employer/dashboard_cards.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';

import 'package:hiway_app/data/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CandidatesPage extends StatefulWidget {
  final EmployerModel? profile;

  const CandidatesPage({super.key, this.profile});

  @override
  State<CandidatesPage> createState() => _CandidatesPageState();
}

class _CandidatesPageState extends State<CandidatesPage> {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<EnrichedApplicationModel> _applications = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 Loading applications...');
      final employer = await _authService.getEmployerProfile();
      if (employer == null) {
        print('❌ Employer profile not found');
        throw Exception('Employer profile not found');
      }
      print('✅ Employer found: ${employer.employerId}');

      // Debug info for development (can be removed in production)
      print('🔍 Loading applications for employer: ${employer.employerId}');

      // Build the query to fetch applications with job seeker and job match data
      // Using !left to handle missing foreign key references gracefully
      final queryBuilder = _supabase
          .from('job_application')
          .select('''
            application_id,
            job_post_id,
            job_seeker_id,
            employer_id,
            match_confidence,
            match_snapshot,
            status,
            status_changed_at,
            source,
            resume_url,
            created_at,
            updated_at,
            job_seeker!left (
              job_seeker_id,
              full_name,
              email,
              phone,
              address,
              skills,
              experience,
              education,
              licenses_certifications,
              updated_at
            ),
            job_post!left (
              job_post_id,
              job_title,
              job_company,
              job_location,
              job_overview,
              job_skills,
              salary,
              created_at
            )
          ''')
          .eq('employer_id', employer.employerId);

      // Apply status filter and execute query
      List<dynamic> response;
      if (_statusFilter != 'all') {
        print('🔍 Querying applications with status filter: $_statusFilter');
        response = await queryBuilder
            .eq('status', _statusFilter)
            .order('created_at', ascending: false);
      } else {
        print('🔍 Querying all applications');
        response = await queryBuilder.order('created_at', ascending: false);
      }

      print('📊 Query response: ${response.length} applications found');

      // Debug: Print the first response item to see the structure
      if (response.isNotEmpty) {
        print('🔍 First response item structure:');
        print(jsonEncode(response.first));

        // Let's also try a direct query to the job_seeker table to see if RLS is blocking us
        final directJobSeekerQuery = await _supabase
            .from('job_seeker')
            .select('job_seeker_id, full_name, email')
            .eq('job_seeker_id', response.first['job_seeker_id'])
            .maybeSingle();
        print('🔍 Direct job_seeker query result: $directJobSeekerQuery');
      }

      List<EnrichedApplicationModel> applications = [];

      for (var item in response) {
        try {
          print('🔍 Processing application ${item['application_id']}');
          print('🔍 Job seeker data in response: ${item['job_seeker']}');
          print('🔍 Job post data in response: ${item['job_post']}');

          // If job_seeker data is null, try to fetch it directly
          if (item['job_seeker'] == null) {
            // Job seeker data is null, attempting direct fetch
            try {
              // Try to find job seeker data in various ways
              final jobSeekerId = item['job_seeker_id'] as String;

              // Method 1: Direct lookup in job_seeker table
              var jobSeekerResponse = await _supabase
                  .from('job_seeker')
                  .select(
                    'job_seeker_id, full_name, email, phone, address, skills, experience, education, licenses_certifications, updated_at',
                  )
                  .eq('job_seeker_id', jobSeekerId)
                  .maybeSingle();

              if (jobSeekerResponse != null) {
                item['job_seeker'] = jobSeekerResponse;
                print(
                  '✅ Found job seeker by job_seeker_id: ${jobSeekerResponse['full_name']}',
                );
              } else {
                // Method 2: Try auth_user_id lookup
                jobSeekerResponse = await _supabase
                    .from('job_seeker')
                    .select(
                      'job_seeker_id, full_name, email, phone, address, skills, experience, education, licenses_certifications, updated_at',
                    )
                    .eq('auth_user_id', jobSeekerId)
                    .maybeSingle();

                if (jobSeekerResponse != null) {
                  item['job_seeker'] = jobSeekerResponse;
                  print(
                    '✅ Found job seeker by auth_user_id: ${jobSeekerResponse['full_name']}',
                  );
                } else {
                  // Method 3: Check if there are any job seekers at all and log them
                  final allJobSeekers = await _supabase
                      .from('job_seeker')
                      .select('job_seeker_id, auth_user_id, full_name, email')
                      .limit(3);
                  print('🔍 Available job seekers in database:');
                  for (var js in allJobSeekers) {
                    print(
                      '   - ${js['full_name']} (job_seeker_id: ${js['job_seeker_id']}, auth_user_id: ${js['auth_user_id']})',
                    );
                  }

                  // Method 4: Try to get user info using RPC or other methods
                  try {
                    final userEmail = await _supabase.rpc(
                      'get_user_email',
                      params: {'user_id': jobSeekerId},
                    );
                    if (userEmail != null) {
                      print('� Found user email via RPC: $userEmail');
                      item['job_seeker'] = {
                        'job_seeker_id': jobSeekerId,
                        'full_name': 'Job Seeker',
                        'email': userEmail,
                        'phone': null,
                        'address': null,
                        'skills': [],
                        'experience': [],
                        'education': [],
                        'licenses_certifications': [],
                        'updated_at': DateTime.now().toIso8601String(),
                      };
                    }
                  } catch (rpcError) {
                    // RPC method not available - continuing with fallback
                  }

                  // Job seeker not found - will use fallback data

                  // Option: Create a minimal job seeker record to fix data integrity
                  // Uncomment the following code if you want to auto-create missing profiles
                  /*
                  try {
                    print('🔧 Attempting to create minimal job seeker record...');
                    final createdJobSeeker = await _supabase
                        .from('job_seeker')
                        .insert({
                          'job_seeker_id': jobSeekerId,
                          'full_name': 'Recovered Applicant ${jobSeekerId.substring(0, 8)}',
                          'email': 'recovered-${jobSeekerId.substring(0, 8)}@hiway.com',
                          'role': 'job_seeker',
                          'skills': ['Profile was recovered from application record'],
                          'experience': ['Original profile data was lost'],
                          'education': ['Education history not available'],
                          'licenses_certifications': [],
                        })
                        .select()
                        .single();
                    
                    item['job_seeker'] = createdJobSeeker;
                    print('✅ Created missing job seeker record: ${createdJobSeeker['full_name']}');
                  } catch (createError) {
                    print('❌ Failed to create job seeker record: $createError');
                  }
                  */
                }
              }
            } catch (e) {
              print('❌ Error fetching job seeker: $e');
            }
          }

          // Get job match scores for this application
          final matchScores = await _supabase
              .from('job_match_scores')
              .select(
                'confidence, matched_skills, missing_skills, overall_summary',
              )
              .eq('job_seeker_id', item['job_seeker_id'])
              .eq('job_post_id', item['job_post_id'])
              .order('calculated_at', ascending: false)
              .limit(1)
              .maybeSingle();

          applications.add(
            EnrichedApplicationModel.fromJson(item, matchScores),
          );
        } catch (e) {
          print('⚠️ Skipping application ${item['application_id']}: $e');
          // Continue processing other applications
        }
      }

      print('✅ Successfully processed ${applications.length} applications');
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading applications: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onStatusChanged(String status) {
    setState(() {
      _statusFilter = status;
    });
    _loadApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EmployerAppBar(
        title: 'Candidates',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showStatusFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Applications',
                    value: _applications.length.toString(),
                    icon: Icons.person_outline,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'New Applications',
                    value: _applications
                        .where((app) => app.status == 'submitted')
                        .length
                        .toString(),
                    icon: Icons.new_releases_outlined,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'In Review',
                    value: _applications
                        .where(
                          (app) => [
                            'shortlisted',
                            'interviewed',
                          ].contains(app.status),
                        )
                        .length
                        .toString(),
                    icon: Icons.rate_review_outlined,
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Error loading applications',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadApplications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.darkColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Candidates Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Browse and discover talented professionals looking for opportunities.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final application = _applications[index];
        return ApplicationCard(
          application: application,
          onTap: () => _viewApplicationDetails(application),
          onStatusUpdate: (status) =>
              _updateApplicationStatus(application, status),
        );
      },
    );
  }

  void _showStatusFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All Applications'),
              value: 'all',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Submitted'),
              value: 'submitted',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Shortlisted'),
              value: 'shortlisted',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Interviewed'),
              value: 'interviewed',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Offered'),
              value: 'offered',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Hired'),
              value: 'hired',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
            RadioListTile<String>(
              title: const Text('Rejected'),
              value: 'rejected',
              groupValue: _statusFilter,
              onChanged: (value) {
                Navigator.pop(context);
                _onStatusChanged(value!);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _viewApplicationDetails(EnrichedApplicationModel application) {
    showDialog(
      context: context,
      builder: (context) => ApplicationDetailsDialog(
        application: application,
        onStatusUpdate: (newStatus) =>
            _updateApplicationStatus(application, newStatus),
      ),
    );
  }

  Future<void> _updateApplicationStatus(
    EnrichedApplicationModel application,
    String newStatus,
  ) async {
    try {
      await _supabase
          .from('job_application')
          .update({
            'status': newStatus,
            'status_changed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', application.applicationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );

      // Refresh the applications list
      _loadApplications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Enhanced Application Model with Job Seeker and Job Post data
class EnrichedApplicationModel {
  final String applicationId;
  final String jobPostId;
  final String jobSeekerId;
  final String employerId;
  final double? matchConfidence;
  final Map<String, dynamic>? matchSnapshot;
  final String status;
  final DateTime statusChangedAt;
  final String source;
  final String? resumeUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Enriched data
  final JobSeekerModel jobSeeker;
  final JobPostSummary jobPost;
  final JobMatchSummary? matchData;

  EnrichedApplicationModel({
    required this.applicationId,
    required this.jobPostId,
    required this.jobSeekerId,
    required this.employerId,
    this.matchConfidence,
    this.matchSnapshot,
    required this.status,
    required this.statusChangedAt,
    required this.source,
    this.resumeUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.jobSeeker,
    required this.jobPost,
    this.matchData,
  });

  factory EnrichedApplicationModel.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? matchScores,
  ) {
    // Parsing application data

    final jobSeekerData = json['job_seeker'] as Map<String, dynamic>?;
    final jobPostData = json['job_post'] as Map<String, dynamic>?;

    // Create fallback data for missing job seeker
    final jobSeekerIdShort = (json['job_seeker_id'] as String? ?? 'unknown')
        .substring(0, 8);
    final jobSeeker = jobSeekerData != null
        ? JobSeekerModel.fromJson(jobSeekerData)
        : JobSeekerModel(
            jobSeekerId: json['job_seeker_id'] as String? ?? 'unknown',
            authUserId: json['job_seeker_id'] as String? ?? 'unknown',
            role: 'job_seeker',
            fullName: 'Job Applicant $jobSeekerIdShort',
            email:
                'Contact details not available - profile not found in database',
            phone: 'Phone number not available',
            address: 'Address not available',
            skills: [
              '⚠️ Profile data missing - job seeker record not found in database',
            ],
            experience: [
              '⚠️ Work experience not available - incomplete profile',
            ],
            education: [
              '⚠️ Education background not loaded - missing profile data',
            ],
            licensesCertifications: [
              '⚠️ Certifications not available - profile incomplete',
            ],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

    // Create fallback data for missing job post
    final jobPost = jobPostData != null
        ? JobPostSummary.fromJson(jobPostData)
        : JobPostSummary(
            jobPostId: json['job_post_id'] as String? ?? 'unknown',
            jobTitle: 'Job Post Not Found',
            jobCompany: 'Unknown Company',
            jobLocation: 'Unknown Location',
            jobOverview: 'Job details not available',
            jobSkills: [],
            salary: {'amount': 0.0, 'currency': 'PHP', 'type': 'monthly'},
            createdAt: DateTime.now(),
          );

    print(
      '✅ Using ${jobSeekerData != null ? "real" : "fallback"} job seeker data',
    );
    print('✅ Using ${jobPostData != null ? "real" : "fallback"} job post data');

    return EnrichedApplicationModel(
      applicationId: json['application_id'] as String,
      jobPostId: json['job_post_id'] as String,
      jobSeekerId: json['job_seeker_id'] as String,
      employerId: json['employer_id'] as String,
      matchConfidence: json['match_confidence']?.toDouble(),
      matchSnapshot: json['match_snapshot'] as Map<String, dynamic>?,
      status: json['status'] as String,
      statusChangedAt: DateTime.parse(json['status_changed_at'] as String),
      source: json['source'] as String? ?? 'hiway',
      resumeUrl: json['resume_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      jobSeeker: jobSeeker,
      jobPost: jobPost,
      matchData: matchScores != null
          ? JobMatchSummary.fromJson(matchScores)
          : null,
    );
  }
}

// Simplified Job Post Summary for display
class JobPostSummary {
  final String jobPostId;
  final String jobTitle;
  final String jobCompany;
  final String jobLocation;
  final String jobOverview;
  final List<String> jobSkills;
  final Map<String, dynamic> salary;
  final DateTime createdAt;

  JobPostSummary({
    required this.jobPostId,
    required this.jobTitle,
    required this.jobCompany,
    required this.jobLocation,
    required this.jobOverview,
    required this.jobSkills,
    required this.salary,
    required this.createdAt,
  });

  factory JobPostSummary.fromJson(Map<String, dynamic> json) {
    return JobPostSummary(
      jobPostId: json['job_post_id'] as String,
      jobTitle: json['job_title'] as String,
      jobCompany: json['job_company'] as String,
      jobLocation: json['job_location'] as String,
      jobOverview: json['job_overview'] as String,
      jobSkills: List<String>.from(json['job_skills'] ?? []),
      salary: Map<String, dynamic>.from(json['salary'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Job Match Summary for display
class JobMatchSummary {
  final double confidence;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String? overallSummary;

  JobMatchSummary({
    required this.confidence,
    required this.matchedSkills,
    required this.missingSkills,
    this.overallSummary,
  });

  factory JobMatchSummary.fromJson(Map<String, dynamic> json) {
    return JobMatchSummary(
      confidence: (json['confidence'] as num).toDouble(),
      matchedSkills: List<String>.from(json['matched_skills'] ?? []),
      missingSkills: List<String>.from(json['missing_skills'] ?? []),
      overallSummary: json['overall_summary'] as String?,
    );
  }
}

// Application Card Widget for displaying enriched application data
class ApplicationCard extends StatelessWidget {
  final EnrichedApplicationModel application;
  final VoidCallback onTap;
  final Function(String) onStatusUpdate;

  const ApplicationCard({
    super.key,
    required this.application,
    required this.onTap,
    required this.onStatusUpdate,
  });

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return '#3B82F6'; // Blue
      case 'shortlisted':
        return '#F59E0B'; // Orange
      case 'interviewed':
        return '#8B5CF6'; // Purple
      case 'offered':
        return '#10B981'; // Green
      case 'hired':
        return '#059669'; // Dark Green
      case 'rejected':
        return '#EF4444'; // Red
      default:
        return '#6B7280'; // Gray
    }
  }

  Color _getStatusColorObject(String status) {
    final colorHex = _getStatusColor(status);
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  }

  List<String> _splitFullName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) {
      return [fullName, ''];
    }
    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');
    return [firstName, lastName];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobSeeker = application.jobSeeker;
    final job = application.jobPost;
    final nameParts = _splitFullName(jobSeeker.fullName);
    final firstName = nameParts[0];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Job Seeker Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobSeeker.fullName,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          jobSeeker.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkColor.withValues(alpha: 0.7),
                          ),
                        ),
                        if (jobSeeker.address != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppTheme.darkColor.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  jobSeeker.address!,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColorObject(
                        application.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      application.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColorObject(application.status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Job Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 16,
                          color: AppTheme.darkColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            job.jobTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 16,
                          color: AppTheme.darkColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(job.jobCompany, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (application.matchData != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Match: ${application.matchData!.confidence.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Skills Preview
              if (jobSeeker.skills.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: jobSeeker.skills.take(5).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: application.status == 'submitted'
                          ? () => onStatusUpdate('rejected')
                          : null,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: application.status == 'submitted'
                          ? () => onStatusUpdate('shortlisted')
                          : onTap,
                      icon: Icon(
                        application.status == 'submitted'
                            ? Icons.check
                            : Icons.visibility,
                        size: 18,
                      ),
                      label: Text(
                        application.status == 'submitted'
                            ? 'Accept'
                            : 'View Details',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: application.status == 'submitted'
                            ? Colors.green
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Application Details Dialog
class ApplicationDetailsDialog extends StatelessWidget {
  final EnrichedApplicationModel application;
  final Function(String) onStatusUpdate;

  const ApplicationDetailsDialog({
    super.key,
    required this.application,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobSeeker = application.jobSeeker;
    final job = application.jobPost;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Application Details',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warning for missing profile data
            if (jobSeeker.fullName.contains('Job Applicant') &&
                jobSeeker.skills.first.contains('⚠️')) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Profile Incomplete: This candidate\'s profile data is missing from the database. The application exists but the job seeker profile may have been deleted or never fully created.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Contact your system administrator to resolve this data integrity issue.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // Show dialog with candidate ID for admin reference
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Missing Profile Details'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Technical Details for Admin:'),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      'Application ID: ${application.applicationId}',
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      'Job Seeker ID: ${application.jobSeekerId}',
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'The job_application record exists but the referenced job_seeker record is missing from the database.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          label: Text(
                            'Details',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job Seeker Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Candidate Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Name: ${jobSeeker.fullName}'),
                            const SizedBox(height: 8),
                            Text('Email: ${jobSeeker.email}'),
                            if (jobSeeker.phone != null) ...[
                              const SizedBox(height: 8),
                              Text('Phone: ${jobSeeker.phone}'),
                            ],
                            if (jobSeeker.address != null) ...[
                              const SizedBox(height: 8),
                              Text('Address: ${jobSeeker.address}'),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Experience
                    if (jobSeeker.experience.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Experience',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...jobSeeker.experience
                                  .take(3)
                                  .map(
                                    (exp) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('• $exp'),
                                    ),
                                  ),
                              if (jobSeeker.experience.length > 3)
                                Text(
                                  '... and ${jobSeeker.experience.length - 3} more',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Education
                    if (jobSeeker.education.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Education',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...jobSeeker.education.map(
                                (edu) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text('• $edu'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Licenses & Certifications
                    if (jobSeeker.licensesCertifications.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Licenses & Certifications',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...jobSeeker.licensesCertifications.map(
                                (cert) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text('• $cert'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Job Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Job Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Position: ${job.jobTitle}'),
                            const SizedBox(height: 8),
                            Text('Company: ${job.jobCompany}'),
                            const SizedBox(height: 8),
                            Text('Location: ${job.jobLocation}'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Skills
                    if (jobSeeker.skills.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Skills',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: jobSeeker.skills.map((skill) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      skill,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Match Information
                    if (application.matchData != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Match Analysis',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Match Score: ${application.matchData!.confidence.toStringAsFixed(1)}%',
                              ),

                              if (application
                                  .matchData!
                                  .matchedSkills
                                  .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Matching Skills:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  application.matchData!.matchedSkills.join(
                                    ', ',
                                  ),
                                ),
                              ],

                              if (application
                                  .matchData!
                                  .missingSkills
                                  .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Missing Skills:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  application.matchData!.missingSkills.join(
                                    ', ',
                                  ),
                                ),
                              ],

                              if (application.matchData!.overallSummary !=
                                  null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Summary:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(application.matchData!.overallSummary!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Application Status
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Application Status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Current Status: ${application.status.toUpperCase()}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Applied: ${_formatDate(application.createdAt)}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Last Updated: ${_formatDate(application.updatedAt)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                if (application.status == 'submitted') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onStatusUpdate('rejected');
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onStatusUpdate('shortlisted');
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
