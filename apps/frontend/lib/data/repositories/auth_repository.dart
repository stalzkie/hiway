import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/employer_model.dart';
import 'package:hiway_app/data/models/job_seeker_model.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

abstract class AuthRepository {
  Future<AuthResponse> signIn(String email, String password);
  Future<AuthResponse> signUp(String email, String password);
  Future<void> signOut();
  Future<JobSeekerModel> createJobSeekerProfile({
    required String fullName,
    required String email,
    String? phone,
    String? address,
  });
  Future<EmployerModel> createEmployerProfile({
    required String name,
    required String company,
    required String companyPosition,
    String? companyEmail,
    String? companyPhoneNumber,
    String? dtiOrSecRegistration,
    String? barangayClearance,
    String? businessPermit,
  });
  Future<String?> getUserRole();
  Future<JobSeekerModel?> getJobSeekerProfile();
  Future<EmployerModel?> getEmployerProfile();
  Future<bool> hasCompletedProfile();
  User? get currentUser;
  Session? get currentSession;
  Stream<AuthState> get authStateStream;
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl({AuthService? authService}) 
      : _authService = authService ?? AuthService();

  @override
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _authService.signInWithEmail(
        email: email,
        password: password,
      );
    } catch (e) {
      throw AuthException('Authentication failed: ${e.toString()}');
    }
  }

  @override
  Future<AuthResponse> signUp(String email, String password) async {
    try {
      return await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  @override
  Future<JobSeekerModel> createJobSeekerProfile({
    required String fullName,
    required String email,
    String? phone,
    String? address,
  }) async {
    try {
      return await _authService.createJobSeekerProfile(
        fullName: fullName,
        email: email,
        phone: phone,
        address: address,
      );
    } catch (e) {
      if (e is DatabaseException || e is AuthException) {
        rethrow;
      }
      throw DatabaseException('Failed to create job seeker profile: ${e.toString()}');
    }
  }

  @override
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
      return await _authService.createEmployerProfile(
        name: name,
        company: company,
        companyPosition: companyPosition,
        companyEmail: companyEmail,
        companyPhoneNumber: companyPhoneNumber,
        dtiOrSecRegistration: dtiOrSecRegistration,
        barangayClearance: barangayClearance,
        businessPermit: businessPermit,
      );
    } catch (e) {
      if (e is DatabaseException || e is AuthException) {
        rethrow;
      }
      throw DatabaseException('Failed to create employer profile: ${e.toString()}');
    }
  }

  @override
  Future<String?> getUserRole() async {
    return await _authService.getUserRole();
  }

  @override
  Future<JobSeekerModel?> getJobSeekerProfile() async {
    return await _authService.getJobSeekerProfile();
  }

  @override
  Future<EmployerModel?> getEmployerProfile() async {
    return await _authService.getEmployerProfile();
  }

  @override
  Future<bool> hasCompletedProfile() async {
    return await _authService.hasCompletedProfile();
  }

  @override
  User? get currentUser => _authService.currentUser;

  @override
  Session? get currentSession => _authService.currentSession;

  @override
  Stream<AuthState> get authStateStream => _authService.authStateStream;
}
