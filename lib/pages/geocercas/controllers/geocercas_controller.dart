import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../models/geocerca_model.dart';
import '../models/registro_geocerca_model.dart';
import '../services/geocerca_service.dart';
import '../services/image_processing_service.dart';
import '../services/async_upload_service.dart';

enum GeofenceEvent { ingreso, salida }

class PendingTransition {
  final Geocerca geocerca;
  final GeofenceEvent event;
  final DateTime detectionTime;

  PendingTransition({
    required this.geocerca,
    required this.event,
    required this.detectionTime,
  });
}

class GeocercasController extends ChangeNotifier {
  List<Geocerca> _geocercas = [];
  List<Geocerca> get geocercas => _geocercas;

  List<RegistroGeocerca> _registros = [];
  List<RegistroGeocerca> get registros => _registros;

  bool _loading = false;
  bool get loading => _loading;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  // Mapa
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Estado local para evitar llamadas repetitivas al backend
  final Set<int> _insideGeofences = {};
  Set<int> get insideGeofences => _insideGeofences;

  // Transición pendiente de evidencia fotográfica
  PendingTransition? _pendingTransition;
  PendingTransition? get pendingTransition => _pendingTransition;

  // Almacenar ruta de la foto de la sesión actual para visualizar en UI
  final Map<int, String> _sessionPhotos = {};
  Map<int, String> get sessionPhotos => _sessionPhotos;

  void clearPendingTransition() {
    _pendingTransition = null;
    notifyListeners();
  }

  String? get nameOfCurrentGeofence {
    if (_insideGeofences.isEmpty) return null;
    final id = _insideGeofences.first;
    try {
      return _geocercas.firstWhere((g) => g.id == id).nombre;
    } catch (_) {
      return null;
    }
  }

