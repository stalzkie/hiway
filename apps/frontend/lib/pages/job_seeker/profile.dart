import 'package:flutter/material.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/profile/profile_section.dart';
import 'package:hiway_app/widgets/profile/info_card.dart';
import 'package:hiway_app/widgets/profile/experience_card.dart';
import 'package:hiway_app/widgets/profile/education_card.dart';
import 'package:hiway_app/widgets/profile/empty_state_card.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/core/constants/profile_constants.dart';

class JobSeekerProfile extends StatefulWidget {
  const JobSeekerProfile({super.key});

  @override
  State<JobSeekerProfile> createState() => _JobSeekerProfileState();
}

class _JobSeekerProfileState extends State<JobSeekerProfile> {
  final AuthService _authService = AuthService();
  JobSeekerModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getJobSeekerProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                        Icons.person_add_outlined,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Set up your profile to unlock personalized job recommendations and connect with employers.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Get Started'),
                      ),
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
          'Profile',
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
              _buildQuickStats(),
              const SizedBox(height: 24),
              _buildPersonalInfo(),
              const SizedBox(height: 20),
              _buildWorkExperience(),
              const SizedBox(height: 20),
              _buildEducation(),
              const SizedBox(height: 20),
              _buildSkills(),
              const SizedBox(height: 20),
              _buildLicensesCertifications(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
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
                  const SizedBox(height: 40),
                  _buildProfileAvatar(),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      _profile!.fullName,
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
                      _profile!.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
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
      child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => [
        _buildMenuItem(
          Icons.logout_rounded,
          'Sign Out',
          'logout',
          isDestructive: true,
        ),
      ],
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
          Icon(icon,
              size: 20,
              color: isDestructive ? AppTheme.errorColor : Colors.grey[700]),
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

  /// --- PROFILE COMPLETION + VERIFIED BADGE (mock) ---
  Widget _buildQuickStats() {
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
              Icon(Icons.analytics_outlined,
                  color: AppTheme.primaryColor, size: 24),
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
          const SizedBox(height: 10),
          const _MockVerifiedBadge(), // mock, always visible
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return ProfileSection(
      title: 'Personal Information',
      icon: Icons.person_outline_rounded,
      children: [
        InfoCard(label: 'Full Name', value: _profile!.fullName),
        InfoCard(label: 'Email', value: _profile!.email),
        InfoCard(
          label: 'Phone',
          value: _profile!.phone?.isNotEmpty == true
              ? _profile!.phone!
              : ProfileConstants.notProvidedText,
          isEmpty: _profile!.phone?.isNotEmpty != true,
        ),
        InfoCard(
          label: 'Address',
          value: _profile!.address?.isNotEmpty == true
              ? _profile!.address!
              : ProfileConstants.notProvidedText,
          isEmpty: _profile!.address?.isNotEmpty != true,
        ),
      ],
    );
  }

  Widget _buildWorkExperience() {
    return ProfileSection(
      title: 'Work Experience',
      icon: Icons.work_outline_rounded,
      children: _profile!.experience.isEmpty
          ? [
              const EmptyStateCard(
                  message: ProfileConstants.noExperienceMessage,
                  icon: Icons.work_outline_rounded)
            ]
          : _profile!.experience
              .map((exp) => ExperienceCard(experience: exp))
              .toList(),
    );
  }

  Widget _buildEducation() {
    return ProfileSection(
      title: 'Education',
      icon: Icons.school_outlined,
      children: _profile!.education.isEmpty
          ? [
              const EmptyStateCard(
                  message: ProfileConstants.noEducationMessage,
                  icon: Icons.school_outlined)
            ]
          : _profile!.education
              .map((edu) => EducationCard(education: edu))
              .toList(),
    );
  }

  Widget _buildSkills() {
    return ProfileSection(
      title: 'Skills',
      icon: Icons.psychology_outlined,
      children: [
        if (_profile!.skills.isEmpty)
          const EmptyStateCard(
              message: ProfileConstants.noSkillsMessage,
              icon: Icons.psychology_outlined)
        else
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _profile!.skills.map(_buildSkillChip).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Text(skill,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          )),
    );
  }

  Widget _buildLicensesCertifications() {
    final items = _normalizeLicenses(_profile?.licensesCertifications);
    final isEmpty = items.isEmpty;

    return ProfileSection(
      title: 'Licenses & Certifications',
      icon: Icons.workspace_premium_outlined,
      children: isEmpty
          ? const [
              EmptyStateCard(
                message: ProfileConstants.noLicensesMessage,
                icon: Icons.verified_outlined,
              ),
            ]
          : items.map((it) => _buildLicenseCard(it)).toList(),
    );
  }

  Widget _buildLicenseCard(_LicenseItem item) => _LicenseCard(item: item);

  int _calculateProfileCompletion() {
    final fields = [
      _profile!.fullName.isNotEmpty,
      _profile!.email.isNotEmpty,
      _profile!.phone?.isNotEmpty == true,
      _profile!.address?.isNotEmpty == true,
      _profile!.experience.isNotEmpty,
      _profile!.education.isNotEmpty,
    ];
    final completed = fields.where((f) => f).length;
    return ((completed / fields.length) * 100).round();
  }

  Color _getCompletionColor(int p) => switch (p) {
        >= ProfileConstants.excellentCompletionThreshold => AppTheme.successColor,
        >= ProfileConstants.goodCompletionThreshold => AppTheme.warningColor,
        _ => AppTheme.errorColor,
      };

  String _getCompletionMessage(int p) => switch (p) {
        >= ProfileConstants.excellentCompletionThreshold =>
          ProfileConstants.excellentCompletionMessage,
        >= ProfileConstants.goodCompletionThreshold =>
          ProfileConstants.goodCompletionMessage,
        _ => ProfileConstants.poorCompletionMessage,
      };

  void _handleMenuSelection(String value) {
    if (value == 'logout') _signOut();
  }
}

