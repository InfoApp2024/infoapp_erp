import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../models/plantilla_model.dart';
import 'package:infoapp/core/env/server_config.dart';

class PlantillaApiService {
  static String get baseUrl => ServerConfig.instance
      .baseUrlFor('plantillas')
      .replaceAll('/plantillas', '');

  /// Listar todas las plantillas
  static Future<List<Plantilla>> getPlantillas({
    int? clienteId,
    int? esGeneral,
    String? modulo,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (clienteId != null) {
        queryParams['cliente_id'] = clienteId.toString();
      }

      if (esGeneral != null) {
        queryParams['es_general'] = esGeneral.toString();
      }

      if (modulo != null) {
        queryParams['modulo'] = modulo;
      }

      final uri = Uri.parse(
        '$baseUrl/plantillas/listar_plantillas.php',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          throw Exception('Respuesta inválida del servidor');
        }

        if (data['success'] == true) {
          final plantillas = data['data'] as List;
          return plantillas
              .map((plantilla) => Plantilla.fromJson(plantilla))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Error al obtener plantillas');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener plantillas: $e');
    }
  }

  /// Obtener una plantilla por ID
  static Future<Plantilla> getPlantilla(int id) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final uri = Uri.parse(
        '$baseUrl/plantillas/obtener_plantilla.php',
      ).replace(queryParameters: {'id': id.toString()});

      final response = await http.get(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return Plantilla.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al obtener plantilla');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al obtener plantilla: $e');
    }
  }

  /// Crear una nueva plantilla
  static Future<Plantilla> createPlantilla(Plantilla plantilla) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final body = plantilla.toJson();

      final response = await http.post(
        Uri.parse('$baseUrl/plantillas/crear_plantilla.php'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return Plantilla.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al crear plantilla');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al crear plantilla: $e');
    }
  }

  /// Actualizar una plantilla existente
  static Future<Plantilla> updatePlantilla(Plantilla plantilla) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      // Algunos backends en PHP manejan actualizaciones vía POST en lugar de PUT.
      // Cambiamos a POST para mejorar compatibilidad con el endpoint existente.
      final response = await http.post(
        Uri.parse('$baseUrl/plantillas/actualizar_plantilla.php'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode(plantilla.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return Plantilla.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Error al actualizar plantilla');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al actualizar plantilla: $e');
    }
  }

  /// Eliminar una plantilla
  static Future<void> deletePlantilla(int id) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final uri = Uri.parse(
        '$baseUrl/plantillas/eliminar_plantilla.php',
      ).replace(queryParameters: {'id': id.toString()});

      final response = await http.delete(
        uri,
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Error al eliminar plantilla');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al eliminar plantilla: $e');
    }
  }

  /// Vista previa de plantilla con datos de un servicio
  static Future<Map<String, dynamic>> previewPlantilla(
    int servicioId, {
    int? plantillaId,
  }) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      //       print('🔵 Generando preview para servicio: $servicioId');

      final Map<String, dynamic> body = {'servicio_id': servicioId};

      if (plantillaId != null) {
        body['plantilla_id'] = plantillaId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/informes/vista_previa_pdf.php'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      //       print('🔵 Response status: ${response.statusCode}');
      //       print('🔵 Response headers: ${response.headers}');
      //       print('🔵 Response body length: ${response.body.length}');
      //       print('🔵 Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          //           print('🔵 JSON decoded successfully');
          //           print('🔵 Success: ${data['success']}');
          //           print('🔵 Has html_procesado: ${data['data']?['html_procesado'] != null}');

          if (data['success'] == true) {
            return data['data'];
          } else {
            throw Exception(data['message'] ?? 'Error al generar vista previa');
          }
        } catch (e) {
          //           print('❌ Error decoding JSON: $e');
          //           print('❌ Response body: ${response.body}');
          throw Exception('Error parseando respuesta JSON: $e');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      //       print('❌ Error en previewPlantilla: $e');
      throw Exception('Error al generar vista previa: $e');
    }
  }

  /// Vista previa usando número de servicio (o_servicio) y HTML de la plantilla actual
  static Future<Map<String, dynamic>> previewPlantillaPorOrden({
    required String oServicio,
    required String contenidoHtml,
    int? plantillaId,
  }) async {
    try {
      final token = await AuthService.getBearerToken();

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      //       print('🔵 Generando preview por o_servicio: $oServicio con contenido_html (${contenidoHtml.length} chars)');

      final Map<String, dynamic> body = {
        'o_servicio': oServicio,
        'contenido_html': contenidoHtml,
      };

      if (plantillaId != null) {
        body['plantilla_id'] = plantillaId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/informes/vista_previa_pdf.php'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      //       print('🔵 Response status: ${response.statusCode}');
      //       print('🔵 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return data['data'];
          } else {
            throw Exception(data['message'] ?? 'Error al generar vista previa');
          }
        } catch (e) {
          throw Exception('Error parseando respuesta JSON: $e');
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      //       print('❌ Error en previewPlantillaPorOrden: $e');
      throw Exception('Error al generar vista previa: $e');
    }
  }
}
