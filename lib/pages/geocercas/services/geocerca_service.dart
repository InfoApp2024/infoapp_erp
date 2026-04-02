import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../models/geocerca_model.dart';
import '../models/registro_geocerca_model.dart';

class GeocercaService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('geocercas');

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // Listar Geocercas (Admin)
  static Future<List<Geocerca>> listarGeocercas() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/listar.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List list = data['data'];
          return list.map((e) => Geocerca.fromJson(e)).toList();
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al listar geocercas: $e');
    }
  }

  // Crear Geocerca
  static Future<void> crearGeocerca(Geocerca geocerca) async {
    try {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({
        'nombre': geocerca.nombre,
        'latitud': geocerca.latitud,
        'longitud': geocerca.longitud,
        'radio': geocerca.radio,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/crear.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al crear geocerca: $e');
    }
  }

  // Actualizar Geocerca
  static Future<void> actualizarGeocerca(Geocerca geocerca) async {
    try {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({
        'id': geocerca.id,
        'nombre': geocerca.nombre,
        'latitud': geocerca.latitud,
        'longitud': geocerca.longitud,
        'radio': geocerca.radio,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/actualizar.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al actualizar geocerca: $e');
    }
  }

  // Eliminar Geocerca
  static Future<void> eliminarGeocerca(int id) async {
    try {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({'id': id});

      final response = await http.post(
        Uri.parse('$_baseUrl/eliminar.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al eliminar geocerca: $e');
    }
  }

  // Registrar Ingreso con reintentos (Original JSON)
  static Future<int> registrarIngreso(int geocercaId) async {
    return _retryRequest(() async {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({'geocerca_id': geocercaId});

      final response = await http.post(
        Uri.parse('$_baseUrl/registrar_ingreso.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['registro_id'];
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    });
  }

  // Registrar Salida con reintentos
  static Future<void> registrarSalida(int geocercaId) async {
    return _retryRequest(() async {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({'geocerca_id': geocercaId});

      final response = await http.post(
        Uri.parse('$_baseUrl/registrar_salida.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    });
  }

  /// Registra ingreso con foto y timestamps separados
  /// [detectionTime]: Tiempo exacto de detección GPS
  /// [captureTime]: Tiempo de captura de la foto
  static Future<int> registrarIngresoConFoto({
    required int geocercaId,
    required DateTime detectionTime,
    required DateTime captureTime,
    required File photoFile,
  }) async {
    return _retryRequest(() async {
      final headers = await _getAuthHeaders();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/registrar_ingreso.php'),
      );

      request.headers.addAll(headers);

      // Enviar ambos timestamps
      request.fields['geocerca_id'] = geocercaId.toString();
      request.fields['detection_time'] = detectionTime.toIso8601String();
      request.fields['capture_time'] = captureTime.toIso8601String();

      // Adjuntar foto
      request.files.add(
        await http.MultipartFile.fromPath('foto', photoFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['registro_id'] as int;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    });
  }

  /// Registra salida con foto y timestamps separados
  /// [detectionTime]: Tiempo exacto de detección GPS
  /// [captureTime]: Tiempo de captura de la foto
  static Future<void> registrarSalidaConFoto({
    required int geocercaId,
    required DateTime detectionTime,
    required DateTime captureTime,
    required File photoFile,
  }) async {
    return _retryRequest(() async {
      final headers = await _getAuthHeaders();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/registrar_salida.php'),
      );

      request.headers.addAll(headers);

      // Enviar ambos timestamps
      request.fields['geocerca_id'] = geocercaId.toString();
      request.fields['detection_time'] = detectionTime.toIso8601String();
      request.fields['capture_time'] = captureTime.toIso8601String();

      // Adjuntar foto
      request.files.add(
        await http.MultipartFile.fromPath('foto', photoFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    });
  }


  // Helper para reintentos simplificado
  static Future<T> _retryRequest<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await action();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        // Esperar un poco antes de reintentar (exponencial simple)
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    throw Exception('Error después de $maxRetries intentos');
  }

  // Listar Registros (Reporte)
  static Future<Map<String, dynamic>> listarRegistros({
    int page = 1,
    int limit = 20,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    int? geocercaId,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      String query = '?page=$page&limit=$limit';
      if (fechaInicio != null) {
        query += '&fecha_inicio=${fechaInicio.toIso8601String().split("T")[0]}';
      }
      if (fechaFin != null) {
        query += '&fecha_fin=${fechaFin.toIso8601String().split("T")[0]}';
      }
      if (usuarioId != null) query += '&usuario_id=$usuarioId';
      if (geocercaId != null) query += '&geocerca_id=$geocercaId';

      final response = await http.get(
        Uri.parse('$_baseUrl/listar_registros.php$query'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List list = data['data'];
          return {
            'data': list.map((e) => RegistroGeocerca.fromJson(e)).toList(),
            'pagination': data['pagination'],
          };
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al listar registros: $e');
    }
  }

  // Obtener datos para reporte (Excel)
  static Future<List<Map<String, dynamic>>> obtenerDatosReporte({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    int? geocercaId,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      String query = '?';
      if (fechaInicio != null) {
        query += 'fecha_inicio=${fechaInicio.toIso8601String().split("T")[0]}&';
      }
      if (fechaFin != null) {
        query += 'fecha_fin=${fechaFin.toIso8601String().split("T")[0]}&';
      }
      if (usuarioId != null) query += 'usuario_id=$usuarioId&';
      if (geocercaId != null) query += 'geocerca_id=$geocercaId&';

      final response = await http.get(
        Uri.parse('$_baseUrl/reporte_registros.php$query'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener datos del reporte: $e');
    }
  }

  // Obtener monitoreo en tiempo real
  static Future<Map<String, dynamic>> obtenerMonitoreoTiempoReal() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/monitoreo_tiempo_real.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener monitoreo en tiempo real: $e');
    }
  }

  /// Obtener registros abiertos (sin fecha_salida) del usuario actual
  /// Usado para recuperar el estado al reiniciar la app
  static Future<List<Map<String, dynamic>>> obtenerRegistrosAbiertos() async {
    return _retryRequest(() async {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/obtener_registros_abiertos.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['registros_abiertos']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    });
  }
}
