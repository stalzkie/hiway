import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hiway_app/data/services/applications_service.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

class ApplicationView extends StatefulWidget {
  final String jobID;
  const ApplicationView({super.key, required this.jobID});

  @override
  State<ApplicationView> createState() => _ApplicationViewState();
}

class _ApplicationViewState extends State<ApplicationView> {
  String appBarTitle = 'Loading...';
  bool isDataLoaded = false;

  String _formatOverview(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is List) return raw.join('\n');
    try {
      return jsonEncode(raw);
    } catch (_) {
      return raw.toString();
    }
  }

  String formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final applicationService =
        ApplicationService(apiBase: 'https://hiway-production-ec0e.up.railway.app');
    AuthService auth = AuthService();
    Map<String, dynamic>? listingData;
    String newTitle = "";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: applicationService.fetchJobWithMatchAndEmployer(
          jobPostId: widget.jobID,
          authId: auth.currentUser?.id ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No data found.'));
          }

          listingData = data;

          // Debugging info
          print('=== FULL API RESPONSE ===');
          print(jsonEncode(listingData));
          print('=========================');
          print('Keys: ${listingData!.keys.toList()}');

          // Set the AppBar title dynamically
          newTitle = data['job_post']['job_title'] ?? 'Job Details';
          if (appBarTitle != newTitle) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                appBarTitle = newTitle;
                isDataLoaded = true;
              });
            });
          }

          final jobOverview =
              _formatOverview(listingData!['job_post']?['job_overview']);
          final overallSummary =
              (listingData?['analysis']?['overall_summary'] as String?)?.trim();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // -------- Header Card --------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 16),
                              Text(
                                listingData!['job_post']['employer']['company'] ??
                                    'Company Name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Enlisted on: ${formatDate(DateTime.parse(listingData!["job_post"]["created_at"]))}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------- Job Description --------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Job Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            jobOverview.isNotEmpty
                                ? jobOverview
                                : 'No description available.',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------- Match Indicators --------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
                      child: Column(
                        children: [
                          // Progress Indicators Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildCircularProgress(
                                'Skills',
                                listingData!["section_scores"]["skills"]
                                        ?.toDouble() ??
                                    0.0,
                              ),
                              _buildCircularProgress(
                                'Licenses',
                                listingData!["section_scores"]["licenses"]
                                        ?.toDouble() ??
                                    0.0,
                              ),
                              _buildCircularProgress(
                                'Education',
                                listingData!["section_scores"]["education"]
                                        ?.toDouble() ??
                                    0.0,
                              ),
                              _buildCircularProgress(
                                'Experience',
                                listingData!["section_scores"]["experience"]
                                        ?.toDouble() ??
                                    0.0,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Skills Analysis Header
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'Skills Analysis',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // -------- Matching vs Missing --------
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                // Matching Skills
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Matching Skills',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          if (listingData!['matched_skills'] !=
                                                  null &&
                                              (listingData!['matched_skills']
                                                      as List)
                                                  .isNotEmpty)
                                            ...(listingData!['matched_skills']
                                                    as List)
                                                .map(
                                              (skill) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4.0),
                                                child: Text('• $skill'),
                                              ),
                                            )
                                          else
                                            const Text(
                                                'No matching skills found'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Missing Skills
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Missing Skills',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          if (listingData!['missing_skills'] !=
                                                  null &&
                                              (listingData!['missing_skills']
                                                      as List)
                                                  .isNotEmpty)
                                            ...(listingData!['missing_skills']
                                                    as List)
                                                .map(
                                              (skill) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4.0),
                                                child: Text('• $skill'),
                                              ),
                                            )
                                          else
                                            const Text('No missing skills'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // -------- Overall Summary --------
                  if (overallSummary != null && overallSummary.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Overall Summary',
                      bodyText: overallSummary,
                    ),
                    const SizedBox(height: 60),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularProgress(String label, double progress) {
    double size = 65;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress / 100,
                strokeWidth: 8,
                backgroundColor: Colors.grey[200],
                color: AppTheme.successColor,
              ),
            ),
            Text(
              '${(progress).round()}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String bodyText,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              bodyText,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
