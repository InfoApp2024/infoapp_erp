// =====================================================
// STAFF SERVICES - PARTE 1: Clases auxiliares y configuración base
// =====================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/core/env/server_config.dart';

// ✅ IMPORTS CORREGIDOS
import '../domain/staff_domain.dart';
import '../models/staff_model.dart';
import '../models/staff_response_models.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

// ===== CLASES AUXILIARES =====

/// Clase genérica para respuestas de la API
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
  });

  factory ApiResponse.success(T data, [String? message]) {
    return ApiResponse(
      success: true,
      data: data,
      message: message ?? 'Operación exitosa',
    );
  }

  factory ApiResponse.error(String message, {Map<String, dynamic>? errors}) {
    return ApiResponse(success: false, message: message, errors: errors);
  }

  bool get hasErrors => errors != null && errors!.isNotEmpty;

  List<String> get errorMessages {
    if (!hasErrors) return [];
    return errors!.values.whereType<String>().cast<String>().toList();
  }

  bool get isConflict => errors != null && errors!['conflict'] == true;

  Map<String, dynamic>? get conflictData =>
      isConflict ? errors!['dependencies'] : null;
}

/// Opciones de importación para empleados
class StaffImportOptions {
  final bool updateExisting;
  final bool createDepartments;
  final bool createPositions;
  final String dateFormat;
  final String encoding;
  final bool skipFirstRow;

  const StaffImportOptions({
    this.updateExisting = false,
    this.createDepartments = true,
    this.createPositions = true,
    this.dateFormat = 'yyyy-MM-dd',
    this.encoding = 'utf-8',
    this.skipFirstRow = true,
  });

  Map<String, dynamic> toJson() => {
    'update_existing': updateExisting,
    'create_departments': createDepartments,
    'create_positions': createPositions,
    'date_format': dateFormat,
    'encoding': encoding,
    'skip_first_row': skipFirstRow,
  };
}

/// Resultado de importación de empleados
class StaffImportResult {
  final int totalFilas;
  final int procesadas;
  final int insertados;
  final int actualizados;
  final int errores;
  final List<String> erroresDetalle;
  final List<StaffModel> importedStaff;

  const StaffImportResult({
    this.totalFilas = 0,
    this.procesadas = 0,
    this.insertados = 0,
    this.actualizados = 0,
    this.errores = 0,
    this.erroresDetalle = const [],
    this.importedStaff = const [],
  });

  double get successRate =>
      totalFilas > 0 ? (insertados + actualizados) / totalFilas : 0.0;

  bool get hasErrors => errores > 0;

  factory StaffImportResult.fromJson(Map<String, dynamic> json) {
    return StaffImportResult(
      totalFilas: json['total_filas'] ?? 0,
      procesadas: json['procesadas'] ?? 0,
      insertados: json['insertados'] ?? 0,
      actualizados: json['actualizados'] ?? 0,
      errores: json['errores'] ?? 0,
      erroresDetalle: List<String>.from(json['errores_detalle'] ?? []),
    );
  }
}

/// Opciones de eliminación de empleados
class StaffDeleteOptions {
  final bool softDelete;
  final bool force;
  final String? reason;
  final int? transferDepartmentsTo;

  const StaffDeleteOptions({
    this.softDelete = true,
    this.force = false,
    this.reason,
    this.transferDepartmentsTo,
  });

  Map<String, dynamic> toJson() => {
    'soft_delete': softDelete,
    'force': force,
    if (reason != null) 'reason': reason,
    if (transferDepartmentsTo != null)
      'transfer_departments_to': transferDepartmentsTo,
  };
}

/// Estadísticas del empleado
class StaffStats {
  final int departmentsManaged;
  final int totalMovementsCreated;
  final int totalItemsCreated;
  final DateTime? lastLogin;
  final double profileCompletion;

  const StaffStats({
    this.departmentsManaged = 0,
    this.totalMovementsCreated = 0,
    this.totalItemsCreated = 0,
    this.lastLogin,
    this.profileCompletion = 0.0,
  });

  factory StaffStats.fromJson(Map<String, dynamic> json) {
    return StaffStats(
      departmentsManaged: json['departments_managed'] ?? 0,
      totalMovementsCreated: json['total_movements_created'] ?? 0,
      totalItemsCreated: json['total_items_created'] ?? 0,
      lastLogin:
          json['last_login'] != null
              ? DateTime.tryParse(json['last_login'])
              : null,
      profileCompletion: (json['profile_completion'] ?? 0.0).toDouble(),
    );
  }
}

/// Relaciones del empleado (colegas, subordinados)
class StaffRelations {
  final List<StaffModel> colleagues;
  final List<StaffModel> subordinates;
  final StaffModel? manager;

  const StaffRelations({
    this.colleagues = const [],
    this.subordinates = const [],
    this.manager,
  });

  factory StaffRelations.fromJson(Map<String, dynamic> json) {
    return StaffRelations(
      colleagues:
          json['colleagues'] != null
              ? (json['colleagues'] as List)
                  .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
                  .toList()
              : [],
      subordinates:
          json['subordinates'] != null
              ? (json['subordinates'] as List)
                  .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
                  .toList()
              : [],
      manager:
          json['manager'] != null
              ? StaffModel.fromJson(json['manager'] as Map<String, dynamic>)
              : null,
    );
  }
}

/// Información adicional del empleado
class StaffAdditionalInfo {
  final bool canBeDeleted;
  final bool requiresSalaryReview;
  final bool profileIncomplete;
  final bool isNewEmployee;
  final bool isVeteran;
  final int? lastUpdatedDaysAgo;

  const StaffAdditionalInfo({
    this.canBeDeleted = true,
    this.requiresSalaryReview = false,
    this.profileIncomplete = false,
    this.isNewEmployee = false,
    this.isVeteran = false,
    this.lastUpdatedDaysAgo,
  });

  factory StaffAdditionalInfo.fromJson(Map<String, dynamic> json) {
    return StaffAdditionalInfo(
      canBeDeleted: json['can_be_deleted'] ?? true,
      requiresSalaryReview: json['requires_salary_review'] ?? false,
      profileIncomplete: json['profile_incomplete'] ?? false,
      isNewEmployee: json['is_new_employee'] ?? false,
      isVeteran: json['is_veteran'] ?? false,
      lastUpdatedDaysAgo: json['last_updated_days_ago'],
    );
  }
}

/// Respuesta detallada del empleado
class StaffDetailResponse {
  final StaffModel staff;
  final StaffModel? manager;
  final StaffRelations? relations;
  final StaffStats? stats;
  final List<Map<String, dynamic>>? history;
  final StaffAdditionalInfo? additionalInfo;

  const StaffDetailResponse({
    required this.staff,
    this.manager,
    this.relations,
    this.stats,
    this.history,
    this.additionalInfo,
  });

