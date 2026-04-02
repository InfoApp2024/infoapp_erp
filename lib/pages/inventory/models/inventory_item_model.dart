// lib/pages/inventory/models/inventory_item_model.dart

class InventoryItem {
  final int? id;
  final String sku;
  final String name;
  final String? description;
  final int? categoryId;
  final String? categoryName;
  final String itemType;
  final String? brand;
  final String? model;
  final String? partNumber;
  final double currentStock;
  final double minimumStock;
  final double maximumStock;
  final String unitOfMeasure;
  final double initialCost;
  final double unitCost;
  final double averageCost;
  final double lastCost;
  final String? location;
  final String? shelf;
  final String? bin;
  final String? barcode;
  final String? qrCode;
  final int? supplierId;
  final String? supplierName;
  final bool isActive;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Campos calculados
  final double? stockValue;
  final bool? isLowStock;
  final DateTime? lastMovementDate;
  final int? recentMovements;
  final String? alertLevel;
  final double? priorityScore;

  const InventoryItem({
    this.id,
    required this.sku,
    required this.name,
    this.description,
    this.categoryId,
    this.categoryName,
    required this.itemType,
    this.brand,
    this.model,
    this.partNumber,
    this.currentStock = 0,
    this.minimumStock = 0,
    this.maximumStock = 0,
    this.unitOfMeasure = 'unidad',
    this.initialCost = 0.0,
    this.unitCost = 0.0,
    this.averageCost = 0.0,
    this.lastCost = 0.0,
    this.location,
    this.shelf,
    this.bin,
    this.barcode,
    this.qrCode,
    this.supplierId,
    this.supplierName,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.stockValue,
    this.isLowStock,
    this.lastMovementDate,
    this.recentMovements,
    this.alertLevel,
    this.priorityScore,
  });

  // Factory constructor para crear desde JSON (API response)
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as int?,
      sku: json['sku'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      itemType: json['item_type'] as String,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      partNumber: json['part_number'] as String?,
      currentStock: _parseDouble(json['current_stock']),
      minimumStock: _parseDouble(json['minimum_stock']),
      maximumStock: _parseDouble(json['maximum_stock']),
      unitOfMeasure: json['unit_of_measure'] as String? ?? 'unidad',
      initialCost: _parseDouble(json['initial_cost']),
      unitCost: _parseDouble(json['unit_cost']),
      averageCost: _parseDouble(json['average_cost']),
      lastCost: _parseDouble(json['last_cost']),
      location: json['location'] as String?,
      shelf: json['shelf'] as String?,
      bin: json['bin'] as String?,
      barcode: json['barcode'] as String?,
      qrCode: json['qr_code'] as String?,
      supplierId: json['supplier_id'] as int?,
      supplierName: json['supplier_name'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdBy: json['created_by'] as int?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
      stockValue: (json['stock_value'] as num?)?.toDouble(),
      isLowStock: json['is_low_stock'] == 1 || json['is_low_stock'] == true,
      lastMovementDate:
          json['last_movement_date'] != null
              ? DateTime.tryParse(json['last_movement_date'].toString())
              : null,
      recentMovements: (json['recent_movements'] as num?)?.toInt(),
      alertLevel: json['alert_level'] as String?,
      priorityScore: (json['priority_score'] as num?)?.toDouble(),
    );
  }

  // Convertir a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'sku': sku,
      'name': name,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      'item_type': itemType,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (partNumber != null) 'part_number': partNumber,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'unit_of_measure': unitOfMeasure,
      'initial_cost': initialCost,
      'unit_cost': unitCost,
      'average_cost': averageCost,
      'last_cost': lastCost,
      if (location != null) 'location': location,
      if (shelf != null) 'shelf': shelf,
      if (bin != null) 'bin': bin,
      if (barcode != null) 'barcode': barcode,
      if (qrCode != null) 'qr_code': qrCode,
      if (supplierId != null) 'supplier_id': supplierId,
      'is_active': isActive,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  // Crear copia con valores modificados
  InventoryItem copyWith({
    int? id,
    String? sku,
    String? name,
    String? description,
    int? categoryId,
    String? categoryName,
    String? itemType,
    String? brand,
    String? model,
    String? partNumber,
    double? currentStock,
    double? minimumStock,
    double? maximumStock,
    String? unitOfMeasure,
    double? initialCost,
    double? unitCost,
    double? averageCost,
    double? lastCost,
    String? location,
    String? shelf,
    String? bin,
    String? barcode,
    String? qrCode,
    int? supplierId,
    String? supplierName,
    bool? isActive,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? stockValue,
    bool? isLowStock,
    DateTime? lastMovementDate,
    int? recentMovements,
    String? alertLevel,
    double? priorityScore,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      itemType: itemType ?? this.itemType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      partNumber: partNumber ?? this.partNumber,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      initialCost: initialCost ?? this.initialCost,
      unitCost: unitCost ?? this.unitCost,
      averageCost: averageCost ?? this.averageCost,
      lastCost: lastCost ?? this.lastCost,
      location: location ?? this.location,
      shelf: shelf ?? this.shelf,
      bin: bin ?? this.bin,
      barcode: barcode ?? this.barcode,
      qrCode: qrCode ?? this.qrCode,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stockValue: stockValue ?? this.stockValue,
      isLowStock: isLowStock ?? this.isLowStock,
      lastMovementDate: lastMovementDate ?? this.lastMovementDate,
      recentMovements: recentMovements ?? this.recentMovements,
      alertLevel: alertLevel ?? this.alertLevel,
      priorityScore: priorityScore ?? this.priorityScore,
    );
  }

