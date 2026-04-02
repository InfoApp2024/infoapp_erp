import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/pending_upload.dart';
import 'geocerca_service.dart';
import 'image_compression_service.dart';

/// Servicio para manejar uploads asíncronos de fotos de geocercas
/// con reintentos automáticos y cola persistente
class AsyncUploadService {
  static const String _pendingUploadsKey = 'pending_geocerca_uploads';
  static const int _maxRetries = 5;
  static const _uuid = Uuid();

  // Listeners para notificar cambios en la cola
  static final List<VoidCallback> _listeners = [];

  /// Registra un listener para cambios en la cola
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Elimina un listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notifica a todos los listeners
  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Encola una foto para subir de forma asíncrona
  static Future<void> enqueueUpload({
    required int geocercaId,
    required String event, // 'ingreso' o 'salida'
    required DateTime detectionTime,
    required File photoFile,
  }) async {
    try {
      if (kDebugMode) {
        print('📤 Encolando upload: geocerca=$geocercaId, event=$event');
      }

      // Comprimir imagen
      final compressedFile = await ImageCompressionService.compressImage(photoFile);

      final upload = PendingUpload(
        id: _uuid.v4(),
        geocercaId: geocercaId,
        event: event,
        detectionTime: detectionTime,
        captureTime: DateTime.now(), // Tiempo de captura
        photoPath: compressedFile.path,
        retryCount: 0,
        lastAttempt: DateTime.now(),
      );

      // Guardar en cola
      final pending = await _getPendingUploads();
      pending.add(upload);
      await _savePendingUploads(pending);

      if (kDebugMode) {
        print('✅ Upload encolado: ${upload.id}');
      }

      // Notificar cambios
      _notifyListeners();

      // Intentar subir inmediatamente (sin await para no bloquear)
      _processQueue();
    } catch (e) {
      if (kDebugMode) print('❌ Error al encolar upload: $e');
      rethrow;
    }
  }

  /// Procesa la cola de uploads pendientes
  static Future<void> _processQueue() async {
    final pending = await _getPendingUploads();
    if (pending.isEmpty) {
      _notifyListeners();
      return;
    }

    if (kDebugMode) {
      print('🔄 Procesando cola de uploads: ${pending.length} pendientes');
    }

    bool hasChanges = false;

    for (final upload in List.from(pending)) {
      // Calcular delay exponencial
      final delay = _calculateDelay(upload.retryCount);
      final timeSinceLastAttempt = DateTime.now().difference(upload.lastAttempt);

      if (timeSinceLastAttempt.inMilliseconds < delay) {
        // Aún no es tiempo de reintentar
        continue;
      }

      try {
        if (kDebugMode) {
          print('⬆️ Intentando subir: ${upload.id} (intento ${upload.retryCount + 1})');
        }

        await _uploadSingle(upload);

        // Éxito: eliminar de la cola
        pending.remove(upload);
        hasChanges = true;

        if (kDebugMode) {
          print('✅ Upload exitoso: ${upload.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error en upload ${upload.id}: $e');
        }

        // Fallo: incrementar contador de reintentos
        if (upload.retryCount >= _maxRetries - 1) {
          // Máximo de reintentos alcanzado: eliminar y notificar
          pending.remove(upload);
          hasChanges = true;

          if (kDebugMode) {
            print('❌ Upload fallido después de $_maxRetries intentos: ${upload.id}');
          }
        } else {
          // Actualizar reintento
          final updated = upload.copyWith(
            retryCount: upload.retryCount + 1,
            lastAttempt: DateTime.now(),
          );
          final index = pending.indexOf(upload);
          pending[index] = updated;
          hasChanges = true;

          if (kDebugMode) {
            print('🔄 Reintento ${updated.retryCount}/$_maxRetries programado para ${upload.id}');
          }
        }
      }
    }

    if (hasChanges) {
      await _savePendingUploads(pending);
      _notifyListeners();
    }
  }

  /// Calcula el delay exponencial para reintentos
  /// Reintento 0: 0ms (inmediato)
  /// Reintento 1: 2s
  /// Reintento 2: 4s
  /// Reintento 3: 8s
  /// Reintento 4: 16s
  static int _calculateDelay(int retryCount) {
    if (retryCount == 0) return 0;
    return (2000 * (1 << (retryCount - 1))); // 2^(n-1) * 2000ms
  }

  /// Sube un archivo individual
  static Future<void> _uploadSingle(PendingUpload upload) async {
    final photoFile = File(upload.photoPath);
    if (!await photoFile.exists()) {
      throw Exception('Archivo de foto no encontrado: ${upload.photoPath}');
    }

    if (upload.event == 'ingreso') {
      await GeocercaService.registrarIngresoConFoto(
        geocercaId: upload.geocercaId,
        detectionTime: upload.detectionTime,
        captureTime: upload.captureTime,
        photoFile: photoFile,
      );
    } else if (upload.event == 'salida') {
      await GeocercaService.registrarSalidaConFoto(
        geocercaId: upload.geocercaId,
        detectionTime: upload.detectionTime,
        captureTime: upload.captureTime,
        photoFile: photoFile,
      );
    } else {
      throw Exception('Evento desconocido: ${upload.event}');
    }

    // Eliminar archivo temporal después de subir exitosamente
    try {
      await photoFile.delete();
      if (kDebugMode) print('🗑️ Archivo temporal eliminado: ${upload.photoPath}');
    } catch (e) {
      if (kDebugMode) print('⚠️ No se pudo eliminar archivo temporal: $e');
    }
  }

  /// Obtiene uploads pendientes
  static Future<List<PendingUpload>> _getPendingUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_pendingUploadsKey);
      if (json == null || json.isEmpty) return [];

      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => PendingUpload.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('⚠️ Error al leer uploads pendientes: $e');
      return [];
    }
  }

  /// Guarda uploads pendientes
  static Future<void> _savePendingUploads(List<PendingUpload> uploads) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(uploads.map((e) => e.toJson()).toList());
      await prefs.setString(_pendingUploadsKey, json);
    } catch (e) {
      if (kDebugMode) print('⚠️ Error al guardar uploads pendientes: $e');
    }
  }

  /// Reintenta todos los uploads pendientes (llamar al iniciar app)
  static Future<void> retryPendingUploads() async {
    if (kDebugMode) {
      print('🔄 Reintentando uploads pendientes...');
    }
    await _processQueue();
  }

  /// Obtiene el número de uploads pendientes
  static Future<int> getPendingCount() async {
    final pending = await _getPendingUploads();
    return pending.length;
  }

  /// Limpia todos los uploads pendientes (usar con precaución)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUploadsKey);
    _notifyListeners();
    if (kDebugMode) print('🗑️ Cola de uploads limpiada');
  }
}
