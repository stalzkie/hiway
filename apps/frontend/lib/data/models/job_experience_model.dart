/// Experience model for job posts
class JobExperienceModel {
  final int years;
  final String domain;

  const JobExperienceModel({required this.years, required this.domain});

  factory JobExperienceModel.fromJson(Map<String, dynamic> json) {
    return JobExperienceModel(
      years: json['years'] as int? ?? 0,
      domain: json['domain'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'years': years, 'domain': domain};
  }

  @override
  String toString() => '$years years in $domain';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JobExperienceModel &&
        other.years == years &&
        other.domain == domain;
  }

  @override
  int get hashCode => years.hashCode ^ domain.hashCode;
}
