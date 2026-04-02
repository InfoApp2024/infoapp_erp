// lib/pages/staff/models/staff_model.dart

import '../domain/staff_domain.dart';

/// Modelo de empleado (implementación concreta de Staff)
class StaffModel extends Staff {
  @override
  final String id;
  @override
  final String staffCode;
  @override
  final String firstName;
  @override
  final String lastName;
  @override
  final String email;
  @override
  final String? phone;
  @override
  final String positionId;
  @override
  final String departmentId;
  @override
  final String? especialidadId;
  @override
  final DateTime hireDate;
  final DateTime? birthDate;
  @override
  final IdentificationType identificationType;
  @override
  final String identificationNumber;
  @override
  final String? photoUrl;
  @override
  final bool isActive;
  @override
  final double? salary;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  // Campos adicionales opcionales
  final String? departmentName;
  final String? positionTitle;
  final String? especialidadNombre;
  final String? createdByName;
  final String? updatedByName;

  StaffModel({
    required this.id,
    required this.staffCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.positionId,
    required this.departmentId,
    DateTime? hireDate, // ✅ CAMBIADO: Ya no required
    this.birthDate,
    required this.identificationType,
    required this.identificationNumber,
    this.photoUrl,
    this.isActive = true,
    this.salary,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    required this.createdAt,
    required this.updatedAt,
    this.departmentName,
    this.positionTitle,
    this.especialidadId,
    this.especialidadNombre,
    this.createdByName,
    this.updatedByName,
  }) : hireDate = hireDate ?? DateTime.now(); //

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id']?.toString() ?? '',
      staffCode: json['staff_code'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      positionId: json['position_id']?.toString() ?? '',
      departmentId: json['department_id']?.toString() ?? '',
      especialidadId: json['id_especialidad']?.toString(),
      hireDate:
          json['hire_date'] != null
              ? DateTime.parse(json['hire_date'])
              : DateTime.now(),
      birthDate:
          json['birth_date'] != null
              ? DateTime.parse(json['birth_date'])
              : null,
      identificationType: IdentificationType.values.firstWhere(
        (e) => e.name == json['identification_type'],
        orElse: () => IdentificationType.dni,
      ),
      identificationNumber: json['identification_number'] ?? '',
      photoUrl: json['photo_url'],
      isActive: json['is_active'] ?? true,
      salary: json['salary']?.toDouble(),
      address: json['address'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      departmentName: json['department_name'],
      positionTitle: json['position_title'],
      createdByName: json['created_by_name'],
      updatedByName: json['updated_by_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_code': staffCode,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'position_id': positionId,
      'department_id': departmentId,
      'id_especialidad': especialidadId,
      'hire_date': hireDate.toIso8601String().split('T')[0],
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'identification_type': identificationType.name,
      'identification_number': identificationNumber,
      'photo_url': photoUrl,
      'is_active': isActive,
      'salary': salary,
      'address': address,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'department_name': departmentName,
      'position_title': positionTitle,
      'created_by_name': createdByName,
      'updated_by_name': updatedByName,
    };
  }

  StaffModel copyWith({
    String? id,
    String? staffCode,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? positionId,
    String? departmentId,
    String? especialidadId,
    DateTime? hireDate,
    DateTime? birthDate,
    IdentificationType? identificationType,
    String? identificationNumber,
    String? photoUrl,
    bool? isActive,
    double? salary,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? departmentName,
    String? positionTitle,
    String? createdByName,
    String? updatedByName,
  }) {
    return StaffModel(
      id: id ?? this.id,
      staffCode: staffCode ?? this.staffCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      positionId: positionId ?? this.positionId,
      departmentId: departmentId ?? this.departmentId,
      especialidadId: especialidadId ?? this.especialidadId,
      hireDate: hireDate ?? this.hireDate,
      birthDate: birthDate ?? this.birthDate,
      identificationType: identificationType ?? this.identificationType,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      salary: salary ?? this.salary,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      departmentName: departmentName ?? this.departmentName,
      positionTitle: positionTitle ?? this.positionTitle,
      createdByName: createdByName ?? this.createdByName,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }

  // Campos calculados
  @override
  String get fullName => '$firstName $lastName';

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    final age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      return age - 1;
    }
    return age;
  }

  int get yearsEmployed {
    final now = DateTime.now();
    final years = now.year - hireDate.year;
    if (now.month < hireDate.month ||
        (now.month == hireDate.month && now.day < hireDate.day)) {
      return years - 1;
    }
    return years;
  }

