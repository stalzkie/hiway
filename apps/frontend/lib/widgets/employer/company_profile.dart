import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/profile_widgets.dart';
import 'package:hiway_app/widgets/employer/dashboard_cards.dart';
import 'package:hiway_app/data/models/employer_model.dart';

class CompanyProfilePage extends StatelessWidget {
  final EmployerModel? profile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onUploadDocuments;

  const CompanyProfilePage({
    super.key,
    this.profile,
    this.onEditProfile,
    this.onUploadDocuments,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Header Card
          _buildCompanyHeaderCard(context),

          const SizedBox(height: 24),

          // Company Information
          ProfileInfoCard(profile: profile, onEditTap: onEditProfile),

          const SizedBox(height: 24),

          // Company Statistics
          _buildCompanyStats(context),

          const SizedBox(height: 24),

          // Documents Section
          _buildDocumentsSection(context),

          const SizedBox(height: 24),

          // Verification Status
          _buildVerificationSection(context),
        ],
      ),
    );
  }

  Widget _buildCompanyHeaderCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.business,
                      color: AppTheme.primaryColor,
                      size: 40,
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Company Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.company ?? 'Your Company',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile?.companyPosition ?? 'Technology',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Business Location',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEditProfile,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onUploadDocuments,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Upload Docs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildCompanyStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkColor,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Active Jobs',
                value: '12',
                icon: Icons.work,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Applications',
                value: '245',
                icon: Icons.assignment,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Team Size',
                value: '50-100',
                icon: Icons.people,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                title: 'Founded',
                value: '2020',
                icon: Icons.calendar_today,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(BuildContext context) {
    final documents = [
      {
        'name': 'Business License',
        'status': 'Verified',
        'icon': Icons.verified,
      },
      {'name': 'Tax Certificate', 'status': 'Pending', 'icon': Icons.pending},
      {
        'name': 'Company Registration',
        'status': 'Verified',
        'icon': Icons.verified,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Company Documents',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onUploadDocuments,
              icon: Icon(Icons.add, color: AppTheme.primaryColor),
              label: Text(
                'Upload',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: documents
                .map((doc) => _buildDocumentItem(context, doc))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentItem(
    BuildContext context,
    Map<String, dynamic> document,
  ) {
    final isVerified = document['status'] == 'Verified';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isVerified ? AppTheme.successColor : AppTheme.warningColor)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          document['icon'],
          color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
          size: 20,
        ),
      ),
      title: Text(
        document['name'],
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.darkColor,
        ),
      ),
      subtitle: Text(
        document['status'],
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.darkColor.withValues(alpha: 0.4),
      ),
      onTap: () {
        // Handle document tap
      },
    );
  }

  Widget _buildVerificationSection(BuildContext context) {
    return Card(
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
                    Icons.verified_user,
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
                        'Verification Status',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your company is verified',
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
              'Your company profile has been verified and is visible to job seekers. This increases your credibility and helps attract quality candidates.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildVerificationBadge('Email Verified', true),
                _buildVerificationBadge('Phone Verified', true),
                _buildVerificationBadge('Business Verified', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(String label, bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isVerified ? AppTheme.successColor : AppTheme.warningColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isVerified ? AppTheme.successColor : AppTheme.warningColor)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.check_circle : Icons.pending,
            color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isVerified ? AppTheme.successColor : AppTheme.warningColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
