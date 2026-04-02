/// Modelo para representar una operación o subtarea de un servicio
class OperacionModel {
  final int? id;
  final int servicioId;
  final String descripcion;
  final int? actividadEstandarId;
  final String? fechaInicio;
  final String? fechaFin;
  final int? tecnicoResponsableId;
  final String? tecnicoNombre;
  final String? observaciones;
  final String? createdAt;
  final String? updatedAt;
  final bool isMaster; // ✅ NUEVO

  OperacionModel({
    this.id,
    required this.servicioId,
    required this.descripcion,
    this.actividadEstandarId,
    this.fechaInicio,
    this.fechaFin,
    this.tecnicoResponsableId,
    this.tecnicoNombre,
    this.observaciones,
    this.createdAt,
    this.updatedAt,
    this.isMaster = false, // ✅ NUEVO
  });

  bool get estaFinalizada => fechaFin != null;

  /// Calcula la duración transcurrida hasta ahora (o hasta el fin si ya terminó)
  Duration get duracionCalculada {
    if (fechaInicio == null) return Duration.zero;
    try {
      final inicio =
          DateTime.parse(fechaInicio!.replaceFirst(' ', 'T')).toLocal();
      final fin =
          fechaFin != null
              ? DateTime.parse(fechaFin!.replaceFirst(' ', 'T')).toLocal()
              : DateTime.now();
      return fin.difference(inicio);
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Indica si la operación lleva más de 12 horas abierta
  bool get excedeLimiteLogico {
    if (estaFinalizada) return false;
    return duracionCalculada.inHours >= 12;
  }

  factory OperacionModel.fromJson(Map<String, dynamic> json) {
    return OperacionModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      servicioId:
          (json['servicio_id'] is int
              ? json['servicio_id']
              : int.tryParse(json['servicio_id']?.toString() ?? '')) ??
          0,
      descripcion: json['descripcion']?.toString() ?? '',
      actividadEstandarId:
          json['actividad_estandar_id'] is int
              ? json['actividad_estandar_id']
              : int.tryParse(json['actividad_estandar_id']?.toString() ?? ''),
      fechaInicio: json['fecha_inicio']?.toString(),
      fechaFin: json['fecha_fin']?.toString(),
      tecnicoResponsableId:
          json['tecnico_responsable_id'] is int
              ? json['tecnico_responsable_id']
              : int.tryParse(json['tecnico_responsable_id']?.toString() ?? ''),
      tecnicoNombre: json['tecnico_nombre']?.toString(),
      observaciones: json['observaciones']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      isMaster:
          (json['is_master'] == 1 || json['is_master'] == true), // ✅ NUEVO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'servicio_id': servicioId,
      'descripcion': descripcion,
      if (actividadEstandarId != null)
        'actividad_estandar_id': actividadEstandarId,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'tecnico_responsable_id': tecnicoResponsableId,
      'observaciones': observaciones,
      'is_master': isMaster ? 1 : 0,
    };
  }

  OperacionModel copyWith({
    int? id,
    int? servicioId,
    String? descripcion,
    int? actividadEstandarId,
    String? fechaInicio,
    String? fechaFin,
    int? tecnicoResponsableId,
    String? tecnicoNombre,
    String? observaciones,
    bool? isMaster, // ✅ CORRECCIÓN
  }) {
    return OperacionModel(
      id: id ?? this.id,
      servicioId: servicioId ?? this.servicioId,
      descripcion: descripcion ?? this.descripcion,
      actividadEstandarId: actividadEstandarId ?? this.actividadEstandarId,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      tecnicoResponsableId: tecnicoResponsableId ?? this.tecnicoResponsableId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      observaciones: observaciones ?? this.observaciones,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isMaster: isMaster ?? this.isMaster,
    );
  }
}
