class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final trimmedValue = value.trim().toLowerCase();

    if (trimmedValue.length < 5) {
      return 'Email is too short';
    }

    if (trimmedValue.length > 254) {
      return 'Email is too long';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(trimmedValue)) {
      return 'Please enter a valid email address';
    }

    // Check for @ position (should not be at the start)
    if (trimmedValue.indexOf('@') < 1) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (value.length > 72) {
      // bcrypt limit
      return 'Password must be less than 72 characters';
    }

    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  static String? validateConfirmPassword(
    String? value,
    String? originalPassword,
  ) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 2) {
      return 'Full name must be at least 2 characters long';
    }

    // Based on database constraint: char_length(full_name) <= 150
    if (trimmedValue.length > 150) {
      return 'Full name must be less than 150 characters';
    }

    // Allow letters, spaces, hyphens, apostrophes, and common accented characters
    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\s\-'\.]+$");
    if (!nameRegex.hasMatch(trimmedValue)) {
      return 'Full name can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Check for reasonable name format (at least first and last name)
    final nameParts = trimmedValue
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (nameParts.length < 1) {
      return 'Please enter your full name';
    }

    return null;
  }

  static String? validatePhoneNumber(String? value) {
    // Phone is optional for job seekers
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final trimmedValue = value.trim();

    // Remove common formatting characters
    final digitsOnly = trimmedValue.replaceAll(RegExp(r'[^0-9+]'), '');

    // Philippine phone number validation
    // Should be 11 digits (09xxxxxxxxx) or 13 digits (+639xxxxxxxxx)
    if (digitsOnly.startsWith('+63')) {
      if (digitsOnly.length != 13) {
        return 'Please enter a valid Philippine phone number (+639xxxxxxxxx)';
      }
      if (!digitsOnly.substring(3).startsWith('9')) {
        return 'Please enter a valid Philippine mobile number';
      }
    } else if (digitsOnly.startsWith('09')) {
      if (digitsOnly.length != 11) {
        return 'Please enter a valid Philippine phone number (09xxxxxxxxx)';
      }
    } else {
      return 'Please enter a valid Philippine phone number (09xxxxxxxxx or +639xxxxxxxxx)';
    }

    return null;
  }

  static String? validateCompanyName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Company name is required';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 2) {
      return 'Company name must be at least 2 characters long';
    }

    if (trimmedValue.length > 200) {
      // Reasonable limit for company names
      return 'Company name must be less than 200 characters';
    }

    // Allow letters, numbers, spaces, and common business symbols
    final companyRegex = RegExp(r"^[a-zA-Z0-9À-ÿ\s\-'&\.,()]+$");
    if (!companyRegex.hasMatch(trimmedValue)) {
      return 'Company name contains invalid characters';
    }

    return null;
  }

  static String? validatePosition(String? value) {
    if (value == null || value.isEmpty) {
      return 'Position is required';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 2) {
      return 'Position must be at least 2 characters long';
    }

    if (trimmedValue.length > 100) {
      return 'Position must be less than 100 characters';
    }

    // Allow letters, spaces, hyphens, and common position-related characters
    final positionRegex = RegExp(r"^[a-zA-ZÀ-ÿ0-9\s\-'&\.,()]+$");
    if (!positionRegex.hasMatch(trimmedValue)) {
      return 'Position contains invalid characters';
    }

    return null;
  }

  // New validator for general text fields
  static String? validateRequiredText(
    String? value,
    String fieldName, {
    int maxLength = 255,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return '$fieldName is required';
    }

    if (trimmedValue.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }

    return null;
  }

  // Validator for optional text fields
  static String? validateOptionalText(
    String? value,
    String fieldName, {
    int maxLength = 255,
  }) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }

    return null;
  }
}
