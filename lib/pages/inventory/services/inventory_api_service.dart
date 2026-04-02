// lib/pages/inventory/services/inventory_api_service.dart

import 'dart:convert';
import 'dart:typed_data'; // ← AGREGAR ESTA LÍNEA
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ✅ NUEVO IMPORT
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart'; // ✅ IMPORTAR AuthService

// Importar los modelos existentes
import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';
import '../models/inventory_response_models.dart';
import '../models/inventory_form_data_models.dart';
import '../models/inventory_movement_model.dart';

/// Opciones de importación
class ImportOptions {
  final bool updateExisting;
  final bool createCategories;
  final bool createSuppliers;
  final String dateFormat;
  final String encoding;
  final bool skipFirstRow;

  const ImportOptions({
    this.updateExisting = false,
    this.createCategories = true,
    this.createSuppliers = true,
    this.dateFormat = 'yyyy-MM-dd',
    this.encoding = 'utf-8',
    this.skipFirstRow = true,
  });

  Map<String, dynamic> toJson() => {
    'update_existing': updateExisting,
    'create_categories': createCategories,
    'create_suppliers': createSuppliers,
    'date_format': dateFormat,
    'encoding': encoding,
    'skip_first_row': skipFirstRow,
  };
}

/// Resultado de importación
class ImportResult {
  final int totalRecords;
  final int successfulImports;
  final int skippedRecords;
  final int errorRecords;
  final List<String> errors;
  final List<InventoryItem> importedItems;

  const ImportResult({
    this.totalRecords = 0,
    this.successfulImports = 0,
    this.skippedRecords = 0,
    this.errorRecords = 0,
    this.errors = const [],
    this.importedItems = const [],
  });

  double get successRate =>
      totalRecords > 0 ? successfulImports / totalRecords : 0.0;

  Map<String, dynamic> toJson() => {
    'total_records': totalRecords,
    'successful_imports': successfulImports,
    'skipped_records': skippedRecords,
    'error_records': errorRecords,
    'errors': errors,
    'success_rate': successRate,
  };
}

class InventoryApiService {
  static String get _baseUrl => ServerConfig.instance.baseUrlFor('inventory');
  static const Duration _timeout = Duration(seconds: 30);

  // Headers por defecto
  static Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  // ✅ NUEVO: Método para activar/inactivar items
  static Future<ApiResponse<InventoryItem>> toggleItemStatus({
    required int itemId,
    required bool isActive,
    String? reason,
  }) async {
    try {
      //       print('🔄 Cambiando estado de item ID: $itemId a ${isActive ? 'ACTIVO' : 'INACTIVO'}');

      // ✅ PASO 1: Obtener los datos actuales del item
      final itemDetailResponse = await getItemDetail(id: itemId);

      if (!itemDetailResponse.success || itemDetailResponse.data == null) {
        return ApiResponse.error(
          'No se pudo obtener la información del item: ${itemDetailResponse.message}',
        );
      }

      final currentItem = itemDetailResponse.data!.item;

      // ✅ PASO 2: Preparar datos completos para actualización
      final uri = Uri.parse('$_baseUrl/items/update_item.php');

      final requestData = <String, dynamic>{
        'id': itemId,
        // ✅ CAMPOS REQUERIDOS (mantener valores actuales)
        'sku': currentItem.sku,
        'name': currentItem.name,
        'item_type': currentItem.itemType,
        // ✅ CAMBIAR SOLO EL ESTADO
        'is_active': isActive,
        // ✅ MANTENER OTROS CAMPOS IMPORTANTES
        'description': currentItem.description,
        'category_id': currentItem.categoryId,
        'brand': currentItem.brand,
        'model': currentItem.model,
        'part_number': currentItem.partNumber,
        'current_stock': currentItem.currentStock,
        'minimum_stock': currentItem.minimumStock,
        'maximum_stock': currentItem.maximumStock,
        'unit_of_measure': currentItem.unitOfMeasure,
        'unit_cost': currentItem.unitCost,
        'average_cost': currentItem.averageCost,
        'last_cost': currentItem.lastCost,
        'location': currentItem.location,
        'shelf': currentItem.shelf,
        'bin': currentItem.bin,
        'barcode': currentItem.barcode,
        'qr_code': currentItem.qrCode,
        'supplier_id': currentItem.supplierId,
      };

      // Agregar razón si se proporciona
      if (reason != null && reason.isNotEmpty) {
        requestData['update_reason'] = reason;
      }

      // Obtener el usuario actual
      final userId = await _getCurrentUserId();
      if (userId != null) {
        requestData['updated_by'] = userId;
      }

      //       print('🔄 Enviando datos completos para actualización');

      final response = await http
          .put(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            InventoryItem.fromJson(responseData['data']['item']),
            responseData['message'] ??
                'Estado del item actualizado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(
        'Error al cambiar estado del item: ${e.toString()}',
      );
    }
  }

