class JobValidators {
  static String? validateJobTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Job title is required';
    }

    final title = value.trim();
    if (title.length < 3) {
      return 'Job title must be at least 3 characters long';
    }

    if (title.length > 100) {
      return 'Job title cannot exceed 100 characters';
    }

    return null;
  }

  /// Validates job overview
  static String? validateJobOverview(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Job overview is required';
    }

    final overview = value.trim();
    if (overview.length < 50) {
      return 'Job overview must be at least 50 characters long';
    }

    if (overview.length > 2000) {
      return 'Job overview cannot exceed 2000 characters';
    }

    return null;
  }

  /// Validates job location
  static String? validateJobLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Location is required';
    }

    if (value.trim().length > 100) {
      return 'Location cannot exceed 100 characters';
    }

    return null;
  }

  /// Validates salary amount
  static String? validateSalaryAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Salary amount is required';
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Enter a valid salary amount';
    }

    if (amount <= 0) {
      return 'Salary amount must be greater than 0';
    }

    if (amount > 10000000) {
      return 'Salary amount seems too high';
    }

    return null;
  }

  /// Validates comma-separated lists (skills, experience, etc.)
  static String? validateCommaSeparatedList(
    String? value, {
    required String fieldName,
    int minItems = 0,
  }) {
    if (value == null || value.trim().isEmpty) {
      return minItems > 0 ? '$fieldName is required' : null;
    }

    final items = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (items.length < minItems) {
      return '$fieldName must have at least $minItems item${minItems > 1 ? 's' : ''}';
    }

    // Check for duplicate items
    final uniqueItems = items.toSet();
    if (uniqueItems.length != items.length) {
      return '$fieldName contains duplicate entries';
    }

    // Check individual item length
    for (final item in items) {
      if (item.length > 50) {
        return 'Each $fieldName item should not exceed 50 characters';
      }
    }

    return null;
  }

  /// Validates deadline
  static String? validateDeadline(DateTime? deadline) {
    if (deadline == null) {
      return null;
    }

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    if (deadline.isBefore(tomorrow)) {
      return 'Deadline must be at least tomorrow';
    }

    final oneYearFromNow = DateTime(now.year + 1, now.month, now.day);
    if (deadline.isAfter(oneYearFromNow)) {
      return 'Deadline cannot be more than 1 year from now';
    }
    return null;
  }
}
