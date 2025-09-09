// lib/models/orchestrator_models.dart
import 'dart:convert';

class MilestoneMatchedEvidence {
  final String item;
  final String? source;

  const MilestoneMatchedEvidence({required this.item, this.source});

  factory MilestoneMatchedEvidence.fromJson(Map<String, dynamic> j) =>
      MilestoneMatchedEvidence(
        item: (j['item'] ?? '').toString(),
        source: j['source']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'item': item,
        'source': source,
      };
}

class MilestoneGap {
  final String item;
  const MilestoneGap({required this.item});

  factory MilestoneGap.fromJson(Map<String, dynamic> j) =>
      MilestoneGap(item: (j['item'] ?? '').toString());

  Map<String, dynamic> toJson() => {'item': item};
}

class MilestoneScore {
  final int index;
  final String? title;
  final double scorePct;
  final List<MilestoneMatchedEvidence> matchedEvidence;
  final List<MilestoneGap> gaps;
  final String? rationale;
  final double? etaHours;
  final String? etaText;
  final double? etaConfidence;

  const MilestoneScore({
    required this.index,
    this.title,
    required this.scorePct,
    this.matchedEvidence = const [],
    this.gaps = const [],
    this.rationale,
    this.etaHours,
    this.etaText,
    this.etaConfidence,
  });

