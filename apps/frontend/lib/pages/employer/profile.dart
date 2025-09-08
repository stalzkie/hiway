import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/layout_widgets.dart';
import 'package:hiway_app/widgets/employer/company_profile.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/widgets/common/loading_widget.dart';

/// Employer Profile Page - Single Responsibility Principle
class EmployerProfilePage extends StatefulWidget {
  const EmployerProfilePage({super.key});

  @override
  State<EmployerProfilePage> createState() => _EmployerProfilePageState();
}

class _EmployerProfilePageState extends State<EmployerProfilePage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  EmployerModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load employer profile
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
        _showErrorSnackBar(e.toString());
      }
    }
  }

  /// Refresh profile data
  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
    });
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(size: 48),
        ),
      );
    }

    return Scaffold(
      appBar: EmployerAppBar(
        title: 'Company Profile',
        actions: [
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
          ),
          IconButton(
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.darkColor.withValues(alpha: 0.6),
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Settings'),
                Tab(text: 'Security'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSettingsTab(),
                _buildSecurityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: CompanyProfilePage(
        profile: _profile,
        onEditProfile: _editProfile,
        onUploadDocuments: _uploadDocuments,
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Settings Section
          _buildSettingsSection(
            title: 'Account Settings',
            items: [
              SettingsItem(
                icon: Icons.business,
                title: 'Company Information',
                subtitle: 'Update your company details',
                onTap: _editCompanyInfo,
              ),
              SettingsItem(
                icon: Icons.person,
                title: 'Contact Information',
                subtitle: 'Update contact details',
                onTap: _editContactInfo,
              ),
              SettingsItem(
                icon: Icons.location_on,
                title: 'Business Address',
                subtitle: 'Manage your business locations',
                onTap: _editBusinessAddress,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Notification Settings Section
          _buildSettingsSection(
            title: 'Notifications',
            items: [
              SettingsItem(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Configure app notifications',
                onTap: _configureNotifications,
                trailing: Switch(
                  value: true, // Replace with actual setting
                  onChanged: _toggleNotifications,
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ),
              SettingsItem(
                icon: Icons.email,
                title: 'Email Notifications',
                subtitle: 'Configure email alerts',
                onTap: _configureEmailNotifications,
                trailing: Switch(
                  value: true, // Replace with actual setting
                  onChanged: _toggleEmailNotifications,
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Privacy Settings Section
          _buildSettingsSection(
            title: 'Privacy & Data',
            items: [
              SettingsItem(
                icon: Icons.visibility,
                title: 'Profile Visibility',
                subtitle: 'Control who can see your company profile',
                onTap: _configureProfileVisibility,
              ),
              SettingsItem(
                icon: Icons.download,
                title: 'Export Data',
                subtitle: 'Download your company data',
                onTap: _exportData,
              ),
              SettingsItem(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                subtitle: 'Permanently delete your company account',
                onTap: _showDeleteAccountDialog,
                textColor: AppTheme.errorColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Overview Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.security,
                          color: AppTheme.successColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Status',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your account is secure',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your company account is protected with industry-standard security measures.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Security Settings Section
          _buildSettingsSection(
            title: 'Authentication',
            items: [
              SettingsItem(
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: _changePassword,
              ),
              SettingsItem(
                icon: Icons.phone,
                title: 'Two-Factor Authentication',
                subtitle: 'Add extra security to your account',
                onTap: _setup2FA,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Session Management Section
          _buildSettingsSection(
            title: 'Session Management',
            items: [
              SettingsItem(
                icon: Icons.devices,
                title: 'Active Sessions',
                subtitle: 'Manage your logged-in devices',
                onTap: _viewActiveSessions,
              ),
              SettingsItem(
                icon: Icons.logout,
                title: 'Sign Out All Devices',
                subtitle: 'Log out from all other devices',
                onTap: _signOutAllDevices,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Activity Log Section
          _buildSettingsSection(
            title: 'Activity',
            items: [
              SettingsItem(
                icon: Icons.history,
                title: 'Login History',
                subtitle: 'View your recent login activity',
                onTap: _viewLoginHistory,
              ),
              SettingsItem(
                icon: Icons.report,
                title: 'Security Alerts',
                subtitle: 'Configure security notifications',
                onTap: _configureSecurityAlerts,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<SettingsItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: items
                .map((item) => _buildSettingsItem(item))
                .expand((widget) => [widget, if (widget != items.last) const Divider(height: 1)])
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(SettingsItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (item.textColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          item.icon,
          color: item.textColor ?? AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: item.textColor ?? AppTheme.darkColor,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.darkColor.withValues(alpha: 0.6),
        ),
      ),
      trailing: item.trailing ??
          Icon(
            Icons.chevron_right,
            color: AppTheme.darkColor.withValues(alpha: 0.4),
          ),
      onTap: item.onTap,
    );
  }

  // Action methods (placeholder implementations)
  void _editProfile() => _showFeatureComingSoon('Edit Profile');
  void _uploadDocuments() => _showFeatureComingSoon('Upload Documents');
  void _editCompanyInfo() => _showFeatureComingSoon('Edit Company Info');
  void _editContactInfo() => _showFeatureComingSoon('Edit Contact Info');
  void _editBusinessAddress() => _showFeatureComingSoon('Edit Business Address');
  void _configureNotifications() => _showFeatureComingSoon('Configure Notifications');
  void _configureEmailNotifications() => _showFeatureComingSoon('Configure Email Notifications');
  void _configureProfileVisibility() => _showFeatureComingSoon('Configure Profile Visibility');
  void _exportData() => _showFeatureComingSoon('Export Data');
  void _changePassword() => _showFeatureComingSoon('Change Password');
  void _setup2FA() => _showFeatureComingSoon('Setup 2FA');
  void _viewActiveSessions() => _showFeatureComingSoon('View Active Sessions');
  void _signOutAllDevices() => _showFeatureComingSoon('Sign Out All Devices');
  void _viewLoginHistory() => _showFeatureComingSoon('View Login History');
  void _configureSecurityAlerts() => _showFeatureComingSoon('Configure Security Alerts');

  void _toggleNotifications(bool value) {
    // TODO: Implement notification toggle
    _showFeatureComingSoon('Toggle Notifications');
  }

  void _toggleEmailNotifications(bool value) {
    // TODO: Implement email notification toggle
    _showFeatureComingSoon('Toggle Email Notifications');
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: AppTheme.errorColor),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your company account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showFeatureComingSoon('Delete Account');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showFeatureComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Settings item data class - Following KISS principle
class SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? textColor;

  const SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.textColor,
  });
}
