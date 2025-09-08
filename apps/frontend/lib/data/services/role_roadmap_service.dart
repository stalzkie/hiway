import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/roadmap_role_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class RoleRoadmapService {
  static final RoleRoadmapService _instance = RoleRoadmapService._internal();
  factory RoleRoadmapService() => _instance;
  RoleRoadmapService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  static const String _tableName = 'role_roadmaps';

  /// Get roadmap by ID
  Future<RoadmapRoleModel?> getRoadmapById(String roadmapId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('roadmap_id', roadmapId)
          .maybeSingle();

      if (response == null) return null;
      return RoadmapRoleModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get roadmap: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to get roadmap: $e');
    }
  }

  /// Get roadmaps by role for current job seeker
  Future<List<RoadmapRoleModel>> getRoadmapsByRole(String role) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('role', role)
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => RoadmapRoleModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get roadmaps by role: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get roadmaps by role: $e');
    }
  }

  /// Get all roadmaps for current job seeker
  Future<List<RoadmapRoleModel>> getJobSeekerRoadmaps() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => RoadmapRoleModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get job seeker roadmaps: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get job seeker roadmaps: $e');
    }
  }

  /// Get active (non-expired) roadmaps for current job seeker
  Future<List<RoadmapRoleModel>> getActiveRoadmaps() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .or('expires_at.is.null,expires_at.gt.$now')
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => RoadmapRoleModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get active roadmaps: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get active roadmaps: $e');
    }
  }

  /// Find existing roadmap by unique constraint (role, provider, model, prompt_hash, allowlist_hash)
  Future<RoadmapRoleModel?> findExistingRoadmap({
    required String role,
    required String provider,
    required String model,
    required String promptHash,
    required String allowlistHash,
  }) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('role', role)
          .eq('provider', provider)
          .eq('model', model)
          .eq('prompt_hash', promptHash)
          .eq('allowlist_hash', allowlistHash)
          .maybeSingle();

      if (response == null) return null;
      return RoadmapRoleModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to find existing roadmap: ${e.message}');
    } catch (e) {
      throw DatabaseException('Failed to find existing roadmap: $e');
    }
  }

  /// Create new roadmap
  Future<RoadmapRoleModel> createRoadmap({
    required String role,
    required String provider,
    required String model,
    required String promptHash,
    required String allowlistHash,
    required List<dynamic> milestones,
    DateTime? expiresAt,
    List<dynamic>? certAllowlist,
    String? promptTemplate,
  }) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final roadmapData = {
        'role': role,
        'provider': provider,
        'model': model,
        'prompt_hash': promptHash,
        'allowlist_hash': allowlistHash,
        'milestones': milestones,
        'expires_at': expiresAt?.toIso8601String(),
        'job_seeker_id': jobSeeker.jobSeekerId,
        'cert_allowlist': certAllowlist ?? [],
        'prompt_template': promptTemplate,
      };

      final response = await _client
          .from(_tableName)
          .insert(roadmapData)
          .select()
          .single();

      return RoadmapRoleModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to create roadmap: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to create roadmap: $e');
    }
  }

  /// Update existing roadmap
  Future<RoadmapRoleModel> updateRoadmap({
    required String roadmapId,
    String? role,
    String? provider,
    String? model,
    String? promptHash,
    String? allowlistHash,
    List<dynamic>? milestones,
    DateTime? expiresAt,
    List<dynamic>? certAllowlist,
    String? promptTemplate,
  }) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final updateData = <String, dynamic>{};
      if (role != null) updateData['role'] = role;
      if (provider != null) updateData['provider'] = provider;
      if (model != null) updateData['model'] = model;
      if (promptHash != null) updateData['prompt_hash'] = promptHash;
      if (allowlistHash != null) updateData['allowlist_hash'] = allowlistHash;
      if (milestones != null) updateData['milestones'] = milestones;
      if (expiresAt != null) {
        updateData['expires_at'] = expiresAt.toIso8601String();
      }
      if (certAllowlist != null) updateData['cert_allowlist'] = certAllowlist;
      if (promptTemplate != null) {
        updateData['prompt_template'] = promptTemplate;
      }

      if (updateData.isEmpty) {
        throw ArgumentError('No fields to update');
      }

      final response = await _client
          .from(_tableName)
          .update(updateData)
          .eq('roadmap_id', roadmapId)
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .select()
          .single();

      return RoadmapRoleModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Roadmap not found or access denied');
      }
      throw DatabaseException('Failed to update roadmap: ${e.message}');
    } catch (e) {
      if (e is AuthException || e is NotFoundException) rethrow;
      throw DatabaseException('Failed to update roadmap: $e');
    }
  }

  /// Delete roadmap
  Future<void> deleteRoadmap(String roadmapId) async {
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
      if (e.code == 'PGRST116') {
        throw NotFoundException('Roadmap not found or access denied');
      }
      throw DatabaseException('Failed to delete roadmap: ${e.message}');
    } catch (e) {
      if (e is AuthException || e is NotFoundException) rethrow;
      throw DatabaseException('Failed to delete roadmap: $e');
    }
  }

  /// Get roadmap roles (unique roles for job seeker)
  Future<List<String>> getRoadmapRoles() async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select('role')
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .order('role');

      return (response as List)
          .map((json) => json['role'] as String)
          .toSet() // Remove duplicates
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get roadmap roles: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get roadmap roles: $e');
    }
  }

  /// Get latest roadmap for a specific role
  Future<RoadmapRoleModel?> getLatestRoadmapForRole(String role) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('role', role)
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return RoadmapRoleModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(
        'Failed to get latest roadmap for role: ${e.message}',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get latest roadmap for role: $e');
    }
  }

  /// Check if roadmap is expired
  Future<bool> isRoadmapExpired(String roadmapId) async {
    try {
      final roadmap = await getRoadmapById(roadmapId);
      return roadmap?.isExpired ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get roadmaps expiring soon (within specified days)
  Future<List<RoadmapRoleModel>> getExpiringSoon(int withinDays) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final futureDate = DateTime.now()
          .add(Duration(days: withinDays))
          .toIso8601String();
      final now = DateTime.now().toIso8601String();

      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', jobSeeker.jobSeekerId)
          .gte('expires_at', now)
          .lte('expires_at', futureDate)
          .order('expires_at', ascending: true);

      return (response as List)
          .map(
            (json) => RoadmapRoleModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get expiring roadmaps: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get expiring roadmaps: $e');
    }
  }

  /// Get roadmap count by role
  Future<int> getRoadmapCountByRole(String role) async {
    try {
      final jobSeeker = await _authService.getJobSeekerProfile();
      if (jobSeeker == null) {
        throw AuthException('No job seeker profile found');
      }

      final response = await _client
          .from(_tableName)
          .select()
          .eq('role', role)
          .eq('job_seeker_id', jobSeeker.jobSeekerId);

      return (response as List).length;
    } on PostgrestException catch (e) {
      throw DatabaseException('Failed to get roadmap count: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw DatabaseException('Failed to get roadmap count: $e');
    }
  }
}
