import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/env/server_config.dart';
import '../../../features/auth/data/auth_service.dart';
import '../models/accounting_models.dart';

class AccountingPeriodsService {
  String get baseUrl => ServerConfig.instance.baseUrlFor('accounting');

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<AccountingPeriodModel>> getPeriods() async {
    final url = '$baseUrl/gestionar_periodos.php';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['success']) {
        final List data = jsonResponse['data'];
        return data.map((p) => AccountingPeriodModel.fromJson(p)).toList();
      }
    }
    throw Exception('Error al obtener periodos contables');
  }

  Future<bool> createPeriod({
    required int anio,
    required int mes,
    required String fechaInicio,
    required String fechaFin,
  }) async {
    final url = '$baseUrl/gestionar_periodos.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({
        'action': 'create',
        'anio': anio,
        'mes': mes,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['success'] ?? false;
    } else {
      final jsonResponse = json.decode(response.body);
      throw Exception(
        jsonResponse['message'] ?? 'Error desconocido al crear periodo',
      );
    }
  }

  Future<bool> updatePeriodStatus(int id, String status) async {
    final url = '$baseUrl/gestionar_periodos.php';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: json.encode({'id': id, 'estado': status}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['success'] ?? false;
    } else {
      final jsonResponse = json.decode(response.body);
      throw Exception(
        jsonResponse['message'] ?? 'Error al actualizar estado del periodo',
      );
    }
  }
}
