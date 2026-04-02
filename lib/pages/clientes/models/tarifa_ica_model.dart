class TarifaIcaModel {
  final int? id;
  final int ciudadId;
  final double tarifaXMil;
  final double baseMinimaUvt;
  final String? ciudadNombre;

  TarifaIcaModel({
    this.id,
    required this.ciudadId,
    required this.tarifaXMil,
    required this.baseMinimaUvt,
    this.ciudadNombre,
  });

  factory TarifaIcaModel.fromJson(Map<String, dynamic> json) {
    return TarifaIcaModel(
      id: int.tryParse(json['id'].toString()),
      ciudadId: int.tryParse(json['ciudad_id'].toString()) ?? 0,
      tarifaXMil: double.tryParse(json['tarifa_x_mil'].toString()) ?? 0.0,
      baseMinimaUvt: double.tryParse(json['base_minima_uvt'].toString()) ?? 0.0,
      ciudadNombre: json['ciudad_nombre'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ciudad_id': ciudadId,
      'tarifa_x_mil': tarifaXMil,
      'base_minima_uvt': baseMinimaUvt,
    };
  }

  TarifaIcaModel copyWith({
    int? id,
    int? ciudadId,
    double? tarifaXMil,
    double? baseMinimaUvt,
    String? ciudadNombre,
  }) {
    return TarifaIcaModel(
      id: id ?? this.id,
      ciudadId: ciudadId ?? this.ciudadId,
      tarifaXMil: tarifaXMil ?? this.tarifaXMil,
      baseMinimaUvt: baseMinimaUvt ?? this.baseMinimaUvt,
      ciudadNombre: ciudadNombre ?? this.ciudadNombre,
    );
  }
}
