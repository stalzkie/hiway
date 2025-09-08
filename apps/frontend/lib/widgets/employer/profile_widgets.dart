import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/employer_model.dart';

class ProfileInfoCard extends StatelessWidget {
  final EmployerModel? profile;
  final VoidCallback? onEditTap;

  const ProfileInfoCard({super.key, this.profile, this.onEditTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Company Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkColor,
                  ),
                ),
                const Spacer(),
                if (onEditTap != null)
                  IconButton(
                    onPressed: onEditTap,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    tooltip: 'Edit Profile',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProfileItems(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItems(BuildContext context) {
    final items = [
      ProfileItem(
        icon: Icons.business_outlined,
        label: 'Company Name',
        value: profile?.company ?? 'Not set',
      ),
      ProfileItem(
        icon: Icons.person_outline,
        label: 'Contact Person',
        value: profile?.name ?? 'Not set',
      ),
      ProfileItem(
        icon: Icons.work_outline,
        label: 'Position',
        value: profile?.companyPosition ?? 'Not set',
      ),
      ProfileItem(
        icon: Icons.email_outlined,
        label: 'Company Email',
        value: profile?.companyEmail ?? 'Not set',
      ),
      ProfileItem(
        icon: Icons.phone_outlined,
        label: 'Company Phone',
        value: profile?.companyPhoneNumber ?? 'Not set',
      ),
    ];

    return Column(
      children:
          items
              .map((item) => _buildProfileItem(context, item))
              .expand((widget) => [widget, const SizedBox(height: 16)])
              .toList()
            ..removeLast(), 
    );
  }

  Widget _buildProfileItem(BuildContext context, ProfileItem item) {
    final isEmpty = item.value == 'Not set';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty
            ? AppTheme.surfaceColor.withValues(alpha: 0.3)
            : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty
              ? AppTheme.surfaceColor.withValues(alpha: 0.5)
              : AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEmpty
                  ? AppTheme.darkColor.withValues(alpha: 0.1)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: isEmpty
                  ? AppTheme.darkColor.withValues(alpha: 0.5)
                  : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.darkColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isEmpty
                        ? AppTheme.darkColor.withValues(alpha: 0.5)
                        : AppTheme.darkColor,
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isEmpty)
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warningColor,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class ProfileItem {
  final IconData icon;
  final String label;
  final String value;

  const ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class DocumentsCard extends StatelessWidget {
  final EmployerModel? profile;
  final VoidCallback? onUploadTap;

  const DocumentsCard({super.key, this.profile, this.onUploadTap});

  @override
  Widget build(BuildContext context) {
    final documents = [
      DocumentItem(
        title: 'DTI/SEC Registration',
        hasFile: profile?.dtiOrSecRegistration != null,
        fileName: profile?.dtiOrSecRegistration,
        icon: Icons.assignment_outlined,
      ),
      DocumentItem(
        title: 'Barangay Clearance',
        hasFile: profile?.barangayClearance != null,
        fileName: profile?.barangayClearance,
        icon: Icons.location_city_outlined,
      ),
      DocumentItem(
        title: 'Business Permit',
        hasFile: profile?.businessPermit != null,
        fileName: profile?.businessPermit,
        icon: Icons.business_center_outlined,
      ),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Required Documents',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkColor,
                  ),
                ),
                const Spacer(),
                if (onUploadTap != null)
                  TextButton.icon(
                    onPressed: onUploadTap,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...documents.map((doc) => _buildDocumentItem(context, doc)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(BuildContext context, DocumentItem document) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: document.hasFile
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: document.hasFile
              ? AppTheme.successColor.withValues(alpha: 0.3)
              : AppTheme.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: document.hasFile
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.warningColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              document.icon,
              size: 18,
              color: document.hasFile
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  document.hasFile ? 'Uploaded' : 'Required',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: document.hasFile
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            document.hasFile ? Icons.check_circle : Icons.warning_amber_rounded,
            color: document.hasFile
                ? AppTheme.successColor
                : AppTheme.warningColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class DocumentItem {
  final String title;
  final bool hasFile;
  final String? fileName;
  final IconData icon;

  const DocumentItem({
    required this.title,
    required this.hasFile,
    this.fileName,
    required this.icon,
  });
}
