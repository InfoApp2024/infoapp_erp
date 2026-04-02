/// ============================================================================
/// ARCHIVO: inspecciones_api_service.dart
///
/// PROPÓSITO: Servicio de API que:
/// - Centraliza todas las llamadas HTTP al backend de inspecciones
/// - Maneja autenticación y headers
/// - Procesa respuestas y errores
/// - Implementa métodos CRUD para inspecciones
///
/// USO: Capa de datos usada por providers para comunicación HTTP
/// ============================================================================
library;


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import '../models/inspeccion_model.dart';
import '../models/evidencia_seleccionada.dart';

class InspeccionesApiService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  // Headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // =====================================
  //    CRUD DE INSPECCIONES
  // =====================================

  /// Listar inspecciones con paginación y filtros
  static Future<Map<String, dynamic>> listarInspecciones({
    int pagina = 1,
    int limite = 20,
    String? buscar,
    String? estado,
    String? sitio,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    try {
      final queryParams = <String, String>{
        'pagina': pagina.toString(),
        'limite': limite.toString(),
        if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (sitio != null && sitio.isNotEmpty) 'sitio': sitio,
        if (equipoId != null) 'equipo_id': equipoId.toString(),
        if (fechaDesde != null && fechaDesde.isNotEmpty) 'fecha_desde': fechaDesde,
        if (fechaHasta != null && fechaHasta.isNotEmpty) 'fecha_hasta': fechaHasta,
      };

      final uri = Uri.parse('$_baseUrl/inspecciones/listar.php')
          .replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final data = jsonData['data'];
          final inspeccionesJson = data['inspecciones'] as List;
          final paginacion = data['paginacion'];

          return {
            'inspecciones':
                inspeccionesJson
                    .map((json) => InspeccionModel.fromJson(json))
                    .toList(),
            'total': paginacion['total_registros'],
            'pagina': paginacion['pagina_actual'],
            'totalPaginas': paginacion['total_paginas'],
            'tieneSiguiente': paginacion['tiene_siguiente'],
            'tieneAnterior': paginacion['tiene_anterior'],
            'mensaje': jsonData['mensaje'] ?? '',
          };
        } else {
          throw Exception(jsonData['message'] ?? 'Error en respuesta del servidor');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error obteniendo inspecciones: $e');
    }
  }

  /// Obtener detalle completo de una inspección
  static Future<InspeccionModel> obtenerInspeccion(int inspeccionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/inspecciones/obtener.php')
          .replace(queryParameters: {'id': inspeccionId.toString()});

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          return InspeccionModel.fromJsonDetalle(jsonData['data']);
        } else {
          throw Exception(jsonData['message'] ?? 'Error obteniendo inspección');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error obteniendo inspección: $e');
    }
  }



  /// Crear nueva inspección
  static Future<Map<String, dynamic>> crearInspeccion({
    required int estadoId,
    required String sitio,
    required String fechaInspe,
    required int equipoId,
    required List<int> inspectores,
    required List<int> sistemas,
    required List<int> actividades,
    List<EvidenciaSeleccionada>? evidencias,
  }) async {
    try {
      final authHeaders = await _getAuthHeaders();
      var uri = Uri.parse('$_baseUrl/inspecciones/crear.php');
      var request = http.MultipartRequest('POST', uri);
      
      request.headers.addAll(authHeaders);
      
      // Fields
      request.fields['estado_id'] = estadoId.toString();
      request.fields['sitio'] = sitio;
      request.fields['fecha_inspe'] = fechaInspe;
      request.fields['equipo_id'] = equipoId.toString();
      
      // Arrays as JSON strings
      request.fields['inspectores'] = jsonEncode(inspectores);
      request.fields['sistemas'] = jsonEncode(sistemas);
      request.fields['actividades'] = jsonEncode(actividades);
      
      // Evidences
      if (evidencias != null && evidencias.isNotEmpty) {
        final nuevasEvidencias = evidencias.where((e) => !e.isRemote).toList();
        
        for (var i = 0; i < nuevasEvidencias.length; i++) {
            var evidencia = nuevasEvidencias[i];
             var bytes = await evidencia.file.readAsBytes();
             var multipartFile = http.MultipartFile.fromBytes(
               'evidencias[]', 
               bytes, 
               filename: evidencia.file.name
             );
             request.files.add(multipartFile);
        }
        
        // Metadata (comments and activity association) - Solo de las nuevas
        List<Map<String, dynamic>> metadata = nuevasEvidencias.map((e) => {
           'filename': e.file.name,
           'comentario': e.comentario,
           'actividad_id': e.actividadId
        }).toList().cast<Map<String, dynamic>>();
        request.fields['evidencias_info'] = jsonEncode(metadata);
      }
      
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          return result['data'];
        } else {
          throw Exception(result['message'] ?? 'Error del servidor');
        }
      } else {
        try {
          final result = jsonDecode(response.body);
          throw Exception(result['message'] ?? 'Error HTTP ${response.statusCode}');
        } catch (_) {
          throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error al crear inspección: $e');
    }
  }

  /// Actualizar inspección existente
  static Future<bool> actualizarInspeccion({
    required int inspeccionId,
    int? estadoId,
    String? sitio,
    String? fechaInspe,
    int? equipoId,
    List<int>? inspectores,
    List<int>? sistemas,
    List<int>? actividades,
    Map<int, String>? notasEliminacion,
    List<EvidenciaSeleccionada>? evidencias,
  }) async {
    try {
      // Si hay evidencias, usar MultipartRequest
      if (evidencias != null && evidencias.isNotEmpty) {
        final authHeaders = await _getAuthHeaders();
        var uri = Uri.parse('$_baseUrl/inspecciones/actualizar.php');
        var request = http.MultipartRequest('POST', uri);
        
        request.headers.addAll(authHeaders);
        
        // Campos básicos
        request.fields['id'] = inspeccionId.toString();
        if (estadoId != null) request.fields['estado_id'] = estadoId.toString();
        if (sitio != null) request.fields['sitio'] = sitio;
        if (fechaInspe != null) request.fields['fecha_inspe'] = fechaInspe;
        if (equipoId != null) request.fields['equipo_id'] = equipoId.toString();
        
        // Arrays as JSON strings
        if (inspectores != null) request.fields['inspectores'] = jsonEncode(inspectores);
        if (sistemas != null) request.fields['sistemas'] = jsonEncode(sistemas);
        if (actividades != null) request.fields['actividades'] = jsonEncode(actividades);
        if (notasEliminacion != null) {
          request.fields['notas_eliminacion'] = jsonEncode(
            notasEliminacion.map((k, v) => MapEntry(k.toString(), v))
          );
        }
        
        // Archivos de evidencias - SOLO NUEVAS
        final nuevasEvidencias = evidencias.where((e) => !e.isRemote).toList();
        
        for (var i = 0; i < nuevasEvidencias.length; i++) {
          var evidencia = nuevasEvidencias[i];
          var bytes = await evidencia.file.readAsBytes();
          var multipartFile = http.MultipartFile.fromBytes(
            'evidencias[]',
            bytes,
            filename: evidencia.file.name
          );
          request.files.add(multipartFile);
        }
        
        // Metadata de evidencias - SOLO NUEVAS
        List<Map<String, dynamic>> metadata = nuevasEvidencias.map((e) => {
          'filename': e.file.name,
          'comentario': e.comentario,
          'actividad_id': e.actividadId
        }).toList().cast<Map<String, dynamic>>();
        request.fields['evidencias_info'] = jsonEncode(metadata);
        
        var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          return result['success'] == true;
        } else {
          try {
            final result = jsonDecode(response.body);
            throw Exception(result['message'] ?? 'Error HTTP ${response.statusCode}');
          } catch (_) {
            throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
          }
        }
      } else {
        // Sin evidencias, usar JSON tradicional
        final requestData = {
          'id': inspeccionId,
          if (estadoId != null) 'estado_id': estadoId,
          if (sitio != null) 'sitio': sitio,
          if (fechaInspe != null) 'fecha_inspe': fechaInspe,
          if (equipoId != null) 'equipo_id': equipoId,
          if (inspectores != null) 'inspectores': inspectores,
          if (sistemas != null) 'sistemas': sistemas,
          if (actividades != null) 'actividades': actividades,
          if (notasEliminacion != null) 
            'notas_eliminacion': notasEliminacion.map((k, v) => MapEntry(k.toString(), v)),
        };

        final authHeaders = await _getAuthHeaders();
        final response = await http.post(
          Uri.parse('$_baseUrl/inspecciones/actualizar.php'),
          headers: authHeaders,
          body: jsonEncode(requestData),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          return result['success'] == true;
        } else {
          try {
            final result = jsonDecode(response.body);
            throw Exception(result['message'] ?? 'Error HTTP ${response.statusCode}');
          } catch (_) {
            throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
          }
        }
      }
    } catch (e) {
      throw Exception('Error al actualizar inspección: $e');
    }
  }

  /// Eliminar inspección (soft delete)
  static Future<bool> eliminarInspeccion(int inspeccionId) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/inspecciones/eliminar.php'),
        headers: authHeaders,
        body: jsonEncode({'id': inspeccionId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al eliminar inspección: $e');
    }
  }

  // =====================================
  //    ACTIVIDADES DE INSPECCIÓN
  // =====================================


  /// Autorizar/desautorizar actividad
  static Future<bool> autorizarActividad({
    required int inspeccionActividadId,
    required bool autorizada,
    String? notas,
  }) async {
    try {
      final requestData = {
        'id': inspeccionActividadId,
        'autorizada': autorizada,
        if (notas != null) 'notas': notas,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/inspecciones/autorizar_actividad.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        try {
          final result = jsonDecode(response.body);
          throw Exception(result['message'] ?? 'Error HTTP ${response.statusCode}');
        } catch (_) {
          throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error al autorizar actividad: $e');
    }
  }

  /// Eliminar actividad de inspección
  static Future<bool> eliminarActividad({
    required int inspeccionActividadId,
    required String notas,
  }) async {
    try {
      final requestData = {
        'id': inspeccionActividadId,
        'notas': notas,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/inspecciones/eliminar_actividad.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        try {
          final result = jsonDecode(response.body);
          throw Exception(result['message'] ?? 'Error HTTP ${response.statusCode}');
        } catch (_) {
          throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error al eliminar actividad: $e');
    }
  }

  /// Crear servicio desde actividad autorizada
  static Future<Map<String, dynamic>> crearServicioDesdeActividad({
    required int inspeccionActividadId,
    required int autorizadoPor,
    String? ordenCliente,
    String? tipoMantenimiento,
    String? centroCosto,
    required int estadoId,
    int? clienteId,
    String? nota,
  }) async {
    try {
      final requestData = {
        'inspeccion_actividad_id': inspeccionActividadId,
        'autorizado_por': autorizadoPor,
        'orden_cliente': ordenCliente ?? '',
        'tipo_mantenimiento': tipoMantenimiento ?? 'correctivo',
        'centro_costo': centroCosto ?? '',
        'estado_id': estadoId,
        'cliente_id': clienteId,
        if (nota != null) 'nota': nota,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/inspecciones/crear_servicio_desde_actividad.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          return result['data'];
        } else {
          throw Exception(result['message'] ?? 'Error del servidor');
        }
      } else {
        try {
          final result = jsonDecode(response.body);
          throw Exception(result['message'] ?? 'Error HTTP ${response.statusCode}');
        } catch (_) {
          throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error al crear servicio: $e');
    }
  }

  // =====================================
  //    EVIDENCIAS
  // =====================================

  /// Subir evidencia fotográfica
  static Future<Map<String, dynamic>> subirEvidencia({
    required int inspeccionId,
    int? actividadId,
    required String imagenBase64,
    required String nombreArchivo,
    String? comentario,
    int? orden,
  }) async {
    try {
      final requestData = {
        'inspeccion_id': inspeccionId,
        if (actividadId != null) 'actividad_id': actividadId,
        'imagen_base64': imagenBase64,
        'nombre_archivo': nombreArchivo,
        'comentario': comentario ?? '',
        if (orden != null) 'orden': orden,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/inspecciones/evidencias/subir.php'),
            headers: authHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 30)); // Más tiempo para upload

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          return result['data'];
        } else {
          throw Exception(result['message'] ?? 'Error del servidor');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al subir evidencia: $e');
    }
  }

  /// Listar evidencias de una inspección
  static Future<List<EvidenciaModel>> listarEvidencias({
    required int inspeccionId,
    int? actividadId,
  }) async {
    try {
      final queryParams = <String, String>{
        'inspeccion_id': inspeccionId.toString(),
        if (actividadId != null) 'actividad_id': actividadId.toString(),
      };

      final uri = Uri.parse('$_baseUrl/inspecciones/evidencias/listar.php')
          .replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final evidenciasJson = jsonData['data'] as List;
          return evidenciasJson
              .map((json) => EvidenciaModel.fromJson(json))
              .toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Error obteniendo evidencias');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error obteniendo evidencias: $e');
    }
  }

  /// Actualizar comentario de evidencia
  static Future<bool> actualizarComentarioEvidencia({
    required int evidenciaId,
    required String comentario,
  }) async {
    try {
      final requestData = {
        'id': evidenciaId,
        'comentario': comentario,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/inspecciones/evidencias/actualizar_comentario.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al actualizar comentario: $e');
    }
  }

  /// Eliminar evidencia
  static Future<bool> eliminarEvidencia(int evidenciaId) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/inspecciones/evidencias/eliminar.php'),
        headers: authHeaders,
        body: jsonEncode({'id': evidenciaId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al eliminar evidencia: $e');
    }
  }

  /// ✅ NUEVO: Vincular actividad de inspección a servicio creado
  /// Actualiza inspecciones_actividades SET servicio_id = [servicioId]
  static Future<bool> vincularActividadAServicio({
    required int actividadInspeccionId,
    required int servicioId,
  }) async {
    try {
      final requestData = {
        'actividad_inspeccion_id': actividadInspeccionId,
        'servicio_id': servicioId,
      };

      final authHeaders = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/inspecciones/actividades/vincular_servicio.php'),
        headers: authHeaders,
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      } else {
        debugPrint('❌ Error vinculando actividad: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Excepción vinculando actividad: $e');
      return false;
    }
  }
}
