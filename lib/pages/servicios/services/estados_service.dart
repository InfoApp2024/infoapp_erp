import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/estado_model.dart';
import '../models/transicion_model.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class EstadosService {
  static String get baseUrl => ServerConfig.instance.apiRoot();
  static String get workflowUrl => ServerConfig.instance.baseUrlFor('workflow');

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<EstadoModel>> obtenerTodosLosEstados() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/workflow/listar_estados.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        List<dynamic> estadosData = [];

        if (result is List) {
          estadosData = result;
        } else if (result['success'] == true) {
          estadosData = result['estados'] ?? [];
        }

        return estadosData
            .map((estado) => EstadoModel.fromJson(estado))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
      }
      return [];
    } catch (e) {
      //       print('Error cargando estados: $e');
      return [];
    }
  }

  static Future<EstadoModel?> obtenerEstadoInicial() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/workflow/obtener_estado_inicial.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return EstadoModel.fromJson(result['estado']);
        }
      }
      return null;
    } catch (e) {
      //       print('Error cargando estado inicial: $e');
      return null;
    }
  }

  static Future<List<TransicionModel>> obtenerTransicionesDisponibles(
    int estadoActualId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final url =
          '$workflowUrl/obtener_transiciones_disponibles.php?estado_actual_id=$estadoActualId';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        String cleanResponse = response.body.trim();
        int jsonStart = cleanResponse.indexOf('{');
        if (jsonStart > 0) {
          cleanResponse = cleanResponse.substring(jsonStart);
        }
        int jsonEnd = cleanResponse.lastIndexOf('}') + 1;
        if (jsonEnd < cleanResponse.length) {
          cleanResponse = cleanResponse.substring(0, jsonEnd);
        }

        final result = jsonDecode(cleanResponse);
        if (result['success'] == true) {
          final List<dynamic> transicionesData = result['transiciones'] ?? [];
          return transicionesData
              .map((t) => TransicionModel.fromJson(t))
              .toList();
        }
      }
      return [];
    } catch (e) {
      //       print('Error cargando transiciones: $e');
      return [];
    }
  }

  static Future<bool> cambiarEstadoServicio(
    int servicioId,
    int nuevoEstadoId,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/servicio/cambiar_estado_servicio.php'),
        headers: headers,
        body: jsonEncode({
          'servicio_id': servicioId,
          'nuevo_estado_id': nuevoEstadoId,
        }),
      );

      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      //       print('Error cambiando estado: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Obtener lista de estados base del sistema
  static Future<List<Map<String, dynamic>>> obtenerEstadosBase() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/workflow/listar_estados_base.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List<dynamic> estadosData = result['estados_base'] ?? [];
          return estadosData
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      //       print('Error cargando estados base: $e');
      return [];
    }
  }
  static Future<bool> editarTransicion(
    int id,
    String? nombre,
    String? triggerCode,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/workflow/editar_transicion.php'),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'nombre': nombre,
          'trigger_code': triggerCode,
        }),
      );

      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      return false;
    }
  }
}

