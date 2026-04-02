import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../models/tag_category_model.dart';
import 'package:infoapp/core/env/server_config.dart';

class TagsApiService {
  static String get baseUrl => ServerConfig.instance.apiRoot();

  /// Obtener todos los tags disponibles
  static Future<List<TagCategory>> getTags({String? modulo}) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final queryParams = modulo != null ? {'modulo': modulo} : null;
      final uri = Uri.parse('$baseUrl/tags/tags.php').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final categories = data['data']['categories'] as List;
          return categories
              .map((category) => TagCategory.fromJson(category))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Error al obtener tags');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener tags: $e');
    }
  }

  /// Validar tags en un HTML
  static Future<Map<String, dynamic>> validateTags(String contenidoHtml) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/plantillas/validar_tags.php'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode({'contenido_html': contenidoHtml}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Error al validar tags');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al validar tags: $e');
    }
  }
}
