class ErrorMessages {
  ErrorMessages._();

  static const String loginInvalidCredentials =
      'Email or password is incorrect. Double-check your credentials.';

  static const String loginEmailNotVerified =
      'Account not verified. Check your email for the verification link.';

  static const String loginSessionExpired =
      'Session expired. Please sign in again to continue.';

  static const String loginNetworkError =
      'No internet connection. Check your network and try again.';

  static const String loginServerError =
      'Server temporarily unavailable. Please try again in a few minutes.';

  static const String loginTooManyAttempts =
      'Too many failed attempts. Please wait 15 minutes before trying again.';

  static const String loginAccountLocked =
      'Account temporarily locked for security. Contact support if this continues.';

  static const String loginUnknownError =
      'Sign in failed. If this continues, contact support.';

  static const String registerEmailExists =
      'Email already registered. Use "Sign In" or try password reset.';

  static const String registerWeakPassword =
      'Password too weak. Use 8+ characters with letters, numbers, and symbols.';

  static const String registerEmailInvalid =
      'Invalid email format. Please enter a valid email address.';

  static const String registerNetworkError =
      'No internet connection. Check your network and try again.';

  static const String registerServerError =
      'Registration service unavailable. Please try again in a few minutes.';

  static const String registerUnknownError =
      'Registration failed. If this continues, contact support.';

  // ========================================
  // VALIDATION ERRORS
  // ========================================

  static const String validationEmailRequired = 'Email address is required';
  static const String validationEmailInvalid =
      'Please enter a valid email address';
  static const String validationPasswordRequired = 'Password is required';
  static const String validationPasswordTooShort =
      'Password must be at least 8 characters';
  static const String validationPasswordsNoMatch = 'Passwords do not match';
  static const String validationNameRequired = 'Name is required';
  static const String validationNameTooShort =
      'Name must be at least 2 characters';
  static const String validationPhoneInvalid =
      'Please enter a valid phone number';
  static const String validationRequiredField = 'This field is required';

  // ========================================
  // PROFILE & DATA ERRORS
  // ========================================

  static const String profileCreateError =
      'We couldn\'t create your profile. Please try again.';

  static const String profileUpdateError =
      'We couldn\'t save your changes. Please try again.';

  static const String profileNotFound =
      'Profile not found. Please complete your profile setup.';

  static const String dataLoadError =
      'Unable to load data. Please refresh and try again.';

  static const String dataSaveError =
      'We couldn\'t save your changes. Please try again.';

  // ========================================
  // JOB-RELATED ERRORS
  // ========================================

  static const String jobCreateError =
      'We couldn\'t create your job posting. Please try again.';

  static const String jobUpdateError =
      'We couldn\'t update your job posting. Please try again.';

  static const String jobDeleteError =
      'We couldn\'t delete this job posting. Please try again.';

  static const String jobNotFound = 'This job posting is no longer available.';

  static const String jobApplicationError =
      'We couldn\'t submit your application. Please try again.';

  // ========================================
  // NETWORK & GENERAL ERRORS
  // ========================================

  static const String networkConnectionError =
      'No internet connection. Please check your network and try again.';

  static const String serverError =
      'Our servers are experiencing issues. Please try again in a moment.';

  static const String timeoutError = 'The request timed out. Please try again.';

  static const String unknownError = 'Something went wrong. Please try again.';

  static const String permissionDenied =
      'You don\'t have permission to perform this action.';

  // ========================================
  // SUCCESS MESSAGES
  // ========================================

  static const String loginSuccess = 'Welcome back!';
  static const String registerSuccess = 'Account created successfully!';
  static const String profileUpdateSuccess = 'Profile updated successfully!';
  static const String jobCreatedSuccess = 'Job posting created successfully!';
  static const String jobUpdatedSuccess = 'Job posting updated successfully!';
  static const String applicationSentSuccess = 'Application sent successfully!';
  static const String emailVerificationSent = 'Verification email sent!';

  // ========================================
  // HELPER METHODS
  // ========================================

  /// Convert raw exception to user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return unknownError;

    final errorMessage = error.toString().toLowerCase();

