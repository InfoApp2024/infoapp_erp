import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';

/// Utilidad para convertir imágenes que requieren autenticación a Base64 (Data URIs).
/// Útil para que carguen correctamente en WebViews que no comparten cookies/headers.
class AuthImageProcessor {
  static Future<String> processAuthenticatedImages(String html) async {
    final token = await AuthService.getBearerToken();
    if (token == null) return html;

    // Buscar URLs de ver_imagen.php
    final regex = RegExp(r'src="([^"]*ver_imagen\.php[^"]*)"');
    final matches = regex.allMatches(html);

    if (matches.isEmpty) return html;

    String processedHtml = html;
    final uniqueUrls = matches.map((m) => m.group(1)!).toSet();

    for (final url in uniqueUrls) {
      try {
        final uri = Uri.tryParse(url);
        if (uri == null) continue;

        final response = await http.get(uri, headers: {'Authorization': token});

        if (response.statusCode == 200) {
          final contentType = response.headers['content-type'] ?? 'image/jpeg';
          final base64 = base64Encode(response.bodyBytes);
          final dataUri = 'data:$contentType;base64,$base64';

          processedHtml = processedHtml.replaceAll(url, dataUri);
        }
      } catch (e) {
        debugPrint('⚠️ Error cargando imagen autenticada $url: $e');
      }
    }

    return processedHtml;
  }
}
