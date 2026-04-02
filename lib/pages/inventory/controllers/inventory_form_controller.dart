// lib/pages/inventory/controllers/inventory_form_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';
import 'package:infoapp/pages/inventory/services/inventory_api_service.dart';

class InventoryFormController extends ChangeNotifier {
  // === MODO DEL FORMULARIO ===
  final bool isEditMode;
  final InventoryItem? originalItem;

  // === CONTROLADORES DE TEXTO ===
  final TextEditingController skuController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController currentStockController = TextEditingController();
  final TextEditingController minimumStockController = TextEditingController();
  final TextEditingController maximumStockController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();

  // === VALORES DEL FORMULARIO ===
  int? _selectedCategoryId;
  String _selectedType = 'product';
  int? _selectedSupplierId;
  String _selectedUnit = 'unidad';
  bool _isActive = true;
  bool _trackStock = true;

  // === ESTADO DE VALIDACIÓN ===
  final Map<String, String> _validationErrors = {};
  bool _isDirty = false;

  // === ESTADO DE SKU ===
  bool _isCheckingSku = false;
  bool _skuIsAvailable = true;
  List<SkuSuggestion> _skuSuggestions = [];
  Timer? _skuCheckTimer;

  // === ESTADO DE GUARDADO ===
  bool _isSaving = false;
  String? _saveError;

  // === DATOS DE REFERENCIA ===
  List<InventoryCategory> _categories = [];
  List<InventorySupplier> _suppliers = [];

  // === CONSTRUCTOR ===
  InventoryFormController({
    InventoryItem? item,
    List<InventoryCategory>? categories,
    List<InventorySupplier>? suppliers,
  }) : isEditMode = item != null,
       originalItem = item {
    _categories = categories ?? [];
    _suppliers = suppliers ?? [];

    if (item != null) {
      _initializeFromItem(item);
    } else {
      _initializeDefaults();
    }

    _setupListeners();
  }

  // === GETTERS ===
  int? get selectedCategoryId => _selectedCategoryId;
  String get selectedType => _selectedType;
  int? get selectedSupplierId => _selectedSupplierId;
  String get selectedUnit => _selectedUnit;
  bool get isActive => _isActive;
  bool get trackStock => _trackStock;

  Map<String, String> get validationErrors =>
      Map.unmodifiable(_validationErrors);
  bool get isDirty => _isDirty;
  bool get hasErrors => _validationErrors.isNotEmpty;

  bool get isCheckingSku => _isCheckingSku;
  bool get skuIsAvailable => _skuIsAvailable;
  List<SkuSuggestion> get skuSuggestions => List.unmodifiable(_skuSuggestions);

  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  List<InventoryCategory> get categories => List.unmodifiable(_categories);
  List<InventorySupplier> get suppliers => List.unmodifiable(_suppliers);

  bool get canSave => !hasErrors && !_isSaving && _skuIsAvailable && _isDirty;

  // === INICIALIZACIÓN ===

  void _initializeFromItem(InventoryItem item) {
    skuController.text = item.sku;
    nameController.text = item.name;
    descriptionController.text = item.description ?? '';
    _selectedCategoryId = item.categoryId;
    _selectedType = item.itemType;
    priceController.text = item.unitCost.toString();
    costController.text = item.initialCost.toString();
    currentStockController.text = item.currentStock.toString();
    minimumStockController.text = item.minimumStock.toString();
    maximumStockController.text = item.maximumStock.toString();
    _selectedUnit = item.unitOfMeasure;
    locationController.text = item.location ?? '';
    barcodeController.text = item.barcode ?? '';
    _selectedSupplierId = item.supplierId;
    _isActive = item.isActive;
    // _trackStock = item.trackStock; // Not in model
  }

  void _initializeDefaults() {
    currentStockController.text = '0';
    minimumStockController.text = '0';
    maximumStockController.text = '0';
    priceController.text = '0.00';
    costController.text = '0.00';
  }

