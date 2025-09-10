import 'package:flutter/material.dart';
import 'package:hiway_app/data/services/applications_service.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

class ApplicationView extends StatefulWidget {  // Change to StatefulWidget
  final String jobID;
  const ApplicationView({super.key, required this.jobID});

  @override
  State<ApplicationView> createState() => _ApplicationViewState();
}

class _ApplicationViewState extends State<ApplicationView> {
  String appBarTitle = 'Loading...';
  bool isDataLoaded = false; // <-- new flag

  @override
  Widget build(BuildContext context) {
    final applicationService = ApplicationService(apiBase: 'https://hiway-production-ec0e.up.railway.app');
    AuthService _auth = AuthService();
    Map<String, dynamic>? listing_data;
    String newTitle = "";

    String _formatDate(DateTime date) {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor  ,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: applicationService.fetchJobWithMatchAndEmployer(
          jobPostId: widget.jobID,
          authId: _auth.currentUser?.id ?? '',
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

          listing_data = data;

          // Update title only if it's different
          newTitle = data['job_post']['job_title'] ?? 'Job Details';
          if (appBarTitle != newTitle) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                appBarTitle = newTitle;
                isDataLoaded = true; // <-- flag turns true
              });
            });
          }
  
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // First Card - Job Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // Image.asset(
                              //   'assets/images/company_logo.png', // Add your image
                              //   width: 50,
                              //   height: 50,
                              // ),
                              const SizedBox(width: 16),
                              Text(
                                listing_data!['job_post']['employer']['company'] ?? 'Company Name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Enlisted on: ${_formatDate(DateTime.parse(listing_data!["job_post"]["created_at"]))}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Second Card - Job Description
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
                            listing_data!['job_post']['job_overview'] ?? 'Job Title',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Third Card - Match Indicators
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
                      child: Column(
                        children: [
                          // Progress Indicators Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildCircularProgress('Skills', listing_data!["section_scores"]["skills"]?.toDouble() ?? 0.0),
                              _buildCircularProgress('Licenses', listing_data!["section_scores"]["licenses"]?.toDouble() ?? 0.0),
                              _buildCircularProgress('Education', listing_data!["section_scores"]["education"]?.toDouble() ?? 0.0),
                              _buildCircularProgress('Experience', listing_data!["section_scores"]["experience"]?.toDouble() ?? 0.0),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Title Bar
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

                          // Side by Side Cards
                          IntrinsicHeight(
                            child:Row(
                              children: [
                                // First List Card
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Matching Skills',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          ...listing_data!['matched_skills'].map((skill) => 
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Text('• $skill'),
                                            ),
                                          ).toList(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8), // Space between cards
                                // Second List Card
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Missing Skills',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          ...listing_data!['missing_skills'].map((skill) => 
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Text('• $skill'),
                                            ),
                                          ).toList(),
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
                  if (listing_data!["overall_summary"].isNotEmpty) ...{
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Overall Summary',
                      bodyText: listing_data!["overall_summary"],
                    ),
                    SizedBox(height:60)
                  }
                ],
              ),
            ),
          );
        },
      ),
      
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FloatingActionButton.extended(
          onPressed: isDataLoaded
              ? () {
                  applicationService.applyForJob(
                    context: context,
                    jobPostId: listing_data!["job_post"]["job_post_id"],
                    jobSeekerId: listing_data!["job_seeker_id"],
                    employerId: listing_data!["job_post"]["employer"]["employer_id"],
                    matchConfidence:
                        listing_data!["confidence"]?.toDouble() ?? 0.0,
                  );
                }
              : null, // disables until loaded
          backgroundColor: isDataLoaded
              ? AppTheme.primaryColor
              : AppTheme.surfaceColor,
          label: Text(
            isDataLoaded ? 'Apply Now' : 'Loading...',
            style: const TextStyle(color: Colors.white),
          ),
          icon: isDataLoaded ? const Icon(Icons.send, color: Colors.white) : null,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              value: progress/100,
              strokeWidth: 8,
              backgroundColor: Colors.grey[200],
              color: AppTheme.successColor
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

  // Widget build(BuildContext context) {
  //   final applicationService = ApplicationService(apiBase: 'https://hiway-production-ec0e.up.railway.app');
  //   AuthService _auth = AuthService();
  //   Map<String, dynamic>? listing_data;

  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('Application Details'),
  //     ),
  //     body: FutureBuilder<Map<String, dynamic>?>(
  //       future: applicationService.fetchJobWithMatchAndEmployer(
  //         jobPostId: widget.jobID,
  //         authId: _auth.currentUser?.id ?? '',
  //       ),
  //       builder: (context, snapshot) {
  //         if (snapshot.connectionState == ConnectionState.waiting) {
  //           return const Center(child: CircularProgressIndicator());
  //         }
  //         if (snapshot.hasError) {
  //           return Center(child: Text('Error: ${snapshot.error}'));
  //         }
  //         final data = snapshot.data;
  //         listing_data = data ?? {};

  //         if (data == null) {
  //           return const Center(child: Text('No data found.'));
  //         }
  //         // Dynamically print all key-value pairs
  //         return ListView(
  //           padding: const EdgeInsets.all(16),
  //           children: data.entries.map((entry) {
  //             return Padding(
  //               padding: const EdgeInsets.symmetric(vertical: 4),
  //               child: Text('${entry.key}: ${(entry.key == "job_match_scores") ? entry.value : entry.value}'),
  //             );
  //           }).toList(),
  //         );
  //       },
  //     ),
  //     floatingActionButton: Container(
  //       width: MediaQuery.of(context).size.width * 0.9, // 90% of screen width
  //       padding: const EdgeInsets.symmetric(horizontal: 16),
  //       child: FloatingActionButton.extended(
  //         onPressed: () {
  //           // Add your button action here

  //         },
  //         backgroundColor: Colors.blue,
  //         label: const Text(
  //           'Apply Now',
  //           style: TextStyle(color: Colors.white),
  //         ),
  //         icon: const Icon(Icons.send, color: Colors.white),
  //       ),
  //     ),
  //     floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  //   );
  // }

  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       backgroundColor: Colors.blue,
  //       leading: IconButton(
  //         icon: const Icon(Icons.arrow_back, color: Colors.white),
  //         onPressed: () => Navigator.of(context).pop(),
  //       ),
  //       title: Text(
  //         "title",
  //         style: const TextStyle(color: Colors.white),
  //       ),
  //       centerTitle: true,
  //     ),
  //     body: SingleChildScrollView(
  //       child: Padding(
  //         padding: const EdgeInsets.all(16.0),
  //         child: child,
  //       ),
  //     ),
  //   );
  // }
}