  // Stream de ubicación
  // ignore: cancel_subscriptions
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Cargar geocercas
  Future<void> cargarGeocercas() async {
    // ✅ Solo notificar si no está ya cargando (evita parpadeo en recarga)
    if (!_loading) {
      _loading = true;
      notifyListeners();
    }
    
    try {
      _geocercas = await GeocercaService.listarGeocercas();
    } catch (e) {
      if (kDebugMode) print('Error cargando geocercas: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Crear
  Future<bool> crearGeocerca(Geocerca geocerca) async {
    try {
      await GeocercaService.crearGeocerca(geocerca);
      await cargarGeocercas();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error creando geocerca: $e');
      return false;
    }
  }

  // Actualizar
  Future<bool> actualizarGeocerca(Geocerca geocerca) async {
    try {
      await GeocercaService.actualizarGeocerca(geocerca);
      await cargarGeocercas();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error actualizando geocerca: $e');
      return false;
    }
  }

  // Eliminar
  Future<bool> eliminarGeocerca(int id) async {
    try {
      await GeocercaService.eliminarGeocerca(id);
      await cargarGeocercas();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error eliminando geocerca: $e');
      return false;
    }
  }

  // Registros
  Future<void> cargarRegistros({DateTime? inicio, DateTime? fin}) async {
    _loading = true;
    notifyListeners();
    try {
      final result = await GeocercaService.listarRegistros(
        fechaInicio: inicio,
        fechaFin: fin,
      );
      _registros = result['data'];
    } catch (e) {
      if (kDebugMode) print('Error cargando registros: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Geolocalización y chequeo
  Future<void> obtenerUbicacionActual() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Servicios de ubicación deshabilitados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permisos de ubicación denegados');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permisos de ubicación permanentemente denegados');
    }

    // Obtener ubicación actual una vez
    _currentPosition = await Geolocator.getCurrentPosition();
    notifyListeners();
  }

  // Iniciar monitoreo en tiempo real
  Future<void> iniciarMonitoreo() async {
    if (_isMonitoring) {
      if (kDebugMode) print('⚠️ Monitoreo ya está activo, ignorando solicitud duplicada');
      return;
    }

    // Asegurar permisos primero
    try {
      await obtenerUbicacionActual();
    } catch (e) {
      if (kDebugMode) print('❌ No se pudo iniciar monitoreo: $e');
      return;
    }

    // ✅ Verificar si hay registros abiertos (recuperar estado)
    await _verificarRegistrosAbiertos();

    // Cancelar suscripción anterior si existe
    await _positionStreamSubscription?.cancel();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Notificar cada 10 metros
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;
      // ✅ NO notificar aquí - verificarGeocercas() notificará solo si hay cambios relevantes
      verificarGeocercas(); // Chequear geocercas en cada actualización
    });

    _isMonitoring = true;
    if (kDebugMode) print('✅ Monitoreo de ubicación iniciado');
  }

  // Detener monitoreo
  Future<void> detenerMonitoreo() async {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _insideGeofences.clear();
    _isMonitoring = false;
    if (kDebugMode) print('⏹️ Monitoreo de ubicación detenido');
  }

  /// Verificar si hay registros abiertos en el backend
  /// Esto recupera el estado cuando la app se reinicia o el token expira
  Future<void> _verificarRegistrosAbiertos() async {
    try {
      if (kDebugMode) print('🔄 Verificando registros abiertos...');
      
      final registrosAbiertos = await GeocercaService.obtenerRegistrosAbiertos();
      
      if (registrosAbiertos.isEmpty) {
        if (kDebugMode) print('✅ No hay registros abiertos');
        return;
      }
      
      for (var registro in registrosAbiertos) {
        final geocercaId = registro['geocerca_id'] as int;
        final geocercaNombre = registro['geocerca_nombre'] as String;
        final fechaIngreso = registro['fecha_ingreso'] as String;
        
        // Marcar como "dentro" en el estado local
        _insideGeofences.add(geocercaId);
        
        if (kDebugMode) {
          print('🔄 Registro abierto recuperado:');
          print('   Geocerca: $geocercaNombre (ID: $geocercaId)');
          print('   Entrada: $fechaIngreso');
        }
      }
      
      if (kDebugMode) {
        print('✅ ${registrosAbiertos.length} registro(s) abierto(s) recuperado(s)');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al verificar registros abiertos: $e');
        print('   Continuando con monitoreo normal...');
      }
    }
  }

  // Lógica principal: Verificar si estoy en una geocerca
  Future<void> verificarGeocercas() async {
    // Si ya hay una transición esperando foto, no procesamos nuevas hasta que se resuelva
    if (_pendingTransition != null) return;

    if (_currentPosition == null) await obtenerUbicacionActual();
    if (_currentPosition == null) return;

    // Margen de tolerancia para evitar falsos positivos por fluctuación del GPS (Histéresis)
    const double margenTolerancia = 20.0; // metros

    for (var geo in _geocercas) {
      double distancia = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        geo.latitud,
        geo.longitud,
      );

      final bool wasInside = _insideGeofences.contains(geo.id);

      // Lógica de transición
      if (distancia <= geo.radio) {
        if (!wasInside) {
          // Recién entrando
          final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
          
          if (kDebugMode) print('🚪 ENTRADA detectada en "${geo.nombre}" (distancia: ${distancia.toStringAsFixed(1)}m)');
          
          if (isMobile) {
            // En móvil: Pausar y pedir foto
            _pendingTransition = PendingTransition(
              geocerca: geo,
              event: GeofenceEvent.ingreso,
              detectionTime: DateTime.now(),
            );
            notifyListeners();
            if (kDebugMode) print('📸 Esperando evidencia fotográfica para confirmar entrada...');
          } else {
            // En otras plataformas (Web/Desktop): Registro automático sin foto
            if (kDebugMode) print('💻 Plataforma Web/Desktop, registrando automáticamente...');
            await GeocercaService.registrarIngreso(geo.id);
            _insideGeofences.add(geo.id);
            notifyListeners();
            if (kDebugMode) print('✅ Entrada automática registrada en ${geo.nombre}');
          }
          break; 
        }
      } else if (distancia > (geo.radio + margenTolerancia)) {
        if (wasInside) {
          // Recién saliendo
          final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

          if (kDebugMode) print('🚪 SALIDA detectada de "${geo.nombre}" (distancia: ${distancia.toStringAsFixed(1)}m)');

          if (isMobile) {
            // En móvil: Pausar y pedir foto
            _pendingTransition = PendingTransition(
              geocerca: geo,
              event: GeofenceEvent.salida,
              detectionTime: DateTime.now(),
            );
            notifyListeners();
            if (kDebugMode) print('📸 Esperando evidencia fotográfica para confirmar salida...');
          } else {
            // En otras plataformas: Registro automático sin foto
            if (kDebugMode) print('💻 Plataforma Web/Desktop, registrando automáticamente...');
            await GeocercaService.registrarSalida(geo.id);
            _insideGeofences.remove(geo.id);
            notifyListeners();
            if (kDebugMode) print('✅ Salida automática registrada de ${geo.nombre}');
          }
          break;
        }
      }
    }
  }

