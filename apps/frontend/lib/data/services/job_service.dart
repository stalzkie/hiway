import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_model.dart';

/// JobService
/// - Personalized feed: pulled from your FastAPI `/match` endpoint (Suggestion 3)
/// - Generic lists (all / trending / by id): read from Supabase
class JobService {
  JobService({
    SupabaseClient? client,
    required String apiBase, // e.g. "http://localhost:8000"
  })  : _sb = client ?? Supabase.instance.client,
        _apiBase = apiBase.replaceAll(RegExp(r'/+$'), '');

  final SupabaseClient _sb;
  final String _apiBase;

  // Base columns from job_post (no `status`, per your schema)
  static const _cols = '''
    job_post_id, job_title, job_company, job_location,
    salary, job_skills, job_overview, job_type, job_experience,
    created_at, deadline, company_logo, is_trending
  ''';

  // ---------------------------------------------------------------------------
  // Personalized feed (from FastAPI `/match`) — Suggestion 3 applied
  // ---------------------------------------------------------------------------

  /// Recommended jobs for a specific seeker using the FastAPI `/match` endpoint.
  /// We request `include_details=1` so the server returns `job_post` rows inline.
  ///
  /// Response shape expected (per your matcher):
  /// [
  ///   {
  ///     "job_post_id": "...",
  ///     "confidence": 87.34,
  ///     "section_scores": {...},
  ///     "job_post": { <job_post columns> },
  ///     "analysis": {...}
  ///   },
  ///   ...
  /// ]
  Future<List<JobModel>> getRecommendedJobs({
  required String jobSeekerId,
  int topKPerSection = 20,
  int limit = 5,
  int minSections = 1,
  }) async {
    final uri = Uri.parse(
      '$_apiBase/match'
      '?job_seeker_id=$jobSeekerId'
      '&include_details=true'
      // NOTE: backend param is `top_k`, not `top_k_per_section`
      '&top_k=$topKPerSection'
      '&min_sections=$minSections'
      '&eager_embed=true',
    );

    try {
      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      if (resp.statusCode != 200) return const <JobModel>[];

      final decoded = jsonDecode(resp.body);

      // Accept both shapes for safety:
      // 1) { job_seeker_id, count, matches: [...] }  <-- current FastAPI
      // 2) [ ... ]                                   <-- legacy shape
      final List matches;
      if (decoded is Map<String, dynamic> && decoded['matches'] is List) {
        matches = decoded['matches'] as List;
      } else if (decoded is List) {
        matches = decoded;
      } else {
        return const <JobModel>[];
      }

      final results = <JobModel>[];
      for (final item in matches.take(limit)) {
        if (item is! Map<String, dynamic>) continue;

        // Merge job_post payload into root for JobModel.fromJson
        final merged = <String, dynamic>{};
        final jp = (item['job_post'] is Map) ? item['job_post'] as Map : const {};
        merged.addAll(jp.cast<String, dynamic>());

        // carry scoring fields (JobModel reads confidence/match_percentage)
        final conf = item['confidence'];
        if (conf != null) merged['confidence'] = conf;
        final mp = item['match_percentage'];
        if (mp != null) merged['match_percentage'] = mp;

        // fallback for id
        if (!merged.containsKey('job_post_id') && item['job_post_id'] != null) {
          merged['job_post_id'] = item['job_post_id'];
        }

        results.add(JobModel.fromJson(merged));
      }
      return results;
    } catch (_) {
      return const <JobModel>[];
    }
  }


  // ---------------------------------------------------------------------------
  // Generic lists via Supabase (not personalized)
  // ---------------------------------------------------------------------------

  /// All jobs with optional filters (unpersonalized).
  /// For a personalized list, call [getRecommendedJobs] above instead.
  Future<List<JobModel>> getAllJobs({
    String? searchQuery,
    String? location,
    String? jobType,
    String? experience,
    List<String>? skills,
    int limit = 50,
    int offset = 0,
  }) async {
    // Cast to PostgrestFilterBuilder so ilike/or/contains helpers are available.
    final query = (_sb
            .from('job_post')
            .select(_cols)
            .range(offset, offset + limit - 1))
        as PostgrestFilterBuilder;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      // OR across multiple text columns
      query.or(
        'job_title.ilike.%$q%,job_company.ilike.%$q%,job_location.ilike.%$q%',
      );
    }

    if (location != null && location.trim().isNotEmpty) {
      query.ilike('job_location', '%${location.trim()}%');
    }

    if (jobType != null && jobType.trim().isNotEmpty) {
      query.ilike('job_type', '%${jobType.trim()}%');
    }

    if (experience != null && experience.trim().isNotEmpty) {
      query.ilike('job_experience', '%${experience.trim()}%');
    }

    if (skills != null && skills.isNotEmpty) {
      // jsonb @> array containment for skill filters
      query.contains('job_skills', skills);
    }

    // Newest first
    query.order('created_at', ascending: false);

    final rows = await query;
    final list = rows as List;
    return list.map((r) => JobModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Trending jobs (no personalization).
  Future<List<JobModel>> getTrendingJobs({int limit = 20}) async {
    final rows = await _sb
        .from('job_post')
        .select(_cols)
        .eq('is_trending', true)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = rows as List;
    return list.map((r) => JobModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Single job (no personalization here).
  /// If you need the seeker’s score, fetch via `/match` and pick the row.
  Future<JobModel?> getJobById(String id) async {
    final row = await _sb
        .from('job_post')
        .select(_cols)
        .eq('job_post_id', id)
        .maybeSingle();

    if (row == null) return null;
    return JobModel.fromJson(row);
  }

  // Stubs for later
  Future<bool> applyToJob(String jobId) async => true;
  Future<bool> saveJob(String jobId) async => true;
}
