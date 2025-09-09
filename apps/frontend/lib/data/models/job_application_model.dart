import 'dart:convert';

class ApplicationModel {
  final String applicationId;
  final String jobPostId;
  final String jobSeekerId;
  final String employerId;
  final double matchConfidence;
  final Map<String, dynamic> matchSnapshot;
  final DateTime statusChangedAt;
  final String source;
  final String resumeUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicationModel({
    required this.applicationId,
    required this.jobPostId,
    required this.jobSeekerId,
    required this.employerId,
    required this.matchConfidence,
    required this.matchSnapshot,
    required this.statusChangedAt,
    required this.source,
    required this.resumeUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      applicationId: json['application_id'] as String,
      jobPostId: json['job_post_id'] as String,
      jobSeekerId: json['job_seeker_id'] as String,
      employerId: json['employer_id'] as String,
      matchConfidence: (json['match_confidence'] as num).toDouble(),
      matchSnapshot: json['match_snapshot'] is String
          ? jsonDecode(json['match_snapshot'])
          : Map<String, dynamic>.from(json['match_snapshot'] ?? {}),
      statusChangedAt: DateTime.parse(json['status_changed_at'] as String),
      source: json['source'] as String,
      resumeUrl: json['resume_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'application_id': applicationId,
      'job_post_id': jobPostId,
      'job_seeker_id': jobSeekerId,
      'employer_id': employerId,
      'match_confidence': matchConfidence,
      'match_snapshot': jsonEncode(matchSnapshot),
      'status_changed_at': statusChangedAt.toIso8601String(),
      'source': source,
      'resume_url': resumeUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}