import 'dart:convert';
import 'job_experience_model.dart';
import '../../core/utils/time_formatter.dart';

class JobPostModel {
  final String jobPostId;
  final String postedBy;
  final String jobTitle;
  final String jobCompany;
  final String jobLocation;
  final String jobOverview;
  final List<String> jobSkills;
  final List<JobExperienceModel> jobExperience;
  final List<String>? jobEducation;
  final List<String>? jobLicensesCertifications;
  final SalaryModel salary;
  final String? searchDocument;
  final String? pineconeId;
  final String? embeddingChecksum;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String jobType;
  final DateTime? deadline;
  final String status;

  const JobPostModel({
    required this.jobPostId,
    required this.postedBy,
    required this.jobTitle,
    required this.jobCompany,
    required this.jobLocation,
    required this.jobOverview,
    this.jobSkills = const [],
    this.jobExperience = const [],
    this.jobEducation,
    this.jobLicensesCertifications,
    required this.salary,
    this.searchDocument,
    this.pineconeId,
    this.embeddingChecksum,
    required this.createdAt,
    required this.updatedAt,
    this.jobType = 'full-time',
    this.deadline,
    this.status = 'active',
  });

  /// Factory constructor from JSON - matches database schema
  factory JobPostModel.fromJson(Map<String, dynamic> json) {
    return JobPostModel(
      jobPostId: json['job_post_id'] as String,
      postedBy: json['posted_by'] as String,
      jobTitle: json['job_title'] as String? ?? '',
      jobCompany: json['job_company'] as String? ?? '',
      jobLocation: json['job_location'] as String? ?? '',
      jobOverview: json['job_overview'] as String,
      jobSkills: _parseJsonbArray(json['job_skills']) ?? [],
      jobExperience: _parseJobExperienceArray(json['job_experience']),
      jobEducation: _parseJsonbArray(json['job_education']),
      jobLicensesCertifications: _parseJsonbArray(
        json['job_licenses_certifications'],
      ),
      salary: SalaryModel.fromJson(
        json['salary'] as Map<String, dynamic>? ?? {},
      ),
      searchDocument: json['search_document'] as String?,
      pineconeId: json['pinecone_id'] as String?,
      embeddingChecksum: json['embedding_checksum'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      jobType: 'full-time', // Default value since not in database
      deadline: null, // Default value since not in database
      status: 'active', // Default value since not in database
    );
  }

  /// Convert to JSON for database operations
  Map<String, dynamic> toJson() {
    return {
      'job_post_id': jobPostId,
      'posted_by': postedBy,
      'job_title': jobTitle,
      'job_company': jobCompany,
      'job_location': jobLocation,
      'job_overview': jobOverview,
      'job_skills': jobSkills,
      'job_experience': jobExperience.map((e) => e.toJson()).toList(),
      'job_education': jobEducation,
      'job_licenses_certifications': jobLicensesCertifications,
      'salary': salary.toJson(),
      'search_document': searchDocument,
      'pinecone_id': pineconeId,
      'embedding_checksum': embeddingChecksum,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Exclude job_type, deadline, status as they don't exist in database
    };
  }

  /// Create a new job post for insert (without generated fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'posted_by': postedBy,
      'job_title': jobTitle,
      'job_company': jobCompany,
      'job_location': jobLocation,
      'job_overview': jobOverview,
      'job_skills': jobSkills,
      'job_experience': jobExperience.map((e) => e.toJson()).toList(),
      'job_education': jobEducation,
      'job_licenses_certifications': jobLicensesCertifications,
      'salary': salary.toJson(),
      // Exclude job_type, deadline, status as they don't exist in database
    };
  }

  /// Create a copy with updated fields
  JobPostModel copyWith({
    String? jobPostId,
    String? postedBy,
    String? jobTitle,
    String? jobCompany,
    String? jobLocation,
    String? jobOverview,
    List<String>? jobSkills,
    List<JobExperienceModel>? jobExperience,
    List<String>? jobEducation,
    List<String>? jobLicensesCertifications,
    SalaryModel? salary,
    String? searchDocument,
    String? pineconeId,
    String? embeddingChecksum,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? jobType,
    DateTime? deadline,
    String? status,
  }) {
    return JobPostModel(
      jobPostId: jobPostId ?? this.jobPostId,
      postedBy: postedBy ?? this.postedBy,
      jobTitle: jobTitle ?? this.jobTitle,
      jobCompany: jobCompany ?? this.jobCompany,
      jobLocation: jobLocation ?? this.jobLocation,
      jobOverview: jobOverview ?? this.jobOverview,
      jobSkills: jobSkills ?? this.jobSkills,
      jobExperience: jobExperience ?? this.jobExperience,
      jobEducation: jobEducation ?? this.jobEducation,
      jobLicensesCertifications:
          jobLicensesCertifications ?? this.jobLicensesCertifications,
      salary: salary ?? this.salary,
      searchDocument: searchDocument ?? this.searchDocument,
      pineconeId: pineconeId ?? this.pineconeId,
      embeddingChecksum: embeddingChecksum ?? this.embeddingChecksum,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      jobType: jobType ?? this.jobType,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
    );
  }

  /// Helper method to parse JSONB arrays from database
  static List<String>? _parseJsonbArray(dynamic json) {
    if (json == null) return null;

    if (json is List) {
      final result = json.map((item) => item.toString()).toList();
      return result.isEmpty ? null : result;
    }

    if (json is String) {
      if (json.trim().isEmpty) return null;

      try {
        final decoded = jsonDecode(json);
        if (decoded is List) {
          final result = decoded.map((item) => item.toString()).toList();
          return result.isEmpty ? null : result;
        }
      } catch (e) {
        // If it's not valid JSON, treat as comma-separated string
        final result = json
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return result.isEmpty ? null : result;
      }
    }

    return null;
  }

  /// Parse JSONB array for job experience with years and domain
  static List<JobExperienceModel> _parseJobExperienceArray(dynamic json) {
    if (json == null) return const [];

    if (json is List) {
      return json.map((item) {
        if (item is Map<String, dynamic>) {
          return JobExperienceModel.fromJson(item);
        } else if (item is String) {
          // Try to parse legacy string format "3 years in frontend development"
          final parts = item.split(' years in ');
          if (parts.length == 2) {
            final years = int.tryParse(parts[0]) ?? 0;
            return JobExperienceModel(years: years, domain: parts[1]);
          }
          return JobExperienceModel(years: 0, domain: item);
        }
        return JobExperienceModel(years: 0, domain: item.toString());
      }).toList();
    }

    if (json is String) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is List) {
          return _parseJobExperienceArray(decoded);
        }
      } catch (e) {
        // If it's not valid JSON, treat as comma-separated string
        return json
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => JobExperienceModel(years: 0, domain: s))
            .toList();
      }
    }

    return const [];
  }

  /// Display helpers for UI
  String get formattedSalary => salary.displayText;
  String get experienceDisplayText =>
      jobExperience.map((e) => e.toString()).join(', ');
  String get skillsDisplayText => jobSkills.join(', ');
  String get educationDisplayText =>
      jobEducation?.join(', ') ?? 'Not specified';
  String get certificationsDisplayText =>
      jobLicensesCertifications?.join(', ') ?? 'Not specified';

  /// Calculate days since posted (legacy - kept for backward compatibility)
  int get daysSincePosted {
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  /// Get formatted time since posted (e.g., "2h ago", "3d ago", "1w ago")
  String get timeSincePosted {
    return TimeFormatter.getTimeAgo(createdAt);
  }

  /// Check if deadline is approaching (within 7 days)
  bool get isDeadlineApproaching {
    return false; // Always false since deadline doesn't exist in database
  }

  /// Check if deadline has passed
  bool get isExpired {
    return false; // Always false since deadline doesn't exist in database
  }

  /// Check if job has embedding data processed
  bool get hasEmbedding => pineconeId != null && embeddingChecksum != null;

  /// Check if job needs embedding processing
  bool get needsEmbeddingUpdate {
    if (pineconeId == null || embeddingChecksum == null) return true;

    // Calculate current checksum of job content for comparison
    final currentChecksum = _calculateContentChecksum();
    return embeddingChecksum != currentChecksum;
  }

  /// Calculate content checksum for embedding comparison
  String _calculateContentChecksum() {
    final content = [
      jobTitle,
      jobOverview,
      jobLocation,
      jobSkills.join(' '),
      jobExperience
          .map((exp) => '${exp.years} years in ${exp.domain}')
          .join(' '),
      salary.toString(),
    ].join(' ');

    return content.hashCode.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobPostModel &&
          runtimeType == other.runtimeType &&
          jobPostId == other.jobPostId;

  @override
  int get hashCode => jobPostId.hashCode;

  @override
  String toString() {
    return 'JobPostModel{jobPostId: $jobPostId, jobTitle: $jobTitle, jobCompany: $jobCompany}';
  }
}

/// Salary Model - Matches database salary JSONB structure
class SalaryModel {
  final double amount;
  final String currency;
  final String type; // 'monthly', 'yearly', 'hourly'

  const SalaryModel({
    required this.amount,
    this.currency = 'PHP',
    this.type = 'monthly',
  });

  factory SalaryModel.fromJson(Map<String, dynamic> json) {
    return SalaryModel(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'PHP',
      type: json['type'] as String? ?? 'monthly',
    );
  }

  Map<String, dynamic> toJson() {
    return {'amount': amount, 'currency': currency, 'type': type};
  }

  /// Display text for UI (without currency symbol for cleaner look)
  String get displayText {
    final formattedAmount = amount >= 1000
        ? '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K'
        : amount.toStringAsFixed(amount % 1 == 0 ? 0 : 0);

    final period = switch (type.toLowerCase()) {
      'yearly' || 'annual' => '/year',
      'monthly' => '/month',
      'hourly' => '/hour',
      'daily' => '/day',
      _ => '/$type',
    };

    return '$formattedAmount$period';
  }

  /// Create salary range display (for min-max salaries)
  static String displayRange({
    required SalaryModel min,
    required SalaryModel max,
  }) {
    if (min.currency != max.currency || min.type != max.type) {
      return '${min.displayText} - ${max.displayText}';
    }

    final period = switch (min.type.toLowerCase()) {
      'yearly' || 'annual' => '/year',
      'monthly' => '/month',
      'hourly' => '/hour',
      'daily' => '/day',
      _ => '/${min.type}',
    };

    final minFormatted = min.amount >= 1000
        ? '${(min.amount / 1000).toStringAsFixed(min.amount % 1000 == 0 ? 0 : 1)}K'
        : min.amount.toStringAsFixed(min.amount % 1 == 0 ? 0 : 0);

    final maxFormatted = max.amount >= 1000
        ? '${(max.amount / 1000).toStringAsFixed(max.amount % 1000 == 0 ? 0 : 1)}K'
        : max.amount.toStringAsFixed(max.amount % 1 == 0 ? 0 : 0);

    return '${min.currency} $minFormatted - $maxFormatted$period';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalaryModel &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          currency == other.currency &&
          type == other.type;

  @override
  int get hashCode => Object.hash(amount, currency, type);

  @override
  String toString() =>
      'SalaryModel(amount: $amount, currency: $currency, type: $type)';
}
