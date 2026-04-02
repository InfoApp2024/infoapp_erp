import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/pages/clientes/models/tarifa_ica_model.dart';

class TarifasIcaService {
  static String get _baseUrl =>
      ServerConfig.instance.baseUrlFor('impuestos/ica');

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<TarifaIcaModel>> listarTarifas() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/listar.php');

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> list = decoded['data'];
          return list.map((e) => TarifaIcaModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print('Error al listar tarifas ICA: $e');
    }
    return [];
  }

  static Future<bool> crearTarifa(TarifaIcaModel tarifa) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/crear.php');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(tarifa.toJson()),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
    } catch (e) {
      print('Error al crear tarifa ICA: $e');
    }
    return false;
  }

  static Future<bool> actualizarTarifa(TarifaIcaModel tarifa) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/actualizar.php');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(tarifa.toJson()),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
    } catch (e) {
      print('Error al actualizar tarifa ICA: $e');
    }
    return false;
  }

  static Future<bool> eliminarTarifa(int id) async {
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
      print('Error al eliminar tarifa ICA: $e');
    }
    return false;
  }
}
