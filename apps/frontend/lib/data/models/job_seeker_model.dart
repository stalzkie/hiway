class JobSeekerModel {
  final String jobSeekerId;
  final String? authUserId;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final String? address;
  final List<dynamic> skills;
  final List<dynamic> experience;
  final List<dynamic> education;
  final List<dynamic> licensesCertifications;
  final String? searchDocument; 
  final String? pineconeId; 
  final String? embeddingChecksum; 
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobSeekerModel({
    required this.jobSeekerId,
    this.authUserId,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.address,
    required this.skills,
    required this.experience,
    required this.education,
    required this.licensesCertifications,
    this.searchDocument,
    this.pineconeId,
    this.embeddingChecksum,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobSeekerModel.fromJson(Map<String, dynamic> json) {
    return JobSeekerModel(
      jobSeekerId: json['job_seeker_id'] as String,
      authUserId: json['auth_user_id'] as String?,
      role: json['role'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      skills: json['skills'] as List<dynamic>? ?? [],
      experience: json['experience'] as List<dynamic>? ?? [],
      education: json['education'] as List<dynamic>? ?? [],
      licensesCertifications:
          json['licenses_certifications'] as List<dynamic>? ?? [],
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

  JobSeekerModel copyWith({
    String? jobSeekerId,
    String? authUserId,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    List<dynamic>? skills,
    List<dynamic>? experience,
    List<dynamic>? education,
    List<dynamic>? licensesCertifications,
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
    return other is JobSeekerModel && other.jobSeekerId == jobSeekerId;
  }

  @override
  int get hashCode => jobSeekerId.hashCode;
}

