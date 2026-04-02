import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/firma_model.dart';
import 'package:infoapp/features/auth/data/auth_service.dart'; // ✅ IMPORTAR AuthService
import 'package:infoapp/core/env/server_config.dart';

class FirmasService {
  static String get baseUrl => ServerConfig.instance.baseUrlFor('firma');

  // ✅ NUEVO: Método para obtener headers con token (igual que servicios)
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();

    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // 1. Crear nueva firma
  static Future<Map<String, dynamic>> crearFirma(FirmaModel firma) async {
    try {
      final url = Uri.parse('$baseUrl/crear_firma.php');
      final authHeaders = await _getAuthHeaders(); // ✅ USAR authHeaders

      final response = await http.post(
        url,
        headers: authHeaders, // ✅ CAMBIO AQUÍ
        body: jsonEncode(firma.toJson()),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al crear firma',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // 2. Listar firmas con filtros opcionales
  static Future<Map<String, dynamic>> listarFirmas({
    int? idServicio,
    String? fechaDesde,
    String? fechaHasta,
    int limite = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limite': limite.toString(),
        'offset': offset.toString(),
      };

      if (idServicio != null) {
        queryParams['id_servicio'] = idServicio.toString();
      }
      if (fechaDesde != null) {
        queryParams['fecha_desde'] = fechaDesde;
      }
      if (fechaHasta != null) {
        queryParams['fecha_hasta'] = fechaHasta;
      }

      final url = Uri.parse(
        '$baseUrl/listar_firmas.php',
      ).replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders(); // ✅ USAR authHeaders
      final response = await http.get(
        url,
        headers: authHeaders,
      ); // ✅ CAMBIO AQUÍ

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final dynamic payload = data['data'];
        final List<dynamic> rawList = payload is List
            ? payload
            : payload is Map<String, dynamic>
                ? (payload['firmas'] as List?) ??
                    (payload['data'] as List?) ??
                    <dynamic>[]
                : <dynamic>[];

        final List<FirmaModel> firmas =
            rawList.map((json) => FirmaModel.fromJson(json as Map<String, dynamic>)).toList();

        final pagination = data['pagination'] ?? {'total': rawList.length};

        return {
          'success': true,
          'firmas': firmas,
          'pagination': pagination,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al listar firmas',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // 3. Obtener una firma específica por ID
  static Future<Map<String, dynamic>> obtenerFirma(int id) async {
    try {
      final url = Uri.parse(
        '$baseUrl/obtener_firma.php',
      ).replace(queryParameters: {'id': id.toString()});

      final authHeaders = await _getAuthHeaders(); // ✅ USAR authHeaders
      final response = await http.get(
        url,
        headers: authHeaders,
      ); // ✅ CAMBIO AQUÍ

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Firma no encontrada'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener firma',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // 4. Obtener firmas por servicio
  static Future<Map<String, dynamic>> obtenerFirmasPorServicio(
    int idServicio,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/firmas_por_servicio.php',
      ).replace(queryParameters: {'id_servicio': idServicio.toString()});

      final authHeaders = await _getAuthHeaders(); // ✅ USAR authHeaders
      // 🔎 Debug: log de solicitud
      // Nota: estos logs ayudan a verificar en consola si la llamada ocurre
      // y con qué parámetros/headers.
      // No afectan la UI ni el comportamiento.
      // ignore: avoid_print
      print('[FirmasService] GET ${url.toString()}');
      // ignore: avoid_print
      print('[FirmasService] Headers: ${authHeaders.isEmpty ? '{}' : authHeaders.keys.join(',')}');

      final response = await http.get(
        url,
        headers: authHeaders,
      ); // ✅ CAMBIO AQUÍ

      // ignore: avoid_print
      print('[FirmasService] Status: ${response.statusCode}');
      // ignore: avoid_print
      print('[FirmasService] Body length: ${response.body.length}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final dynamic payload = data['data'];
        final List<dynamic> rawList = payload is List
            ? payload
            : payload is Map<String, dynamic>
                ? (payload['firmas'] as List?) ??
                    (payload['data'] as List?) ??
                    <dynamic>[]
                : <dynamic>[];

        final List<FirmaModel> firmas =
            rawList.map((json) => FirmaModel.fromJson(json as Map<String, dynamic>)).toList();

        final servicio = payload is Map<String, dynamic> ? payload['servicio'] : null;
        final totalFirmas = payload is Map<String, dynamic>
            ? (payload['totalFirmas'] ?? rawList.length)
            : rawList.length;

        return {
          'success': true,
          'servicio': servicio,
          'firmas': firmas,
          'totalFirmas': totalFirmas,
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Servicio no encontrado'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener firmas del servicio',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // 5. Eliminar firma
  static Future<Map<String, dynamic>> eliminarFirma(int id) async {
    try {
      final url = Uri.parse('$baseUrl/eliminar_firma.php');
      final authHeaders = await _getAuthHeaders(); // ✅ USAR authHeaders

      final response = await http.post(
        url,
        headers: authHeaders, // ✅ CAMBIO AQUÍ
        body: jsonEncode({'id': id}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Firma no encontrada'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al eliminar firma',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // 6. Validar que no exista firma duplicada para un servicio
  static Future<bool> existeFirmaParaServicio(int idServicio) async {
    try {
      final result = await obtenerFirmasPorServicio(idServicio);

      if (result['success'] == true) {
        final totalFirmas = result['totalFirmas'] as int;
        return totalFirmas > 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
