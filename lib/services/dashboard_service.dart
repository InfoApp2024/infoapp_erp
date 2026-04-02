import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/models/dashboard_kpi.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class DashboardService {
  String get _baseUrl => ServerConfig.instance.apiRoot();

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  Future<KpiServicios> getKpiServicios({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final headers = await _getHeaders();
    final inicioStr = fechaInicio.toIso8601String().split('T')[0];
    final finStr = fechaFin.toIso8601String().split('T')[0];

    final url = Uri.parse(
      '$_baseUrl/dashboard/kpi_servicios.php?fecha_inicio=$inicioStr&fecha_fin=$finStr',
    );

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return KpiServicios.fromJson(json['data']);
      } else {
        throw Exception(json['message'] ?? 'Error al cargar KPIs de servicios');
      }
    } else if (response.statusCode == 404) {
      throw Exception(
        'Endpoint no encontrado (404). Verifica que los archivos PHP estén subidos al servidor.',
      );
    } else {
      throw Exception('Error de servidor: ${response.statusCode}');
    }
  }

  Future<KpiInventario> getKpiInventario() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$_baseUrl/dashboard/kpi_inventario.php');

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return KpiInventario.fromJson(json['data']);
      } else {
        throw Exception(
          json['message'] ?? 'Error al cargar KPIs de inventario',
        );
      }
    } else if (response.statusCode == 404) {
      throw Exception(
        'Endpoint no encontrado (404). Verifica que los archivos PHP estén subidos al servidor.',
      );
    } else {
      throw Exception('Error de servidor: ${response.statusCode}');
    }
  }
}