  // Métodos de utilidad

  /// Calcula el valor total del stock actual
  double get calculatedStockValue => currentStock * unitCost;

  /// Determina si el item tiene stock bajo
  bool get hasLowStock {
    if (minimumStock <= 0) return false;
    return currentStock <= minimumStock;
  }

  /// Determina si el item está sin stock
  bool get isOutOfStock => currentStock <= 0;

  /// Calcula el porcentaje de stock actual vs mínimo
  double get stockPercentage {
    if (minimumStock <= 0) return 100.0;
    return (currentStock / minimumStock) * 100;
  }

  /// Obtiene el nivel de alerta calculado
  String get calculatedAlertLevel {
    if (isOutOfStock) return 'critical';
    if (hasLowStock) return 'low';
    if (minimumStock > 0 && currentStock <= (minimumStock * 1.5)) {
      return 'moderate';
    }
    return 'normal';
  }

  /// Obtiene el color asociado al nivel de alerta
  String get alertColor {
    switch (calculatedAlertLevel) {
      case 'critical':
        return '#F44336'; // Rojo
      case 'low':
        return '#FF9800'; // Naranja
      case 'moderate':
        return '#FFC107'; // Amarillo
      default:
        return '#4CAF50'; // Verde
    }
  }

  /// Formatea la ubicación completa
  String get fullLocation {
    List<String> locationParts = [];
    if (location != null && location!.isNotEmpty) {
      locationParts.add(location!);
    }
    if (shelf != null && shelf!.isNotEmpty) {
      locationParts.add('Estante: ${shelf!}');
    }
    if (bin != null && bin!.isNotEmpty) {
      locationParts.add('Bin: ${bin!}');
    }
    return locationParts.isEmpty
        ? 'Ubicación no definida'
        : locationParts.join(' - ');
  }

  /// Obtiene el texto descriptivo del tipo de item
  String get itemTypeDisplayName {
    switch (itemType.toLowerCase()) {
      case 'repuesto':
        return 'Repuesto';
      case 'insumo':
        return 'Insumo';
      case 'herramienta':
        return 'Herramienta';
      case 'consumible':
        return 'Consumible';
      default:
        return itemType;
    }
  }

  /// Genera un resumen del item para búsqueda
  String get searchableText {
    return [
      sku,
      name,
      description ?? '',
      brand ?? '',
      model ?? '',
      partNumber ?? '',
      categoryName ?? '',
      supplierName ?? '',
    ].where((text) => text.isNotEmpty).join(' ').toLowerCase();
  }

  @override
  String toString() {
    return 'InventoryItem(id: $id, sku: $sku, name: $name, currentStock: $currentStock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryItem && other.id == id && other.sku == sku;
  }

  @override
  int get hashCode => Object.hash(id, sku);

  // Helpers para parseo seguro
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

}

// Enum para tipos de items
enum ItemType {
  repuesto('repuesto', 'Repuesto'),
  insumo('insumo', 'Insumo'),
  herramienta('herramienta', 'Herramienta'),
  consumible('consumible', 'Consumible');

  const ItemType(this.value, this.displayName);
  final String value;
  final String displayName;

  static ItemType fromString(String value) {
    return ItemType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => ItemType.repuesto,
    );
  }
}

// Enum para niveles de alerta
enum AlertLevel {
  critical('critical', 'Crítico', '#F44336'),
  low('low', 'Bajo', '#FF9800'),
  moderate('moderate', 'Moderado', '#FFC107'),
  normal('normal', 'Normal', '#4CAF50');

  const AlertLevel(this.value, this.displayName, this.color);
  final String value;
  final String displayName;
  final String color;

  static AlertLevel fromString(String value) {
    return AlertLevel.values.firstWhere(
      (level) => level.value == value.toLowerCase(),
      orElse: () => AlertLevel.normal,
    );
  }
}

// Clase para respuesta de la API con paginación
class InventoryItemResponse {
  final List<InventoryItem> items;
  final int totalRecords;
  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final Map<String, dynamic>? summary;
  final Map<String, dynamic>? filters;

  const InventoryItemResponse({
    required this.items,
    required this.totalRecords,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    this.summary,
    this.filters,
  });

  factory InventoryItemResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pagination = json['pagination'] as Map<String, dynamic>;

    return InventoryItemResponse(
      items:
          (data['items'] as List<dynamic>)
              .map(
                (item) => InventoryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      totalRecords: pagination['total_records'] as int,
      currentPage: pagination['current_page'] as int,
      totalPages: pagination['total_pages'] as int,
      hasNext: pagination['has_next'] as bool,
      hasPrevious: pagination['has_previous'] as bool,
      summary: data['summary'] as Map<String, dynamic>?,
      filters: data['filters_applied'] as Map<String, dynamic>?,
    );
  }
}