  int get monthsEmployed {
    final now = DateTime.now();
    return ((now.year - hireDate.year) * 12) + (now.month - hireDate.month);
  }

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;
  bool get hasEmergencyContact =>
      emergencyContactName != null && emergencyContactName!.isNotEmpty;
  bool get hasAddress => address != null && address!.isNotEmpty;
  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasSalary => salary != null && salary! > 0;

  double get profileCompletion {
    int completedFields = 0;
    int totalFields = 13; // Total de campos importantes

    // Campos requeridos (siempre presentes)
    completedFields +=
        6; // firstName, lastName, email, departmentId, positionId, identificationNumber

    // Campos opcionales
    if (hasPhone) completedFields++;
    if (hasAddress) completedFields++;
    if (hasPhoto) completedFields++;
    if (hasEmergencyContact) completedFields++;
    if (hasSalary) completedFields++;
    if (birthDate != null) completedFields++;
    if (emergencyContactPhone != null && emergencyContactPhone!.isNotEmpty) {
      completedFields++;
    }

    return (completedFields / totalFields) * 100;
  }

  String get statusDisplayText => isActive ? 'Activo' : 'Inactivo';

  String get experienceLevel {
    final years = yearsEmployed;
    if (years < 1) return 'Nuevo';
    if (years < 3) return 'Junior';
    if (years < 7) return 'Senior';
    return 'Veterano';
  }
}

/// Modelo de departamento
class DepartmentModel extends Department {
  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  final String? managerId;
  final String? managerName;
  final String? managerEmail;
  @override
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasManager;
  final int totalEmployees;
  final int activeEmployees;
  final int inactiveEmployees;

  DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    this.managerId,
    this.managerName,
    this.managerEmail,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.hasManager = false,
    this.totalEmployees = 0,
    this.activeEmployees = 0,
    this.inactiveEmployees = 0,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      managerId: json['manager_id']?.toString(),
      managerName: json['manager_name'],
      managerEmail: json['manager_email'],
      isActive: json['is_active'] ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      hasManager: json['has_manager'] ?? false,
      totalEmployees: json['total_employees'] ?? 0,
      activeEmployees: json['active_employees'] ?? 0,
      inactiveEmployees: json['inactive_employees'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'manager_id': managerId,
      'manager_name': managerName,
      'manager_email': managerEmail,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'has_manager': hasManager,
      'total_employees': totalEmployees,
      'active_employees': activeEmployees,
      'inactive_employees': inactiveEmployees,
    };
  }

  String get displayText {
    if (managerName != null) {
      return '$name (Manager: $managerName)';
    }
    return name;
  }

  bool get canBeDeleted => activeEmployees == 0;
}

/// Modelo de posición
class PositionModel extends Position {
  @override
  final String id;
  @override
  final String title;
  final String? description;
  @override
  final String departmentId;
  final String? departmentName;
  final double? minSalary;
  final double? maxSalary;
  @override
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasSalaryRange;
  final String? salaryRangeText;
  final int totalEmployees;
  final int activeEmployees;
  final int inactiveEmployees;

  PositionModel({
    required this.id,
    required this.title,
    this.description,
    required this.departmentId,
    this.departmentName,
    this.minSalary,
    this.maxSalary,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.hasSalaryRange = false,
    this.salaryRangeText,
    this.totalEmployees = 0,
    this.activeEmployees = 0,
    this.inactiveEmployees = 0,
  });

  factory PositionModel.fromJson(Map<String, dynamic> json) {
    return PositionModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      departmentId: json['department_id']?.toString() ?? '',
      departmentName: json['department_name'],
      minSalary: json['min_salary']?.toDouble(),
      maxSalary: json['max_salary']?.toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
      hasSalaryRange: json['has_salary_range'] ?? false,
      salaryRangeText: json['salary_range_text'],
      totalEmployees: json['total_employees'] ?? 0,
      activeEmployees: json['active_employees'] ?? 0,
      inactiveEmployees: json['inactive_employees'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'department_id': departmentId,
      'department_name': departmentName,
      'min_salary': minSalary,
      'max_salary': maxSalary,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'has_salary_range': hasSalaryRange,
      'salary_range_text': salaryRangeText,
      'total_employees': totalEmployees,
      'active_employees': activeEmployees,
      'inactive_employees': inactiveEmployees,
    };
  }

  String get displayText {
    if (departmentName != null) {
      return '$title ($departmentName)';
    }
    return title;
  }

  String get fullDisplayText {
    final buffer = StringBuffer(title);

    if (departmentName != null) {
      buffer.write(' - $departmentName');
    }

    if (salaryRangeText != null) {
      buffer.write(' ($salaryRangeText)');
    }

    return buffer.toString();
  }

  bool get canBeDeleted => activeEmployees == 0;
}
