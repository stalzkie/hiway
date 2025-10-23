import 'dart:convert';

class JobSeekerModel {
  final String jobSeekerId;
  final String authUserId;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final String? address;

  // Keep these as simple strings
  final List<String> skills;
  final List<String> experience;
  final List<String> education;

  // NOTE: preserve structure (Map or String) for flexible UI rendering
  final List<dynamic> licensesCertifications;

  final String? searchDocument;
  final String? pineconeId;
  final String? embeddingChecksum;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobSeekerModel({
    required this.jobSeekerId,
    required this.authUserId,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.address,
    this.skills = const [],
    this.experience = const [],
    this.education = const [],
    this.licensesCertifications = const [],
    this.searchDocument,
    this.pineconeId,
    this.embeddingChecksum,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobSeekerModel.fromJson(Map<String, dynamic> json) {
    return JobSeekerModel(
      jobSeekerId: json['job_seeker_id'] as String,
      authUserId: json['auth_user_id'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      skills: _parseStringArray(json['skills']),
      experience: _parseStringArray(json['experience']),
      education: _parseStringArray(json['education']),

      // 👇 preserve maps/objects here
      licensesCertifications: _parseFlexibleArray(json['licenses_certifications']),

      searchDocument: json['search_document'] as String?,
      pineconeId: json['pinecone_id'] as String?,
      embeddingChecksum: json['embedding_checksum'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_seeker_id': jobSeekerId,
      'auth_user_id': authUserId,
      'role': role,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'address': address,
      'skills': skills,
      'experience': experience,
      'education': education,

      // 👇 pass through as-is (list of maps/strings)
      'licenses_certifications': licensesCertifications,

      'search_document': searchDocument,
      'pinecone_id': pineconeId,
      'embedding_checksum': embeddingChecksum,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // --- Parsers -----------------------------------------------------

  // Keep these strictly strings
  static List<String> _parseStringArray(dynamic jsonData) {
    if (jsonData == null) return [];
    if (jsonData is List) {
      return jsonData.map((e) => e.toString()).toList();
    }
    if (jsonData is String) {
      try {
        final decoded = jsonDecode(jsonData);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Flexible parser that preserves Maps/Lists if present.
  /// Accepts:
  /// - List<dynamic> (already structured)
  /// - JSON string of a list
  /// - Comma-delimited string (falls back to list of strings)
  static List<dynamic> _parseFlexibleArray(dynamic jsonData) {
    if (jsonData == null) return [];

    if (jsonData is List) {
      // make a shallow copy to avoid external mutation
      return List<dynamic>.from(jsonData);
    }

    if (jsonData is String) {
      // Try JSON first
      try {
        final decoded = jsonDecode(jsonData);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (_) {
        // Not JSON — return as a single-entry list or split by commas as a last resort
        final s = jsonData.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          // looks like a non-JSON-ish list, still keep raw
          return [s];
        }
        // basic CSV fallback
        if (s.contains(',')) {
          return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        return s.isNotEmpty ? [s] : [];
      }
    }

    return [];
  }

  // --- Equality / hash --------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JobSeekerModel &&
        other.jobSeekerId == jobSeekerId &&
        other.authUserId == authUserId &&
        other.role == role &&
        other.fullName == fullName &&
        other.email == email &&
        other.phone == phone &&
        other.address == address &&
        _listEquals(other.skills, skills) &&
        _listEquals(other.experience, experience) &&
        _listEquals(other.education, education) &&
        _deepListEquals(other.licensesCertifications, licensesCertifications) &&
        other.searchDocument == searchDocument &&
        other.pineconeId == pineconeId &&
        other.embeddingChecksum == embeddingChecksum &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      jobSeekerId,
      authUserId,
      role,
      fullName,
      email,
      phone,
      address,
      Object.hashAll(skills),
      Object.hashAll(experience),
      Object.hashAll(education),
      // deep-ish hash (maps stringify deterministically enough for most cases)
      Object.hashAll(licensesCertifications.map((e) => e is Map ? jsonEncode(e) : e.toString())),
      searchDocument,
      pineconeId,
      embeddingChecksum,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() =>
      'JobSeekerModel{jobSeekerId: $jobSeekerId, fullName: $fullName, email: $email}';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _deepListEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ai = a[i], bi = b[i];
      if (ai is Map && bi is Map) {
        if (jsonEncode(ai) != jsonEncode(bi)) return false;
      } else if (ai is List && bi is List) {
        if (!_deepListEquals(ai, bi)) return false;
      } else {
        if (ai?.toString() != bi?.toString()) return false;
      }
    }
    return true;
  }
}
