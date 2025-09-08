import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/roadmap_resources_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Roadmap Resources Service - CRUD operations for roadmap resources
/// Following Single Responsibility and Clean Code principles
class RoadmapResourcesService {
  static final RoadmapResourcesService _instance =
      RoadmapResourcesService._internal();
  factory RoadmapResourcesService() => _instance;
  RoadmapResourcesService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  static const String _tableName = 'roadmap_resources';

  /// Get roadmap resources by roadmap ID and milestone index
  Future<RoadmapResourcesModel?> getRoadmapResources({
    required String roadmapId,
    required int milestoneIndex,
  }) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('roadmap_id', roadmapId)
          .eq('milestone_index', milestoneIndex)
          .maybeSingle();

      if (response == null) return null;
      return RoadmapResourcesModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get roadmap resources: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to get roadmap resources: $e');
    }
  }

  /// Get all roadmap resources for a specific roadmap
  Future<List<RoadmapResourcesModel>> getRoadmapResourcesByRoadmap(
    String roadmapId,
  ) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('roadmap_id', roadmapId)
          .order('milestone_index', ascending: true);

      return (response as List)
          .map(
            (json) =>
                RoadmapResourcesModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get roadmap resources: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to get roadmap resources: $e');
    }
  }

  /// Get all roadmap resources for the current job seeker
  Future<List<RoadmapResourcesModel>> getJobSeekerRoadmapResources() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .order('fetched_at', ascending: false);

      return (response as List)
          .map(
            (json) =>
                RoadmapResourcesModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get job seeker roadmap resources: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get job seeker roadmap resources: $e');
    }
  }

  /// Create or update roadmap resources
  Future<RoadmapResourcesModel> upsertRoadmapResources({
    required String roadmapId,
    required int milestoneIndex,
    required List<dynamic> resources,
    required List<dynamic> certifications,
    required List<dynamic> networkGroups,
  }) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final resourceData = {
        'roadmap_id': roadmapId,
        'milestone_index': milestoneIndex,
        'resources': resources,
        'certifications': certifications,
        'network_groups': networkGroups,
        'job_seeker_id': jobSeeker.jobSeekerId,
      };

      final response = await _client
          .from(_tableName)
          .upsert(resourceData, onConflict: 'roadmap_id,milestone_index')
          .select()
          .single();

      return RoadmapResourcesModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to upsert roadmap resources: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to upsert roadmap resources: $e');
    }
  }

  /// Delete roadmap resources
  Future<void> deleteRoadmapResources({
    required String roadmapId,
    required int milestoneIndex,
  }) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      await _client
          .from(_tableName)
          .delete()
          .eq('roadmap_id', roadmapId)
          .eq('milestone_index', milestoneIndex)
          .eq('job_seeker_id', jobSeeker.jobSeekerId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Roadmap resources not found');
      }
      throw DatabaseException(
        'Failed to delete roadmap resources: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException || e is NotFoundException) rethrow;
      throw DatabaseException('Failed to delete roadmap resources: $e');
    }
  }

  /// Delete all roadmap resources for a specific roadmap
  Future<void> deleteAllRoadmapResources(String roadmapId) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      await _client
          .from(_tableName)
          .delete()
          .eq('roadmap_id', roadmapId)
          .eq('job_seeker_id', jobSeeker.jobSeekerId);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to delete roadmap resources: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to delete roadmap resources: $e');
    }
  }

  /// Check if resources exist for a milestone
  Future<bool> hasResourcesForMilestone({
    required String roadmapId,
    required int milestoneIndex,
  }) async {
    try {
      final resource = await getRoadmapResources(
        roadmapId: roadmapId,
        milestoneIndex: milestoneIndex,
      );
      return resource != null;
    } catch (e) {
      return false;
    }
  }

  /// Get resources count for a roadmap
  Future<int> getResourcesCount(String roadmapId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('roadmap_id', roadmapId);

      return (response as List).length;
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get resources count: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to get resources count: $e');
    }
  }

  /// Batch update multiple milestone resources
  Future<List<RoadmapResourcesModel>> batchUpsertResources(
    List<Map<String, dynamic>> resourcesData,
  ) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      // Add job seeker ID to all resources
      final enrichedData = resourcesData.map((data) {
        return {...data, 'job_seeker_id': jobSeeker.jobSeekerId};
      }).toList();

      final response = await _client
          .from(_tableName)
          .upsert(enrichedData, onConflict: 'roadmap_id,milestone_index')
          .select();

      return (response as List)
          .map(
            (json) =>
                RoadmapResourcesModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to batch upsert resources: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to batch upsert resources: $e');
    }
  }
}