  factory MilestoneScore.fromJson(Map<String, dynamic> j) {
    List me = (j['matched_evidence'] as List?) ?? const [];
    List gs = (j['gaps'] as List?) ?? const [];
    return MilestoneScore(
      index: (j['index'] ?? 0) is int
          ? j['index']
          : int.tryParse(j['index']?.toString() ?? '0') ?? 0,
      title: j['title']?.toString(),
      scorePct: (j['score_pct'] is num)
          ? (j['score_pct'] as num).toDouble()
          : double.tryParse(j['score_pct']?.toString() ?? '0') ?? 0,
      matchedEvidence:
          me.map((e) => MilestoneMatchedEvidence.fromJson(Map<String, dynamic>.from(e))).toList(),
      gaps: gs.map((e) => MilestoneGap.fromJson(Map<String, dynamic>.from(e))).toList(),
      rationale: j['rationale']?.toString(),
      etaHours: (j['eta_hours'] is num)
          ? (j['eta_hours'] as num).toDouble()
          : double.tryParse(j['eta_hours']?.toString() ?? ''),
      etaText: j['eta_text']?.toString(),
      etaConfidence: (j['eta_confidence'] is num)
          ? (j['eta_confidence'] as num).toDouble()
          : double.tryParse(j['eta_confidence']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        'score_pct': scorePct,
        'matched_evidence': matchedEvidence.map((e) => e.toJson()).toList(),
        'gaps': gaps.map((e) => e.toJson()).toList(),
        'rationale': rationale,
        'eta_hours': etaHours,
        'eta_text': etaText,
        'eta_confidence': etaConfidence,
      };
}

class MilestoneStatus {
  final String? roadmapId;
  final String? currentMilestone;
  final String? currentLevel;
  final double? currentScorePct;
  final String? nextMilestone;
  final String? nextLevel;
  final List<MilestoneGap> gaps;
  final List<MilestoneScore> milestonesScored;
  final Map<String, dynamic>? weights;
  final String? modelVersion;
  final bool? lowConfidence;
  final String? calculatedAt;

  const MilestoneStatus({
    this.roadmapId,
    this.currentMilestone,
    this.currentLevel,
    this.currentScorePct,
    this.nextMilestone,
    this.nextLevel,
    this.gaps = const [],
    this.milestonesScored = const [],
    this.weights,
    this.modelVersion,
    this.lowConfidence,
    this.calculatedAt,
  });

  factory MilestoneStatus.fromJson(Map<String, dynamic> j) {
    List gs = (j['gaps'] as List?) ?? const [];
    List ms = (j['milestones_scored'] as List?) ?? const [];
    return MilestoneStatus(
      roadmapId: j['roadmap_id']?.toString(),
      currentMilestone: j['current_milestone']?.toString(),
      currentLevel: j['current_level']?.toString(),
      currentScorePct: (j['current_score_pct'] is num)
          ? (j['current_score_pct'] as num).toDouble()
          : double.tryParse(j['current_score_pct']?.toString() ?? ''),
      nextMilestone: j['next_milestone']?.toString(),
      nextLevel: j['next_level']?.toString(),
      gaps: gs.map((e) => MilestoneGap.fromJson(Map<String, dynamic>.from(e))).toList(),
      milestonesScored: ms
          .map((e) => MilestoneScore.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      weights: j['weights'] == null ? null : Map<String, dynamic>.from(j['weights']),
      modelVersion: j['model_version']?.toString(),
      lowConfidence: j['low_confidence'] == null ? null : j['low_confidence'] == true,
      calculatedAt: j['calculated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'roadmap_id': roadmapId,
        'current_milestone': currentMilestone,
        'current_level': currentLevel,
        'current_score_pct': currentScorePct,
        'next_milestone': nextMilestone,
        'next_level': nextLevel,
        'gaps': gaps.map((e) => e.toJson()).toList(),
        'milestones_scored': milestonesScored.map((e) => e.toJson()).toList(),
        'weights': weights,
        'model_version': modelVersion,
        'low_confidence': lowConfidence,
        'calculated_at': calculatedAt,
      };
}

// ---------------- NEW: Link + Milestone ----------------
class RoadmapLink {
  final String title;
  final String? source;
  final String? url;

  const RoadmapLink({required this.title, this.source, this.url});

  static RoadmapLink? tryParse(dynamic json) {
    if (json == null) return null;
    if (json is! Map) return null;
    
    try {
      final title = json['title']?.toString() ?? '';
      if (title.isEmpty) return null;
      
      return RoadmapLink(
        title: title,
        source: json['source']?.toString(),
        url: json['url']?.toString(),
      );
    } catch (e) {
      print('Error parsing RoadmapLink: $e');
      return null;
    }
  }

  factory RoadmapLink.fromJson(Map<String, dynamic> j) => RoadmapLink(
        title: (j['title'] ?? '').toString(),
        source: j['source']?.toString(),
        url: j['url']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'source': source,
        'url': url,
      };
}

class RoadmapMilestone {
  final String? title;
  final String? level;
  final String? milestone;
  final String? description;
  final List<RoadmapLink> resources;
  final List<RoadmapLink> certifications;
  final List<RoadmapLink> networkGroups;

  const RoadmapMilestone({
    this.title,
    this.level,
    this.milestone,
    this.description,
    this.resources = const [],
    this.certifications = const [],
    this.networkGroups = const [],
  });

  static RoadmapMilestone? tryParse(dynamic json) {
    if (json == null) return null;
    if (json is! Map<String, dynamic>) return null;

    try {
      final title = json['title']?.toString();
      if (title == null) return null;

      return RoadmapMilestone(
        title: title,
        level: json['level']?.toString(),
        milestone: json['milestone']?.toString(),
        description: json['description']?.toString(),
        resources: () {
          try {
            final list = json['resources'];
            if (list == null) return const <RoadmapLink>[];
            if (list is! List) return const <RoadmapLink>[];
            return list
                .whereType<Map>()
                .map((e) => RoadmapLink.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          } catch (e) {
            print('Error parsing resources: $e');
            return const <RoadmapLink>[];
          }
        }(),
        certifications: () {
          try {
            final list = json['certifications'];
            if (list == null) return const <RoadmapLink>[];
            if (list is! List) return const <RoadmapLink>[];
            return list
                .whereType<Map>()
                .map((e) => RoadmapLink.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          } catch (e) {
            print('Error parsing certifications: $e');
            return const <RoadmapLink>[];
          }
        }(),
        networkGroups: () {
          try {
            final list = json['network_groups'];
            if (list == null) return const <RoadmapLink>[];
            if (list is! List) return const <RoadmapLink>[];
            return list
                .whereType<Map>()
                .map((e) => RoadmapLink.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          } catch (e) {
            print('Error parsing network groups: $e');
            return const <RoadmapLink>[];
          }
        }(),
      );
    } catch (e) {
      print('Error parsing RoadmapMilestone: $e');
      return null;
    }
  }

  factory RoadmapMilestone.fromJson(Map<String, dynamic> j) {
    final milestone = tryParse(j);
    if (milestone == null) {
      throw FormatException('Invalid RoadmapMilestone format: ${j['title']}');
    }
    return milestone;
  }

  static List<RoadmapMilestone> parseList(dynamic json) {
    if (json == null) return [];
    if (json is! List) return [];
    return json.map((x) => tryParse(x)).whereType<RoadmapMilestone>().toList();
  }
  
  Map<String, dynamic> toJson() => {
        'title': title,
        'level': level,
        'milestone': milestone,
        'description': description,
        'resources': resources.map((e) => e.toJson()).toList(),
        'certifications': certifications.map((e) => e.toJson()).toList(),
        'network_groups': networkGroups.map((e) => e.toJson()).toList(),
      };
}
// --------------------------------------------------------

class RoadmapDoc {
  final String? roadmapId;
  final String? jobSeekerId;
  final String? role;
  final List<RoadmapMilestone>? milestones; // changed from List<dynamic>
  final String? promptTemplate;
  final String? createdAt;
  final String? expiresAt;

  const RoadmapDoc({
    this.roadmapId,
    this.jobSeekerId,
    this.role,
    this.milestones,
    this.promptTemplate,
    this.createdAt,
    this.expiresAt,
  });

  factory RoadmapDoc.fromJson(Map<String, dynamic> j) => RoadmapDoc(
        roadmapId: j['roadmap_id']?.toString(),
        jobSeekerId: j['job_seeker_id']?.toString(),
        role: j['role']?.toString(),
        milestones: () {
          try {
            final list = j['milestones'];
            if (list == null) return null;
            if (list is! List) return null;
            final result = <RoadmapMilestone>[];
            for (final e in list) {
              if (e is Map<String, dynamic> && (e['title'] != null || e['milestone'] != null)) {
                try {
                  result.add(RoadmapMilestone.fromJson(e));
                } catch (err) {
                  print('Skipping invalid milestone: $err');
                }
              }
            }
            return result;
          } catch (e) {
            print('Error parsing milestones: $e');
            return null;
          }
        }(),
        promptTemplate: j['prompt_template']?.toString(),
        createdAt: j['created_at']?.toString(),
        expiresAt: j['expires_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'roadmap_id': roadmapId,
        'job_seeker_id': jobSeekerId,
        'role': role,
        'milestones': milestones?.map((e) => e.toJson()).toList(),
        'prompt_template': promptTemplate,
        'created_at': createdAt,
        'expires_at': expiresAt,
      };
}

class OrchestratorResponse {
  final String status; // "updated" | "cached"
  final String? jobSeekerId;
  final String? role;
  final int matchesWritten;
  final RoadmapDoc? roadmap;
  final MilestoneStatus? milestoneStatus;
  final String? message;

  const OrchestratorResponse({
    required this.status,
    this.jobSeekerId,
    this.role,
    required this.matchesWritten,
    this.roadmap,
    this.milestoneStatus,
    this.message,
  });

  factory OrchestratorResponse.fromJson(Map<String, dynamic> j) => OrchestratorResponse(
        status: (j['status'] ?? 'cached').toString(),
        jobSeekerId: j['job_seeker_id']?.toString(),
        role: j['role']?.toString(),
        matchesWritten: (j['matches_written'] ?? 0) is int
            ? j['matches_written']
            : int.tryParse(j['matches_written']?.toString() ?? '0') ?? 0,
        roadmap: j['roadmap'] == null ? null : RoadmapDoc.fromJson(Map<String, dynamic>.from(j['roadmap'])),
        milestoneStatus: j['milestone_status'] == null
            ? null
            : MilestoneStatus.fromJson(Map<String, dynamic>.from(j['milestone_status'])),
        message: j['message']?.toString(),
      );

  static OrchestratorResponse fromJsonString(String s) =>
      OrchestratorResponse.fromJson(json.decode(s) as Map<String, dynamic>);
}
