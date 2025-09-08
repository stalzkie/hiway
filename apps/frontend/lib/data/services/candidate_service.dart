import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Candidate Service for Employers - Search and manage job seekers
/// Following Single Responsibility and Clean Code principles
class CandidateService {
  static final CandidateService _instance = CandidateService._internal();
  factory CandidateService() => _instance;
  CandidateService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  static const String _tableName = 'job_seeker';

  /// Get all candidates/job seekers with optional filtering
  Future<List<JobSeekerModel>> getCandidates({
    String? searchQuery,
    List<String>? skillsFilter,
    String? locationFilter,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final query =
          (_client
                  .from(_tableName)
                  .select()
                  .range(offset, offset + limit - 1)
                  .order('updated_at', ascending: false))
              as PostgrestFilterBuilder;

      // Apply search filter
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query.or(
          'full_name.ilike.%$q%,email.ilike.%$q%,address.ilike.%$q%,search_document.ilike.%$q%',
        );
      }

      // Apply location filter
      if (locationFilter != null && locationFilter.trim().isNotEmpty) {
        query.ilike('address', '%${locationFilter.trim()}%');
      }

      // Apply skills filter using JSONB contains
      if (skillsFilter != null && skillsFilter.isNotEmpty) {
        for (final skill in skillsFilter) {
          query.contains('skills', [skill]);
        }
      }

      final response = await query;
      return (response as List)
          .map((json) => JobSeekerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException('Failed to get candidates: ${e.toString()}');
    }
  }

  /// Get candidate by ID
  Future<JobSeekerModel?> getCandidateById(String candidateId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('job_seeker_id', candidateId)
          .maybeSingle();

      if (response == null) return null;
      return JobSeekerModel.fromJson(response);
    } catch (e) {
      throw DatabaseException('Failed to get candidate: ${e.toString()}');
    }
  }

  /// Search candidates by skills matching
  Future<List<JobSeekerModel>> searchCandidatesBySkills({
    required List<String> requiredSkills,
    int minMatchingSkills = 1,
    int limit = 20,
  }) async {
    try {
      final query =
          (_client
                  .from(_tableName)
                  .select()
                  .order('updated_at', ascending: false)
                  .limit(limit))
              as PostgrestFilterBuilder;

      // Create skill filters - check if any of the required skills exist
      if (requiredSkills.isNotEmpty) {
        // Use contains to check if skills array contains any of the required skills
        for (int i = 0; i < requiredSkills.length; i++) {
          if (i == 0) {
            query.contains('skills', [requiredSkills[i]]);
          }
          // For additional skills, we'll filter in memory since Supabase OR with contains is complex
        }
      }

      final response = await query;
      final candidates = (response as List)
          .map((json) => JobSeekerModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter by minimum matching skills count in memory for better control
      if (minMatchingSkills > 1 || requiredSkills.length > 1) {
        return candidates.where((candidate) {
          final matchingSkills = candidate.skills
              .where(
                (skill) => requiredSkills.any(
                  (req) =>
                      skill.toLowerCase().contains(req.toLowerCase()) ||
                      req.toLowerCase().contains(skill.toLowerCase()),
                ),
              )
              .length;
          return matchingSkills >= minMatchingSkills;
        }).toList();
      }

      return candidates;
    } catch (e) {
      throw DatabaseException(
        'Failed to search candidates by skills: ${e.toString()}',
      );
    }
  }

  /// Get recently updated candidates
  Future<List<JobSeekerModel>> getRecentCandidates({int limit = 10}) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .order('updated_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => JobSeekerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        'Failed to get recent candidates: ${e.toString()}',
      );
    }
  }

  /// Search candidates using full-text search on search_document
  Future<List<JobSeekerModel>> fullTextSearchCandidates({
    required String searchTerm,
    int limit = 20,
  }) async {
    try {
      final query =
          (_client
                  .from(_tableName)
                  .select()
                  .order('updated_at', ascending: false)
                  .limit(limit))
              as PostgrestFilterBuilder;

      query.textSearch('search_document', searchTerm.trim());

      final response = await query;
      return (response as List)
          .map((json) => JobSeekerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        'Failed to perform full-text search: ${e.toString()}',
      );
    }
  }

  /// Get candidates suitable for a specific job post
  /// This method would integrate with your matching system
  Future<List<JobSeekerModel>> getCandidatesForJob({
    required String jobPostId,
    int limit = 20,
  }) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, you would use your matching algorithm
      // or query job_match_scores table to get suitable candidates

      // For now, just return recent candidates
      return await getRecentCandidates(limit: limit);
    } catch (e) {
      throw DatabaseException(
        'Failed to get candidates for job: ${e.toString()}',
      );
    }
  }

  /// Get basic candidate statistics for dashboard
  Future<Map<String, dynamic>> getCandidateStatistics() async {
    try {
      // Get recent candidates sample for statistics
      final recentCandidates = await _client
          .from(_tableName)
          .select('skills')
          .order('updated_at', ascending: false)
          .limit(100);

      final allSkills = <String>[];
      int totalCandidates = recentCandidates.length;

      for (final row in recentCandidates) {
        final candidate = JobSeekerModel.fromJson(row);
        allSkills.addAll(candidate.skills);
      }

      // Count skill occurrences
      final skillCounts = <String, int>{};
      for (final skill in allSkills) {
        skillCounts[skill] = (skillCounts[skill] ?? 0) + 1;
      }

      final topSkills = skillCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'sampleCandidates': totalCandidates,
        'topSkills': topSkills
            .take(10)
            .map((e) => {'skill': e.key, 'count': e.value})
            .toList(),
      };
    } catch (e) {
      throw DatabaseException(
        'Failed to get candidate statistics: ${e.toString()}',
      );
    }
  }

  /// Helper method to calculate match percentage between job requirements and candidate
  int calculateMatchPercentage({
    required JobSeekerModel candidate,
    required List<String> requiredSkills,
    List<String>? preferredExperience,
  }) {
    if (requiredSkills.isEmpty) return 0;

    int matches = 0;
    int total = requiredSkills.length;

    // Check skill matches
    for (final skill in requiredSkills) {
      if (candidate.skills.any(
        (candidateSkill) =>
            candidateSkill.toLowerCase().contains(skill.toLowerCase()) ||
            skill.toLowerCase().contains(candidateSkill.toLowerCase()),
      )) {
        matches++;
      }
    }

    // Add experience bonus if provided
    if (preferredExperience != null && preferredExperience.isNotEmpty) {
      total += preferredExperience.length;
      for (final exp in preferredExperience) {
        if (candidate.experience.any(
          (candidateExp) =>
              candidateExp.toLowerCase().contains(exp.toLowerCase()),
        )) {
          matches++;
        }
      }
    }

    return ((matches / total) * 100).round();
  }

  /// Search candidates by location
  Future<List<JobSeekerModel>> searchCandidatesByLocation({
    required String location,
    int limit = 20,
  }) async {
    try {
      final query =
          (_client
                  .from(_tableName)
                  .select()
                  .order('updated_at', ascending: false)
                  .limit(limit))
              as PostgrestFilterBuilder;

      query.ilike('address', '%${location.trim()}%');

      final response = await query;
      return (response as List)
          .map((json) => JobSeekerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DatabaseException(
        'Failed to search candidates by location: ${e.toString()}',
      );
    }
  }
}
