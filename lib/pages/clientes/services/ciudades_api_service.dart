import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/pages/clientes/models/ciudad_model.dart';
import 'package:infoapp/pages/clientes/models/departamento_model.dart';

class CiudadesApiService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('ciudades');

  // Headers con Token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<DepartamentoModel>> listarDepartamentos() async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ServerConfig.instance.baseUrlFor('departamentos')}/listar.php';
      final resp = await http.get(Uri.parse(url), headers: headers);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((e) => DepartamentoModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<CiudadModel>> listarCiudades({
    String? search,
    int? departamentoId,
  }) async {
    try {
      final headers = await _getHeaders();
      String url =
          '$_baseUrl/listar.php?t=${DateTime.now().millisecondsSinceEpoch}';

      if (departamentoId != null && departamentoId > 0) {
        url += '&departamento_id=$departamentoId';
      }

      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      final resp = await http.get(Uri.parse(url), headers: headers);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((e) => CiudadModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<CiudadModel?> crearCiudad(CiudadModel ciudad) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(ciudad.toJson());

      final resp = await http.post(
        Uri.parse('$_baseUrl/crear.php'),
        headers: headers,
        body: body,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          return CiudadModel.fromJson(decoded['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
