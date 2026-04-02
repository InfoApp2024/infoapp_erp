import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/servicio_model.dart';
import 'servicios_api_service.dart';
import 'servicio_repuestos_api_service.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:http/http.dart' as http;

/// Cola de sincronización offline para operaciones de Servicios.
/// Guarda operaciones en `SharedPreferences` cuando no hay conexión
/// y las reprocesa automáticamente al volver a estar en línea.
class ServiciosSyncQueue {
  static const String _prefsKey = 'servicios_sync_queue_v1';

  /// Elemento de la cola
  /// `type`: 'create' | 'update'
  /// `payload`: ServicioModel serializado
  /// `ts`: timestamp ISO
  /// `attempts`: intentos realizados
  static Map<String, dynamic> _toItem(String type, ServicioModel servicio) {
    return {
      'type': type,
      'payload': servicio.toJson(),
      'ts': DateTime.now().toIso8601String(),
      'attempts': 0,
    };
  }

  /// Elemento genérico para otras operaciones relacionadas al servicio
  /// `type` ejemplos:
  /// - 'repuestos_assign' { servicioId, repuestos: [ {inventory_item_id, cantidad, ...} ] }
  /// - 'repuesto_delete' { servicioRepuestoId, razon?, devolverStock }
  /// - 'staff_update' { servicioId, usuarioIds: [...], responsableId }
  /// - 'foto_upload' { servicioId, tipo_foto, descripcion, imagen_base64, nombre_archivo }
  /// - 'foto_delete' { foto_id }
  static Map<String, dynamic> _toGenericItem(
    String type,
    Map<String, dynamic> payload,
  ) {
    return {
      'type': type,
      'payload': payload,
      'ts': DateTime.now().toIso8601String(),
      'attempts': 0,
    };
  }

