class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

class DatabaseException implements Exception {
  final String message;

  const DatabaseException(this.message);

  @override
  String toString() => 'DatabaseException: $message';
}

extension SupabaseExceptionHandler on Exception {
  AuthException toAuthException() {
    final message = toString();

    if (message.contains('Invalid login credentials')) {
      return const AuthException('Invalid email or password');
    } else if (message.contains('User already registered')) {
      return const AuthException('An account with this email already exists');
    } else if (message.contains('Password should be at least')) {
      return const AuthException('Password must be at least 8 characters long');
    } else if (message.contains('Email not confirmed')) {
      return const AuthException('Please check your email and confirm your account');
    } else if (message.contains('Invalid email')) {
      return const AuthException('Please enter a valid email address');
    } else if (message.contains('Network request failed')) {
      return const AuthException('Network error. Please check your internet connection');
    } else {
      return AuthException('Authentication failed: ${message.replaceAll('Exception: ', '')}');
    }
  }
}