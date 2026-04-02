import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/actividad_estandar_model.dart';

class ActividadesEstandarApiService {
  // Nota: El endpoint está en backend/workflow/listarActividadesEstandar.php
  // Ajustamos la URL base según server_config
  static String get _baseUrl => ServerConfig.instance.apiRoot(); 
  // Pero el endpoint está en workflow...
  // server_config.apiRoot() devuelve ".../API_Infoapp"
  // Necesitamos ".../API_Infoapp/workflow/listarActividadesEstandar.php"
  
  // Headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  static Future<List<ActividadEstandarModel>> listarActividades({
    bool? activo,
    String? busqueda,
  }) async {
    try {
      final queryParams = <String, String>{
        if (activo != null) 'activo': activo ? '1' : '0',
        if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
      };

      // Construcción de la URL apuntando a la carpeta workflow
      final uri = Uri.parse('$_baseUrl/workflow/listarActividadesEstandar.php')
          .replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final listJson = jsonData['data'] as List;
          return listJson
              .map((json) => ActividadEstandarModel.fromJson(json))
              .toList();
        } else {
          // Si no hay datos o error lógico
          return [];
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error obteniendo actividades: $e');
    }
  }
}
