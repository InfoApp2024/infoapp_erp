/// ============================================================================
/// ARCHIVO: inspeccion_model.dart
///
/// PROPÓSITO: Modelo de datos que:
/// - Define la estructura de una inspección
/// - Maneja serialización/deserialización JSON
/// - Implementa métodos de utilidad (copyWith, toString, etc.)
/// - Valida y parsea tipos de datos
///
/// USO: Estructura de datos base usada en todo el módulo de inspecciones
/// ============================================================================
library;


class InspeccionModel {
  final int? id;
  final String? oInspe;
  final int? estadoId;
  final String? estadoNombre;
  final String? estadoColor;
  final bool? esFinal;
  final String? sitio;
  final String? fechaInspe;
  final int? equipoId;
  final int? clienteId;
  final String? equipoNombre;
  final String? equipoPlaca;
  final String? equipoModelo;
  final String? equipoMarca;
  final String? equipoEmpresa;
  final String? createdAt;
  final String? updatedAt;
  final String? creadoPorNombre;
  final String? actualizadoPorNombre;
  final int? totalInspectores;
  final int? totalSistemas;
  final int? totalActividades;
  final int? actividadesAutorizadas;
  final int? actividadesEliminadas;
  final int? actividadesVinculadas;
  final int? totalEvidencias;

  // Listas relacionadas (solo en detalle completo)
  final List<InspectorModel>? inspectores;
  final List<SistemaInspeccionModel>? sistemas;
  final List<ActividadInspeccionModel>? actividades;
  final List<EvidenciaModel>? evidencias;

  const InspeccionModel({
    this.id,
    this.oInspe,
    this.estadoId,
    this.estadoNombre,
    this.estadoColor,
    this.esFinal,
    this.sitio,
    this.fechaInspe,
    this.equipoId,
    this.clienteId,
    this.equipoNombre,
    this.equipoPlaca,
    this.equipoModelo,
    this.equipoMarca,
    this.equipoEmpresa,
    this.createdAt,
    this.updatedAt,
    this.creadoPorNombre,
    this.actualizadoPorNombre,
    this.totalInspectores,
    this.totalSistemas,
    this.totalActividades,
    this.actividadesAutorizadas,
    this.actividadesEliminadas,
    this.actividadesVinculadas,
    this.totalEvidencias,
    this.inspectores,
    this.sistemas,
    this.actividades,
    this.evidencias,
  });

  // Crear desde JSON (lista)
  bool get estaFinalizada {
    // Si el backend explícitamente nos dice que es el estado final (ID máximo), confiamos en ello.
    if (esFinal == true) return true;

    // Fallback por nombre para robustez o si no viene el flag
    if (estadoNombre == null) return false;
    final nombre = estadoNombre!.toUpperCase();
    return nombre.contains('APROBAD') || 
           nombre.contains('COMPLETAD') || 
           nombre.contains('RECHAZAD') || 
           nombre.contains('FINALIZAD') || 
           nombre.contains('TERMINAD') || 
           nombre.contains('CERRAD');
  }

  factory InspeccionModel.fromJson(Map<String, dynamic> json) {
    return InspeccionModel(
      id: _parseToInt(json['id']),
      oInspe: json['o_inspe']?.toString(),
      estadoId: _parseToInt(json['estado_id']),
      estadoNombre: json['estado_nombre']?.toString(),
      estadoColor: json['estado_color']?.toString(),
      esFinal: _parseToBool(json['es_final']),
      sitio: json['sitio']?.toString(),
      fechaInspe: json['fecha_inspe']?.toString(),
      equipoId: _parseToInt(json['equipo_id']),
      clienteId: _parseToInt(json['cliente_id']),
      equipoNombre: json['equipo_nombre']?.toString(),
      equipoPlaca: json['equipo_placa']?.toString(),
      equipoModelo: json['equipo_modelo']?.toString(),
      equipoMarca: json['equipo_marca']?.toString(),
      equipoEmpresa: json['equipo_empresa']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      creadoPorNombre: json['creado_por_nombre']?.toString(),
      actualizadoPorNombre: json['actualizado_por_nombre']?.toString(),
      totalInspectores: _parseToInt(json['total_inspectores']),
      totalSistemas: _parseToInt(json['total_sistemas']),
      totalActividades: _parseToInt(json['total_actividades']),
      actividadesAutorizadas: _parseToInt(json['actividades_autorizadas']),
      actividadesEliminadas: _parseToInt(json['actividades_eliminadas']),
      actividadesVinculadas: _parseToInt(json['actividades_vinculadas']),
      totalEvidencias: _parseToInt(json['total_evidencias']),
    );
  }

