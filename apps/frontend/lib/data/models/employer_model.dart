class EmployerModel {
  final String employerId;
  final String? authUserId;
  final String role;
  final String? name;
  final String? company;
  final String? companyEmail;
  final String? companyPosition;
  final String? companyPhoneNumber;
  final String? dtiOrSecRegistration; 
  final String? barangayClearance; 
  final String? businessPermit; 
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployerModel({
    required this.employerId,
    this.authUserId,
    required this.role,
    this.name,
    this.company,
    this.companyEmail,
    this.companyPosition,
    this.companyPhoneNumber,
    this.dtiOrSecRegistration,
    this.barangayClearance,
    this.businessPermit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployerModel.fromJson(Map<String, dynamic> json) {
    return EmployerModel(
      employerId: json['employer_id'] as String,
      authUserId: json['auth_user_id'] as String?,
      role: json['role'] as String,
      name: json['name'] as String?,
      company: json['company'] as String?,
      companyEmail: json['company_email'] as String?,
      companyPosition: json['company_position'] as String?, 
      companyPhoneNumber: json['company_phone_number'] as String?,
      dtiOrSecRegistration: json['dti_or_sec_registration'] as String?,
      barangayClearance: json['barangay_clearance'] as String?,
      businessPermit: json['business_permit'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employer_id': employerId,
      'auth_user_id': authUserId,
      'role': role,
      'name': name,
      'company': company,
      'company_email': companyEmail,
      'company_position': companyPosition,
      'company_phone_number': companyPhoneNumber,
      'dti_or_sec_registration': dtiOrSecRegistration,
      'barangay_clearance': barangayClearance,
      'business_permit': businessPermit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EmployerModel copyWith({
    String? employerId,
    String? authUserId,
    String? role,
    String? name,
    String? company,
    String? companyEmail,
    String? companyPosition,
    String? companyPhoneNumber,
    String? dtiOrSecRegistration,
    String? barangayClearance,
    String? businessPermit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployerModel(
      employerId: employerId ?? this.employerId,
      authUserId: authUserId ?? this.authUserId,
      role: role ?? this.role,
      name: name ?? this.name,
      company: company ?? this.company,
      companyEmail: companyEmail ?? this.companyEmail,
      companyPosition: companyPosition ?? this.companyPosition,
      companyPhoneNumber: companyPhoneNumber ?? this.companyPhoneNumber,
      dtiOrSecRegistration: dtiOrSecRegistration ?? this.dtiOrSecRegistration,
      barangayClearance: barangayClearance ?? this.barangayClearance,
      businessPermit: businessPermit ?? this.businessPermit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployerModel && other.employerId == employerId;
  }

  @override
  int get hashCode => employerId.hashCode;
}