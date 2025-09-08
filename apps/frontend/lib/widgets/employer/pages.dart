import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/dashboard_cards.dart';
import 'package:hiway_app/widgets/employer/layout_widgets.dart';
import 'package:hiway_app/data/models/employer_model.dart';

class DashboardOverviewPage extends StatelessWidget {
  final EmployerModel? profile;
  final VoidCallback onPostJobTap;
  final VoidCallback onViewJobsTap;
  final VoidCallback onViewCandidatesTap;
  final VoidCallback onMessagesTap;

  const DashboardOverviewPage({
    super.key,
    this.profile,
    required this.onPostJobTap,
    required this.onViewJobsTap,
    required this.onViewCandidatesTap,
    required this.onMessagesTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeCard(
            name: profile?.name,
            company: profile?.company,
            message:
                'Find the perfect candidates for your company and grow your team.',
          ),

          const SizedBox(height: 32),

          // Statistics Section
          const SectionHeader(
            title: 'Overview Stats',
            subtitle: 'Your hiring performance at a glance',
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.work,
                  title: 'Active Jobs',
                  value: '3',
                  color: AppTheme.primaryColor,
                  subtitle: 'Currently posted',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  icon: Icons.people,
                  title: 'Applications',
                  value: '24',
                  color: Colors.blue,
                  subtitle: 'This month',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const SectionHeader(
            title: 'Recent Activity',
            subtitle: 'Latest updates on your postings',
          ),
          const SizedBox(height: 16),

          _buildRecentActivityCard(context),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    final activities = [
      _ActivityItem(
        icon: Icons.person_add,
        title: 'New application received',
        subtitle: 'Frontend Developer position',
        time: '2 hours ago',
        color: Colors.blue,
      ),
      _ActivityItem(
        icon: Icons.schedule,
        title: 'Interview scheduled',
        subtitle: 'UI/UX Designer role',
        time: '4 hours ago',
        color: Colors.orange,
      ),
      _ActivityItem(
        icon: Icons.work,
        title: 'Job posting approved',
        subtitle: 'Backend Developer',
        time: '1 day ago',
        color: AppTheme.successColor,
      ),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children:
              activities
                  .map((activity) => _buildActivityItem(context, activity))
                  .expand((widget) => [widget, const Divider()])
                  .toList()
                ..removeLast(), // Remove last divider
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, _ActivityItem activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activity.icon, size: 20, color: activity.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.darkColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.darkColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.work_outline,
      title: 'No Jobs Posted',
      message:
          'Start by creating your first job listing to attract talented candidates.',
      actionText: 'Post Your First Job',
    );
  }
}

class CandidatesPage extends StatelessWidget {
  const CandidatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.people_outline,
      title: 'No Candidates Yet',
      message:
          'Browse and discover talented professionals looking for opportunities.',
      actionText: 'Browse Candidates',
    );
  }
}
