import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/widgets/employer/layout_widgets.dart';
import 'package:hiway_app/widgets/employer/dashboard_cards.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:hiway_app/data/services/candidate_service.dart';

class CandidatesPage extends StatefulWidget {
  final EmployerModel? profile;

  const CandidatesPage({super.key, this.profile});

  @override
  State<CandidatesPage> createState() => _CandidatesPageState();
}

class _CandidatesPageState extends State<CandidatesPage> {
  final CandidateService _candidateService = CandidateService();
  List<JobSeekerModel> _candidates = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final candidates = await _candidateService.getCandidates(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      setState(() {
        _candidates = candidates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadCandidates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: EmployerAppBar(
        title: 'Candidates',
        actions: [
          IconButton(
            onPressed: () => _showSearchDialog(context),
            icon: const Icon(Icons.search),
            tooltip: 'Search Candidates',
          ),
          IconButton(
            onPressed: _loadCandidates,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.backgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.people,
                    title: 'Total Candidates',
                    value: _candidates.length.toString(),
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    icon: Icons.schedule,
                    title: 'Available',
                    value: _candidates
                        .where((c) => c.email.isNotEmpty)
                        .length
                        .toString(),
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    icon: Icons.location_on,
                    title: 'Locations',
                    value: _candidates
                        .where((c) => c.address != null)
                        .map((c) => c.address)
                        .toSet()
                        .length
                        .toString(),
                    color: AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search results for: "$_searchQuery"',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                      _loadCandidates();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Error loading candidates',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCandidates,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No candidates found', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Start by posting a job to attract candidates'
                  : 'Try adjusting your search terms',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _candidates.length,
      itemBuilder: (context, index) {
        final candidate = _candidates[index];
        return CandidateCard(
          candidate: candidate,
          onTap: () => _viewCandidateProfile(candidate),
          onMessage: () => _sendMessage(candidate),
          onContact: () => _contactCandidate(candidate),
        );
      },
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Candidates'),
        content: TextField(
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Enter keywords, skills, or location...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadCandidates();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _viewCandidateProfile(JobSeekerModel candidate) {
    // Navigate to candidate profile
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Viewing ${candidate.fullName}')));
  }

  void _sendMessage(JobSeekerModel candidate) {
    // Navigate to messaging
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Messaging ${candidate.fullName}')));
  }

  void _contactCandidate(JobSeekerModel candidate) {
    final theme = Theme.of(context);

    // Show contact options
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact ${candidate.fullName}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Send Email'),
              subtitle: Text(candidate.email),
              onTap: () {
                Navigator.pop(context);
                // Launch email
              },
            ),
            if (candidate.phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Call'),
                subtitle: Text(candidate.phone!),
                onTap: () {
                  Navigator.pop(context);
                  // Launch phone
                },
              ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                _sendMessage(candidate);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Candidate card widget for displaying job seekers
class CandidateCard extends StatelessWidget {
  final JobSeekerModel candidate;
  final VoidCallback onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onContact;

  const CandidateCard({
    super.key,
    required this.candidate,
    required this.onTap,
    this.onMessage,
    this.onContact,
  });

  // Helper method to extract first and last name from fullName
  List<String> _splitFullName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) {
      return [fullName, ''];
    }
    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');
    return [firstName, lastName];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameParts = _splitFullName(candidate.fullName);
    final firstName = nameParts[0];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Candidate Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.fullName,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          candidate.role,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (candidate.address != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppTheme.darkColor.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  candidate.address!,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Skills
              if (candidate.skills.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: candidate.skills.take(5).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onContact,
                      icon: const Icon(Icons.contact_mail, size: 18),
                      label: const Text('Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
}
