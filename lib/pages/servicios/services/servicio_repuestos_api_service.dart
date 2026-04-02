/// ============================================================================
/// ARCHIVO: servicio_repuestos_api_service.dart
///
/// PROPÓSITO: Servicio de API que:
/// - Gestiona la relación entre servicios y repuestos de inventario
/// - Maneja asignación, actualización y eliminación de repuestos
/// - Controla el stock de inventario automáticamente
/// - Proporciona métodos para listar repuestos disponibles
/// - Implementa transacciones para mantener consistencia de datos
///
/// USO: Capa de datos para el módulo de repuestos en servicios
///
/// FUNCIÓN: Abstracción para comunicación HTTP con endpoints de servicio-repuestos
/// ============================================================================
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/utils/connectivity_service.dart';

// Importar modelos necesarios
import '../models/servicio_repuesto_model.dart';
import '../../inventory/models/inventory_item_model.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'servicios_api_service.dart'; // ✅ NUEVO: Para ApiResponse

// Entrada de caché para repuestos (TOP-LEVEL)
class _RepuestosCacheEntry {
  final ServicioRepuestosResponse data;
  final DateTime timestamp;
  const _RepuestosCacheEntry({required this.data, required this.timestamp});
}

/// Servicio para manejar todas las operaciones de repuestos en servicios
class ServicioRepuestosApiService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();
  static const Duration _timeout = Duration(seconds: 30);

  // ✅ CACHE EN MEMORIA: Repuestos por servicio (TTL 10 min)
  static final Map<int, _RepuestosCacheEntry> _cachePorServicio = {};
  static const Duration _ttlRepuestos = Duration(minutes: 10);

  // Utilidades de invalidación de caché
  static void _invalidateCacheForServicio(int servicioId) {
    _cachePorServicio.remove(servicioId);
  }

  /// Obtiene el costo total desde la caché si existe y es válida
  static double? getCachedTotal(int servicioId) {
    final entry = _cachePorServicio[servicioId];
    if (entry != null) {
      if (DateTime.now().difference(entry.timestamp) < _ttlRepuestos) {
        return entry.data.costoTotal;
      }
    }
    return null;
  }

  static void _invalidateCacheByRepuestoId(int servicioRepuestoId) {
    final idsAEliminar = <int>[];
    _cachePorServicio.forEach((servicioId, entry) {
      final contiene = entry.data.repuestos.any(
        (r) => r.id == servicioRepuestoId,
      );
      if (contiene) idsAEliminar.add(servicioId);
    });
    for (final id in idsAEliminar) {
      _cachePorServicio.remove(id);
    }
  }

  static void _invalidateCacheByRepuestoIds(List<int> servicioRepuestoIds) {
    final setIds = servicioRepuestoIds.toSet();
    final idsAEliminar = <int>[];
    _cachePorServicio.forEach((servicioId, entry) {
      final contiene = entry.data.repuestos.any(
        (r) => r.id != null && setIds.contains(r.id!),
      );
      if (contiene) idsAEliminar.add(servicioId);
    });
    for (final id in idsAEliminar) {
      _cachePorServicio.remove(id);
    }
  }

  // Método para obtener headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  // =====================================
  //    OBTENER REPUESTOS DISPONIBLES
  // =====================================

  /// Obtiene lista de repuestos disponibles para asignar a servicios
  static Future<ApiResponse<List<InventoryItem>>> listarRepuestosDisponibles({
    String? search,
    int? categoryId,
    String? itemType, // ✅ CAMBIADO: null por defecto para mostrar TODOS los tipos
    int? supplierId,
    bool soloConStock = true,
    int limit = 50,
    int offset = 0,
    String sortBy = 'name',
    String sortOrder = 'ASC',
  }) async {
    try {
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('repuestos_disponibles_cache');
        if (cached != null && cached.isNotEmpty) {
          final List<dynamic> itemsData = jsonDecode(cached);
          final items =
              itemsData
                  .map(
                    (e) => InventoryItem.fromJson(
                      (e as Map).cast<String, dynamic>(),
                    ),
                  )
                  .toList();
          return ApiResponse.success(
            data: items,
            message: 'Repuestos cargados desde caché',
          );
        }
        return ApiResponse.error('Sin conexión y sin datos guardados');
      }

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
        'is_active': 'true', // Solo activos
      };

      // Filtros específicos
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }
      if (itemType != null && itemType.isNotEmpty) {
        queryParams['item_type'] = itemType;
      }
      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId.toString();
      }
      // Siempre pedir todos los repuestos, sin importar el stock
      queryParams['min_stock'] = '0';

      final uri = Uri.parse(
        '$_baseUrl/servicio/listar_repuestos_disponibles.php',
      ).replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> itemsData = responseData['data']['items'] ?? [];
          final items =
              itemsData
                  .map(
                    (json) =>
                        InventoryItem.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();
          try {
            final prefs = await SharedPreferences.getInstance();
            final toSave = items.map((e) => e.toJson()).toList();
            await prefs.setString(
              'repuestos_disponibles_cache',
              jsonEncode(toSave),
            );
          } catch (_) {}
          // print('✅ [API] ${items.length} repuestos disponibles cargados');
          return ApiResponse.success(
            data: items,
            message: 'Repuestos cargados exitosamente',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error obteniendo repuestos',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error obteniendo repuestos disponibles: $e');
      return ApiResponse.error('Error al obtener repuestos: $e');
    }
  }

  // =====================================
  //    GESTIÓN DE REPUESTOS EN SERVICIOS
  // =====================================

  /// Asigna repuestos a un servicio (descuenta del inventario inmediatamente)
  static Future<ApiResponse<List<ServicioRepuestoModel>>>
  asignarRepuestosAServicio({
    required int servicioId,
    required List<Map<String, dynamic>> repuestos,
    int? usuarioAsigno,
    String? observaciones,
  }) async {
    try {
      // print('📡 [API] Asignando repuestos al servicio $servicioId...');
      // print('📦 [API] Repuestos a asignar: ${repuestos.length}');

      // Obtener usuario actual si no se proporciona
      final prefs = await SharedPreferences.getInstance();
      final usuarioActual = prefs.getInt('usuario_id');

      // Preparar datos de la petición
      final int? userId = usuarioAsigno ?? usuarioActual;
      final requestData = <String, dynamic>{
        'servicio_id': servicioId,
        'repuestos': repuestos,
        // Enviar ambas claves para compatibilidad con backend
        if (userId != null) 'usuario_asigno': userId,
        if (userId != null) 'usuario_id': userId,
      };

      if (observaciones != null && observaciones.isNotEmpty) {
        requestData['observaciones'] = observaciones;
      }

      final uri = Uri.parse(
        '$_baseUrl/servicio/asignar_repuestos_servicio.php',
      );
      final authHeaders = await _getAuthHeaders();

      final response = await http
          .post(uri, headers: authHeaders, body: jsonEncode(requestData))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          // Parsear repuestos asignados
          final List<dynamic> repuestosData =
              responseData['data']['repuestos_asignados'] ?? [];
          final repuestosAsignados =
              repuestosData
                  .map(
                    (json) => ServicioRepuestoModel.fromJson(
                      json as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          // Log de resultados
          // final resumen = responseData['data']['resumen'];
          // print('✅ [API] Repuestos asignados exitosamente');

          return ApiResponse.success(
            data: repuestosAsignados,
            message:
                responseData['message'] ?? 'Repuestos asignados exitosamente',
          );
        } else {
          throw Exception(responseData['message'] ?? 'Error del servidor');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error asignando repuestos: $e');
      return ApiResponse.error('Error al asignar repuestos: $e');
    } finally {
      // Invalidate cache del servicio tras cambios
      _cachePorServicio.remove(servicioId);
    }
  }

  /// Obtiene todos los repuestos asignados a un servicio
  static Future<ApiResponse<ServicioRepuestosResponse>>
  listarRepuestosDeServicio({
    required int servicioId,
    bool incluirDetallesItem = true,
    bool forceRefresh = false,
  }) async {
    try {
      // print('📡 [API] Obteniendo repuestos del servicio $servicioId...');

      // Cache en memoria
      final now = DateTime.now();
      if (!forceRefresh) {
        final entry = _cachePorServicio[servicioId];
        if (entry != null && now.difference(entry.timestamp) < _ttlRepuestos) {
          return ApiResponse.success(
            data: entry.data,
            message: 'Repuestos del servicio cargados (cache)',
          );
        }
      }

      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('servicio_repuestos_cache_$servicioId');
        if (cached != null && cached.isNotEmpty) {
          final dataMap = (jsonDecode(cached) as Map).cast<String, dynamic>();
          final servicioRepuestos = ServicioRepuestosResponse.fromJson(dataMap);
          return ApiResponse.success(
            data: servicioRepuestos,
            message: 'Repuestos del servicio cargados (caché persistente)',
          );
        }
        return ApiResponse.error('Sin conexión y sin datos guardados');
      }

      final queryParams = <String, String>{
        'servicio_id': servicioId.toString(),
        'incluir_detalles_item': incluirDetallesItem.toString(),
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/listar_repuestos_servicio.php',
      ).replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final servicioRepuestos = ServicioRepuestosResponse.fromJson(
            responseData['data'],
          );

          // print('✅ [API] ${servicioRepuestos.totalItems} repuestos del servicio cargados');

          // Guardar en cache de memoria
          _cachePorServicio[servicioId] = _RepuestosCacheEntry(
            data: servicioRepuestos,
            timestamp: now,
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'servicio_repuestos_cache_$servicioId',
              jsonEncode(responseData['data']),
            );
          } catch (_) {}
          return ApiResponse.success(
            data: servicioRepuestos,
            message: 'Repuestos del servicio cargados',
          );
        } else {
          throw Exception(
            responseData['message'] ??
                'Error obteniendo repuestos del servicio',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error obteniendo repuestos del servicio: $e');
      return ApiResponse.error('Error al obtener repuestos del servicio: $e');
    }
  }

  /// Actualiza la cantidad de un repuesto asignado
  static Future<ApiResponse<ServicioRepuestoModel>> actualizarCantidadRepuesto({
    required int servicioRepuestoId,
    required double nuevaCantidad,
    String? notas,
  }) async {
    try {
      // print('📡 [API] Actualizando cantidad del repuesto $servicioRepuestoId...');

      if (nuevaCantidad <= 0) {
        return ApiResponse.error('La cantidad debe ser mayor a 0');
      }

      // Obtener usuario actual
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');

      final requestData = <String, dynamic>{
        'servicio_repuesto_id': servicioRepuestoId,
        'nueva_cantidad': nuevaCantidad,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
        if (usuarioId != null) 'usuario_actualiza': usuarioId,
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/actualizar_cantidad_repuesto.php',
      );
      final authHeaders = await _getAuthHeaders();

      final response = await http
          .put(uri, headers: authHeaders, body: jsonEncode(requestData))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final repuestoActualizado = ServicioRepuestoModel.fromJson(
            responseData['data']['repuesto_actualizado'],
          );

          // print('✅ [API] Cantidad actualizada exitosamente');

          return ApiResponse.success(
            data: repuestoActualizado,
            message:
                responseData['message'] ?? 'Cantidad actualizada exitosamente',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error actualizando cantidad',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error actualizando cantidad: $e');
      return ApiResponse.error('Error al actualizar cantidad: $e');
    } finally {
      _invalidateCacheByRepuestoId(servicioRepuestoId);
    }
  }

  /// Elimina un repuesto asignado a un servicio (devuelve stock al inventario)
  static Future<ApiResponse<Map<String, dynamic>>> eliminarRepuestoDeServicio({
    required int servicioRepuestoId,
    String? razon,
    bool devolverStock = true,
  }) async {
    try {
      // print('📡 [API] Eliminando repuesto $servicioRepuestoId del servicio...');

      // Obtener usuario actual
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');

      final requestData = <String, dynamic>{
        'servicio_repuesto_id': servicioRepuestoId,
        'devolver_stock': devolverStock,
        if (razon != null && razon.isNotEmpty) 'razon': razon,
        if (usuarioId != null) 'usuario_elimina': usuarioId,
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/eliminar_repuesto_servicio.php',
      );
      final authHeaders = await _getAuthHeaders();

      final response = await http
          .delete(uri, headers: authHeaders, body: jsonEncode(requestData))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final resultado = responseData['data'];

          // print('✅ [API] Repuesto eliminado exitosamente');

          return ApiResponse.success(
            data: resultado,
            message:
                responseData['message'] ?? 'Repuesto eliminado exitosamente',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error eliminando repuesto',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error eliminando repuesto: $e');
      return ApiResponse.error('Error al eliminar repuesto: $e');
    } finally {
      _invalidateCacheByRepuestoId(servicioRepuestoId);
    }
  }

  // =====================================
  //    OPERACIONES MASIVAS
  // =====================================

  /// Elimina todos los repuestos de un servicio (útil para cancelaciones)
  static Future<ApiResponse<Map<String, dynamic>>>
  eliminarTodosRepuestosServicio({
    required int servicioId,
    String? razon,
    bool devolverStock = true,
  }) async {
    try {
      // print('📡 [API] Eliminando todos los repuestos del servicio $servicioId...');

      // Obtener usuario actual
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');

      final requestData = <String, dynamic>{
        'servicio_id': servicioId,
        'devolver_stock': devolverStock,
        if (razon != null && razon.isNotEmpty) 'razon': razon,
        if (usuarioId != null) 'usuario_elimina': usuarioId,
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/eliminar_todos_repuestos_servicio.php',
      );
      final authHeaders = await _getAuthHeaders();

      final response = await http
          .post(uri, headers: authHeaders, body: jsonEncode(requestData))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final resultado = responseData['data'];

          // print('✅ [API] Todos los repuestos eliminados exitosamente');

          return ApiResponse.success(
            data: resultado,
            message:
                responseData['message'] ?? 'Todos los repuestos eliminados',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error eliminando repuestos',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error eliminando todos los repuestos: $e');
      return ApiResponse.error('Error al eliminar repuestos: $e');
    } finally {
      _invalidateCacheForServicio(servicioId);
    }
  }

  /// Actualiza múltiples repuestos de un servicio en una sola operación
  static Future<ApiResponse<List<ServicioRepuestoModel>>>
  actualizarMultiplesRepuestos({
    required List<Map<String, dynamic>> actualizaciones,
    String? observaciones,
  }) async {
    try {
      // print('📡 [API] Actualizando ${actualizaciones.length} repuestos...');

      // Obtener usuario actual
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');

      final requestData = <String, dynamic>{
        'actualizaciones': actualizaciones,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
        if (usuarioId != null) 'usuario_actualiza': usuarioId,
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/actualizar_multiples_repuestos.php',
      );
      final authHeaders = await _getAuthHeaders();

      final response = await http
          .put(uri, headers: authHeaders, body: jsonEncode(requestData))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> repuestosData =
              responseData['data']['repuestos_actualizados'] ?? [];
          final repuestosActualizados =
              repuestosData
                  .map(
                    (json) => ServicioRepuestoModel.fromJson(
                      json as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          // print('✅ [API] ${repuestosActualizados.length} repuestos actualizados');

          return ApiResponse.success(
            data: repuestosActualizados,
            message:
                responseData['message'] ??
                'Repuestos actualizados exitosamente',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error actualizando repuestos',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error actualizando múltiples repuestos: $e');
      return ApiResponse.error('Error al actualizar repuestos: $e');
    } finally {
      try {
        final ids =
            actualizaciones
                .map((a) => a['servicio_repuesto_id'])
                .whereType<int>()
                .toList();
        if (ids.isNotEmpty) {
          _invalidateCacheByRepuestoIds(ids);
        }
        int? servicioId;
        for (final a in actualizaciones) {
          final sId = a['servicio_id'];
          if (sId is int) {
            servicioId = sId;
            break;
          }
        }
        if (servicioId != null) {
          _invalidateCacheForServicio(servicioId);
        }
      } catch (_) {}
    }
  }

  // =====================================
  //    VALIDACIONES Y VERIFICACIONES
  // =====================================

  /// Verifica si un repuesto puede ser asignado (stock disponible)
  static Future<ApiResponse<Map<String, dynamic>>>
  verificarDisponibilidadRepuesto({
    required int inventoryItemId,
    required int cantidadSolicitada,
  }) async {
    try {
      // print('📡 [API] Verificando disponibilidad del item $inventoryItemId...');

      final queryParams = <String, String>{
        'inventory_item_id': inventoryItemId.toString(),
        'cantidad_solicitada': cantidadSolicitada.toString(),
      };

      final uri = Uri.parse(
        '$_baseUrl/servicio/verificar_disponibilidad_repuesto.php',
      ).replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final verificacion = responseData['data'];

          // print('✅ [API] Verificación completada');

          return ApiResponse.success(
            data: verificacion,
            message: 'Verificación completada',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error verificando disponibilidad',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error verificando disponibilidad: $e');
      return ApiResponse.error('Error al verificar disponibilidad: $e');
    }
  }

  // =====================================
  //    REPORTES Y ESTADÍSTICAS
  // =====================================

  /// Obtiene resumen de repuestos utilizados por período
  static Future<ApiResponse<Map<String, dynamic>>>
  obtenerResumenRepuestosPorPeriodo({
    required String fechaInicio,
    required String fechaFin,
    int? categoriaId,
    int? proveedorId,
  }) async {
    try {
      // print('📡 [API] Obteniendo resumen de repuestos por período...');

      final queryParams = <String, String>{
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
      };

      if (categoriaId != null) {
        queryParams['categoria_id'] = categoriaId.toString();
      }
      if (proveedorId != null) {
        queryParams['proveedor_id'] = proveedorId.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/servicio/resumen_repuestos_periodo.php',
      ).replace(queryParameters: queryParams);

      final authHeaders = await _getAuthHeaders();
      final response = await http
          .get(uri, headers: authHeaders)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final resumen = responseData['data'];

          // print('✅ [API] Resumen obtenido exitosamente');

          return ApiResponse.success(
            data: resumen,
            message: 'Resumen obtenido exitosamente',
          );
        } else {
          throw Exception(
            responseData['message'] ?? 'Error obteniendo resumen',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('❌ [API] Error obteniendo resumen: $e');
      return ApiResponse.error('Error al obtener resumen: $e');
    }
  }
}
