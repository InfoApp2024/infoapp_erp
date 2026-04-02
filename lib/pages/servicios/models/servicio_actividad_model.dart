import 'actividad_estandar_model.dart';

class ServicioActividadModel {
  final int servicioId;
  final int? actividadId;
  final ActividadEstandarModel? actividad;

  ServicioActividadModel({
    required this.servicioId,
    this.actividadId,
    this.actividad,
  });

  factory ServicioActividadModel.fromJson(Map<String, dynamic> json) {
    return ServicioActividadModel(
      servicioId: json['servicio_id'] as int,
      actividadId: json['actividad_id'] as int?,
      actividad:
          json['actividad'] != null
              ? ActividadEstandarModel.fromJson(json['actividad'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'servicio_id': servicioId, 'actividad_id': actividadId};
  }
}
