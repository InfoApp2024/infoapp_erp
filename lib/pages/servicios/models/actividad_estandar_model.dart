class ActividadEstandarModel {
  final int? id;
  final String actividad;
  final bool activo;
  final double cantHora;
  final int numTecnicos;
  final int? sistemaId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? sistemaNombre;

  ActividadEstandarModel({
    this.id,
    required this.actividad,
    this.activo = true,
    this.cantHora = 0.0,
    this.numTecnicos = 1,
    this.sistemaId,
    this.createdAt,
    this.updatedAt,
    this.sistemaNombre,
  });

  factory ActividadEstandarModel.fromJson(Map<String, dynamic> json) {
    return ActividadEstandarModel(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id']?.toString() ?? ''),
      actividad: json['actividad'] as String,
      activo:
          json['activo'] == true ||
          json['activo'] == 1 ||
          json['activo'] == '1',
      cantHora: double.tryParse(json['cant_hora']?.toString() ?? '0.0') ?? 0.0,
      numTecnicos: int.tryParse(json['num_tecnicos']?.toString() ?? '1') ?? 1,
      sistemaId:
          json['sistema_id'] is int
              ? json['sistema_id']
              : int.tryParse(json['sistema_id']?.toString() ?? ''),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
      sistemaNombre: json['sistema_nombre'] as String?,
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
      'sistema_nombre': sistemaNombre,
    };
  }

  ActividadEstandarModel copyWith({
    int? id,
    String? actividad,
    bool? activo,
    double? cantHora,
    int? numTecnicos,
    int? sistemaId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sistemaNombre,
  }) {
    return ActividadEstandarModel(
      id: id ?? this.id,
      actividad: actividad ?? this.actividad,
      activo: activo ?? this.activo,
      cantHora: cantHora ?? this.cantHora,
      numTecnicos: numTecnicos ?? this.numTecnicos,
      sistemaId: sistemaId ?? this.sistemaId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sistemaNombre: sistemaNombre ?? this.sistemaNombre,
    );
  }

  @override
  String toString() => actividad;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActividadEstandarModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
