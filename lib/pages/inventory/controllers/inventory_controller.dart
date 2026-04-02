// lib/pages/inventory/controllers/inventory_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Importar modelos
import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';
import '../models/inventory_response_models.dart';

// Importar servicios
import '../services/inventory_api_service.dart';

class InventoryController extends ChangeNotifier {
  // === ESTADO INTERNO ===

  // Estado de carga
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;

  // Datos
  List<InventoryItem> _items = [];
  List<InventoryCategory> _categories = [];
  List<InventorySupplier> _suppliers = [];
  DashboardStats? _dashboardStats;
  LowStockResponse? _lowStockData;

  // Filtros y búsqueda
  String _searchQuery = '';
  InventoryFilters _filters = InventoryFilters();

  // Paginación
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  final int _itemsPerPage = 20;
  bool _hasMore = true;

  // Estados de error
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};

  // === GETTERS PÚBLICOS ===

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  bool get hasError => _errorMessage != null;
  bool get hasMore => _hasMore;

  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;

  List<InventoryItem> get items => _items;
  List<InventoryCategory> get categories => _categories;
  List<InventorySupplier> get suppliers => _suppliers;
  DashboardStats? get dashboardStats => _dashboardStats;
  LowStockResponse? get lowStockData => _lowStockData;

  String get searchQuery => _searchQuery;
  InventoryFilters get filters => _filters;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalRecords => _totalRecords;
  int get itemsPerPage => _itemsPerPage;

  // === MÉTODOS DE GESTIÓN DE ESTADO ===

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setLoadingMore(bool loading) {
    if (_isLoadingMore != loading) {
      _isLoadingMore = loading;
      notifyListeners();
    }
  }

  void _setRefreshing(bool refreshing) {
    if (_isRefreshing != refreshing) {
      _isRefreshing = refreshing;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      notifyListeners();
    }
  }

  void _setFieldErrors(Map<String, String> errors) {
    _fieldErrors = errors;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
    _setFieldErrors({});
  }

  // === MÉTODOS PÚBLICOS PRINCIPALES ===

  /// Inicializa el controlador cargando datos básicos
  Future<void> initialize() async {
    await loadCategories();
    await loadSuppliers();
    await loadItems();
  }

  /// Carga la lista de items con filtros actuales
  Future<void> loadItems({bool refresh = false}) async {
    if (refresh) {
      _setRefreshing(true);
      _currentPage = 1;
      _hasMore = true;
    } else {
      _setLoading(true);
    }

    clearError();

    try {
      final response = await InventoryApiService.getItems(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _filters.categoryId,
        itemType: _filters.itemType,
        supplierId: _filters.supplierId,
        lowStock: _filters.stockStatus == StockStatus.low,
        noStock: _filters.stockStatus == StockStatus.empty,
        includeInactive: !_filters.onlyActive,
        limit: _itemsPerPage,
        offset: refresh ? 0 : (_currentPage - 1) * _itemsPerPage,
        sortBy: _filters.sortBy,
        sortOrder: _filters.sortOrder,
      );

      if (response.success && response.data != null) {
        final data = response.data!;

        if (refresh) {
          _items = data.items;
        } else {
          _items.addAll(data.items);
        }

        _totalRecords = data.totalRecords;
        _totalPages = data.totalPages;
        _hasMore = data.hasNext;

        if (!refresh) {
          _currentPage++;
        }
      } else {
        _setError(response.message ?? 'Error al cargar items');
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
    } finally {
      _setLoading(false);
      _setRefreshing(false);
    }
  }

  /// Carga más items (paginación)
  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _setLoadingMore(true);
    clearError();

    try {
      final response = await InventoryApiService.getItems(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _filters.categoryId,
        itemType: _filters.itemType,
        supplierId: _filters.supplierId,
        lowStock: _filters.stockStatus == StockStatus.low,
        noStock: _filters.stockStatus == StockStatus.empty,
        includeInactive: !_filters.onlyActive,
        limit: _itemsPerPage,
        offset: (_currentPage - 1) * _itemsPerPage,
        sortBy: _filters.sortBy,
        sortOrder: _filters.sortOrder,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        _items.addAll(data.items);
        _hasMore = data.hasNext;
        _currentPage++;
      } else {
        _setError(response.message ?? 'Error al cargar más items');
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
    } finally {
      _setLoadingMore(false);
    }
  }

  /// Carga categorías
  Future<void> loadCategories() async {
    try {
      final response = await InventoryApiService.getCategories();

      if (response.success && response.data != null) {
        _categories = response.data!.categories;
        notifyListeners();
      }
    } catch (e) {
      // Error silencioso para categorías, no crítico
      debugPrint('Error loading categories: $e');
    }
  }

  /// Carga proveedores
  Future<void> loadSuppliers() async {
    try {
      final response = await InventoryApiService.getSuppliers();

      if (response.success && response.data != null) {
        _suppliers = response.data!.suppliers;
        notifyListeners();
      }
    } catch (e) {
      // Error silencioso para proveedores, no crítico
      debugPrint('Error loading suppliers: $e');
    }
  }

  /// Obtiene estadísticas del dashboard
  Future<void> loadDashboardStats() async {
    _setLoading(true);
    clearError();

    try {
      final response = await InventoryApiService.getDashboardStats();

      if (response.success && response.data != null) {
        _dashboardStats = response.data!;
      } else {
        _setError(response.message ?? 'Error al cargar estadísticas');
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Obtiene items con stock bajo
  Future<void> loadLowStockItems() async {
    try {
      final response = await InventoryApiService.getLowStockItems();

      if (response.success && response.data != null) {
        _lowStockData = response.data!;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading low stock items: $e');
    }
  }

  // === BÚSQUEDA Y FILTROS ===

  /// Actualiza el término de búsqueda
  void updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _resetPagination();
      loadItems(refresh: true);
    }
  }

  /// Actualiza los filtros
  void updateFilters(InventoryFilters newFilters) {
    _filters = newFilters;
    _resetPagination();
    loadItems(refresh: true);
  }

  /// Limpia filtros y búsqueda
  void clearFiltersAndSearch() {
    _searchQuery = '';
    _filters = InventoryFilters();
    _resetPagination();
    loadItems(refresh: true);
  }

  void _resetPagination() {
    _currentPage = 1;
    _hasMore = true;
    _items.clear();
  }

  // === OPERACIONES CRUD ===

  /// Crea un nuevo item
  Future<bool> createItem(InventoryItem item) async {
    _setLoading(true);
    clearError();

    try {
      final response = await InventoryApiService.createItem(item);

      if (response.success && response.data != null) {
        // Agregar el item al inicio de la lista
        _items.insert(0, response.data!);
        _totalRecords++;
        notifyListeners();
        return true;
      } else {
        _setError(response.message ?? 'Error al crear item');
        return false;
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza un item existente
  Future<bool> updateItem(InventoryItem item) async {
    _setLoading(true);
    clearError();

    try {
      final response = await InventoryApiService.updateItem(item);

      if (response.success && response.data != null) {
        // Actualizar el item en la lista
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _items[index] = response.data!;
          notifyListeners();
        }
        return true;
      } else {
        _setError(response.message ?? 'Error al actualizar item');
        return false;
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Obtiene detalle de un item
  Future<InventoryItemDetailResponse?> getItemDetail({
    int? id,
    String? sku,
  }) async {
    try {
      final response = await InventoryApiService.getItemDetail(
        id: id,
        sku: sku,
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        _setError(response.message ?? 'Error al obtener detalle');
        return null;
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return null;
    }
  }

  /// Verifica disponibilidad de SKU
  Future<SkuCheckResponse?> checkSku(String sku, {int? excludeId}) async {
    try {
      final response = await InventoryApiService.checkSku(
        sku,
        excludeId: excludeId,
        suggestAlternatives: true,
      );

      if (response.success && response.data != null) {
        return response.data!;
      }
      return null;
    } catch (e) {
      debugPrint('Error checking SKU: $e');
      return null;
    }
  }

  /// Crea un movimiento de inventario
  Future<bool> createMovement({
    required int inventoryItemId,
    required String movementType,
    required String movementReason,
    required double quantity,
    double? unitCost,
    String? referenceType,
    int? referenceId,
    String? notes,
    String? documentNumber,
  }) async {
    _setLoading(true);
    clearError();

    try {
      final response = await InventoryApiService.createMovement(
        inventoryItemId: inventoryItemId,
        movementType: movementType,
        movementReason: movementReason,
        quantity: quantity,
        unitCost: unitCost,
        referenceType: referenceType,
        referenceId: referenceId,
        notes: notes,
        documentNumber: documentNumber,
      );

      if (response.success) {
        // Recargar items para actualizar stock
        await loadItems(refresh: true);
        return true;
      } else {
        _setError(response.message ?? 'Error al crear movimiento');
        return false;
      }
    } catch (e) {
      _setError('Error de conexión: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // === MÉTODOS AUXILIARES ===

  /// Busca un item por ID
  InventoryItem? findItemById(int? id) {
    if (id == null) return null;
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Busca un item por SKU
  InventoryItem? findItemBySku(String sku) {
    try {
      return _items.firstWhere((item) => item.sku == sku);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene items por categoría
  List<InventoryItem> getItemsByCategory(int? categoryId) {
    if (categoryId == null) return [];
    return _items.where((item) => item.categoryId == categoryId).toList();
  }

  /// Obtiene items por proveedor
  List<InventoryItem> getItemsBySupplier(int? supplierId) {
    if (supplierId == null) return [];
    return _items.where((item) => item.supplierId == supplierId).toList();
  }

  /// Obtiene items con stock bajo
  List<InventoryItem> getLowStockItems() {
    return _items.where((item) => item.hasLowStock).toList();
  }

  /// Obtiene items sin stock
  List<InventoryItem> getOutOfStockItems() {
    return _items.where((item) => item.isOutOfStock).toList();
  }

  /// Busca una categoría por ID
  InventoryCategory? findCategoryById(int? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Busca un proveedor por ID
  InventorySupplier? findSupplierById(int? id) {
    if (id == null) return null;
    try {
      return _suppliers.firstWhere((sup) => sup.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Calcula el valor total del inventario
  double get totalInventoryValue {
    return _items.fold(0.0, (sum, item) => sum + item.calculatedStockValue);
  }

  /// Obtiene el conteo de items por estado de stock
  Map<String, int> get stockStatusCounts {
    int normal = 0;
    int low = 0;
    int out = 0;

    for (final item in _items) {
      if (item.isOutOfStock) {
        out++;
      } else if (item.hasLowStock) {
        low++;
      } else {
        normal++;
      }
    }

    return {'normal': normal, 'low': low, 'out': out};
  }
}

// === CLASES AUXILIARES ===

/// Clase para manejar filtros de inventario
class InventoryFilters {
  final int? categoryId;
  final int? supplierId;
  final String? itemType;
  final StockStatus? stockStatus;
  final double? priceMin;
  final double? priceMax;
  final int? stockMin;
  final int? stockMax;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool onlyActive;
  final String sortBy;
  final String sortOrder;

  const InventoryFilters({
    this.categoryId,
    this.supplierId,
    this.itemType,
    this.stockStatus,
    this.priceMin,
    this.priceMax,
    this.stockMin,
    this.stockMax,
    this.dateFrom,
    this.dateTo,
    this.onlyActive = true,
    this.sortBy = 'name',
    this.sortOrder = 'ASC',
  });

  /// Crea una copia con valores modificados
  InventoryFilters copyWith({
    int? categoryId,
    int? supplierId,
    String? itemType,
    StockStatus? stockStatus,
    double? priceMin,
    double? priceMax,
    int? stockMin,
    int? stockMax,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? onlyActive,
    String? sortBy,
    String? sortOrder,
  }) {
    return InventoryFilters(
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      itemType: itemType ?? this.itemType,
      stockStatus: stockStatus ?? this.stockStatus,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      stockMin: stockMin ?? this.stockMin,
      stockMax: stockMax ?? this.stockMax,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      onlyActive: onlyActive ?? this.onlyActive,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Verifica si hay filtros activos
  bool get hasActiveFilters {
    return categoryId != null ||
        supplierId != null ||
        itemType != null ||
        stockStatus != null ||
        priceMin != null ||
        priceMax != null ||
        stockMin != null ||
        stockMax != null ||
        dateFrom != null ||
        dateTo != null ||
        !onlyActive;
  }

  /// Convierte a JSON para enviar a la API
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (categoryId != null) json['category_id'] = categoryId;
    if (supplierId != null) json['supplier_id'] = supplierId;
    if (itemType != null) json['item_type'] = itemType;
    if (stockStatus != null) json['stock_status'] = stockStatus!.value;
    if (priceMin != null) json['price_min'] = priceMin;
    if (priceMax != null) json['price_max'] = priceMax;
    if (stockMin != null) json['stock_min'] = stockMin;
    if (stockMax != null) json['stock_max'] = stockMax;
    if (dateFrom != null) json['date_from'] = dateFrom!.toIso8601String();
    if (dateTo != null) json['date_to'] = dateTo!.toIso8601String();
    json['only_active'] = onlyActive;
    json['sort_by'] = sortBy;
    json['sort_order'] = sortOrder;

    return json;
  }
}

/// Enum para estados de stock
enum StockStatus {
  all('all', 'Todos'),
  normal('normal', 'Stock Normal'),
  low('low', 'Stock Bajo'),
  empty('empty', 'Sin Stock');

  const StockStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static StockStatus fromString(String value) {
    return StockStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StockStatus.all,
    );
  }
}