    // Authentication errors - More specific detection
    if (errorMessage.contains('invalid login credentials') ||
        errorMessage.contains('invalid email or password') ||
        errorMessage.contains('wrong email or password') ||
        errorMessage.contains('invalid_grant')) {
      return loginInvalidCredentials;
    }

    if (errorMessage.contains('email not confirmed') ||
        errorMessage.contains('signup requires email confirmation') ||
        errorMessage.contains('email_not_confirmed')) {
      return loginEmailNotVerified;
    }

    if (errorMessage.contains('too many requests') ||
        errorMessage.contains('rate limit') ||
        errorMessage.contains('too_many_requests')) {
      return loginTooManyAttempts;
    }

    if (errorMessage.contains('account locked') ||
        errorMessage.contains('account disabled') ||
        errorMessage.contains('user_disabled')) {
      return loginAccountLocked;
    }

    if (errorMessage.contains('user already registered') ||
        errorMessage.contains('user already exists') ||
        errorMessage.contains('email_address_not_available')) {
      return registerEmailExists;
    }

    if (errorMessage.contains('password should be at least') ||
        errorMessage.contains('password must be at least') ||
        errorMessage.contains('weak_password') ||
        errorMessage.contains('password too short')) {
      return registerWeakPassword;
    }

    if (errorMessage.contains('invalid email') ||
        errorMessage.contains('email_address_invalid') ||
        errorMessage.contains('malformed email')) {
      return registerEmailInvalid;
    }

    if (errorMessage.contains('invalid refresh token') ||
        errorMessage.contains('session expired') ||
        errorMessage.contains('jwt expired')) {
      return loginSessionExpired;
    }

    // Network errors - More specific detection
    if (errorMessage.contains('network request failed') ||
        errorMessage.contains('network error') ||
        errorMessage.contains('no internet connection') ||
        errorMessage.contains('connection failed') ||
        errorMessage.contains('socketexception')) {
      return loginNetworkError;
    }

    if (errorMessage.contains('timeout') ||
        errorMessage.contains('timed out') ||
        errorMessage.contains('request timeout')) {
      return timeoutError;
    }

    if (errorMessage.contains('server error') ||
        errorMessage.contains('internal server error') ||
        errorMessage.contains('500') ||
        errorMessage.contains('503') ||
        errorMessage.contains('502')) {
      return loginServerError;
    }

    // Permission errors
    if (errorMessage.contains('permission denied') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('403')) {
      return permissionDenied;
    }

    // Profile errors
    if (errorMessage.contains('profile not found')) {
      return profileNotFound;
    }

    // Job errors
    if (errorMessage.contains('job not found')) {
      return jobNotFound;
    }

    // Default fallback
    return unknownError;
  }

  /// Get user-friendly error message for login errors
  static String getLoginErrorMessage(dynamic error) {
    return getUserFriendlyMessage(error);
  }

  /// Get user-friendly error message for signup errors
  static String getSignupErrorMessage(dynamic error) {
    return getUserFriendlyMessage(error);
  }

  /// Get validation message based on field type
  static String getValidationMessage(String fieldType, String? error) {
    if (error == null) return validationRequiredField;

    switch (fieldType.toLowerCase()) {
      case 'email':
        if (error.contains('required')) return validationEmailRequired;
        return validationEmailInvalid;

      case 'password':
        if (error.contains('required')) return validationPasswordRequired;
        if (error.contains('8 characters')) return validationPasswordTooShort;
        if (error.contains('match')) return validationPasswordsNoMatch;
        return error;

      case 'name':
      case 'fullname':
        if (error.contains('required')) return validationNameRequired;
        if (error.contains('2 characters')) return validationNameTooShort;
        return error;

      case 'phone':
        return validationPhoneInvalid;

      default:
        return error;
    }
  }

  /// Check if error indicates a network issue
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('no internet');
  }

  /// Check if error requires user authentication
  static bool requiresAuthentication(dynamic error) {
    if (error == null) return false;
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('session expired') ||
        errorMessage.contains('invalid refresh token') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('authentication required');
  }
}
