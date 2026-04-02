import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/operacion_model.dart';

class ServicioOperacionesApiService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<OperacionModel>> listarOperaciones(int servicioId) async {
    try {
      final headers = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final url = Uri.parse('$_baseUrl/operaciones/listar_operaciones.php?servicio_id=$servicioId${token != null ? '&token=$token' : ''}');
      
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'] ?? [];
          return data.map((json) => OperacionModel.fromJson(json)).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> crearOperacion(OperacionModel operacion) async {
    try {
      final headers = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final url = Uri.parse('$_baseUrl/operaciones/crear_operacion.php${token != null ? '?token=$token' : ''}');
      
      final response = await http.post(
        url, 
        headers: headers, 
        body: jsonEncode(operacion.toJson())
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': result['success'] == true,
          'message': result['message'] ?? 'Operación creada'
        };
      }

      if (response.statusCode >= 400) {
        final message = result['message']?.toString() ?? 'Error desconocido';
        if (message.contains('estado final')) {
          print('No se pueden crear operaciones en un estado final');
        } else {
          if (kDebugMode) {
            print('?? [ServicioOperacionesApiService] Error ${response.statusCode}: $message');
          }
        }
        return {
          'success': false,
          'message': message
        };
      }

      return {
        'success': false,
        'message': 'Error inesperado (${response.statusCode})'
      };
    } catch (e) {
      if (kDebugMode) {
        print('?? Error en crearOperacion: $e');
      }
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> actualizarOperacion(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final url = Uri.parse('$_baseUrl/operaciones/actualizar_operacion.php${token != null ? '?token=$token' : ''}');
      
      final body = {...data, 'id': id};
      
      final response = await http.post(
        url, 
        headers: headers, 
        body: jsonEncode(body)
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': result['success'] == true,
          'message': result['message'] ?? 'Operación actualizada'
        };
      }

      if (response.statusCode >= 400) {
        final message = result['message']?.toString() ?? 'Error desconocido';
        return {
          'success': false,
          'message': message
        };
      }

      return {
        'success': false,
        'message': 'Error inesperado (${response.statusCode})'
      };
    } catch (e) {
      if (kDebugMode) {
        print('?? Error en actualizarOperacion: $e');
      }
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> eliminarOperacion(int id) async {
    try {
      final headers = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final url = Uri.parse('$_baseUrl/operaciones/eliminar_operacion.php${token != null ? '?token=$token' : ''}');
      
      final response = await http.post(
        url, 
        headers: headers, 
        body: jsonEncode({'id': id})
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': result['success'] == true,
          'message': result['message'] ?? 'Operación eliminada'
        };
      }

      if (response.statusCode >= 400) {
        final message = result['message']?.toString() ?? 'Error desconocido';
        return {
          'success': false,
          'message': message
        };
      }

      return {
        'success': false,
        'message': 'Error inesperado (${response.statusCode})'
      };
    } catch (e) {
      if (kDebugMode) {
        print('?? Error en eliminarOperacion: $e');
      }
      return {
        'success': false,
        'message': 'Error de conexión: $e'
      };
    }
  }
}
