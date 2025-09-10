import 'package:flutter/material.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

import 'package:hiway_app/pages/employer/jobs.dart' as employer_jobs;
import 'package:hiway_app/pages/employer/candidate.dart';
import 'package:hiway_app/pages/employer/profile.dart';
import 'package:hiway_app/widgets/employer/job_actions.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({super.key});

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard>
    with JobActionsMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  EmployerModel? _profile;
  bool _isLoading = true;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getEmployerProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _searchCandidates({String? query}) {
    // Navigate to candidates page with search
    _handleBottomNavTap(2);
  }

  void _handleBottomNavTap(int index) {
    setState(() => _currentNavIndex = index);
  }

  void _handlePostJob() async {
    final result = await showCreateJobForm();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Go to Jobs tab to manage your new posting!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
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

    // Main dashboard with navigation
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _getCurrentPage(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentNavIndex) {
      case 0:
        return Column(
          children: [
            _buildHeroSection(),
            Expanded(child: _buildMainContent()),
          ],
        );
      case 1:
        return employer_jobs.JobsPage(profile: _profile);
      case 2:
        return CandidatesPage(profile: _profile);
      case 3:
        return const EmployerProfilePage();
      default:
        return Column(
          children: [
            _buildHeroSection(),
            Expanded(child: _buildMainContent()),
          ],
        );
    }
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
          child: const Icon(
            Icons.business_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _handleBottomNavTap(3),
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
    final companyName = (_profile?.company ?? 'Company').split(' ').first;

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
                    '$greeting, $companyName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let\'s find great candidates',
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
          hintText: 'Search candidates, skills, experience...',
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
            iconSize: 20,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _searchCandidates(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 17,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (q) => _searchCandidates(query: q),
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
      child: SingleChildScrollView(
        child: Column(children: [_buildSectionHeader(), _buildQuickActions()]),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkColor,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _handleBottomNavTap(1),
            child: Text(
              'View all jobs',
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

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'Post Job',
                  subtitle: 'Create new listing',
                  onTap: _handlePostJob,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.people_outline,
                  title: 'View Candidates',
                  subtitle: 'Browse applicants',
                  onTap: () => _handleBottomNavTap(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              0,
              Icons.dashboard_outlined,
              Icons.dashboard,
              'Dashboard',
            ),
            _buildNavItem(1, Icons.work_outline, Icons.work, 'Jobs'),
            _buildNavItem(2, Icons.people_outline, Icons.people, 'Candidates'),
            _buildNavItem(
              3,
              Icons.business_outlined,
              Icons.business,
              'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlinedIcon,
    IconData filledIcon,
    String label,
  ) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => _handleBottomNavTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isActive ? filledIcon : outlinedIcon,
                color: isActive ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 18,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
