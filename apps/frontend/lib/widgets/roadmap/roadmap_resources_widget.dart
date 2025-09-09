import 'package:flutter/material.dart';
import 'package:hiway_app/data/models/roadmap_resources_model.dart';
import 'package:hiway_app/data/services/roadmap_resources_service.dart';
import 'package:hiway_app/widgets/common/loading_widget.dart';

class RoadmapResourcesWidget extends StatefulWidget {
  final String roadmapId;
  final int milestoneIndex;
  final String milestoneTitle;
  final bool readOnly;

  const RoadmapResourcesWidget({
    super.key,
    required this.roadmapId,
    required this.milestoneIndex,
    required this.milestoneTitle,
    this.readOnly = false,
  });

  @override
  State<RoadmapResourcesWidget> createState() => _RoadmapResourcesWidgetState();
}

class _RoadmapResourcesWidgetState extends State<RoadmapResourcesWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RoadmapResourcesService _service = RoadmapResourcesService();

  RoadmapResourcesModel? _resources;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadResources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resources = await _service.getRoadmapResources(
        roadmapId: widget.roadmapId,
        milestoneIndex: widget.milestoneIndex,
      );

      if (mounted) {
        setState(() {
          _resources = resources;
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

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12.0),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.school_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Milestone ${widget.milestoneIndex + 1} Resources',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        widget.milestoneTitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!widget.readOnly) ...[
                  IconButton(
                    onPressed: _showEditDialog,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Resources',
                  ),
                ],
              ],
            ),
          ),

          // Content
          if (_isLoading) ...[
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(child: LoadingWidget(nextScreen: Container())),
            ),
          ] else if (_errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_resources == null) ...[
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 48.0,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'No resources available yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(height: 8.0),
                      ElevatedButton.icon(
                        onPressed: _showEditDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Resources'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            Column(
              children: [
                // Tabs
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Resources', icon: Icon(Icons.menu_book)),
                    Tab(text: 'Certifications', icon: Icon(Icons.verified)),
                    Tab(text: 'Networks', icon: Icon(Icons.groups)),
                  ],
                ),

                // Tab Content
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResourcesList(_resources!.resources),
                      _buildCertificationsList(_resources!.certifications),
                      _buildNetworksList(_resources!.networkGroups),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResourcesList(List<dynamic> resources) {
    if (resources.isEmpty) {
      return _buildEmptyState(
        'No learning resources',
        Icons.menu_book_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: resources.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final resource = resources[index];
        return ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(resource['title'] ?? 'Resource ${index + 1}'),
          subtitle: resource['description'] != null
              ? Text(resource['description'])
              : null,
          trailing: resource['url'] != null
              ? IconButton(
                  onPressed: () => _launchUrl(resource['url']),
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open Resource',
                )
              : null,
        );
      },
    );
  }

  Widget _buildCertificationsList(List<dynamic> certifications) {
    if (certifications.isEmpty) {
      return _buildEmptyState('No certifications', Icons.verified_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: certifications.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final cert = certifications[index];
        return ListTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(cert['name'] ?? 'Certification ${index + 1}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cert['provider'] != null)
                Text('Provider: ${cert['provider']}'),
              if (cert['difficulty'] != null)
                Text('Level: ${cert['difficulty']}'),
            ],
          ),
          trailing: cert['url'] != null
              ? IconButton(
                  onPressed: () => _launchUrl(cert['url']),
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'View Certification',
                )
              : null,
        );
      },
    );
  }

  Widget _buildNetworksList(List<dynamic> networks) {
    if (networks.isEmpty) {
      return _buildEmptyState('No network groups', Icons.groups_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: networks.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final network = networks[index];
        return ListTile(
          leading: const Icon(Icons.group_outlined),
          title: Text(network['name'] ?? 'Network ${index + 1}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (network['type'] != null) Text('Type: ${network['type']}'),
              if (network['description'] != null) Text(network['description']),
            ],
          ),
          trailing: network['url'] != null
              ? IconButton(
                  onPressed: () => _launchUrl(network['url']),
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Join Network',
                )
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.0, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16.0),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => RoadmapResourcesEditDialog(
        roadmapId: widget.roadmapId,
        milestoneIndex: widget.milestoneIndex,
        milestoneTitle: widget.milestoneTitle,
        existingResources: _resources,
        onSaved: (savedResources) {
          setState(() {
            _resources = savedResources;
          });
        },
      ),
    );
  }

  void _launchUrl(String url) {
    // TODO: Implement URL launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Would open: $url'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // TODO: Copy to clipboard
          },
        ),
      ),
    );
  }
}

/// Edit Dialog for Roadmap Resources
class RoadmapResourcesEditDialog extends StatefulWidget {
  final String roadmapId;
  final int milestoneIndex;
  final String milestoneTitle;
  final RoadmapResourcesModel? existingResources;
  final Function(RoadmapResourcesModel) onSaved;

  const RoadmapResourcesEditDialog({
    super.key,
    required this.roadmapId,
    required this.milestoneIndex,
    required this.milestoneTitle,
    this.existingResources,
    required this.onSaved,
  });

  @override
  State<RoadmapResourcesEditDialog> createState() =>
      _RoadmapResourcesEditDialogState();
}

class _RoadmapResourcesEditDialogState
    extends State<RoadmapResourcesEditDialog> {
  final RoadmapResourcesService _service = RoadmapResourcesService();

  late List<Map<String, dynamic>> _resources;
  late List<Map<String, dynamic>> _certifications;
  late List<Map<String, dynamic>> _networks;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final existing = widget.existingResources;

    _resources = existing?.resources.cast<Map<String, dynamic>>() ?? [];
    _certifications =
        existing?.certifications.cast<Map<String, dynamic>>() ?? [];
    _networks = existing?.networkGroups.cast<Map<String, dynamic>>() ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Edit Resources - ${widget.milestoneTitle}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24.0),

            // Content (simplified for demo)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Resources section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.menu_book),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Learning Resources (${_resources.length})',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _addResource,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add Resource',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12.0),
                            Text(
                              'Add learning materials, courses, and tutorials for this milestone.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Certifications section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Certifications (${_certifications.length})',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _addCertification,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add Certification',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12.0),
                            Text(
                              'Add relevant certifications and credentials.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // Networks section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.groups),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Professional Networks (${_networks.length})',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _addNetwork,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add Network',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12.0),
                            Text(
                              'Add professional groups and networking opportunities.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24.0),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12.0),
                LoadingButton(
                  onPressed: _saveResources,
                  isLoading: _isSaving,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addResource() {
    setState(() {
      _resources.add({
        'title': 'New Resource',
        'description': '',
        'url': '',
        'type': 'article',
      });
    });
  }

  void _addCertification() {
    setState(() {
      _certifications.add({
        'name': 'New Certification',
        'provider': '',
        'url': '',
        'difficulty': 'intermediate',
      });
    });
  }

  void _addNetwork() {
    setState(() {
      _networks.add({
        'name': 'New Network',
        'type': 'professional',
        'description': '',
        'url': '',
      });
    });
  }

  Future<void> _saveResources() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final savedResource = await _service.upsertRoadmapResources(
        roadmapId: widget.roadmapId,
        milestoneIndex: widget.milestoneIndex,
        resources: _resources,
        certifications: _certifications,
        networkGroups: _networks,
      );

      if (mounted) {
        widget.onSaved(savedResource);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save resources: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