  // Confirmar transición con la foto capturada
  // ✨ OPTIMIZADO: Upload asíncrono, UI no bloqueante
  Future<bool> confirmarTransicion(File rawPhoto) async {
    if (_pendingTransition == null) {
      if (kDebugMode) print('❌ No hay transición pendiente para confirmar');
      return false;
    }

    final geocercaNombre = _pendingTransition!.geocerca.nombre;
    final tipoEvento = _pendingTransition!.event == GeofenceEvent.ingreso ? 'ENTRADA' : 'SALIDA';
    final detectionTime = _pendingTransition!.detectionTime; // ⏱️ Tiempo GPS
    
    if (kDebugMode) print('📸 Iniciando confirmación de $tipoEvento en "$geocercaNombre"...');

    _loading = true;
    notifyListeners();

    try {
      // 1. Procesar la imagen (Redimensionar, Marca de agua, Compresión)
      if (kDebugMode) print('🖼️ Procesando imagen (redimensionar, marca de agua, compresión)...');
      
      final processedPhoto = await ImageProcessingService.procesarEvidencia(
        originalFile: rawPhoto,
        nombreLugar: _pendingTransition!.geocerca.nombre,
        tipoEvento: tipoEvento,
        latitud: _currentPosition?.latitude,
        longitud: _currentPosition?.longitude,
      );

      if (processedPhoto == null) {
        throw Exception('El servicio de procesamiento de imagen devolvió null');
      }

      if (kDebugMode) print('✅ Imagen procesada correctamente: ${processedPhoto.path}');

      // 2. ✨ NUEVO: Encolar upload asíncrono (no bloquea UI)
      if (kDebugMode) print('📤 Encolando upload asíncrono...');
      
      await AsyncUploadService.enqueueUpload(
        geocercaId: _pendingTransition!.geocerca.id,
        event: _pendingTransition!.event == GeofenceEvent.ingreso ? 'ingreso' : 'salida',
        detectionTime: detectionTime, // Tiempo GPS
        photoFile: processedPhoto, // Ya procesada con marca de agua
      );

      // 3. Actualizar estado local inmediatamente (optimistic update)
      if (_pendingTransition!.event == GeofenceEvent.ingreso) {
        _insideGeofences.add(_pendingTransition!.geocerca.id);
        
        // Guardar copia de la foto para mostrar en la interfaz mientras esté en el lugar
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/session_photo_${_pendingTransition!.geocerca.id}.jpg';
        await processedPhoto.copy(path);
        _sessionPhotos[_pendingTransition!.geocerca.id] = path;
        
        if (kDebugMode) print('💾 Foto de sesión guardada: $path');
      } else {
        _insideGeofences.remove(_pendingTransition!.geocerca.id);
        _sessionPhotos.remove(_pendingTransition!.geocerca.id);
      }

      // 4. Limpiar archivo original (el procesado se maneja en AsyncUploadService)
      if (await rawPhoto.exists()) await rawPhoto.delete();
      
      if (kDebugMode) print('🗑️ Archivo original limpiado');

      _pendingTransition = null;
      _loading = false;
      notifyListeners();
      
      if (kDebugMode) print('✅ Confirmación de $tipoEvento completada (upload en background)');
      return true;
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error confirmando transición de $tipoEvento en "$geocercaNombre":');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}
