import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_application_model.dart';

class ApplicationService {
  ApplicationService({
    SupabaseClient? client,
    required String apiBase, // e.g. "http://localhost:8000"
  })  : _sb = client ?? Supabase.instance.client,
        _apiBase = apiBase.replaceAll(RegExp(r'/+$'), '');

  final SupabaseClient _sb;
  final String _apiBase;

  /// Apply for a job (calls FastAPI `/applications/apply`)
  Future<String?> applyForJob({
    required String job_post_id,
    required String job_seeker_id,
    required String employer_id,
    double? matchConfidence,
    Map<String, dynamic>? matchSnapshot,
    String? resumeUrl,
    required String bearerToken,
  }) async {
    final uri = Uri.parse('$_apiBase/applications/apply');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      body: jsonEncode({
        'job_post_id': job_post_id,
        'job_seeker_id': job_seeker_id,
        'employer_id': employer_id,
        if (matchConfidence != null) 'match_confidence': matchConfidence,
        if (matchSnapshot != null) 'match_snapshot': matchSnapshot,
        if (resumeUrl != null) 'resume_url': resumeUrl,
      }),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['application_id'] as String?;
    } else {
      throw Exception('Failed to apply: ${resp.body}');
    }
  }

  Future<String?> getJobSeekerId(String authId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final url = Uri.parse(
      'https://txgqnhsivkmthngtsqhg.supabase.co/functions/v1/get-job-seeker-id',
    ).replace(queryParameters: {
      'authId': authId,
    });

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer ${_sb.auth.currentSession?.accessToken}',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["job_seeker_id"] as String?;
    } else {
      print("Error: ${res.body}");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchJobWithMatchAndEmployer({
    required String jobPostId,
    required String authId,
  }) async {
    String? jobSeekerId = await getJobSeekerId(authId);
    final url = Uri.parse(
      'https://txgqnhsivkmthngtsqhg.supabase.co/functions/v1/test-edge-func',
    ).replace(queryParameters: {
    'jobPostId': jobPostId,
    'jobSeekerId': jobSeekerId ?? "",
  });

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer ${_sb.auth.currentSession?.accessToken}',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      if (data.isEmpty) return null;

      // Take the first item from the list since we expect one result
      if (data[0] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data[0]);
      }
      return null;
    } else {
      print("Error: ${res.body}");
      return null;
    }
  }

  /// List my applications (seeker)
  Future<List<ApplicationModel>> listMyApplications({
    required String bearerToken,
    int limit = 20,
    int offset = 0,
    String? status,
    String? jobPostId,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null) 'status': status,
      if (jobPostId != null) 'job_post_id': jobPostId,
    };
    final uri = Uri.parse('$_apiBase/applications/me').replace(queryParameters: params);
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $bearerToken'},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final items = data['items'] as List;
      return items.map((e) => ApplicationModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch applications: ${resp.body}');
    }
  }

  /// Employer: list applications to my job posts
  Future<List<ApplicationModel>> employerListApplications({
    required String bearerToken,
    int limit = 20,
    int offset = 0,
    String? jobPostId,
    String? status,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (jobPostId != null) 'job_post_id': jobPostId,
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('$_apiBase/applications/employer').replace(queryParameters: params);
    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $bearerToken'},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final items = data['items'] as List;
      return items.map((e) => ApplicationModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch employer applications: ${resp.body}');
    }
  }

  /// Employer: update application status
  Future<ApplicationModel> updateApplicationStatus({
    required String applicationId,
    required String newStatus,
    required String bearerToken,
  }) async {
    final uri = Uri.parse('$_apiBase/applications/$applicationId/status');
    final resp = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      body: jsonEncode({'status': newStatus}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return ApplicationModel.fromJson(data);
    } else {
      throw Exception('Failed to update status: ${resp.body}');
    }
  }

  /// Seeker: withdraw application
  Future<ApplicationModel> withdrawApplication({
    required String applicationId,
    required String bearerToken,
  }) async {
    final uri = Uri.parse('$_apiBase/applications/$applicationId/withdraw');
    final resp = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $bearerToken'},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return ApplicationModel.fromJson(data);
    } else {
      throw Exception('Failed to withdraw application: ${resp.body}');
    }
  }
}