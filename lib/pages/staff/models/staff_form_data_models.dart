// lib/pages/staff/models/staff_form_data_models.dart

import '../domain/staff_domain.dart';

/// Datos del formulario de empleado
class StaffFormData {
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String departmentId;
  final String positionId;
  final DateTime hireDate;
  final IdentificationType identificationType;
  final String identificationNumber;
  final String? photoUrl;
  final bool isActive;
  final double? salary;
  final DateTime? birthDate;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const StaffFormData({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.departmentId,
    required this.positionId,
    required this.hireDate,
    required this.identificationType,
    required this.identificationNumber,
    this.photoUrl,
    this.isActive = true,
    this.salary,
    this.birthDate,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory StaffFormData.fromJson(Map<String, dynamic> json) {
    return StaffFormData(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      departmentId: json['department_id']?.toString() ?? '',
      positionId: json['position_id']?.toString() ?? '',
      hireDate:
          json['hire_date'] != null
              ? DateTime.parse(json['hire_date'])
              : DateTime.now(),
      identificationType: IdentificationType.values.firstWhere(
        (e) => e.name == json['identification_type'],
        orElse: () => IdentificationType.dni,
      ),
      identificationNumber: json['identification_number'] ?? '',
      photoUrl: json['photo_url'],
      isActive: json['is_active'] ?? true,
      salary: json['salary']?.toDouble(),
      birthDate:
          json['birth_date'] != null
              ? DateTime.parse(json['birth_date'])
              : null,
      address: json['address'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
    );
  }

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'department_id': departmentId,
    'position_id': positionId,
    'hire_date': hireDate.toIso8601String().split('T')[0],
    'identification_type': identificationType.name,
    'identification_number': identificationNumber,
    'photo_url': photoUrl,
    'is_active': isActive,
    'salary': salary,
    'birth_date': birthDate?.toIso8601String().split('T')[0],
    'address': address,
    'emergency_contact_name': emergencyContactName,
    'emergency_contact_phone': emergencyContactPhone,
  };

  StaffFormData copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? departmentId,
    String? positionId,
    DateTime? hireDate,
    IdentificationType? identificationType,
    String? identificationNumber,
    String? photoUrl,
    bool? isActive,
    double? salary,
    DateTime? birthDate,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return StaffFormData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      departmentId: departmentId ?? this.departmentId,
      positionId: positionId ?? this.positionId,
      hireDate: hireDate ?? this.hireDate,
      identificationType: identificationType ?? this.identificationType,
      identificationNumber: identificationNumber ?? this.identificationNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      salary: salary ?? this.salary,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }
}

/// Datos del formulario de departamento
class DepartmentFormData {
  final String name;
  final String? description;
  final String? managerId;
  final bool isActive;

  const DepartmentFormData({
    required this.name,
    this.description,
    this.managerId,
    this.isActive = true,
  });

