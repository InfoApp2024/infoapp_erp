// lib/pages/inventory/models/inventory_response_models.dart

import 'inventory_category_model.dart';
import 'inventory_supplier_model.dart';
import 'inventory_item_model.dart';

// === RESPUESTAS DE ITEMS ===

class InventoryItemDetailResponse {
  final InventoryItem item;
  final Map<String, dynamic>? movementStats;
  final List<Map<String, dynamic>>? movements;
  final List<Map<String, dynamic>>? relatedServices;

  const InventoryItemDetailResponse({
    required this.item,
    this.movementStats,
    this.movements,
    this.relatedServices,
  });

  factory InventoryItemDetailResponse.fromJson(Map<String, dynamic> json) {
    return InventoryItemDetailResponse(
      item: InventoryItem.fromJson(json['item']),
      movementStats: json['movement_stats'] as Map<String, dynamic>?,
      movements:
          json['movements'] != null
              ? List<Map<String, dynamic>>.from(json['movements'])
              : null,
      relatedServices:
          json['related_services'] != null
              ? List<Map<String, dynamic>>.from(json['related_services'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'movement_stats': movementStats,
      'movements': movements,
      'related_services': relatedServices,
    };
  }
}

// === RESPUESTAS DE CATEGORÍAS ===

class InventoryCategoryResponse {
  final List<InventoryCategory> categories;
  final int totalRecords;
  final Map<String, dynamic>? hierarchy;
  final Map<String, dynamic>? summary;

  const InventoryCategoryResponse({
    required this.categories,
    required this.totalRecords,
    this.hierarchy,
    this.summary,
  });

  factory InventoryCategoryResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    return InventoryCategoryResponse(
      categories:
          (data['categories'] as List<dynamic>)
              .map(
                (category) => InventoryCategory.fromJson(
                  category as Map<String, dynamic>,
                ),
              )
              .toList(),
      totalRecords: data['total_records'] as int? ?? 0,
      hierarchy: data['hierarchy'] as Map<String, dynamic>?,
      summary: data['summary'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((e) => e.toJson()).toList(),
      'total_records': totalRecords,
      'hierarchy': hierarchy,
      'summary': summary,
    };
  }
}

// === RESPUESTAS DE PROVEEDORES ===

class InventorySupplierResponse {
  final List<InventorySupplier> suppliers;
  final int totalRecords;
  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final Map<String, dynamic>? summary;

  const InventorySupplierResponse({
    required this.suppliers,
    required this.totalRecords,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    this.summary,
  });

  factory InventorySupplierResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return InventorySupplierResponse(
      suppliers:
          (data['suppliers'] as List<dynamic>)
              .map(
                (supplier) => InventorySupplier.fromJson(
                  supplier as Map<String, dynamic>,
                ),
              )
              .toList(),
      totalRecords: pagination['total_records'] as int? ?? 0,
      currentPage: pagination['current_page'] as int? ?? 1,
      totalPages: pagination['total_pages'] as int? ?? 1,
      hasNext: pagination['has_next'] as bool? ?? false,
      hasPrevious: pagination['has_previous'] as bool? ?? false,
      summary: data['summary'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'suppliers': suppliers.map((e) => e.toJson()).toList(),
      'total_records': totalRecords,
      'current_page': currentPage,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_previous': hasPrevious,
      'summary': summary,
    };
  }
}

// === RESPUESTAS DE VERIFICACIÓN SKU ===

class SkuCheckResponse {
  final String sku;
  final bool isAvailable;
  final DateTime checkedAt;
  final Map<String, dynamic>? existingItem;
  final List<Map<String, dynamic>>? suggestedAlternatives;
  final int similarSkusCount;

  const SkuCheckResponse({
    required this.sku,
    required this.isAvailable,
    required this.checkedAt,
    this.existingItem,
    this.suggestedAlternatives,
    required this.similarSkusCount,
  });

  factory SkuCheckResponse.fromJson(Map<String, dynamic> json) {
    return SkuCheckResponse(
      sku: json['sku'] as String,
      isAvailable: json['is_available'] as bool,
      checkedAt: DateTime.parse(json['checked_at'] as String),
      existingItem: json['existing_item'] as Map<String, dynamic>?,
      suggestedAlternatives:
          json['suggested_alternatives'] != null
              ? List<Map<String, dynamic>>.from(json['suggested_alternatives'])
              : null,
      similarSkusCount: json['similar_skus_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'is_available': isAvailable,
      'checked_at': checkedAt.toIso8601String(),
      'existing_item': existingItem,
      'suggested_alternatives': suggestedAlternatives,
      'similar_skus_count': similarSkusCount,
    };
  }
}

// === RESPUESTAS DE MOVIMIENTOS ===

class MovementResponse {
  final Map<String, dynamic> movement;
  final Map<String, dynamic> stockUpdate;
  final List<Map<String, dynamic>> alerts;

  const MovementResponse({
    required this.movement,
    required this.stockUpdate,
    required this.alerts,
  });

  factory MovementResponse.fromJson(Map<String, dynamic> json) {
    return MovementResponse(
      movement: json['movement'] as Map<String, dynamic>? ?? {},
      stockUpdate: json['stock_update'] as Map<String, dynamic>? ?? {},
      alerts: List<Map<String, dynamic>>.from(json['alerts'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movement': movement,
      'stock_update': stockUpdate,
      'alerts': alerts,
    };
  }
}

class MovementListResponse {
  final List<Map<String, dynamic>> movements;
  final String displayMode;
  final Map<String, dynamic> appliedFilters;
  final Map<String, dynamic>? summary;

  const MovementListResponse({
    required this.movements,
    required this.displayMode,
    required this.appliedFilters,
    this.summary,
  });

  factory MovementListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return MovementListResponse(
      movements: List<Map<String, dynamic>>.from(data['movements'] ?? []),
      displayMode: data['display_mode'] as String? ?? 'list',
      appliedFilters: data['applied_filters'] as Map<String, dynamic>? ?? {},
      summary: data['summary'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movements': movements,
      'display_mode': displayMode,
      'applied_filters': appliedFilters,
      'summary': summary,
    };
  }
}

// === RESPUESTAS DE DASHBOARD ===

class DashboardStats {
  final String period;
  final DateTime generatedAt;
  final Map<String, dynamic> generalStats;
  final Map<String, dynamic> movementsStats;
  final Map<String, dynamic> alerts;
  final Map<String, dynamic>? charts;
  final Map<String, dynamic>? trends;

  const DashboardStats({
    required this.period,
    required this.generatedAt,
    required this.generalStats,
    required this.movementsStats,
    required this.alerts,
    this.charts,
    this.trends,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;

    return DashboardStats(
      period: data['period'] as String? ?? 'month',
      generatedAt:
          data['generated_at'] != null
              ? DateTime.parse(data['generated_at'] as String)
              : DateTime.now(),
      generalStats: data['general_stats'] as Map<String, dynamic>? ?? data,
      movementsStats: data['movements_stats'] as Map<String, dynamic>? ?? data,
      alerts: data['alerts'] as Map<String, dynamic>? ?? data,
      charts: data['charts'] as Map<String, dynamic>?,
      trends: data['trends'] as Map<String, dynamic>?,
    );
  }

  // ✅ PROPIEDADES CORREGIDAS - Acceso directo a los datos del endpoint
  int get totalProducts {
    // Buscar en varios lugares posibles
    return (generalStats['total_items'] as int?) ??
        (generalStats['total_products'] as int?) ??
        0;
  }

  int get activeProducts {
    return (generalStats['active_items'] as int?) ??
        (generalStats['active_products'] as int?) ??
        0;
  }

  int get lowStockItems {
    return (generalStats['low_stock_items'] as int?) ??
        (alerts['low_stock_count'] as int?) ??
        0;
  }

  int get outOfStockItems {
    return (generalStats['no_stock_items'] as int?) ??
        (alerts['out_of_stock_count'] as int?) ??
        0;
  }

  double get totalInventoryValue {
    return (generalStats['total_inventory_value'] as num?)?.toDouble() ?? 0.0;
  }

  int get totalCategories {
    return (generalStats['total_categories'] as int?) ?? 0;
  }

  int get totalSuppliers {
    return (generalStats['total_suppliers'] as int?) ?? 0;
  }

  int get todayMovements {
    return (movementsStats['total_movements'] as int?) ??
        (generalStats['total_movements'] as int?) ??
        0;
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'generated_at': generatedAt.toIso8601String(),
      'general_stats': generalStats,
      'movements_stats': movementsStats,
      'alerts': alerts,
      'charts': charts,
      'trends': trends,
    };
  }
}

// === RESPUESTAS DE STOCK BAJO ===

class LowStockResponse {
  final List<LowStockItem> items;
  final LowStockSummary summary;
  final Map<String, dynamic> analysisSettings;

  const LowStockResponse({
    required this.items,
    required this.summary,
    required this.analysisSettings,
  });

  factory LowStockResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    return LowStockResponse(
      items:
          (data['items'] as List<dynamic>?)
              ?.map(
                (item) => LowStockItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      summary: LowStockSummary.fromJson(
        data['summary'] as Map<String, dynamic>? ?? {},
      ),
      analysisSettings:
          data['analysis_settings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'summary': summary.toJson(),
      'analysis_settings': analysisSettings,
    };
  }
}

class LowStockItem {
  final int id;
  final String name;
  final String sku;
  final int currentStock;
  final int minimumStock;
  final int? maximumStock;
  final String priority;
  final int? projectedRunoutDays;
  final double? averageDailyUsage;
  final String? categoryName;
  final String? supplierName;

  const LowStockItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.currentStock,
    required this.minimumStock,
    this.maximumStock,
    required this.priority,
    this.projectedRunoutDays,
    this.averageDailyUsage,
    this.categoryName,
    this.supplierName,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) {
    return LowStockItem(
      id: json['id'] as int,
      name: json['name'] as String,
      sku: json['sku'] as String,
      currentStock: json['current_stock'] as int? ?? 0,
      minimumStock: json['minimum_stock'] as int? ?? 0,
      maximumStock: json['maximum_stock'] as int?,
      priority: json['priority'] as String? ?? 'medium',
      projectedRunoutDays: json['projected_runout_days'] as int?,
      averageDailyUsage: (json['average_daily_usage'] as num?)?.toDouble(),
      categoryName: json['category_name'] as String?,
      supplierName: json['supplier_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'priority': priority,
      'projected_runout_days': projectedRunoutDays,
      'average_daily_usage': averageDailyUsage,
      'category_name': categoryName,
      'supplier_name': supplierName,
    };
  }
}

class LowStockSummary {
  final int totalLowStockItems;
  final int criticalItems;
  final int warningItems;
  final double totalAffectedValue;
  final int estimatedRestockCost;

  const LowStockSummary({
    required this.totalLowStockItems,
    required this.criticalItems,
    required this.warningItems,
    required this.totalAffectedValue,
    required this.estimatedRestockCost,
  });

  factory LowStockSummary.fromJson(Map<String, dynamic> json) {
    return LowStockSummary(
      totalLowStockItems: json['total_low_stock_items'] as int? ?? 0,
      criticalItems: json['critical_items'] as int? ?? 0,
      warningItems: json['warning_items'] as int? ?? 0,
      totalAffectedValue:
          (json['total_affected_value'] as num?)?.toDouble() ?? 0.0,
      estimatedRestockCost: json['estimated_restock_cost'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_low_stock_items': totalLowStockItems,
      'critical_items': criticalItems,
      'warning_items': warningItems,
      'total_affected_value': totalAffectedValue,
      'estimated_restock_cost': estimatedRestockCost,
    };
  }
}

// === CLASES AUXILIARES ===

class StockRecommendation {
  final int itemId;
  final String itemName;
  final String recommendationType;
  final int suggestedQuantity;
  final String reason;
  final double? estimatedCost;
  final int? priority;

  const StockRecommendation({
    required this.itemId,
    required this.itemName,
    required this.recommendationType,
    required this.suggestedQuantity,
    required this.reason,
    this.estimatedCost,
    this.priority,
  });

  factory StockRecommendation.fromJson(Map<String, dynamic> json) {
    return StockRecommendation(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String,
      recommendationType: json['recommendation_type'] as String,
      suggestedQuantity: json['suggested_quantity'] as int,
      reason: json['reason'] as String,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      priority: json['priority'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'recommendation_type': recommendationType,
      'suggested_quantity': suggestedQuantity,
      'reason': reason,
      'estimated_cost': estimatedCost,
      'priority': priority,
    };
  }
}
