import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/index.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/data/services/job_post_service.dart';

class JobsPage extends StatefulWidget {
  final EmployerModel? profile;

  const JobsPage({super.key, this.profile});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with JobActionsMixin {
  final JobPostService _jobPostService = JobPostService();
  final TextEditingController _searchController = TextEditingController();

  List<JobPostModel> _jobs = [];
  List<JobPostModel> _filteredJobs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load jobs from service
  Future<void> _loadJobs() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final jobs = await _jobPostService.getEmployerJobPosts();

      if (mounted) {
        setState(() {
          _jobs = jobs;
          _applySearch();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar('Failed to load jobs: ${e.toString()}');
      }
    }
  }

  /// Apply search filter
  void _applySearch() {
    final query = _searchController.text.trim();
    _filteredJobs = _jobs.where((job) {
      if (query.isEmpty) return true;

      final searchLower = query.toLowerCase();
      return job.jobTitle.toLowerCase().contains(searchLower) ||
          job.jobLocation.toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs Management'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              final result = await showCreateJobForm();
              if (result == true) _loadJobs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Post Job'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search jobs by title or location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        iconSize: 20,
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applySearch());
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() => _applySearch());
              },
            ),
          ),

          // Job Statistics
          JobStatistics(
            jobs: _jobs,
            onCreateJob: () async {
              final result = await showCreateJobForm();
              if (result == true) _loadJobs();
            },
          ),

          // Jobs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildJobsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showCreateJobForm();
          if (result == true) _loadJobs();
        },
        backgroundColor: AppTheme.primaryColor,
        label: const Text(
          'Post New Job',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Build jobs list
  Widget _buildJobsList() {
    return JobList(
      jobs: _filteredJobs,
      status: 'active',
      onRefresh: _loadJobs,
      onViewJob: _viewJobDetails,
      onEditJob: (job) async {
        final result = await showEditJobForm(job);
        if (result == true) _loadJobs();
      },
      onDeleteJob: (job) async {
        await showDeleteConfirmation(job);
        _loadJobs(); // Refresh after delete
      },
      onCreateJob: () async {
        final result = await showCreateJobForm();
        if (result == true) _loadJobs();
      },
    );
  }

  void _viewJobDetails(JobPostModel job) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing details for: ${job.jobTitle}')),
    );
  }
}
