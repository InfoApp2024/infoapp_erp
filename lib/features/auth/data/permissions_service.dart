import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';

/// Servicio para gestionar permisos por usuario.
class PermissionsService {
  /// Base relativa donde estarán los endpoints PHP de permisos.
  /// Ajusta esta ruta si tus endpoints viven en otra ubicación.
  // Ruta absoluta validada en servidor
  static String get _basePath => '${ServerConfig.instance.apiRoot()}/login/permissions';

  static const List<String> allowedActions = [
    'listar', 'crear', 'actualizar', 'eliminar', 'ver', 'exportar',
    'filtrar', 'configurar_columnas', 'desbloquear', 'monitoreo',
  ];

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    // El backend declara CORS para 'Authorization' y maneja OPTIONS,
    // por lo que podemos enviar el header siempre que tengamos token.
    if (token != null) headers['Authorization'] = token;
    return headers;
  }

  /// Construye la URI agregando el token como query param de respaldo cuando sea necesario.
  static Future<Uri> _buildUri(String path, [Map<String, dynamic>? params]) async {
    final rawToken = await AuthService.getToken();
    final qp = <String, String>{};
    if (params != null) {
      params.forEach((key, value) {
        if (value == null) return;
        qp[key] = value.toString();
      });
    }
    // Fallback: en algunos servidores el header Authorization no se propaga
    // por proxies/CDN; agregamos ?token= para compatibilidad.
    if (rawToken != null && qp['token'] == null) {
      qp['token'] = rawToken;
    }
    return Uri.parse('$_basePath/$path').replace(queryParameters: qp.isEmpty ? null : qp);
  }

  /// Listar permisos de un usuario. Devuelve mapa: modulo -> conjunto de acciones permitidas.
  static Future<Map<String, Set<String>>> listarPermisos({required int userId}) async {
    final uri = await _buildUri('get_user_permissions.php', {'user_id': userId});

    final headers = await _getAuthHeaders();

    final resp = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));


    if (resp.statusCode != 200) {
      throw Exception('Error al obtener permisos (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body);
    // Esperamos formato { success, data: { modulo: [acciones...] } }
    if (data is Map && (data['success'] == null || data['success'] == true)) {
      final out = <String, Set<String>>{};
      final map = data['data'] ?? data['permissions'] ?? {};
      if (map is Map) {
        map.forEach((key, value) {
          if (value is List) {
            out[key.toString()] = value.map((e) => e.toString()).toSet();
          }
        });
      }

      return out;
    }

    // Si el backend aún no está listo, devolvemos vacío para no romper la UI
    return {};
  }

  /// Reemplaza el set de permisos de un usuario por los proporcionados.
  static Future<bool> actualizarPermisos({
    required int userId,
    required Map<String, Set<String>> permisos,
  }) async {
    // El backend espera: permissions como mapa { modulo: [acciones...] }
    // Convertimos Set<String> -> List<String> por módulo
    final Map<String, List<String>> permissionsMap = permisos.map(
      (mod, actions) => MapEntry(mod, actions.toList()),
    );

    final uri = await _buildUri('update_user_permissions.php');
    final body = jsonEncode({
      'user_id': userId,
      'permissions': permissionsMap,
    });

    final resp = await http
        .post(uri, headers: await _getAuthHeaders(), body: body)
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Error al actualizar permisos (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body);
    if (data is Map) {
      // Consideramos éxito cuando el backend confirma success.
      // Opcionalmente podríamos validar 'permissions_count'.
      return data['success'] == true;
    }
    return false;
  }

  /// Consultar si el usuario tiene un permiso puntual (módulo + acción).
  static Future<bool> checarPermiso({
    required String module,
    required String action,
    int? userId,
  }) async {
    final uri = await _buildUri('check_permission.php', {
      'module': module,
      'action': action,
      if (userId != null) 'user_id': userId,
    });

    final resp = await http
        .get(uri, headers: await _getAuthHeaders())
        .timeout(const Duration(seconds: 10));


    if (resp.statusCode != 200) {
      throw Exception('Error al checar permiso (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body);
    if (data is Map) {
      return data['allowed'] == true;
    }
    return false;
  }
}