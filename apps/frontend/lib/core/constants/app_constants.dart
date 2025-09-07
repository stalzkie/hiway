class AppConstants {
  static const String appName = 'Hi-Way';

  // User Roles
  static const String jobSeekerRole = 'job_seeker';
  static const String employerRole = 'employer';

  // Route Names
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String profileSetupRoute = '/profile-setup';
  static const String emailVerificationRoute = '/email-verification';
  static const String homeRoute = '/home';
  static const String jobSeekerDashboardRoute = '/job-seeker-dashboard';
  static const String employerDashboardRoute = '/employer-dashboard';
  static const String profileRoute = '/profile';

  // Form Field
  static const String emailField = 'email';
  static const String passwordField = 'password';
  static const String rememberMeField = 'remember_me';
  static const String fullNameField = 'full_name';
  static const String phoneField = 'phone';
  static const String companyField = 'company';
  static const String positionField = 'position';
  static const String roleField = 'role';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Success Messages
  static const String loginSuccess = 'Welcome back!';
  static const String registerSuccess = 'Account created successfully';
  static const String logoutSuccess = 'Successfully logged out';
  static const String profileUpdateSuccess = 'Profile updated successfully';
  static const String profileCreatedSuccess =
      'Profile created successfully! You can now sign in.';

  // Error Messages
  static const String networkError = 'Please check your internet connection';
  static const String unknownError = 'An unexpected error occurred';
  static const String sessionExpired =
      'Your session has expired. Please login again';
  static const String profileNotFound =
      'Profile not found. Please complete your profile setup.';

  // Validation Messages
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String passwordTooShort =
      'Password must be at least 8 characters long';
  static const String passwordsNotMatch = 'Passwords do not match';

  // Table Names in Database
  static const String jobSeekerTable = 'job_seeker';
  static const String employerTable = 'employer';
}
