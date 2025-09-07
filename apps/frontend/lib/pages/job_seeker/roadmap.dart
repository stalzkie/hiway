import 'package:flutter/material.dart';

class JobSeekerRoadmap extends StatefulWidget {
  const JobSeekerRoadmap({super.key});

  @override
  State<JobSeekerRoadmap> createState() => _JobSeekerRoadmapState();
}

class _JobSeekerRoadmapState extends State<JobSeekerRoadmap> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career Roadmap'), elevation: 0),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 100, color: Colors.grey),
              SizedBox(height: 24),
              Text(
                'Career Roadmap',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Coming Soon!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'We\'re working on building your personalized career roadmap to help you achieve your goals.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
