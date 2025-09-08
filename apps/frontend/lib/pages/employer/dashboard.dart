import 'package:flutter/material.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/widgets/common/loading_widget.dart';
import 'package:hiway_app/widgets/employer/layout_widgets.dart';
import 'package:hiway_app/widgets/employer/pages.dart';
import 'package:hiway_app/widgets/employer/company_profile.dart';
import 'package:hiway_app/widgets/employer/job_post_form.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({super.key});

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard> {
  final AuthService _authService = AuthService();
  EmployerModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  void _handlePostJob() {
    // Directly navigate to job creation form
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobPostForm(
          onSubmit: (formData) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Job posted successfully! Go to Jobs tab to manage it.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _handleViewJobs() {
    // This would ideally switch to Jobs tab, but for now show message
    _showFeatureComingSoon('Jobs Management - Please use the Jobs tab');
  }

  void _handleViewCandidates() {
    _showFeatureComingSoon('Browse Candidates');
  }

  void _handleMessages() {
    _showFeatureComingSoon('Messages');
  }

  void _handleEditProfile() {
    _showFeatureComingSoon('Edit Profile');
  }

  void _handleUploadDocuments() {
    _showFeatureComingSoon('Document Upload');
  }

  void _showFeatureComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: LoadingIndicator(size: 48)));
    }

    return EmployerLayout(
      pages: [
        DashboardOverviewPage(
          profile: _profile,
          onPostJobTap: _handlePostJob,
          onViewJobsTap: _handleViewJobs,
          onViewCandidatesTap: _handleViewCandidates,
          onMessagesTap: _handleMessages,
        ),
        const JobsPage(),
        const CandidatesPage(),
        CompanyProfilePage(
          profile: _profile,
          onEditProfile: _handleEditProfile,
          onUploadDocuments: _handleUploadDocuments,
        ),
      ],
      pageTitles: const [
        'Dashboard',
        'My Jobs',
        'Candidates',
        'Company Profile',
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handlePostJob,
        icon: const Icon(Icons.add),
        label: const Text('Post Job'),
      ),
    );
  }
}
