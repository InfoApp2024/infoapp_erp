class Geocerca {
  final int id;
  final String nombre;
  final double latitud;
  final double longitud;
  final int radio;
  final int estado;

  Geocerca({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.radio,
    required this.estado,
  });

  factory Geocerca.fromJson(Map<String, dynamic> json) {
    return Geocerca(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      latitud:
          json['latitud'] is double
              ? json['latitud']
              : double.parse(json['latitud'].toString()),
      longitud:
          json['longitud'] is double
              ? json['longitud']
              : double.parse(json['longitud'].toString()),
      radio:
          json['radio'] is int
              ? json['radio']
              : int.parse(json['radio'].toString()),
      estado:
          json['estado'] is int
              ? json['estado']
              : int.parse(json['estado'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'latitud': latitud,
      'longitud': longitud,
      'radio': radio,
      'estado': estado,
    };
  }
}