  void _setupListeners() {
    // Listeners para marcar el formulario como dirty
    final controllers = [
      skuController,
      nameController,
      descriptionController,
      priceController,
      costController,
      currentStockController,
      minimumStockController,
      maximumStockController,
      locationController,
      barcodeController,
    ];

    for (var controller in controllers) {
      controller.addListener(_markDirty);
    }

    // Listener específico para SKU
    skuController.addListener(_onSkuChanged);
  }

  void _markDirty() {
    if (!_isDirty) {
      _isDirty = true;
      notifyListeners();
    }
  }

  void _onSkuChanged() {
    final sku = skuController.text.trim();

    // Cancel previous timer
    _skuCheckTimer?.cancel();

    if (sku.isEmpty) {
      _skuIsAvailable = true;
      _skuSuggestions.clear();
      _clearSkuError();
      notifyListeners();
      return;
    }

    // Si estamos editando y el SKU no cambió, no validar
    if (isEditMode && sku == originalItem?.sku) {
      _skuIsAvailable = true;
      _skuSuggestions.clear();
      _clearSkuError();
      notifyListeners();
      return;
    }

    // Debounce la verificación
    _skuCheckTimer = Timer(const Duration(milliseconds: 800), () {
      _checkSkuAvailability(sku);
    });
  }

  // === SETTERS ===

  void setSelectedCategory(int? categoryId) {
    if (_selectedCategoryId != categoryId) {
      _selectedCategoryId = categoryId;
      _markDirty();
      _validateField('category');
      notifyListeners();
    }
  }

  void setSelectedType(String type) {
    if (_selectedType != type) {
      _selectedType = type;
      _markDirty();
      notifyListeners();
    }
  }

  void setSelectedSupplier(int? supplierId) {
    if (_selectedSupplierId != supplierId) {
      _selectedSupplierId = supplierId;
      _markDirty();
      notifyListeners();
    }
  }

  void setSelectedUnit(String unit) {
    if (_selectedUnit != unit) {
      _selectedUnit = unit;
      _markDirty();
      notifyListeners();
    }
  }

  void setIsActive(bool isActive) {
    if (_isActive != isActive) {
      _isActive = isActive;
      _markDirty();
      notifyListeners();
    }
  }

  void setTrackStock(bool trackStock) {
    if (_trackStock != trackStock) {
      _trackStock = trackStock;
      _markDirty();
      notifyListeners();
    }
  }

  // === VALIDACIÓN DE SKU ===

  Future<void> _checkSkuAvailability(String sku) async {
    if (sku.trim().isEmpty) return;

    _isCheckingSku = true;
    _skuSuggestions.clear();
    notifyListeners();

    try {
      final response = await InventoryApiService.checkSku(
        sku,
        excludeId: originalItem?.id,
        suggestAlternatives: true,
      );

      if (response.success && response.data != null) {
        _skuIsAvailable = response.data!.isAvailable;

        if (!_skuIsAvailable) {
          _setValidationError('sku', 'Este SKU ya existe');

          if (response.data!.suggestedAlternatives != null) {
            _skuSuggestions =
                response.data!.suggestedAlternatives!
                    .map((alt) => SkuSuggestion.fromMap(alt))
                    .toList();
          }
        } else {
          _clearSkuError();
        }
      } else {
        _skuIsAvailable = true; // Asumir disponible en caso de error
        _clearSkuError();
      }
    } catch (e) {
      _skuIsAvailable = true; // Asumir disponible en caso de error
      _clearSkuError();
      debugPrint('Error checking SKU: $e');
    } finally {
      _isCheckingSku = false;
      notifyListeners();
    }
  }

  void _clearSkuError() {
    _clearValidationError('sku');
  }

  void applySuggestedSku(String sku) {
    skuController.text = sku;
    _skuSuggestions.clear();
    notifyListeners();
  }

  // === VALIDACIÓN COMPLETA ===

  bool validateForm() {
    _validationErrors.clear();

    // Validar SKU
    _validateSku();

    // Validar nombre
    _validateName();

    // Validar categoría
    _validateCategory();

    // Validar campos numéricos
    _validateNumericFields();

    // Validar lógica de negocio
    _validateBusinessRules();

    notifyListeners();
    return !hasErrors;
  }

