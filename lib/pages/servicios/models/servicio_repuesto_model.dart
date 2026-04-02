/// ============================================================================
/// ARCHIVO: servicio_repuesto_model.dart
///
/// PROPÓSITO: Modelo de datos que:
/// - Define la relación entre servicios y repuestos de inventario
/// - Maneja serialización/deserialización JSON
/// - Implementa métodos de utilidad y validación
/// - Calcula costos y totales automáticamente
/// - Gestiona el estado de la asignación de repuestos
///
/// USO: Estructura de datos para la tabla relacional servicio_repuestos
///
/// FUNCIÓN: Define la estructura de datos para la relación servicio-inventario.
/// ============================================================================
library;

class ServicioRepuestoModel {
  final int? id;
  final int servicioId;
  final int inventoryItemId;
  final double cantidad;
  final double costoUnitario;
  final String? notas;
  final int? usuarioAsigno;
  final DateTime? fechaAsignacion;
  final int? operacionId;

  // Campos del item de inventario (para mostrar información completa)
  final String? itemSku;
  final String? itemNombre;
  final String? itemDescripcion;
  final String? itemUnidadMedida;
  final String? itemCategoria;
  final String? itemMarca;
  final String? itemModelo;
  final double? itemStockActual;
  final double? itemStockMinimo;
  final String? itemUbicacion;

  const ServicioRepuestoModel({
    this.id,
    required this.servicioId,
    required this.inventoryItemId,
    required this.cantidad,
    this.costoUnitario = 0.0,
    this.notas,
    this.usuarioAsigno,
    this.fechaAsignacion,
    // Campos del item de inventario
    this.itemSku,
    this.itemNombre,
    this.itemDescripcion,
    this.itemUnidadMedida,
    this.itemCategoria,
    this.itemMarca,
    this.itemModelo,
    this.itemStockActual,
    this.itemStockMinimo,
    this.itemUbicacion,
    this.operacionId,
  });

  /// Factory constructor para crear desde JSON (API response)
  factory ServicioRepuestoModel.fromJson(Map<String, dynamic> json) {
    return ServicioRepuestoModel(
      id: _parseToInt(json['id']),
      servicioId: _parseToInt(json['servicio_id']) ?? 0,
      inventoryItemId: _parseToInt(json['inventory_item_id']) ?? 0,
      cantidad:
          _parseToDouble(json['cantidad_decimal']) ??
          _parseToDouble(json['cantidad']) ??
          1.0,
      costoUnitario: _parseToDouble(json['costo_unitario']) ?? 0.0,
      notas: json['notas']?.toString(),
      usuarioAsigno: _parseToInt(json['usuario_asigno']),
      fechaAsignacion:
          json['fecha_asignacion'] != null
              ? DateTime.tryParse(json['fecha_asignacion'].toString())
              : null,
      operacionId: _parseToInt(json['operacion_id']),
      // Campos del item de inventario (si vienen en el JOIN)
      itemSku: json['item_sku']?.toString() ?? json['sku']?.toString(),
      itemNombre: json['item_nombre']?.toString() ?? json['name']?.toString(),
      itemDescripcion:
          json['item_descripcion']?.toString() ??
          json['description']?.toString(),
      itemUnidadMedida:
          json['item_unidad_medida']?.toString() ??
          json['unit_of_measure']?.toString(),
      itemCategoria:
          json['item_categoria']?.toString() ??
          json['category_name']?.toString(),
      itemMarca: json['item_marca']?.toString() ?? json['brand']?.toString(),
      itemModelo: json['item_modelo']?.toString() ?? json['model']?.toString(),
      itemStockActual:
          _parseToDouble(json['item_stock_actual']) ??
          _parseToDouble(json['current_stock']),
      itemStockMinimo:
          _parseToDouble(json['item_stock_minimo']) ??
          _parseToDouble(json['minimum_stock']),
      itemUbicacion:
          json['item_ubicacion']?.toString() ?? json['location']?.toString(),
    );
  }

