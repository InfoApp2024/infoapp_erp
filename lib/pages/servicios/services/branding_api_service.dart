import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

/// Servicio para manejar la configuración de branding
class BrandingApiService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  // Headers comunes
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'User-Agent': 'Flutter App',
  };

  // Método para obtener headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Obtener configuración de branding
  static Future<Map<String, dynamic>?> obtenerBranding() async {
    try {
      //       print('📡 [BRANDING] Cargando configuración...');

      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/core/branding/obtener_branding.php'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
 
        if (result['success'] == true) {
          //           print('✅ [BRANDING] Configuración cargada');
          return result['branding'];
        } else {
          throw Exception(result['message'] ?? 'Error obteniendo branding');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print('❌ [BRANDING] Error: $e');
      // Retornar configuración por defecto en caso de error
      return _getBrandingPorDefecto();
    }
  }
 
  /// Configuración por defecto cuando falla la carga
  static Map<String, dynamic> _getBrandingPorDefecto() {
    return {
      'color_primario': '#2196F3',
      'color_secundario': '#FFC107',
      'logo_url': null,
      'nombre_empresa': 'Mi Aplicación',
      'configuracion_cargada': false, // Flag para indicar que es por defecto
    };
  }

  /// Actualizar configuración de branding
  static Future<bool> actualizarBranding(Map<String, dynamic> branding) async {
    try {
      //       print('📡 [BRANDING] Actualizando configuración...');

      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/core/branding/guardar_branding.php'),
        headers: headers,
        body: jsonEncode(branding),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
 
        if (result['success'] == true) {
          //           print('✅ [BRANDING] Configuración actualizada');
          return true;
        } else {
          throw Exception(result['message'] ?? 'Error actualizando branding');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print('❌ [BRANDING] Error actualizando: $e');
      return false;
    }
  }
}
