import 'package:flutter/material.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/data/services/job_service.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:hiway_app/data/models/job_model.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/job_seeker/bottom_nav.dart';
import 'package:hiway_app/widgets/job_seeker/job_card.dart';

class JobSeekerDashboard extends StatefulWidget {
  const JobSeekerDashboard({super.key});

  @override
  State<JobSeekerDashboard> createState() => _JobSeekerDashboardState();
}

class _JobSeekerDashboardState extends State<JobSeekerDashboard> {
  final AuthService _authService = AuthService();
  final JobService _jobService = JobService(apiBase: AppConstants.apiBase);

  final TextEditingController _searchController = TextEditingController();

  JobSeekerModel? _profile;
  List<JobModel> _recommendedJobs = [];
  bool _isLoading = true;
  bool _isLoadingJobs = true;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Only use jobSeekerId. The /match endpoint expects job_seeker_id (UUID).
  String? _seekerId() => _profile?.jobSeekerId;

  Future<void> _loadDashboardData() async {
    try {
      final profile = await _authService.getJobSeekerProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });

      await _loadRecommendedOrFallback();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingJobs = false;
      });
    }
  }

  /// Try personalized from /match; if empty/error, fallback to generic Supabase list.
  Future<void> _loadRecommendedOrFallback() async {
    setState(() => _isLoadingJobs = true);

    List<JobModel> jobs = const <JobModel>[];
    try {
      final seekerId = _seekerId();
      if (seekerId != null && seekerId.isNotEmpty) {
        jobs = await _jobService.getRecommendedJobs(jobSeekerId: seekerId);
      }
    } catch (_) {
      // swallow and fallback below
    }

    if (jobs.isEmpty) {
      try {
        jobs = await _jobService.getAllJobs(limit: 20);
      } catch (_) {
        // still empty
      }
    }

    if (!mounted) return;
    setState(() {
      _recommendedJobs = jobs;
      _isLoadingJobs = false;
    });
  }

  // Unpersonalized search/browse list (explicit user search)
  Future<void> _searchJobs({String? query}) async {
    setState(() => _isLoadingJobs = true);
    try {
      final jobs = await _jobService.getAllJobs(
        searchQuery: (query ?? _searchController.text).trim(),
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _recommendedJobs = jobs;
        _isLoadingJobs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _refresh() async {
    _searchController.clear();
    await _loadRecommendedOrFallback();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your dashboard...',
                style: TextStyle(
                  color: AppTheme.darkColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildHeroSection(),
          Expanded(child: _buildMainContent()),
        ],
      ),
      bottomNavigationBar: JobSeekerBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          _handleBottomNavTap(index);
        },
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildWelcomeSection(),
              const Spacer(),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.work_outline, color: Colors.white, size: 24),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _handleBottomNavTap(2),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    final greeting = _getGreeting();
    final userName = (_profile?.fullName ?? 'there').split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $userName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let\'s find your perfect job',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search jobs, companies, skills...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(15),
            child: Icon(
              Icons.search_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
            onPressed: () => _searchJobs(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (q) => _searchJobs(query: q),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _refresh,
        // IMPORTANT: child must be scrollable even when loading/empty (see _buildJobsList)
        child: Column(
          children: [
            _buildSectionHeader(),
            Expanded(child: _buildJobsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Text(
            'Fitting for you',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkColor,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await _searchJobs(); // show generic list
            },
            child: Text(
              'View all',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList() {
    // Always return a scrollable to keep RefreshIndicator working
    if (_isLoadingJobs) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 40),
        children: [
          Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding jobs for you...',
                  style: TextStyle(
                    color: AppTheme.darkColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_recommendedJobs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        children: [_buildEmptyState()],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _recommendedJobs.length,
      itemBuilder: (context, index) {
        final job = _recommendedJobs[index];
        return JobCard(job: job, onTap: () => _handleJobTap(job));
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.work_outline_rounded,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term or pull to refresh',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _refresh, child: const Text('Refresh')),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _handleJobTap(JobModel job) {
    debugPrint('Tapped on job: ${job.title}');
  }

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        // Already on dashboard, do nothing
        break;
      case 1:
        // Reset to home index before navigating
        setState(() => _currentNavIndex = 0);
        Navigator.pushNamed(context, AppConstants.roadmapRoute).then((_) {
          // Reset to home when returning from roadmap
          if (mounted) {
            setState(() => _currentNavIndex = 0);
          }
        });
        break;
      case 2:
        // Reset to home index before navigating
        setState(() => _currentNavIndex = 0);
        Navigator.pushNamed(context, AppConstants.profileRoute).then((_) {
          // Reset to home when returning from profile
          if (mounted) {
            setState(() => _currentNavIndex = 0);
          }
        });
        break;
    }
  }
}
