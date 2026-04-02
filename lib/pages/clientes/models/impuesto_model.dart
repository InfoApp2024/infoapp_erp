class ImpuestoModel {
  final int? id;
  final String nombreImpuesto;
  final String tipoImpuesto;
  final double porcentaje;
  final double baseMinimaPesos;
  final String? descripcion;
  final bool activo; // estado: 1 = true, 0 = false

  ImpuestoModel({
    this.id,
    required this.nombreImpuesto,
    required this.tipoImpuesto,
    required this.porcentaje,
    required this.baseMinimaPesos,
    this.descripcion,
    this.activo = true,
  });

  factory ImpuestoModel.fromJson(Map<String, dynamic> json) {
    return ImpuestoModel(
      id: int.tryParse(json['id'].toString()),
      nombreImpuesto: json['nombre_impuesto'] ?? '',
      tipoImpuesto: json['tipo_impuesto'] ?? 'IVA',
      porcentaje: double.tryParse(json['porcentaje'].toString()) ?? 0.0,
      baseMinimaPesos:
          double.tryParse(json['base_minima_pesos'].toString()) ??
          double.tryParse(json['base_minima_uvt'].toString()) ??
          0.0,
      descripcion: json['descripcion'],
      activo: (int.tryParse(json['estado'].toString()) ?? 1) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_impuesto': nombreImpuesto,
      'tipo_impuesto': tipoImpuesto,
      'porcentaje': porcentaje,
      'base_minima_pesos': baseMinimaPesos,
      'descripcion': descripcion,
      'estado': activo ? 1 : 0,
    };
  }

  ImpuestoModel copyWith({
    int? id,
    String? nombreImpuesto,
    String? tipoImpuesto,
    double? porcentaje,
    double? baseMinimaPesos,
    String? descripcion,
    bool? activo,
  }) {
    return ImpuestoModel(
      id: id ?? this.id,
      nombreImpuesto: nombreImpuesto ?? this.nombreImpuesto,
      tipoImpuesto: tipoImpuesto ?? this.tipoImpuesto,
      porcentaje: porcentaje ?? this.porcentaje,
      baseMinimaPesos: baseMinimaPesos ?? this.baseMinimaPesos,
      descripcion: descripcion ?? this.descripcion,
      activo: activo ?? this.activo,
    );
  }
}