  void _validateField(String field) {
    switch (field) {
      case 'sku':
        _validateSku();
        break;
      case 'name':
        _validateName();
        break;
      case 'category':
        _validateCategory();
        break;
      case 'currentStock':
      case 'minimumStock':
      case 'maximumStock':
      case 'price':
      case 'cost':
        _validateNumericFields();
        break;
      case 'business':
        _validateBusinessRules();
        break;
    }
    notifyListeners();
  }

  void _validateSku() {
    final sku = skuController.text.trim();

    if (sku.isEmpty) {
      _setValidationError('sku', 'El SKU es requerido');
    } else if (sku.length < 2) {
      _setValidationError('sku', 'El SKU debe tener al menos 2 caracteres');
    } else if (!_skuIsAvailable) {
      _setValidationError('sku', 'Este SKU ya existe');
    } else {
      _clearValidationError('sku');
    }
  }

  void _validateName() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      _setValidationError('name', 'El nombre es requerido');
    } else if (name.length < 2) {
      _setValidationError('name', 'El nombre debe tener al menos 2 caracteres');
    } else {
      _clearValidationError('name');
    }
  }

  void _validateCategory() {
    if (_selectedCategoryId == null) {
      _setValidationError('category', 'Debe seleccionar una categoría');
    } else {
      _clearValidationError('category');
    }
  }

  void _validateNumericFields() {
    // Validar precio
    final price = double.tryParse(priceController.text);
    if (price == null || price < 0) {
      _setValidationError('price', 'Debe ser un precio válido');
    } else {
      _clearValidationError('price');
    }

    // Validar costo (opcional)
    if (costController.text.isNotEmpty) {
      final cost = double.tryParse(costController.text);
      if (cost == null || cost < 0) {
        _setValidationError('cost', 'Debe ser un costo válido');
      } else {
        _clearValidationError('cost');
      }
    } else {
      _clearValidationError('cost');
    }

    if (_trackStock) {
      // Validar stock actual
      final currentStock = int.tryParse(currentStockController.text);
      if (currentStock == null || currentStock < 0) {
        _setValidationError(
          'currentStock',
          'Debe ser un número entero positivo',
        );
      } else {
        _clearValidationError('currentStock');
      }

      // Validar stock mínimo
      final minimumStock = int.tryParse(minimumStockController.text);
      if (minimumStock == null || minimumStock < 0) {
        _setValidationError(
          'minimumStock',
          'Debe ser un número entero positivo',
        );
      } else {
        _clearValidationError('minimumStock');
      }

      // Validar stock máximo (opcional)
      if (maximumStockController.text.isNotEmpty) {
        final maximumStock = int.tryParse(maximumStockController.text);
        if (maximumStock == null || maximumStock < 0) {
          _setValidationError(
            'maximumStock',
            'Debe ser un número entero positivo',
          );
        } else {
          _clearValidationError('maximumStock');
        }
      } else {
        _clearValidationError('maximumStock');
      }
    }
  }

  void _validateBusinessRules() {
    if (_trackStock) {
      final minStock = int.tryParse(minimumStockController.text) ?? 0;
      final maxStock = int.tryParse(maximumStockController.text) ?? 0;

      if (minStock > 0 && maxStock > 0 && minStock > maxStock) {
        _setValidationError(
          'stockRange',
          'El stock mínimo no puede ser mayor que el máximo',
        );
      } else {
        _clearValidationError('stockRange');
      }
    }

    // Validar precio vs costo
    final price = double.tryParse(priceController.text) ?? 0;
    final cost = double.tryParse(costController.text) ?? 0;

    if (cost > 0 && price > 0 && cost > price) {
      _setValidationError(
        'priceVsCost',
        'El costo no debería ser mayor que el precio de venta',
      );
    } else {
      _clearValidationError('priceVsCost');
    }
  }

  void _setValidationError(String field, String message) {
    _validationErrors[field] = message;
  }

  void _clearValidationError(String field) {
    _validationErrors.remove(field);
  }

  // === GUARDADO ===

  Future<bool> saveForm() async {
    if (!validateForm()) {
      return false;
    }

    if (_isSaving) return false;

    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final item = _buildItemFromForm();

      // TODO: Descomentar cuando InventoryApiService esté disponible
      ApiResponse<InventoryItem> response;
      if (isEditMode) {
        response = await InventoryApiService.updateItem(item);
      } else {
        response = await InventoryApiService.createItem(item);
      }

      if (response.success) {
        _isDirty = false;
        return true;
      } else {
        _saveError = response.message ?? 'Error al guardar';
        _processServerErrors(response.errors);
        return false;
      }

      // Simulación temporal - REMOVIDA
      /*
      await Future.delayed(const Duration(seconds: 1));

      // Simular éxito
      _isDirty = false;
      return true;
      */
    } catch (e) {
      _saveError = 'Error inesperado: ${e.toString()}';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _processServerErrors(Map<String, dynamic>? errors) {
    if (errors == null) return;

    errors.forEach((field, message) {
      if (message is String) {
        _setValidationError(field, message);
      }
    });
  }

  InventoryItem _buildItemFromForm() {
    return InventoryItem(
      id: originalItem?.id,
      sku: skuController.text.trim(),
      name: nameController.text.trim(),
      description:
          descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
      categoryId: _selectedCategoryId,
      supplierId: _selectedSupplierId,
      itemType: _selectedType,
      unitOfMeasure: _selectedUnit,
      unitCost: double.tryParse(priceController.text) ?? 0.0,
      initialCost: double.tryParse(costController.text) ?? 0.0,
      currentStock:
          _trackStock
              ? (double.tryParse(currentStockController.text) ?? 0.0)
              : 0.0,
      minimumStock:
          _trackStock
              ? (double.tryParse(minimumStockController.text) ?? 0.0)
              : 0.0,
      maximumStock:
          _trackStock
              ? (double.tryParse(maximumStockController.text) ?? 0.0)
              : 0.0,
      location:
          locationController.text.trim().isEmpty
              ? null
              : locationController.text.trim(),
      barcode:
          barcodeController.text.trim().isEmpty
              ? null
              : barcodeController.text.trim(),
      isActive: _isActive,
      createdAt: originalItem?.createdAt,
      updatedAt: DateTime.now(),
      averageCost: originalItem?.averageCost ?? 0.0,
      lastCost: originalItem?.lastCost ?? 0.0,
    );
  }

  // === UTILIDADES ===

  void resetForm() {
    // Limpiar controladores
    skuController.clear();
    nameController.clear();
    descriptionController.clear();
    priceController.text = '0.00';
    costController.clear();
    currentStockController.text = '0';
    minimumStockController.text = '0';
    maximumStockController.clear();
    locationController.clear();
    barcodeController.clear();

    // Reset valores
    _selectedCategoryId = null;
    _selectedType = 'product';
    _selectedSupplierId = null;
    _selectedUnit = 'unidad';
    _isActive = true;
    _trackStock = true;

    // Reset estado
    _validationErrors.clear();
    _isDirty = false;
    _skuIsAvailable = true;
    _skuSuggestions.clear();
    _saveError = null;

    notifyListeners();
  }

  bool hasUnsavedChanges() {
    return _isDirty;
  }

  String getLocationPreview() {
    return locationController.text.trim().isEmpty
        ? 'No se ha especificado ubicación'
        : locationController.text.trim();
  }

  Map<String, dynamic> getFormSummary() {
    return {
      'sku': skuController.text.trim(),
      'name': nameController.text.trim(),
      'type': _selectedType,
      'category':
          _selectedCategoryId != null
              ? _categories
                      .where((c) => c.id == _selectedCategoryId)
                      .map((c) => c.name)
                      .firstOrNull ??
                  'Sin categoría'
              : 'Sin categoría',
      'supplier':
          _selectedSupplierId != null
              ? _suppliers
                      .where((s) => s.id == _selectedSupplierId)
                      .map((s) => s.name)
                      .firstOrNull ??
                  'Sin proveedor'
              : 'Sin proveedor',
      'price': priceController.text,
      'current_stock': currentStockController.text,
      'location': getLocationPreview(),
      'is_active': _isActive,
      'track_stock': _trackStock,
    };
  }

  // === CARGA DE DATOS DE REFERENCIA ===

  Future<void> loadCategories() async {
    try {
      final response = await InventoryApiService.getCategories(flat: true);
      if (response.success && response.data != null) {
        _categories = response.data!.categories;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> loadSuppliers() async {
    try {
      final response = await InventoryApiService.getSuppliers(limit: 100);
      if (response.success && response.data != null) {
        _suppliers = response.data!.suppliers;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  void updateReferenceData({
    List<InventoryCategory>? categories,
    List<InventorySupplier>? suppliers,
  }) {
    if (categories != null) {
      _categories = categories;
    }
    if (suppliers != null) {
      _suppliers = suppliers;
    }
    notifyListeners();
  }

  // === CLEANUP ===

  @override
  void dispose() {
    _skuCheckTimer?.cancel();

    // Dispose controladores
    skuController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    costController.dispose();
    currentStockController.dispose();
    minimumStockController.dispose();
    maximumStockController.dispose();
    locationController.dispose();
    barcodeController.dispose();

    super.dispose();
  }
}

// === CLASES AUXILIARES TEMPORALES ===

class SkuSuggestion {
  final String sku;
  final String type;
  final String description;

  const SkuSuggestion({
    required this.sku,
    required this.type,
    required this.description,
  });

  factory SkuSuggestion.fromMap(Map<String, dynamic> map) {
    return SkuSuggestion(
      sku: map['sku'] as String,
      type: map['type'] as String,
      description: map['description'] as String,
    );
  }

  @override
  String toString() => 'SkuSuggestion(sku: $sku, type: $type)';
}

// === EXTENSIONES ===

extension InventoryFormControllerExtensions on InventoryFormController {
  /// Obtiene el nombre de la categoría seleccionada
  String? get selectedCategoryName {
    if (_selectedCategoryId == null) return null;
    try {
      return _categories
          .where((c) => c.id == _selectedCategoryId)
          .map((c) => c.name)
          .firstOrNull;
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el nombre del proveedor seleccionado
  String? get selectedSupplierName {
    if (_selectedSupplierId == null) return null;
    try {
      return _suppliers
          .where((s) => s.id == _selectedSupplierId)
          .map((s) => s.name)
          .firstOrNull;
    } catch (e) {
      return null;
    }
  }

  /// Verifica si el formulario está listo para guardar
  bool get isReadyToSave {
    return canSave && !_isCheckingSku;
  }

  /// Obtiene el porcentaje de completitud del formulario
  double get completionPercentage {
    int totalFields = 10; // Campos importantes del formulario
    int completedFields = 0;

    if (skuController.text.trim().isNotEmpty) completedFields++;
    if (nameController.text.trim().isNotEmpty) completedFields++;
    if (descriptionController.text.trim().isNotEmpty) completedFields++;
    if (_selectedCategoryId != null) completedFields++;
    if (priceController.text.trim().isNotEmpty) completedFields++;
    if (currentStockController.text.trim().isNotEmpty) completedFields++;
    if (minimumStockController.text.trim().isNotEmpty) completedFields++;
    if (locationController.text.trim().isNotEmpty) completedFields++;
    if (_selectedSupplierId != null) completedFields++;
    if (barcodeController.text.trim().isNotEmpty) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  /// Calcula el margen de ganancia
  double get profitMargin {
    final price = double.tryParse(priceController.text) ?? 0;
    final cost = double.tryParse(costController.text) ?? 0;

    if (cost == 0) return 0;
    return ((price - cost) / cost) * 100;
  }

  /// Obtiene el estado del stock
  String get stockStatus {
    if (!_trackStock) return 'No controlado';

    final current = int.tryParse(currentStockController.text) ?? 0;
    final minimum = int.tryParse(minimumStockController.text) ?? 0;
    final maximum = int.tryParse(maximumStockController.text) ?? 0;

    if (current == 0) return 'Sin stock';
    if (current <= minimum) return 'Stock bajo';
    if (maximum > 0 && current >= maximum) return 'Stock alto';
    return 'Stock normal';
  }
}
