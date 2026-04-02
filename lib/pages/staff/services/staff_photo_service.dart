import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';

/// Servicio para subir y obtener URL de foto de perfil de usuario/staff
class StaffPhotoService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('login');

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Sube la foto de perfil en base64 y retorna una URL pública si existe
  /// Devuelve null si falla o el backend no responde con una URL válida
  static Future<String?> subirFotoPerfil(XFile imagen, {int? userId}) async {
    try {
      final Uint8List bytes = await imagen.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final extension = imagen.name.split('.').last.toLowerCase();
      final String fileName =
          'staff_${userId ?? DateTime.now().millisecondsSinceEpoch}_perfil_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final requestData = {
        if (userId != null) 'user_id': userId,
        'imagen_base64': base64Image,
        'nombre_archivo': fileName,
        'descripcion': 'Foto de perfil',
      };

      final headers = await _getAuthHeaders();

      final uri = Uri.parse('$_baseUrl/subir_foto_perfil_base64.php');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result is Map &&
            (result['success'] == true || result['status'] == 'ok')) {
          // Intentar varias claves comunes
          final data = result['data'];
          final url = result['url'] ?? (data is Map ? data['url'] : null);
          final ruta = result['ruta'] ?? (data is Map ? data['ruta'] : null);

          if (url is String && url.isNotEmpty) {
            // Sanitizar URL: reemplazar backslashes por slashes normales y espacios
            return url.replaceAll('\\', '/').trim();
          }

          if (ruta is String && ruta.isNotEmpty) {
            // Usar script proxy ver_imagen.php para evitar problemas de CORS y headers
            // BaseUrl: .../API_Infoapp/login
            // Resultado: .../API_Infoapp/login/ver_imagen.php?ruta=uploads/staff/perfil/foto.jpg
            return '$_baseUrl/ver_imagen.php?ruta=$ruta';
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
