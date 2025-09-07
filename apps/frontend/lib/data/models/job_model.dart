// models/job_model.dart
class JobModel {
  final String id;
  final String title;
  final String company;
  final String location;

  /// UI expects plain strings for salary.
  /// `salaryRange` = numeric string (e.g., "80000")
  /// `salaryPeriod` = unit (e.g., "monthly", "mo", "yr")
  final String salaryRange;
  final String salaryPeriod;

  final List<String> skills;
  final String description;
  final String jobType;
  final String experience; // display string
  final DateTime postedDate;

  // Optional / derived
  final DateTime? deadline;
  final String? companyLogo;
  final int matchPercentage; // 0..100
  final bool isTrending;

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
  });

  // --------------------------
  // Helpers
  // --------------------------

  static List<String> _parseJsonbList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      return v
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String _stringify(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    return v.toString();
  }

  static int _clamp0to100(num n) => n.clamp(0, 100).toInt();

  /// Read match % from various shapes:
  /// - match_percentage (0..100)
  /// - confidence (0..1 or 0..100)
  /// - job_match_scores: [{ confidence: 0..1 or 0..100, ... }, ...]
  static int _readMatchPercentage(Map<String, dynamic> json) {
    // 1) direct int percent
    final mp = json['match_percentage'];
    if (mp is num) return _clamp0to100(mp);

    // 2) direct confidence (handle 0..1 or 0..100)
    final conf = json['confidence'];
    if (conf is num) {
      final asPercent = conf <= 1 ? (conf * 100) : conf;
      return _clamp0to100(asPercent.round());
    }

    // 3) joined table array
    final jms = json['job_match_scores'];
    if (jms is List && jms.isNotEmpty) {
      final first = jms.first;
      if (first is Map && first['confidence'] is num) {
        final c = first['confidence'] as num;
        final asPercent = c <= 1 ? (c * 100) : c;
        return _clamp0to100(asPercent.round());
      }
    }

    return 0;
  }

  /// Read salary object if provided as:
  /// { amount: 80000, currency: 'PHP', type: 'monthly' }
  /// Falls back to flat columns if you later switch back.
  static (String amountStr, String period) _readSalary(Map<String, dynamic> json) {
    // Nested salary object (recommended)
    final salary = (json['salary'] is Map) ? json['salary'] as Map : const {};
    final amount = salary['amount'];
    final type = (salary['type'] as String?) ?? 'monthly';
    final amountStr = (amount == null) ? '' : amount.toString();

    // If you ever return flat columns again, uncomment this fallback:
    // final flatAmount = json['salary_amount'];
    // final flatType = json['salary_period'];
    // final resolvedAmount = (amountStr.isEmpty && flatAmount != null)
    //     ? flatAmount.toString()
    //     : amountStr;
    // final resolvedType = (type.isEmpty && flatType is String) ? flatType : type;

    return (amountStr, type);
  }

  static String _readExperienceAsDisplay(dynamic v) {
    // Your schema showed `job_experience` possibly jsonb; display as a string.
    final list = _parseJsonbList(v);
    if (list.isNotEmpty) return list.join(', ');
    return _stringify(v);
  }

  // --------------------------
  // Factory
  // --------------------------

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final (salaryAmountStr, salaryType) = _readSalary(json);

    final createdRaw = json['created_at'] as String?;
    final createdAt =
        createdRaw != null ? DateTime.parse(createdRaw) : DateTime.now();

    final deadlineRaw = json['deadline'] as String?;
    final deadline = (deadlineRaw == null || deadlineRaw.isEmpty)
        ? null
        : DateTime.parse(deadlineRaw);

    return JobModel(
      id: _stringify(json['job_post_id'].toString().isNotEmpty ? json['job_post_id'] : json['id']),
      title: _stringify(json['job_title'].toString().isNotEmpty ? json['job_title'] : json['title']),
      company: _stringify(json['job_company'].toString().isNotEmpty ? json['job_company'] : json['company']),
      location: _stringify(json['job_location'].toString().isNotEmpty ? json['job_location'] : json['location']),
      salaryRange: salaryAmountStr,
      salaryPeriod: salaryType,
      skills: _parseJsonbList(json['job_skills']),
      description: _stringify(json['job_overview'].toString().isNotEmpty ? json['job_overview'] : json['description']),
      jobType: _stringify(json['job_type'], fallback: 'full-time'),
      experience: _readExperienceAsDisplay(json['job_experience']),
      postedDate: createdAt,
      deadline: deadline,
      companyLogo: json['company_logo'] as String?,
      matchPercentage: _readMatchPercentage(json),
      isTrending: (json['is_trending'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final parsedAmount = int.tryParse(salaryRange);
    final salaryJson = {
      'amount': parsedAmount ?? salaryRange,
      'currency': 'PHP',
      'type': salaryPeriod,
    };

    return {
      'job_post_id': id,
      'job_title': title,
      'job_company': company,
      'job_location': location,
      'salary': salaryJson,
      'job_skills': skills,
      'job_overview': description,
      'job_type': jobType,
      'job_experience': experience,
      'created_at': postedDate.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'company_logo': companyLogo,
      // Persist as percent for portability. (If you prefer confidence 0..1, convert upstream.)
      'match_percentage': matchPercentage,
      'is_trending': isTrending,
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
    );
  }
}
