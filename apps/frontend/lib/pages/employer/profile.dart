import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/widgets/profile/profile_section.dart';
import 'package:hiway_app/widgets/profile/info_card.dart';

class EmployerProfilePage extends StatefulWidget {
  const EmployerProfilePage({super.key});

  @override
  State<EmployerProfilePage> createState() => _EmployerProfilePageState();
}

class _EmployerProfilePageState extends State<EmployerProfilePage> {
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
                'Loading your profile...',
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
      body: _profile == null ? _buildEmptyProfile() : _buildProfileContent(),
    );
  }

  Widget _buildEmptyProfile() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildEmptyHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business_outlined,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Complete Company Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Set up your company profile to attract top talent and manage your job postings effectively.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHeader() {
    return Row(
      children: [
        Text(
          'Company Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkColor,
          ),
        ),
        const Spacer(),
        _buildMenuButton(),
      ],
    );
  }

  Widget _buildProfileContent() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildProfileCompletion(),
              const SizedBox(height: 24),
              _buildPersonalInformation(),
              const SizedBox(height: 20),
              _buildCompanyInformation(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [_buildMenuButton()],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 40), // Account for app bar height
                  _buildProfileAvatar(),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      _profile?.company ?? 'Company Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      _profile?.companyEmail ?? 'company@example.com',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.business_rounded, size: 40, color: Colors.white),
    );
  }

  Widget _buildMenuButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        iconSize: 24,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onSelected: _handleMenuAction,
        itemBuilder: (context) => [
          _buildMenuItem(
            Icons.logout_rounded,
            'Sign Out',
            'logout',
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    IconData icon,
    String title,
    String value, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? AppTheme.errorColor : Colors.grey[700],
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDestructive ? AppTheme.errorColor : Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletion() {
    final completionPercentage = _calculateProfileCompletion();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Profile Completion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkColor,
                ),
              ),
              const Spacer(),
              Text(
                '$completionPercentage%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _getCompletionColor(completionPercentage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: completionPercentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
              _getCompletionColor(completionPercentage),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            _getCompletionMessage(completionPercentage),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _calculateProfileCompletion() {
    final fields = [
      _profile?.name?.isNotEmpty == true,
      _profile?.companyEmail?.isNotEmpty == true,
      _profile?.company?.isNotEmpty == true,
      _profile?.companyPosition?.isNotEmpty == true,
    ];

    final completed = fields.where((field) => field).length;
    return ((completed / fields.length) * 100).round();
  }

  Color _getCompletionColor(int percentage) {
    if (percentage >= 80) return AppTheme.successColor;
    if (percentage >= 50) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _getCompletionMessage(int percentage) {
    if (percentage >= 80) return 'Great! Your profile is almost complete.';
    if (percentage >= 50) {
      return 'Good progress! Add more details to stand out.';
    }
    return 'Complete your profile to attract top talent.';
  }

  Widget _buildPersonalInformation() {
    return ProfileSection(
      title: 'Personal Information',
      icon: Icons.person_outline_rounded,
      children: [
        InfoCard(
          label: 'Full Name',
          value: _profile?.name ?? 'Not provided',
          isEmpty: _profile?.name?.isEmpty != false,
        ),
        InfoCard(
          label: 'Email',
          value: _profile?.companyEmail ?? 'Not provided',
          isEmpty: _profile?.companyEmail?.isEmpty != false,
        ),
        InfoCard(
          label: 'Position',
          value: _profile?.companyPosition ?? 'Not provided',
          isEmpty: _profile?.companyPosition?.isEmpty != false,
        ),
      ],
    );
  }

  Widget _buildCompanyInformation() {
    return ProfileSection(
      title: 'Company Information',
      icon: Icons.business_outlined,
      children: [
        InfoCard(
          label: 'Company Name',
          value: _profile?.company ?? 'Not provided',
          isEmpty: _profile?.company?.isEmpty != false,
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    if (action == 'logout') _signOut();
  }

  // Helper methods for various actions
  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.loginRoute,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
