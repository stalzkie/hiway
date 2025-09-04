import 'package:hiway_app/core/config/app_config.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => SupabaseConfig.client;
  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;
  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateStream => _auth.onAuthStateChange;

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
        throw Exception('No user found');
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw e.toAuthException();
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
      );

      if (response.user == null) {
        throw Exception('No user found');
      }
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw e.toAuthException();
    }
  }

  // Create job seeker profile
  Future<JobSeekerModel> createJobSeekerProfile({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');

      final data = {
        'auth_user_id': user.id,
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
        'role': AppConstants.jobSeekerRole,
      };

      final response = await _client
          .from(AppConstants.jobSeekerTable)
          .insert(data)
          .select()
          .single();

      return JobSeekerModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
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
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');

      final data = {
        'auth_user_id': user.id,
        'name': name.trim(),
        'company': company.trim(),
        'company_position': companyPosition.trim(),
        'company_email': companyEmail?.trim(),
        'company_phone_number': companyPhoneNumber?.trim(),
        'role': AppConstants.employerRole,
      };

      final response = await _client
          .from(AppConstants.employerTable)
          .insert(data)
          .select()
          .single();

      return EmployerModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    } catch (e) {
      throw DatabaseException('Failed to create employer profile: $e');
    }
  }

  // Get user role
  Future<String?> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');

      final jobSeekerResponse = await _client
          .from(AppConstants.jobSeekerTable)
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (jobSeekerResponse != null) {
        return jobSeekerResponse['role'] as String;
      }

      final employerResponse = await _client
          .from(AppConstants.employerTable)
          .select()
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
      final user= currentUser;
      if (user == null) throw Exception('No user found');

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

  //Get employer profile
  Future<EmployerModel?> getEmployerProfile() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');

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
    } catch (e) {
      throw AuthException('Failed to sign out');
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Check if user has completed profile
  Future<bool> hasCompletedProfile() async {
    final role = await getUserRole();
    return role != null;
  }
}
