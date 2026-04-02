class ActividadEstandarModel {
  final int id;
  final String actividad;
  final bool activo;
  final double? cantHora;
  final int? numTecnicos;
  final int? sistemaId; // ✅ NUEVO: Asociación con sistema

  ActividadEstandarModel({
    required this.id,
    required this.actividad,
    required this.activo,
    this.cantHora,
    this.numTecnicos,
    this.sistemaId,
  });

  factory ActividadEstandarModel.fromJson(Map<String, dynamic> json) {
    return ActividadEstandarModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      actividad: json['actividad'] ?? '',
      activo: json['activo'] == true || json['activo'] == 1 || json['activo'] == '1',
      cantHora: json['cant_hora'] != null ? double.tryParse(json['cant_hora'].toString()) : null,
      numTecnicos: json['num_tecnicos'] != null ? int.tryParse(json['num_tecnicos'].toString()) : null,
      sistemaId: json['sistema_id'] != null ? int.tryParse(json['sistema_id'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actividad': actividad,
      'activo': activo,
      'cant_hora': cantHora,
      'num_tecnicos': numTecnicos,
      'sistema_id': sistemaId,
    };
  }
}
