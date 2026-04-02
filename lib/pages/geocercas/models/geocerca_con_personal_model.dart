// lib/pages/geocercas/models/geocerca_con_personal_model.dart

import 'personal_activo_model.dart';

class GeocercaConPersonal {
  final int id;
  final String nombre;
  final double latitud;
  final double longitud;
  final double radio;
  final bool activo;
  final List<PersonalActivo> personalActivo;
  final int cantidadPersonal;

  GeocercaConPersonal({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.radio,
    required this.activo,
    required this.personalActivo,
    required this.cantidadPersonal,
  });

  factory GeocercaConPersonal.fromJson(Map<String, dynamic> json) {
    List<PersonalActivo> personal = [];
    if (json['personal_activo'] != null) {
      personal = (json['personal_activo'] as List)
          .map((p) => PersonalActivo.fromJson(p))
          .toList();
    }

    return GeocercaConPersonal(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? 'Sin nombre',
      latitud: json['latitud'] is double 
        ? json['latitud'] 
        : double.parse(json['latitud'].toString()),
      longitud: json['longitud'] is double 
        ? json['longitud'] 
        : double.parse(json['longitud'].toString()),
      radio: json['radio'] is double 
        ? json['radio'] 
        : double.parse(json['radio'].toString()),
      activo: json['activo'] == true || json['activo'] == 1,
      personalActivo: personal,
      cantidadPersonal: json['cantidad_personal'] is int 
        ? json['cantidad_personal'] 
        : int.parse(json['cantidad_personal'].toString()),
    );
  }

  bool get tienePersonal => cantidadPersonal > 0;
}
