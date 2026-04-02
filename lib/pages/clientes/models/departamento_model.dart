class DepartamentoModel {
  final int id;
  final String nombre;

  const DepartamentoModel({required this.id, required this.nombre});

  factory DepartamentoModel.fromJson(Map<String, dynamic> json) {
    return DepartamentoModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nombre': nombre};
  }

  @override
  String toString() => nombre;
}