  // Crear desde JSON detallado (con relaciones)
  factory InspeccionModel.fromJsonDetalle(Map<String, dynamic> json) {
    return InspeccionModel(
      id: _parseToInt(json['id']),
      oInspe: json['o_inspe']?.toString(),
      estadoId: _parseToInt(json['estado_id']),
      estadoNombre: json['estado_nombre']?.toString(),
      estadoColor: json['estado_color']?.toString(),
      esFinal: _parseToBool(json['es_final']),
      sitio: json['sitio']?.toString(),
      fechaInspe: json['fecha_inspe']?.toString(),
      equipoId: _parseToInt(json['equipo_id']),
      clienteId: _parseToInt(json['cliente_id']),
      equipoNombre: json['equipo']?['nombre']?.toString() ?? json['equipo_nombre']?.toString(),
      equipoPlaca: json['equipo']?['placa']?.toString() ?? json['equipo_placa']?.toString(),
      equipoModelo: json['equipo']?['modelo']?.toString() ?? json['equipo_modelo']?.toString(),
      equipoMarca: json['equipo']?['marca']?.toString() ?? json['equipo_marca']?.toString(),
      equipoEmpresa: json['equipo']?['nombre_empresa']?.toString() ?? json['equipo_empresa']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      creadoPorNombre: json['creado_por_nombre']?.toString(),
      actualizadoPorNombre: json['actualizado_por_nombre']?.toString(),
      totalInspectores: json['totales']?['inspectores'] as int?,
      totalSistemas: json['totales']?['sistemas'] as int?,
      totalActividades: json['totales']?['actividades'] as int?,
      actividadesAutorizadas: json['totales']?['actividades_autorizadas'] as int?,
      actividadesEliminadas: json['totales']?['actividades_eliminadas'] as int?,
      actividadesVinculadas: json['totales']?['actividades_vinculadas'] as int?,
      totalEvidencias: json['totales']?['evidencias'] as int?,
      inspectores: (json['inspectores'] as List<dynamic>?)
          ?.map((e) => InspectorModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sistemas: (json['sistemas'] as List<dynamic>?)
          ?.map((e) => SistemaInspeccionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      actividades: (json['actividades'] as List<dynamic>?)
          ?.map((e) => ActividadInspeccionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      evidencias: (json['evidencias'] as List<dynamic>?)
          ?.map((e) => EvidenciaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Convertir a JSON (para enviar al backend)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (estadoId != null) 'estado_id': estadoId,
      if (sitio != null) 'sitio': sitio,
      if (fechaInspe != null) 'fecha_inspe': fechaInspe,
      if (equipoId != null) 'equipo_id': equipoId,
      if (clienteId != null) 'cliente_id': clienteId,
      if (inspectores != null)
        'inspectores': inspectores!.map((e) => e.usuarioId).toList(),
      if (sistemas != null)
        'sistemas': sistemas!.map((e) => e.sistemaId).toList(),
      if (actividades != null)
        'actividades': actividades!.map((e) => e.actividadId).toList(),
    };
  }

  // Crear copia con modificaciones

  InspeccionModel copyWith({
    int? id,
    String? oInspe,
    int? estadoId,
    String? estadoNombre,
    String? estadoColor,
    bool? esFinal,
    String? sitio,
    String? fechaInspe,
    int? equipoId,
    int? clienteId,
    String? equipoNombre,
    String? equipoPlaca,
    String? equipoModelo,
    String? equipoMarca,
    String? equipoEmpresa,
    String? createdAt,
    String? updatedAt,
    String? creadoPorNombre,
    String? actualizadoPorNombre,
    int? totalInspectores,
    int? totalSistemas,
    int? totalActividades,
    int? actividadesAutorizadas,
    int? actividadesEliminadas,
    int? totalEvidencias,
    List<InspectorModel>? inspectores,
    List<SistemaInspeccionModel>? sistemas,
    List<ActividadInspeccionModel>? actividades,
    List<EvidenciaModel>? evidencias,
  }) {
    return InspeccionModel(
      id: id ?? this.id,
      oInspe: oInspe ?? this.oInspe,
      estadoId: estadoId ?? this.estadoId,
      estadoNombre: estadoNombre ?? this.estadoNombre,
      estadoColor: estadoColor ?? this.estadoColor,
      esFinal: esFinal ?? this.esFinal,
      sitio: sitio ?? this.sitio,
      fechaInspe: fechaInspe ?? this.fechaInspe,
      equipoId: equipoId ?? this.equipoId,
      clienteId: clienteId ?? this.clienteId,
      equipoNombre: equipoNombre ?? this.equipoNombre,
      equipoPlaca: equipoPlaca ?? this.equipoPlaca,
      equipoModelo: equipoModelo ?? this.equipoModelo,
      equipoMarca: equipoMarca ?? this.equipoMarca,
      equipoEmpresa: equipoEmpresa ?? this.equipoEmpresa,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
      actualizadoPorNombre: actualizadoPorNombre ?? this.actualizadoPorNombre,
      totalInspectores: totalInspectores ?? this.totalInspectores,
      totalSistemas: totalSistemas ?? this.totalSistemas,
      totalActividades: totalActividades ?? this.totalActividades,
      actividadesAutorizadas: actividadesAutorizadas ?? this.actividadesAutorizadas,
      actividadesEliminadas: actividadesEliminadas ?? this.actividadesEliminadas,
      totalEvidencias: totalEvidencias ?? this.totalEvidencias,
      inspectores: inspectores ?? this.inspectores,
      sistemas: sistemas ?? this.sistemas,
      actividades: actividades ?? this.actividades,
      evidencias: evidencias ?? this.evidencias,
    );
  }

  // Métodos auxiliares
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _parseToBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return null;
  }

  // Getters útiles
  String get numeroInspeccionFormateado => oInspe ?? '#0000';

  /// Cantidad de actividades pendientes (Total - Autorizadas - Eliminadas - Vinculadas)
  int get actividadesPendientes {
    final total = totalActividades ?? 0;
    final autorizadas = actividadesAutorizadas ?? 0;
    final eliminadas = actividadesEliminadas ?? 0;
    final vinculadas = actividadesVinculadas ?? 0;
    final pendientes = total - autorizadas - eliminadas - vinculadas;
    return pendientes > 0 ? pendientes : 0;
  }

  DateTime? get fechaInspeDate {
    if (fechaInspe == null) return null;
    try {
      return DateTime.parse(fechaInspe!);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'InspeccionModel(id: $id, oInspe: $oInspe, sitio: $sitio, equipoNombre: $equipoNombre)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InspeccionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ============================================================================
// Modelo para Inspector
// ============================================================================
class InspectorModel {
  final int? id;
  final int? usuarioId;
  final String? rolInspector;
  final String? nombre;
  final String? username;
  final String? email;

  const InspectorModel({
    this.id,
    this.usuarioId,
    this.rolInspector,
    this.nombre,
    this.username,
    this.email,
  });

  factory InspectorModel.fromJson(Map<String, dynamic> json) {
    return InspectorModel(
      id: json['id'] as int?,
      usuarioId: json['usuario_id'] as int?,
      rolInspector: json['rol_inspector']?.toString(),
      nombre: json['nombre']?.toString(),
      username: json['username']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (rolInspector != null) 'rol_inspector': rolInspector,
    };
  }
}

// ============================================================================
// Modelo para Sistema en Inspección
// ============================================================================
class SistemaInspeccionModel {
  final int? id;
  final int? sistemaId;
  final String? nombre;
  final String? descripcion;

  const SistemaInspeccionModel({
    this.id,
    this.sistemaId,
    this.nombre,
    this.descripcion,
  });

  factory SistemaInspeccionModel.fromJson(Map<String, dynamic> json) {
    return SistemaInspeccionModel(
      id: json['id'] as int?,
      sistemaId: json['sistema_id'] as int?,
      nombre: json['nombre']?.toString(),
      descripcion: json['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sistemaId != null) 'sistema_id': sistemaId,
    };
  }
}

// ============================================================================
// Modelo para Actividad de Inspección
// ============================================================================
class ActividadInspeccionModel {
  final int? id;
  final int? actividadId;
  final String? actividadNombre;
  final String? actividadDescripcion;
  final bool? autorizada;
  final int? autorizadoPorId;
  final String? autorizadoPorNombre;
  final String? ordenCliente;
  final int? servicioId;
  final String? servicioNumero;
  final String? servicioFecha;
  final String? fechaAutorizacion;
  final String? avaladorNombre;
  final String? aprobadoPorNombre;
  final String? notas;
  final String? createdAt;
  final String? updatedAt;
  final String? registradoPorNombre;
  final String? eliminadoPorNombre;
  final String? deletedAt;

  const ActividadInspeccionModel({
    this.id,
    this.actividadId,
    this.actividadNombre,
    this.actividadDescripcion,
    this.autorizada,
    this.autorizadoPorId,
    this.autorizadoPorNombre,
    this.ordenCliente,
    this.servicioId,
    this.servicioNumero,
    this.servicioFecha,
    this.fechaAutorizacion,
    this.avaladorNombre,
    this.aprobadoPorNombre,
    this.notas,
    this.createdAt,
    this.updatedAt,
    this.registradoPorNombre,
    this.eliminadoPorNombre,
    this.deletedAt,
  });

  factory ActividadInspeccionModel.fromJson(Map<String, dynamic> json) {
    return ActividadInspeccionModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      actividadId:
          json['actividad_id'] != null
              ? int.tryParse(json['actividad_id'].toString())
              : null,
      actividadNombre: json['actividad_nombre']?.toString(),
      actividadDescripcion: json['actividad_descripcion']?.toString(),
      autorizada: json['autorizada'] == true ||
          json['autorizada'] == 1 ||
          json['autorizada'] == '1' ||
          json['autorizada'] == 'true',
      autorizadoPorId:
          json['autorizado_por_id'] != null
              ? int.tryParse(json['autorizado_por_id'].toString())
              : null,
      autorizadoPorNombre: json['autorizado_por_nombre']?.toString(),
      ordenCliente: json['orden_cliente']?.toString(),
      servicioId:
          json['servicio_id'] != null
              ? int.tryParse(json['servicio_id'].toString())
              : null,
      servicioNumero: json['servicio_numero']?.toString(),
      servicioFecha: json['servicio_fecha']?.toString(),
      fechaAutorizacion: json['fecha_autorizacion']?.toString(),
      avaladorNombre: json['avalador_nombre']?.toString(),
      aprobadoPorNombre: json['aprobado_por_nombre']?.toString(),
      notas: json['notas']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      registradoPorNombre: json['registrado_por_nombre']?.toString(),
      eliminadoPorNombre: json['eliminado_por_nombre']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (actividadId != null) 'actividad_id': actividadId,
      if (autorizada != null) 'autorizada': autorizada,
      if (notas != null) 'notas': notas,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };
  }

  bool get estaEliminada => deletedAt != null;

  bool get yaSeCreoServicio => servicioId != null;

  String get servicioNumeroFormateado =>
      servicioNumero != null ? 'Servicio #$servicioNumero' : 'Sin servicio';
}

// ============================================================================
// Modelo para Evidencia
// ============================================================================
class EvidenciaModel {
  final int? id;
  final int? inspeccionId;
  final int? actividadId;
  final String? rutaImagen;
  final String? comentario;
  final int? orden;
  final String? createdAt;
  final String? creadoPorNombre;

  const EvidenciaModel({
    this.id,
    this.inspeccionId,
    this.actividadId,
    this.rutaImagen,
    this.comentario,
    this.orden,
    this.createdAt,
    this.creadoPorNombre,
  });

  factory EvidenciaModel.fromJson(Map<String, dynamic> json) {
    return EvidenciaModel(
      id: json['id'] as int?,
      inspeccionId: json['inspeccion_id'] as int?,
      actividadId: json['actividad_id'] as int?,
      rutaImagen: json['ruta_imagen']?.toString(),
      comentario: json['comentario']?.toString(),
      orden: json['orden'] as int?,
      createdAt: json['created_at']?.toString(),
      creadoPorNombre: json['creado_por_nombre']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (inspeccionId != null) 'inspeccion_id': inspeccionId,
      if (actividadId != null) 'actividad_id': actividadId,
      if (comentario != null) 'comentario': comentario,
      if (orden != null) 'orden': orden,
    };
  }
}
