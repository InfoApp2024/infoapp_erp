class Plantilla {
  final int? id;
  final String nombre;
  final String modulo; // ✅ NUEVO: Contexto de módulo
  final int? clienteId;
  final String? clienteNombre;
  final bool esGeneral;
  final String contenidoHtml;
  final String? fechaCreacion;
  final String? fechaActualizacion;
  final int? usuarioCreador;
  final String? creadorUsuario;

  Plantilla({
    this.id,
    required this.nombre,
    this.modulo = 'servicios',
    this.clienteId,
    this.clienteNombre,
    required this.esGeneral,
    required this.contenidoHtml,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.usuarioCreador,
    this.creadorUsuario,
  });

  factory Plantilla.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    bool asBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    return Plantilla(
      id: asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      modulo: (json['modulo'] ?? 'servicios').toString(),
      clienteId: asInt(json['cliente_id']),
      clienteNombre: json['cliente_nombre']?.toString(),
      esGeneral: asBool(json['es_general']),
      contenidoHtml: (json['contenido_html'] ?? '').toString(),
      fechaCreacion: json['fecha_creacion']?.toString(),
      fechaActualizacion: json['fecha_actualizacion']?.toString(),
      usuarioCreador: asInt(json['usuario_creador']),
      creadorUsuario: json['creador_usuario']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'modulo': modulo,
      'cliente_id': clienteId,
      'es_general': esGeneral ? 1 : 0,
      'contenido_html': contenidoHtml,
    };
  }

  Plantilla copyWith({
    int? id,
    String? nombre,
    String? modulo,
    int? clienteId,
    String? clienteNombre,
    bool? esGeneral,
    String? contenidoHtml,
    String? fechaCreacion,
    String? fechaActualizacion,
    int? usuarioCreador,
    String? creadorUsuario,
  }) {
    return Plantilla(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      modulo: modulo ?? this.modulo,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      esGeneral: esGeneral ?? this.esGeneral,
      contenidoHtml: contenidoHtml ?? this.contenidoHtml,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      usuarioCreador: usuarioCreador ?? this.usuarioCreador,
      creadorUsuario: creadorUsuario ?? this.creadorUsuario,
    );
  }

  bool get isNew => id == null;

  String get tipoPlantilla => esGeneral ? 'General' : 'Específica';
}
