/// Servicio de API para gestión de servicios
library;

/// ============================================================================
/// ARCHIVO: servicios_api_service.dart
///
/// PROPÓSITO: Servicio de API que:
/// - Centraliza todas las llamadas HTTP al backend
/// - Maneja autenticación y headers
/// - Procesa respuestas y errores
/// - Implementa métodos CRUD para servicios
/// - Gestiona endpoints relacionados (estados, funcionarios, equipos)
///
/// USO: Capa de datos usada por controllers y páginas para comunicación HTTP
/// FUNCIÓN: Capa de abstracción para todas las comunicaciones HTTP con el servidor PHP.

/// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart'; // Cross-platform File support
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import '../models/servicio_model.dart';
import '../models/estado_model.dart';
import '../models/funcionario_model.dart';
import '../models/equipo_model.dart';
import '../models/branding_model.dart';
import '../models/campo_adicional_model.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/servicio_staff_model.dart';
import '../models/cliente_model.dart'; //  NUEVO IMPORT
import '../models/service_time_log_model.dart'; // NUEVO IMPORT
import 'package:infoapp/pages/accounting/models/accounting_models.dart'; // IMPORT PARA SOD

/// Servicio para manejar todas las llamadas API relacionadas con servicios
/// ///  NUEVO: Clase para manejar entradas de cache
///  NUEVO: Clase para manejar entradas de cache
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.ttl = const Duration(minutes: 5),
  });

  bool get isValid => DateTime.now().difference(timestamp) < ttl;

  bool get isExpired => !isValid;
}

/// Entrada de caché para staff por servicio (TOP-LEVEL)
class _StaffCacheEntry {
  final List<ServicioStaffModel> staff;
  final DateTime ts;
  const _StaffCacheEntry({required this.staff, required this.ts});
}

class ServiciosApiService {
  //  NUEVO: Cache para campos por estado
  static final Map<String, CacheEntry<List<CampoAdicionalModel>>>
  _camposPorEstadoCache = {};

