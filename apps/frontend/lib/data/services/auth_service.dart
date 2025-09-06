<<<<<<< HEAD
=======
// auth_service.dart - Improved version
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
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

<<<<<<< HEAD
=======
  // Sign in with email and password
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
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
<<<<<<< HEAD
        throw Exception('No user found');
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw e.toAuthException();
=======
        throw AuthException('Login failed - no user returned');
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException('Login failed: ${e.message}');
    } catch (e) {
      throw AuthException('Login failed: ${e.toString()}');
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
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
<<<<<<< HEAD
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
=======
        throw AuthException('Registration failed - no user returned');
      }
      return response;
    } on AuthException catch (e) {
      throw AuthException('Registration failed: ${e.message}');
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  // Create job seeker profile with better error handling
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
  Future<JobSeekerModel> createJobSeekerProfile({
    required String fullName,
    required String email,
    String? phone,
<<<<<<< HEAD
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');
=======
    String? address,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe

      final data = {
        'auth_user_id': user.id,
        'full_name': fullName.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
<<<<<<< HEAD
        'role': AppConstants.jobSeekerRole,
=======
        'address': address?.trim(),
        'role': AppConstants.jobSeekerRole,
        'skills': [],
        'experience': [],
        'education': [],
        'licenses_certifications': [],
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
      };

      final response = await _client
          .from(AppConstants.jobSeekerTable)
          .insert(data)
          .select()
          .single();

      return JobSeekerModel.fromJson(response);
    } on PostgrestException catch (e) {
<<<<<<< HEAD
      throw DatabaseException(e.message);
=======
      if (e.code == '23505') {
        throw DatabaseException('Profile already exists for this user');
      }
      throw DatabaseException('Database error: ${e.message}');
    } on AuthException {
      rethrow;
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
    } catch (e) {
      throw DatabaseException('Failed to create job seeker profile: $e');
    }
  }

<<<<<<< HEAD
  // Create employer profile
=======
  // Create employer profile with better error handling
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
  Future<EmployerModel> createEmployerProfile({
    required String name,
    required String company,
    required String companyPosition,
    String? companyEmail,
    String? companyPhoneNumber,
<<<<<<< HEAD
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');
=======
    String? dtiOrSecRegistration,
    String? barangayClearance,
    String? businessPermit,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe

      final data = {
        'auth_user_id': user.id,
        'name': name.trim(),
        'company': company.trim(),
        'company_position': companyPosition.trim(),
        'company_email': companyEmail?.trim(),
        'company_phone_number': companyPhoneNumber?.trim(),
<<<<<<< HEAD
=======
        'dti_or_sec_registration': dtiOrSecRegistration?.trim(),
        'barangay_clearance': barangayClearance?.trim(),
        'business_permit': businessPermit?.trim(),
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
        'role': AppConstants.employerRole,
      };

      final response = await _client
          .from(AppConstants.employerTable)
          .insert(data)
          .select()
          .single();

      return EmployerModel.fromJson(response);
    } on PostgrestException catch (e) {
<<<<<<< HEAD
      throw DatabaseException(e.message);
=======
      if (e.code == '23505') {
        throw DatabaseException('Profile already exists for this user');
      }
      throw DatabaseException('Database error: ${e.message}');
    } on AuthException {
      rethrow;
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
    } catch (e) {
      throw DatabaseException('Failed to create employer profile: $e');
    }
  }

<<<<<<< HEAD
  // Get user role
  Future<String?> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');

      final jobSeekerResponse = await _client
          .from(AppConstants.jobSeekerTable)
          .select()
=======
  // Get user role with better error handling
  Future<String?> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      // Check job seeker first
      final jobSeekerResponse = await _client
          .from(AppConstants.jobSeekerTable)
          .select('role')
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (jobSeekerResponse != null) {
        return jobSeekerResponse['role'] as String;
      }

<<<<<<< HEAD
      final employerResponse = await _client
          .from(AppConstants.employerTable)
          .select()
=======
      // Check employer
      final employerResponse = await _client
          .from(AppConstants.employerTable)
          .select('role')
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (employerResponse != null) {
        return employerResponse['role'] as String;
      }

      return null;
<<<<<<< HEAD
    } catch (e) {
=======
    } on PostgrestException catch (e) {
      print('Database error getting user role: ${e.message}');
      return null;
    } catch (e) {
      print('Error getting user role: $e');
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
      return null;
    }
  }

<<<<<<< HEAD
  // Get job seeker profile
  Future<JobSeekerModel?> getJobSeekerProfile() async {
    try {
      final user= currentUser;
      if (user == null) throw Exception('No user found');
=======
  // Get job seeker profile with better error handling
  Future<JobSeekerModel?> getJobSeekerProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe

      final response = await _client
          .from(AppConstants.jobSeekerTable)
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return JobSeekerModel.fromJson(response);
<<<<<<< HEAD
    } catch (e) {
=======
    } on PostgrestException catch (e) {
      print('Database error getting job seeker profile: ${e.message}');
      return null;
    } catch (e) {
      print('Error getting job seeker profile: $e');
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
      return null;
    }
  }

<<<<<<< HEAD
  //Get employer profile
  Future<EmployerModel?> getEmployerProfile() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user found');
=======
  // Get employer profile with better error handling
  Future<EmployerModel?> getEmployerProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe

      final response = await _client
          .from(AppConstants.employerTable)
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return EmployerModel.fromJson(response);
<<<<<<< HEAD
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
=======
    } on PostgrestException catch (e) {
      print('Database error getting employer profile: ${e.message}');
      return null;
    } catch (e) {
      print('Error getting employer profile: $e');
      return null;
    }
  }

  // Logout with better error handling
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      throw AuthException('Failed to sign out: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to sign out: ${e.toString()}');
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Check if user has completed profile
  Future<bool> hasCompletedProfile() async {
<<<<<<< HEAD
    final role = await getUserRole();
    return role != null;
=======
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
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
  }
}