  factory DepartmentFormData.fromJson(Map<String, dynamic> json) {
    return DepartmentFormData(
      name: json['name'] ?? '',
      description: json['description'],
      managerId: json['manager_id']?.toString(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'manager_id': managerId,
    'is_active': isActive,
  };

  DepartmentFormData copyWith({
    String? name,
    String? description,
    String? managerId,
    bool? isActive,
  }) {
    return DepartmentFormData(
      name: name ?? this.name,
      description: description ?? this.description,
      managerId: managerId ?? this.managerId,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Datos del formulario de posición
class PositionFormData {
  final String title;
  final String? description;
  final String departmentId;
  final double? minSalary;
  final double? maxSalary;
  final bool isActive;

  const PositionFormData({
    required this.title,
    this.description,
    required this.departmentId,
    this.minSalary,
    this.maxSalary,
    this.isActive = true,
  });

  factory PositionFormData.fromJson(Map<String, dynamic> json) {
    return PositionFormData(
      title: json['title'] ?? '',
      description: json['description'],
      departmentId: json['department_id']?.toString() ?? '',
      minSalary: json['min_salary']?.toDouble(),
      maxSalary: json['max_salary']?.toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'department_id': departmentId,
    'min_salary': minSalary,
    'max_salary': maxSalary,
    'is_active': isActive,
  };

  PositionFormData copyWith({
    String? title,
    String? description,
    String? departmentId,
    double? minSalary,
    double? maxSalary,
    bool? isActive,
  }) {
    return PositionFormData(
      title: title ?? this.title,
      description: description ?? this.description,
      departmentId: departmentId ?? this.departmentId,
      minSalary: minSalary ?? this.minSalary,
      maxSalary: maxSalary ?? this.maxSalary,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Validación de formularios
class FormValidation {
  final bool isValid;
  final Map<String, String> errors;

  const FormValidation({required this.isValid, required this.errors});

  factory FormValidation.valid() {
    return const FormValidation(isValid: true, errors: {});
  }

  factory FormValidation.invalid(Map<String, String> errors) {
    return FormValidation(isValid: false, errors: errors);
  }

  String? getError(String field) => errors[field];
  bool hasError(String field) => errors.containsKey(field);
  List<String> get allErrors => errors.values.toList();
}

/// Validador de formulario de empleado
class StaffFormValidator {
  static FormValidation validate(StaffFormData data) {
    final errors = <String, String>{};

    // Validar nombre
    if (data.firstName.trim().isEmpty) {
      errors['firstName'] = 'El nombre es requerido';
    } else if (data.firstName.trim().length < 2) {
      errors['firstName'] = 'El nombre debe tener al menos 2 caracteres';
    }

    // Validar apellido
    if (data.lastName.trim().isEmpty) {
      errors['lastName'] = 'El apellido es requerido';
    } else if (data.lastName.trim().length < 2) {
      errors['lastName'] = 'El apellido debe tener al menos 2 caracteres';
    }

    // Validar email
    if (data.email.trim().isEmpty) {
      errors['email'] = 'El email es requerido';
    } else if (!_isValidEmail(data.email)) {
      errors['email'] = 'El formato del email no es válido';
    }

    // Validar teléfono (opcional)
    if (data.phone != null && data.phone!.isNotEmpty) {
      if (!_isValidPhone(data.phone!)) {
        errors['phone'] = 'El formato del teléfono no es válido';
      }
    }

    // Validar departamento
    if (data.departmentId.trim().isEmpty) {
      errors['departmentId'] = 'El departamento es requerido';
    }

    // Validar posición
    if (data.positionId.trim().isEmpty) {
      errors['positionId'] = 'El cargo es requerido';
    }

    // Validar número de identificación
    if (data.identificationNumber.trim().isEmpty) {
      errors['identificationNumber'] = 'El número de documento es requerido';
    } else if (data.identificationNumber.trim().length < 6) {
      errors['identificationNumber'] =
          'El número de documento debe tener al menos 6 caracteres';
    }

    // Validar fecha de contratación
    final today = DateTime.now();
    if (data.hireDate.isAfter(today)) {
      errors['hireDate'] = 'La fecha de contratación no puede ser futura';
    }

    // Validar fecha de nacimiento (opcional)
    if (data.birthDate != null) {
      if (data.birthDate!.isAfter(today)) {
        errors['birthDate'] = 'La fecha de nacimiento no puede ser futura';
      } else {
        final age = today.difference(data.birthDate!).inDays ~/ 365;
        if (age < 16) {
          errors['birthDate'] = 'El empleado debe tener al menos 16 años';
        } else if (age > 100) {
          errors['birthDate'] = 'La fecha de nacimiento no es válida';
        }
      }
    }

    // Validar salario (opcional)
    if (data.salary != null && data.salary! < 0) {
      errors['salary'] = 'El salario no puede ser negativo';
    }

    return errors.isEmpty
        ? FormValidation.valid()
        : FormValidation.invalid(errors);
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }
}

/// Validador de formulario de departamento
class DepartmentFormValidator {
  static FormValidation validate(DepartmentFormData data) {
    final errors = <String, String>{};

    // Validar nombre
    if (data.name.trim().isEmpty) {
      errors['name'] = 'El nombre del departamento es requerido';
    } else if (data.name.trim().length < 2) {
      errors['name'] = 'El nombre debe tener al menos 2 caracteres';
    }

    // Validar descripción (opcional, pero si se proporciona, debe tener contenido)
    if (data.description != null && data.description!.trim().isNotEmpty) {
      if (data.description!.trim().length < 5) {
        errors['description'] =
            'La descripción debe tener al menos 5 caracteres';
      }
    }

    return errors.isEmpty
        ? FormValidation.valid()
        : FormValidation.invalid(errors);
  }
}

/// Validador de formulario de posición
class PositionFormValidator {
  static FormValidation validate(PositionFormData data) {
    final errors = <String, String>{};

    // Validar título
    if (data.title.trim().isEmpty) {
      errors['title'] = 'El título del cargo es requerido';
    } else if (data.title.trim().length < 2) {
      errors['title'] = 'El título debe tener al menos 2 caracteres';
    }

    // Validar departamento
    if (data.departmentId.trim().isEmpty) {
      errors['departmentId'] = 'El departamento es requerido';
    }

    // Validar rango salarial
    if (data.minSalary != null && data.minSalary! < 0) {
      errors['minSalary'] = 'El salario mínimo no puede ser negativo';
    }

    if (data.maxSalary != null && data.maxSalary! < 0) {
      errors['maxSalary'] = 'El salario máximo no puede ser negativo';
    }

    if (data.minSalary != null && data.maxSalary != null) {
      if (data.minSalary! > data.maxSalary!) {
        errors['maxSalary'] =
            'El salario máximo debe ser mayor al salario mínimo';
      }
    }

    return errors.isEmpty
        ? FormValidation.valid()
        : FormValidation.invalid(errors);
  }
}