  factory StaffDetailResponse.fromJson(Map<String, dynamic> json) {
    return StaffDetailResponse(
      staff: StaffModel.fromJson(json['staff'] as Map<String, dynamic>),
      manager:
          json['manager'] != null
              ? StaffModel.fromJson(json['manager'] as Map<String, dynamic>)
              : null,
      relations:
          json['relations'] != null
              ? StaffRelations.fromJson(
                json['relations'] as Map<String, dynamic>,
              )
              : null,
      stats:
          json['stats'] != null
              ? StaffStats.fromJson(json['stats'] as Map<String, dynamic>)
              : null,
      history:
          json['history'] != null
              ? List<Map<String, dynamic>>.from(json['history'])
              : null,
      additionalInfo:
          json['additional_info'] != null
              ? StaffAdditionalInfo.fromJson(
                json['additional_info'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}

/// Servicio principal para gestión de empleados
class StaffApiService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('staff');
  static const Duration _timeout = Duration(seconds: 30);

  // ===== CONFIGURACIÓN Y MÉTODOS AUXILIARES =====

  /// Headers por defecto
  static Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Obtiene el usuario_id desde SharedPreferences
  static Future<int?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('usuario_id');
    } catch (e) {
      //       print('Error obteniendo usuario_id: $e');
      return null;
    }
  }

  /// Obtiene headers con usuario si está disponible
  static Future<Map<String, String>> _getHeadersWithUser() async {
    final userId = await _getCurrentUserId();
    final token = await AuthService.getBearerToken();
    final headers = Map<String, String>.from(_defaultHeaders);

    if (userId != null) {
      headers['User-ID'] = userId.toString();
    }

    if (token != null) {
      headers['Authorization'] = token;
    }

    return headers;
  }

  /// Maneja las respuestas de la API de forma consistente
  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
  ) {
    try {
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode})',
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data['success'] == true) {
          return ApiResponse.success(
            parser(data),
            data['message'] ?? 'Operación exitosa',
          );
        } else {
          return ApiResponse.error(
            data['message'] ?? 'Error desconocido',
            errors: data['errors'],
          );
        }
      } else if (response.statusCode == 409) {
        // Manejar conflictos específicamente (para eliminaciones con dependencias)
        return ApiResponse.error(
          data['message'] ?? 'Conflicto en la operación',
          errors: data['errors'],
        );
      } else {
        return ApiResponse.error(
          'Error HTTP ${response.statusCode}: ${data['message'] ?? 'Error desconocido'}',
          errors: data['errors'],
        );
      }
    } catch (e) {
      return ApiResponse.error('Error al procesar respuesta: ${e.toString()}');
    }
  }

  /// Valida los datos del empleado antes de enviar
  static Map<String, String> _validateStaffData(StaffModel staff) {
    final errors = <String, String>{};

    // Campos requeridos
    if (staff.firstName.trim().isEmpty) {
      errors['first_name'] = 'Nombre es requerido';
    }

    if (staff.lastName.trim().isEmpty) {
      errors['last_name'] = 'Apellido es requerido';
    }

    if (staff.email.trim().isEmpty) {
      errors['email'] = 'Email es requerido';
    } else if (!_isValidEmail(staff.email)) {
      errors['email'] = 'Formato de email inválido';
    }

    if (staff.identificationNumber.trim().isEmpty) {
      errors['identification_number'] = 'Número de documento es requerido';
    } else if (staff.identificationNumber.trim().length < 6) {
      errors['identification_number'] =
          'Número de documento debe tener al menos 6 caracteres';
    }

    if (staff.departmentId.trim().isEmpty) {
      errors['department_id'] = 'Departamento es requerido';
    }

    if (staff.positionId.trim().isEmpty) {
      errors['position_id'] = 'Cargo es requerido';
    }

    // Validar especialidad (opcional o requerida según lógica de negocio)
    // Si se requiere para todos, descomentar:
    // if (staff.especialidadId != null && staff.especialidadId!.isEmpty) {
    //   errors['id_especialidad'] = 'Especialidad es requerida';
    // }

    // Validaciones opcionales
    if (staff.phone != null &&
        staff.phone!.isNotEmpty &&
        !_isValidPhone(staff.phone!)) {
      errors['phone'] = 'Formato de teléfono inválido';
    }

    if (staff.salary != null && staff.salary! < 0) {
      errors['salary'] = 'Salario no puede ser negativo';
    }

    // Validar fecha de contratación
    final today = DateTime.now();
    if (staff.hireDate.isAfter(today)) {
      errors['hire_date'] = 'Fecha de contratación no puede ser futura';
    }

    return errors;
  }

  /// Validaciones de formato
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(phone);
  }


  /// Convierte StaffModel a Map para envío a la API
  static Map<String, dynamic> _staffToApiMap(
    StaffModel staff, {
    bool includeId = false,
  }) {
    final map = <String, dynamic>{
      'first_name': staff.firstName,
      'last_name': staff.lastName,
      'email': staff.email,
      'department_id': int.tryParse(staff.departmentId) ?? 0,
      'position_id': int.tryParse(staff.positionId) ?? 0,
      'id_especialidad': int.tryParse(staff.especialidadId ?? '') ?? 0,
      'hire_date': staff.hireDate.toIso8601String().split('T')[0],
      'identification_type': staff.identificationType.name,
      'identification_number': staff.identificationNumber,
      'is_active': staff.isActive,
    };

    // Incluir ID solo para actualizaciones
    if (includeId && staff.id.isNotEmpty) {
      map['id'] = int.tryParse(staff.id) ?? 0;
    }

    // Campos opcionales
    if (staff.phone != null && staff.phone!.isNotEmpty) {
      map['phone'] = staff.phone;
    }

    if (staff.salary != null) {
      map['salary'] = staff.salary;
    }

    if (staff.birthDate != null) {
      map['birth_date'] = staff.birthDate!.toIso8601String().split('T')[0];
    }

    if (staff.address != null && staff.address!.isNotEmpty) {
      map['address'] = staff.address;
    }

    if (staff.emergencyContactName != null &&
        staff.emergencyContactName!.isNotEmpty) {
      map['emergency_contact_name'] = staff.emergencyContactName;
    }

    if (staff.emergencyContactPhone != null &&
        staff.emergencyContactPhone!.isNotEmpty) {
      map['emergency_contact_phone'] = staff.emergencyContactPhone;
    }

    if (staff.photoUrl != null && staff.photoUrl!.isNotEmpty) {
      map['photo_url'] = staff.photoUrl;
    }

    return map;
  }

  /// Maneja errores de red comunes
  static String _getNetworkErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Error de conectividad. Verifique su conexión a internet.';
    } else if (error is http.ClientException) {
      return 'Error en la solicitud. Intente nuevamente.';
    } else if (error.toString().contains('timeout')) {
      return 'Tiempo de espera agotado. Intente nuevamente.';
    } else {
      return 'Error de conexión: ${error.toString()}';
    }
  }

  // ===== CONTINUARÁ EN PARTE 2 =====

  // =====================================================
  // STAFF SERVICES - PARTE 2: Métodos CRUD principales
  // =====================================================

  // ===== CONTINUACIÓN DE LA CLASE StaffApiService =====

  // ===== GESTIÓN DE EMPLEADOS - CRUD PRINCIPAL =====

  /// Crea un nuevo empleado
  static Future<ApiResponse<StaffModel>> createStaff(StaffModel staff) async {
    try {
      //       print('📦 Creando empleado: ${staff.firstName} ${staff.lastName}');

      final uri = Uri.parse('$_baseUrl/create_staff.php');

      // Validar datos localmente antes de enviar
      final validationErrors = _validateStaffData(staff);
      if (validationErrors.isNotEmpty) {
        return ApiResponse.error(
          'Errores de validación',
          errors: validationErrors,
        );
      }

      // Obtener el usuario actual
      final userId = await _getCurrentUserId();

      // Preparar datos para envío
      final staffData = _staffToApiMap(staff);

      // Agregar usuario si está disponible
      if (userId != null) {
        staffData['created_by'] = userId;
        //         print('📦 Creando empleado con usuario: $userId');
      } else {
        //         print('⚠️ Creando empleado sin usuario (usuario no encontrado en sesión)');
      }

      //       print('📦 Enviando datos: $staffData');

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(staffData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            StaffModel.fromJson(responseData['data']['staff']),
            responseData['message'] ?? 'Empleado creado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Actualiza un empleado existente
  static Future<ApiResponse<StaffModel>> updateStaff(StaffModel staff) async {
    try {
      //       print('📝 Actualizando empleado ID: ${staff.id}');

      final uri = Uri.parse('$_baseUrl/update_staff.php');

      // Verificar que el empleado tenga ID
      if (staff.id.isEmpty) {
        return ApiResponse.error(
          'El empleado debe tener un ID para poder actualizarlo',
        );
      }

      // Validar datos localmente antes de enviar
      final validationErrors = _validateStaffData(staff);
      if (validationErrors.isNotEmpty) {
        return ApiResponse.error(
          'Errores de validación',
          errors: validationErrors,
        );
      }

      // Preparar datos para envío (incluir ID)
      final staffData = _staffToApiMap(staff, includeId: true);

      // Obtener usuario actualizador
      final userId = await _getCurrentUserId();
      if (userId != null) {
        staffData['updated_by'] = userId;
      }

      //       print('📝 Enviando datos: $staffData');

      final response = await http
          .put(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(staffData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            StaffModel.fromJson(responseData['data']['staff']),
            responseData['message'] ?? 'Empleado actualizado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Elimina o desactiva un empleado
  static Future<ApiResponse<Map<String, dynamic>>> deleteStaff({
    required String staffId,
    StaffDeleteOptions? options,
  }) async {
    try {
      //       print('🗑️ Eliminando empleado ID: $staffId');

      final uri = Uri.parse('$_baseUrl/delete_staff.php');

      // Verificar ID válido
      final id = int.tryParse(staffId);
      if (id == null) {
        return ApiResponse.error('ID de empleado inválido');
      }

      // Preparar datos para eliminación
      final deleteOptions = options ?? const StaffDeleteOptions();
      final deleteData = <String, dynamic>{'id': id, ...deleteOptions.toJson()};

      // Obtener usuario eliminador
      final userId = await _getCurrentUserId();
      if (userId != null) {
        deleteData['deleted_by'] = userId;
      }

      //       print('🗑️ Parámetros de eliminación: $deleteData');

      final response = await http
          .delete(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(deleteData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar diferentes códigos de respuesta
        if (response.statusCode == 200 && responseData['success'] == true) {
          // Eliminación exitosa
          return ApiResponse.success(
            responseData['data'] ?? {},
            responseData['message'] ?? 'Empleado eliminado exitosamente',
          );
        } else if (response.statusCode == 409) {
          // Conflicto - tiene dependencias
          return ApiResponse.error(
            responseData['message'] ?? 'El empleado tiene dependencias',
            errors: {
              'conflict': true,
              'dependencies': responseData['errors'],
              'recommendations': responseData['data']?['recommendations'] ?? {},
              'can_delete': false,
            },
          );
        } else if (response.statusCode == 400) {
          // Error de validación
          return ApiResponse.error(
            responseData['message'] ?? 'Error de validación',
            errors: responseData['errors'],
          );
        } else {
          // Otros errores
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Verifica si un empleado puede ser eliminado sin conflictos
  static Future<ApiResponse<Map<String, dynamic>>> checkStaffDependencies({
    required String staffId,
  }) async {
    try {
      //       print('🔍 Verificando dependencias para empleado ID: $staffId');

      // Primero obtener el detalle del empleado para verificar si es manager
      final staffDetailResponse = await getStaffDetail(id: staffId);

      if (!staffDetailResponse.success || staffDetailResponse.data == null) {
        return ApiResponse.error(
          'No se pudo obtener la información del empleado: ${staffDetailResponse.message}',
        );
      }

      final staffDetail = staffDetailResponse.data!;

      // Verificar si es manager de departamento
      final isManager = staffDetail.additionalInfo?.canBeDeleted == false;

      if (isManager) {
        return ApiResponse.error(
          'El empleado es manager de un departamento',
          errors: {
            'conflict': true,
            'dependencies': {'departments': 'Es manager de departamento'},
            'can_delete': false,
            'recommendations': {
              'transfer_departments':
                  'Transfiere el departamento a otro manager',
              'force_delete':
                  'Usa eliminación forzada (departamento quedará sin manager)',
              'soft_delete': 'Desactiva el empleado en lugar de eliminarlo',
            },
          },
        );
      }

      return ApiResponse.success({
        'can_delete': true,
        'staff': staffDetail.staff.toJson(),
        'dependencies': {},
      });
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(
        'Error al verificar dependencias: ${e.toString()}',
      );
    }
  }

  /// Activa o desactiva un empleado (toggle status) - VERSIÓN SIMPLIFICADA
  static Future<ApiResponse<StaffModel>> toggleStaffStatus({
    required String staffId,
    bool? isActive,
    String? reason,
  }) async {
    try {
      //       print('🔄 Cambiando estado de empleado ID: $staffId');

      // ✅ OBTENER EL EMPLEADO ACTUAL DE LA LISTA EN LUGAR DE get_staff_detail
      final staffListResponse = await getStaffList(limit: 1000);

      if (!staffListResponse.success || staffListResponse.data == null) {
        return ApiResponse.error(
          'No se pudo cargar la lista de empleados: ${staffListResponse.message}',
        );
      }

      // Buscar el empleado en la lista
      StaffModel? currentStaff;
      try {
        currentStaff =
            staffListResponse.data!.firstWhere((staff) => staff.id == staffId)
                as StaffModel;
      } catch (e) {
        return ApiResponse.error('Empleado no encontrado con ID: $staffId');
      }

      // Determinar el nuevo estado (toggle si no se especifica)
      final newStatus = isActive ?? !currentStaff.isActive;

      //       print('🔄 Cambiando de ${currentStaff.isActive} a $newStatus');

      // Crear una copia con el nuevo estado
      final updatedStaff = StaffModel(
        id: currentStaff.id,
        staffCode: currentStaff.staffCode,
        firstName: currentStaff.firstName,
        lastName: currentStaff.lastName,
        email: currentStaff.email,
        phone: currentStaff.phone,
        positionId: currentStaff.positionId,
        departmentId: currentStaff.departmentId,
        hireDate: currentStaff.hireDate,
        identificationType: currentStaff.identificationType,
        identificationNumber: currentStaff.identificationNumber,
        photoUrl: currentStaff.photoUrl,
        isActive: newStatus, // SOLO CAMBIAR EL ESTADO
        salary: currentStaff.salary,
        birthDate: currentStaff.birthDate,
        address: currentStaff.address,
        emergencyContactName: currentStaff.emergencyContactName,
        emergencyContactPhone: currentStaff.emergencyContactPhone,
        createdAt: currentStaff.createdAt,
        updatedAt: DateTime.now(),
      );

      // Actualizar el empleado usando el método update
      //       print('📡 Actualizando empleado con nuevo estado...');
      final updateResponse = await updateStaff(updatedStaff);

      if (updateResponse.success) {
        //         print('✅ Estado del empleado cambiado exitosamente');
        return updateResponse;
      } else {
        throw Exception(updateResponse.message ?? 'Error actualizando estado');
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(
        'Error al cambiar estado del empleado: ${e.toString()}',
      );
    }
  }

  /// Reactiva un empleado inactivo
  static Future<ApiResponse<StaffModel>> reactivateStaff({
    required String staffId,
    String? reason,
  }) async {
    return toggleStaffStatus(
      staffId: staffId,
      isActive: true,
      reason: reason ?? 'Reactivación de empleado',
    );
  }

  /// Desactiva un empleado activo
  static Future<ApiResponse<StaffModel>> deactivateStaff({
    required String staffId,
    String? reason,
  }) async {
    return toggleStaffStatus(
      staffId: staffId,
      isActive: false,
      reason: reason ?? 'Desactivación de empleado',
    );
  }

  /// Duplica un empleado (crear uno nuevo basado en otro existente)
  static Future<ApiResponse<StaffModel>> duplicateStaff({
    required String staffId,
    required String newEmail,
    required String newIdentificationNumber,
    String? newFirstName,
    String? newLastName,
  }) async {
    try {
      //       print('📋 Duplicando empleado ID: $staffId');

      // Obtener el empleado original
      final staffDetailResponse = await getStaffDetail(id: staffId);

      if (!staffDetailResponse.success || staffDetailResponse.data == null) {
        return ApiResponse.error(
          'No se pudo obtener la información del empleado original: ${staffDetailResponse.message}',
        );
      }

      final originalStaff = staffDetailResponse.data!.staff;

      // Crear nuevo empleado basado en el original
      final newStaff = StaffModel(
        id: '', // Nuevo ID se generará automáticamente
        staffCode: '', // Nuevo código se generará automáticamente
        firstName: newFirstName ?? originalStaff.firstName,
        lastName: newLastName ?? originalStaff.lastName,
        email: newEmail,
        phone: originalStaff.phone,
        positionId: originalStaff.positionId,
        departmentId: originalStaff.departmentId,
        hireDate: DateTime.now(), // Nueva fecha de contratación
        identificationType: originalStaff.identificationType,
        identificationNumber: newIdentificationNumber,
        photoUrl: null, // No duplicar foto
        isActive: true,
        salary: originalStaff.salary,
        birthDate: originalStaff.birthDate,
        address: originalStaff.address,
        emergencyContactName: originalStaff.emergencyContactName,
        emergencyContactPhone: originalStaff.emergencyContactPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Crear el nuevo empleado
      return await createStaff(newStaff);
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error al duplicar empleado: ${e.toString()}');
    }
  }
  // =====================================================
  // STAFF SERVICES - PARTE 3: Métodos de consulta y búsqueda
  // VERSIÓN CORREGIDA COMPATIBLE CON get_staff.php
  // =====================================================

  // ===== CONTINUACIÓN DE LA CLASE StaffApiService =====

  // ===== MÉTODOS DE CONSULTA Y BÚSQUEDA =====
  /// Obtiene lista de empleados con filtros y paginación
  static Future<ApiResponse<StaffResponse>> getStaff({
    String? search,
    int? departmentId,
    int? positionId,
    bool? isActive,
    bool includeInactive = false,
    String? hireDateFrom,
    String? hireDateTo,
    double? salaryMin,
    double? salaryMax,
    String? identificationType,
    int limit = 20,
    int offset = 0,
    String sortBy = 'first_name',
    String sortOrder = 'ASC',
    bool includeStats = false,
    bool includeSummary = true,
  }) async {
    try {
      //       print('📋 Obteniendo lista de empleados...');

      final queryParams = <String, String>{};

      // Filtros opcionales
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (departmentId != null) {
        queryParams['department_id'] = departmentId.toString();
      }
      if (positionId != null) {
        queryParams['position_id'] = positionId.toString();
      }
      if (identificationType != null && identificationType.isNotEmpty) {
        queryParams['identification_type'] = identificationType;
      }
      if (hireDateFrom != null && hireDateFrom.isNotEmpty) {
        queryParams['hire_date_from'] = hireDateFrom;
      }
      if (hireDateTo != null && hireDateTo.isNotEmpty) {
        queryParams['hire_date_to'] = hireDateTo;
      }
      if (salaryMin != null) queryParams['salary_min'] = salaryMin.toString();
      if (salaryMax != null) queryParams['salary_max'] = salaryMax.toString();

      // Estado activo/inactivo
      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      } else if (includeInactive) {
        queryParams['include_inactive'] = 'true';
      }

      // Paginación y ordenamiento
      queryParams['limit'] = limit.toString();
      queryParams['offset'] = offset.toString();
      queryParams['sort_by'] = sortBy;
      queryParams['sort_order'] = sortOrder;

      // Opciones adicionales
      if (includeStats) queryParams['include_stats'] = 'true';
      if (includeSummary) queryParams['include_summary'] = 'true';

      final uri = Uri.parse(
        '$_baseUrl/get_staff.php',
      ).replace(queryParameters: queryParams);

      //       print('📋 URI: $uri');

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');

      // ✅ VALIDACIÓN MEJORADA DE RESPUESTA
      if (response.statusCode != 200) {
        //         print('❌ HTTP Error: ${response.statusCode}');
        return ApiResponse.error(
          'Error del servidor HTTP ${response.statusCode}',
        );
      }

      if (response.body.isEmpty) {
        //         print('❌ Empty response body');
        return ApiResponse.error('El servidor devolvió una respuesta vacía');
      }

      //       print('📡 Body length: ${response.body.length} characters');
      //       print('📡 Body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      try {
        final Map<String, dynamic> responseData = json.decode(response.body);
        //         print('📋 JSON parsed successfully');
        //         print('📋 Response keys: ${responseData.keys}');
        //         print('📋 Success: ${responseData['success']}');

        if (responseData['success'] != true) {
          final errorMsg =
              responseData['message'] ?? 'Error desconocido del servidor';
          //           print('❌ Server reported error: $errorMsg');
          return ApiResponse.error(errorMsg, errors: responseData['errors']);
        }

        // ✅ VERIFICAR ESTRUCTURA DE DATOS
        if (responseData['data'] == null) {
          //           print('❌ Missing data section in response');
          return ApiResponse.error(
            'Respuesta del servidor sin sección de datos',
          );
        }

        final dataSection = responseData['data'] as Map<String, dynamic>;
        //         print('📋 Data section keys: ${dataSection.keys}');

        if (dataSection['staff'] == null) {
          //           print('❌ Missing staff array in data section');
          return ApiResponse.error(
            'Respuesta del servidor sin lista de empleados',
          );
        }

        final staffArray = dataSection['staff'] as List;
        //         print('📋 Staff count in response: ${staffArray.length}');

        // ✅ PROCESAR LISTA DE EMPLEADOS
        final staffList = <StaffModel>[];
        for (int i = 0; i < staffArray.length; i++) {
          try {
            final staffJson = staffArray[i] as Map<String, dynamic>;

            // ✅ ASEGURAR QUE TODOS LOS CAMPOS REQUERIDOS EXISTEN
            staffJson['id'] = staffJson['id']?.toString() ?? '';
            staffJson['staff_code'] = staffJson['staff_code'] ?? 'EMP-${i + 1}';
            staffJson['first_name'] = staffJson['first_name'] ?? '';
            staffJson['last_name'] = staffJson['last_name'] ?? '';
            staffJson['email'] = staffJson['email'] ?? '';
            staffJson['department_id'] =
                staffJson['department_id']?.toString() ?? '1';
            staffJson['position_id'] =
                staffJson['position_id']?.toString() ?? '1';
            staffJson['identification_number'] =
                staffJson['identification_number'] ?? '';
            staffJson['identification_type'] =
                staffJson['identification_type'] ?? 'dni';
            staffJson['hire_date'] =
                staffJson['hire_date'] ??
                DateTime.now().toIso8601String().split('T')[0];
            staffJson['is_active'] = staffJson['is_active'] ?? true;
            staffJson['created_at'] =
                staffJson['created_at'] ?? DateTime.now().toIso8601String();
            staffJson['updated_at'] =
                staffJson['updated_at'] ?? DateTime.now().toIso8601String();

            final staff = StaffModel.fromJson(staffJson);
            staffList.add(staff);
            //             print('✅ Staff ${i + 1} processed: ${staff.firstName} ${staff.lastName}');
          } catch (staffError) {
            //             print('⚠️ Error processing staff ${i + 1}: $staffError');
            // Continuar con el siguiente empleado en lugar de fallar completamente
          }
        }

        //         print('✅ Total staff processed: ${staffList.length}');

        // ✅ PROCESAR PAGINACIÓN
        final paginationData =
            dataSection['pagination'] as Map<String, dynamic>? ?? {};
        final pagination = PaginationData(
          totalRecords: paginationData['total_records'] ?? staffList.length,
          totalPages: paginationData['total_pages'] ?? 1,
          currentPage: paginationData['current_page'] ?? 1,
          limit: paginationData['limit'] ?? limit,
          offset: paginationData['offset'] ?? offset,
          hasNext: paginationData['has_next'] ?? false,
          hasPrev:
              paginationData['has_prev'] ??
              false, // Note: hasPrev instead of hasPrevious
        );

        // ✅ CREAR STAFF RESPONSE
        final staffResponse = StaffResponse(
          staff: staffList,
          pagination: pagination,
        );

        //         print('✅ StaffResponse created with ${staffResponse.staff.length} employees');

        return ApiResponse.success(
          staffResponse,
          'Empleados cargados exitosamente: ${staffList.length} encontrados',
        );
      } catch (parseError) {
        //         print('❌ JSON Parse Error: $parseError');
        //         print('❌ Raw response: ${response.body}');
        return ApiResponse.error(
          'Error parseando respuesta del servidor: ${parseError.toString()}',
        );
      }
    } catch (networkError) {
      //       print('❌ Network Error: $networkError');
      if (networkError.toString().contains('TimeoutException')) {
        return ApiResponse.error(
          'Tiempo de espera agotado. Verifique su conexión a internet.',
        );
      } else if (networkError.toString().contains('SocketException')) {
        return ApiResponse.error(
          'Error de conexión. Verifique su internet y el servidor.',
        );
      } else {
        return ApiResponse.error('Error de red: ${networkError.toString()}');
      }
    }
  }

  // ✅ MÉTODO DE COMPATIBILIDAD: getStaffList (para staff_presentation.dart)
  /// Obtiene lista simple de empleados (compatible con controller)
  static Future<ApiResponse<List<Staff>>> getStaffList({
    String? search,
    int? departmentId,
    int? positionId,
    bool? isActive,
    bool includeInactive = false,
    String? hireDateFrom,
    String? hireDateTo,
    double? salaryMin,
    double? salaryMax,
    String? identificationType,
    int limit = 20,
    int offset = 0,
    String sortBy = 'first_name',
    String sortOrder = 'ASC',
  }) async {
    try {
      // Llamar al método principal
      final response = await getStaff(
        search: search,
        departmentId: departmentId,
        positionId: positionId,
        isActive: isActive,
        includeInactive: includeInactive,
        hireDateFrom: hireDateFrom,
        hireDateTo: hireDateTo,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        identificationType: identificationType,
        limit: limit,
        offset: offset,
        sortBy: sortBy,
        sortOrder: sortOrder,
        includeStats: false,
        includeSummary: false,
      );

      if (response.success && response.data != null) {
        // ✅ CORRECCIÓN: StaffResponse.staff contiene List<StaffModel>
        final staffList = response.data!.staff.cast<Staff>();
        return ApiResponse.success(
          staffList,
          response.message ?? 'Empleados obtenidos exitosamente',
        );
      } else {
        return ApiResponse.error(
          response.message ?? 'Error obteniendo empleados',
          errors: response.errors,
        );
      }
    } catch (e) {
      //       print('❌ Error en getStaffList: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Obtiene detalle completo de un empleado específico
  static Future<ApiResponse<StaffDetailResponse>> getStaffDetail({
    String? id,
    String? staffCode,
    String? email,
    bool includeHistory = true,
    bool includeStats = true,
    bool includeRelations = true,
    int historyLimit = 10,
    bool includeInactive = false,
  }) async {
    try {
      //       print('📋 Obteniendo detalle de empleado...');

      final queryParams = <String, String>{};

      // Identificadores (al menos uno requerido)
      if (id != null && id.isNotEmpty) {
        queryParams['id'] = id;
      } else if (staffCode != null && staffCode.isNotEmpty) {
        queryParams['staff_code'] = staffCode;
      } else if (email != null && email.isNotEmpty) {
        queryParams['email'] = email;
      } else {
        return ApiResponse.error(
          'Se requiere al menos uno de: id, staff_code, o email',
        );
      }

      // Opciones de inclusión
      queryParams['include_history'] = includeHistory.toString();
      queryParams['include_stats'] = includeStats.toString();
      queryParams['include_relations'] = includeRelations.toString();
      queryParams['history_limit'] = historyLimit.toString();
      if (includeInactive) queryParams['include_inactive'] = 'true';

      final uri = Uri.parse(
        '$_baseUrl/get_staff_detail.php',
      ).replace(queryParameters: queryParams);

      //       print('📋 URI: $uri');

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');

      // ✅ PARA MÉTODO QUE NO EXISTE AÚN, SIMULAR RESPUESTA
      if (response.statusCode == 404 || response.body.contains('no funciona')) {
        //         print('⚠️ Endpoint get_staff_detail.php no existe, usando simulación');

        // Obtener empleado básico de la lista
        final staffListResponse = await getStaffList(limit: 1000);
        if (staffListResponse.success && staffListResponse.data != null) {
          final staff = staffListResponse.data!.firstWhere(
            (s) => s.id == id || s.email == email,
            orElse: () => throw Exception('Empleado no encontrado'),
          );

          // Crear respuesta simulada
          final staffDetail = StaffDetailResponse(
            staff: staff as StaffModel,
            manager: null,
            relations: null,
            stats: null,
            history: null,
            additionalInfo: const StaffAdditionalInfo(
              canBeDeleted: true,
              requiresSalaryReview: false,
              profileIncomplete: false,
              isNewEmployee: false,
              isVeteran: false,
            ),
          );

          return ApiResponse.success(
            staffDetail,
            'Detalle de empleado obtenido (simulado)',
          );
        }
      }

      return _handleResponse<StaffDetailResponse>(
        response,
        (data) => StaffDetailResponse.fromJson(data['data']),
      );
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Búsqueda avanzada de empleados
  static Future<ApiResponse<StaffResponse>> searchStaff({
    String? q, // Búsqueda general
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? staffCode,
    String? identificationNumber,
    List<int>? departmentIds,
    List<int>? positionIds,
    List<String>? identificationTypes,
    String? salaryRange, // 'low', 'medium', 'high'
    double? salaryMin,
    double? salaryMax,
    int? ageMin,
    int? ageMax,
    String? hireDateFrom,
    String? hireDateTo,
    String? location, // Para búsqueda por dirección
    bool? hasEmergencyContact,
    bool? hasPhoto,
    bool? isActive,
    String? experienceLevel, // 'new', 'experienced', 'veteran'
    int limit = 50,
    int offset = 0,
    String sortBy = 'first_name',
    String sortOrder = 'ASC',
    bool includeInactive = false,
    bool includeStats = false,
  }) async {
    // ✅ USAR get_staff.php PARA BÚSQUEDA (hasta que tengamos search_staff.php)
    return await getStaff(
      search: q,
      departmentId: departmentIds?.first,
      positionId: positionIds?.first,
      isActive: isActive,
      includeInactive: includeInactive,
      hireDateFrom: hireDateFrom,
      hireDateTo: hireDateTo,
      salaryMin: salaryMin,
      salaryMax: salaryMax,
      limit: limit,
      offset: offset,
      sortBy: sortBy,
      sortOrder: sortOrder,
      includeStats: includeStats,
    );
  }

  // ✅ MÉTODO DE COMPATIBILIDAD: searchStaffList (para staff_presentation.dart)
  /// Búsqueda simple que devuelve List<Staff> (compatible con controller)
  static Future<ApiResponse<List<Staff>>> searchStaffList({
    String? q,
    String? search, // Alias para q
    int? departmentId,
    int? positionId,
    bool? isActive,
    int limit = 50,
    int offset = 0,
    String sortBy = 'first_name',
    String sortOrder = 'ASC',
  }) async {
    try {
      // Usar q o search
      final query = q ?? search;

      // Llamar al método de búsqueda
      final response = await searchStaff(
        q: query,
        departmentIds: departmentId != null ? [departmentId] : null,
        positionIds: positionId != null ? [positionId] : null,
        isActive: isActive,
        limit: limit,
        offset: offset,
        sortBy: sortBy,
        sortOrder: sortOrder,
        includeStats: false,
      );

      if (response.success && response.data != null) {
        // ✅ CORRECCIÓN: StaffResponse.staff contiene List<StaffModel>
        final staffList = response.data!.staff.cast<Staff>();
        return ApiResponse.success(
          staffList,
          response.message ?? 'Búsqueda completada exitosamente',
        );
      } else {
        return ApiResponse.error(
          response.message ?? 'Error en búsqueda',
          errors: response.errors,
        );
      }
    } catch (e) {
      //       print('❌ Error en searchStaffList: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ===== MÉTODOS DE CONSULTA ESPECIALIZADOS =====

  /// Obtiene empleados inactivos
  static Future<ApiResponse<StaffResponse>> getInactiveStaff({
    String? search,
    int? departmentId,
    int? positionId,
    String? deactivatedAfter,
    String? deactivatedBefore,
    int limit = 20,
    int offset = 0,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
  }) async {
    return getStaff(
      search: search,
      departmentId: departmentId,
      positionId: positionId,
      isActive: false,
      includeInactive: true,
      limit: limit,
      offset: offset,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  /// Obtiene empleados por departamento
  static Future<ApiResponse<StaffResponse>> getStaffByDepartment({
    required int departmentId,
    bool includeInactive = false,
    String sortBy = 'first_name',
    String sortOrder = 'ASC',
  }) async {
    return getStaff(
      departmentId: departmentId,
      includeInactive: includeInactive,
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: 1000, // Obtener todos los empleados del departamento
    );
  }

  /// Obtiene empleados por posición
  static Future<ApiResponse<StaffResponse>> getStaffByPosition({
    required int positionId,
    bool includeInactive = false,
    String sortBy = 'first_name',
    String sortOrder = 'ASC',
  }) async {
    return getStaff(
      positionId: positionId,
      includeInactive: includeInactive,
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: 1000, // Obtener todos los empleados de la posición
    );
  }

  /// Obtiene lista de especialidades
  static Future<ApiResponse<List<Map<String, dynamic>>>>
  getSpecialties() async {
    try {
      // Usar la URL base de especialidades (catálogo global)
      final baseUrl = ServerConfig.instance.baseUrlFor('especialidades');
      final uri = Uri.parse('$baseUrl/listar.php');

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Asumiendo que data['data'] es una lista de especialidades
          final List<dynamic> specialtiesData = data['data'] ?? [];
          final specialties =
              specialtiesData.map((e) => e as Map<String, dynamic>).toList();

          return ApiResponse.success(
            specialties,
            data['message'] ?? 'Especialidades obtenidas exitosamente',
          );
        } else {
          return ApiResponse.error(
            data['message'] ?? 'Error al obtener especialidades',
          );
        }
      } else {
        return ApiResponse.error('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      // print('❌ Error obteniendo especialidades: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ===== ESTADÍSTICAS Y VALIDACIONES =====

  /// Verifica disponibilidad de email
  static Future<ApiResponse<Map<String, dynamic>>> checkEmailAvailability(
    String email, {
    String? excludeStaffId,
  }) async {
    try {
      //       print('📧 Verificando disponibilidad de email: $email');

      // ✅ SIMULACIÓN TEMPORAL (hasta crear check_email.php)
      final staffResponse = await getStaffList(limit: 1000);
      if (staffResponse.success && staffResponse.data != null) {
        final emailExists = staffResponse.data!.any(
          (staff) =>
              staff.email.toLowerCase() == email.toLowerCase() &&
              staff.id != excludeStaffId,
        );

        return ApiResponse.success({
          'available': !emailExists,
          'email': email,
          'exists': emailExists,
        }, emailExists ? 'Email ya registrado' : 'Email disponible');
      }

      return ApiResponse.error('Error verificando email');
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ✅ MÉTODO DE COMPATIBILIDAD: isEmailAvailable (para staff_presentation.dart)
  /// Verifica si un email está disponible (devuelve bool)
  static Future<ApiResponse<bool>> isEmailAvailable(
    String email, {
    String? excludeStaffId,
  }) async {
    try {
      final response = await checkEmailAvailability(
        email,
        excludeStaffId: excludeStaffId,
      );

      if (response.success && response.data != null) {
        final available = response.data!['available'] == true;
        return ApiResponse.success(available, response.message);
      } else {
        return ApiResponse.error(
          response.message ?? 'Error verificando email',
          errors: response.errors,
        );
      }
    } catch (e) {
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Verifica disponibilidad de número de identificación
  static Future<ApiResponse<Map<String, dynamic>>>
  checkIdentificationAvailability(
    String identificationNumber, {
    String? excludeStaffId,
  }) async {
    try {
      //       print('🆔 Verificando disponibilidad de identificación: $identificationNumber');

      // ✅ SIMULACIÓN TEMPORAL (hasta crear check_identification.php)
      final staffResponse = await getStaffList(limit: 1000);
      if (staffResponse.success && staffResponse.data != null) {
        final idExists = staffResponse.data!.any(
          (staff) =>
              staff.identificationNumber == identificationNumber &&
              staff.id != excludeStaffId,
        );

        return ApiResponse.success(
          {
            'available': !idExists,
            'identification_number': identificationNumber,
            'exists': idExists,
          },
          idExists
              ? 'Identificación ya registrada'
              : 'Identificación disponible',
        );
      }

      return ApiResponse.error('Error verificando identificación');
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ✅ MÉTODO DE COMPATIBILIDAD: isIdentificationAvailable (para staff_presentation.dart)
  /// Verifica si una identificación está disponible (devuelve bool)
  static Future<ApiResponse<bool>> isIdentificationAvailable(
    String identificationNumber, {
    String? excludeStaffId,
  }) async {
    try {
      final response = await checkIdentificationAvailability(
        identificationNumber,
        excludeStaffId: excludeStaffId,
      );

      if (response.success && response.data != null) {
        final available = response.data!['available'] == true;
        return ApiResponse.success(available, response.message);
      } else {
        return ApiResponse.error(
          response.message ?? 'Error verificando identificación',
          errors: response.errors,
        );
      }
    } catch (e) {
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ✅ MÉTODOS DE COMPATIBILIDAD PARA DEPARTAMENTOS
  /// Obtiene lista simple de departamentos (compatible con controller)
  static Future<ApiResponse<List<Department>>> getDepartmentsList({
    bool includeInactive = false,
    bool includeStats = true,
  }) async {
    try {
      //       print('🏢 Obteniendo departamentos REALES desde la base de datos...');

      final queryParams = <String, String>{};

      // Parámetros opcionales
      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (includeStats) queryParams['include_stats'] = 'true';

      final uri = Uri.parse(
        '${ServerConfig.instance.baseUrlFor('staff')}/departments/get_departments.php',
      ).replace(queryParameters: queryParams);

      //       print('🏢 URI: $uri');

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body length: ${response.body.length} characters');
      //       print('📡 Body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode != 200) {
        //         print('❌ HTTP Error: ${response.statusCode}');
        return ApiResponse.error(
          'Error del servidor HTTP ${response.statusCode}',
        );
      }

      if (response.body.isEmpty) {
        //         print('❌ Empty response body');
        return ApiResponse.error('El servidor devolvió una respuesta vacía');
      }

      try {
        final Map<String, dynamic> responseData = json.decode(response.body);
        //         print('🏢 JSON parsed successfully');
        //         print('🏢 Response keys: ${responseData.keys}');
        //         print('🏢 Success: ${responseData['success']}');

        if (responseData['success'] != true) {
          final errorMsg =
              responseData['message'] ?? 'Error desconocido del servidor';
          //           print('❌ Server reported error: $errorMsg');
          return ApiResponse.error(errorMsg, errors: responseData['errors']);
        }

        // Procesar lista de departamentos
        if (responseData['data'] == null) {
          //           print('❌ Missing data section in response');
          return ApiResponse.error(
            'Respuesta del servidor sin sección de datos',
          );
        }

        final dataSection = responseData['data'];
        List<dynamic> departmentsArray;

        // Manejar diferentes estructuras de respuesta
        if (dataSection is List) {
          departmentsArray = dataSection;
        } else if (dataSection is Map && dataSection['departments'] != null) {
          departmentsArray = dataSection['departments'] as List;
        } else {
          //           print('❌ Invalid data structure in response');
          return ApiResponse.error(
            'Estructura de datos inválida en la respuesta',
          );
        }

        //         print('🏢 Departments count in response: ${departmentsArray.length}');

        // Procesar lista de departamentos
        final departmentsList = <Department>[];
        for (int i = 0; i < departmentsArray.length; i++) {
          try {
            final deptJson = departmentsArray[i] as Map<String, dynamic>;

            // Asegurar que todos los campos requeridos existen
            deptJson['id'] = deptJson['id']?.toString() ?? (i + 1).toString();
            deptJson['name'] = deptJson['name'] ?? 'Departamento ${i + 1}';
            deptJson['description'] = deptJson['description'] ?? '';
            deptJson['manager_id'] = deptJson['manager_id']?.toString();
            deptJson['is_active'] = deptJson['is_active'] ?? true;
            deptJson['created_at'] =
                deptJson['created_at'] ?? DateTime.now().toIso8601String();
            deptJson['updated_at'] =
                deptJson['updated_at'] ?? DateTime.now().toIso8601String();

            final department = DepartmentModel.fromJson(deptJson);
            departmentsList.add(department);
            //             print('✅ Department ${i + 1} processed: ${department.name}');
          } catch (deptError) {
            //             print('⚠️ Error processing department ${i + 1}: $deptError');
            // Continuar con el siguiente departamento
          }
        }

        //         print('✅ Total departments processed: ${departmentsList.length}');

        return ApiResponse.success(
          departmentsList,
          'Departamentos obtenidos exitosamente desde la base de datos: ${departmentsList.length} encontrados',
        );
      } catch (parseError) {
        //         print('❌ JSON Parse Error: $parseError');
        //         print('❌ Raw response: ${response.body}');
        return ApiResponse.error(
          'Error parseando respuesta del servidor: ${parseError.toString()}',
        );
      }
    } catch (networkError) {
      //       print('❌ Network Error: $networkError');
      if (networkError.toString().contains('TimeoutException')) {
        return ApiResponse.error(
          'Tiempo de espera agotado. Verifique su conexión a internet.',
        );
      } else if (networkError.toString().contains('SocketException')) {
        return ApiResponse.error(
          'Error de conexión. Verifique su internet y el servidor.',
        );
      } else {
        return ApiResponse.error('Error de red: ${networkError.toString()}');
      }
    }
  }

  // ✅ MÉTODOS DE COMPATIBILIDAD PARA POSICIONES
  /// Obtiene lista simple de posiciones (compatible con controller)
  static Future<ApiResponse<List<Position>>> getPositionsList({
    int? departmentId,
    bool includeInactive = false,
    bool includeStats = true,
  }) async {
    try {
      //       print('💼 Obteniendo posiciones REALES desde la base de datos...');

      final queryParams = <String, String>{};

      // Parámetros opcionales
      if (departmentId != null) {
        queryParams['department_id'] = departmentId.toString();
      }
      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (includeStats) queryParams['include_stats'] = 'true';

      final uri = Uri.parse(
        '$_baseUrl/positions/get_positions.php',
      ).replace(queryParameters: queryParams);

      //       print('💼 URI: $uri');

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        return ApiResponse.error(
          'Error del servidor HTTP ${response.statusCode}',
        );
      }

      if (response.body.isEmpty) {
        return ApiResponse.error('El servidor devolvió una respuesta vacía');
      }

      try {
        final Map<String, dynamic> responseData = json.decode(response.body);
        //         print('💼 JSON parsed successfully');

        if (responseData['success'] != true) {
          final errorMsg =
              responseData['message'] ?? 'Error desconocido del servidor';
          return ApiResponse.error(errorMsg, errors: responseData['errors']);
        }

        // Procesar lista de posiciones
        final dataSection = responseData['data'];
        List<dynamic> positionsArray;

        if (dataSection is List) {
          positionsArray = dataSection;
        } else if (dataSection is Map && dataSection['positions'] != null) {
          positionsArray = dataSection['positions'] as List;
        } else {
          return ApiResponse.error(
            'Estructura de datos inválida en la respuesta',
          );
        }

        //         print('💼 Positions count in response: ${positionsArray.length}');

        // Procesar lista de posiciones
        final positionsList = <Position>[];
        for (int i = 0; i < positionsArray.length; i++) {
          try {
            final posJson = positionsArray[i] as Map<String, dynamic>;

            // Asegurar que todos los campos requeridos existen
            posJson['id'] = posJson['id']?.toString() ?? (i + 1).toString();
            posJson['title'] = posJson['title'] ?? 'Posición ${i + 1}';
            posJson['department_id'] =
                posJson['department_id']?.toString() ?? '1';
            posJson['description'] = posJson['description'] ?? '';
            posJson['min_salary'] = posJson['min_salary']?.toDouble();
            posJson['max_salary'] = posJson['max_salary']?.toDouble();
            posJson['is_active'] = posJson['is_active'] ?? true;
            posJson['created_at'] =
                posJson['created_at'] ?? DateTime.now().toIso8601String();
            posJson['updated_at'] =
                posJson['updated_at'] ?? DateTime.now().toIso8601String();

            final position = PositionModel.fromJson(posJson);
            positionsList.add(position);
            //             print('✅ Position ${i + 1} processed: ${position.title}');
          } catch (posError) {
            //             print('⚠️ Error processing position ${i + 1}: $posError');
          }
        }

        //         print('✅ Total positions processed: ${positionsList.length}');

        return ApiResponse.success(
          positionsList,
          'Posiciones obtenidas exitosamente desde la base de datos: ${positionsList.length} encontradas',
        );
      } catch (parseError) {
        //         print('❌ JSON Parse Error: $parseError');
        return ApiResponse.error(
          'Error parseando respuesta del servidor: ${parseError.toString()}',
        );
      }
    } catch (networkError) {
      //       print('❌ Network Error: $networkError');
      return ApiResponse.error('Error de red: ${networkError.toString()}');
    }
  }

  // ===== CONTINUARÁ EN PARTE 4 =====

  // =====================================================
  // STAFF SERVICES - PARTE 4: Import/Export y métodos auxiliares finales
  // =====================================================

  // ===== CONTINUACIÓN DE LA CLASE StaffApiService =====

  // ===== GESTIÓN DE DEPARTAMENTOS (INTEGRADOS) =====

  /// Obtiene lista de departamentos
  static Future<ApiResponse<List<DepartmentModel>>> getDepartments({
    bool includeInactive = false,
    bool includeStats = true,
  }) async {
    try {
      //       print('🏢 Obteniendo departamentos...');

      final queryParams = <String, String>{
        'include_stats': includeStats.toString(),
      };

      if (includeInactive) queryParams['include_inactive'] = 'true';

      final uri = Uri.parse(
        '$_baseUrl/departments/get_departments.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      return _handleResponse<List<DepartmentModel>>(
        response,
        (data) =>
            (data['data'] as List)
                .map((json) => DepartmentModel.fromJson(json))
                .toList(),
      );
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Crea un nuevo departamento
  static Future<ApiResponse<DepartmentModel>> createDepartment({
    required String name,
    String? description,
    int? managerId,
    bool isActive = true,
  }) async {
    try {
      //       print('🏢 Creando departamento: $name');

      final uri = Uri.parse('$_baseUrl/departments/create_department.php');

      final userId = await _getCurrentUserId();

      final requestData = <String, dynamic>{
        'name': name,
        'is_active': isActive,
      };

      if (description != null && description.isNotEmpty) {
        requestData['description'] = description;
      }
      if (managerId != null) requestData['manager_id'] = managerId;
      if (userId != null) requestData['created_by'] = userId;

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      return _handleResponse<DepartmentModel>(
        response,
        (data) => DepartmentModel.fromJson(data['data']),
      );
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ===== GESTIÓN DE POSICIONES (INTEGRADOS) =====

  /// Obtiene lista de posiciones
  static Future<ApiResponse<List<PositionModel>>> getPositions({
    int? departmentId,
    bool includeInactive = false,
    bool includeStats = true,
  }) async {
    try {
      //       print('💼 Obteniendo posiciones...');

      final queryParams = <String, String>{
        'include_stats': includeStats.toString(),
        'include_inactive': includeInactive.toString(),
      };

      if (departmentId != null) {
        queryParams['department_id'] = departmentId.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/positions/get_positions.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      return _handleResponse<List<PositionModel>>(
        response,
        (data) =>
            (data['data'] as List)
                .map((json) => PositionModel.fromJson(json))
                .toList(),
      );
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  /// Crea una nueva posición
  static Future<ApiResponse<PositionModel>> createPosition({
    required String title,
    required int departmentId,
    String? description,
    double? minSalary,
    double? maxSalary,
    bool isActive = true,
  }) async {
    try {
      //       print('💼 Creando posición: $title');

      final uri = Uri.parse('$_baseUrl/positions/create_position.php');

      final userId = await _getCurrentUserId();

      final requestData = <String, dynamic>{
        'title': title,
        'department_id': departmentId,
        'is_active': isActive,
      };

      if (description != null && description.isNotEmpty) {
        requestData['description'] = description;
      }
      if (minSalary != null) requestData['min_salary'] = minSalary;
      if (maxSalary != null) requestData['max_salary'] = maxSalary;
      if (userId != null) requestData['created_by'] = userId;

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      return _handleResponse<PositionModel>(
        response,
        (data) => PositionModel.fromJson(data['data']),
      );
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(_getNetworkErrorMessage(e));
    }
  }

  // ===== IMPORTACIÓN/EXPORTACIÓN =====

  /// Exporta empleados a Excel
  static Future<ApiResponse<Uint8List>> exportStaffToExcel({
    List<StaffModel>? staff,
    List<String>? selectedFields,
  }) async {
    try {
      //       print('[EXPORT STAFF] Iniciando exportación...');

      final uri = Uri.parse('$_baseUrl/exportar_staff.php');

      // Preparar datos para envío
      final requestData = <String, dynamic>{};

      if (staff != null && staff.isNotEmpty) {
        // Convertir empleados a formato Map para enviar al servidor
        requestData['staff'] =
            staff
                .map(
                  (employee) => {
                    'id': int.tryParse(employee.id) ?? 0,
                    'staff_code': employee.staffCode,
                    'first_name': employee.firstName,
                    'last_name': employee.lastName,
                    'full_name': '${employee.firstName} ${employee.lastName}',
                    'email': employee.email,
                    'phone': employee.phone,
                    'department_id': int.tryParse(employee.departmentId) ?? 0,
                    'department_name': '', // Se llenará en el servidor
                    'position_id': int.tryParse(employee.positionId) ?? 0,
                    'position_title': '', // Se llenará en el servidor
                    'hire_date':
                        employee.hireDate.toIso8601String().split('T')[0],
                    'identification_type': employee.identificationType.name,
                    'identification_number': employee.identificationNumber,
                    'salary': employee.salary,
                    'birth_date':
                        employee.birthDate?.toIso8601String().split('T')[0],
                    'age':
                        employee.birthDate != null
                            ? DateTime.now()
                                    .difference(employee.birthDate!)
                                    .inDays ~/
                                365
                            : null,
                    'address': employee.address,
                    'emergency_contact_name': employee.emergencyContactName,
                    'emergency_contact_phone': employee.emergencyContactPhone,
                    'photo_url': employee.photoUrl,
                    'is_active': employee.isActive,
                    'years_employed':
                        DateTime.now().difference(employee.hireDate).inDays ~/
                        365,
                    'months_employed':
                        DateTime.now().difference(employee.hireDate).inDays ~/
                        30,
                    'created_at': employee.createdAt.toIso8601String(),
                    'updated_at': employee.updatedAt.toIso8601String(),
                  },
                )
                .toList();
        //         print('[EXPORT STAFF] Empleados a exportar: ${staff.length}');
      }

      if (selectedFields != null && selectedFields.isNotEmpty) {
        requestData['selected_fields'] = selectedFields;
      }

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            },
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 60));

      //       print('[EXPORT STAFF] Status Code: ${response.statusCode}');
      //       print('[EXPORT STAFF] Response length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          // Es un error JSON
          final errorData = jsonDecode(response.body);
          return ApiResponse.error(
            'Error del servidor: ${errorData['error'] ?? 'Error desconocido'}',
          );
        }

        // Es un archivo Excel válido - retornar los bytes
        return ApiResponse.success(
          response.bodyBytes,
          'Excel de empleados generado exitosamente',
        );
      } else {
        String errorMessage = 'Error al exportar Excel: ${response.statusCode}';

        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (e) {
          // Si no es JSON válido, usar mensaje por defecto
        }

        return ApiResponse.error(errorMessage);
      }
    } catch (e) {
      //       print('[EXPORT STAFF] Error: $e');
      return ApiResponse.error('Error al exportar empleados: ${e.toString()}');
    }
  }

  /// Importa empleados desde archivo Excel/CSV
  static Future<ApiResponse<StaffImportResult>> importStaffFromFile({
    required Uint8List fileBytes,
    required String fileName,
    StaffImportOptions? options,
  }) async {
    try {
      //       print('[IMPORT STAFF] Iniciando importación...');
      //       print('[IMPORT STAFF] Archivo: $fileName');
      //       print('[IMPORT STAFF] Tamaño: ${fileBytes.length} bytes');

      final uri = Uri.parse('$_baseUrl/importar_staff.php');

      // Convertir bytes a base64
      final base64String = base64Encode(fileBytes);

      final requestData = <String, dynamic>{
        'archivo_base64': base64String,
        'nombre_archivo': fileName,
      };

      // Agregar opciones si se proporcionan
      if (options != null) {
        requestData['options'] = options.toJson();
      }

      // Agregar usuario actual
      final userId = await _getCurrentUserId();
      if (userId != null) {
        requestData['created_by'] = userId;
      }

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 120));

      //       print('[IMPORT STAFF] Status Code: ${response.statusCode}');
      //       print('[IMPORT STAFF] Response: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode})',
        );
      }

      try {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final result = StaffImportResult.fromJson(responseData);

          return ApiResponse.success(
            result,
            responseData['message'] ??
                'Importación de empleados completada exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        //         print('[IMPORT STAFF] Error parseando JSON: $jsonError');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('[IMPORT STAFF] Error: $e');
      return ApiResponse.error('Error al importar empleados: ${e.toString()}');
    }
  }

  /// Descarga la plantilla de Excel para importación de empleados
  static Future<ApiResponse<Uint8List>> downloadStaffTemplate() async {
    try {
      //       print('[TEMPLATE] Descargando plantilla de empleados...');

      final uri = Uri.parse('$_baseUrl/plantilla_staff.php');

      final response = await http
          .get(
            uri,
            headers: {
              'Accept':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      //       print('[TEMPLATE] Status Code: ${response.statusCode}');
      //       print('[TEMPLATE] Response length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          // Es un error JSON
          final errorData = jsonDecode(response.body);
          return ApiResponse.error(
            'Error del servidor: ${errorData['error'] ?? 'Error desconocido'}',
          );
        }

        // Es un archivo Excel válido
        return ApiResponse.success(
          response.bodyBytes,
          'Plantilla de empleados descargada exitosamente',
        );
      } else {
        return ApiResponse.error(
          'Error al descargar plantilla: ${response.statusCode}',
        );
      }
    } catch (e) {
      //       print('[TEMPLATE] Error: $e');
      return ApiResponse.error('Error al descargar plantilla: ${e.toString()}');
    }
  }

  /// Valida archivo de importación antes de procesarlo
  static Future<ApiResponse<Map<String, dynamic>>> validateImportFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      //       print('[VALIDATE] Validando archivo de importación...');

      final uri = Uri.parse('$_baseUrl/validate_import_staff.php');

      // Convertir bytes a base64
      final base64String = base64Encode(fileBytes);

      final requestData = <String, dynamic>{
        'archivo_base64': base64String,
        'nombre_archivo': fileName,
        'validate_only': true,
      };

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 60));

      //       print('[VALIDATE] Status Code: ${response.statusCode}');

      if (response.body.isEmpty) {
        return ApiResponse.error('El servidor devolvió una respuesta vacía');
      }

      try {
        final responseData = jsonDecode(response.body);

        return ApiResponse.success(
          responseData['data'] ?? {},
          responseData['message'] ?? 'Archivo validado',
        );
      } catch (jsonError) {
        return ApiResponse.error('Error procesando validación: $jsonError');
      }
    } catch (e) {
      //       print('[VALIDATE] Error: $e');
      return ApiResponse.error('Error al validar archivo: ${e.toString()}');
    }
  }

  /// Obtiene el progreso de importación en curso
  static Future<ApiResponse<Map<String, dynamic>>> getImportProgress({
    required String importId,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/import_progress.php',
      ).replace(queryParameters: {'import_id': importId});

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener progreso: ${e.toString()}');
    }
  }

  /// Cancela una importación en curso
  static Future<ApiResponse<bool>> cancelImport({
    required String importId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/cancel_import.php');

      final requestData = {'import_id': importId};

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      return _handleResponse<bool>(response, (data) => data['success'] == true);
    } catch (e) {
      return ApiResponse.error(
        'Error al cancelar importación: ${e.toString()}',
      );
    }
  }

  // ===== MÉTODOS DE RESPALDO Y RESTAURACIÓN =====

  /// Crea respaldo completo del personal
  static Future<ApiResponse<Uint8List>> createStaffBackup({
    bool includeInactive = true,
    bool includeHistory = false,
    String format = 'excel', // 'excel' o 'json'
  }) async {
    try {
      //       print('[BACKUP] Creando respaldo del personal...');

      final uri = Uri.parse('$_baseUrl/backup_staff.php');

      final requestData = <String, dynamic>{
        'include_inactive': includeInactive,
        'include_history': includeHistory,
        'format': format,
      };

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        return ApiResponse.success(
          response.bodyBytes,
          'Respaldo creado exitosamente',
        );
      } else {
        return ApiResponse.error(
          'Error al crear respaldo: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse.error('Error al crear respaldo: ${e.toString()}');
    }
  }

  // ===== MÉTODOS AUXILIARES PARA ARCHIVOS =====




}

// ===== FINAL DE LA CLASE StaffApiService =====
