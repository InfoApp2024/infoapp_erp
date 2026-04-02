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

// ✅ REPOSITORY INTERFACES (Contracts) - CORREGIDO
abstract class StaffRepository {
  Future<List<Staff>> getStaff({
    String? search,
    bool? active,
    String? departmentId,
  });
  Future<Staff> getStaffById(String id);
  Future<Staff> createStaff(Staff staff);
  Future<Staff> updateStaff(Staff staff);
  Future<void> toggleStaffStatus(String id);
  Future<List<Department>> getDepartments();
  Future<List<Position>> getPositions({String? departmentId});
  Future<String> uploadPhoto(String imagePath);
}

// DOMAIN SERVICES
class StaffCodeGenerator {
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'STF${timestamp.toString().substring(7)}';
  }

  static bool isValid(String code) {
    return code.startsWith('STF') && code.length >= 6;
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
    } else if (!isValidEmail(staff.email)) {
      errors['email'] = 'Email inválido';
    }

    if (staff.phone != null && !isValidPhone(staff.phone!)) {
      errors['phone'] = 'Teléfono inválido';
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
    return phone.length >= 10 && RegExp(r'^\+?\d+$').hasMatch(phone);
  }
}

// BUSINESS RULES
class StaffBusinessRules {
  static bool canDeactivateStaff(Staff staff) {
    // Business logic: Can't deactivate if staff is a manager
    // This would need to check if staff manages any department
    return true; // Simplified for now
  }

  static bool canPromoteToManager(Staff staff) {
    // Business logic for promotion eligibility
    final workDuration = DateTime.now().difference(staff.hireDate);
    return workDuration.inDays >= 365; // At least 1 year of work
  }

  static double calculateYearsEmployed(Staff staff) {
    final workDuration = DateTime.now().difference(staff.hireDate);
    return workDuration.inDays / 365.25;
  }
}

// VALUE OBJECTS
class PhoneNumber {
  final String value;

  PhoneNumber(this.value) {
    if (!StaffValidator.isValidPhone(value)) {
      throw ArgumentError('Invalid phone number format');
    }
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneNumber &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class Email {
  final String value;

  Email(this.value) {
    if (!StaffValidator.isValidEmail(value)) {
      throw ArgumentError('Invalid email format');
    }
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Email &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

// EXTENSIONS
extension IdentificationTypeExtension on IdentificationType {
  String get shortCode {
    switch (this) {
      case IdentificationType.dni:
        return 'DNI';
      case IdentificationType.cedula:
        return 'CC';
      case IdentificationType.passport:
        return 'PP';
    }
  }
}

extension StaffExtension on Staff {
  int get age {
    // This would require birthDate, which is only available in StaffModel
    // Return 0 as default for the abstract Staff
    return 0;
  }

  double get yearsEmployed => StaffBusinessRules.calculateYearsEmployed(this);

  String get displayName => '$firstName $lastName';

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

  bool get isNewEmployee => yearsEmployed < 1.0;

  bool get isVeteran => yearsEmployed > 5.0;
}

// UTILITIES
class StaffUtils {
  static String formatFullName(String firstName, String lastName) {
    return '$firstName $lastName'.trim();
  }

  static String generateDisplayCode(String staffCode) {
    return staffCode.toUpperCase();
  }

  static String maskIdentification(String identification) {
    if (identification.length <= 4) return identification;
    final visible = identification.substring(identification.length - 4);
    final masked = '*' * (identification.length - 4);
    return '$masked$visible';
  }

  static String formatSalary(double? salary) {
    if (salary == null) return 'No especificado';
    return '\$${salary.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
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
  static const int minAge = 16;
  static const int maxAge = 100;
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
