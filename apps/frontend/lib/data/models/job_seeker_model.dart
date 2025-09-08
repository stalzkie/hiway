import 'dart:convert';

class JobSeekerModel {
  final String jobSeekerId;
  final String authUserId;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final String? address;
  final List<String> skills;
  final List<String> experience;
  final List<String> education;
  final List<String> licensesCertifications;
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
      skills: _parseJsonArray(json['skills']),
      experience: _parseJsonArray(json['experience']),
      education: _parseJsonArray(json['education']),
      licensesCertifications: _parseJsonArray(json['licenses_certifications']),
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
      'licenses_certifications': licensesCertifications,
      'search_document': searchDocument,
      'pinecone_id': pineconeId,
      'embedding_checksum': embeddingChecksum,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper method to parse JSONB arrays
  static List<String> _parseJsonArray(dynamic jsonData) {
    if (jsonData == null) return [];

    if (jsonData is List) {
      return jsonData.map((item) => item.toString()).toList();
    }

    if (jsonData is String) {
      try {
        final decoded = jsonDecode(jsonData);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (e) {
        return [];
      }
    }

    return [];
  }

  JobSeekerModel copyWith({
    String? jobSeekerId,
    String? authUserId,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    List<String>? skills,
    List<String>? experience,
    List<String>? education,
    List<String>? licensesCertifications,
    String? searchDocument,
    String? pineconeId,
    String? embeddingChecksum,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobSeekerModel(
      jobSeekerId: jobSeekerId ?? this.jobSeekerId,
      authUserId: authUserId ?? this.authUserId,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      licensesCertifications:
          licensesCertifications ?? this.licensesCertifications,
      searchDocument: searchDocument ?? this.searchDocument,
      pineconeId: pineconeId ?? this.pineconeId,
      embeddingChecksum: embeddingChecksum ?? this.embeddingChecksum,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
        _listEquals(other.licensesCertifications, licensesCertifications) &&
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
      Object.hashAll(licensesCertifications),
      searchDocument,
      pineconeId,
      embeddingChecksum,
      createdAt,
      updatedAt,
    );
  }

  get uuid => null;

  get userId => null;

  @override
  String toString() {
    return 'JobSeekerModel{jobSeekerId: $jobSeekerId, fullName: $fullName, email: $email}';
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
