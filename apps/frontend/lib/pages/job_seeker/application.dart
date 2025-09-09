import 'package:flutter/material.dart';
import 'package:hiway_app/data/services/applications_service.dart';
import 'package:hiway_app/data/services/auth_service.dart';

class ApplicationView extends StatelessWidget {
  final String jobID;
  const ApplicationView({super.key, required this.jobID});

  @override
  Widget build(BuildContext context) {
    final applicationService = ApplicationService(apiBase: 'https://hiway-production-ec0e.up.railway.app');
    AuthService _auth = AuthService();
    Map<String, dynamic>? listing_data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: applicationService.fetchJobWithMatchAndEmployer(
          jobPostId: jobID,
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
          listing_data = data ?? {};

          if (data == null) {
            return const Center(child: Text('No data found.'));
          }
          // Dynamically print all key-value pairs
          return ListView(
            padding: const EdgeInsets.all(16),
            children: data.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${entry.key}: ${(entry.key == "job_match_scores") ? entry.value : entry.value}'),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width * 0.9, // 90% of screen width
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            // Add your button action here
            print(_auth.currentSession!.accessToken );
            applicationService.applyForJob(job_post_id: listing_data!["job_post"]["job_post_id"],
                                           job_seeker_id: listing_data!["job_seeker_id"],
                                           employer_id: listing_data!["job_post"]["employer"]["employer_id"],
                                           bearerToken: _auth.currentSession!.accessToken );
          },
          backgroundColor: Colors.blue,
          label: const Text(
            'Apply Now',
            style: TextStyle(color: Colors.white),
          ),
          icon: const Icon(Icons.send, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

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