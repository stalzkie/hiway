import 'package:hiway_app/core/config/app_config.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => SupabaseConfig.client;
  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;
  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateStream => _auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // FastAPI matcher access
  // ---------------------------------------------------------------------------

  // OPTION A ✅: unify with JobService — use the SAME base everywhere
  // Previously: AppConfig.fastApiBaseUrl
  String get _apiBase => AppConstants.apiBase; // e.g., http://10.0.2.2:8000

  Future<Map<String, String>> _authHeaders() async {
    final token = currentSession?.accessToken;
    if (token == null) {
      throw AuthException('Not authenticated: no access token');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Call FastAPI /match for a given seeker.
  /// We keep defaults minimal; tweak query params if you need different behavior.
  Future<void> _runMatcherFastApi({required String jobSeekerId}) async {
    final uri = Uri.parse('$_apiBase/match?job_seeker_id=$jobSeekerId');

    // 🔎 DEBUG (temporary): confirm API base at runtime
    // Remove after verifying on device/simulator.
    // You should see this in your device/emulator logs.
    // Example expected:
    //   Android emulator → http://10.0.2.2:8000/match?job_seeker_id=...
    //   iOS simulator   → http://127.0.0.1:8000/match?job_seeker_id=...
    //   Physical phone  → http://192.168.x.x:8000/match?job_seeker_id=...
    // ignore: avoid_print
    print('[AuthService] calling /match → $uri');

    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Do not crash login flow; surface as a controlled exception
      throw Exception('FastAPI /match failed (${res.statusCode}): ${res.body}');
    }
  }

  /// Decide whether we need to re-run the matcher:
  /// - If there is no prior score (no calculated_at) for this seeker
  /// - OR if the newest job_post (updated_at || created_at) is newer than last score
  /// - OR if the job seeker profile updated_at is newer than last score
  Future<bool> _shouldRunMatcher(String jobSeekerId, DateTime seekerUpdatedAt) async {
    // 1) Get last score time for this seeker
    DateTime? lastCalculatedAt;
    try {
      final lastScoreRow = await _client
          .from('job_match_scores')
          .select('calculated_at')
          .eq('job_seeker_id', jobSeekerId)
          .order('calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastScoreRow != null && lastScoreRow['calculated_at'] != null) {
        lastCalculatedAt = DateTime.parse(lastScoreRow['calculated_at'] as String);
      }
    } catch (_) {
      // Ignore read errors; treat as if no score exists.
      lastCalculatedAt = null;
    }

    // If no score exists, we should run.
    if (lastCalculatedAt == null) return true;

    // 2) Get newest job_post timestamp (prefer updated_at; fallback to created_at)
    DateTime newestJobPost = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final newestPostRow = await _client
          .from('job_post')
          .select('updated_at, created_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String? ts =
          (newestPostRow?['updated_at'] as String?) ?? (newestPostRow?['created_at'] as String?);
      if (ts != null) {
        newestJobPost = DateTime.parse(ts);
      }
    } catch (_) {
      // If job_post read fails, keep epoch -> means won't force run based on posts.
    }

    // Compare times
    if (newestJobPost.isAfter(lastCalculatedAt)) return true;
    if (seekerUpdatedAt.isAfter(lastCalculatedAt)) return true;

    return false;
  }

  /// Ensure latest matches on login:
  /// - Fetch the job seeker profile
  /// - Decide freshness
  /// - Run matcher if needed (silently swallow non-fatal errors)
  Future<void> _ensureFreshMatchesOnLogin() async {
    try {
      final seeker = await getJobSeekerProfile();
      if (seeker == null) return; // not a seeker; nothing to do

      final needsRun = await _shouldRunMatcher(seeker.jobSeekerId, seeker.updatedAt);
      if (needsRun) {
        await _runMatcherFastApi(jobSeekerId: seeker.jobSeekerId);
      }
    } catch (e) {
      // Do not block the login UX if matcher fails;
      // you may log this to your telemetry instead.
      // print('[matcher] skipped on login: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Auth & profile methods (existing)
  // ---------------------------------------------------------------------------

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw AuthException('Login failed - no user returned');
      }

      // 🔸 After successful login, ensure matches exist & are fresh
      await _ensureFreshMatchesOnLogin();

      return response;
    } on AuthException catch (e) {
      throw AuthException('Login failed: ${e.message}');
    } catch (e) {
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: null, // default redirect from Supabase dashboard
      );

      if (response.user == null) {
        throw AuthException('Registration failed - no user returned');
      }
      return response;
    } on AuthException catch (e) {
      throw AuthException('Registration failed: ${e.message}');
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  // Resend email confirmation
  Future<void> resendEmailConfirmation({required String email}) async {
    try {
      await _auth.resend(type: OtpType.signup, email: email.trim());
    } on AuthException catch (e) {
      throw AuthException('Failed to resend confirmation: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to resend confirmation: ${e.toString()}');
    }
  }

  // Check if user needs email verification
  bool get needsEmailVerification {
    final user = currentUser;
    return user != null && user.emailConfirmedAt == null;
  }

  // Create job seeker profile
  Future<JobSeekerModel> createJobSeekerProfile({
    required String fullName,
    required String email,
    String? phone,
    String? address,
  }) async {
    return createJobSeekerProfileWithDetails(
      fullName: fullName,
      email: email,
      phone: phone,
      address: address,
      skills: const [],
      experience: const [],
      education: const [],
      licensesCertifications: const [],
    );
  }

  // Create job seeker profile with more details
  Future<JobSeekerModel> createJobSeekerProfileWithDetails({
    required String fullName,
    required String email,
    String? phone,
    String? address,
    List<String> skills = const [],
    List<Map<String, dynamic>> experience = const [],
    List<Map<String, dynamic>> education = const [],
    List<Map<String, dynamic>> licensesCertifications = const [],
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }

      final data = {
        'auth_user_id': user.id,
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
        'address': address?.trim(),
        'role': AppConstants.jobSeekerRole,
        'skills': skills,
        'experience': experience,
        'education': education,
        'licenses_certifications': licensesCertifications,
      };

      final response = await _client
          .from(AppConstants.jobSeekerTable)
          .insert(data)
          .select()
          .single();

      return JobSeekerModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw DatabaseException('Profile already exists for this user');
      }
      throw DatabaseException('Database error: ${e.message}');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to create job seeker profile: $e');
    }
  }

  // Create employer profile
  Future<EmployerModel> createEmployerProfile({
    required String name,
    required String company,
    required String companyPosition,
    String? companyEmail,
    String? companyPhoneNumber,
    String? dtiOrSecRegistration,
    String? barangayClearance,
    String? businessPermit,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }

      final data = {
        'auth_user_id': user.id,
        'name': name.trim(),
        'company': company.trim(),
        'company_position': companyPosition.trim(),
        'company_email': companyEmail?.trim(),
        'company_phone_number': companyPhoneNumber?.trim(),
        'dti_or_sec_registration': dtiOrSecRegistration?.trim(),
        'barangay_clearance': barangayClearance?.trim(),
        'business_permit': businessPermit?.trim(),
        'role': AppConstants.employerRole,
      };

      final response = await _client
          .from(AppConstants.employerTable)
          .insert(data)
          .select()
          .single();

      return EmployerModel.fromJson(response);
    } catch (e) {
      throw DatabaseException('Failed to create employer profile: $e');
    }
  }

  // Get user role
  Future<String?> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      // Check job seeker first
      final jobSeekerResponse = await _client
          .from(AppConstants.jobSeekerTable)
          .select('role')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (jobSeekerResponse != null) {
        return jobSeekerResponse['role'] as String;
      }

      // Check employer
      final employerResponse = await _client
          .from(AppConstants.employerTable)
          .select('role')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (employerResponse != null) {
        return employerResponse['role'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get job seeker profile
  Future<JobSeekerModel?> getJobSeekerProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await _client
          .from(AppConstants.jobSeekerTable)
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return JobSeekerModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get employer profile
  Future<EmployerModel?> getEmployerProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await _client
          .from(AppConstants.employerTable)
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return EmployerModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Logout
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      throw AuthException('Failed to sign out: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to sign out: ${e.toString()}');
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Check if user has completed profile
  Future<bool> hasCompletedProfile() async {
    try {
      final role = await getUserRole();
      return role != null;
    } catch (e) {
      return false;
    }
  }

  // Get user profile (either job seeker or employer)
  Future<dynamic> getUserProfile() async {
    final role = await getUserRole();

    if (role == AppConstants.jobSeekerRole) {
      return await getJobSeekerProfile();
    } else if (role == AppConstants.employerRole) {
      return await getEmployerProfile();
    }

    return null;
  }
}
