import 'package:flutter/material.dart';
import 'estado_base_enum.dart';

class EstadoModel {
  final int id;
  final String nombre;
  final String color;
  final String? descripcion;
  final int? orden;
  final bool? esInicial;
  final bool? esFinal;
  
  // ✅ NUEVO: Campos de estado base para semántica de negocio
  final String estadoBaseCodigo;
  final String? estadoBaseNombre;
  final bool bloqueaCierre;

  const EstadoModel({
    required this.id,
    required this.nombre,
    required this.color,
    this.descripcion,
    this.orden,
    this.esInicial,
    this.esFinal,
    this.estadoBaseCodigo = 'ABIERTO', // Default seguro para retrocompatibilidad
    this.estadoBaseNombre,
    this.bloqueaCierre = false,
  });

  factory EstadoModel.fromJson(Map<String, dynamic> json) {
    return EstadoModel(
      id: _parseToInt(json['id']) ?? 0,
      nombre:
          json['nombre_estado']?.toString() ?? json['nombre']?.toString() ?? '',
      color: json['color']?.toString() ?? '#808080',
      descripcion: json['descripcion']?.toString(),
      orden: _parseToInt(json['orden']),
      esInicial: _parseToBool(json['es_inicial']),
      esFinal: _parseToBool(json['es_final']),
      // ✅ NUEVO: Parsear campos de estado base con defaults seguros
      estadoBaseCodigo: json['estado_base_codigo']?.toString() ?? 'ABIERTO',
      estadoBaseNombre: json['estado_base_nombre']?.toString(),
      bloqueaCierre: _parseToBool(json['bloquea_cierre']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_estado': nombre,
      'color': color,
      if (descripcion != null) 'descripcion': descripcion,
      if (orden != null) 'orden': orden,
      if (esInicial != null) 'es_inicial': esInicial == true ? 1 : 0,
      if (esFinal != null) 'es_final': esFinal == true ? 1 : 0,
      // ✅ NUEVO: Incluir campos de estado base en JSON
      'estado_base_codigo': estadoBaseCodigo,
      'bloquea_cierre': bloqueaCierre ? 1 : 0,
    };
  }

  Color get colorWidget {
    try {
      if (!color.startsWith('#') || color.length != 7) {
        return Colors.grey;
      }
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (e) {
      return Colors.grey;
    }
  }

  EstadoModel copyWith({
    int? id,
    String? nombre,
    String? color,
    String? descripcion,
    int? orden,
    bool? esInicial,
    bool? esFinal,
    String? estadoBaseCodigo,
    String? estadoBaseNombre,
    bool? bloqueaCierre,
  }) {
    return EstadoModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
      descripcion: descripcion ?? this.descripcion,
      orden: orden ?? this.orden,
      esInicial: esInicial ?? this.esInicial,
      esFinal: esFinal ?? this.esFinal,
      estadoBaseCodigo: estadoBaseCodigo ?? this.estadoBaseCodigo,
      estadoBaseNombre: estadoBaseNombre ?? this.estadoBaseNombre,
      bloqueaCierre: bloqueaCierre ?? this.bloqueaCierre,
    );
  }

  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _parseToBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return null;
  }

  // ✅ NUEVO: Getter para obtener enum EstadoBase
  EstadoBase get estadoBase => EstadoBase.fromCodigo(estadoBaseCodigo);
  
  // ✅ NUEVO: Helpers de estado base
  bool get esEstadoFinal => estadoBase.esFinal;
  bool get permiteEdicion => estadoBase.permiteEdicion;
  bool get esEstadoActivo => estadoBase.esActivo;

  @override
  String toString() {
    return 'EstadoModel(id: $id, nombre: $nombre, color: $color, estadoBase: ${estadoBase.nombre})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EstadoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
