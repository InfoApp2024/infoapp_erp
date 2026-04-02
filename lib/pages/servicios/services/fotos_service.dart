import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/foto_model.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';


class FotosService {
  static String get baseUrl => ServerConfig.instance.apiRoot();

  // ✅ CACHE LIGERO EN MEMORIA PARA FOTOS POR SERVICIO (TTL 10 min)
  static final Map<int, _FotosCacheEntry> _cacheFotos = {};
  static const Duration _ttlFotos = Duration(minutes: 10);

  // Método para headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();

    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  /// Obtener todas las fotos de un servicio (CON JWT)
  static Future<List<FotoModel>> obtenerFotosServicio(int servicioId) async {
    try {
      // Intentar cache en memoria
      final now = DateTime.now();
      final entry = _cacheFotos[servicioId];
      if (entry != null && now.difference(entry.timestamp) < _ttlFotos) {
        return List<FotoModel>.from(entry.fotos);
      }
//       print('📸 Obteniendo fotos para servicio ID: $servicioId');

      final authHeaders = await _getAuthHeaders(); // AGREGAR JWT
      final token = await AuthService.getToken();
      final url =
          '$baseUrl/servicio/listar_fotos_servicio.php?servicio_id=$servicioId${token != null ? '&token=$token' : ''}';
//       print('📡 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders, // USAR HEADERS CON JWT
      );

//       print('é°Å¸âÂ¨ Response status: ${response.statusCode}');
//       print('é°Å¸âÂ¨ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final List<dynamic> fotosData = result['fotos'] ?? [];
//           print('✅ Fotos encontradas: ${fotosData.length}');

          final fotos =
              fotosData.map((foto) => FotoModel.fromJson(foto)).toList();

          for (var foto in fotos) {
//             print('  - Foto ID: ${foto.id}, Tipo: ${foto.tipoFoto}, Archivo: ${foto.nombreArchivo}');
          }

          // Guardar en cache de memoria
          _cacheFotos[servicioId] = _FotosCacheEntry(
            fotos: fotos,
            timestamp: now,
          );
          return fotos;
        } else {
//           print('❌ API devolvió success=false: ${result['message'] ?? 'Sin mensaje'}');
          return [];
        }
      } else if (response.statusCode == 401) {
//         print('❌ Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData(); // LIMPIAR AUTH SI TOKEN INVÁLIDO
        return [];
      } else {
//         print('❌ Error HTTP: ${response.statusCode}');
        return [];
      }
    } catch (e) {
//       print('❌ Error cargando fotos: $e');
      return [];
    }
  }

  /// Subir una nueva foto al servicio (CON JWT)
  static Future<bool> subirFoto(
    int servicioId,
    XFile imagen,
    String tipo,
    {int? pairIndex}
  ) async {
    try {
//       print('📦 === INICIANDO SUBIDA DE FOTO (JWT) ===');
//       print('📦 Servicio ID: $servicioId');
//       print('📦 Tipo: $tipo');
//       print('📦 Archivo: ${imagen.name}');

      // Convertir imagen a Base64
      final Uint8List bytes = await imagen.readAsBytes();
      final String base64Image = base64Encode(bytes);

//       print('📦 Tamaño archivo: ${bytes.length} bytes');
//       print('📦 Tamaño base64: ${base64Image.length} caracteres');

      // Generar nombre único para el archivo
      final extension = imagen.name.split('.').last.toLowerCase();
      final String fileName =
          'servicio_${servicioId}_${tipo}_${DateTime.now().millisecondsSinceEpoch}.$extension';

//       print('📦 Nombre archivo generado: $fileName');

      // Preparar datos para enviar
      final requestData = {
        'servicio_id': servicioId.toString(),
        'tipo_foto': tipo,
        'descripcion': pairIndex != null
            ? '[PAIR:$pairIndex] Foto $tipo del servicio #$servicioId'
            : 'Foto $tipo del servicio #$servicioId',
        'imagen_base64': base64Image,
        'nombre_archivo': fileName,
        if (pairIndex != null) 'orden_visualizacion': pairIndex,
      };

//       print('📦 Enviando request...');

      final authHeaders = await _getAuthHeaders(); // AGREGAR JWT
      final token = await AuthService.getToken();
      final urlWithToken = '$baseUrl/servicio/subir_foto_servicio_base64.php${token != null ? '?token=$token' : ''}';

      final response = await http.post(
        Uri.parse(urlWithToken),
        headers: authHeaders, // USAR HEADERS CON JWT
        body: jsonEncode(requestData),
      );

//       print('é°Å¸âÂ¨ Response status: ${response.statusCode}');
//       print('é°Å¸âÂ¨ Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
//           print('✅ Foto subida exitosamente');
          if (result['data'] != null) {
//             print('✅ Datos de respuesta: ${result['data']}');
          }
          // Invalidate cache para este servicio
          _cacheFotos.remove(servicioId);
          return true;
        } else {
//           print('❌ Error del servidor: ${result['message'] ?? 'Error desconocido'}');
          return false;
        }
      } else if (response.statusCode == 401) {
//         print('❌ Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return false;
      } else {
//         print('❌ Error HTTP: ${response.statusCode}');
        return false;
      }
    } catch (e) {
//       print('❌ Error subiendo foto: $e');
      return false;
    }
  }

  /// Eliminar una foto (YA ESTÁ CORRECTO CON JWT)
  static Future<bool> eliminarFoto(int fotoId) async {
    try {
//       print('🗑️ === ELIMINANDO FOTO (JWT) ===');
//       print('🗑️ Foto ID: $fotoId');

      final authHeaders = await _getAuthHeaders();
      final requestData = {'foto_id': fotoId};
//       print('🗑️ Datos a enviar: $requestData');

      final token = await AuthService.getToken();
      final urlWithToken = '$baseUrl/servicio/eliminar_foto_servicio.php${token != null ? '?token=$token' : ''}';

      final response = await http.post(
        Uri.parse(urlWithToken),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

//       print('é°Å¸âÂ¨ Response status: ${response.statusCode}');
//       print('é°Å¸âÂ¨ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
//           print('✅ Foto eliminada exitosamente');
          // Invalidate cache global (desconocemos servicioId aquí)
          _cacheFotos.clear();
          return true;
        } else {
//           print('❌ Error del servidor: ${result['message'] ?? 'Error desconocido'}');
          return false;
        }
      } else if (response.statusCode == 401) {
//         print('❌ Error de autenticación: Token inválido o expirado');
        await AuthService.clearAuthData();
        return false;
      } else {
//         print('❌ Error HTTP: ${response.statusCode}');
        return false;
      }
    } catch (e) {
//       print('❌ Error eliminando foto: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Obtener solo fotos de un tipo específico
  static Future<List<FotoModel>> obtenerFotosPorTipo(
    int servicioId,
    String tipo,
  ) async {
    try {
      final todasLasFotos = await obtenerFotosServicio(servicioId);
      return todasLasFotos.where((foto) => foto.tipoFoto == tipo).toList();
    } catch (e) {
//       print('❌ Error obteniendo fotos por tipo: $e');
      return [];
    }
  }

  /// ✅ NUEVO: Contar fotos por tipo
  static Future<Map<String, int>> contarFotosPorTipo(int servicioId) async {
    try {
      final fotos = await obtenerFotosServicio(servicioId);

      final contadores = <String, int>{
        'antes': 0,
        'despues': 0,
        'total': fotos.length,
      };

      for (var foto in fotos) {
        if (foto.tipoFoto == 'antes') {
          contadores['antes'] = (contadores['antes'] ?? 0) + 1;
        } else if (foto.tipoFoto == 'despues') {
          contadores['despues'] = (contadores['despues'] ?? 0) + 1;
        }
      }

      return contadores;
    } catch (e) {
//       print('❌ Error contando fotos: $e');
      return {'antes': 0, 'despues': 0, 'total': 0};
    }
  }

  /// ✅ NUEVO: Validar si el servicio tiene fotos
  static Future<bool> servicioTieneFotos(int servicioId) async {
    try {
      final fotos = await obtenerFotosServicio(servicioId);
      return fotos.isNotEmpty;
    } catch (e) {
//       print('❌ Error validando fotos: $e');
      return false;
    }
  }

  /// Obtener URL de imagen con autenticación JWT
  static Future<String> obtenerUrlImagenAutenticada(String rutaArchivo) async {
    final token = await AuthService.getBearerToken();
    if (token != null) {
      return '$baseUrl/servicio/ver_imagen.php?ruta=$rutaArchivo';
    } else {
      // Fallback si no hay token
      return '$baseUrl/$rutaArchivo';
    }
  }

  /// Crear widget de imagen autenticada
  static Future<Map<String, String>> obtenerHeadersParaImagen() async {
    final token = await AuthService.getBearerToken();
    return {if (token != null) 'Authorization': token};
  }

  /// Actualizar orden de fotos
  static Future<bool> reordenarFotos(
      int servicioId, List<Map<String, dynamic>> ordenes) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final token = await AuthService.getToken();
      final requestData = {'ordenes': ordenes};
      final urlWithToken = '$baseUrl/servicio/reordenar_fotos.php${token != null ? '?token=$token' : ''}';

      final response = await http.post(
        Uri.parse(urlWithToken),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _cacheFotos.remove(servicioId); // Invalidate cache
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

class _FotosCacheEntry {
  final List<FotoModel> fotos;
  final DateTime timestamp;
  _FotosCacheEntry({required this.fotos, required this.timestamp});
}