  /// Convertir a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'servicio_id': servicioId,
      'inventory_item_id': inventoryItemId,
      'cantidad': cantidad,
      'cantidad_decimal': cantidad,
      'costo_unitario': costoUnitario,
      if (notas != null && notas!.isNotEmpty) 'notas': notas,
      if (usuarioAsigno != null) 'usuario_asigno': usuarioAsigno,
      if (fechaAsignacion != null)
        'fecha_asignacion': fechaAsignacion!.toIso8601String(),
      'operacion_id': operacionId,
    };
  }

  /// Crear copia con valores modificados
  ServicioRepuestoModel copyWith({
    int? id,
    int? servicioId,
    int? inventoryItemId,
    double? cantidad,
    double? costoUnitario,
    String? notas,
    int? usuarioAsigno,
    DateTime? fechaAsignacion,
    String? itemSku,
    String? itemNombre,
    String? itemDescripcion,
    String? itemUnidadMedida,
    String? itemCategoria,
    String? itemMarca,
    String? itemModelo,
    double? itemStockActual,
    double? itemStockMinimo,
    String? itemUbicacion,
    int? operacionId,
  }) {
    return ServicioRepuestoModel(
      id: id ?? this.id,
      servicioId: servicioId ?? this.servicioId,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      cantidad: cantidad ?? this.cantidad,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      notas: notas ?? this.notas,
      usuarioAsigno: usuarioAsigno ?? this.usuarioAsigno,
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      operacionId: operacionId ?? this.operacionId,
      itemSku: itemSku ?? this.itemSku,
      itemNombre: itemNombre ?? this.itemNombre,
      itemDescripcion: itemDescripcion ?? this.itemDescripcion,
      itemUnidadMedida: itemUnidadMedida ?? this.itemUnidadMedida,
      itemCategoria: itemCategoria ?? this.itemCategoria,
      itemMarca: itemMarca ?? this.itemMarca,
      itemModelo: itemModelo ?? this.itemModelo,
      itemStockActual: itemStockActual ?? this.itemStockActual,
      itemStockMinimo: itemStockMinimo ?? this.itemStockMinimo,
      itemUbicacion: itemUbicacion ?? this.itemUbicacion,
    );
  }

  // =====================================
  //    GETTERS CALCULADOS
  // =====================================

  /// Calcula el costo total (cantidad * costo unitario)
  double get costoTotal => cantidad * costoUnitario;

  /// Obtiene el nombre completo del item para mostrar
  String get itemNombreCompleto {
    final nombre = itemNombre ?? 'Item #$inventoryItemId';
    final marca = itemMarca;
    final modelo = itemModelo;

    if (marca != null && modelo != null) {
      return '$nombre ($marca - $modelo)';
    } else if (marca != null) {
      return '$nombre ($marca)';
    } else if (modelo != null) {
      return '$nombre - $modelo';
    }

    return nombre;
  }

  /// Obtiene descripción completa del item
  String get itemDescripcionCompleta {
    final List<String> partes = [];

    if (itemDescripcion != null && itemDescripcion!.isNotEmpty) {
      partes.add(itemDescripcion!);
    }

    if (itemSku != null && itemSku!.isNotEmpty) {
      partes.add('SKU: ${itemSku!}');
    }

    if (itemCategoria != null && itemCategoria!.isNotEmpty) {
      partes.add('Cat: ${itemCategoria!}');
    }

    return partes.isEmpty ? 'Sin descripción' : partes.join(' | ');
  }

  /// Obtiene información del stock del item
  String get infoStock {
    if (itemStockActual == null) return 'Stock: N/A';

    final stockTexto = '$itemStockActual ${itemUnidadMedida ?? 'und'}';

    if (itemStockMinimo != null && itemStockActual! <= itemStockMinimo!) {
      return '$stockTexto (BAJO STOCK)';
    }

    return stockTexto;
  }

  /// Determina si el item tiene stock bajo
  bool get tieneStockBajo {
    if (itemStockActual == null || itemStockMinimo == null) return false;
    return itemStockActual! <= itemStockMinimo!;
  }

  /// Obtiene el color de alerta según el stock
  String get colorAlertaStock {
    if (itemStockActual == null) return '#757575'; // Gris
    if (itemStockActual! <= 0) return '#F44336'; // Rojo crítico
    if (tieneStockBajo) return '#FF9800'; // Naranja
    return '#4CAF50'; // Verde
  }

  /// Formatea la fecha de asignación
  String get fechaAsignacionFormateada {
    if (fechaAsignacion == null) return 'No establecida';

    final fecha = fechaAsignacion!;
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// Obtiene resumen para mostrar en listas
  String get resumenParaLista {
    return '$itemNombreCompleto - Cant: $cantidad - Total: \$${costoTotal.toStringAsFixed(2)}';
  }

  /// Determina si la cantidad solicitada es válida según el stock
  bool get cantidadEsValida {
    if (itemStockActual == null) {
      return true; // Si no conocemos el stock, asumimos válido
    }
    return cantidad <= itemStockActual!;
  }

  /// Obtiene mensaje de advertencia si la cantidad no es válida
  String? get mensajeAdvertencia {
    if (cantidadEsValida) return null;

    if (itemStockActual != null) {
      return 'Cantidad solicitada ($cantidad) supera el stock disponible ($itemStockActual)';
    }

    return null;
  }

  // =====================================
  //    VALIDACIONES
  // =====================================

  /// Valida que todos los campos requeridos estén presentes
  List<String> validar() {
    final List<String> errores = [];

    if (servicioId <= 0) {
      errores.add('ID de servicio es requerido');
    }

    if (inventoryItemId <= 0) {
      errores.add('ID de item de inventario es requerido');
    }

    if (cantidad <= 0) {
      errores.add('La cantidad debe ser mayor a 0');
    }

    if (costoUnitario < 0) {
      errores.add('El costo unitario no puede ser negativo');
    }

    // Validar stock disponible si se conoce
    if (!cantidadEsValida) {
      errores.add(mensajeAdvertencia!);
    }

    return errores;
  }

  /// Determina si el modelo es válido
  bool get esValido => validar().isEmpty;

  // =====================================
  //    MÉTODOS AUXILIARES ESTÁTICOS
  // =====================================

  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // =====================================
  //    MÉTODOS DE OBJECT
  // =====================================

  @override
  String toString() {
    return 'ServicioRepuestoModel('
        'id: $id, '
        'servicioId: $servicioId, '
        'inventoryItemId: $inventoryItemId, '
        'cantidad: $cantidad, '
        'costoTotal: ${costoTotal.toStringAsFixed(2)}, '
        'item: $itemNombreCompleto, '
        'operacionId: $operacionId'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServicioRepuestoModel &&
        other.servicioId == servicioId &&
        other.inventoryItemId == inventoryItemId &&
        other.operacionId == operacionId;
  }

  @override
  int get hashCode => Object.hash(servicioId, inventoryItemId, operacionId);
}

