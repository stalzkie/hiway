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
    } else if (message.contains('User already registered') ||
        message.contains('User already exists')) {
      return const AuthException('An account with this email already exists');
    } else if (message.contains('Password should be at least') ||
        message.contains('Password must be at least')) {
      return const AuthException('Password must be at least 8 characters long');
    } else if (message.contains('Email not confirmed')) {
      return const AuthException(
        'Please check your email and confirm your account',
      );
    } else if (message.contains('Invalid email') ||
        message.contains('email_address_invalid')) {
      return const AuthException('Please enter a valid email address');
    } else if (message.contains('Network request failed') ||
        message.contains('network_request_failed')) {
      return const AuthException(
        'Network error. Please check your internet connection',
      );
    } else if (message.contains('Email address is invalid')) {
      return const AuthException('Please enter a valid email address');
    } else if (message.contains('Password is too weak')) {
      return const AuthException(
        'Password is too weak. Please use a stronger password',
      );
    } else if (message.contains('Signup requires email confirmation')) {
      return const AuthException(
        'Please check your email to confirm your account',
      );
    } else if (message.contains('Invalid refresh token')) {
      return const AuthException('Session expired. Please login again');
    } else {
      var cleanMessage = message
          .replaceAll('Exception: ', '')
          .replaceAll('AuthException: ', '')
          .replaceAll('DatabaseException: ', '');

      return AuthException(
        cleanMessage.isEmpty ? 'Authentication failed' : cleanMessage,
      );
    }
  }
}
