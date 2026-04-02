// =====================================================
// DOMAIN LAYER - Business Logic & Entities
// =====================================================
import 'package:infoapp/core/env/server_config.dart';

// ENTITIES (Business Objects)
abstract class Staff {
  String get id;
  String get staffCode;
  String get firstName;
  String get lastName;
  String get email;
  String? get phone;
  String get positionId;
  String get departmentId;
  String? get especialidadId;
  DateTime get hireDate;
  IdentificationType get identificationType;
  String get identificationNumber;
  String? get photoUrl;
  bool get isActive;
  double? get salary;
  DateTime get createdAt;
  DateTime get updatedAt;

  String get fullName => '$firstName $lastName';
}

abstract class Department {
  String get id;
  String get name;
  String? get description;
  bool get isActive;
}

abstract class Position {
  String get id;
  String get title;
  String get departmentId;
  bool get isActive;
}

// ENUMS & VALUE OBJECTS
enum IdentificationType {
  dni('DNI'),
  passport('Pasaporte'),
  cedula('Cédula');

  const IdentificationType(this.displayName);
  final String displayName;
}

enum StaffStatus {
  active('Activo'),
  inactive('Inactivo');

  const StaffStatus(this.displayName);
  final String displayName;
}

enum GenderType {
  male('Masculino'),
  female('Femenino'),
  other('Otro');

  const GenderType(this.displayName);
  final String displayName;
}

// DOMAIN SERVICES
class StaffCodeGenerator {
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'STF${timestamp.toString().substring(7)}';
  }

  static bool isValid(String code) {
    return RegExp(r'^STF\d{6,}$').hasMatch(code);
  }
}

class StaffValidator {
  static Map<String, String?> validate(Staff staff) {
    final errors = <String, String?>{};

    if (staff.firstName.isEmpty) {
      errors['firstName'] = 'Nombre requerido';
    }

    if (staff.lastName.isEmpty) {
      errors['lastName'] = 'Apellido requerido';
    }

    if (staff.email.isEmpty) {
      errors['email'] = 'Email requerido';
    } else if (!staff.email.contains('@')) {
      errors['email'] = 'Email inválido';
    }

    if (staff.phone != null && staff.phone!.length < 10) {
      errors['phone'] = 'Teléfono debe tener al menos 10 dígitos';
    }

    if (staff.identificationNumber.isEmpty) {
      errors['identificationNumber'] = 'Número de documento requerido';
    }

    if (staff.positionId.isEmpty) {
      errors['positionId'] = 'Cargo requerido';
    }

    if (staff.departmentId.isEmpty) {
      errors['departmentId'] = 'Departamento requerido';
    }

    return errors;
  }

  static bool isValid(Staff staff) {
    final errors = validate(staff);
    return errors.values.every((error) => error == null);
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }
}

// CONSTANTS
class StaffConstants {
  static const String defaultPhotoUrl = 'assets/images/default_avatar.png';
  static const int maxPhotoSizeKB = 2048;
  static const List<String> allowedImageFormats = ['jpg', 'jpeg', 'png'];
  static const int staffCodeLength = 6;
  static String get apiBaseUrl => ServerConfig.instance.baseUrlFor('staff');

  // Validation Rules
  static const int minPhoneLength = 10;
  static const int maxNameLength = 100;
  static const int maxEmailLength = 150;
  static const int maxAddressLength = 500;

  // Department related
  static const int maxDepartmentNameLength = 100;
  static const int maxDepartmentDescriptionLength = 500;

  // Position related
  static const int maxPositionTitleLength = 100;
  static const int maxPositionDescriptionLength = 500;
}

// EXCEPTIONS
class StaffDomainException implements Exception {
  final String message;
  final String? code;

  StaffDomainException(this.message, {this.code});

  @override
  String toString() => 'StaffDomainException: $message';
}

class StaffValidationException extends StaffDomainException {
  final Map<String, String> errors;

  StaffValidationException(this.errors)
    : super('Errores de validación encontrados', code: 'VALIDATION_ERROR');
}

class StaffNotFoundException extends StaffDomainException {
  StaffNotFoundException(String staffId)
    : super('Empleado con ID $staffId no encontrado', code: 'STAFF_NOT_FOUND');
}

class DuplicateStaffException extends StaffDomainException {
  DuplicateStaffException(String field, String value)
    : super(
        'Ya existe un empleado con $field: $value',
        code: 'DUPLICATE_STAFF',
      );
}