  /// Listar centros de costo disponibles desde el backend
  /// Crear servicio con repuestos (envía lista de IDs de repuestos)
  static Future<ApiResponse<ServicioModel>> crearServicioConRepuestos(
    ServicioModel servicio,
    List<int> repuestosIds,
  ) async {
    try {
      //       print(' [API] Creando servicio con repuestos...');

      final servicioJson = servicio.toJson();
      servicioJson.removeWhere((key, value) => value == null);
      // Agregar lista de repuestos como campo adicional
      if (repuestosIds.isNotEmpty) {
        servicioJson['repuestos'] = repuestosIds;
      }

      final authHeaders = await _getAuthHeaders();

      final token = await AuthService.getToken();
      final url =
          '$_baseUrl/servicio/crear_servicio.php${token != null ? '?token=$token' : ''}';

      final response = await http
          .post(
            Uri.parse(url),
            headers: authHeaders,
            body: jsonEncode(servicioJson),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true && result['data'] != null) {
          //           print(' [API] Servicio creado: #${result['o_servicio']}');
          return ApiResponse.success(
            data: ServicioModel.fromJson(result['data']),
            message: 'Servicio creado exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error del servidor');
        }
      } else {
        return _parseErrorResponse(response, 'Error al crear servicio');
      }
    } catch (e) {
      return ApiResponse.error('Error al crear servicio: $e');
    }
  }

  static String get _baseUrl => ServerConfig.instance.apiRoot();
  //  NUEVO: Sistema de cache para optimizar rendimiento
  static final Map<String, CacheEntry> _cacheValoresCampos = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  // Headers comunes para todas las peticiones
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  // Nuevo método para obtener headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();

    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // =====================================
  //    CLIENTES (NUEVO)
  // =====================================

  /// Obtener todos los clientes activos para el selector de servicios
  static Future<List<ClienteModel>> listarClientes({String? buscar}) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final queryParams = <String, String>{
        if (buscar != null && buscar.isNotEmpty) 'busqueda': buscar,
        'activos_solo': '1',
        'limit': '100',
      };

      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/plantillas/listar_clientes.php',
      ).replace(queryParameters: {
        ...queryParams,
        if (token != null) 'token': token,
      });

      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> data = jsonData['data'];
          return data.map((json) => ClienteModel.fromJson(json)).toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Error obteniendo clientes');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      //       print(' [API] Error obteniendo clientes: $e');
      throw Exception('Error al obtener clientes: $e');
    }
  }

  // =====================================
  //    SERVICIOS PRINCIPALES
  // =====================================

  //  CACHE: Estados por módulo (memoria) con timestamps
  static Map<String, List<EstadoModel>>? _cacheEstados;
  static Map<String, DateTime>? _tsEstados;

  //  CACHE: Equipos (memoria) con timestamps
  static List<EquipoModel>? _cacheEquipos;
  static DateTime? _tsEquipos;

  ///  NUEVO: Método con paginación
  static Future<Map<String, dynamic>> listarServicios({
    int pagina = 1,
    int limite = 20,
    String? buscar,
    String? estado,
    String? tipo,
    dynamic finalizados, //  NUEVO: Filtro server-side (true/false/'all')
  }) async {
    try {
      final queryParams = <String, String>{
        'pagina': pagina.toString(),
        'limite': limite.toString(),
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
        if (finalizados != null) 'finalizados': finalizados.toString(),
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/listar_servicios.php',
      ).replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();

      final token = await AuthService.getToken();

      // Agregar token a query params
      if (token != null) {
        queryParams['token'] = token;
      }

      final response = await http
          .get(uri.replace(queryParameters: queryParams), headers: authHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final data = jsonData['data'];
          final serviciosJson = data['servicios'] as List;
          final paginacion = data['paginacion'];

          return {
            'servicios':
                serviciosJson
                    .map((json) => ServicioModel.fromJson(json))
                    .toList(),
            'total': paginacion['total_registros'],
            'pagina': paginacion['pagina_actual'],
            'totalPaginas': paginacion['total_paginas'],
            'tieneSiguiente': paginacion['tiene_siguiente'],
            'tieneAnterior': paginacion['tiene_anterior'],
            'mensaje': jsonData['mensaje'] ?? '',
          };
        } else {
          throw Exception(
            jsonData['message'] ?? 'Error en respuesta del servidor',
          );
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      //       print(' Error en listarServicios: $e');
      throw Exception('Error obteniendo servicios: $e');
    }
  }

  ///  NUEVO: Obtener metadatos rápidos
  static Future<Map<String, dynamic>> obtenerMetadatos() async {
    try {
      //       print(' Obteniendo metadatos desde: $_baseUrl/obtener_metadatos_servicios.php');
      final authHeaders = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final url = '$_baseUrl/obtener_metadatos_servicios.php${token != null ? '?token=$token' : ''}';
      
      final response = await http
          .get(
            Uri.parse(url),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      //       print(' Metadatos status: ${response.statusCode}');
      //       print(' Metadatos body preview: ${response.body.substring(0, 100)}...');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return jsonData['data'];
        } else {
          throw Exception(jsonData['message'] ?? 'Error en metadatos');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      //       print(' Error en obtenerMetadatos: $e');
      throw Exception('Error obteniendo metadatos: $e');
    }
  }

  ///  MANTENER: Método de compatibilidad (sin paginación)
  static Future<List<ServicioModel>> listarServiciosSimple() async {
    final resultado = await listarServicios(limite: 1000); // Cargar hasta 1000
    return resultado['servicios'] as List<ServicioModel>;
  }

  /// Obtener detalle completo de un servicio por su ID
  static Future<ApiResponse<ServicioModel>> obtenerServicio(
    int servicioId,
  ) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/servicio/obtener_servicio.php',
      ).replace(queryParameters: {
        'id': servicioId.toString(),
        if (token != null) 'token': token,
      });

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return ApiResponse.success(
            data: ServicioModel.fromJson(jsonData['data']),
            message: 'Servicio obtenido exitosamente',
          );
        } else {
          return ApiResponse.error(
            jsonData['message'] ?? 'Error obteniendo servicio',
          );
        }
      } else {
        return ApiResponse.error('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error obteniendo servicio: $e');
    }
  }

  /// Obtener logs de tiempo (trazabilidad) para un servicio
  static Future<ApiResponse<List<ServiceTimeLogModel>>> obtenerLogsTiempo(
    int servicioId,
  ) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/servicio/obtener_logs_tiempo.php',
      ).replace(queryParameters: {
        'servicio_id': servicioId.toString(),
        if (token != null) 'token': token,
      });

      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final List<dynamic> logsJson = result['data'] ?? [];
          final logs =
              logsJson
                  .map((json) => ServiceTimeLogModel.fromJson(json))
                  .toList();
          return ApiResponse.success(data: logs);
        } else {
          throw Exception(
            result['message'] ?? 'Error obteniendo logs de tiempo',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error al obtener logs de tiempo: $e');
    }
  }

  /// Crear un nuevo servicio - VERSIÓN CON JWT
  static Future<ApiResponse<ServicioModel>> crearServicio(
    ServicioModel servicio,
  ) async {
    try {
      //       print(' [API] Creando servicio...');

      final servicioJson = servicio.toJson();
      servicioJson.removeWhere((key, value) => value == null);

      //  Log específico para validar tipo de mantenimiento en creación
      //       print(' [API] tipo_mantenimiento a enviar: ${servicioJson['tipo_mantenimiento'] ?? '(no definido)'}');

      final authHeaders = await _getAuthHeaders();

      final token = await AuthService.getToken();
      final url =
          '$_baseUrl/servicio/crear_servicio.php${token != null ? '?token=$token' : ''}';

      final response = await http
          .post(
            Uri.parse(url),
            headers: authHeaders,
            body: jsonEncode(servicioJson),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true && result['data'] != null) {
          //           print(' [API] Servicio creado: #${result['o_servicio']}');
          return ApiResponse.success(
            data: ServicioModel.fromJson(result['data']),
            message: 'Servicio creado exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error del servidor');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error creando servicio: $e');
      return ApiResponse.error('Error al crear servicio: $e');
    }
  }

  /// Actualizar un servicio existente - VERSIÓN CON USUARIO_ID
  static Future<ApiResponse<ServicioModel>> actualizarServicio(
    ServicioModel servicio,
  ) async {
    try {
      //       print(' [API] Actualizando servicio ID: ${servicio.id}...');

      //  MAPEO CORRECTO: Usar los nombres que espera el PHP
      final requestData = {
        'servicio_id': servicio.id,
        'orden_cliente': servicio.ordenCliente,
        'fecha_ingreso': servicio.fechaIngreso,
        'tipo_mantenimiento': servicio.tipoMantenimiento,
        'centro_costo': servicio.centroCosto,
        'autorizado_por': servicio.autorizadoPor,
        'id_equipo': servicio.idEquipo,
        'actividad_id': servicio.actividadId, //  NUEVO: Agregar actividad_id
        'suministraron_repuestos': servicio.suministraronRepuestos ?? 0,
        'fecha_finalizacion': servicio.fechaFinalizacion,
        'anular_servicio': servicio.anularServicio ?? 0,
        'razon': servicio.razon,
      };

      // Remover campos null para evitar enviar datos innecesarios
      requestData.removeWhere((key, value) => value == null);

      //       print(' [API] Datos a enviar: $requestData');

      final authHeaders = await _getAuthHeaders();

      final token = await AuthService.getToken();
      final url =
          '$_baseUrl/servicio/actualizar_servicio.php${token != null ? '?token=$token' : ''}';

      final response = await http.post(
        Uri.parse(url), // Nueva ruta con token
        headers: authHeaders, // Usar headers con autenticación
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Servicio actualizado: #${servicio.oServicio}');
          //           print('   Usuario actualizado por: ${result['usuario_actualizado_por'] ?? 'No especificado'}');
          //  NUEVO: Invalidar cache de campos adicionales al actualizar servicio
          invalidarCacheValores(servicioId: servicio.id!, modulo: 'Servicios');
          return ApiResponse.success(
            data: servicio,
            message: result['message'] ?? 'Servicio actualizado exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido del servidor',
          );
        }
      } else {
        return _parseErrorResponse(response, 'Error al actualizar servicio');
      }
    } catch (e) {
      return ApiResponse.error('Error al actualizar servicio: $e');
    }
  }

  /// Anular un servicio con razón obligatoria - VERSIÓN CON JWT
  static Future<ApiResponse<bool>> anularServicio({
    required int servicioId,
    required int estadoFinalId,
    required String razon,
  }) async {
    try {
      final authHeaders = await _getAuthHeaders();

      final token = await AuthService.getToken();
      final url =
          '$_baseUrl/servicio/anular_servicio.php${token != null ? '?token=$token' : ''}';

      final response = await http.post(
        Uri.parse(url),
        headers: authHeaders,
        body: jsonEncode({
          'servicio_id': servicioId,
          'estado_final_id': estadoFinalId,
          'razon': razon,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Servicio anulado exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido del servidor',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Error al anular servicio: $e');
    }
  }

  /// Cambiar estado de un servicio

  static Future<ApiResponse<bool>> cambiarEstadoServicio({
    required int servicioId,
    required int nuevoEstadoId,
    String? estadoOrigenNombre,
    String? estadoDestinoNombre,
    String? triggerCode,
    bool esAnulacion = false,
    String? razonAnulacion,
    bool saltarTransiciones = false,
  }) async {
    try {
      //       print(' [API] Cambiando estado del servicio $servicioId a estado $nuevoEstadoId...');

      final authHeaders = await _getAuthHeaders(); // CAMBIO: Usar JWT headers
      final token = await AuthService.getToken();
      final url =
          '$_baseUrl/servicio/cambiar_estado_servicio.php${token != null ? '?token=$token' : ''}';

      final requestData = {
        'servicio_id': servicioId,
        'nuevo_estado_id': nuevoEstadoId,
        if (estadoOrigenNombre != null)
          'estado_origen_nombre': estadoOrigenNombre,
        if (estadoDestinoNombre != null)
          'estado_destino_nombre': estadoDestinoNombre,
        if (triggerCode != null) 'trigger_code': triggerCode,
        if (esAnulacion) 'es_anulacion': true,
        if (razonAnulacion != null) 'razon_anulacion': razonAnulacion,
        if (saltarTransiciones) 'saltar_transiciones': true,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: authHeaders, // CAMBIO: Usar authHeaders en lugar de _headers
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Estado cambiado exitosamente');
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Estado actualizado exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido del servidor',
          );
        }
      } else {
        return _parseErrorResponse(response, 'Error al cambiar estado');
      }
    } catch (e) {
      return ApiResponse.error('Error al cambiar estado: $e');
    }
  }
  // =====================================
  //    DESBLOQUEO DE REPUESTOS
  // =====================================

  /// Desbloquear repuestos para un servicio firmado
  /// Requiere permiso especial en el backend
  static Future<ApiResponse<bool>> desbloquearRepuestos({
    required int servicioId,
    required String motivo,
  }) async {
    try {
      final authHeaders = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/desbloquear_repuestos.php'),
        headers: authHeaders,
        body: jsonEncode({
          'servicio_id': servicioId,
          'motivo': motivo, // Motivo de auditoría
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // Invalidar caché del servicio si es necesario
          return ApiResponse.success(
            data: true,
            message:
                result['message'] ?? 'Repuestos desbloqueados exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 403) {
        throw Exception('No tienes permiso para desbloquear repuestos');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ApiResponse.error('Error al desbloquear repuestos: $e');
    }
  }

  // =====================================
  //    CONFIRMAR TRIGGERS
  // =====================================

  /// Confirmar que un trigger ha sido completado (repuestos, fotos, firma)
  /// Marca el flag correspondiente en la tabla servicios
  static Future<ApiResponse<bool>> confirmarTrigger({
    required int servicioId,
    required String triggerType, // 'repuestos', 'fotos', 'firma'
  }) async {
    try {
      final authHeaders = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/confirmar_trigger.php'),
        headers: authHeaders,
        body: jsonEncode({
          'servicio_id': servicioId,
          'trigger_type': triggerType,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return ApiResponse.success(
            data: true,
            message:
                result['message'] ?? 'Confirmación registrada exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error desconocido');
        }
      } else {
        return _parseErrorResponse(response, 'Error al confirmar trigger');
      }
    } catch (e) {
      return ApiResponse.error('Error al confirmar trigger: $e');
    }
  }

  // =====================================
  //    AUDITORÍA FINANCIERA (SoD)
  // =====================================

  /// Consultar el estado de auditoría para un servicio
  static Future<ApiResponse<AuditoriaFinancieraModel>> checkAuditoria(
    int servicioId,
  ) async {
    try {
      final token = await AuthService.getToken();
      final authHeaders = await _getAuthHeaders();
      final url =
          '${ServerConfig.instance.baseUrlFor('accounting')}/check_auditoria.php?servicio_id=$servicioId${token != null ? '&token=$token' : ''}';

      final response = await http
          .get(Uri.parse(url), headers: authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return ApiResponse.success(
            data: AuditoriaFinancieraModel.fromJson(result['data']),
          );
        } else {
          throw Exception(result['message'] ?? 'Error consultando auditoría');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error al consultar auditoría: $e');
    }
  }

  /// Registrar una auditoría para un servicio
  static Future<ApiResponse<bool>> registrarAuditoria({
    required int servicioId,
    required String comentario,
  }) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final url =
          '${ServerConfig.instance.baseUrlFor('accounting')}/registrar_auditoria.php';

      final response = await http.post(
        Uri.parse(url),
        headers: authHeaders,
        body: jsonEncode({'servicio_id': servicioId, 'comentario': comentario}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Auditoría registrada correctamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error registrando auditoría');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Error al registrar auditoría: $e');
    }
  }

  /// Refrescar datos de sesión del usuario actual
  static Future<ApiResponse<Map<String, dynamic>>> refreshUserData() async {
    try {
      final token = await AuthService.getToken();
      final authHeaders = await _getAuthHeaders();
      final url = '$_baseUrl/login/perfil.php${token != null ? '?token=$token' : ''}';

      final response = await http
          .get(Uri.parse(url), headers: authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final userData = result['data'] as Map<String, dynamic>;

          // Actualizar SharedPreferences vía AuthService (necesitamos el token actual)
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token') ?? '';
          final tokenType = prefs.getString('token_type') ?? 'Bearer';
          final expiresAt = prefs.getString('expires_at') ?? '';

          await AuthService.saveAuthData(
            token: token,
            tokenType: tokenType,
            expiresAt: expiresAt,
            userData: userData,
          );

          return ApiResponse.success(data: userData);
        } else {
          throw Exception(result['message'] ?? 'Error refrescando perfil');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('DEBUG: Error en refreshUserData: $e');
      return ApiResponse.error('Error al refrescar datos: $e');
    }
  }

  // =====================================
  //    ESTADOS
  // =====================================

  /// Obtener estado inicial del flujo
  static Future<EstadoModel?> obtenerEstadoInicial() async {
    try {
      //       print(' [API] Obteniendo estado inicial...');

      final response = await http.get(
        Uri.parse('$_baseUrl/workflow/obtener_estado_inicial.php'),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true && result['estado'] != null) {
          final estado = EstadoModel.fromJson(result['estado']);
          //           print(' [API] Estado inicial: ${estado.nombre}');
          return estado;
        } else {
          throw Exception(result['message'] ?? 'No se encontró estado inicial');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error obteniendo estado inicial: $e');
      return null;
    }
  }

  // =====================================
  //     CAMPOS ADICIONALES - MÉTODOS COMPLETOS
  // =====================================

  ///  Obtener campos adicionales por estado
  ///  NUEVO: Método síncrono para verificar cache (evita spinner)
  static List<CampoAdicionalModel>? obtenerCamposDesdeCache({
    required int estadoId,
    String modulo = 'Servicios',
  }) {
    final cacheKey = '${modulo}_$estadoId';
    if (_camposPorEstadoCache.containsKey(cacheKey)) {
      final cached = _camposPorEstadoCache[cacheKey]!;
      if (cached.isValid) {
        return cached.data;
      }
    }
    return null;
  }

  static Future<List<CampoAdicionalModel>> obtenerCamposPorEstado({
    required int estadoId,
    String modulo = 'Servicios',
  }) async {
    //  OPTIMIZACIÓN: Cache de campos por estado
    final cacheKey = '${modulo}_$estadoId';

    // Verificar si ya está en caché
    if (_camposPorEstadoCache.containsKey(cacheKey)) {
      final cached = _camposPorEstadoCache[cacheKey]!;
      // Cache válido por 5 minutos
      if (DateTime.now().difference(cached.timestamp).inMinutes < 5) {
        return cached.data;
      }
    }

    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '$_baseUrl/core/fields/obtener_campos_por_estado.php?estado_id=$estadoId&modulo=$modulo',
      );

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Limpiar respuesta de contenido extra que pueda enviar PHP
        String cleanResponse = response.body.trim();
        int jsonStart = cleanResponse.indexOf('{');
        if (jsonStart > 0) {
          cleanResponse = cleanResponse.substring(jsonStart);
        }

        final result = jsonDecode(cleanResponse);

        if (result['success'] == true) {
          final List<dynamic> camposData = result['campos'] ?? [];
          var campos =
              camposData
                  .map((json) => CampoAdicionalModel.fromJson(json))
                  .toList();

          //  Guardar en caché
          _camposPorEstadoCache[cacheKey] = CacheEntry(
            data: campos,
            timestamp: DateTime.now(),
          );

          // No sobreescribir el módulo: si viene vacío, se conserva vacío.
          // El filtrado por módulo se realiza en la UI y servicios específicos.

          //           print(' [API] ${campos.length} campos adicionales cargados');
          for (var campo in campos) {
            //             print('   Campo: ${campo.nombreCampo} (${campo.tipoCampo})');
          }

          return campos;
        } else {
          //           print(' [API] No hay campos adicionales para este estado');
          return [];
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error obteniendo campos adicionales: $e');
      return []; // Retornar lista vaca en caso de error
    }
  }

  ///  Obtener valores existentes de campos adicionales - CON CACHE INTELIGENTE
  static Future<Map<int, dynamic>> obtenerValoresCamposAdicionales({
    required int servicioId,
    String modulo = 'Servicios',
  }) async {
    try {
      //       print(' [API] Cargando valores de campos adicionales para servicio: $servicioId...');

      final claveCache = _generarClaveCacheValores(
        servicioId: servicioId,
        modulo: modulo,
      );

      // 1. Verificar cache en memoria primero
      if (_tieneCacheValido(claveCache)) {
        final datosCache = _obtenerDelCache(claveCache);
        if (datosCache != null) {
          //           print(' [CACHE MEMORIA] Retornando datos desde cache en memoria (${datosCache.length} valores)');
          return datosCache;
        }
      }

      // 2. Verificar cache persistente
      final cachePersistente = await _cargarCachePersistente(claveCache);
      String? ultimoTimestamp = cachePersistente?['timestamp'];

      // 3. Verificar si hay cambios en el servidor
      final hayCambios = await _verificarCambiosEnServidor(
        servicioId: servicioId,
        ultimoTimestamp: ultimoTimestamp,
      );

      // 4. Si no hay cambios y tenemos cache persistente, usarlo
      if (!hayCambios && cachePersistente != null) {
        final datos = cachePersistente['datos'] as Map<int, dynamic>;

        // Guardar tambin en cache de memoria
        _guardarEnCache(claveCache, datos);

        //         print(' [CACHE PERSISTENTE] Retornando datos sin cambios (${datos.length} valores)');
        return datos;
      }

      // 5. Consultar servidor si hay cambios o no hay cache
      //       print(' [API] Consultando servidor (hay cambios: $hayCambios)...');

      final url =
          '$_baseUrl/core/fields/obtener_valores_campos_adicionales.php?servicio_id=$servicioId&modulo=$modulo';
      final authHeaders = await _getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: authHeaders);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final Map<int, dynamic> valores = {};
          final List<dynamic> valoresData = result['valores'] ?? [];
          String nuevoTimestamp = DateTime.now().toIso8601String();

          for (var valor in valoresData) {
            final campoId = int.tryParse(valor['campo_id'].toString());
            if (campoId != null) {
              valores[campoId] = _procesarValorCampo(valor);

              // Usar timestamp del servidor si est disponible
              if (valor['ultima_modificacion'] != null) {
                nuevoTimestamp = valor['ultima_modificacion'];
              }
            }
          }

          // Guardar en ambos caches
          _guardarEnCache(claveCache, valores);
          await _guardarCachePersistente(claveCache, valores, nuevoTimestamp);

          //           print(' [API] ${valores.length} valores de campos cargados desde servidor');
          return valores;
        } else {
          //           print(' [API] No hay valores existentes para los campos adicionales');

          // Guardar cache vacío
          final timestampVacio = DateTime.now().toIso8601String();
          _guardarEnCache(claveCache, {});
          await _guardarCachePersistente(claveCache, {}, timestampVacio);
          return {};
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error obteniendo valores de campos: $e');

      // Fallback: intentar cache persistente aunque haya error
      final claveCache = _generarClaveCacheValores(
        servicioId: servicioId,
        modulo: modulo,
      );
      final cachePersistente = await _cargarCachePersistente(claveCache);
      if (cachePersistente != null) {
        final datos = cachePersistente['datos'] as Map<int, dynamic>;
        //         print(' [CACHE PERSISTENTE] Devolviendo cache como fallback de error');
        return datos;
      }

      return {};
    }
  }

  ///  Guardar valores de campos adicionales
  static Future<ApiResponse<bool>> guardarValoresCamposAdicionales({
    required int servicioId,
    required List<CampoAdicionalModel> campos,
    required Map<int, dynamic> valores,
    String modulo = 'Servicios',
  }) async {
    try {
      //       print(' [API] Guardando valores de campos adicionales...');

      // Validar campos obligatorios
      final erroresValidacion = _validarCamposObligatorios(campos, valores);
      if (erroresValidacion.isNotEmpty) {
        return ApiResponse.error(
          'Campos obligatorios faltantes: ${erroresValidacion.join(', ')}',
        );
      }

      // Preparar datos en el formato correcto
      final List<Map<String, dynamic>> camposParaGuardar = [];

      for (var campo in campos) {
        final valor = valores[campo.id];
        if (valor != null) {
          final valorProcesado = _prepararValorParaGuardar(campo, valor);
          if (valorProcesado != null) {
            camposParaGuardar.add({
              'campo_id': campo.id,
              'valor': valorProcesado,
            });
          }
        }
      }

      if (camposParaGuardar.isEmpty) {
        //         print(' [API] No hay campos válidos para guardar');
        return ApiResponse.success(
          data: true,
          message: 'No hay datos para guardar',
        );
      }

      // Enviar al servidor
      final requestData = {
        'servicio_id': servicioId,
        'modulo': modulo,
        'campos': camposParaGuardar,
      };

      //       print(' [API] Enviando ${camposParaGuardar.length} campos...');

      final authHeaders = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse(
          '$_baseUrl/core/fields/guardar_valores_campos_adicionales_nuevo.php',
        ),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Campos adicionales guardados exitosamente');
          //  NUEVO: Invalidar cache después de guardar
          invalidarCacheValores(servicioId: servicioId, modulo: modulo);
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Campos guardados exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido del servidor',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error guardando campos adicionales: $e');
      return ApiResponse.error('Error al guardar campos adicionales: $e');
    }
  }

  ///  Subir archivo para campo adicional
  static Future<ApiResponse<Map<String, dynamic>>> subirArchivoCampoAdicional({
    required int servicioId,
    required int campoId,
    required XFile archivo,
    required String tipoCampo, // Este parámetro define el tipo
  }) async {
    try {
      //       print(' [API] Subiendo archivo para campo $campoId...');

      final Uint8List bytes = await archivo.readAsBytes();
      final String base64File = base64Encode(bytes);

      // Detectar extensión
      final extension = archivo.name.split('.').last.toLowerCase();

      //  CAMBIO: Respetar el tipoCampo recibido del widget
      // Solo detectar si es imagen cuando el tipo es explícitamente "Imagen"
      final esImagenPorExtension = [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'svg',
      ].contains(extension);

      // Si el tipo del campo es "Archivo", forzar como archivo aunque sea imagen
      final tipoReal =
          tipoCampo.toLowerCase() == 'imagen' && esImagenPorExtension
              ? 'Imagen'
              : 'Archivo';

      final tipoFolder = tipoReal == 'Imagen' ? 'imagenes' : 'archivos';

      final String fileName =
          'servicio_${servicioId}_campo_${campoId}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final requestData = {
        'servicio_id': servicioId.toString(),
        'campo_id': campoId.toString(),
        'tipo_campo': tipoReal,
        'archivo_base64': base64File,
        'nombre_archivo': fileName,
        'descripcion': '$tipoReal para campo $campoId del servicio $servicioId',
        'extension': extension,
        'carpeta_destino': tipoFolder,
      };

      //       print(' [API] Enviando archivo: ${archivo.name} (${bytes.length} bytes) como tipo: $tipoReal');

      final authHeaders = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/core/fields/subir_archivo_campo_adicional.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final datosRespuesta = result['datos'];
          final estructuraArchivo = {
            'tipo': tipoReal.toLowerCase(),
            'nombre': datosRespuesta['nombre_almacenado'] ?? fileName,
            'nombre_original': archivo.name,
            'es_existente': true,
            'extension': extension,
            'ruta_publica':
                datosRespuesta['ruta_publica'] ??
                'uploads/campos_adicionales/$tipoFolder/$fileName',
            'url_completa':
                '$_baseUrl/core/fields/ver_archivo_campo.php?ruta=${datosRespuesta['ruta_publica'] ?? 'uploads/campos_adicionales/$tipoFolder/$fileName'}',
          };

          //           print(' [API] Archivo subido exitosamente: ${archivo.name}');
          return ApiResponse.success(
            data: estructuraArchivo,
            message: '$tipoReal subido exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido del servidor',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error subiendo archivo: $e');
      return ApiResponse.error('Error al subir archivo: $e');
    }
  }

  ///  Subir archivo desde file picker para campo adicional
  static Future<ApiResponse<Map<String, dynamic>>> subirArchivoPlatformFile({
    required int servicioId,
    required int campoId,
    required PlatformFile archivo,
  }) async {
    try {
      //       print(' [API] Subiendo archivo platform para campo $campoId...');

      Uint8List? bytes;
      if (archivo.bytes != null) {
        bytes = archivo.bytes!;
      } else if (archivo.path != null) {
        // En móvil, leer desde la ruta del archivo
        try {
          final file = File(archivo.path!);
          bytes = await file.readAsBytes();
        } catch (e) {
          throw Exception('No se pudo leer el archivo desde la ruta: $e');
        }
      } else {
        throw Exception('No se pudieron obtener los bytes del archivo');
      }

      final String base64File = base64Encode(bytes);
      final String fileName =
          'campo_${campoId}_${DateTime.now().millisecondsSinceEpoch}_${archivo.name}';

      final requestData = {
        'servicio_id': servicioId.toString(),
        'campo_id': campoId.toString(),
        'tipo_campo': 'archivo',
        'archivo_base64': base64File,
        'nombre_archivo': fileName,
        'descripcion': 'Archivo para campo $campoId del servicio $servicioId',
      };

      //       print(' [API] Enviando archivo: ${archivo.name} (${bytes.length} bytes)');

      final authHeaders = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/core/fields/subir_archivo_campo_adicional.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final estructuraArchivo = {
            'tipo': 'archivo',
            'nombre': result['datos']['nombre_almacenado'],
            'nombre_original': result['datos']['nombre_original'],
            'es_existente': true,
            'extension': result['datos']['extension'],
            'size': archivo.size,
          };

          //           print(' [API] Archivo platform subido exitosamente: ${archivo.name}');
          return ApiResponse.success(
            data: estructuraArchivo,
            message: 'Archivo subido exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error desconocido');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error subiendo archivo platform: $e');
      return ApiResponse.error('Error al subir archivo: $e');
    }
  }

  // =====================================
  //     MÉTODOS AUXILIARES PARA CAMPOS ADICIONALES
  // =====================================
  /// Procesar valor según tipo de campo al cargar desde BD
  static dynamic _procesarValorCampo(Map<String, dynamic> valor) {
    final valorCampo = valor['valor'];
    final tipoCampo = (valor['tipo_campo']?.toString() ?? '').toLowerCase();

    switch (tipoCampo) {
      case 'fecha':
        try {
          return DateTime.parse(valorCampo.toString());
        } catch (e) {
          //           print(' Error parseando fecha: $valorCampo');
          return null;
        }
      case 'datetime':
      case 'fecha y hora':
        try {
          return DateTime.parse(valorCampo.toString());
        } catch (e) {
          //           print(' Error parseando fecha y hora: $valorCampo');
          return null;
        }
      case 'entero':
        return int.tryParse(valorCampo.toString());
      case 'decimal':
      case 'moneda':
        return double.tryParse(valorCampo.toString());
      case 'imagen':
        if (valorCampo.toString().isNotEmpty) {
          final nombreArchivo = valorCampo.toString();
          final extension = nombreArchivo.split('.').last.toLowerCase();

          //  RETORNAR ESTRUCTURA COMPLETA
          return {
            'tipo': 'imagen',
            'nombre': nombreArchivo,
            'nombre_original': nombreArchivo,
            'es_existente': true,
            'extension': extension,
            'ruta_publica':
                'uploads/campos_adicionales/imagenes/$nombreArchivo',
            'url_completa':
                '$_baseUrl/core/fields/ver_archivo_campo.php?ruta=uploads/campos_adicionales/imagenes/$nombreArchivo',
          };
        }
        return null;
      case 'archivo':
        if (valorCampo.toString().isNotEmpty) {
          final nombreArchivo = valorCampo.toString();
          final extension = nombreArchivo.split('.').last.toLowerCase();

          //  RETORNAR ESTRUCTURA COMPLETA
          return {
            'tipo': 'archivo',
            'nombre': nombreArchivo,
            'nombre_original': nombreArchivo,
            'es_existente': true,
            'extension': extension,
            'ruta_publica':
                'uploads/campos_adicionales/archivos/$nombreArchivo',
            'url_completa':
                '$_baseUrl/core/fields/ver_archivo_campo.php?ruta=uploads/campos_adicionales/archivos/$nombreArchivo',
          };
        }
        return null;
      default:
        return valorCampo.toString();
    }
  }

  /// Preparar valor para guardar en BD
  static String? _prepararValorParaGuardar(
    CampoAdicionalModel campo,
    dynamic valor,
  ) {
    switch (campo.tipoCampo.toLowerCase()) {
      case 'fecha':
        if (valor is DateTime) {
          return valor.toIso8601String().split('T')[0]; // Solo fecha YYYY-MM-DD
        }
        break;
      case 'datetime':
      case 'fecha y hora':
        if (valor is DateTime) {
          final y = valor.year.toString().padLeft(4, '0');
          final m = valor.month.toString().padLeft(2, '0');
          final d = valor.day.toString().padLeft(2, '0');
          final hh = valor.hour.toString().padLeft(2, '0');
          final mm = valor.minute.toString().padLeft(2, '0');
          final ss = valor.second.toString().padLeft(2, '0');
          return '$y-$m-$d $hh:$mm:$ss'; // Formato compatible MySQL DATETIME
        } else if (valor is String && valor.trim().isNotEmpty) {
          return valor.trim();
        }
        break;
      case 'hora':
        return valor.toString();
      case 'entero':
        if (valor is int) {
          return valor.toString();
        } else if (valor is String && int.tryParse(valor) != null) {
          return valor;
        }
        break;
      case 'Decimal':
      case 'Moneda':
        if (valor is double) {
          return valor.toString();
        } else if (valor is String && double.tryParse(valor) != null) {
          return valor;
        }
        break;
      case 'Imagen':
        if (valor is Map && valor['tipo'] == 'imagen') {
          return valor['nombre'] ?? '';
        }
        break;
      case 'Archivo':
        if (valor is Map && valor['tipo'] == 'archivo') {
          return valor['nombre'] ?? '';
        }
        break;
      default:
        return valor.toString();
    }
    return null;
  }

  /// Validar campos obligatorios
  static List<String> _validarCamposObligatorios(
    List<CampoAdicionalModel> campos,
    Map<int, dynamic> valores,
  ) {
    final List<String> errores = [];

    for (var campo in campos) {
      if (campo.obligatorio) {
        final valor = valores[campo.id];
        if (valor == null ||
            (valor is String && valor.trim().isEmpty) ||
            (valor is Map &&
                (valor['nombre'] == null ||
                    valor['nombre'].toString().isEmpty))) {
          errores.add(campo.nombreCampo);
        }
      }
    }

    return errores;
  }

  // =====================================
  //    FUNCIONARIOS (EXISTENTE)
  // =====================================

  /// Crear un nuevo funcionario - VERSIÓN FINAL CORREGIDA
  static Future<ApiResponse<FuncionarioModel>> crearFuncionario({
    required String nombre,
    String? cargo,
    String? empresa,
    String? telefono,
    String? correo,
    int? clienteId,
  }) async {
    try {
      //       print(' [API] Creando funcionario: $nombre...');

      final authHeaders = await _getAuthHeaders();
      final requestData = {
        'nombre': nombre.trim(),
        if (cargo != null && cargo.isNotEmpty) 'cargo': cargo.trim(),
        if (empresa != null && empresa.isNotEmpty) 'empresa': empresa.trim(),
        if (telefono != null && telefono.isNotEmpty)
          'telefono': telefono.trim(),
        if (correo != null && correo.isNotEmpty) 'correo': correo.trim(),
        if (clienteId != null) 'cliente_id': clienteId,
      };

      //       print(' [API] JSON data a enviar: $requestData');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/funcionarios/crear_funcionario.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final funcionario = FuncionarioModel(
            id: result['funcionario_id'],
            nombre: nombre.trim(),
            cargo: cargo?.trim(),
            empresa: empresa?.trim(),
            telefono: telefono?.trim(),
            correo: correo?.trim(),
            activo: true,
            clienteId: clienteId,
          );

          //           print(' [API] Funcionario creado: ${funcionario.nombre}');
          return ApiResponse.success(
            data: funcionario,
            message: result['message'] ?? 'Funcionario creado exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido al crear funcionario',
          );
        }
      } else if (response.statusCode == 401) {
        //         print(' Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return ApiResponse.error('Error de autenticación');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error creando funcionario: $e');
      return ApiResponse.error('Error al crear funcionario: $e');
    }
  }

  /// Actualizar un funcionario existente - VERSIÓN JSON CORREGIDA
  static Future<ApiResponse<FuncionarioModel>> actualizarFuncionario({
    required int funcionarioId,
    required String nombre,
    String? cargo,
    String? empresa,
    String? telefono,
    String? correo,
    int? clienteId,
  }) async {
    try {
      //       print(' [API] Actualizando funcionario ID: $funcionarioId...');

      final authHeaders = await _getAuthHeaders();
      final requestData = {
        'funcionario_id': funcionarioId,
        'nombre': nombre.trim(),
        'cargo': cargo?.trim() ?? '',
        'empresa': empresa?.trim() ?? '',
        'telefono': telefono?.trim() ?? '',
        'correo': correo?.trim() ?? '',
        if (clienteId != null) 'cliente_id': clienteId,
      };

      //       print(' [API] JSON data a enviar: $requestData');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/funcionarios/editar_funcionario.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final funcionario = FuncionarioModel(
            id: funcionarioId,
            nombre: nombre.trim(),
            cargo: cargo?.trim(),
            empresa: empresa?.trim(),
            telefono: telefono?.trim(),
            correo: correo?.trim(),
            activo: true,
            clienteId: clienteId,
          );

          //           print(' [API] Funcionario actualizado: ${funcionario.nombre}');
          return ApiResponse.success(
            data: funcionario,
            message:
                result['message'] ?? 'Funcionario actualizado exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido al actualizar funcionario',
          );
        }
      } else if (response.statusCode == 401) {
        //         print(' Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return ApiResponse.error('Error de autenticación');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error actualizando funcionario: $e');
      return ApiResponse.error('Error al actualizar funcionario: $e');
    }
  }

  /// Eliminar (desactivar) un funcionario - VERSIÓN CORREGIDA
  static Future<ApiResponse<bool>> eliminarFuncionario(
    int funcionarioId,
  ) async {
    try {
      //       print(' [API] Eliminando funcionario ID: $funcionarioId...');

      final authHeaders = await _getAuthHeaders();
      final requestData = {'funcionario_id': funcionarioId};

      //       print(' [API] Datos a enviar: $requestData');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/funcionarios/eliminar_funcionario.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 10));

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Funcionario eliminado exitosamente');
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Funcionario eliminado exitosamente',
          );
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido al eliminar funcionario',
          );
        }
      } else if (response.statusCode == 401) {
        //         print(' Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return ApiResponse.error('Error de autenticación');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error eliminando funcionario: $e');
      return ApiResponse.error('Error al eliminar funcionario: $e');
    }
  }

  /// Obtener un funcionario específico por ID
  static Future<ApiResponse<FuncionarioModel>> obtenerFuncionario(
    int funcionarioId,
  ) async {
    try {
      //       print(' [API] Obteniendo funcionario ID: $funcionarioId...');

      final authHeaders = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/funcionarios/obtener_funcionario.php?funcionario_id=$funcionarioId',
        ),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true && result['funcionario'] != null) {
          final funcionario = FuncionarioModel.fromJson(result['funcionario']);
          //           print(' [API] Funcionario obtenido: ${funcionario.nombre}');
          return ApiResponse.success(data: funcionario);
        } else {
          throw Exception(result['message'] ?? 'Funcionario no encontrado');
        }
      } else if (response.statusCode == 401) {
        //         print(' Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return ApiResponse.error('Error de autenticación');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error obteniendo funcionario: $e');
      return ApiResponse.error('Error al obtener funcionario: $e');
    }
  }

  /// Obtener todos los funcionarios activos
  static Future<List<FuncionarioModel>> listarFuncionarios({
    String? empresa,
    int? clienteId,
  }) async {
    try {
      final isOnline = await ConnectivityService.instance.checkNow();
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'cache_funcionarios_v2';

      // Solo usar caché offline si no hay filtros y no hay conexión
      if (!isOnline &&
          (empresa == null || empresa.isEmpty) &&
          clienteId == null) {
        final cached = await _loadFuncionariosFromCache();
        if (cached.isNotEmpty) return cached;
      }

      final authHeaders = await _getAuthHeaders();

      final queryParams = <String, String>{};
      if (clienteId != null && clienteId > 0) {
        queryParams['cliente_id'] = clienteId.toString();
      } else if (empresa != null && empresa.isNotEmpty) {
        queryParams['empresa'] = empresa;
      }

      final uri = Uri.parse(
        '$_baseUrl/funcionarios/listar_funcionarios.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        List<dynamic> funcionariosData = [];

        if (responseData is Map && responseData['success'] == true) {
          funcionariosData =
              (responseData['funcionarios'] as List<dynamic>? ?? []);
        } else if (responseData is List) {
          funcionariosData = responseData;
        } else if (responseData is Map && responseData['success'] == false) {
          // Fallback a caché solo si NO hay filtro de empresa
          if (empresa == null || empresa.isEmpty) {
            final cached = await _loadFuncionariosFromCache();
            if (cached.isNotEmpty) return cached;
          }
          throw Exception(responseData['message'] ?? 'Error del servidor');
        } else {
          // Formato inesperado
          if (empresa == null || empresa.isEmpty) {
            final cached = await _loadFuncionariosFromCache();
            if (cached.isNotEmpty) return cached;
          }
          throw Exception('Formato de respuesta inesperado');
        }

        // Guardar caché SOLO si no hay filtro (lista completa)
        if (empresa == null || empresa.isEmpty) {
          try {
            final payload = jsonEncode({
              'items': funcionariosData,
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
            await prefs.setString(cacheKey, payload);
          } catch (_) {}
        }

        return funcionariosData
            .map(
              (json) => FuncionarioModel.fromJson(
                (json as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
      } else if (response.statusCode == 401) {
        await AuthService.clearAuthData();
        throw Exception('Error de autenticación');
      } else {
        // Fallback a caché solo si NO hay filtro de empresa
        if (empresa == null || empresa.isEmpty) {
          final cached = await _loadFuncionariosFromCache();
          if (cached.isNotEmpty) return cached;
        }
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Fallback final a caché solo si NO hay filtro de empresa
      if (empresa == null || empresa.isEmpty) {
        final cached = await _loadFuncionariosFromCache();
        if (cached.isNotEmpty) return cached;
      }
      throw Exception('Error al cargar funcionarios: $e');
    }
  }

  /// Cargar funcionarios desde el caché
  static Future<List<FuncionarioModel>> _loadFuncionariosFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'cache_funcionarios';
      final raw = prefs.getString(cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        List<dynamic> items =
            (decoded is Map) ? (decoded['items'] ?? []) : decoded;
        return items
            .map(
              (json) => FuncionarioModel.fromJson(
                (json as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // =========================================================================
  // MÉTODOS PARA IMPORTACIÓN Y EXPORTACIÓN DE FUNCIONARIOS EN EXCEL
  // =========================================================================

  /// Exportar funcionarios en formato Excel (.xlsx)
  static Future<ApiResponse<Uint8List>> exportarFuncionariosExcel({
    bool incluirInactivos = false,
  }) async {
    try {
      //       print(' [API] Exportando funcionarios a Excel...');

      final authHeaders = await _getAuthHeaders();

      final queryParams = {'incluir_inactivos': incluirInactivos.toString()};

      final uri = Uri.parse(
        '$_baseUrl/funcionarios/exportar_funcionarios_excel.php',
      ).replace(queryParameters: queryParams);

      //       print(' [API] URL: $uri');

      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));

      //       print(' [API] Export status: ${response.statusCode}');
      //       print(' [API] Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        // Verificar que sea realmente un archivo Excel
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('spreadsheet') ||
            contentType.contains('excel')) {
          final bytes = response.bodyBytes;
          //           print(' [API] Excel exportado (${bytes.length} bytes)');
          return ApiResponse.success(
            data: bytes,
            message: 'Excel exportado exitosamente',
          );
        } else {
          // Es una respuesta JSON de error
          try {
            final errorData = jsonDecode(response.body);
            throw Exception(errorData['message'] ?? 'Error desconocido');
          } catch (e) {
            throw Exception('Respuesta inesperada del servidor');
          }
        }
      } else if (response.statusCode == 401) {
        //         print(' Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return ApiResponse.error('Error de autenticación');
      } else {
        // Intentar parsear error JSON
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(
            errorData['message'] ?? 'Error HTTP ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'Error HTTP ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      //       print(' [API] Error exportando Excel: $e');
      return ApiResponse.error('Error al exportar Excel: $e');
    }
  }

  /// Guardar archivo Excel exportado
  static Future<ApiResponse<String>> exportarYGuardarExcel({
    bool incluirInactivos = false,
  }) async {
    try {
      //       print(' [API] Exportando y guardando Excel...');

      final exportResult = await exportarFuncionariosExcel(
        incluirInactivos: incluirInactivos,
      );

      if (!exportResult.isSuccess || exportResult.data == null) {
        return ApiResponse.error(exportResult.error ?? 'Error exportando');
      }

      final bytes = exportResult.data!;
      final fileName =
          'funcionarios_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      await dl.saveBytes(
        fileName,
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      //       print(' [API] Excel descargado/guardado: $fileName');
      return ApiResponse.success(
        data: fileName,
        message: 'Excel exportado y descargado exitosamente',
      );
    } catch (e) {
      //       print(' [API] Error guardando Excel: $e');
      return ApiResponse.error('Error al guardar Excel: $e');
    }
  }

  /// Importar funcionarios desde archivo Excel
  static Future<ApiResponse<Map<String, dynamic>>>
  importarFuncionariosDesdeExcel({
    required Uint8List excelBytes,
    String modo =
        'crear_o_actualizar', // 'crear', 'actualizar', 'crear_o_actualizar'
    bool sobrescribirExistentes = false,
  }) async {
    try {
      //       print(' [API] Importando funcionarios desde Excel...');
      //       print(' [API] Tamaño del archivo: ${excelBytes.length} bytes');

      final authHeaders = await _getAuthHeaders();

      // Convertir bytes a base64
      final base64Excel = base64Encode(excelBytes);

      // Algunos endpoints esperan 'archivo_base64' y otros 'excel_base64'.
      // Enviamos ambos para maximizar compatibilidad.
      final requestData = {
        'archivo_base64': base64Excel,
        'excel_base64': base64Excel,
        'modo': modo,
        'sobrescribir_existentes': sobrescribirExistentes,
      };

      //       print(' [API] Enviando archivo (${base64Excel.length} caracteres en base64)...');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/funcionarios/importar_funcionarios_excel.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(
            const Duration(seconds: 60),
          ); // Timeout ms largo para archivos grandes

      //       print(' [API] Import status: ${response.statusCode}');
      //       print(' [API] Import body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final resultados = result['data']['resultados'];
          //           print(' [API] Importación completada:');
          //           print('   Total filas: ${result['data']['total_filas']}');
          //           print('   Insertados: ${resultados['insertados']}');
          //           print('   Actualizados: ${resultados['actualizados']}');
          //           print('   Omitidos: ${resultados['omitidos']}');
          //           print('   Errores: ${resultados['errores'].length}');

          if (resultados['errores'].length > 0) {
            //             print(' [API] Errores encontrados:');
            for (var error in resultados['errores']) {
              //               print('   - $error');
            }
          }

          return ApiResponse.success(
            data: result['data'],
            message: result['message'],
          );
        } else {
          throw Exception(result['message'] ?? 'Error importando Excel');
        }
      } else if (response.statusCode == 401) {
        //         print(' Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return ApiResponse.error('Error de autenticación');
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error importando Excel: $e');
      return ApiResponse.error('Error al importar Excel: $e');
    }
  }

  /// Seleccionar y leer archivo Excel desde el dispositivo
  static Future<Uint8List?> seleccionarArchivoExcel() async {
    try {
      //       print(' [API] Abriendo selector de archivos...');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes != null) {
          //           print(' [API] Archivo seleccionado: ${file.name} (${file.bytes!.length} bytes)');
          return file.bytes!;
        } else {
          //           print(' [API] No se pudieron leer los bytes del archivo seleccionado');
          return null;
        }
      }

      //       print(' [API] No se seleccionó ningún archivo');
      return null;
    } catch (e) {
      //       print(' [API] Error seleccionando archivo: $e');
      return null;
    }
  }

  /// Flujo completo: Seleccionar e importar Excel
  static Future<ApiResponse<Map<String, dynamic>>> seleccionarEImportarExcel({
    String modo = 'crear_o_actualizar',
    bool sobrescribirExistentes = false,
  }) async {
    try {
      // Paso 1: Seleccionar archivo
      final bytes = await seleccionarArchivoExcel();

      if (bytes == null) {
        return ApiResponse.error('No se seleccionó ningún archivo');
      }

      // Paso 2: Importar
      return await importarFuncionariosDesdeExcel(
        excelBytes: bytes,
        modo: modo,
        sobrescribirExistentes: sobrescribirExistentes,
      );
    } catch (e) {
      //       print(' [API] Error en flujo de importación: $e');
      return ApiResponse.error('Error: $e');
    }
  }

  // =====================================
  //    EQUIPOS (EXISTENTE)
  // =====================================

  /// Obtener todos los equipos - VERSIÓN CON JWT
  static Future<List<EquipoModel>> listarEquipos({int? clienteId}) async {
    try {
      // Si hay clienteId, no usar caché offline simple
      final bool usarCache = clienteId == null;
      // Caché offline
      final prefs = await SharedPreferences.getInstance();
      // 1) Intentar cache en memoria si no está expirado
      final DateTime now = DateTime.now();
      final Duration ttlEquipos = const Duration(minutes: 30);

      if (usarCache && _cacheEquipos != null && _tsEquipos != null) {
        if (now.difference(_tsEquipos!) < ttlEquipos) {
          //           print(' [API] Retornando equipos desde cache en memoria');
          return List<EquipoModel>.from(_cacheEquipos!);
        }
      }

      const cacheKey = 'cache_equipos_v2';
      final isOnline = await ConnectivityService.instance.checkNow();

      Future<List<EquipoModel>> loadFromCache() async {
        final raw = prefs.getString(cacheKey);
        if (raw == null || raw.isEmpty) return [];
        try {
          final decoded = jsonDecode(raw);
          List<dynamic> items;
          if (decoded is Map && decoded['items'] is List) {
            items = decoded['items'] as List<dynamic>;
          } else if (decoded is List) {
            items = decoded;
          } else {
            return [];
          }
          final equipos =
              items.map((json) => EquipoModel.fromJson(json)).toList();
          // Actualizar cache memoria si cargamos desde persistencia
          _cacheEquipos = equipos;
          _tsEquipos = now;
          return equipos;
        } catch (_) {
          return [];
        }
      }

      if (!isOnline) {
        final cached = await loadFromCache();
        if (cached.isNotEmpty) return cached;
        // Sin caché, continuar a intentar red (posible fallo)
      }

      //       print(' [API] Cargando equipos...');
      final authHeaders = await _getAuthHeaders();

      final queryParams = <String, String>{};
      if (clienteId != null) {
        queryParams['cliente_id'] = clienteId.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/equipo/listar_equipos.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        List<dynamic> equiposData = [];

        if (responseData is Map && responseData['success'] == true) {
          if (responseData['equipos'] is List) {
            equiposData = responseData['equipos'] as List<dynamic>;
          } else if (responseData['data'] is Map &&
              (responseData['data'] as Map)['equipos'] is List) {
            equiposData =
                (responseData['data'] as Map)['equipos'] as List<dynamic>;
          }
        } else if (responseData is List) {
          equiposData = responseData;
        } else if (responseData is Map && responseData['data'] is Map) {
          final data = responseData['data'] as Map;
          equiposData = (data['equipos'] as List<dynamic>? ?? []);
        } else if (responseData is Map && responseData['success'] == false) {
          // Fallback a caché en error de servidor
          final cached = await loadFromCache();
          if (cached.isNotEmpty) return cached;
          throw Exception(responseData['message'] ?? 'Error del servidor');
        }

        // Mapear a modelos
        final equipos =
            equiposData.map((json) => EquipoModel.fromJson(json)).toList();

        //  ACTUALIZAR CACHE EN MEMORIA
        _cacheEquipos = equipos;
        _tsEquipos = DateTime.now();

        // Guardar caché cruda
        try {
          final payload = jsonEncode({
            'ts': _tsEquipos!.toIso8601String(),
            'items': equiposData,
          });
          await prefs.setString(cacheKey, payload);
        } catch (_) {}

        return equipos;
      } else if (response.statusCode == 401) {
        await AuthService.clearAuthData();
        throw Exception('Error de autenticación');
      } else {
        // Fallback a caché en error HTTP
        final cached = await loadFromCache();
        if (cached.isNotEmpty) return cached;
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Fallback a caché en excepciones
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_equipos');
        if (raw != null) {
          final decoded = jsonDecode(raw);
          final items =
              (decoded is Map && decoded['items'] is List)
                  ? decoded['items'] as List<dynamic>
                  : (decoded is List ? decoded : []);
          if (items.isNotEmpty) {
            return items.map((json) => EquipoModel.fromJson(json)).toList();
          }
        }
      } catch (_) {}
      throw Exception('Error al cargar equipos: $e');
    }
  }

  // =====================================
  //    VERIFICACIONES (EXISTENTE)
  // =====================================

  /// Verificar si puede editar el número de servicio
  static Future<ApiResponse<Map<String, dynamic>>>
  verificarPrimerServicio() async {
    try {
      //       print(' [API] Verificando primer servicio...');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final token = await AuthService.getToken();
      final headers = await _getAuthHeaders();
      final url = '$_baseUrl/servicio/verificar_primer_servicio.php?t=$timestamp${token != null ? '&token=$token' : ''}';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final data = {
            'es_primer_servicio': result['es_primer_servicio'] == true,
            'siguiente_numero': result['siguiente_numero'] ?? 1,
          };

          //           print(' [API] Verificación completada: ${data['es_primer_servicio']}');
          return ApiResponse.success(data: data);
        } else {
          throw Exception(result['message'] ?? 'Error en verificación');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // FALLBACK GRACEFUL:
      // Si falla la verificación (404/CORS/Offline), asumimos que NO es el primer servicio
      // y devolvemos 0 como siguiente nmero para evitar que la app falle.
      // debugPrint(' [API] Error verificando primer servicio (usando fallback): $e');
      return ApiResponse.success(
        data: {
          'es_primer_servicio': false,
          'siguiente_numero':
              0, // 0 indicará "desconocido" o "calcular localmente"
        },
        message: 'Verificación omitida (error de conexión)',
      );
    }
  }

  // =====================================
  //     NUEVOS MÉTODOS DE AUTENTICACIÓN Y DEBUG
  // =====================================

  ///  NUEVO: Verificar autenticación
  static Future<bool> verificarAutenticacion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');
      final usuarioNombre = prefs.getString('usuario_nombre');
      final loginTimestamp = prefs.getString('login_timestamp');

      //       print(' VERIFICAR AUTENTICACIÓN:');
      //       print('   Usuario ID: $usuarioId');
      //       print('   Usuario: $usuarioNombre');
      //       print('   Login: $loginTimestamp');

      if (usuarioId == null || usuarioNombre == null) {
        //         print(' Usuario no autenticado');
        return false;
      }

      // Verificar que el login no haya expirado (24 horas)
      if (loginTimestamp != null) {
        try {
          final loginDate = DateTime.parse(loginTimestamp);
          final now = DateTime.now();
          final difference = now.difference(loginDate);

          if (difference.inHours >= 24) {
            //             print(' Sesión expirada (${difference.inHours} horas)');
            return false;
          }

          //           print(' Sesión válida (${difference.inHours} horas activa)');
        } catch (e) {
          //           print(' Error verificando timestamp: $e');
        }
      }

      return true;
    } catch (e) {
      //       print(' Error verificando autenticación: $e');
      return false;
    }
  }

  ///  NUEVO: Mostrar configuración para debug
  static Future<void> mostrarConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      //       print(' ===== CONFIGURACIÓN SERVICIOS API =====');
      //       print('Base URL: $_baseUrl');
      //       print('Usuario ID: ${prefs.getInt('usuario_id')}');
      //       print('Usuario: ${prefs.getString('usuario_nombre')}');
      //       print('Rol: ${prefs.getString('usuario_rol')}');
      //       print('Login: ${prefs.getString('login_timestamp')}');
      //       print('Autenticado: ${await verificarAutenticacion()}');
      //       print('==========================================');
    } catch (e) {
      //       print(' Error mostrando configuración: $e');
    }
  }

  ///  NUEVO: Inicialización optimizada del sistema de cache
  static Future<void> inicializarSistemaOptimizado() async {
    try {
      //       print(' ===== INICIALIZACIÓN OPTIMIZADA =====');

      // 1. Verificar autenticación
      final isAuth = await verificarAutenticacion();
      if (!isAuth) {
        //         print(' No autenticado - cancelando inicialización');
        return;
      }

      // 2. Precargar metadatos de campos (muy rápido)
      final stopwatch = Stopwatch()..start();
      await precargarMetadatosCampos();
      //       print(' Metadatos precargados en ${stopwatch.elapsedMilliseconds}ms');

      // 3. Limpiar cache expirado
      _limpiarCacheExpirado();

      //       print(' Inicialización completada en ${stopwatch.elapsedMilliseconds}ms');
      //       print('==========================================');
    } catch (e) {
      //       print(' Error en inicialización optimizada: $e');
    }
  }

  /// Limpiar entradas de cache expiradas
  static void _limpiarCacheExpirado() {
    final clavesAEliminar = <String>[];

    _cacheValoresCampos.forEach((clave, entry) {
      if (entry.isExpired) {
        clavesAEliminar.add(clave);
      }
    });

    for (String clave in clavesAEliminar) {
      _cacheValoresCampos.remove(clave);
      _cacheTimestamps.remove(clave);
    }

    if (clavesAEliminar.isNotEmpty) {
      //       print(' [CACHE] ${clavesAEliminar.length} entradas expiradas eliminadas');
    }
  }

  ///  NUEVO: Test de conexión completo
  static Future<void> testConexion() async {
    //     print(' ===== TEST DE CONEXIÓN =====');

    try {
      // 1. Verificar autenticación
      final isAuth = await verificarAutenticacion();
      //       print('1. Autenticado: $isAuth');

      if (!isAuth) {
        //         print(' No autenticado - no se puede continuar test');
        return;
      }

      // 3. Test básico de conectividad
      final response = await http
          .get(
            Uri.parse('$_baseUrl/debug_session.php'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      //       print('3. Conectividad: ${response.statusCode == 200 ? 'OK' : 'ERROR'}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        //         print('4. Respuesta servidor: ${result['timestamp']}');
      }

      //       print(' Test completado');
    } catch (e) {
      //       print(' Error en test: $e');
    }

    //     print('===============================');
  }

  // =====================================
  //     MÉTODOS DE CACHE
  // =====================================

  /// Generar clave de cache para valores de campos adicionales
  static String _generarClaveCacheValores({
    required int servicioId,
    String modulo = 'Servicios',
  }) {
    return 'valores_campos_${servicioId}_$modulo';
  }

  // Cache en memoria para staff por servicio (TTL 10 min)
  static final Map<int, _StaffCacheEntry> _cacheStaffServicio = {};
  static const Duration _ttlStaff = Duration(minutes: 10);

  static void _invalidateStaffCacheForServicio(int servicioId) {
    _cacheStaffServicio.remove(servicioId);
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('servicio_staff_cache_$servicioId');
      });
    } catch (_) {}
  }

  /// Verificar si existe cache válido
  static bool _tieneCacheValido(String clave) {
    final entry = _cacheValoresCampos[clave];
    if (entry == null) return false;

    final isValid = entry.isValid;
    if (!isValid) {
      // Limpiar cache expirado
      _cacheValoresCampos.remove(clave);
      _cacheTimestamps.remove(clave);
    }

    return isValid;
  }

  /// Obtener datos del cache
  static Map<int, dynamic>? _obtenerDelCache(String clave) {
    final entry = _cacheValoresCampos[clave];
    if (entry != null && entry.isValid) {
      //       print(' [CACHE] Datos obtenidos del cache: $clave');
      return Map<int, dynamic>.from(entry.data);
    }
    return null;
  }

  /// Guardar datos en cache
  static void _guardarEnCache(String clave, Map<int, dynamic> datos) {
    _cacheValoresCampos[clave] = CacheEntry(
      data: Map<int, dynamic>.from(datos),
      timestamp: DateTime.now(),
      ttl: _cacheTTL,
    );
    _cacheTimestamps[clave] = DateTime.now();
    //     print(' [CACHE] Datos guardados en cache: $clave');
  }

  /// Invalidar cache específico
  static void invalidarCacheValores({int? servicioId, String? modulo}) {
    if (servicioId != null && modulo != null) {
      // Invalidar cache específico
      final clave = _generarClaveCacheValores(
        servicioId: servicioId,
        modulo: modulo,
      );
      _cacheValoresCampos.remove(clave);
      _cacheTimestamps.remove(clave);

      // cache de campos por estado
      _camposPorEstadoCache.remove('${modulo}_$servicioId');
    } else {
      // Invalidar todo el cache
      _cacheValoresCampos.clear();
      _cacheTimestamps.clear();
      _camposPorEstadoCache.clear();
    }
  }

  // =====================================
  //     CACHE PERSISTENTE CON VERSIONADO
  // =====================================

  /// Guardar cache en SharedPreferences
  static Future<void> _guardarCachePersistente(
    String clave,
    Map<int, dynamic> datos,
    String timestamp,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datosJson = jsonEncode(
        datos.map((k, v) => MapEntry(k.toString(), v)),
      );

      await prefs.setString('cache_$clave', datosJson);
      await prefs.setString('timestamp_$clave', timestamp);

      //       print(' [CACHE PERSISTENTE] Guardado: $clave');
    } catch (e) {
      //       print(' [CACHE PERSISTENTE] Error guardando: $e');
    }
  }

  /// Cargar cache desde SharedPreferences
  static Future<Map<String, dynamic>?> _cargarCachePersistente(
    String clave,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datosJson = prefs.getString('cache_$clave');
      final timestamp = prefs.getString('timestamp_$clave');

      if (datosJson != null && timestamp != null) {
        final datosMap = jsonDecode(datosJson) as Map<String, dynamic>;
        final datos = datosMap.map((k, v) => MapEntry(int.parse(k), v));

        //         print(' [CACHE PERSISTENTE] Cargado: $clave (timestamp: $timestamp)');
        return {'datos': datos, 'timestamp': timestamp};
      }
    } catch (e) {
      //       print(' [CACHE PERSISTENTE] Error cargando: $e');
    }
    return null;
  }

  /// Verificar si hay cambios en el servidor
  static Future<bool> _verificarCambiosEnServidor({
    required int servicioId,
    String? ultimoTimestamp,
  }) async {
    try {
      final url =
          '$_baseUrl/core/fields/verificar_cambios_campos.php?servicio_id=$servicioId${ultimoTimestamp != null ? '&ultimo_timestamp=${Uri.encodeComponent(ultimoTimestamp)}' : ''}';

      //       print(' [VERIFICACIÓN] Consultando cambios: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final hayCambios = result['hay_cambios'] == true;
          //           print(' [VERIFICACIÓN] Hay cambios: $hayCambios');
          return hayCambios;
        }
      }

      //       print(' [VERIFICACIÓN] Error en respuesta, asumiendo cambios');
      return true; // En caso de error, asumir que hay cambios
    } catch (e) {
      //       print(' [VERIFICACIÓN] Error verificando cambios: $e');
      return true; // En caso de error, asumir que hay cambios
    }
  }

  // =====================================
  //     CARGA DIFERIDA Y OPTIMIZACIONES
  // =====================================

  /// Cache para metadatos de campos (estructura sin valores)
  static Map<int, List<CampoAdicionalModel>>? _cacheMetadatosCampos;
  static DateTime? _timestampMetadatos;
  static const Duration _ttlMetadatos = Duration(
    hours: 1,
  ); // Los metadatos cambian poco

  /// Precargar metadatos de campos (solo estructura, muy rápido)
  static Future<void> precargarMetadatosCampos() async {
    try {
      // Verificar si ya tenemos metadatos válidos
      if (_cacheMetadatosCampos != null && _timestampMetadatos != null) {
        final edad = DateTime.now().difference(_timestampMetadatos!);
        if (edad < _ttlMetadatos) {
          //           print(' [METADATOS] Cache de metadatos válido (${edad.inMinutes}min)');
          return;
        }
      }

      //       print(' [METADATOS] Cargando estructura de campos...');

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/core/metadata/obtener_metadatos_campos_rapido.php',
            ),
            headers: authHeaders,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final Map<String, dynamic> camposPorEstado =
              result['campos_por_estado'] ?? {};
          final Map<int, List<CampoAdicionalModel>> metadatos = {};

          camposPorEstado.forEach((estadoIdStr, campos) {
            final estadoId = int.tryParse(estadoIdStr) ?? 0;
            final List<dynamic> camposLista = campos as List<dynamic>;

            metadatos[estadoId] =
                camposLista
                    .map((campo) => CampoAdicionalModel.fromJson(campo))
                    .toList();
          });

          _cacheMetadatosCampos = metadatos;
          _timestampMetadatos = DateTime.now();

          //           print(' [METADATOS] ${result['total_campos']} campos estructurados cargados');
        }
      }
    } catch (e) {
      //       print(' [METADATOS] Error precargando metadatos: $e');
    }
  }

  /// Obtener campos por estado desde cache de metadatos
  static Future<List<CampoAdicionalModel>> obtenerCamposPorEstadoRapido({
    required int estadoId,
    String modulo = 'Servicios',
  }) async {
    // Asegurar que tenemos metadatos
    await precargarMetadatosCampos();

    if (_cacheMetadatosCampos != null) {
      final campos = _cacheMetadatosCampos![estadoId] ?? [];
      String moduloNorm = modulo.trim().toLowerCase();
      if (moduloNorm.startsWith('serv')) moduloNorm = 'servicios';
      if (moduloNorm.startsWith('equ')) moduloNorm = 'equipos';
      // Filtrado estricto: no forzar módulo para vacíos; solo aceptar explícitos
      final camposFiltrados =
          campos.where((campo) {
            final m = (campo.modulo).trim().toLowerCase();
            if (moduloNorm == 'servicios') {
              return m == 'servicios' || m == 'servicio';
            }
            if (moduloNorm == 'equipos') {
              return m == 'equipos' || m == 'equipo';
            }
            return m == moduloNorm;
          }).toList();

      //       print(' [METADATOS] ${camposFiltrados.length} campos para estado $estadoId desde cache');
      return camposFiltrados;
    }

    // Fallback al método original si no hay cache
    //     print(' [METADATOS] Fallback al método original');
    return obtenerCamposPorEstado(estadoId: estadoId, modulo: modulo);
  }

  /// Obtener valores específicos de campos (optimizado)
  static Future<Map<int, dynamic>> obtenerValoresEspecificos({
    required int servicioId,
    List<int>? campoIds,
  }) async {
    try {
      //       print(' [API ESPECÍFICA] Cargando valores específicos para servicio: $servicioId...');

      String url =
          '$_baseUrl/servicio/obtener_valores_servicio_específico.php?servicio_id=$servicioId';

      if (campoIds != null && campoIds.isNotEmpty) {
        final campoIdsStr = campoIds.join(',');
        url += '&campo_ids=$campoIdsStr';
        //         print(' [API ESPECÍFICA] Solo campos: $campoIdsStr');
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final Map<String, dynamic> valoresRaw = result['valores'] ?? {};
          final Map<int, dynamic> valores = {};

          // Convertir claves string a int
          valoresRaw.forEach((key, value) {
            final campoId = int.tryParse(key.toString());
            if (campoId != null) {
              valores[campoId] = value;
            }
          });

          //           print(' [API ESPECÍFICA] ${valores.length} valores específicos cargados');
          return valores;
        }
      }

      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      //       print(' [API ESPECFICA] Error: $e');
      return {};
    }
  }

  /// Método híbrido: usar cache inteligente + carga específica según contexto
  static Future<Map<int, dynamic>> obtenerValoresCamposHibrido({
    required int servicioId,
    String modulo = 'Servicios',
    List<int>? soloEstosCampos,
    bool forzarRecarga = false,
  }) async {
    try {
      // Si se solicitan campos específicos, usar endpoint optimizado
      if (soloEstosCampos != null && soloEstosCampos.isNotEmpty) {
        //         print(' [HÍBRIDO] Modo específico: ${soloEstosCampos.length} campos');
        return obtenerValoresEspecificos(
          servicioId: servicioId,
          campoIds: soloEstosCampos,
        );
      }

      // Si se fuerza recarga, limpiar cache
      if (forzarRecarga) {
        invalidarCacheValores(servicioId: servicioId, modulo: modulo);
      }

      // Usar método inteligente completo
      //       print(' [HÍBRIDO] Modo completo con cache inteligente');
      return obtenerValoresCamposAdicionales(
        servicioId: servicioId,
        modulo: modulo,
      );
    } catch (e) {
      //       print(' [HÍBRIDO] Error: $e');
      return {};
    }
  }

  // =====================================
  //    BRANDING (EXISTENTE)
  // =====================================

  // ✅ CORREGIDO: Cache de estados por módulo (aislado por clave)
  // Antes era un solo CacheEntry compartido, lo que causaba que estados de
  // 'inspecciones' pudieran contaminar la lista del módulo 'servicio'.
  static final Map<String, CacheEntry<List<EstadoModel>>> _estadosCachePorModulo = {};

  /// Listar estados disponibles
  static Future<List<EstadoModel>> listarEstados({
    String modulo = 'servicio',
  }) async {
    // ✅ CORREGIDO: Cada módulo tiene su propio cache aislado.
    // Antes exisía un solo CacheEntry compartido que no diferenciaba módulos,
    // causando una condición de carrera: si 'inspecciones' cargaba primero,
    // 'servicio' podía leer esos estados erróneos desde la cache compartida.
    final cacheActual = _estadosCachePorModulo[modulo];
    if (cacheActual != null &&
        cacheActual.isValid &&
        cacheActual.data.isNotEmpty) {
      return cacheActual.data;
    }

    try {
      final authHeaders = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/workflow/listar_estados.php?modulo=$modulo'),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> lista;
        if (decoded is List) {
          lista = decoded;
        } else if (decoded is Map && decoded['success'] == true) {
          lista = decoded['data'];
        } else {
          lista = [];
        }

        final estados = lista.map((e) => EstadoModel.fromJson(e)).toList();

        // ✅ Guardar en cache AISLADO por módulo
        if (estados.isNotEmpty) {
          _estadosCachePorModulo[modulo] = CacheEntry(
            data: estados,
            timestamp: DateTime.now(),
          );
        }
        return estados;
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      // En caso de error, usar la cache del módulo aunque esté vencida
      final fallback = _estadosCachePorModulo[modulo];
      if (fallback != null && fallback.data.isNotEmpty) return fallback.data;
      return [];
    }
  }

  /// Obtener configuración de branding
  static Future<BrandingModel> obtenerBranding() async {
    try {
      //       print(' [API] Cargando branding...');
      final authHeaders = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/core/branding/obtener_branding.php'),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true && result['branding'] != null) {
          final branding = BrandingModel.fromJson(result['branding']);
          //           print(' [API] Branding cargado: ${branding.nombreEmpresa}');
          return branding;
        } else {
          throw Exception(result['message'] ?? 'Error obteniendo branding');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error cargando branding: $e');
      // Retornar configuración por defecto
      return BrandingModel.porDefecto();
    }
  }

  /// Obtener todos los tipos de mantenimiento disponibles
  static Future<List<String>> listarTiposMantenimiento() async {
    try {
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        return ['preventivo', 'correctivo', 'predictivo'];
      }
      //       print(' [API] Cargando tipos de mantenimiento...');

      final response = await http.get(
        Uri.parse('$_baseUrl/core/metadata/obtener_tipos_mantenimiento.php'),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final List<String> tipos = List<String>.from(result['tipos'] ?? []);
          //           print(' [API] ${tipos.length} tipos de mantenimiento cargados');
          return tipos;
        } else {
          throw Exception(result['message'] ?? 'Error obteniendo tipos');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error cargando tipos de mantenimiento: $e');
      // Retornar tipos por defecto si hay error
      return ['preventivo', 'correctivo', 'predictivo'];
    }
  }

  /// Eliminar tipo de mantenimiento personalizado
  static Future<ApiResponse<bool>> eliminarTipoMantenimiento(
    String tipo,
  ) async {
    try {
      //       print(' [API] Eliminando tipo de mantenimiento: $tipo...');

      final requestData = {'tipo': tipo};

      final response = await http.post(
        Uri.parse('$_baseUrl/core/metadata/eliminar_tipo_mantenimiento.php'),
        headers: _headers,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Tipo eliminado exitosamente');
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Tipo eliminado exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error eliminando tipo');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error eliminando tipo: $e');
      return ApiResponse.error('Error al eliminar tipo: $e');
    }
  }

  /// Actualizar nombre de tipo de mantenimiento personalizado
  static Future<ApiResponse<bool>> actualizarTipoMantenimiento(
    String tipoAnterior,
    String tipoNuevo,
  ) async {
    try {
      //       print(' [API] Actualizando tipo de mantenimiento: $tipoAnterior -> $tipoNuevo...');

      final requestData = {
        'tipo_anterior': tipoAnterior,
        'tipo_nuevo': tipoNuevo,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/core/metadata/actualizar_tipo_mantenimiento.php'),
        headers: _headers,
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Tipo actualizado exitosamente');
          return ApiResponse.success(
            data: true,
            message:
                result['message'] ??
                'Tipo de mantenimiento actualizado exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error actualizando tipo');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error actualizando tipo: $e');
      return ApiResponse.error('Error al actualizar tipo: $e');
    }
  }

  /// Crear nuevo tipo de mantenimiento personalizado
  static Future<ApiResponse<bool>> crearTipoMantenimiento(String tipo) async {
    try {
      //       print(' [API] Creando tipo de mantenimiento: $tipo...');
      final authHeaders = await _getAuthHeaders();

      final requestData = {'tipo': tipo};

      final response = await http.post(
        Uri.parse('$_baseUrl/core/metadata/crear_tipo_mantenimiento.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' [API] Response status: ${response.statusCode}');
      //       print(' [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Tipo creado exitosamente');
          return ApiResponse.success(
            data: true,
            message:
                result['message'] ??
                'Tipo de mantenimiento creado exitosamente',
          );
        } else {
          throw Exception(result['message'] ?? 'Error creando tipo');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error creando tipo: $e');
      return ApiResponse.error('Error al crear tipo: $e');
    }
  }

  /// Listar staff asignado a un servicio
  static Future<List<ServicioStaffModel>> listarStaffDeServicio(
    int servicioId,
  ) async {
    try {
      //       print(' Listando staff del servicio ID: $servicioId');

      // Caché en memoria
      final now = DateTime.now();
      final cached = _cacheStaffServicio[servicioId];
      if (cached != null && now.difference(cached.ts) < _ttlStaff) {
        return cached.staff;
      }

      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('servicio_staff_cache_$servicioId');
          if (raw != null && raw.isNotEmpty) {
            final List<dynamic> staffList = jsonDecode(raw);
            final staff =
                staffList
                    .map((json) => ServicioStaffModel.fromJson(json))
                    .toList();
            return staff;
          }
        } catch (_) {}
        return <ServicioStaffModel>[];
      }

      final authHeaders = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/servicio/servicio_staff/listar.php?servicio_id=$servicioId',
        ),
        headers: authHeaders,
      );

      //       print(' Respuesta recibida: [32m${response.statusCode}[0m');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          // Compatibilidad: intentar diferentes claves posibles del backend
          final data = result['data'] ?? {};
          List<dynamic> staffList = [];
          if (data is Map<String, dynamic>) {
            staffList =
                data['usuarios'] ??
                data['staff_asignado'] ??
                data['usuarios_asignados'] ??
                data['users_asignados'] ??
                data['asignados'] ??
                [];
          }

          final staff =
              staffList
                  .map((json) => ServicioStaffModel.fromJson(json))
                  .toList();

          // Guardar en caché
          _cacheStaffServicio[servicioId] = _StaffCacheEntry(
            staff: staff,
            ts: now,
          );

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'servicio_staff_cache_$servicioId',
              jsonEncode(staffList),
            );
          } catch (_) {}

          //           print(' Staff cargado: ${staff.length} empleados');
          return staff;
        } else {
          throw Exception(
            result['message'] ?? 'Error desconocido al listar staff',
          );
        }
      } else {
        // Error HTTP: devolver lista vacía para modo offline
        return <ServicioStaffModel>[];
      }
    } catch (e) {
      //       print(' Error listando staff del servicio: $e');
      // Offline u otros errores: devolver lista vacía
      return <ServicioStaffModel>[];
    }
  }

  /// Actualizar (reemplazar) staff de un servicio
  static Future<ApiResponse<List<ServicioStaffModel>>> actualizarStaffServicio({
    required int servicioId,
    required List<int> staffIds,
  }) async {
    try {
      //       print(' Actualizando staff del servicio ID: $servicioId');
      //       print(' Staff IDs: $staffIds');

      final authHeaders = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/servicio_staff/actualizar.php'),
        headers: authHeaders,
        body: jsonEncode({'servicio_id': servicioId, 'staff_ids': staffIds}),
      );

      //       print(' Respuesta recibida: [32m${response.statusCode}[0m');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final data = result['data'] ?? {};
          List<dynamic> staffList = [];
          if (data is Map<String, dynamic>) {
            staffList =
                data['staff_asignado'] ??
                data['usuarios_asignados'] ??
                data['users_asignados'] ??
                data['asignados'] ??
                [];
          }

          final staff =
              staffList
                  .map((json) => ServicioStaffModel.fromJson(json))
                  .toList();

          //           print(' Staff actualizado exitosamente: ${staff.length} empleados');

          // Invalidate cache
          _invalidateStaffCacheForServicio(servicioId);
          return ApiResponse.success(
            data: staff,
            message: result['mensaje'] ?? 'Staff actualizado exitosamente',
          );
        } else {
          return ApiResponse.error(
            result['message'] ?? 'Error desconocido al actualizar staff',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' Error actualizando staff: $e');
      return ApiResponse.error('Error al actualizar staff: $e');
    }
  }

  /// Actualizar (reemplazar) usuarios asignados a un servicio
  /// Usa la nueva validación basada en tabla `usuarios` enviando `usuario_ids`.
  static Future<ApiResponse<List<ServicioStaffModel>>>
  actualizarUsuariosServicio({
    required int servicioId,
    required List<int> usuarioIds,
    int? responsableId,
    int? operacionId,
    List<Map<String, dynamic>>? assignments,
  }) async {
    try {
      //       print(' Actualizando usuarios del servicio ID: $servicioId');
      //       print(' Usuario IDs: $usuarioIds');

      final authHeaders = await _getAuthHeaders();

      //  Intentar primero el nuevo endpoint basado en usuarios
      try {
        final respUsuarios = await http.post(
          Uri.parse('$_baseUrl/servicio/servicio_usuarios/actualizar.php'),
          headers: authHeaders,
          body: jsonEncode({
            'servicio_id': servicioId,
            'usuario_ids': usuarioIds,
            if (responsableId != null) 'responsable_id': responsableId,
            if (operacionId != null) 'operacion_id': operacionId,
            if (assignments != null) 'assignments': assignments,
          }),
        );

        if (respUsuarios.statusCode == 200) {
          final result = jsonDecode(respUsuarios.body);
          if (result is Map && result['success'] == true) {
            final List<dynamic> staffList =
                (result['data']?['usuarios'] ??
                        result['data']?['usuarios_asignados'] ??
                        result['data']?['users_asignados'] ??
                        result['data']?['asignados'] ??
                        [])
                    as List<dynamic>;

            final staff =
                staffList
                    .map((json) => ServicioStaffModel.fromJson(json))
                    .toList();

            _invalidateStaffCacheForServicio(servicioId);
            return ApiResponse.success(
              data: staff,
              message: result['mensaje'] ?? 'Usuarios asignados exitosamente',
            );
          }
        }
      } catch (_) {
        // Ignorar y caer al endpoint legacy si falla el nuevo
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/servicio_staff/actualizar.php'),
        headers: authHeaders,
        // Enviar ambos keys para compatibilidad de backend:
        // - `usuario_ids` para nueva validación por usuarios
        // - `staff_ids` como arreglo vacío para satisfacer validación de tipo
        body: jsonEncode({
          'servicio_id': servicioId,
          'usuario_ids': usuarioIds,
          if (responsableId != null) 'responsable_id': responsableId,
          if (assignments != null) 'staff_assignments': assignments,
        }),
      );

      //       print(' Respuesta recibida: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          // Compatibilidad de clave de respuesta
          final List<dynamic> staffList =
              (result['data']?['usuarios'] ??
                      result['data']?['staff_asignado'] ??
                      result['data']?['usuarios_asignados'] ??
                      result['data']?['users_asignados'] ??
                      result['data']?['asignados'] ??
                      [])
                  as List<dynamic>;

          final staff =
              staffList
                  .map((json) => ServicioStaffModel.fromJson(json))
                  .toList();

          // Invalidate cache
          _invalidateStaffCacheForServicio(servicioId);
          return ApiResponse.success(
            data: staff,
            message: result['mensaje'] ?? 'Usuarios asignados exitosamente',
          );
        } else {
          return ApiResponse.error(
            result['message'] ?? 'Error desconocido al asignar usuarios',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' Error actualizando usuarios: $e');
      return ApiResponse.error('Error al actualizar usuarios: $e');
    }
  }

  /// Eliminar un staff específico del servicio
  static Future<ApiResponse> eliminarStaffDeServicio({
    int? servicioStaffId,
    int? servicioId,
    int? staffId,
  }) async {
    try {
      if (servicioStaffId == null && (servicioId == null || staffId == null)) {
        return ApiResponse.error(
          'Debe proporcionar servicioStaffId o (servicioId + staffId)',
        );
      }

      //       print(' Eliminando staff del servicio');

      final Map<String, dynamic> data = {};

      if (servicioStaffId != null) {
        data['servicio_staff_id'] = servicioStaffId;
        //         print('   Por ID pivot: $servicioStaffId');
      } else {
        data['servicio_id'] = servicioId;
        data['staff_id'] = staffId;
        //         print('   Por servicio: $servicioId, staff: $staffId');
      }

      final authHeaders = await _getAuthHeaders();

      final response = await http.delete(
        Uri.parse('$_baseUrl/servicio/servicio_staff/eliminar.php'),
        headers: authHeaders,
        body: jsonEncode(data),
      );

      //       print(' Respuesta recibida: [32m${response.statusCode}[0m');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' Staff eliminado exitosamente');
          // Invalidate cache si tenemos servicioId
          if (servicioId != null) {
            _invalidateStaffCacheForServicio(servicioId);
          }
          return ApiResponse.success(
            message: result['mensaje'] ?? 'Staff eliminado exitosamente',
          );
        } else {
          return ApiResponse.error(
            result['message'] ?? 'Error desconocido al eliminar staff',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' Error eliminando staff: $e');
      return ApiResponse.error('Error al eliminar staff: $e');
    }
  }
  // =========================================================================
  // MÉTODOS PARA GESTIÓN DE CENTROS DE COSTO
  // =========================================================================

  /// Listar centros de costo disponibles
  static Future<List<String>> listarCentrosCosto() async {
    try {
      // Cache offline
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'cache_centros_costo_v1';
      final isOnline = await ConnectivityService.instance.checkNow();

      List<String> normalize(List<dynamic> raw) {
        return raw
            .map((c) => c.toString().trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));
      }

      Future<List<String>> loadFromCache() async {
        try {
          final raw = prefs.getString(cacheKey);
          if (raw == null || raw.isEmpty) return [];
          final decoded = jsonDecode(raw);
          final items =
              (decoded is Map && decoded['items'] is List)
                  ? decoded['items'] as List<dynamic>
                  : (decoded is List ? decoded : []);
          return normalize(items);
        } catch (_) {
          return [];
        }
      }

      if (!isOnline) {
        final cached = await loadFromCache();
        if (cached.isNotEmpty) return cached;
        // Sin caché, continuar a intentar por si hay conectividad intermitente
      }

      final url = '$_baseUrl/servicio/obtener_centros_costo_unicos.php';
      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(Uri.parse(url), headers: authHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map && result['success'] == true) {
          final centrosRaw = (result['centros'] as List<dynamic>? ?? []);
          final centros = normalize(centrosRaw);

          // Guardar en caché
          try {
            final payload = jsonEncode({
              'items': centrosRaw,
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
            await prefs.setString(cacheKey, payload);
          } catch (_) {}

          return centros;
        } else {
          // Fallback a cach en error de respuesta
          final cached = await loadFromCache();
          if (cached.isNotEmpty) return cached;
          throw Exception(
            result is Map
                ? (result['message'] ?? 'Error obteniendo centros de costo')
                : 'Respuesta inválida',
          );
        }
      } else if (response.statusCode == 401) {
        await AuthService.clearAuthData();
        throw Exception('Error de autenticación');
      } else {
        // Fallback a caché en error HTTP
        final cached = await loadFromCache();
        if (cached.isNotEmpty) return cached;
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Fallback a caché en excepciones
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cache_centros_costo_v1');
        if (raw != null) {
          final decoded = jsonDecode(raw);
          final items =
              (decoded is Map && decoded['items'] is List)
                  ? decoded['items'] as List<dynamic>
                  : (decoded is List ? decoded : []);
          final centros =
              items
                  .map((c) => c.toString().trim().toLowerCase())
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.compareTo(b));
          if (centros.isNotEmpty) return centros;
        }
      } catch (e) {
        // Ignorar errores de caché
      }

      // Retornar centros por defecto si no hay caché
      return ['produccion', 'mantenimiento', 'administracion'];
    }
  }

  /// Crear nuevo centro de costo
  static Future<ApiResponse<bool>> crearCentroCosto(String nombre) async {
    try {
      //       print(' [API] Creando centro de costo: $nombre...');

      final authHeaders = await _getAuthHeaders();

      final requestData = {'nombre': nombre};

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/centros_costo/crear.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' Respuesta recibida: [32m${response.statusCode}[0m');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Centro de costo creado exitosamente');
          return ApiResponse.success(
            data: true,
            message: result['message'] ?? 'Centro de costo creado exitosamente',
          );
        } else {
          return ApiResponse.error(
            result['message'] ?? 'Error desconocido al crear centro de costo',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error creando centro de costo: $e');
      return ApiResponse.error('Error al crear centro de costo: $e');
    }
  }

  /// Actualizar centro de costo existente
  static Future<ApiResponse<bool>> actualizarCentroCosto({
    required String nombreAnterior,
    required String nombreNuevo,
  }) async {
    try {
      //       print(' [API] Actualizando centro de costo: $nombreAnterior -> $nombreNuevo...');

      final authHeaders = await _getAuthHeaders();

      final requestData = {
        'nombre_anterior': nombreAnterior,
        'nombre_nuevo': nombreNuevo,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/centros_costo/actualizar.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' Respuesta recibida: [32m${response.statusCode}[0m');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Centro de costo actualizado exitosamente');
          return ApiResponse.success(
            data: true,
            message:
                result['message'] ?? 'Centro de costo actualizado exitosamente',
          );
        } else {
          return ApiResponse.error(
            result['message'] ??
                'Error desconocido al actualizar centro de costo',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error actualizando centro de costo: $e');
      return ApiResponse.error('Error al actualizar centro de costo: $e');
    }
  }

  /// Eliminar centro de costo
  static Future<ApiResponse<bool>> eliminarCentroCosto(String nombre) async {
    try {
      //       print(' [API] Eliminando centro de costo: $nombre...');

      final authHeaders = await _getAuthHeaders();

      final requestData = {'nombre': nombre};

      final response = await http.post(
        Uri.parse('$_baseUrl/servicio/centros_costo/eliminar.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      //       print(' Respuesta recibida: [32m${response.statusCode}[0m');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          //           print(' [API] Centro de costo eliminado exitosamente');
          return ApiResponse.success(
            data: true,
            message:
                result['message'] ?? 'Centro de costo eliminado exitosamente',
          );
        } else {
          return ApiResponse.error(
            result['message'] ??
                'Error desconocido al eliminar centro de costo',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print(' [API] Error eliminando centro de costo: $e');
      return ApiResponse.error('Error al eliminar centro de costo: $e');
    }
  }

  ///  NUEVO: Helper centralizado para parsear errores de la API
  static ApiResponse<T> _parseErrorResponse<T>(
    http.Response response,
    String fallbackPrefix,
  ) {
    try {
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        final body = jsonDecode(response.body);
        final String? msg = body['message'] ?? body['error'];
        if (msg != null) {
          return ApiResponse.error(msg);
        }
      }

      // Si no es JSON o no tiene mensaje claro
      if (response.statusCode == 401) {
        return ApiResponse.error(
          'Sesión expirada. Por favor inicie sesión de nuevo.',
        );
      }
      if (response.statusCode == 403) {
        return ApiResponse.error(
          'No tiene permisos para realizar esta acción.',
        );
      }

      return ApiResponse.error(
        '$fallbackPrefix (Código ${response.statusCode})',
      );
    } catch (_) {
      return ApiResponse.error(
        '$fallbackPrefix: Error inesperado del servidor',
      );
    }
  }
}

// =====================================
//    CLASES AUXILIARES (EXISTENTE)
// =====================================

/// Clase para manejar respuestas de la API de forma consistente
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;

  const ApiResponse._({
    required this.success,
    this.data,
    this.message,
    this.error,
  });

  /// Respuesta exitosa
  factory ApiResponse.success({T? data, String? message}) {
    return ApiResponse._(success: true, data: data, message: message);
  }

  /// Respuesta con error
  factory ApiResponse.error(String error) {
    return ApiResponse._(success: false, error: error);
  }

  /// Verifica si la respuesta fue exitosa
  bool get isSuccess => success;

  /// Verifica si la respuesta tiene error
  bool get isError => !success;
}
