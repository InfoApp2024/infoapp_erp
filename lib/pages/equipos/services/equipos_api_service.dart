import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/pages/equipos/models/equipo_model.dart';
import 'package:infoapp/core/env/server_config.dart';

class EquiposApiService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('equipo');
  static String get _rootUrl => ServerConfig.instance.apiRoot();

  // Cambiar a false en producción
  static const bool _debug = true;

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Logging condicional para debug
  static void _log(String message) {
    if (_debug) {
      //       print(message);
    }
  }

  /// Obtener headers con autenticación JWT
  static Future<Map<String, String>> _getAuthHeaders({
    bool forBinary = false,
  }) async {
    final token = await AuthService.getBearerToken();

    if (forBinary) {
      // Para descargas binarias
      return {
        'Accept': 'application/octet-stream',
        if (token != null) 'Authorization': token,
      };
    }

    // Para JSON
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Manejar petición genérica con errores comunes
  static Future<T?> _handleRequest<T>({
    required Future<http.Response> Function() request,
    required T? Function(http.Response response) onSuccess,
    required String errorMessage,
    List<int> successCodes = const [200, 201],
  }) async {
    try {
      final resp = await request();
      _log('📨 $errorMessage - Status: ${resp.statusCode}');

      if (successCodes.contains(resp.statusCode)) {
        return onSuccess(resp);
      }

      // Manejar token expirado
      if (resp.statusCode == 401) {
        _log('❌ Token inválido o expirado');
        await AuthService.clearAuthData();
        throw Exception('Token inválido o expirado');
      }

      // Manejar conflicto
      if (resp.statusCode == 409) {
        _log('⚠️ Conflicto: ${resp.body}');
        throw Exception('Recurso duplicado o conflicto');
      }

      // Manejar no encontrado
      if (resp.statusCode == 404) {
        _log('❌ Recurso no encontrado');
        throw Exception('Recurso no encontrado');
      }

      // Manejar error del servidor
      if (resp.statusCode >= 500) {
        _log('❌ Error del servidor: ${resp.statusCode}');
        throw Exception('Error del servidor');
      }

      _log('❌ Error HTTP ${resp.statusCode}');
      throw Exception('Error: ${resp.statusCode}');
    } catch (e) {
      _log('❌ $errorMessage: $e');
      return null;
    }
  }

  /// Parsear respuesta JSON con estructura de éxito
  static Map<String, dynamic>? _parseSuccessResponse(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      _log('❌ Error parseando JSON: $e');
    }
    return null;
  }

  // ============================================
  // LISTAR EQUIPOS
  // ============================================

  /// Listar todos los equipos
  static Future<List<EquipoModel>> listarEquipos() async {
    return await _handleRequest<List<EquipoModel>>(
          request: () async {
            final authHeaders = await _getAuthHeaders();
            final url = Uri.parse('$_baseUrl/listar_equipos.php');
            _log('📡 [Equipos] GET: $url');
            return await http.get(url, headers: authHeaders);
          },
          onSuccess: (resp) {
            final decoded = jsonDecode(resp.body);

            // Caso 1: Array directo de equipos
            if (decoded is List) {
              _log('✅ Respuesta tipo List');
              return decoded
                  .map((e) => EquipoModel.fromJson(e as Map<String, dynamic>))
                  .toList();
            }

            // Caso 2: Objeto con estructura { success, data: { equipos: [...] } }
            if (decoded is Map<String, dynamic> && decoded['success'] == true) {
              final data = decoded['data'] as Map<String, dynamic>?;
              if (data != null) {
                final list = (data['equipos'] as List<dynamic>? ?? []);
                _log('✅ Respuesta tipo Map - ${list.length} equipos');
                return list
                    .map((e) => EquipoModel.fromJson(e as Map<String, dynamic>))
                    .toList();
              }
            }

            _log('⚠️ Respuesta no reconocida');
            return [];
          },
          errorMessage: '[Equipos] listar todos',
        ) ??
        [];
  }

  /// Listar equipos con paginación, búsqueda y filtros
  static Future<Map<String, dynamic>> listarEquiposPaginado({
    int pagina = 1,
    int limite = 20,
    String? buscar,
    int? activo,
    int? estadoId,
    String sortBy = 'id',
    String sortOrder = 'DESC',
  }) async {
    final defaultResponse = {
      'equipos': <EquipoModel>[],
      'total': 0,
      'pagina': pagina,
      'totalPaginas': 1,
      'tieneSiguiente': false,
      'tieneAnterior': false,
      'campos_adicionales': <int, List<dynamic>>{}, // 🆕 Data merged
      'mensaje': 'Sin datos',
    };

    return await _handleRequest<Map<String, dynamic>>(
          request: () async {
            final authHeaders = await _getAuthHeaders();
            final uri = Uri.parse('$_baseUrl/listar_equipos.php').replace(
              queryParameters: {
                'pagina': pagina.toString(),
                'limite': limite.toString(),
                if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
                if (activo != null) 'activo': activo.toString(),
                if (estadoId != null) 'estado_id': estadoId.toString(),
                'sort_by': sortBy,
                'sort_order': sortOrder,
              },
            );
            _log('📡 [Equipos] GET: $uri');
            return await http.get(uri, headers: authHeaders);
          },
          onSuccess: (resp) {
            final jsonData = _parseSuccessResponse(resp);

            if (jsonData == null || jsonData['success'] != true) {
              _log('⚠️ Respuesta sin éxito');
              return defaultResponse;
            }

            final data = jsonData['data'] as Map<String, dynamic>?;
            if (data == null) {
              _log('⚠️ Sin data en respuesta');
              return defaultResponse;
            }

            final equiposJson = (data['equipos'] as List<dynamic>? ?? []);
            final pag = (data['paginacion'] as Map<String, dynamic>? ?? {});
            // 🆕 Extraer datos mergeados (defensivo ante [] vs {})
            final dynamic rawCampos = data['campos_adicionales'];
            final Map<String, dynamic> camposAdicionalesJson =
                (rawCampos is Map<String, dynamic>) ? rawCampos : {};

            _log(
              '✅ ${equiposJson.length} equipos en página $pagina (Merge: ${camposAdicionalesJson.isNotEmpty})',
            );

            // Convertir mapa de campos a formato tipado
            final camposMap = <int, List<dynamic>>{};
            camposAdicionalesJson.forEach((key, value) {
              final id = int.tryParse(key);
              if (id != null && value is List) {
                camposMap[id] = value;
              }
            });

            return {
              'equipos':
                  equiposJson
                      .map(
                        (e) => EquipoModel.fromJson(e as Map<String, dynamic>),
                      )
                      .toList(),
              'total':
                  pag['total_registros'] ??
                  (data['total'] ?? equiposJson.length),
              'pagina': pag['pagina_actual'] ?? (data['pagina'] ?? pagina),
              'totalPaginas':
                  pag['total_paginas'] ?? (data['totalPaginas'] ?? 1),
              'tieneSiguiente':
                  pag['tiene_siguiente'] ?? (data['tieneSiguiente'] ?? false),
              'tieneAnterior':
                  pag['tiene_anterior'] ?? (data['tieneAnterior'] ?? false),
              'campos_adicionales': camposMap,
              'mensaje': jsonData['mensaje'] ?? 'Datos cargados',
            };
          },
          errorMessage: '[Equipos] listar paginado',
        ) ??
        defaultResponse;
  }

  /// Obtener detalle de un equipo por ID
  static Future<EquipoModel?> obtenerEquipo({required int id}) async {
    if (id <= 0) {
      _log('❌ ID inválido');
      return null;
    }

    return await _handleRequest<EquipoModel>(
      request: () async {
        final authHeaders = await _getAuthHeaders();
        final url = Uri.parse('$_baseUrl/obtener_equipo.php?id=$id');
        _log('📡 [Equipos] GET: $url');
        return await http.get(url, headers: authHeaders);
      },
      onSuccess: (resp) {
        if (resp.body.isEmpty) {
          _log('⚠️ Respuesta vacía');
          return null;
        }
        final data = _parseSuccessResponse(resp);
        if (data == null) return null;
        _log('✅ Equipo obtenido: ${data['nombre']}');
        return EquipoModel.fromJson(data);
      },
      errorMessage: '[Equipos] obtener ID: $id',
    );
  }

  // ============================================
  // CREAR EQUIPO
  // ============================================

  /// Crear nuevo equipo (retorna {success, message, error_code})
  static Future<Map<String, dynamic>> crearEquipo(EquipoModel equipo) async {
    try {
      // Validación de campos requeridos
      if (equipo.nombre?.isEmpty ?? true) {
        return {'success': false, 'message': 'Nombre requerido'};
      }

      if (equipo.placa?.isEmpty ?? true) {
        return {'success': false, 'message': 'Placa requerida'};
      }

      if (equipo.nombreEmpresa?.isEmpty ?? true) {
        return {'success': false, 'message': 'Empresa requerida'};
      }

      final authHeaders = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/crear_equipo.php');

      final jsonData = equipo.toJson();
      _log('📤 [Equipos] POST crear: ${jsonEncode(jsonData)}');

      final resp = await http.post(
        url,
        headers: authHeaders,
        body: jsonEncode(jsonData),
      );

      _log('📨 [Equipos] Response: ${resp.statusCode} ${resp.body}');

      // Éxito: 200 o 201
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final result = _parseSuccessResponse(resp);
        if (result?['success'] == true) {
          return {'success': true, 'message': 'Equipo creado'};
        }
      }

      // Conflictos (409)
      if (resp.statusCode == 409) {
        final body = jsonDecode(resp.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Conflicto de datos',
          'error_code': body['error_code'],
        };
      }

      if (resp.statusCode == 401) {
        await AuthService.clearAuthData();
        return {'success': false, 'message': 'Sesión expirada'};
      }

      return {'success': false, 'message': 'Error ${resp.statusCode}'};
    } catch (e) {
      _log('❌ Error creando: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // ============================================
  // ACTUALIZAR EQUIPO
  // ============================================

  /// Actualizar equipo (retorna {success, message, error_code})
  static Future<Map<String, dynamic>> actualizarEquipo(
    EquipoModel equipo,
  ) async {
    try {
      if (equipo.id == null) {
        return {'success': false, 'message': 'ID requerido'};
      }

      final authHeaders = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/editar_equipo.php');

      final jsonData = equipo.toJson();
      _log('📤 [Equipos] POST actualizar: ${jsonEncode(jsonData)}');

      final resp = await http.post(
        url,
        headers: authHeaders,
        body: jsonEncode(jsonData),
      );

      if (resp.statusCode == 200) {
        final result = _parseSuccessResponse(resp);
        if (result?['success'] == true) {
          return {'success': true, 'message': 'Actualizado'};
        }
      }

      if (resp.statusCode == 409) {
        final body = jsonDecode(resp.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Conflicto',
          'error_code': body['error_code'],
        };
      }

      if (resp.statusCode == 401) {
        await AuthService.clearAuthData();
        return {'success': false, 'message': 'Sesión expirada'};
      }

      return {'success': false, 'message': 'Error ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ============================================
  // ELIMINAR EQUIPO
  // ============================================

  /// Eliminar equipo (soft delete)
  static Future<bool> eliminarEquipo({required int id}) async {
    try {
      if (id <= 0) {
        _log('❌ ID de equipo inválido');
        throw Exception('ID de equipo inválido');
      }

      final authHeaders = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/eliminar_equipo.php');

      _log('📤 [Equipos] POST eliminar equipo $id');

      final resp = await http.post(
        url,
        headers: authHeaders,
        body: jsonEncode({'id': id}),
      );

      _log('📨 [Equipos] eliminarEquipo status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final result = _parseSuccessResponse(resp);
        if (result?['success'] == true) {
          _log('✅ Equipo eliminado exitosamente');
          return true;
        }
      }

      if (resp.statusCode == 401) {
        _log('❌ Token inválido');
        await AuthService.clearAuthData();
        return false;
      }

      if (resp.statusCode == 404) {
        _log('❌ Equipo no encontrado');
        return false;
      }

      _log('❌ Error eliminando equipo: ${resp.statusCode}');
      return false;
    } catch (e) {
      _log('❌ Error eliminando equipo: $e');
      return false;
    }
  }

  // ============================================
  // IMPORT/EXPORT/PLANTILLA
  // ============================================

  /// Descargar plantilla Excel vacía
  static Future<Uint8List?> descargarPlantillaEquipos() async {
    return await _handleRequest<Uint8List>(
      request: () async {
        final headers = await _getAuthHeaders(forBinary: true);
        final url = Uri.parse('$_rootUrl/equipo/template_equipos.php');
        _log('📡 [Equipos] GET plantilla: $url');
        return await http.get(url, headers: headers);
      },
      onSuccess: (resp) {
        _log('✅ Plantilla descargada: ${resp.bodyBytes.length} bytes');
        return resp.bodyBytes;
      },
      errorMessage: '[Equipos] descargar plantilla',
    );
  }

  /// Exportar todos los equipos como Excel
  static Future<Uint8List?> exportarEquipos() async {
    return await _handleRequest<Uint8List>(
      request: () async {
        final headers = await _getAuthHeaders();
        headers['Accept'] = 'application/octet-stream';
        final url = Uri.parse('$_rootUrl/equipo/exportar_equipos.php');
        _log('📡 [Equipos] POST exportar: $url');
        return await http.post(url, headers: headers, body: jsonEncode({}));
      },
      onSuccess: (resp) {
        _log('✅ Equipos exportados: ${resp.bodyBytes.length} bytes');
        return resp.bodyBytes;
      },
      errorMessage: '[Equipos] exportar',
    );
  }

  /// Exportar equipos específicos
  static Future<Uint8List?> exportarEquiposSeleccionados({
    required List<int> equipoIds,
  }) async {
    if (equipoIds.isEmpty) {
      _log('❌ No hay equipos seleccionados');
      return null;
    }

    return await _handleRequest<Uint8List>(
      request: () async {
        final headers = await _getAuthHeaders();
        headers['Accept'] = 'application/octet-stream';
        final url = Uri.parse('$_rootUrl/equipo/exportar_equipos.php');
        _log('📡 [Equipos] POST exportar ${equipoIds.length} equipos');
        return await http.post(
          url,
          headers: headers,
          body: jsonEncode({'equipos': equipoIds}),
        );
      },
      onSuccess: (resp) {
        _log('✅ Equipos exportados: ${resp.bodyBytes.length} bytes');
        return resp.bodyBytes;
      },
      errorMessage: '[Equipos] exportar seleccionados',
    );
  }

  /// Importar equipos desde archivo Excel
  static Future<Map<String, dynamic>?> importarEquipos({
    required String archivoBase64,
    required String nombreArchivo,
  }) async {
    if (archivoBase64.isEmpty || nombreArchivo.isEmpty) {
      _log('❌ Archivo base64 o nombre vacío');
      return null;
    }

    return await _handleRequest<Map<String, dynamic>>(
      request: () async {
        final headers = await _getAuthHeaders();
        final url = Uri.parse('$_rootUrl/equipo/importar_equipos_web.php');
        _log('📡 [Equipos] POST importar: $nombreArchivo');
        return await http.post(
          url,
          headers: headers,
          body: jsonEncode({
            'archivo_base64': archivoBase64,
            'nombre_archivo': nombreArchivo,
          }),
        );
      },
      onSuccess: (resp) {
        final result = _parseSuccessResponse(resp);
        if (result != null) {
          _log('✅ Importación completada');
          return result;
        }
        return {'success': true, 'message': 'Importación completada'};
      },
      errorMessage: '[Equipos] importar $nombreArchivo',
    );
  }

  // ============================================
  // UTILIDADES
  // ============================================

  /// Limpiar cache/datos locales
  static void limpiarCache() {
    _log('🧹 Limpiando cache de equipos');
    // Aquí podrías implementar limpieza de cache local si lo necesitas
  }

  /// Obtener estadísticas de equipos
  static Future<Map<String, dynamic>?> obtenerEstadisticas() async {
    try {
      final authHeaders = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/estadisticas_equipos.php');
      _log('📡 [Equipos] GET estadísticas: $url');

      final resp = await http.get(url, headers: authHeaders);

      if (resp.statusCode == 200) {
        final result = _parseSuccessResponse(resp);
        if (result != null) {
          _log('✅ Estadísticas obtenidas');
          return result;
        }
      }

      if (resp.statusCode == 401) {
        await AuthService.clearAuthData();
      }

      return null;
    } catch (e) {
      _log('❌ Error obteniendo estadísticas: $e');
      return null;
    }
  }
}
