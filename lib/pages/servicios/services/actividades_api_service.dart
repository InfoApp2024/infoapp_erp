/// ============================================================================
/// ARCHIVO: actividades_api_service.dart
///
/// PROPÓSITO: Servicio especializado para actividades que:
/// - Gestiona CRUD de actividades estándar
/// - Maneja la relación actividades-servicios
/// - Implementa búsqueda y filtrado
/// - Gestiona importación masiva
///
/// USO: Servicio específico para el manejo de actividades
/// FUNCIÓN: Maneja toda la lógica relacionada con las actividades que se pueden asignar a los servicios.
/// ============================================================================
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/actividad_estandar_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class ActividadesApiService {
  // Ajusta esta URL según tu configuración
  static String get baseUrl => ServerConfig.instance.apiRoot();

  // ✅ Timeout para las peticiones
  static const Duration timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Listar todas las actividades
  static Future<List<ActividadEstandarModel>> listarActividades({
    bool? activo,
    String? busqueda,
  }) async {
    // Definir la clave de caché fuera del try/catch para que esté disponible en ambos bloques
    final keyBase =
        'cache_actividades_${activo == null ? 'all' : (activo ? '1' : '0')}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final isOnline = await ConnectivityService.instance.checkNow();

      Future<List<ActividadEstandarModel>> loadFromCache() async {
        final raw = prefs.getString(keyBase);
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
          var list =
              items
                  .map((json) => ActividadEstandarModel.fromJson(json))
                  .toList();
          if (busqueda != null && busqueda.isNotEmpty) {
            final q = busqueda.toLowerCase();
            list =
                list
                    .where((a) => a.actividad.toLowerCase().contains(q))
                    .toList();
          }
          return list;
        } catch (_) {
          return [];
        }
      }

      if (!isOnline) {
        final cached = await loadFromCache();
        if (cached.isNotEmpty) return cached;
        // Sin caché, continuar a intentar red
      }

      final queryParams = <String, String>{};
      if (activo != null) {
        queryParams['activo'] = activo ? '1' : '0';
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        queryParams['busqueda'] = busqueda;
      }

      final uri = Uri.parse(
        '$baseUrl/workflow/listarActividadesEstandar.php',
      ).replace(queryParameters: queryParams);
      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> actividadesJson = data['data'] ?? [];

          // Guardar caché cruda del resultado base (sin busqueda específica)
          try {
            final payload = jsonEncode({
              'items': actividadesJson,
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
            await prefs.setString(keyBase, payload);
          } catch (_) {}

          var list =
              actividadesJson
                  .map((json) => ActividadEstandarModel.fromJson(json))
                  .toList();
          if (busqueda != null && busqueda.isNotEmpty) {
            final q = busqueda.toLowerCase();
            list =
                list
                    .where((a) => a.actividad.toLowerCase().contains(q))
                    .toList();
          }
          return list;
        } else {
          final cached = await loadFromCache();
          if (cached.isNotEmpty) return cached;
          throw Exception(data['message'] ?? 'Error al listar actividades');
        }
      } else {
        final cached = await loadFromCache();
        if (cached.isNotEmpty) return cached;
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyBase);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          final items =
              (decoded is Map && decoded['items'] is List)
                  ? decoded['items'] as List<dynamic>
                  : (decoded is List ? decoded : []);
          var list =
              items
                  .map((json) => ActividadEstandarModel.fromJson(json))
                  .toList();
          if (busqueda != null && busqueda.isNotEmpty) {
            final q = busqueda.toLowerCase();
            list =
                list
                    .where((a) => a.actividad.toLowerCase().contains(q))
                    .toList();
          }
          return list;
        } catch (_) {}
      }
      throw Exception('Error al listar actividades: $e');
    }
  }

  /// Obtener una actividad por ID
  static Future<ActividadEstandarModel> obtenerActividad(int id) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/workflow/obtenerActividadEstandar.php?id=$id'),
            headers: authHeaders,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          return ActividadEstandarModel.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener actividad');
        }
      } else {
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      //       print('❌ Error en obtenerActividad: $e');
      throw Exception('Error al obtener actividad: $e');
    }
  }

  /// Crear nueva actividad
  static Future<ActividadEstandarModel> crearActividad(
    ActividadEstandarModel actividad,
  ) async {
    try {
      //       print('🚀 DEBUG API SERVICE:');
      //       print('✨ API Service recibió modelo:');
      //       print('   - actividad: "${actividad.actividad}"');
      //       print('   - activo: ${actividad.activo}');
      //       print('   - toJson: ${actividad.toJson()}');

      // Enviar activo como entero (1/0) para compatibilidad con PHP
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('usuario_id');

      final Map<String, dynamic> bodyMap = {
        if (actividad.id != null) 'id': actividad.id,
        'actividad': actividad.actividad,
        'activo': actividad.activo ? 1 : 0,
        'cant_hora': actividad.cantHora,
        'num_tecnicos': actividad.numTecnicos,
        'id_user': userId,
        'sistema_id': actividad.sistemaId,
      };
      final jsonBody = json.encode(bodyMap);
      //       print('📤 JSON que se enviará: $jsonBody');

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/workflow/crearActividadEstandar.php'),
            headers: authHeaders,
            body: jsonBody,
          )
          .timeout(timeout);

      //       print('📩 Respuesta del servidor:');
      //       print('   - Status: ${response.statusCode}');
      //       print('   - Body: ${response.body}');

      // ✅ Verificar errores PHP/HTML
      if (_isHtmlError(response.body)) {
        //         print('⚠️ RESPUESTA HTML DEL SERVIDOR (posible error PHP):');
        //         print(response.body);
        throw Exception('Error del servidor. Revise los logs del servidor.');
      }

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);

          if (data['success'] == true) {
            return ActividadEstandarModel.fromJson(data['data']);
          } else {
            // Priorizar 'error' sobre 'message'
            throw Exception(data['error'] ?? data['message'] ?? 'Error al crear actividad');
          }
        } catch (e) {
          if (e.toString().contains('Error al crear actividad') || 
              e.toString().contains('Ya existe')) {
            rethrow;
          }
          throw Exception('Respuesta inválida del servidor');
        }
      } else if (response.statusCode == 400 || response.statusCode == 500) {
        // Intentar obtener el mensaje de error del backend
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          final msg = data['error'] ?? data['message'];
          if (msg != null) {
            throw Exception(msg);
          }
        } catch (_) {
          // Si falla el decode, usar error genérico
        }
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      } else {
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      // Limpiar el mensaje de error para evitar "Exception: Exception: ..."
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  /// Actualizar actividad
  static Future<ActividadEstandarModel> actualizarActividad(
    ActividadEstandarModel actividad,
  ) async {
    try {
      //       print('🚀 DEBUG ACTUALIZAR ACTIVIDAD:');
      //       print('✨ API Service recibió modelo:');
      //       print('   - id: ${actividad.id}');
      //       print('   - actividad: "${actividad.actividad}"');
      //       print('   - activo: ${actividad.activo}');
      //       print('   - toJson: ${actividad.toJson()}');

      // ✅ Validación previa
      if (actividad.id == null) {
        throw Exception('ID de actividad es requerido para actualizar');
      }

      // Enviar activo como entero (1/0) para compatibilidad con PHP
      final Map<String, dynamic> bodyMap = {
        'id': actividad.id,
        'actividad': actividad.actividad.trim(),
        'activo': actividad.activo ? 1 : 0,
        'cant_hora': actividad.cantHora,
        'num_tecnicos': actividad.numTecnicos,
        'sistema_id': actividad.sistemaId,
      };
      final jsonBody = json.encode(bodyMap);
      //       print('📤 JSON que se enviará: $jsonBody');
      //       print('🔗 URL: $baseUrl/actualizarActividadEstandar.php');

      // ✅ Usar POST (compatible con el PHP)
      final authHeaders = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/workflow/actualizarActividadEstandar.php'),
            headers: authHeaders,
            body: jsonBody,
          )
          .timeout(
            timeout,
            onTimeout: () {
              throw Exception('Tiempo de espera agotado (30 segundos)');
            },
          );

      //       print('📩 Respuesta del servidor:');
      //       print('   - Status: ${response.statusCode}');
      //       print('   - Headers: ${response.headers}');
      //       print('   - Body length: ${response.body.length}');
      //       print('   - Body: ${response.body}');

      // ✅ Verificar si el body está vacío
      if (response.body.isEmpty) {
        //         print('⚠️ Body vacío - posible error fatal en PHP');
        throw Exception(
          'El servidor no devolvió respuesta. Error código ${response.statusCode}',
        );
      }

      // ✅ Verificar errores PHP/HTML
      if (_isHtmlError(response.body)) {
        //         print('⚠️ RESPUESTA HTML DEL SERVIDOR (posible error PHP):');
        //         print(response.body);

        // Intentar extraer mensaje de error si es posible
        final errorMessage = _extractPhpError(response.body);
        throw Exception(
          errorMessage ?? 'Error del servidor. Revise los logs del servidor.',
        );
      }

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          //           print('✅ JSON decodificado: $data');

          if (data['success'] == true) {
            //             print('✅ Actividad actualizada exitosamente');
            return ActividadEstandarModel.fromJson(data['data']);
          } else {
            //             print('❌ Error del servidor: ${data['message']}');
            throw Exception(data['message'] ?? 'Error al actualizar actividad');
          }
        } catch (e) {
          //           print('❌ Error parseando JSON: $e');
          //           print('   Body recibido: ${response.body}');
          throw Exception('Respuesta inválida del servidor: $e');
        }
      } else if (response.statusCode == 500 || response.statusCode == 400) {
        // ✅ Manejo específico para error 500 y 400
        //         print('❌ Error ${response.statusCode}');

        // Intentar parsear si hay JSON
        try {
          final data = json.decode(response.body);
          final message =
              data['error'] ?? data['message'] ?? 'Error del servidor';
          throw Exception(message);
        } catch (e) {
          if (e.toString().contains('Exception:')) rethrow;
          throw Exception(
            'Error ${response.statusCode}. Verifique los datos o logs.',
          );
        }
      } else {
        //         print('❌ Error HTTP: ${response.statusCode}');
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase ?? "Sin descripción"}',
        );
      }
    } catch (e) {
      //       print('❌ Error en actualizarActividad: $e');

      // Re-lanzar con mensaje más descriptivo
      if (e.toString().contains('SocketException')) {
        throw Exception('Error de conexión. Verifique su conexión a internet.');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Tiempo de espera agotado. Intente nuevamente.');
      } else {
        final msg = e.toString().replaceAll('Exception: ', '');
        throw Exception(msg);
      }
    }
  }

  /// Eliminar actividad
  static Future<void> eliminarActividad(int id) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/workflow/eliminarActividadEstandar.php?id=$id'),
            headers: authHeaders,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Error al eliminar actividad');
        }
      } else {
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      //       print('❌ Error en eliminarActividad: $e');
      throw Exception('Error al eliminar actividad: $e');
    }
  }

  /// Importar actividades masivamente
  static Future<Map<String, dynamic>> importarActividades(
    List<Map<String, dynamic>> actividades, {
    bool sobrescribir = false,
    int? sistemaId, // ✅ AGREGADO
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('usuario_id');
      final authHeaders = await _getAuthHeaders();

      final response = await http
          .post(
            Uri.parse('$baseUrl/workflow/importarActividadesEstandar.php'),
            headers: authHeaders,
            body: json.encode({
              'actividades': actividades,
              'sobrescribir': sobrescribir,
              'id_user': userId,
              'sistema_id': sistemaId, // ✅ ENVIADO AL BACKEND
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Error al importar actividades');
        }
      } else {
        throw Exception(
          'Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      //       print('❌ Error en importarActividades: $e');
      throw Exception('Error al importar actividades: $e');
    }
  }

  /// ✅ Detectar si la respuesta es un error HTML/PHP
  static bool _isHtmlError(String body) {
    final lowerBody = body.toLowerCase();
    return lowerBody.contains('<!doctype') ||
        lowerBody.contains('<html') ||
        lowerBody.contains('<br') ||
        lowerBody.contains('warning:') ||
        lowerBody.contains('error:') ||
        lowerBody.contains('fatal error:') ||
        lowerBody.contains('parse error:') ||
        lowerBody.contains('notice:');
  }

  /// ✅ Intentar extraer mensaje de error PHP
  static String? _extractPhpError(String htmlBody) {
    // Buscar patrones comunes de error PHP
    final patterns = [
      RegExp(r'Fatal error:(.*?)in', multiLine: true, caseSensitive: false),
      RegExp(r'Warning:(.*?)in', multiLine: true, caseSensitive: false),
      RegExp(r'Parse error:(.*?)in', multiLine: true, caseSensitive: false),
      RegExp(r'Error:(.*?)in', multiLine: true, caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(htmlBody);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }
}
