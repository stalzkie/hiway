import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/index.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_post_model.dart';
import 'package:hiway_app/data/services/job_post_service.dart';
import 'package:hiway_app/widgets/employer/job_actions.dart';

class JobsPage extends StatefulWidget {
  final EmployerModel? profile;

  const JobsPage({super.key, this.profile});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage>
    with SingleTickerProviderStateMixin, JobActionsMixin {
  late TabController _tabController;
  final JobPostService _jobPostService = JobPostService();

  List<JobPostModel> _jobs = [];
  List<JobPostModel> _filteredJobs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 1,
      vsync: this,
    ); // Only one tab since no status tracking
    _loadJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load jobs from service
  Future<void> _loadJobs() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final jobs = await _jobPostService.getEmployerJobPosts();
      
      if (jobs.isNotEmpty) {
        print('🔥 DEBUG: First job: ${jobs.first.jobTitle} - ID: ${jobs.first.jobPostId}');
      }
      
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('🔥 DEBUG: Error loading jobs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar('Failed to load jobs: ${e.toString()}');
      }
    }
  }

  /// Apply search and filter criteria
  void _applyFilters() {
    _filteredJobs = _jobs.where((job) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          job.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          job.jobLocation.toLowerCase().contains(_searchQuery.toLowerCase());

      // Since status doesn't exist in database, we'll treat all jobs as active
      final matchesStatus =
          _selectedStatusFilter == 'all' || _selectedStatusFilter == 'active';

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EmployerAppBar(
        title: 'Jobs Management',
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              final result = await showCreateJobForm();
              if (result == true) _loadJobs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Post Job'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Jobs',
          ),
          IconButton(
            onPressed: _showSearchDialog,
            icon: const Icon(Icons.search),
            tooltip: 'Search Jobs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Job Statistics
          JobStatistics(
            jobs: _jobs,
            onCreateJob: () async {
              final result = await showCreateJobForm();
              if (result == true) _loadJobs();
            },
          ),

          // Tab Bar - Simplified to show only active jobs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'All Jobs'),
                // Removed Draft and Closed tabs since status doesn't exist in database
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildJobsList('active'),
                      // Removed draft and closed views
                    ],
                  ),
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

  /// Build jobs list for specific status
  Widget _buildJobsList(String status) {
    // Since status doesn't exist in database, show all jobs in 'active' tab
    // and empty lists for 'draft' and 'closed' tabs
    final jobs = status == 'active' ? _filteredJobs : <JobPostModel>[];

    return JobList(
      jobs: jobs,
      status: status,
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
    // TODO: Navigate to job details page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing details for: ${job.jobTitle}')),
    );
  }

  /// Show filter options
  void _showFilterOptions() {
    JobFilters.show(
      context: context,
      selectedStatusFilter: _selectedStatusFilter,
      onStatusFilterChanged: (filter) {
        setState(() {
          _selectedStatusFilter = filter;
          _applyFilters();
        });
      },
    );
  }

  /// Show search dialog
  void _showSearchDialog() {
    JobSearchDialog.show(
      context: context,
      initialQuery: _searchQuery,
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
          _applyFilters();
        });
      },
    );
  }
}
