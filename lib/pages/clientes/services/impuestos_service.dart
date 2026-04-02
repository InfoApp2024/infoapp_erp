import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/pages/clientes/models/impuesto_model.dart';

class ImpuestosService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('impuestos');

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<ImpuestoModel>> listarImpuestos() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/listar.php');

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> list = decoded['data'];
          return list.map((e) => ImpuestoModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print('Error al listar impuestos: $e');
    }
    return [];
  }

  static Future<bool> crearImpuesto(ImpuestoModel impuesto) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/crear.php');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(impuesto.toJson()),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
    } catch (e) {
      print('Error al crear impuesto: $e');
    }
    return false;
  }

  static Future<bool> actualizarImpuesto(ImpuestoModel impuesto) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/actualizar.php');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(impuesto.toJson()),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
    } catch (e) {
      print('Error al actualizar impuesto: $e');
    }
    return false;
  }

  static Future<bool> eliminarImpuesto(int id) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/eliminar.php');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'id': id}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
    } catch (e) {
      print('Error al eliminar impuesto: $e');
    }
    return false;
  }
}
