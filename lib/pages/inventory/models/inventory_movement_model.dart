// lib/pages/inventory/models/inventory_movement_model.dart

class InventoryMovement {
  final int? id;
  final int inventoryItemId;
  final String movementType; // 'entrada', 'salida', 'ajuste', 'transferencia'
  final String
  movementReason; // 'compra', 'venta', 'uso_servicio', 'devolucion', 'ajuste_inventario', etc.
  final double quantity;
  final double previousStock;
  final double newStock;
  final double? unitCost;
  final double? totalCost;
  final String? referenceType; // 'service', 'purchase', 'manual', 'adjustment'
  final int? referenceId;
  final String? notes;
  final String? documentNumber;
  final int? createdBy;
  final DateTime? createdAt;

  // Campos adicionales del item (para display)
  final String? itemName;
  final String? itemSku;
  final String? unitOfMeasure;
  final String? createdByName;

  const InventoryMovement({
    this.id,
    required this.inventoryItemId,
    required this.movementType,
    required this.movementReason,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.unitCost,
    this.totalCost,
    this.referenceType,
    this.referenceId,
    this.notes,
    this.documentNumber,
    this.createdBy,
    this.createdAt,
    this.itemName,
    this.itemSku,
    this.unitOfMeasure,
    this.createdByName,
  });

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    return InventoryMovement(
      id: json['id'] as int?,
      inventoryItemId: json['inventory_item_id'] as int,
      movementType: json['movement_type'] as String,
      movementReason: json['movement_reason'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      previousStock: (json['previous_stock'] as num).toDouble(),
      newStock: (json['new_stock'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num?)?.toDouble(),
      totalCost: (json['total_cost'] as num?)?.toDouble(),
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as int?,
      notes: json['notes'] as String?,
      documentNumber: json['document_number'] as String?,
      createdBy: json['created_by'] as int?,
      createdAt: _parseDate(json['created_at']),
      itemName: json['item_name'] as String?,
      itemSku: json['item_sku'] as String?,
      unitOfMeasure: json['unit_of_measure'] as String?,
      createdByName: json['created_by_name'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    var dateStr = value.toString();
    if (dateStr.isEmpty) return null;

    try {
      // Normalizar formato (espacio por T)
      if (dateStr.contains(' ')) {
        dateStr = dateStr.replaceFirst(' ', 'T');
      }

      // Si no tiene información de zona horaria (ni Z ni offset), asumir UTC
      if (!dateStr.endsWith('Z') &&
          !dateStr.contains(RegExp(r'[+-]\d{2}:?\d{2}'))) {
        dateStr += 'Z';
      }

      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'inventory_item_id': inventoryItemId,
      'movement_type': movementType,
      'movement_reason': movementReason,
      'quantity': quantity,
      'previous_stock': previousStock,
      'new_stock': newStock,
      if (unitCost != null) 'unit_cost': unitCost,
      if (totalCost != null) 'total_cost': totalCost,
      if (referenceType != null) 'reference_type': referenceType,
      if (referenceId != null) 'reference_id': referenceId,
      if (notes != null) 'notes': notes,
      if (documentNumber != null) 'document_number': documentNumber,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (itemName != null) 'item_name': itemName,
      if (itemSku != null) 'item_sku': itemSku,
      if (unitOfMeasure != null) 'unit_of_measure': unitOfMeasure,
      if (createdByName != null) 'created_by_name': createdByName,
    };
  }

  // Métodos de utilidad

  /// Obtiene el texto descriptivo del tipo de movimiento
  String get movementTypeDisplayName {
    switch (movementType.toLowerCase()) {
      case 'entrada':
        return 'Entrada';
      case 'salida':
        return 'Salida';
      case 'ajuste':
        return 'Ajuste';
      case 'transferencia':
        return 'Transferencia';
      default:
        return movementType;
    }
  }

  /// Obtiene el texto descriptivo de la razón del movimiento
  String get movementReasonDisplayName {
    switch (movementReason.toLowerCase()) {
      case 'compra':
        return 'Compra a proveedor';
      case 'venta':
        return 'Venta a cliente';
      case 'uso_servicio':
        return 'Usado en servicio';
      case 'devolucion':
        return 'Devolución';
      case 'ajuste_inventario':
        return 'Ajuste de inventario';
      case 'ajuste_edicion':
        return 'Ajuste por edición';
      case 'transferencia':
        return 'Transferencia entre ubicaciones';
      case 'daño':
        return 'Pérdida por daño';
      case 'robo':
        return 'Pérdida por robo';
      case 'vencimiento':
        return 'Pérdida por vencimiento';
      default:
        return movementReason.replaceAll('_', ' ');
    }
  }

  /// Obtiene el color asociado al tipo de movimiento
  String get movementColor {
    switch (movementType.toLowerCase()) {
      case 'entrada':
        return '#4CAF50'; // Verde
      case 'salida':
        return '#F44336'; // Rojo
      case 'ajuste':
        return '#2196F3'; // Azul
      case 'transferencia':
        return '#FF9800'; // Naranja
      default:
        return '#757575'; // Gris
    }
  }

  /// Obtiene el icono asociado al tipo de movimiento
  String get movementIcon {
    switch (movementType.toLowerCase()) {
      case 'entrada':
        return 'add';
      case 'salida':
        return 'remove';
      case 'ajuste':
        return 'tune';
      case 'transferencia':
        return 'swap_horiz';
      default:
        return 'help';
    }
  }

  /// Calcula la diferencia de stock
  double get stockDifference => newStock - previousStock;

  /// Determina si es un movimiento positivo (aumenta stock)
  bool get isPositiveMovement => stockDifference > 0;

  /// Determina si es un movimiento negativo (disminuye stock)
  bool get isNegativeMovement => stockDifference < 0;

  /// Obtiene el texto del cambio de stock con formato
  String get stockChangeText {
    final diff = stockDifference;

    // Función local para formatear números eliminando .0 si es entero
    String formatNumber(double value) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
      return value.toString();
    }

    if (diff > 0) {
      return '+${formatNumber(diff)}';
    } else if (diff < 0) {
      return formatNumber(diff); // El signo negativo ya está incluido
    } else {
      return '±0';
    }
  }

  /// Obtiene el texto completo del movimiento para mostrar
  String get movementSummary {
    return '$movementTypeDisplayName: $stockChangeText ${unitOfMeasure ?? 'unidades'}';
  }

  /// Formatea la fecha de creación
  String get formattedCreatedAt {
    if (createdAt == null) return 'Fecha no disponible';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(createdAt!.year, createdAt!.month, createdAt!.day);
    final daysDiff = today.difference(date).inDays;
    final timeDiff = now.difference(createdAt!);

    if (daysDiff == 0) {
      if (timeDiff.inMinutes < 1) {
        return 'Hace un momento';
      } else if (timeDiff.inHours < 1) {
        return 'Hace ${timeDiff.inMinutes} minutos';
      } else {
        return 'Hace ${timeDiff.inHours} horas';
      }
    } else if (daysDiff == 1) {
      return 'Ayer';
    } else if (daysDiff < 7) {
      return 'Hace $daysDiff días';
    } else {
      return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
    }
  }

  @override
  String toString() {
    return 'InventoryMovement(id: $id, type: $movementType, quantity: $quantity, item: $inventoryItemId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryMovement &&
        other.id == id &&
        other.inventoryItemId == inventoryItemId;
  }

  @override
  int get hashCode => Object.hash(id, inventoryItemId);
}

// Enums para tipos de movimiento
enum MovementType {
  entrada('entrada', 'Entrada'),
  salida('salida', 'Salida'),
  ajuste('ajuste', 'Ajuste'),
  transferencia('transferencia', 'Transferencia');

  const MovementType(this.value, this.displayName);
  final String value;
  final String displayName;

  static MovementType fromString(String value) {
    return MovementType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => MovementType.ajuste,
    );
  }
}

// Enums para razones de movimiento
enum MovementReason {
  compra('compra', 'Compra a proveedor'),
  venta('venta', 'Venta a cliente'),
  usoServicio('uso_servicio', 'Usado en servicio'),
  devolucion('devolucion', 'Devolución'),
  ajusteInventario('ajuste_inventario', 'Ajuste de inventario'),
  ajusteEdicion('ajuste_edicion', 'Ajuste por edición'),
  transferencia('transferencia', 'Transferencia'),
  dano('daño', 'Pérdida por daño'),
  robo('robo', 'Pérdida por robo'),
  vencimiento('vencimiento', 'Pérdida por vencimiento');

