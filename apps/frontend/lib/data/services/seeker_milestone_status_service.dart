import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/seeker_milestone_status_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class SeekerMilestoneStatusService {
  static final SeekerMilestoneStatusService _instance =
      SeekerMilestoneStatusService._internal();
  factory SeekerMilestoneStatusService() => _instance;
  SeekerMilestoneStatusService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  static const String _tableName = 'seeker_milestone_status';

  /// Get milestone status by ID
  Future<SeekerMilestoneStatusModel?> getStatusById(String statusId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('status_id', statusId)
          .maybeSingle();

      if (response == null) return null;
      return SeekerMilestoneStatusModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get milestone status: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to get milestone status: $e');
    }
  }

  /// Get latest milestone status for current job seeker and role
  Future<SeekerMilestoneStatusModel?> getLatestStatusForRole(
    String role,
  ) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .eq('role', role)
          .order('calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return SeekerMilestoneStatusModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get latest status for role: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get latest status for role: $e');
    }
  }

  /// Get latest milestone status for specific roadmap
  Future<SeekerMilestoneStatusModel?> getLatestStatusForRoadmap(
    String roadmapId,
  ) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .eq('roadmap_id', roadmapId)
          .order('calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return SeekerMilestoneStatusModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get latest status for roadmap: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get latest status for roadmap: $e');
    }
  }

  /// Get all milestone statuses for current job seeker
  Future<List<SeekerMilestoneStatusModel>> getJobSeekerStatuses() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .order('calculated_at', ascending: false);

      return (response as List)
          .map(
            (json) => SeekerMilestoneStatusModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get job seeker statuses: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get job seeker statuses: $e');
    }
  }

  /// Get milestone statuses for a specific role
  Future<List<SeekerMilestoneStatusModel>> getStatusesForRole(
    String role,
  ) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .eq('role', role)
          .order('calculated_at', ascending: false);

      return (response as List)
          .map(
            (json) => SeekerMilestoneStatusModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get statuses for role: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get statuses for role: $e');
    }
  }

  /// Get milestone statuses for a specific roadmap
  Future<List<SeekerMilestoneStatusModel>> getStatusesForRoadmap(
    String roadmapId,
  ) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .eq('roadmap_id', roadmapId)
          .order('calculated_at', ascending: false);

      return (response as List)
          .map(
            (json) => SeekerMilestoneStatusModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get statuses for roadmap: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get statuses for roadmap: $e');
    }
  }

  /// Create new milestone status
  Future<SeekerMilestoneStatusModel> createStatus({
    String? authUserId,
    required String role,
    String? roadmapId,
    String? currentMilestone,
    String? currentLevel,
    double? currentScorePct,
    bool? lowConfidence,
    String? nextMilestone,
    String? nextLevel,
    List<dynamic>? gaps,
    required List<dynamic> milestonesScored,
    required Map<String, dynamic> weights,
    String? modelVersion,
  }) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final statusData = {
        'auth_user_id': authUserId,
        'job_seeker_id': jobSeeker.jobSeekerId,
        'role': role,
        'roadmap_id': roadmapId,
        'current_milestone': currentMilestone,
        'current_level': currentLevel,
        'current_score_pct': currentScorePct,
        'low_confidence': lowConfidence ?? false,
        'next_milestone': nextMilestone,
        'next_level': nextLevel,
        'gaps': gaps ?? [],
        'milestones_scored': milestonesScored,
        'weights': weights,
        'model_version': modelVersion,
      };

      final response = await _client
          .from(_tableName)
          .insert(statusData)
          .select()
          .single();

      return SeekerMilestoneStatusModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to create milestone status: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to create milestone status: $e');
    }
  }

  /// Update existing milestone status
  Future<SeekerMilestoneStatusModel> updateStatus({
    required String statusId,
    String? authUserId,
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
  }) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final updateData = <String, dynamic>{};
      if (authUserId != null) updateData['auth_user_id'] = authUserId;
      if (role != null) updateData['role'] = role;
      if (roadmapId != null) updateData['roadmap_id'] = roadmapId;
      if (currentMilestone != null) {
        updateData['current_milestone'] = currentMilestone;
      }
      if (currentLevel != null) updateData['current_level'] = currentLevel;
      if (currentScorePct != null) {
        updateData['current_score_pct'] = currentScorePct;
      }
      if (lowConfidence != null) updateData['low_confidence'] = lowConfidence;
      if (nextMilestone != null) updateData['next_milestone'] = nextMilestone;
      if (nextLevel != null) updateData['next_level'] = nextLevel;
      if (gaps != null) updateData['gaps'] = gaps;
      if (milestonesScored != null) {
        updateData['milestones_scored'] = milestonesScored;
      }
      if (weights != null) updateData['weights'] = weights;
      if (modelVersion != null) updateData['model_version'] = modelVersion;

      if (updateData.isEmpty) {
        throw ArgumentError('No fields to update');
      }

      final response = await _client
          .from(_tableName)
          .update(updateData)
          .eq('status_id', statusId)
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .select()
          .single();

      return SeekerMilestoneStatusModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Milestone status not found or access denied');
      }
      throw DatabaseException(
        'Failed to update milestone status: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException || e is NotFoundException) rethrow;
      throw DatabaseException('Failed to update milestone status: $e');
    }
  }

  /// Delete milestone status
  Future<void> deleteStatus(String statusId) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      await _client
          .from(_tableName)
          .delete()
          .eq('status_id', statusId)
          .eq('job_seeker_id', jobSeeker.jobSeekerId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Milestone status not found or access denied');
      }
      throw DatabaseException(
        'Failed to delete milestone status: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException || e is NotFoundException) rethrow;
      throw DatabaseException('Failed to delete milestone status: $e');
    }
  }

  /// Get statuses with low confidence
  Future<List<SeekerMilestoneStatusModel>> getLowConfidenceStatuses() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .eq('low_confidence', true)
          .order('calculated_at', ascending: false);

      return (response as List)
          .map(
            (json) => SeekerMilestoneStatusModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get low confidence statuses: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get low confidence statuses: $e');
    }
  }

  /// Get statuses with skill gaps
  Future<List<SeekerMilestoneStatusModel>> getStatusesWithGaps() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .not('gaps', 'eq', '[]')
          .order('calculated_at', ascending: false);

      return (response as List)
          .map(
            (json) => SeekerMilestoneStatusModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get statuses with gaps: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get statuses with gaps: $e');
    }
  }

  /// Get average score for a role
  Future<double?> getAverageScoreForRole(String role) async {
    try {
      final statuses = await getStatusesForRole(role);
      if (statuses.isEmpty) return null;

      final scoresWithValues = statuses
          .where((s) => s.currentScorePct != null)
          .map((s) => s.currentScorePct!)
          .toList();

      if (scoresWithValues.isEmpty) return null;

      return scoresWithValues.reduce((a, b) => a + b) / scoresWithValues.length;
    } catch (e) {
      return null;
    }
  }

  /// Get progress summary for current job seeker
  Future<Map<String, dynamic>> getProgressSummary() async {
    try {
      final statuses = await getJobSeekerStatuses();

      if (statuses.isEmpty) {
        return {
          'total_assessments': 0,
          'roles_assessed': 0,
          'average_score': 0.0,
          'low_confidence_count': 0,
          'gaps_count': 0,
        };
      }

      final rolesAssessed = statuses.map((s) => s.role).toSet().length;
      final lowConfidenceCount = statuses
          .where((s) => s.hasLowConfidence)
          .length;
      final gapsCount = statuses.where((s) => s.hasGaps).length;

      final scoresWithValues = statuses
          .where((s) => s.currentScorePct != null)
          .map((s) => s.currentScorePct!)
          .toList();

      final averageScore = scoresWithValues.isEmpty
          ? 0.0
          : scoresWithValues.reduce((a, b) => a + b) / scoresWithValues.length;

      return {
        'total_assessments': statuses.length,
        'roles_assessed': rolesAssessed,
        'average_score': averageScore,
        'low_confidence_count': lowConfidenceCount,
        'gaps_count': gapsCount,
      };
    } catch (e) {
      return {
        'total_assessments': 0,
        'roles_assessed': 0,
        'average_score': 0.0,
        'low_confidence_count': 0,
        'gaps_count': 0,
      };
    }
  }

  /// Get recent statuses (within specified days)
  Future<List<SeekerMilestoneStatusModel>> getRecentStatuses(
    int withinDays,
  ) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final pastDate = DateTime.now()
          .subtract(Duration(days: withinDays))
          .toIso8601String();

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .gte('calculated_at', pastDate)
          .order('calculated_at', ascending: false);

      return (response as List)
          .map(
            (json) => SeekerMilestoneStatusModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get recent statuses: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get recent statuses: $e');
    }
  }
}
