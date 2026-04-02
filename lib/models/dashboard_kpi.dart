class KpiServicios {
  final List<ChartData> distribucionEstados;
  final List<ChartData> tiposMantenimiento;
  final List<ChartData> cargaTecnicos;
  final List<ChartData> topEquiposCosto; // Nuevo
  final List<ChartData> topRepuestosUso; // Nuevo
  final List<ServicioAnulado> serviciosAnulados; // Nuevo
  final ResumenServicios resumen;

  KpiServicios({
    required this.distribucionEstados,
    required this.tiposMantenimiento,
    required this.cargaTecnicos,
    required this.topEquiposCosto,
    required this.topRepuestosUso,
    required this.serviciosAnulados,
    required this.resumen,
  });

  factory KpiServicios.fromJson(Map<String, dynamic> json) {
    return KpiServicios(
      distribucionEstados:
          (json['distribucion_estados'] as List?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
      tiposMantenimiento:
          (json['tipos_mantenimiento'] as List?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
      cargaTecnicos:
          (json['carga_tecnicos'] as List?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
      topEquiposCosto:
          (json['top_equipos_costo'] as List?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
      topRepuestosUso:
          (json['top_repuestos_uso'] as List?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
      serviciosAnulados:
          (json['servicios_anulados'] as List?)
              ?.map((e) => ServicioAnulado.fromJson(e))
              .toList() ??
          [],
      resumen: ResumenServicios.fromJson(json['resumen'] ?? {}),
    );
  }
}

class ServicioAnulado {
  final int id;
  final int ordenServicio;
  final String motivo;
  final DateTime fecha;
  final String usuario;

  ServicioAnulado({
    required this.id,
    required this.ordenServicio,
    required this.motivo,
    required this.fecha,
    required this.usuario,
  });

  factory ServicioAnulado.fromJson(Map<String, dynamic> json) {
    return ServicioAnulado(
      id: int.tryParse(json['id'].toString()) ?? 0,
      ordenServicio: int.tryParse(json['o_servicio'].toString()) ?? 0,
      motivo: json['motivo'] ?? 'Sin motivo registrado',
      fecha: DateTime.tryParse(json['fecha'].toString()) ?? DateTime.now(),
      usuario: json['usuario'] ?? 'Desconocido',
    );
  }
}

class KpiInventario {
  final ResumenInventario resumen;
  final List<AlertaStock> alertasStock;
  final List<ChartData> distribucionCategorias;

  KpiInventario({
    required this.resumen,
    required this.alertasStock,
    required this.distribucionCategorias,
  });

  factory KpiInventario.fromJson(Map<String, dynamic> json) {
    return KpiInventario(
      resumen: ResumenInventario.fromJson(json['resumen_inventario'] ?? {}),
      alertasStock:
          (json['alertas_stock'] as List?)
              ?.map((e) => AlertaStock.fromJson(e))
              .toList() ??
          [],
      distribucionCategorias:
          (json['distribucion_categorias'] as List?)
              ?.map((e) => ChartData.fromJson(e))
              .toList() ??
          [],
    );
  }
}

// Modelos Auxiliares

class ChartData {
  final String label;
  final double value;
  final String? colorHex;

  ChartData({required this.label, required this.value, this.colorHex});

  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      label: json['label'] ?? 'Sin etiqueta',
      value: double.tryParse(json['value'].toString()) ?? 0.0,
      colorHex: json['color'],
    );
  }
}

class ResumenServicios {
  final int total;
  final int finalizados;
  final int activos;
  final int anulados;

  ResumenServicios({
    required this.total,
    required this.finalizados,
    required this.activos,
    required this.anulados,
  });

  factory ResumenServicios.fromJson(Map<String, dynamic> json) {
    return ResumenServicios(
      total: int.tryParse(json['total_servicios'].toString()) ?? 0,
      finalizados: int.tryParse(json['finalizados'].toString()) ?? 0,
      activos: int.tryParse(json['activos'].toString()) ?? 0,
      anulados: int.tryParse(json['anulados'].toString()) ?? 0,
    );
  }
}

class ResumenInventario {
  final double valorTotal;
  final int totalItems;
  final int totalUnidades;

  ResumenInventario({
    required this.valorTotal,
    required this.totalItems,
    required this.totalUnidades,
  });

  factory ResumenInventario.fromJson(Map<String, dynamic> json) {
    return ResumenInventario(
      valorTotal: double.tryParse(json['valor_total'].toString()) ?? 0.0,
      totalItems: int.tryParse(json['total_items'].toString()) ?? 0,
      totalUnidades: int.tryParse(json['total_unidades'].toString()) ?? 0,
    );
  }
}

class AlertaStock {
  final String name;
  final String sku;
  final double currentStock;
  final double minStock;

  AlertaStock({
    required this.name,
    required this.sku,
    required this.currentStock,
    required this.minStock,
  });

  factory AlertaStock.fromJson(Map<String, dynamic> json) {
    return AlertaStock(
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      currentStock: double.tryParse(json['current_stock'].toString()) ?? 0.0,
      minStock: double.tryParse(json['minimum_stock'].toString()) ?? 0.0,
    );
  }
}
