import 'servicio_model.dart';

/// Modelo para eventos de WebSocket relacionados con servicios
class ServicioEventoModel {
  final String tipo;
  final ServicioModel? servicio;
  final int? servicioId;
  final String? mensaje;
  final DateTime timestamp;
  final String? usuarioId;
  final String? usuarioNombre;
  final String? estadoMostrar;
  final dynamic valor; // Puede ser cualquier tipo según el campo

  const ServicioEventoModel({
    required this.tipo,
    this.servicio,
    this.servicioId,
    this.mensaje,
    required this.timestamp,
    this.usuarioId,
    this.usuarioNombre,
    this.estadoMostrar,
    this.valor,
  });

  /// Crear desde JSON
  factory ServicioEventoModel.fromJson(Map<String, dynamic> json) {
    return ServicioEventoModel(
      tipo: json['tipo'] as String,
      servicio:
          json['servicio'] != null
              ? ServicioModel.fromJson(json['servicio'] as Map<String, dynamic>)
              : null,
      servicioId: json['servicio_id'] as int?,
      mensaje: json['mensaje'] as String?,
      timestamp:
          json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
              : DateTime.now(),
      usuarioId: json['usuario_id'] as String?,
      usuarioNombre: json['usuario_nombre'] as String?,
      estadoMostrar: json['estado_mostrar'] as String?,
      valor: json['valor'],
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo,
      'servicio': servicio?.toJson(),
      'servicio_id': servicioId,
      'mensaje': mensaje,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'estado_mostrar': estadoMostrar,
      'valor': valor,
    };
  }

  /// Tipos de eventos disponibles
  static const String servicioCreado = 'servicio_creado';
  static const String servicioActualizado = 'servicio_actualizado';
  static const String servicioEliminado = 'servicio_eliminado';
  static const String servicioEstadoCambiado = 'servicio_estado_cambiado';

  /// Verificar si es un evento de creación
  bool get esCreacion => tipo == servicioCreado;

  /// Verificar si es un evento de actualización
  bool get esActualizacion => tipo == servicioActualizado;

  /// Verificar si es un evento de eliminación
  bool get esEliminacion => tipo == servicioEliminado;

  /// Obtener mensaje descriptivo del evento
  String get mensajeDescriptivo {
    if (mensaje != null) return mensaje!;

    switch (tipo) {
      case servicioCreado:
        return 'Nuevo servicio #${servicio?.oServicio ?? servicioId} creado';
      case servicioActualizado:
        return 'Servicio #${servicio?.oServicio ?? servicioId} actualizado';
      case servicioEliminado:
        return 'Servicio #$servicioId eliminado';
      case servicioEstadoCambiado:
        return 'Estado del servicio #${servicio?.oServicio ?? servicioId} cambiado';
      default:
        return 'Cambio en servicio #${servicio?.oServicio ?? servicioId}';
    }
  }

  /// Obtener ícono para el tipo de evento
  String get icono {
    switch (tipo) {
      case servicioCreado:
        return '🆕';
      case servicioActualizado:
        return '🔄';
      case servicioEliminado:
        return '🗑️';
      case servicioEstadoCambiado:
        return '⇄';
      default:
        return '📋';
    }
  }

  @override
  String toString() {
    return 'ServicioEventoModel(tipo: $tipo, servicioId: ${servicio?.id ?? servicioId}, timestamp: $timestamp)';
  }
}

/// Modelo para el estado de conexión WebSocket
class WebSocketEstadoModel {
  final bool conectado;
  final String? mensaje;
  final DateTime timestamp;
  final int intentosReconexion;

  const WebSocketEstadoModel({
    required this.conectado,
    this.mensaje,
    required this.timestamp,
    this.intentosReconexion = 0,
  });

  /// Crear estado conectado
  factory WebSocketEstadoModel.conectado() {
    return WebSocketEstadoModel(
      conectado: true,
      mensaje: 'Conectado',
      timestamp: DateTime.now(),
    );
  }

  /// Crear estado desconectado
  factory WebSocketEstadoModel.desconectado({String? razon}) {
    return WebSocketEstadoModel(
      conectado: false,
      mensaje: razon ?? 'Desconectado',
      timestamp: DateTime.now(),
    );
  }

  /// Crear estado reconectando
  factory WebSocketEstadoModel.reconectando(int intentos) {
    return WebSocketEstadoModel(
      conectado: false,
      mensaje: 'Reconectando... (intento $intentos)',
      timestamp: DateTime.now(),
      intentosReconexion: intentos,
    );
  }
}
