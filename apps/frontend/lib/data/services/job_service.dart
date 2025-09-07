import 'dart:async';
import '../models/job_model.dart';

class JobService {
  // Mock job data 
  static final List<JobModel> _mockJobs = [
    JobModel(
      id: '1',
      title: 'Social Media Manager',
      company: 'Axion',
      location: 'Remote',
      salaryRange: '30,000',
      salaryPeriod: 'month',
      skills: ['Marketing', 'Social Media', 'Content Creation'],
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      jobType: 'Full-time',
      experience: 'Mid-level',
      postedDate: DateTime.now().subtract(const Duration(days: 2)),
      matchPercentage: 81,
      isTrending: false,
    ),
    JobModel(
      id: '2',
      title: 'Video Editor',
      company: 'Creative Studio',
      location: 'Manila, Philippines',
      salaryRange: '25,000',
      salaryPeriod: 'month',
      skills: ['Video Editing', 'After Effects', 'Premiere Pro'],
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      jobType: 'Full-time',
      experience: 'Entry-level',
      postedDate: DateTime.now().subtract(const Duration(days: 1)),
      matchPercentage: 29,
      isTrending: true,
    ),
    JobModel(
      id: '3',
      title: 'UI/UX Designer',
      company: 'Tech Innovators',
      location: 'Cebu, Philippines',
      salaryRange: '35,000',
      salaryPeriod: 'month',
      skills: ['UI Design', 'UX Research', 'Figma', 'Prototyping'],
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      jobType: 'Full-time',
      experience: 'Mid-level',
      postedDate: DateTime.now().subtract(const Duration(days: 3)),
      matchPercentage: 65,
      isTrending: false,
    ),
    JobModel(
      id: '4',
      title: 'Flutter Developer',
      company: 'Mobile Solutions Inc.',
      location: 'Remote',
      salaryRange: '50,000',
      salaryPeriod: 'month',
      skills: ['Flutter', 'Dart', 'Mobile Development', 'Firebase'],
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      jobType: 'Full-time',
      experience: 'Senior-level',
      postedDate: DateTime.now().subtract(const Duration(hours: 12)),
      matchPercentage: 92,
      isTrending: true,
    ),
    JobModel(
      id: '5',
      title: 'Content Writer',
      company: 'Digital Marketing Agency',
      location: 'Makati, Philippines',
      salaryRange: '22,000',
      salaryPeriod: 'month',
      skills: ['Content Writing', 'SEO', 'Copywriting'],
      description:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      jobType: 'Part-time',
      experience: 'Entry-level',
      postedDate: DateTime.now().subtract(const Duration(days: 5)),
      matchPercentage: 47,
      isTrending: false,
    ),
  ];

  // Simulate API delay
  static Future<void> _simulateDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Get recommended jobs (sorted by match percentage)
  Future<List<JobModel>> getRecommendedJobs() async {
    await _simulateDelay();

    // Sort by match percentage descending
    final sortedJobs = List<JobModel>.from(_mockJobs)
      ..sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));

    return sortedJobs.take(5).toList(); 
  }

  // Get all jobs
  Future<List<JobModel>> getAllJobs({
    String? searchQuery,
    String? location,
    String? jobType,
    String? experience,
  }) async {
    await _simulateDelay();

    List<JobModel> filteredJobs = List<JobModel>.from(_mockJobs);

    // Apply filters if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredJobs = filteredJobs
          .where(
            (job) =>
                job.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                job.company.toLowerCase().contains(searchQuery.toLowerCase()) ||
                job.skills.any(
                  (skill) =>
                      skill.toLowerCase().contains(searchQuery.toLowerCase()),
                ),
          )
          .toList();
    }

    if (location != null && location.isNotEmpty) {
      filteredJobs = filteredJobs
          .where(
            (job) =>
                job.location.toLowerCase().contains(location.toLowerCase()),
          )
          .toList();
    }

    if (jobType != null && jobType.isNotEmpty) {
      filteredJobs = filteredJobs
          .where((job) => job.jobType.toLowerCase() == jobType.toLowerCase())
          .toList();
    }

    if (experience != null && experience.isNotEmpty) {
      filteredJobs = filteredJobs
          .where(
            (job) =>
                job.experience.toLowerCase().contains(experience.toLowerCase()),
          )
          .toList();
    }

    return filteredJobs;
  }

  // Get trending jobs
  Future<List<JobModel>> getTrendingJobs() async {
    await _simulateDelay();

    return _mockJobs.where((job) => job.isTrending).toList();
  }

  // Get job by ID
  Future<JobModel?> getJobById(String id) async {
    await _simulateDelay();

    try {
      return _mockJobs.firstWhere((job) => job.id == id);
    } catch (e) {
      return null;
    }
  }

  // Apply to job (placeholder)
  Future<bool> applyToJob(String jobId) async {
    await _simulateDelay();

    // In a real app, this would make an API call to apply
    return true;
  }

  // Save job (placeholder)
  Future<bool> saveJob(String jobId) async {
    await _simulateDelay();

    // In a real app, this would save to user's saved jobs
    return true;
  }
}