class DepartmentNotFoundException extends StaffDomainException {
  DepartmentNotFoundException(String departmentId)
    : super(
        'Departamento con ID $departmentId no encontrado',
        code: 'DEPARTMENT_NOT_FOUND',
      );
}

class PositionNotFoundException extends StaffDomainException {
  PositionNotFoundException(String positionId)
    : super(
        'Posición con ID $positionId no encontrada',
        code: 'POSITION_NOT_FOUND',
      );
}

// UTILITY CLASSES
class StaffUtils {
  static String formatSalary(double? salary) {
    if (salary == null) return 'No especificado';
    return '\$${salary.toStringAsFixed(2)}';
  }

  static String formatFullName(String firstName, String lastName) {
    return '$firstName $lastName'.trim();
  }

  static String formatExperience(DateTime hireDate) {
    final now = DateTime.now();
    final years = now.year - hireDate.year;
    final months = now.month - hireDate.month;

    if (years == 0) {
      return '$months meses';
    } else if (months == 0) {
      return '$years años';
    } else {
      return '$years años y $months meses';
    }
  }

  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static bool isValidAge(
    DateTime birthDate, {
    int minAge = 16,
    int maxAge = 100,
  }) {
    final age = calculateAge(birthDate);
    return age >= minAge && age <= maxAge;
  }
}

// VALUE OBJECTS
class PhoneNumber {
  final String value;

  PhoneNumber._(this.value);

  factory PhoneNumber.create(String phone) {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) {
      throw StaffValidationException({
        'phone': 'Teléfono no puede estar vacío',
      });
    }
    if (!StaffValidator.isValidPhone(cleaned)) {
      throw StaffValidationException({'phone': 'Formato de teléfono inválido'});
    }
    return PhoneNumber._(cleaned);
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhoneNumber && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class Email {
  final String value;

  Email._(this.value);

  factory Email.create(String email) {
    final cleaned = email.trim().toLowerCase();
    if (cleaned.isEmpty) {
      throw StaffValidationException({'email': 'Email no puede estar vacío'});
    }
    if (!StaffValidator.isValidEmail(cleaned)) {
      throw StaffValidationException({'email': 'Formato de email inválido'});
    }
    return Email._(cleaned);
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Email && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

// ENUMS EXTENSIONS
extension IdentificationTypeExtension on IdentificationType {
  String get code {
    switch (this) {
      case IdentificationType.dni:
        return 'DNI';
      case IdentificationType.cedula:
        return 'CC';
      case IdentificationType.passport:
        return 'PP';
    }
  }

  bool get requiresNationality {
    return this == IdentificationType.passport;
  }

  int get minLength {
    switch (this) {
      case IdentificationType.dni:
        return 8;
      case IdentificationType.cedula:
        return 6;
      case IdentificationType.passport:
        return 6;
    }
  }

  int get maxLength {
    switch (this) {
      case IdentificationType.dni:
        return 8;
      case IdentificationType.cedula:
        return 12;
      case IdentificationType.passport:
        return 20;
    }
  }
}

extension StaffStatusExtension on StaffStatus {
  bool get isActive => this == StaffStatus.active;
  bool get isInactive => this == StaffStatus.inactive;
}

// BUSINESS RULES
class StaffBusinessRules {
  static bool canBeDeactivated(Staff staff) {
    // Aquí puedes agregar reglas de negocio específicas
    // Por ejemplo, si el empleado es manager de un departamento
    return staff.isActive;
  }

  static bool canBeReactivated(Staff staff) {
    return !staff.isActive;
  }

  static bool canUpdateSalary(Staff staff, double newSalary) {
    // Regla de negocio: no se puede reducir el salario más del 20%
    if (staff.salary == null) return true;
    final reduction = (staff.salary! - newSalary) / staff.salary!;
    return reduction <= 0.20;
  }

  static bool canChangeDepartment(Staff staff, String newDepartmentId) {
    // Regla de negocio: agregar validaciones específicas si es necesario
    return staff.departmentId != newDepartmentId;
  }

  static Duration get minimumEmploymentPeriod => const Duration(days: 90);

  static bool canTerminate(Staff staff) {
    final employmentDuration = DateTime.now().difference(staff.hireDate);
    return employmentDuration >= minimumEmploymentPeriod;
  }
}