// =====================================
//    CLASES AUXILIARES
// =====================================

/// Clase para respuesta de API con lista de repuestos de servicio
class ServicioRepuestosResponse {
  final List<ServicioRepuestoModel> repuestos;
  final double costoTotal;
  final int totalItems;
  final Map<String, dynamic>? resumen;

  const ServicioRepuestosResponse({
    required this.repuestos,
    required this.costoTotal,
    required this.totalItems,
    this.resumen,
  });

  factory ServicioRepuestosResponse.fromJson(Map<String, dynamic> json) {
    final repuestosData = json['repuestos'] as List<dynamic>? ?? [];
    final repuestos =
        repuestosData
            .map(
              (item) =>
                  ServicioRepuestoModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();

    // Aceptar varias posibles claves de total provenientes del backend
    final dynamic totalRaw =
        json['costo_total'] ??
        json['valor_total'] ??
        json['total_costo'] ??
        json['total'] ??
        json['costoTotal'];

    return ServicioRepuestosResponse(
      repuestos: repuestos,
      costoTotal: _parseToDouble(totalRaw) ?? 0.0,
      totalItems: repuestos.length,
      resumen: json['resumen'] as Map<String, dynamic>?,
    );
  }

  static double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      var s = value.trim();
      if (s.isEmpty) return null;

      // Normalizar cadenas con símbolos de moneda, espacios y separadores
      // Ejemplos soportados: "$87,000.00", "87.000,00", "87 000,00", "87000"
      // 1) Eliminar todo excepto dígitos, coma, punto y signo menos
      s = s.replaceAll(RegExp(r"[^0-9,.-]"), "");

      // 2) Resolver separadores: si existen ambos, asumir que el último es el decimal
      final hasComma = s.contains(',');
      final hasDot = s.contains('.');
      if (hasComma && hasDot) {
        final lastComma = s.lastIndexOf(',');
        final lastDot = s.lastIndexOf('.');
        if (lastComma > lastDot) {
          // Coma como decimal: eliminar puntos (miles) y convertir coma a punto
          s = s.replaceAll('.', '');
          s = s.replaceAll(',', '.');
        } else {
          // Punto como decimal: eliminar comas (miles)
          s = s.replaceAll(',', '');
        }
      } else if (hasComma && !hasDot) {
        // Solo coma: tratar como decimal
        s = s.replaceAll(',', '.');
      } else if (!hasComma && hasDot) {
        // Solo punto: ya es decimal, nada que hacer
      }

      return double.tryParse(s);
    }
    return null;
  }
}

/// Clase para datos de asignación de repuestos (para requests)
class AsignarRepuestosRequest {
  final int servicioId;
  final List<RepuestoAsignar> repuestos;
  final String? observaciones;
  final int? usuarioAsigno;

  const AsignarRepuestosRequest({
    required this.servicioId,
    required this.repuestos,
    this.observaciones,
    this.usuarioAsigno,
  });

  Map<String, dynamic> toJson() {
    return {
      'servicio_id': servicioId,
      'repuestos': repuestos.map((r) => r.toJson()).toList(),
      if (observaciones != null && observaciones!.isNotEmpty)
        'observaciones': observaciones,
      if (usuarioAsigno != null) 'usuario_asigno': usuarioAsigno,
    };
  }
}

/// Clase para representar un repuesto a asignar
class RepuestoAsignar {
  final int inventoryItemId;
  final double cantidad;
  final double? costoUnitario;
  final String? notas;
  final int? operacionId;

  const RepuestoAsignar({
    required this.inventoryItemId,
    required this.cantidad,
    this.costoUnitario,
    this.notas,
    this.operacionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'inventory_item_id': inventoryItemId,
      'cantidad': cantidad,
      'cantidad_decimal': cantidad,
      if (costoUnitario != null) 'costo_unitario': costoUnitario,
      if (notas != null && notas!.isNotEmpty) 'notas': notas,
      'operacion_id': operacionId,
    };
  }

  factory RepuestoAsignar.fromServicioRepuesto(ServicioRepuestoModel modelo) {
    return RepuestoAsignar(
      inventoryItemId: modelo.inventoryItemId,
      cantidad: modelo.cantidad,
      costoUnitario: modelo.costoUnitario,
      notas: modelo.notas,
      operacionId: modelo.operacionId,
    );
  }
}
