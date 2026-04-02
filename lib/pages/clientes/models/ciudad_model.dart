class CiudadModel {
  final int? id;
  final String? codigo;
  final String? nombre;
  final String? departamento;
  final int? departamentoId;

  const CiudadModel({
    this.id,
    this.codigo,
    this.nombre,
    this.departamento,
    this.departamentoId,
  });

  factory CiudadModel.fromJson(Map<String, dynamic> json) {
    return CiudadModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      codigo: json['codigo']?.toString(),
      nombre: json['nombre']?.toString(),
      departamento: json['departamento']?.toString(),
      departamentoId:
          json['departamento_id'] is int
              ? json['departamento_id']
              : int.tryParse(json['departamento_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (codigo != null) 'codigo': codigo,
      if (nombre != null) 'nombre': nombre,
      if (departamento != null) 'departamento': departamento,
    };
  }

  @override
  String toString() => '$nombre, $departamento';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CiudadModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
