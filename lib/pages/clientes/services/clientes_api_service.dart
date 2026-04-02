import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/pages/clientes/models/cliente_model.dart';

class ClientesApiService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('clientes');

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<ClienteModel>> listarClientes({
    String? search,
    int limit = 50,
    int offset = 0,
    int? estado,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$_baseUrl/listar.php?limit=$limit&offset=$offset';

      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }
      if (estado != null) {
        url += '&estado=$estado';
      }

      print('🔵 [ClientesApiService] Requesting: $url');

      final resp = await http.get(Uri.parse(url), headers: headers);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((e) => ClienteModel.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error listando clientes: $e');
      return [];
    }
  }

  static Future<ClienteModel?> obtenerCliente(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '$_baseUrl/obtener.php?id=$id';

      final resp = await http.get(Uri.parse(url), headers: headers);

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['success'] == true) {
          return ClienteModel.fromJson(decoded['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo cliente: $e');
      return null;
    }
  }

  static Future<bool> crearCliente(ClienteModel cliente) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(cliente.toJson());

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
      print('Error creando cliente: $e');
      return false;
    }
  }

  static Future<bool> actualizarCliente(ClienteModel cliente) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(cliente.toJson());

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
      print('Error actualizando cliente: $e');
      return false;
    }
  }

  static Future<bool> eliminarCliente(int id) async {
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
      print('Error eliminando cliente: $e');
      return false;
    }
  }
}