/* ------------------------------ Mock badge ------------------------------ */
class _MockVerifiedBadge extends StatelessWidget {
  const _MockVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.successColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------ Licenses: model + normalizer + card ------------------ */

class _LicenseItem {
  final String name;
  final String? issuer;
  final String? year;
  final String? credentialId;
  final String? url;

  _LicenseItem({
    required this.name,
    this.issuer,
    this.year,
    this.credentialId,
    this.url,
  });
}

// Accepts List<String> OR List<Map> OR null
List<_LicenseItem> _normalizeLicenses(dynamic raw) {
  final List<_LicenseItem> out = [];
  if (raw == null) return out;

  if (raw is List) {
    for (final e in raw) {
      if (e is String) {
        final t = e.trim();
        if (t.isNotEmpty) out.add(_LicenseItem(name: t));
      } else if (e is Map) {
        final name =
            (e['name'] ?? e['title'] ?? e['certificate'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final issuer =
            (e['issuer'] ?? e['organization'] ?? e['provider'] ?? '')
                .toString()
                .trim();
        final year =
            (e['year'] ?? e['issuedAt'] ?? e['issue_date'] ?? '')
                .toString()
                .trim();
        final credId =
            (e['credentialId'] ?? e['id'] ?? '').toString().trim();
        final url = (e['url'] ?? e['link'] ?? '').toString().trim();

        out.add(_LicenseItem(
          name: name,
          issuer: issuer.isEmpty ? null : issuer,
          year: year.isEmpty ? null : year,
          credentialId: credId.isEmpty ? null : credId,
          url: url.isEmpty ? null : url,
        ));
      }
    }
  }
  return out;
}

class _LicenseCard extends StatelessWidget {
  final _LicenseItem item;
  const _LicenseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading icon block (Education-style)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.verified_outlined,
                color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkColor,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),

                // Meta row (issuer • year • credential id)
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (item.issuer != null && item.issuer!.isNotEmpty)
                      _metaChip(Icons.business_outlined, item.issuer!),
                    if (item.year != null && item.year!.isNotEmpty)
                      _metaChip(Icons.calendar_month_outlined, item.year!),
                    if (item.credentialId != null &&
                        item.credentialId!.isNotEmpty)
                      _metaChip(
                          Icons.badge_outlined, 'ID: ${item.credentialId}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
