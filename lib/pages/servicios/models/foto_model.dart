import 'package:infoapp/core/env/server_config.dart';

class FotoModel {
  final int id;
  final int servicioId;
  final String tipoFoto;
  final String nombreArchivo;
  final String rutaArchivo;
  final String? descripcion;
  final DateTime fechaSubida;
  final int ordenVisualizacion;

  FotoModel({
    required this.id,
    required this.servicioId,
    required this.tipoFoto,
    required this.nombreArchivo,
    required this.rutaArchivo,
    this.descripcion,
    required this.fechaSubida,
    this.ordenVisualizacion = 0,
  });

  factory FotoModel.fromJson(Map<String, dynamic> json) {
    return FotoModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      servicioId: int.tryParse(json['servicio_id'].toString()) ?? 0,
      tipoFoto: json['tipo_foto']?.toString() ?? '',
      nombreArchivo: json['nombre_archivo']?.toString() ?? '',
      rutaArchivo: json['ruta_archivo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      // ✅ CORRECCIÓN: Agregar ?? '' antes de DateTime.tryParse
      fechaSubida:
          DateTime.tryParse(json['fecha_subida']?.toString() ?? '') ??
          DateTime.now(),
      ordenVisualizacion:
          int.tryParse(json['orden_visualizacion']?.toString() ?? '0') ?? 0,
    );
  }

  String get urlImagen =>
      '${ServerConfig.instance.apiRoot()}/servicio/ver_imagen.php?ruta=$rutaArchivo';

  /// Índice de pareja (si está codificado en la descripción)
  /// Formatos soportados: "[PAIR:3]", "pair=3", "pair: 3"
  int? get pairIndex {
    final desc = descripcion ?? '';
    final re = RegExp(
      r'(?:\[PAIR:(\d+)\]|pair\s*[:=]\s*(\d+))',
      caseSensitive: false,
    );
    final m = re.firstMatch(desc);
    if (m == null) return null;
    final g1 = m.group(1);
    final g2 = m.group(2);
    return int.tryParse(g1 ?? g2 ?? '');
  }

  FotoModel copyWith({
    int? id,
    int? servicioId,
    String? tipoFoto,
    String? nombreArchivo,
    String? rutaArchivo,
    String? descripcion,
    DateTime? fechaSubida,
    int? ordenVisualizacion,
  }) {
    return FotoModel(
      id: id ?? this.id,
      servicioId: servicioId ?? this.servicioId,
      tipoFoto: tipoFoto ?? this.tipoFoto,
      nombreArchivo: nombreArchivo ?? this.nombreArchivo,
      rutaArchivo: rutaArchivo ?? this.rutaArchivo,
      descripcion: descripcion ?? this.descripcion,
      fechaSubida: fechaSubida ?? this.fechaSubida,
      ordenVisualizacion: ordenVisualizacion ?? this.ordenVisualizacion,
    );
  }
}