  static Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(items));
  }

  static Future<int> pendingCount() async {
    final items = await _load();
    return items.length;
  }

  static Future<void> clear() async {
    await _save([]);
  }

  /// Encolar creación de servicio
  static Future<void> enqueueCreate(ServicioModel servicio) async {
    final items = await _load();
    items.add(_toItem('create', servicio));
    await _save(items);
  }

  /// Encolar creación de servicio y posterior asignación de usuarios
  /// Útil cuando se crea un servicio estando offline y se seleccionó personal.
  static Future<void> enqueueCreateConUsuarios({
    required ServicioModel servicio,
    required List<int> usuarioIds,
    required int responsableId,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('create_with_staff', {
        'servicio': servicio.toJson(),
        'usuarioIds': usuarioIds,
        'responsableId': responsableId,
      }),
    );
    await _save(items);
  }

  /// Encolar actualización de servicio
  static Future<void> enqueueUpdate(ServicioModel servicio) async {
    final items = await _load();
    items.add(_toItem('update', servicio));
    await _save(items);
  }

  /// Encolar asignación de repuestos cuando no hay conexión
  static Future<void> enqueueAsignarRepuestos({
    required int servicioId,
    required List<Map<String, dynamic>> repuestos,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('repuestos_assign', {
        'servicioId': servicioId,
        'repuestos': repuestos,
      }),
    );
    await _save(items);
  }

  /// Encolar eliminación de un repuesto asignado
  static Future<void> enqueueEliminarRepuesto({
    required int servicioRepuestoId,
    String? razon,
    bool devolverStock = false,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('repuesto_delete', {
        'servicioRepuestoId': servicioRepuestoId,
        'razon': razon,
        'devolverStock': devolverStock,
      }),
    );
    await _save(items);
  }

  /// Encolar actualización de usuarios asignados al servicio
  static Future<void> enqueueActualizarUsuarios({
    required int servicioId,
    required List<int> usuarioIds,
    required int responsableId,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('staff_update', {
        'servicioId': servicioId,
        'usuarioIds': usuarioIds,
        'responsableId': responsableId,
      }),
    );
    await _save(items);
  }

  /// Encolar subida de foto (base64 ya preparado)
  static Future<void> enqueueSubirFoto({
    required int servicioId,
    required String tipoFoto,
    required String descripcion,
    required String imagenBase64,
    required String nombreArchivo,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('foto_upload', {
        'servicio_id': servicioId,
        'tipo_foto': tipoFoto,
        'descripcion': descripcion,
        'imagen_base64': imagenBase64,
        'nombre_archivo': nombreArchivo,
      }),
    );
    await _save(items);
  }

  /// Encolar eliminación de foto
  static Future<void> enqueueEliminarFoto({required int fotoId}) async {
    final items = await _load();
    items.add(_toGenericItem('foto_delete', {'foto_id': fotoId}));
    await _save(items);
  }

  /// Encolar reordenamiento de fotos
  static Future<void> enqueueReordenarFotos({
    required int servicioId,
    required List<Map<String, dynamic>> ordenes,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('foto_reorder', {
        'servicio_id': servicioId,
        'ordenes': ordenes,
      }),
    );
    await _save(items);
  }

  /// Encolar creación de firma
  static Future<void> enqueueCrearFirma({
    required int servicioId,
    required int staffEntregaId,
    required int funcionarioRecibeId,
    required String firmaStaffBase64,
    required String firmaFuncionarioBase64,
    String? notaEntrega,
    String? notaRecepcion,
    String? participantesServicio,
  }) async {
    final items = await _load();
    items.add(
      _toGenericItem('firma_create', {
        'id_servicio': servicioId,
        'id_staff_entrega': staffEntregaId,
        'id_funcionario_recibe': funcionarioRecibeId,
        'firma_staff_base64': firmaStaffBase64,
        'firma_funcionario_base64': firmaFuncionarioBase64,
        if (notaEntrega != null) 'nota_entrega': notaEntrega,
        if (notaRecepcion != null) 'nota_recepcion': notaRecepcion,
        if (participantesServicio != null)
          'participantes_servicio': participantesServicio,
      }),
    );
    await _save(items);
  }

  /// Procesar cola pendiente. Devuelve el número de operaciones aplicadas.
  static Future<int> processPending({int maxAttempts = 3}) async {
    final items = await _load();
    if (items.isEmpty) return 0;

    int applied = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final item in items) {
      final type = item['type'] as String?;
      final payload = item['payload'] as Map<String, dynamic>?;
      int attempts = (item['attempts'] as int?) ?? 0;

      if (type == null || payload == null) {
        // Item corrupto: descartar
        continue;
      }

      try {
        if (type == 'create' || type == 'update') {
          final servicio = ServicioModel.fromJson(payload);
          if (type == 'create') {
            final resp = await ServiciosApiService.crearServicio(servicio);
            if (resp.isSuccess) {
              applied++;
              continue; // Consumido
            } else {
              throw Exception(resp.error ?? 'Error creando servicio');
            }
          } else {
            final resp = await ServiciosApiService.actualizarServicio(servicio);
            if (resp.isSuccess) {
              applied++;
              continue; // Consumido
            } else {
              throw Exception(resp.error ?? 'Error actualizando servicio');
            }
          }
        }

        // Creación con asignación de usuarios
        if (type == 'create_with_staff') {
          final servicioJson =
              (payload['servicio'] as Map).cast<String, dynamic>();
          final servicio = ServicioModel.fromJson(servicioJson);
          final usuarioIds = (payload['usuarioIds'] as List).cast<int>();
          final responsableId = payload['responsableId'] as int;

          final respCreate = await ServiciosApiService.crearServicio(servicio);
          if (respCreate.isSuccess && respCreate.data?.id != null) {
            final nuevoId = respCreate.data!.id!;
            // Intentar asignar usuarios inmediatamente
            final respStaff =
                await ServiciosApiService.actualizarUsuariosServicio(
                  servicioId: nuevoId,
                  usuarioIds: usuarioIds,
                  responsableId: responsableId,
                );
            if (respStaff.isSuccess) {
              applied++;
              continue; // Consumido
            } else {
              // Si falla la asignación, reencolar como actualización de usuarios
              remaining.add(
                _toGenericItem('staff_update', {
                  'servicioId': nuevoId,
                  'usuarioIds': usuarioIds,
                  'responsableId': responsableId,
                }),
              );
              applied++;
              continue; // Creación aplicada; staff pendiente
            }
          } else {
            throw Exception(respCreate.error ?? 'Error creando servicio');
          }
        }

        // Repuestos: asignación
        if (type == 'repuestos_assign') {
          final servicioId = payload['servicioId'] as int;
          final repuestos =
              (payload['repuestos'] as List).cast<Map<String, dynamic>>();
          final resp =
              await ServicioRepuestosApiService.asignarRepuestosAServicio(
                servicioId: servicioId,
                repuestos: repuestos,
              );
          if (resp.success) {
            applied++;
            continue;
          } else {
            throw Exception(resp.message ?? 'Error asignando repuestos');
          }
        }

        // Repuestos: eliminación
        if (type == 'repuesto_delete') {
          final servicioRepuestoId = payload['servicioRepuestoId'] as int;
          final razon = payload['razon'] as String?;
          final devolverStock = (payload['devolverStock'] as bool?) ?? false;
          final resp =
              await ServicioRepuestosApiService.eliminarRepuestoDeServicio(
                servicioRepuestoId: servicioRepuestoId,
                razon: razon,
                devolverStock: devolverStock,
              );
          if (resp.success) {
            applied++;
            continue;
          } else {
            throw Exception(resp.message ?? 'Error eliminando repuesto');
          }
        }

        // Staff: actualización
        if (type == 'staff_update') {
          final servicioId = payload['servicioId'] as int;
          final usuarioIds = (payload['usuarioIds'] as List).cast<int>();
          final responsableId = payload['responsableId'] as int;
          final resp = await ServiciosApiService.actualizarUsuariosServicio(
            servicioId: servicioId,
            usuarioIds: usuarioIds,
            responsableId: responsableId,
          );
          if (resp.isSuccess) {
            applied++;
            continue;
          } else {
            throw Exception(resp.error ?? 'Error actualizando usuarios');
          }
        }

        // Foto: subida con base64
        if (type == 'foto_upload') {
          final token = await AuthService.getBearerToken();
          final rawToken = await AuthService.getToken();
          final headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            if (token != null) 'Authorization': token,
          };
          final baseUrl = ServerConfig.instance.baseUrlFor('servicio');
          final uri = Uri.parse(
            '$baseUrl/subir_foto_servicio_base64.php${rawToken != null ? '?token=$rawToken' : ''}',
          );
          final response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            final json = jsonDecode(response.body);
            if (json['success'] == true) {
              applied++;
              continue;
            } else {
              throw Exception(json['message'] ?? 'Error subiendo foto');
            }
          } else {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        }

        // Foto: eliminación
        if (type == 'foto_delete') {
          final token = await AuthService.getBearerToken();
          final rawToken = await AuthService.getToken();
          final headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            if (token != null) 'Authorization': token,
          };
          final baseUrl = ServerConfig.instance.baseUrlFor('servicio');
          final uri = Uri.parse(
            '$baseUrl/eliminar_foto_servicio.php${rawToken != null ? '?token=$rawToken' : ''}',
          );
          final response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          );
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['success'] == true) {
              applied++;
              continue;
            } else {
              throw Exception(json['message'] ?? 'Error eliminando foto');
            }
          } else {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        }

        if (type == 'firma_create') {
          final token = await AuthService.getBearerToken();
          final rawToken = await AuthService.getToken();
          final headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            if (token != null) 'Authorization': token,
          };
          final baseUrl = ServerConfig.instance.baseUrlFor('firma');
          final uri = Uri.parse(
            '$baseUrl/crear_firma.php${rawToken != null ? '?token=$rawToken' : ''}',
          );
          final response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            final json = jsonDecode(response.body);
            if (json['success'] == true) {
              applied++;
              continue;
            } else {
              throw Exception(json['message'] ?? 'Error creando firma');
            }
          } else {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        }

        // Tipo desconocido: descartar
        continue;
      } catch (_) {
        attempts += 1;
        if (attempts < maxAttempts) {
          // Reencolar con intentos actualizados
          item['attempts'] = attempts;
          remaining.add(item);
        } else {
          // Agotar intentos: descartar silenciosamente para no bloquear
        }
      }
    }

    await _save(remaining);
    return applied;
  }
}
