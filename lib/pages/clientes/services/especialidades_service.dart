import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/especialidad_model.dart';

class EspecialidadesService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('especialidades');

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<EspecialidadModel>> listarEspecialidades() async {
    try {
      final headers = await _getHeaders();
      final resp = await http.get(Uri.parse('$_baseUrl/listar.php'), headers: headers);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((e) => EspecialidadModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error listando especialidades: $e');
      return [];
    }
  }

  static Future<bool> crearEspecialidad(EspecialidadModel espe) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(espe.toJson());

      final resp = await http.post(
        Uri.parse('$_baseUrl/crear.php'),
        headers: headers,
        body: body,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error creando especialidad: $e');
      return false;
    }
  }

  static Future<bool> actualizarEspecialidad(EspecialidadModel espe) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(espe.toJson());

      final resp = await http.post(
        Uri.parse('$_baseUrl/actualizar.php'),
        headers: headers,
        body: body,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error actualizando especialidad: $e');
      return false;
    }
  }

  static Future<bool> eliminarEspecialidad(int id) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({'id': id});

      final resp = await http.post(
        Uri.parse('$_baseUrl/eliminar.php'),
        headers: headers,
        body: body,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error eliminando especialidad: $e');
      return false;
    }
  }
}
