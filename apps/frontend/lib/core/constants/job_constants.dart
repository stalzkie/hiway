class JobConstants {
  // Job Types
  static const List<String> jobTypes = [
    'full-time',
    'part-time',
    'contract',
    'temporary',
    'internship',
    'freelance',
  ];

  // Salary Types
  static const List<String> salaryTypes = [
    'hourly',
    'daily',
    'monthly',
    'yearly',
  ];

  // Job Status
  static const List<String> jobStatus = [
    'active',
    'draft',
    'closed',
    'expired',
  ];

  // Default Values
  static const String defaultJobType = 'full-time';
  static const String defaultSalaryType = 'monthly';
  static const String defaultStatus = 'active';
  static const String defaultCurrency = 'PHP';

  // Validation
  static const int minJobTitleLength = 3;
  static const int maxJobTitleLength = 100;
  static const int minJobOverviewLength = 50;
  static const int maxJobOverviewLength = 2000;
  static const int maxJobLocationLength = 100;

  // Display helpers
  static String formatJobType(String jobType) {
    return jobType
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String formatSalaryType(String salaryType) {
    return salaryType[0].toUpperCase() + salaryType.substring(1);
  }
}
