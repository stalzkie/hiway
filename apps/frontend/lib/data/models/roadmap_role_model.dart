class RoadmapRoleModel {
  final String roadmapId;
  final String role;
  final String provider;
  final String model;
  final String promptHash;
  final String allowlistHash;
  final List<dynamic> milestones;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String jobSeekerId;
  final List<dynamic> certAllowlist;
  final String? promptTemplate;

  const RoadmapRoleModel({
    required this.roadmapId,
    required this.role,
    required this.provider,
    required this.model,
    required this.promptHash,
    required this.allowlistHash,
    required this.milestones,
    required this.createdAt,
    this.expiresAt,
    required this.jobSeekerId,
    required this.certAllowlist,
    this.promptTemplate,
  });

  factory RoadmapRoleModel.fromJson(Map<String, dynamic> json) {
    return RoadmapRoleModel(
      roadmapId: json['roadmap_id'] as String,
      role: json['role'] as String,
      provider: json['provider'] as String,
      model: json['model'] as String,
      promptHash: json['prompt_hash'] as String,
      allowlistHash: json['allowlist_hash'] as String,
      milestones: json['milestones'] as List<dynamic>? ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      jobSeekerId: json['job_seeker_id'] as String,
      certAllowlist: json['cert_allowlist'] as List<dynamic>? ?? [],
      promptTemplate: json['prompt_template'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roadmap_id': roadmapId,
      'role': role,
      'provider': provider,
      'model': model,
      'prompt_hash': promptHash,
      'allowlist_hash': allowlistHash,
      'milestones': milestones,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'job_seeker_id': jobSeekerId,
      'cert_allowlist': certAllowlist,
      'prompt_template': promptTemplate,
    };
  }

  /// Create a new roadmap for insert (without generated fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'role': role,
      'provider': provider,
      'model': model,
      'prompt_hash': promptHash,
      'allowlist_hash': allowlistHash,
      'milestones': milestones,
      'expires_at': expiresAt?.toIso8601String(),
      'job_seeker_id': jobSeekerId,
      'cert_allowlist': certAllowlist,
      'prompt_template': promptTemplate,
    };
  }

  /// Check if the roadmap has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get milestone count
  int get milestoneCount => milestones.length;

  /// Get milestone by index
  dynamic getMilestone(int index) {
    if (index < 0 || index >= milestones.length) return null;
    return milestones[index];
  }

  /// Create a copy with updated fields
  RoadmapRoleModel copyWith({
    String? roadmapId,
    String? role,
    String? provider,
    String? model,
    String? promptHash,
    String? allowlistHash,
    List<dynamic>? milestones,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? jobSeekerId,
    List<dynamic>? certAllowlist,
    String? promptTemplate,
  }) {
    return RoadmapRoleModel(
      roadmapId: roadmapId ?? this.roadmapId,
      role: role ?? this.role,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      promptHash: promptHash ?? this.promptHash,
      allowlistHash: allowlistHash ?? this.allowlistHash,
      milestones: milestones ?? this.milestones,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      jobSeekerId: jobSeekerId ?? this.jobSeekerId,
      certAllowlist: certAllowlist ?? this.certAllowlist,
      promptTemplate: promptTemplate ?? this.promptTemplate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadmapRoleModel &&
          runtimeType == other.runtimeType &&
          roadmapId == other.roadmapId;

  @override
  int get hashCode => roadmapId.hashCode;

  @override
  String toString() {
    return 'RoadmapRoleModel{roadmapId: $roadmapId, role: $role, provider: $provider, milestoneCount: $milestoneCount}';
  }
}