  /// ✅ NUEVO: Obtiene lista de items inactivos
  static Future<ApiResponse<InventoryItemResponse>> getInactiveItems({
    String? search,
    int? categoryId,
    String? itemType,
    int? supplierId,
    int limit = 20,
    int offset = 0,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
  }) async {
    try {
      final queryParams = <String, String>{
        'is_active': 'false', // Solo items inactivos
        'include_inactive': 'true',
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }
      if (itemType != null && itemType.isNotEmpty) {
        queryParams['item_type'] = itemType;
      }
      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/items/get_items.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<InventoryItemResponse>(
        response,
        (data) => InventoryItemResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(
        'Error al obtener items inactivos: ${e.toString()}',
      );
    }
  }

  // ✅ NUEVO: Obtener el usuario_id desde SharedPreferences
  static Future<int?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('usuario_id');
    } catch (e) {
      //       print('Error obteniendo usuario_id: $e');
      return null;
    }
  }

  // ✅ NUEVO: Obtener headers con usuario si está disponible
  static Future<Map<String, String>> _getHeadersWithUser() async {
    final userId = await _getCurrentUserId();
    final headers = await _getAuthHeaders();

    if (userId != null) {
      headers['User-ID'] = userId.toString();
    }

    return headers;
  }

  // === GESTIÓN DE ITEMS ===

  /// Obtiene lista de ubicaciones únicas existentes
  static Future<ApiResponse<List<String>>> getUniqueLocations() async {
    try {
      final uri = Uri.parse('$_baseUrl/items/get_unique_locations.php');

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<List<String>>(
        response,
        (data) => (data['data'] as List).map((e) => e.toString()).toList(),
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener ubicaciones: ${e.toString()}');
    }
  }

  /// Obtiene lista de marcas únicas existentes
  static Future<ApiResponse<List<String>>> getUniqueBrands() async {
    try {
      final uri = Uri.parse('$_baseUrl/items/get_unique_brands.php');

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<List<String>>(
        response,
        (data) => (data['data'] as List).map((e) => e.toString()).toList(),
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener marcas: ${e.toString()}');
    }
  }

  /// Obtiene lista de tipos de items únicos existentes
  static Future<ApiResponse<List<String>>> getUniqueTypes() async {
    try {
      final uri = Uri.parse('$_baseUrl/items/get_unique_types.php');

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<List<String>>(
        response,
        (data) => (data['data'] as List).map((e) => e.toString()).toList(),
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener tipos: ${e.toString()}');
    }
  }

  /// Obtiene lista de categorías únicas existentes en items
  static Future<ApiResponse<List<String>>> getUniqueCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/items/get_unique_categories.php');

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<List<String>>(response, (data) {
        final list = data['data'] as List?;
        return list?.map((e) => e.toString()).toList() ?? [];
      });
    } catch (e) {
      return ApiResponse.error('Error al obtener categorías: ${e.toString()}');
    }
  }

  /// Obtiene lista de items con filtros y paginación
  static Future<ApiResponse<InventoryItemResponse>> getItems({
    String? search,
    int? categoryId,
    String? itemType,
    int? supplierId,
    bool? lowStock,
    bool? noStock,
    bool includeInactive = false,
    int limit = 20,
    int offset = 0,
    String sortBy = 'name',
    String sortOrder = 'ASC',
  }) async {
    try {
      final queryParams = <String, String>{};

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }
      if (itemType != null && itemType.isNotEmpty) {
        queryParams['item_type'] = itemType;
      }
      if (supplierId != null) {
        queryParams['supplier_id'] = supplierId.toString();
      }
      if (lowStock == true) queryParams['low_stock'] = 'true';
      if (noStock == true) queryParams['no_stock'] = 'true';
      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (!includeInactive) {
        queryParams['is_active'] = 'true';
      }
      queryParams['limit'] = limit.toString();
      queryParams['offset'] = offset.toString();
      queryParams['sort_by'] = sortBy;
      queryParams['sort_order'] = sortOrder;

      final uri = Uri.parse(
        '$_baseUrl/items/get_items.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<InventoryItemResponse>(
        response,
        (data) => InventoryItemResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener items: ${e.toString()}');
    }
  }

  /// Obtiene detalle de un item específico
  static Future<ApiResponse<InventoryItemDetailResponse>> getItemDetail({
    int? id,
    String? sku,
    bool includeMovements = true,
    int movementsLimit = 10,
    bool includeServices = true,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (id != null) {
        queryParams['id'] = id.toString();
      } else if (sku != null) {
        queryParams['sku'] = sku;
      } else {
        return ApiResponse.error('Se requiere ID o SKU del item');
      }

      queryParams['include_movements'] = includeMovements.toString();
      queryParams['movements_limit'] = movementsLimit.toString();
      queryParams['include_services'] = includeServices.toString();

      final uri = Uri.parse(
        '$_baseUrl/items/get_item_detail.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<InventoryItemDetailResponse>(
        response,
        (data) => InventoryItemDetailResponse.fromJson(data['data']),
      );
    } catch (e) {
      return ApiResponse.error(
        'Error al obtener detalle del item: ${e.toString()}',
      );
    }
  }

  /// Crea un nuevo item de inventario
  static Future<ApiResponse<InventoryItem>> createItem(
    InventoryItem item,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/items/create_item.php');

      // Obtener el usuario actual
      final userId = await _getCurrentUserId();

      // Preparar datos - SOLO enviar campos que el PHP procesa
      final itemData = <String, dynamic>{
        'sku': item.sku,
        'name': item.name,
        'item_type': item.itemType,
      };

      // Campos opcionales que el PHP sí procesa
      if (item.description != null && item.description!.isNotEmpty) {
        itemData['description'] = item.description;
      }
      if (item.categoryId != null) {
        itemData['category_id'] = item.categoryId;
      }
      if (item.brand != null && item.brand!.isNotEmpty) {
        itemData['brand'] = item.brand;
      }
      if (item.model != null && item.model!.isNotEmpty) {
        itemData['model'] = item.model;
      }
      if (item.partNumber != null && item.partNumber!.isNotEmpty) {
        itemData['part_number'] = item.partNumber;
      }
      itemData['current_stock'] = item.currentStock;
      itemData['minimum_stock'] = item.minimumStock;
      itemData['maximum_stock'] = item.maximumStock;
      if (item.unitOfMeasure.isNotEmpty) {
        itemData['unit_of_measure'] = item.unitOfMeasure;
      }
      itemData['initial_cost'] = item.initialCost;
      itemData['unit_cost'] = item.unitCost;
      if (item.location != null && item.location!.isNotEmpty) {
        itemData['location'] = item.location;
      }
      if (item.shelf != null && item.shelf!.isNotEmpty) {
        itemData['shelf'] = item.shelf;
      }
      if (item.bin != null && item.bin!.isNotEmpty) {
        itemData['bin'] = item.bin;
      }
      if (item.barcode != null && item.barcode!.isNotEmpty) {
        itemData['barcode'] = item.barcode;
      }
      if (item.qrCode != null && item.qrCode!.isNotEmpty) {
        itemData['qr_code'] = item.qrCode;
      }
      if (item.supplierId != null) {
        itemData['supplier_id'] = item.supplierId;
      }

      // Agregar usuario si está disponible
      if (userId != null) {
        itemData['created_by'] = userId;
        //         print('📦 Creando item con usuario: $userId');
      } else {
        //         print('⚠️ Creando item sin usuario (usuario no encontrado en sesión)');
      }

      //       print('📦 Enviando datos: $itemData');

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(itemData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            InventoryItem.fromJson(responseData['data']['item']),
            responseData['message'] ?? 'Item creado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error: ${e.toString()}');
    }
  }

  /// Actualiza un item existente
  static Future<ApiResponse<InventoryItem>> updateItem(
    InventoryItem item,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/items/update_item.php');

      // Verificar que el item tenga ID
      if (item.id == null) {
        return ApiResponse.error(
          'El item debe tener un ID para poder actualizarlo',
        );
      }

      // Preparar datos - SOLO enviar campos que el PHP procesa
      final itemData = <String, dynamic>{
        'id': item.id, // REQUERIDO para actualizar
        'sku': item.sku,
        'name': item.name,
        'item_type': item.itemType,
      };

      // Campos opcionales que el PHP sí procesa
      if (item.description != null && item.description!.isNotEmpty) {
        itemData['description'] = item.description;
      }
      if (item.categoryId != null) {
        itemData['category_id'] = item.categoryId;
      }
      if (item.brand != null && item.brand!.isNotEmpty) {
        itemData['brand'] = item.brand;
      }
      if (item.model != null && item.model!.isNotEmpty) {
        itemData['model'] = item.model;
      }
      if (item.partNumber != null && item.partNumber!.isNotEmpty) {
        itemData['part_number'] = item.partNumber;
      }

      // Stock - siempre enviar ya que son números
      itemData['current_stock'] = item.currentStock;
      itemData['minimum_stock'] = item.minimumStock;
      itemData['maximum_stock'] = item.maximumStock;

      if (item.unitOfMeasure.isNotEmpty) {
        itemData['unit_of_measure'] = item.unitOfMeasure;
      }

      // Costos - siempre enviar ya que son números
      itemData['unit_cost'] = item.unitCost;
      itemData['average_cost'] = item.averageCost;
      itemData['last_cost'] = item.lastCost;

      if (item.location != null && item.location!.isNotEmpty) {
        itemData['location'] = item.location;
      }
      if (item.shelf != null && item.shelf!.isNotEmpty) {
        itemData['shelf'] = item.shelf;
      }
      if (item.bin != null && item.bin!.isNotEmpty) {
        itemData['bin'] = item.bin;
      }
      if (item.barcode != null && item.barcode!.isNotEmpty) {
        itemData['barcode'] = item.barcode;
      }
      if (item.qrCode != null && item.qrCode!.isNotEmpty) {
        itemData['qr_code'] = item.qrCode;
      }
      if (item.supplierId != null) {
        itemData['supplier_id'] = item.supplierId;
      }

      // Estado activo
      itemData['is_active'] = item.isActive;

      //       print('📝 Actualizando item ID: ${item.id}');
      //       print('📝 Enviando datos: $itemData');

      final response = await http
          .put(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(itemData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            InventoryItem.fromJson(responseData['data']['item']),
            responseData['message'] ?? 'Item actualizado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error al actualizar item: ${e.toString()}');
    }
  }

  /// Verifica disponibilidad de SKU
  static Future<ApiResponse<SkuCheckResponse>> checkSku(
    String sku, {
    int? excludeId,
    bool suggestAlternatives = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'sku': sku,
        'suggest_alternatives': suggestAlternatives.toString(),
      };

      if (excludeId != null) {
        queryParams['exclude_id'] = excludeId.toString();
      }

      final uri = Uri.parse(
        '$_baseUrl/items/check_sku.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<SkuCheckResponse>(
        response,
        (data) => SkuCheckResponse.fromJson(data['data']),
      );
    } catch (e) {
      return ApiResponse.error('Error al verificar SKU: ${e.toString()}');
    }
  }

  /// Búsqueda avanzada de items
  static Future<ApiResponse<InventoryItemResponse>> searchItems({
    String? q,
    String? sku,
    String? name,
    String? brand,
    String? model,
    String? barcode,
    List<int>? categoryIds,
    List<String>? itemTypes,
    List<int>? supplierIds,
    String? stockStatus,
    double? priceMin,
    double? priceMax,
    int? stockMin,
    int? stockMax,
    String? location,
    String? createdAfter,
    String? createdBefore,
    bool? isActive,
    int limit = 50,
    int offset = 0,
    String sortBy = 'name',
    String sortOrder = 'ASC',
    bool includeInactive = false,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (q != null && q.isNotEmpty) queryParams['q'] = q;
      if (sku != null && sku.isNotEmpty) queryParams['sku'] = sku;
      if (name != null && name.isNotEmpty) queryParams['name'] = name;
      if (brand != null && brand.isNotEmpty) queryParams['brand'] = brand;
      if (model != null && model.isNotEmpty) queryParams['model'] = model;
      if (barcode != null && barcode.isNotEmpty) {
        queryParams['barcode'] = barcode;
      }
      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['category_ids'] = categoryIds.join(',');
      }
      if (itemTypes != null && itemTypes.isNotEmpty) {
        queryParams['item_types'] = itemTypes.join(',');
      }
      if (supplierIds != null && supplierIds.isNotEmpty) {
        queryParams['supplier_ids'] = supplierIds.join(',');
      }
      if (stockStatus != null) queryParams['stock_status'] = stockStatus;
      if (priceMin != null) queryParams['price_min'] = priceMin.toString();
      if (priceMax != null) queryParams['price_max'] = priceMax.toString();
      if (stockMin != null) queryParams['stock_min'] = stockMin.toString();
      if (stockMax != null) queryParams['stock_max'] = stockMax.toString();
      if (location != null && location.isNotEmpty) {
        queryParams['location'] = location;
      }
      if (createdAfter != null) queryParams['created_after'] = createdAfter;
      if (createdBefore != null) queryParams['created_before'] = createdBefore;
      if (isActive != null) queryParams['is_active'] = isActive.toString();
      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (!includeInactive) {
        queryParams['is_active'] = 'true';
      }

      queryParams['limit'] = limit.toString();
      queryParams['offset'] = offset.toString();
      queryParams['sort_by'] = sortBy;
      queryParams['sort_order'] = sortOrder;

      final uri = Uri.parse(
        '$_baseUrl/items/search_items.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<InventoryItemResponse>(
        response,
        (data) => InventoryItemResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error('Error en búsqueda: ${e.toString()}');
    }
  }

  // === GESTIÓN DE CATEGORÍAS ===

  /// Obtiene lista de categorías
  static Future<ApiResponse<InventoryCategoryResponse>> getCategories({
    bool includeInactive = false,
    int? parentId,
    bool flat = false,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (parentId != null) queryParams['parent_id'] = parentId.toString();
      if (flat) queryParams['flat'] = 'true';

      final uri = Uri.parse(
        '$_baseUrl/categories/get_categories.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<InventoryCategoryResponse>(
        response,
        (data) => InventoryCategoryResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener categorías: ${e.toString()}');
    }
  }

  /// Crea una nueva categoría
  static Future<ApiResponse<InventoryCategory>> createCategory(
    CategoryFormData categoryData,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/categories/create_category.php');

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(), // ✅ USAR NUEVOS HEADERS
            body: json.encode(categoryData.toJson()),
          )
          .timeout(_timeout);

      return _handleResponse<InventoryCategory>(
        response,
        (data) => InventoryCategory.fromJson(data['data']['category']),
      );
    } catch (e) {
      return ApiResponse.error('Error al crear categoría: ${e.toString()}');
    }
  }

  /// Actualiza una categoría existente
  static Future<ApiResponse<InventoryCategory>> updateCategory(
    int id,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/categories/update_category.php');

      final requestData = Map<String, dynamic>.from(updateData);
      requestData['id'] = id;

      final response = await http
          .put(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      return _handleResponse<InventoryCategory>(
        response,
        (data) => InventoryCategory.fromJson(data['data']['category']),
      );
    } catch (e) {
      return ApiResponse.error(
        'Error al actualizar categoría: ${e.toString()}',
      );
    }
  }

  // === GESTIÓN DE PROVEEDORES ===

  /// Obtiene lista de proveedores
  static Future<ApiResponse<InventorySupplierResponse>> getSuppliers({
    bool includeInactive = false,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      queryParams['limit'] = limit.toString();
      queryParams['offset'] = offset.toString();

      final uri = Uri.parse(
        '$_baseUrl/suppliers/get_suppliers.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<InventorySupplierResponse>(
        response,
        (data) => InventorySupplierResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error('Error al obtener proveedores: ${e.toString()}');
    }
  }

  /// Crea un nuevo proveedor
  static Future<ApiResponse<InventorySupplier>> createSupplier(
    Map<String, dynamic> supplierData,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/suppliers/create_supplier.php');

      //       print('📦 Creando proveedor con datos: $supplierData');

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(supplierData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            InventorySupplier.fromJson(responseData['data']['supplier']),
            responseData['message'] ?? 'Proveedor creado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error al crear proveedor: ${e.toString()}');
    }
  }

  /// Actualiza un proveedor existente
  static Future<ApiResponse<InventorySupplier>> updateSupplier(
    int id,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/suppliers/update_supplier.php');
      // ✅ AGREGAR ESTAS LÍNEAS DE DEBUG:
      //       print('🔧 DEBUG - URI: $uri');
      //       print('🔧 DEBUG - Método: PUT');
      //       print('🔧 DEBUG - Headers: ${await _getHeadersWithUser()}');

      // Preparar datos - SOLO enviar campos que el PHP procesa
      final supplierData = <String, dynamic>{
        'id': id, // REQUERIDO para actualizar
      };

      // Campos requeridos
      if (updateData.containsKey('name')) {
        supplierData['name'] = updateData['name'];
      }

      // Campos opcionales que el PHP sí procesa
      if (updateData.containsKey('contact_person')) {
        supplierData['contact_person'] = updateData['contact_person'];
      }
      if (updateData.containsKey('email')) {
        supplierData['email'] = updateData['email'];
      }
      if (updateData.containsKey('phone')) {
        supplierData['phone'] = updateData['phone'];
      }
      if (updateData.containsKey('address')) {
        supplierData['address'] = updateData['address'];
      }
      if (updateData.containsKey('tax_id')) {
        supplierData['tax_id'] = updateData['tax_id'];
      }
      if (updateData.containsKey('is_active')) {
        supplierData['is_active'] = updateData['is_active'];
      }

      //       print('📝 Actualizando proveedor ID: $id');
      //       print('📝 Enviando datos: $supplierData');

      final response = await http
          .put(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(supplierData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar respuesta del endpoint
        if (responseData['success'] == true) {
          return ApiResponse.success(
            InventorySupplier.fromJson(responseData['data']['supplier']),
            responseData['message'] ?? 'Proveedor actualizado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(
        'Error al actualizar proveedor: ${e.toString()}',
      );
    }
  }

  /// Elimina un proveedor existente
  static Future<ApiResponse<Map<String, dynamic>>> deleteSupplier({
    required int id,
    bool force = false,
    bool softDelete = true,
    int? transferItemsTo,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/suppliers/delete_supplier.php');

      // Preparar datos para la eliminación
      final deleteData = <String, dynamic>{
        'id': id,
        'force': force,
        'soft_delete': softDelete,
      };

      // Agregar proveedor de destino si se especifica
      if (transferItemsTo != null && transferItemsTo > 0) {
        deleteData['transfer_items_to'] = transferItemsTo;
      }

      //       print('🗑️ Eliminando proveedor ID: $id');
      //       print('🗑️ Parámetros: $deleteData');

      final response = await http
          .delete(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(deleteData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);
        //         print('📋 Response Data: $responseData');

        // Manejar diferentes códigos de respuesta
        if (response.statusCode == 200 && responseData['success'] == true) {
          // Eliminación exitosa
          return ApiResponse.success(
            responseData['data'] ?? {},
            responseData['message'] ?? 'Proveedor eliminado exitosamente',
          );
        } else if (response.statusCode == 409) {
          // Conflicto - tiene dependencias
          return ApiResponse.error(
            responseData['message'] ?? 'El proveedor tiene dependencias',
            errors: {
              'conflict': true,
              'dependencies': responseData['errors'],
              'recommendations': responseData['data']?['recommendations'] ?? {},
              'items_count': responseData['data']?['items_count'] ?? 0,
              'sample_items': responseData['data']?['sample_items'] ?? [],
            },
          );
        } else if (response.statusCode == 400) {
          // Error de validación
          return ApiResponse.error(
            responseData['message'] ?? 'Error de validación',
            errors: responseData['errors'],
          );
        } else {
          // Otros errores
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        // Si hay error al parsear JSON, mostrar el body crudo
        //         print('❌ Error parseando JSON: $jsonError');
        //         print('📡 Raw Body: ${response.body}');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error al eliminar proveedor: ${e.toString()}');
    }
  }

  /// Verifica si un proveedor puede ser eliminado sin conflictos
  static Future<ApiResponse<Map<String, dynamic>>> checkSupplierDependencies({
    required int id,
  }) async {
    try {
      // Hacer una consulta específica para obtener información del proveedor con conteo de items
      final uri = Uri.parse('$_baseUrl/suppliers/get_suppliers.php').replace(
        queryParameters: {
          'search': id.toString(),
          'include_inactive': 'true',
          'limit': '1',
        },
      );

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      if (response.body.isEmpty) {
        return ApiResponse.error('El servidor devolvió una respuesta vacía');
      }

      final responseData = jsonDecode(response.body);

      if (responseData['success'] != true ||
          responseData['data']?['suppliers']?.isEmpty == true) {
        return ApiResponse.error('Proveedor no encontrado');
      }

      final supplierData = responseData['data']['suppliers'][0];
      final itemsCount = supplierData['items_count'] ?? 0;

      // Si el proveedor tiene items, simular la respuesta de conflicto
      if (itemsCount > 0) {
        return ApiResponse.error(
          'El proveedor tiene $itemsCount items asociados',
          errors: {
            'conflict': true,
            'dependencies': {'items': '$itemsCount items asociados'},
            'items_count': itemsCount,
            'can_delete': false,
            'recommendations': {
              'transfer_items': 'Transfiere los items a otro proveedor',
              'force_delete':
                  'Usa eliminación forzada (items quedarán sin proveedor)',
              'soft_delete': 'Desactiva el proveedor en lugar de eliminarlo',
            },
          },
        );
      }

      return ApiResponse.success({
        'can_delete': true,
        'supplier': InventorySupplier.fromJson(supplierData),
        'dependencies': {},
        'items_count': 0,
      });
    } catch (e) {
      return ApiResponse.error(
        'Error al verificar dependencias: ${e.toString()}',
      );
    }
  }

  // === MOVIMIENTOS ===

  /// Crea un nuevo movimiento de inventario
  static Future<ApiResponse<InventoryMovement>> createMovement({
    required int inventoryItemId,
    required String movementType,
    required String movementReason,
    required double quantity,
    double? unitCost,
    double? newSalePrice, // Nuevo parámetro opcional
    String? referenceType,
    int? referenceId,
    String? notes,
    String? documentNumber,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/movements/create_movement.php');

      // Obtener el usuario actual
      final userId = await _getCurrentUserId();

      final requestData = <String, dynamic>{
        'inventory_item_id': inventoryItemId,
        'movement_type': movementType,
        'movement_reason': movementReason,
        'quantity': quantity,
      };

      // Campos opcionales
      if (unitCost != null) requestData['unit_cost'] = unitCost;
      if (newSalePrice != null) {
        requestData['new_sale_price'] = newSalePrice; // Enviar si existe
      }
      if (referenceType != null) requestData['reference_type'] = referenceType;
      if (referenceId != null) requestData['reference_id'] = referenceId;
      if (notes != null && notes.isNotEmpty) requestData['notes'] = notes;
      if (documentNumber != null && documentNumber.isNotEmpty) {
        requestData['document_number'] = documentNumber;
      }
      if (userId != null) requestData['created_by'] = userId;

      //       print('🔄 Creando movimiento: $requestData');

      final response = await http
          .post(
            uri,
            headers: await _getHeadersWithUser(),
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');
      //       print('📡 Body: ${response.body}');

      // Verificar si el body está vacío
      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}). Posible error interno del servidor.',
        );
      }

      try {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          return ApiResponse.success(
            InventoryMovement.fromJson(responseData['data']['movement']),
            responseData['message'] ?? 'Movimiento creado exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        //         print('❌ Error parseando JSON: $jsonError');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error al crear movimiento: ${e.toString()}');
    }
  }

  /// Obtiene historial de movimientos para un item específico
  static Future<ApiResponse<List<InventoryMovement>>> getMovementsByItem({
    required int inventoryItemId,
    int limit = 50,
    int offset = 0,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    String? movementType,
    String? movementReason,
    String? period,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, String>{
        'inventory_item_id': inventoryItemId.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
        'include_item_details': 'true',
      };

      // Filtros opcionales
      if (movementType != null) queryParams['movement_type'] = movementType;
      if (movementReason != null) {
        queryParams['movement_reason'] = movementReason;
      }
      if (period != null) queryParams['period'] = period;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final uri = Uri.parse(
        '$_baseUrl/movements/get_movements.php',
      ).replace(queryParameters: queryParams);

      //       print('📋 Obteniendo movimientos para item: $inventoryItemId');

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      //       print('📡 Status: ${response.statusCode}');

      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}).',
        );
      }

      try {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final movementsData =
              responseData['data']['movements'] as List<dynamic>;
          final movements =
              movementsData
                  .map(
                    (movementJson) => InventoryMovement.fromJson(
                      movementJson as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          return ApiResponse.success(
            movements,
            responseData['message'] ?? 'Movimientos obtenidos exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        //         print('❌ Error parseando JSON: $jsonError');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida.',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error('Error al obtener movimientos: ${e.toString()}');
    }
  }

  /// Obtiene estadísticas de movimientos para un item
  static Future<ApiResponse<MovementStats>> getMovementStats({
    required int inventoryItemId,
    String period = 'all',
  }) async {
    try {
      final queryParams = <String, String>{
        'inventory_item_id': inventoryItemId.toString(),
        'period': period,
        'stats_only': 'true',
      };

      final uri = Uri.parse(
        '$_baseUrl/movements/get_movements.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getHeadersWithUser())
          .timeout(_timeout);

      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode}).',
        );
      }

      try {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final statsData = responseData['data']['summary'] ?? {};
          return ApiResponse.success(
            MovementStats.fromJson(statsData),
            responseData['message'] ?? 'Estadísticas obtenidas exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        //         print('❌ Error parseando JSON: $jsonError');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida.',
        );
      }
    } catch (e) {
      //       print('❌ Error: $e');
      return ApiResponse.error(
        'Error al obtener estadísticas: ${e.toString()}',
      );
    }
  }

  // === DASHBOARD ===

  /// Obtiene estadísticas del dashboard
  static Future<ApiResponse<DashboardStats>> getDashboardStats({
    String period = 'month',
    bool includeCharts = true,
    bool includeTrends = true,
  }) async {
    try {
      final queryParams = <String, String>{
        'period': period,
        'include_charts': includeCharts.toString(),
        'include_trends': includeTrends.toString(),
      };

      final uri = Uri.parse(
        '$_baseUrl/dashboard/get_dashboard_stats.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<DashboardStats>(
        response,
        (data) => DashboardStats.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(
        'Error al obtener estadísticas: ${e.toString()}',
      );
    }
  }

  /// Obtiene items con stock bajo
  static Future<ApiResponse<LowStockResponse>> getLowStockItems({
    String alertLevel = 'all',
    List<int>? categoryIds,
    List<String>? itemTypes,
    List<int>? supplierIds,
    bool includeInactive = false,
    int minUsageFrequency = 0,
    int daysSupplyThreshold = 30,
    int limit = 100,
    int offset = 0,
    String sortBy = 'priority',
    String sortOrder = 'ASC',
    bool includeProjections = true,
    bool includeRecommendations = true,
  }) async {
    try {
      final queryParams = <String, String>{
        'alert_level': alertLevel,
        'include_inactive': includeInactive.toString(),
        'min_usage_frequency': minUsageFrequency.toString(),
        'days_supply_threshold': daysSupplyThreshold.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder,
        'include_projections': includeProjections.toString(),
        'include_recommendations': includeRecommendations.toString(),
      };

      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['category_ids'] = categoryIds.join(',');
      }
      if (itemTypes != null && itemTypes.isNotEmpty) {
        queryParams['item_types'] = itemTypes.join(',');
      }
      if (supplierIds != null && supplierIds.isNotEmpty) {
        queryParams['supplier_ids'] = supplierIds.join(',');
      }

      final uri = Uri.parse(
        '$_baseUrl/dashboard/get_low_stock_items.php',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _getAuthHeaders())
          .timeout(_timeout);

      return _handleResponse<LowStockResponse>(
        response,
        (data) => LowStockResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(
        'Error al obtener items con stock bajo: ${e.toString()}',
      );
    }
  }

  // === MÉTODOS AUXILIARES ===

  /// Maneja las respuestas de la API de forma consistente
  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser,
  ) {
    try {
      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data['success'] == true) {
          return ApiResponse.success(parser(data));
        } else {
          return ApiResponse.error(
            data['message'] ?? 'Error desconocido',
            errors: data['errors'],
          );
        }
      } else {
        return ApiResponse.error(
          'Error HTTP ${response.statusCode}: ${data['message'] ?? 'Error desconocido'}',
          errors: data['errors'],
        );
      }
    } catch (e) {
      return ApiResponse.error('Error al procesar respuesta: ${e.toString()}');
    }
  }
  // === IMPORTACIÓN/EXPORTACIÓN DE INVENTARIO ===

  /// Exporta items de inventario a Excel
  static Future<ApiResponse<List<int>>> exportInventoryToExcel({
    List<InventoryItem>? items,
    List<String>? selectedFields,
    bool? includeHeaders,
  }) async {
    try {
      //       print('[EXPORT INVENTORY] Iniciando exportación...');

      final uri = Uri.parse(
        '${ServerConfig.instance.baseUrlFor('inventory')}/items/exportar_inventario.php',
      );

      // Preparar datos para envío
      final requestData = <String, dynamic>{};

      if (items != null && items.isNotEmpty) {
        // Convertir items a formato Map para enviar al servidor
        requestData['items'] =
            items
                .map(
                  (item) => {
                    'id': item.id,
                    'sku': item.sku,
                    'name': item.name,
                    'description': item.description,
                    'category_id': item.categoryId,
                    'category_name': item.categoryName,
                    'supplier_id': item.supplierId,
                    'supplier_name': item.supplierName,
                    'item_type': item.itemType,
                    'unit_of_measure': item.unitOfMeasure,
                    'brand': item.brand,
                    'model': item.model,
                    'part_number': item.partNumber,
                    'initial_cost': item.initialCost,
                    'unit_cost': item.unitCost,
                    'average_cost': item.averageCost,
                    'last_cost': item.lastCost,
                    'current_stock': item.currentStock,
                    'minimum_stock': item.minimumStock,
                    'maximum_stock': item.maximumStock,
                    'location': item.location,
                    'shelf': item.shelf,
                    'bin': item.bin,
                    'barcode': item.barcode,
                    'qr_code': item.qrCode,
                    'is_active': item.isActive,
                    'created_at': item.createdAt?.toIso8601String(),
                    'updated_at': item.updatedAt?.toIso8601String(),
                  },
                )
                .toList();
        //         print('[EXPORT INVENTORY] Items a exportar: ${items.length}');
      }

      if (selectedFields != null && selectedFields.isNotEmpty) {
        requestData['selected_fields'] = selectedFields;
      }

      if (includeHeaders != null) {
        requestData['include_headers'] = includeHeaders;
      }

      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        if (token != null) 'Authorization': token,
      };

      final response = await http
          .post(uri, headers: headers, body: json.encode(requestData))
          .timeout(const Duration(seconds: 60));

      //       print('[EXPORT INVENTORY] Status Code: ${response.statusCode}');
      //       print('[EXPORT INVENTORY] Response length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          // Es un error JSON
          final errorData = jsonDecode(response.body);
          return ApiResponse.error(
            'Error del servidor: ${errorData['error'] ?? 'Error desconocido'}',
          );
        }

        // Es un archivo Excel válido - retornar los bytes
        return ApiResponse.success(
          response.bodyBytes,
          'Excel generado exitosamente',
        );
      } else {
        String errorMessage = 'Error al exportar Excel: ${response.statusCode}';

        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (e) {
          // Si no es JSON válido, usar mensaje por defecto
        }

        return ApiResponse.error(errorMessage);
      }
    } catch (e) {
      //       print('[EXPORT INVENTORY] Error: $e');
      return ApiResponse.error('Error al exportar inventario: ${e.toString()}');
    }
  }

  /// Importa items de inventario desde archivo Excel/CSV
  static Future<ApiResponse<ImportResult>> importInventoryFromFile({
    required Uint8List fileBytes,
    required String fileName,
    ImportOptions? options,
  }) async {
    try {
      //       print('[IMPORT INVENTORY] Iniciando importación...');
      //       print('[IMPORT INVENTORY] Archivo: $fileName');
      //       print('[IMPORT INVENTORY] Tamaño: ${fileBytes.length} bytes');

      final uri = Uri.parse(
        '${ServerConfig.instance.baseUrlFor('inventory')}/items/importar_inventario.php',
      );

      // Convertir bytes a base64
      final base64String = base64Encode(fileBytes);

      final requestData = <String, dynamic>{
        'archivo_base64': base64String,
        'nombre_archivo': fileName,
      };

      // Agregar opciones si se proporcionan
      if (options != null) {
        requestData['options'] = {
          'update_existing': options.updateExisting,
          'create_categories': options.createCategories,
          'create_suppliers': options.createSuppliers,
          'skip_first_row': options.skipFirstRow,
          'date_format': options.dateFormat,
          'encoding': options.encoding,
        };
      }

      // ✅ DEFINIR HEADERS DIRECTAMENTE
      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final response = await http
          .post(uri, headers: headers, body: json.encode(requestData))
          .timeout(const Duration(seconds: 120));

      //       print('[IMPORT INVENTORY] Status Code: ${response.statusCode}');
      //       print('[IMPORT INVENTORY] Response: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse.error(
          'El servidor devolvió una respuesta vacía (Status: ${response.statusCode})',
        );
      }

      try {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final result = ImportResult(
            totalRecords:
                (responseData['insertados'] ?? 0) +
                (responseData['actualizados'] ?? 0) +
                (responseData['errores'] ?? 0),
            successfulImports:
                (responseData['insertados'] ?? 0) +
                (responseData['actualizados'] ?? 0),
            skippedRecords: 0,
            errorRecords: responseData['errores'] ?? 0,
            errors: List<String>.from(responseData['errores_detalle'] ?? []),
            importedItems:
                [], // Se podría llenar con datos reales si el PHP lo devuelve
          );

          return ApiResponse.success(
            result,
            responseData['message'] ?? 'Importación completada exitosamente',
          );
        } else {
          return ApiResponse.error(
            responseData['message'] ?? 'Error del servidor',
            errors: responseData['errors'],
          );
        }
      } catch (jsonError) {
        //         print('[IMPORT INVENTORY] Error parseando JSON: $jsonError');
        return ApiResponse.error(
          'Error del servidor (Status: ${response.statusCode}). Respuesta no válida: ${response.body}',
        );
      }
    } catch (e) {
      //       print('[IMPORT INVENTORY] Error: $e');
      return ApiResponse.error('Error al importar inventario: ${e.toString()}');
    }
  }

  /// Descarga la plantilla de Excel para importación
  static Future<ApiResponse<List<int>>> downloadInventoryTemplate() async {
    try {
      //       print('[TEMPLATE] Descargando plantilla de inventario...');

      final uri = Uri.parse(
        '${ServerConfig.instance.baseUrlFor('inventory')}/items/plantilla_inventario.php',
      );

      final token = await AuthService.getBearerToken();
      final headers = {
        'Accept':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      //       print('[TEMPLATE] Status Code: ${response.statusCode}');
      //       print('[TEMPLATE] Response length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          // Es un error JSON
          final errorData = jsonDecode(response.body);
          return ApiResponse.error(
            'Error del servidor: ${errorData['error'] ?? 'Error desconocido'}',
          );
        }

        // Es un archivo Excel válido
        return ApiResponse.success(
          response.bodyBytes,
          'Plantilla descargada exitosamente',
        );
      } else {
        return ApiResponse.error(
          'Error al descargar plantilla: ${response.statusCode}',
        );
      }
    } catch (e) {
      //       print('[TEMPLATE] Error: $e');
      return ApiResponse.error('Error al descargar plantilla: ${e.toString()}');
    }
  }

  // Helper para headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      ..._defaultHeaders,
      if (token != null) 'Authorization': token,
    };
  }
}

/// Clase genérica para respuestas de la API
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
  });

  factory ApiResponse.success(T data, [String? message]) {
    return ApiResponse(
      success: true,
      data: data,
      message: message ?? 'Operación exitosa',
    );
  }

  factory ApiResponse.error(String message, {Map<String, dynamic>? errors}) {
    return ApiResponse(success: false, message: message, errors: errors);
  }

  bool get hasErrors => errors != null && errors!.isNotEmpty;

  List<String> get errorMessages {
    if (!hasErrors) return [];
    return errors!.values.whereType<String>().cast<String>().toList();
  }
}
