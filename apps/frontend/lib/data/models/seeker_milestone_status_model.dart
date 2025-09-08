class SeekerMilestoneStatusModel {
  final String statusId;
  final String? authUserId;
  final String jobSeekerId;
  final String role;
  final String? roadmapId;
  final String? currentMilestone;
  final String? currentLevel;
  final double? currentScorePct;
  final bool? lowConfidence;
  final String? nextMilestone;
  final String? nextLevel;
  final List<dynamic> gaps;
  final List<dynamic> milestonesScored;
  final Map<String, dynamic> weights;
  final String? modelVersion;
  final DateTime calculatedAt;

  const SeekerMilestoneStatusModel({
    required this.statusId,
    this.authUserId,
    required this.jobSeekerId,
    required this.role,
    this.roadmapId,
    this.currentMilestone,
    this.currentLevel,
    this.currentScorePct,
    this.lowConfidence,
    this.nextMilestone,
    this.nextLevel,
    required this.gaps,
    required this.milestonesScored,
    required this.weights,
    this.modelVersion,
    required this.calculatedAt,
  });

  factory SeekerMilestoneStatusModel.fromJson(Map<String, dynamic> json) {
    return SeekerMilestoneStatusModel(
      statusId: json['status_id'] as String,
      authUserId: json['auth_user_id'] as String?,
      jobSeekerId: json['job_seeker_id'] as String,
      role: json['role'] as String,
      roadmapId: json['roadmap_id'] as String?,
      currentMilestone: json['current_milestone'] as String?,
      currentLevel: json['current_level'] as String?,
      currentScorePct: json['current_score_pct'] != null
          ? (json['current_score_pct'] as num).toDouble()
          : null,
      lowConfidence: json['low_confidence'] as bool? ?? false,
      nextMilestone: json['next_milestone'] as String?,
      nextLevel: json['next_level'] as String?,
      gaps: json['gaps'] as List<dynamic>? ?? [],
      milestonesScored: json['milestones_scored'] as List<dynamic>? ?? [],
      weights: json['weights'] as Map<String, dynamic>? ?? {},
      modelVersion: json['model_version'] as String?,
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status_id': statusId,
      'auth_user_id': authUserId,
      'job_seeker_id': jobSeekerId,
      'role': role,
      'roadmap_id': roadmapId,
      'current_milestone': currentMilestone,
      'current_level': currentLevel,
      'current_score_pct': currentScorePct,
      'low_confidence': lowConfidence,
      'next_milestone': nextMilestone,
      'next_level': nextLevel,
      'gaps': gaps,
      'milestones_scored': milestonesScored,
      'weights': weights,
      'model_version': modelVersion,
      'calculated_at': calculatedAt.toIso8601String(),
    };
  }

  /// Create a new milestone status for insert (without generated fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'auth_user_id': authUserId,
      'job_seeker_id': jobSeekerId,
      'role': role,
      'roadmap_id': roadmapId,
      'current_milestone': currentMilestone,
      'current_level': currentLevel,
      'current_score_pct': currentScorePct,
      'low_confidence': lowConfidence,
      'next_milestone': nextMilestone,
      'next_level': nextLevel,
      'gaps': gaps,
      'milestones_scored': milestonesScored,
      'weights': weights,
      'model_version': modelVersion,
    };
  }

  /// Check if the current score indicates low confidence
  bool get hasLowConfidence => lowConfidence == true;

  /// Get formatted current score percentage
  String get formattedScore {
    if (currentScorePct == null) return 'No score';
    return '${currentScorePct!.toStringAsFixed(1)}%';
  }

  /// Check if there are skill gaps identified
  bool get hasGaps => gaps.isNotEmpty;

  /// Get gap count
  int get gapCount => gaps.length;

  /// Check if there's a next milestone recommended
  bool get hasNextMilestone =>
      nextMilestone != null && nextMilestone!.isNotEmpty;

  /// Get milestone completion status
  String get completionStatus {
    if (currentScorePct == null) return 'Not scored';
    if (currentScorePct! >= 90) return 'Excellent';
    if (currentScorePct! >= 75) return 'Good';
    if (currentScorePct! >= 60) return 'Satisfactory';
    if (currentScorePct! >= 40) return 'Needs improvement';
    return 'Requires significant work';
  }

  /// Get confidence level description
  String get confidenceDescription {
    if (hasLowConfidence) return 'Low confidence in assessment';
    return 'Standard confidence in assessment';
  }

  /// Create a copy with updated fields
  SeekerMilestoneStatusModel copyWith({
    String? statusId,
    String? authUserId,
    String? jobSeekerId,
    String? role,
    String? roadmapId,
    String? currentMilestone,
    String? currentLevel,
    double? currentScorePct,
    bool? lowConfidence,
    String? nextMilestone,
    String? nextLevel,
    List<dynamic>? gaps,
    List<dynamic>? milestonesScored,
    Map<String, dynamic>? weights,
    String? modelVersion,
    DateTime? calculatedAt,
  }) {
    return SeekerMilestoneStatusModel(
      statusId: statusId ?? this.statusId,
      authUserId: authUserId ?? this.authUserId,
      jobSeekerId: jobSeekerId ?? this.jobSeekerId,
      role: role ?? this.role,
      roadmapId: roadmapId ?? this.roadmapId,
      currentMilestone: currentMilestone ?? this.currentMilestone,
      currentLevel: currentLevel ?? this.currentLevel,
      currentScorePct: currentScorePct ?? this.currentScorePct,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      nextMilestone: nextMilestone ?? this.nextMilestone,
      nextLevel: nextLevel ?? this.nextLevel,
      gaps: gaps ?? this.gaps,
      milestonesScored: milestonesScored ?? this.milestonesScored,
      weights: weights ?? this.weights,
      modelVersion: modelVersion ?? this.modelVersion,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeekerMilestoneStatusModel &&
          runtimeType == other.runtimeType &&
          statusId == other.statusId;

  @override
  int get hashCode => statusId.hashCode;

  @override
  String toString() {
    return 'SeekerMilestoneStatusModel{statusId: $statusId, role: $role, currentMilestone: $currentMilestone, score: $formattedScore}';
  }
}
