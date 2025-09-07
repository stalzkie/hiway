class JobModel {
  final String id;
  final String title;
  final String company;
  final String location;
  final String salaryRange;
  final String salaryPeriod;
  final List<String> skills;
  final String description;
  final String jobType;
  final String experience;
  final DateTime postedDate;
  final DateTime? deadline;
  final String? companyLogo;
  final int matchPercentage;
  final bool isTrending;
  final String status;

  const JobModel({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.salaryRange,
    required this.salaryPeriod,
    required this.skills,
    required this.description,
    required this.jobType,
    required this.experience,
    required this.postedDate,
    this.deadline,
    this.companyLogo,
    required this.matchPercentage,
    this.isTrending = false,
    this.status = 'active',
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'] as String,
      title: json['title'] as String,
      company: json['company'] as String,
      location: json['location'] as String,
      salaryRange: json['salary_range'] as String,
      salaryPeriod: json['salary_period'] as String,
      skills: List<String>.from(json['skills'] as List),
      description: json['description'] as String,
      jobType: json['job_type'] as String,
      experience: json['experience'] as String,
      postedDate: DateTime.parse(json['posted_date'] as String),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      companyLogo: json['company_logo'] as String?,
      matchPercentage: json['match_percentage'] as int? ?? 0,
      isTrending: json['is_trending'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'location': location,
      'salary_range': salaryRange,
      'salary_period': salaryPeriod,
      'skills': skills,
      'description': description,
      'job_type': jobType,
      'experience': experience,
      'posted_date': postedDate.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'company_logo': companyLogo,
      'match_percentage': matchPercentage,
      'is_trending': isTrending,
      'status': status,
    };
  }

  JobModel copyWith({
    String? id,
    String? title,
    String? company,
    String? location,
    String? salaryRange,
    String? salaryPeriod,
    List<String>? skills,
    String? description,
    String? jobType,
    String? experience,
    DateTime? postedDate,
    DateTime? deadline,
    String? companyLogo,
    int? matchPercentage,
    bool? isTrending,
    String? status,
  }) {
    return JobModel(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      salaryRange: salaryRange ?? this.salaryRange,
      salaryPeriod: salaryPeriod ?? this.salaryPeriod,
      skills: skills ?? this.skills,
      description: description ?? this.description,
      jobType: jobType ?? this.jobType,
      experience: experience ?? this.experience,
      postedDate: postedDate ?? this.postedDate,
      deadline: deadline ?? this.deadline,
      companyLogo: companyLogo ?? this.companyLogo,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      isTrending: isTrending ?? this.isTrending,
      status: status ?? this.status,
    );
  }
}
