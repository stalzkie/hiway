import 'package:flutter/material.dart';
import 'package:hiway_app/data/models/roadmap_role_model.dart';
import 'package:hiway_app/data/models/seeker_milestone_status_model.dart';
import 'package:hiway_app/data/services/role_roadmap_service.dart';
import 'package:hiway_app/data/services/seeker_milestone_status_service.dart';
import 'package:hiway_app/widgets/common/loading_widget.dart';
import 'package:hiway_app/widgets/roadmap/roadmap_resources_widget.dart';

/// Roadmap Dashboard - Comprehensive view of job seeker's roadmaps and progress
/// Integrates role roadmaps, milestone status, and resources
class RoadmapDashboard extends StatefulWidget {
  const RoadmapDashboard({super.key});

  @override
  State<RoadmapDashboard> createState() => _RoadmapDashboardState();
}

class _RoadmapDashboardState extends State<RoadmapDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final RoleRoadmapService _roadmapService = RoleRoadmapService();
  final SeekerMilestoneStatusService _statusService =
      SeekerMilestoneStatusService();

  List<RoadmapRoleModel> _roadmaps = [];
  List<SeekerMilestoneStatusModel> _statuses = [];
  Map<String, dynamic> _progressSummary = {};

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all dashboard data in parallel
      final results = await Future.wait([
        _roadmapService.getActiveRoadmaps(),
        _statusService.getJobSeekerStatuses(),
        _statusService.getProgressSummary(),
      ]);

      if (mounted) {
        setState(() {
          _roadmaps = results[0] as List<RoadmapRoleModel>;
          _statuses = results[1] as List<SeekerMilestoneStatusModel>;
          _progressSummary = results[2] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Roadmaps'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Summary Cards
          if (!_isLoading &&
              _errorMessage == null &&
              _progressSummary.isNotEmpty)
            _buildProgressSummary(),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Active Roadmaps', icon: Icon(Icons.map_outlined)),
              Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
              Tab(text: 'Resources', icon: Icon(Icons.library_books)),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRoadmapsTab(),
                _buildProgressTab(),
                _buildResourcesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoadmapDialog,
        icon: const Icon(Icons.add_road),
        label: const Text('New Roadmap'),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final theme = Theme.of(context);
    final summary = _progressSummary;

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Roadmaps',
                  '${_roadmaps.length}',
                  Icons.map,
                  theme,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildSummaryCard(
                  'Roles Assessed',
                  '${summary['roles_assessed'] ?? 0}',
                  Icons.work,
                  theme,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildSummaryCard(
                  'Avg Score',
                  '${(summary['average_score'] ?? 0.0).toStringAsFixed(1)}%',
                  Icons.grade,
                  theme,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: _buildSummaryCard(
                  'Skill Gaps',
                  '${summary['gaps_count'] ?? 0}',
                  Icons.warning,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8.0),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            title,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapsTab() {
    if (_isLoading) {
      return Center(child: LoadingWidget(nextScreen: Container()));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16.0),
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_roadmaps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16.0),
            Text(
              'No roadmaps found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8.0),
            const Text('Create your first career roadmap to get started'),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: _showCreateRoadmapDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Roadmap'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _roadmaps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        final roadmap = _roadmaps[index];
        return _buildRoadmapCard(roadmap);
      },
    );
  }

  Widget _buildRoadmapCard(RoadmapRoleModel roadmap) {
    final theme = Theme.of(context);
    final latestStatus =
        _statuses.where((s) => s.roadmapId == roadmap.roadmapId).isNotEmpty
        ? _statuses.where((s) => s.roadmapId == roadmap.roadmapId).first
        : null;

    return Card(
      child: InkWell(
        onTap: () => _showRoadmapDetails(roadmap),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.work_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roadmap.role,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '${roadmap.milestoneCount} milestones • ${roadmap.provider}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (roadmap.isExpired) ...[
                    Icon(Icons.warning, color: theme.colorScheme.error),
                  ],
                ],
              ),
              const SizedBox(height: 12.0),
              if (latestStatus != null) ...[
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Progress',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              latestStatus.currentMilestone ?? 'Not started',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (latestStatus.currentScorePct != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(
                              latestStatus.currentScorePct!,
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Text(
                            latestStatus.formattedScore,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${_formatDate(roadmap.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      if (latestStatus != null && latestStatus.hasGaps) ...[
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${latestStatus.gapCount} gaps',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_isLoading) {
      return Center(child: LoadingWidget(nextScreen: Container()));
    }

    if (_statuses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey),
            SizedBox(height: 16.0),
            Text('No progress data available'),
            SizedBox(height: 8.0),
            Text('Complete assessments to see your progress'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _statuses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        final status = _statuses[index];
        return _buildStatusCard(status);
      },
    );
  }

  Widget _buildStatusCard(SeekerMilestoneStatusModel status) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getScoreColor(status.currentScorePct ?? 0),
                  child: Text(
                    status.currentScorePct?.toInt().toString() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.role,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        status.currentMilestone ?? 'No milestone',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: status.hasLowConfidence
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        status.completionStatus,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      _formatDate(status.calculatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (status.hasGaps) ...[
              const SizedBox(height: 12.0),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: theme.colorScheme.onErrorContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${status.gapCount} skill gaps identified',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status.hasNextMilestone) ...[
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Next: ${status.nextMilestone}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesTab() {
    if (_roadmaps.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, size: 64, color: Colors.grey),
            SizedBox(height: 16.0),
            Text('No roadmaps with resources'),
            SizedBox(height: 8.0),
            Text('Create roadmaps to manage learning resources'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _roadmaps.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16.0),
      itemBuilder: (context, index) {
        final roadmap = _roadmaps[index];
        return ExpansionTile(
          leading: Icon(Icons.map_outlined),
          title: Text(roadmap.role),
          subtitle: Text('${roadmap.milestoneCount} milestones'),
          children: List.generate(
            roadmap.milestoneCount,
            (milestoneIndex) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: RoadmapResourcesWidget(
                roadmapId: roadmap.roadmapId,
                milestoneIndex: milestoneIndex,
                milestoneTitle: 'Milestone ${milestoneIndex + 1}',
                readOnly: false,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.deepOrange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).round()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showRoadmapDetails(RoadmapRoleModel roadmap) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(roadmap.role),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provider: ${roadmap.provider}'),
            Text('Model: ${roadmap.model}'),
            Text('Milestones: ${roadmap.milestoneCount}'),
            Text('Created: ${_formatDate(roadmap.createdAt)}'),
            if (roadmap.expiresAt != null)
              Text('Expires: ${_formatDate(roadmap.expiresAt!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateRoadmapDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Roadmap'),
        content: const Text(
          'Roadmap creation will be integrated with your AI assessment system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Roadmap creation feature coming soon!'),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
