import 'package:flutter/material.dart';

class BrandingModel {
  final String colorPrimario;
  final String colorSecundario;
  final String? logoUrl;
  final String nombreEmpresa;
  final bool configuracionCargada;
  final bool verTiempos; // NUEVO: Habilitar trazabilidad de tiempos

  BrandingModel({
    required this.colorPrimario,
    required this.colorSecundario,
    this.logoUrl,
    required this.nombreEmpresa,
    this.configuracionCargada = true,
    this.verTiempos = false,
  });

  factory BrandingModel.fromJson(Map<String, dynamic> json) {
    return BrandingModel(
      colorPrimario: json['color_primario']?.toString() ?? '#2196F3',
      colorSecundario: json['color_secundario']?.toString() ?? '#FFC107',
      logoUrl: json['logo_url']?.toString(),
      nombreEmpresa: json['nombre_empresa']?.toString() ?? 'Mi Aplicación',
      configuracionCargada: json['configuracion_cargada'] ?? true,
      verTiempos: json['ver_tiempos'] == true || json['ver_tiempos'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color_primario': colorPrimario,
      'color_secundario': colorSecundario,
      'logo_url': logoUrl,
      'nombre_empresa': nombreEmpresa,
      'configuracion_cargada': configuracionCargada,
      'ver_tiempos': verTiempos,
    };
  }

  Color get primaryColor {
    try {
      final hex = colorPrimario.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (e) {
      return Colors.blue;
    }
  }

  Color get secondaryColor {
    try {
      final hex = colorSecundario.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (e) {
      return Colors.orange;
    }
  }

  static BrandingModel porDefecto() {
    return BrandingModel(
      colorPrimario: '#2196F3',
      colorSecundario: '#FFC107',
      logoUrl: null,
      nombreEmpresa: 'Mi Aplicación',
      configuracionCargada: false,
      verTiempos: false,
    );
  }
}