  const MovementReason(this.value, this.displayName);
  final String value;
  final String displayName;

  static MovementReason fromString(String value) {
    return MovementReason.values.firstWhere(
      (reason) => reason.value == value.toLowerCase(),
      orElse: () => MovementReason.ajusteInventario,
    );
  }

  static List<MovementReason> getByType(MovementType type) {
    switch (type) {
      case MovementType.entrada:
        return [
          MovementReason.compra,
          MovementReason.devolucion,
          MovementReason.ajusteInventario,
        ];
      case MovementType.salida:
        return [
          MovementReason.venta,
          MovementReason.usoServicio,
          MovementReason.dano,
          MovementReason.robo,
          MovementReason.vencimiento,
          MovementReason.devolucion,
        ];
      case MovementType.ajuste:
        return [MovementReason.ajusteInventario, MovementReason.ajusteEdicion];
      case MovementType.transferencia:
        return [MovementReason.transferencia];
    }
  }
}

// Clase para estadísticas de movimientos
class MovementStats {
  final int totalMovements;
  final int totalEntries;
  final int totalExits;
  final int totalAdjustments;
  final double totalValue;
  final DateTime? lastMovementDate;

  const MovementStats({
    required this.totalMovements,
    required this.totalEntries,
    required this.totalExits,
    required this.totalAdjustments,
    required this.totalValue,
    this.lastMovementDate,
  });

  factory MovementStats.fromJson(Map<String, dynamic> json) {
    return MovementStats(
      totalMovements: json['total_movements'] as int? ?? 0,
      totalEntries: json['total_entries'] as int? ?? 0,
      totalExits: json['total_exits'] as int? ?? 0,
      totalAdjustments: json['total_adjustments'] as int? ?? 0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
      lastMovementDate:
          json['last_movement_date'] != null
              ? DateTime.tryParse(json['last_movement_date'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_movements': totalMovements,
      'total_entries': totalEntries,
      'total_exits': totalExits,
      'total_adjustments': totalAdjustments,
      'total_value': totalValue,
      'last_movement_date': lastMovementDate?.toIso8601String(),
    };
  }
}
