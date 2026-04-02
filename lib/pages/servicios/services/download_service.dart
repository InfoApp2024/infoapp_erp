import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Importaciones condicionales para web y móvil
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import 'package:path_provider/path_provider.dart';
//    if (dart.library.io) 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:infoapp/core/env/server_config.dart';
import 'package:open_filex/open_filex.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

/// Servicio para manejar descargas de archivos multiplataforma
class DownloadService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  /// ✅ MÉTODO PRINCIPAL: Descargar archivo de manera directa
  static Future<bool> descargarArchivo({
    required String nombreArchivo,
    required String rutaPublica,
    Function(String)? onSuccess,
    Function(String)? onError,
    Function(double)? onProgress,
  }) async {
    try {
      //       print('💾 Iniciando descarga de: $nombreArchivo');
      //       print('📂 Ruta: $rutaPublica');

      // Construir URL completa
      final url = _construirUrlCompleta(rutaPublica);
      //       print('🔗 URL completa: $url');

      if (kIsWeb) {
        // ✅ DESCARGA PARA WEB
        return await _descargarEnWeb(
          url,
          nombreArchivo,
          onSuccess,
          onError,
          onProgress,
        );
      } else {
        // ✅ DESCARGA PARA MÓVIL
        return await _descargarEnMovil(
          url,
          nombreArchivo,
          onSuccess,
          onError,
          onProgress,
        );
      }
    } catch (e) {
      //       print('❌ Error en descarga: $e');
      onError?.call('Error descargando archivo: $e');
      return false;
    }
  }

  /// ✅ MÉTODO PARA VALIDAR SI EL ARCHIVO EXISTE
  static Future<bool> validarArchivoExiste(String rutaPublica) async {
    try {
      final url = _construirUrlCompleta(rutaPublica);
      final token = await AuthService.getBearerToken();
      final Map<String, String> headers = {
        if (token != null) 'Authorization': token,
      };

      final response = await http.head(Uri.parse(url), headers: headers);

      //       print('📡 Validando archivo: $url');
      //       print('📊 Status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      //       print('❌ Error validando archivo: $e');
      return false;
    }
  }

  /// ✅ CONSTRUIR URL COMPLETA DEL ARCHIVO
  static String _construirUrlCompleta(String rutaPublica) {
    // Si ya tiene el dominio completo, usarla tal como está
    if (rutaPublica.startsWith('http')) {
      return rutaPublica;
    }

    // Si no, construir URL completa
    return '$_baseUrl/$rutaPublica';
  }

  /// ✅ DESCARGA PARA WEB (usando dart:html)
  static Future<bool> _descargarEnWeb(
    String url,
    String nombreArchivo,
    Function(String)? onSuccess,
    Function(String)? onError,
    Function(double)? onProgress,
  ) async {
    try {
      // En web, abrir siempre en nueva pestaña para visualización/descarga desde el navegador
      await dl.openExternalUrl(url);
      onSuccess?.call('Informe abierto en nueva pestaña');
      return true;
    } catch (e) {
      //       print('❌ Error descarga web: $e');
      onError?.call('Error en descarga web: $e');
      return false;
    }
  }

  /// ✅ DESCARGA PARA MÓVIL (usando path_provider)
  static Future<bool> _descargarEnMovil(
    String url,
    String nombreArchivo,
    Function(String)? onSuccess,
    Function(String)? onError,
    Function(double)? onProgress,
  ) async {
    try {
      if (!kIsWeb) {
        // Descargar con progreso
        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(url));
          final streamed = await client.send(request);

          if (streamed.statusCode != 200) {
            throw Exception('Archivo no encontrado (${streamed.statusCode})');
          }

          final total = int.tryParse(streamed.headers['content-length'] ?? '');
          int received = 0;

          // Obtener directorio de descargas
          final directory = await getApplicationDocumentsDirectory();
          final downloadsPath = '${directory.path}/downloads';

          // Crear directorio si no existe
          final downloadsDir = Directory(downloadsPath);
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          // Guardar archivo
          final filePath = '$downloadsPath/$nombreArchivo';
          final file = File(filePath);
          final sink = file.openWrite();

          if (total == null) {
            onProgress?.call(0);
          }

          await for (final chunk in streamed.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (total != null && total > 0) {
              onProgress?.call(received / total);
            }
          }

          await sink.flush();
          await sink.close();

          try {
            final result = await OpenFilex.open(filePath);
            if (result.type == ResultType.done) {
              onSuccess?.call('Archivo guardado y abierto: $filePath');
            } else {
              onSuccess?.call('Archivo guardado en: $filePath');
            }
          } catch (_) {
            onSuccess?.call('Archivo guardado en: $filePath');
          }
          return true;
        } finally {
          client.close();
        }
      }

      return false;
    } catch (e) {
      //       print('❌ Error descarga móvil: $e');
      onError?.call('Error en descarga móvil: $e');
      return false;
    }
  }

  /// ✅ MÉTODO ESPECÍFICO PARA DESCARGAR CAMPOS ADICIONALES
  static Future<bool> descargarCampoAdicional({
    required Map<String, dynamic> datosArchivo,
    Function(String)? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      final nombreOriginal =
          datosArchivo['nombre_original'] ??
          datosArchivo['nombre'] ??
          'archivo_descargado';

      final rutaPublica =
          datosArchivo['ruta_publica'] ??
          datosArchivo['url_completa'] ??
          datosArchivo['ruta'];

      if (rutaPublica == null || rutaPublica.toString().isEmpty) {
        throw Exception('No se encontró la ruta del archivo');
      }

      //       print('📂 Descargando campo adicional:');
      //       print('   - Nombre: $nombreOriginal');
      //       print('   - Ruta: $rutaPublica');

      return await descargarArchivo(
        nombreArchivo: nombreOriginal,
        rutaPublica: rutaPublica.toString(),
        onSuccess: onSuccess,
        onError: onError,
      );
    } catch (e) {
      //       print('❌ Error descargando campo adicional: $e');
      onError?.call('Error: $e');
      return false;
    }
  }

  /// ✅ MÉTODO PARA ABRIR ARCHIVO EN NUEVA PESTAÑA (WEB)
  static void abrirArchivoEnNuevaPestana(String rutaPublica) {
    if (kIsWeb) {
      final url = _construirUrlCompleta(rutaPublica);
      dl.openExternalUrl(url);
    }
  }

  /// ✅ NUEVO: ABRIR LINK EXTERNO EN NUEVA PESTAÑA (WEB)
  static void abrirLinkEnNuevaPestana(String url) {
    if (kIsWeb) {
      try {
        dl.openExternalUrl(url);
      } catch (_) {
        // Silencio: en móvil/desktop no aplica
      }
    }
  }

  /// ✅ MÉTODO PARA OBTENER INFORMACIÓN DEL ARCHIVO
  static Future<Map<String, dynamic>?> obtenerInfoArchivo(
    String rutaPublica,
  ) async {
    try {
      final url = _construirUrlCompleta(rutaPublica);
      final response = await http.head(Uri.parse(url));

      if (response.statusCode == 200) {
        return {
          'existe': true,
          'tamaño': response.headers['content-length'],
          'tipo': response.headers['content-type'],
          'url': url,
        };
      }

      return {'existe': false};
    } catch (e) {
      //       print('❌ Error obteniendo info archivo: $e');
      return {'existe': false, 'error': e.toString()};
    }
  }
}
