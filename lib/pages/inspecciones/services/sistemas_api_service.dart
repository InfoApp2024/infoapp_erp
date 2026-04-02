/// ============================================================================
/// ARCHIVO: sistemas_api_service.dart
///
/// PROPÓSITO: Servicio de API para gestión de sistemas de equipos
/// ============================================================================
library;
// library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/sistema_model.dart';

class SistemasApiService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  // Headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Listar todos los sistemas
  static Future<List<SistemaModel>> listarSistemas({
    bool? activo,
    String? buscar,
  }) async {
    try {
      final queryParams = <String, String>{
        if (activo != null) 'activo': activo ? '1' : '0',
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
      };

      final uri = Uri.parse('$_baseUrl/sistemas/listar.php')
          .replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final sistemasJson = jsonData['data'] as List;
          return sistemasJson
              .map((json) => SistemaModel.fromJson(json))
              .toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Error obteniendo sistemas');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error obteniendo sistemas: $e');
    }
  }

  /// Crear nuevo sistema
  static Future<SistemaModel> crearSistema({
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    try {
      final requestData = {
        'nombre': nombre,
        'descripcion': descripcion ?? '',
        'activo': activo ? 1 : 0,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/sistemas/crear.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          return SistemaModel.fromJson(result['data']);
        } else {
          throw Exception(result['message'] ?? 'Error del servidor');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al crear sistema: $e');
    }
  }

  /// Actualizar sistema existente
  static Future<bool> actualizarSistema({
    required int sistemaId,
    String? nombre,
    String? descripcion,
    bool? activo,
  }) async {
    try {
      final requestData = {
        'id': sistemaId,
        if (nombre != null) 'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        if (activo != null) 'activo': activo ? 1 : 0,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/sistemas/actualizar.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al actualizar sistema: $e');
    }
  }

  /// Eliminar sistema
  static Future<bool> eliminarSistema(int sistemaId) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/sistemas/eliminar.php'),
        headers: authHeaders,
        body: jsonEncode({'id': sistemaId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al eliminar sistema: $e');
    }
  }
}
