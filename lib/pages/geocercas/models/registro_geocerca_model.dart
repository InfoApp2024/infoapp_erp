class RegistroGeocerca {
  final int id;
  final int geocercaId;
  final int usuarioId;
  final DateTime fechaIngreso;
  final DateTime? fechaSalida;
  final String? nombreGeocerca;
  final String? nombreUsuario;
  final String? duracion;
  final String? observaciones;
  final String? fotoIngreso;
  final String? fotoSalida;
  final DateTime? fechaCapturaIngreso;
  final DateTime? fechaCapturaSalida;

  RegistroGeocerca({
    required this.id,
    required this.geocercaId,
    required this.usuarioId,
    required this.fechaIngreso,
    this.fechaSalida,
    this.nombreGeocerca,
    this.nombreUsuario,
    this.duracion,
    this.observaciones,
    this.fotoIngreso,
    this.fotoSalida,
    this.fechaCapturaIngreso,
    this.fechaCapturaSalida,
  });

  factory RegistroGeocerca.fromJson(Map<String, dynamic> json) {
    return RegistroGeocerca(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      geocercaId:
          json['geocerca_id'] is int
              ? json['geocerca_id']
              : int.parse(json['geocerca_id'].toString()),
      usuarioId:
          json['usuario_id'] is int
              ? json['usuario_id']
              : int.parse(json['usuario_id'].toString()),
      fechaIngreso: DateTime.parse(json['fecha_ingreso']),
      fechaSalida:
          json['fecha_salida'] != null
              ? DateTime.parse(json['fecha_salida'])
              : null,
      nombreGeocerca: json['nombre_geocerca'],
      nombreUsuario: json['nombre_usuario'],
      duracion: json['duracion'],
      observaciones: json['observaciones'],
      fotoIngreso: json['foto_ingreso'],
      fotoSalida: json['foto_salida'],
      fechaCapturaIngreso:
          json['fecha_captura_ingreso'] != null
              ? DateTime.parse(json['fecha_captura_ingreso'])
              : null,
      fechaCapturaSalida:
          json['fecha_captura_salida'] != null
              ? DateTime.parse(json['fecha_captura_salida'])
              : null,
    );
  }
}
