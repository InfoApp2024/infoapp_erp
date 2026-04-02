// lib/pages/inventory/pages/inventory_form_page.dart

import 'package:flutter/material.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

// Importar los modelos y servicios reales
import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';
import '../models/inventory_form_data_models.dart'; // ✅ NUEVO IMPORT
import '../services/inventory_api_service.dart';
import 'package:infoapp/core/utils/currency_utils.dart';

import '../widgets/inventory_supplier_widgets.dart';

// ✅ NUEVO IMPORT - Widgets personalizados
import '../widgets/inventory_form_widgets.dart';

class InventoryFormPage extends StatefulWidget {
  final InventoryItem? item; // null para crear, item para editar
  final List<InventoryCategory> categories;
  final List<InventorySupplier> suppliers;

  const InventoryFormPage({
    super.key,
    this.item,
    required this.categories,
    required this.suppliers,
  });

  @override
  State<InventoryFormPage> createState() => _InventoryFormPageState();
}

class _InventoryFormPageState extends State<InventoryFormPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _initialCostController = TextEditingController(); // ✅ NUEVO
  final _unitCostController = TextEditingController();
  final _averageCostController = TextEditingController();
  final _lastCostController = TextEditingController();
  final _currentStockController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _maximumStockController = TextEditingController();
  final _locationController = TextEditingController();
  final _shelfController = TextEditingController();
  final _binController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _qrCodeController = TextEditingController();

  // Estado del formulario
  final bool _isLoading = false;
  bool _isSaving = false;
  bool _isCheckingSku = false;
  Map<String, String> _validationErrors = {};

  // Valores del formulario
  int? _selectedCategoryId;
  String _selectedItemType = 'repuesto';
  int? _selectedSupplierId;
  String _selectedUnitOfMeasure = '';
  bool _isActive = true;
  int? _createdBy;

  // SKU
  bool _skuIsAvailable = true;
  List<String> _skuSuggestions = [];

  // ✅ NUEVO: Estados para manejo de cambio de estado
  bool _isChangingStatus = false;
  bool _showStatusSection = false;

  // Ubicaciones existentes
  List<String> _existingLocations = [];
  List<String> _existingBrands = [];
  List<String> _existingTypes = [];
  List<InventoryCategory> _localCategories = [];

  // Focus nodes para navegación
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _localCategories = List.from(widget.categories);
    _initializeFocusNodes();
    _initializeForm();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    // Cargar datos en paralelo
    final locFuture = InventoryApiService.getUniqueLocations();
    final brandFuture = InventoryApiService.getUniqueBrands();
    final typeFuture = InventoryApiService.getUniqueTypes();

    final responses = await Future.wait([locFuture, brandFuture, typeFuture]);

    if (mounted) {
      setState(() {
        if (responses[0].success && responses[0].data != null) {
          _existingLocations = responses[0].data!;
        }
        if (responses[1].success && responses[1].data != null) {
          _existingBrands = responses[1].data!;
        }
        if (responses[2].success && responses[2].data != null) {
          _existingTypes = responses[2].data!;
        }
      });
    }
  }

  // ✅ NUEVO MÉTODO - Mostrar diálogo para crear categoría
  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nueva Categoría'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Nombre de la categoría',
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Descripción opcional',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  // Mostrar indicador de carga
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Creando categoría...'),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  final response = await InventoryApiService.createCategory(
                    CategoryFormData(
                      name: name,
                      description: descController.text.trim(),
                    ),
                  );

                  if (mounted) {
                    Navigator.pop(context); // Cerrar diálogo

                    if (response.success && response.data != null) {
                      setState(() {
                        _localCategories.add(response.data!);
                        _selectedCategoryId = response.data!.id;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Categoría creada exitosamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            response.message ?? 'Error al crear categoría',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    _disposeFocusNodes();
    super.dispose();
  }

  void _initializeFocusNodes() {
    for (int i = 0; i < 15; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  void _disposeControllers() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _partNumberController.dispose();
    _unitCostController.dispose();
    _averageCostController.dispose();
    _lastCostController.dispose();
    _currentStockController.dispose();
    _minimumStockController.dispose();
    _maximumStockController.dispose();
    _locationController.dispose();
    _shelfController.dispose();
    _binController.dispose();
    _barcodeController.dispose();
    _qrCodeController.dispose();
  }

  void _disposeFocusNodes() {
    for (var node in _focusNodes) {
      node.dispose();
    }
  }

  void _initializeForm() {
    if (widget.item != null) {
      // Modo edición - cargar datos existentes
      final item = widget.item!;
      _skuController.text = item.sku;
      _nameController.text = item.name;
      _descriptionController.text = item.description ?? '';
      _brandController.text = item.brand ?? '';
      _modelController.text = item.model ?? '';
      _partNumberController.text = item.partNumber ?? '';
      _selectedCategoryId = item.categoryId;
      _selectedItemType = item.itemType;
      _unitCostController.text = CurrencyUtils.format(item.unitCost);
      _averageCostController.text = CurrencyUtils.format(item.averageCost);
      _lastCostController.text = CurrencyUtils.format(item.lastCost);
      _currentStockController.text = item.currentStock.toString();
      _minimumStockController.text = item.minimumStock.toString();
      _maximumStockController.text = item.maximumStock.toString();
      _selectedUnitOfMeasure = item.unitOfMeasure;
      _locationController.text = item.location ?? '';
      _shelfController.text = item.shelf ?? '';
      _binController.text = item.bin ?? '';
      _barcodeController.text = item.barcode ?? '';
      _qrCodeController.text = item.qrCode ?? '';
      _selectedSupplierId = item.supplierId;
      _isActive = item.isActive;
      _createdBy = item.createdBy;
      // ✅ NUEVO: Mostrar sección de estado solo en modo edición
      _showStatusSection = true;
    } else {
      // Modo creación - valores por defecto
      _currentStockController.text = ''; // ✅ MODIFICADO: Empezar vacío
      _minimumStockController.text = ''; // ✅ MODIFICADO: Empezar vacío
      _maximumStockController.text = ''; // ✅ MODIFICADO: Empezar vacío
      _initialCostController.text = ''; // ✅ NUEVO: Empezar vacío
      _unitCostController.text = ''; // ✅ NUEVO: Empezar vacío
      _averageCostController.text = '';
      _lastCostController.text = '';
    }
  }

  // === VALIDACIÓN DE SKU ===
  Future<void> _checkSkuAvailability(String sku) async {
    if (sku.trim().isEmpty) return;

    setState(() {
      _isCheckingSku = true;
      _skuSuggestions.clear();
    });

    try {
      final response = await InventoryApiService.checkSku(
        sku,
        excludeId: widget.item?.id,
        suggestAlternatives: true,
      );

      if (response.success && response.data != null) {
        setState(() {
          _skuIsAvailable = response.data!.isAvailable;
          if (!_skuIsAvailable &&
              response.data!.suggestedAlternatives != null) {
            _skuSuggestions =
                response.data!.suggestedAlternatives!
                    .map((alt) => alt['sku'] as String)
                    .toList();
          }
        });
      }
    } catch (e) {
      // Error en verificación, asumir disponible
      setState(() {
        _skuIsAvailable = true;
      });
    } finally {
      setState(() {
        _isCheckingSku = false;
      });
    }
  }

  // ✅ NUEVO MÉTODO - Mostrar sugerencias de SKU usando widget
  void _showSkuSuggestions() {
    if (_skuSuggestions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SKUs Disponibles Sugeridos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...(_skuSuggestions
                    .take(5)
                    .map(
                      (sku) => ListTile(
                        title: Text(sku),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          _skuController.text = sku;
                          _checkSkuAvailability(sku);
                          Navigator.pop(context);
                        },
                      ),
                    )),
              ],
            ),
          ),
    );
  }

  // ✅ NUEVO MÉTODO - Manejar cambio de estado del item
  Future<void> _handleStatusChange(bool newStatus) async {
    if (widget.item == null) return; // Solo disponible en modo edición

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => InventoryStatusChangeDialog(
            currentStatus: _isActive,
            itemName: widget.item!.name,
            itemSku: widget.item!.sku,
            onConfirm: (status, reason) async {
              await _performStatusChange(status, reason);
            },
          ),
    );

    if (confirmed != true) {
      // Si se canceló, revertir el switch
      setState(() {
        _isActive = !newStatus;
      });
    }
  }

  // ✅ NUEVO MÉTODO - Ejecutar cambio de estado
  Future<void> _performStatusChange(bool newStatus, String? reason) async {
    if (widget.item == null) return;

    setState(() {
      _isChangingStatus = true;
    });

    try {
      // Feedback háptico
      HapticFeedback.lightImpact();

      final response = await InventoryApiService.toggleItemStatus(
        itemId: widget.item!.id!,
        isActive: newStatus,
        reason: reason,
      );

      if (response.success) {
        setState(() {
          _isActive = newStatus;
        });

        if (mounted) {
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    newStatus ? Icons.check_circle : Icons.cancel,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      newStatus
                          ? 'Item activado exitosamente'
                          : 'Item inactivado exitosamente',
                    ),
                  ),
                ],
              ),
              backgroundColor: newStatus ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Deshacer',
                textColor: Colors.white,
                onPressed:
                    () =>
                        _performStatusChange(!newStatus, 'Operación deshecha'),
              ),
            ),
          );

          // Si se inactivó el item, preguntar si quiere volver a la lista
          if (!newStatus) {
            _showReturnToListDialog();
          }
        }
      } else {
        _showErrorDialog(
          response.message ?? 'Error al cambiar estado del item',
        );
        // Revertir el estado local
        setState(() {
          _isActive = !newStatus;
        });
      }
    } catch (e) {
      _showErrorDialog('Error inesperado: ${e.toString()}');
      // Revertir el estado local
      setState(() {
        _isActive = !newStatus;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChangingStatus = false;
        });
      }
    }
  }

  // ✅ NUEVO MÉTODO - Mostrar diálogo para volver a la lista
  void _showReturnToListDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Item Inactivado'),
              ],
            ),
            content: const Text(
              'El item ha sido inactivado exitosamente. Ya no aparecerá en las búsquedas normales.\n\n¿Deseas volver a la lista de inventario?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuar Editando'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context, true); // Volver a la lista
                },
                child: const Text('Volver a Lista'),
              ),
            ],
          ),
    );
  }

  // ✅ NUEVO MÉTODO - Validar si se puede guardar según el estado
  bool _canSaveItem() {
    // No permitir guardar si el item está inactivo y hay cambios pendientes sin confirmar
    if (widget.item != null && !_isActive && _hasUnsavedChanges()) {
      return false;
    }
    return true;
  }

  // ✅ NUEVO MÉTODO - Verificar si hay cambios sin guardar
  bool _hasUnsavedChanges() {
    if (widget.item == null) return true; // Nuevo item siempre tiene cambios

    final item = widget.item!;
    return _skuController.text != item.sku ||
        _nameController.text != item.name ||
        _descriptionController.text != (item.description ?? '') ||
        _brandController.text != (item.brand ?? '') ||
        _modelController.text != (item.model ?? '') ||
        _partNumberController.text != (item.partNumber ?? '') ||
        _selectedCategoryId != item.categoryId ||
        _selectedItemType != item.itemType ||
        CurrencyUtils.parse(_initialCostController.text) != item.initialCost || // ✅ NUEVO
        CurrencyUtils.parse(_unitCostController.text) != item.unitCost ||
        CurrencyUtils.parse(_averageCostController.text) != item.averageCost ||
        CurrencyUtils.parse(_lastCostController.text) != item.lastCost ||
        _currentStockController.text != item.currentStock.toString() ||
        _minimumStockController.text != item.minimumStock.toString() ||
        _maximumStockController.text != item.maximumStock.toString() ||
        _selectedUnitOfMeasure != item.unitOfMeasure ||
        _locationController.text != (item.location ?? '') ||
        _shelfController.text != (item.shelf ?? '') ||
        _binController.text != (item.bin ?? '') ||
        _barcodeController.text != (item.barcode ?? '') ||
        _qrCodeController.text != (item.qrCode ?? '') ||
        _selectedSupplierId != item.supplierId;
  }

  // === VALIDACIÓN DEL FORMULARIO ===
  Map<String, String> _validateForm() {
    Map<String, String> errors = {};

    // SKU
    if (_skuController.text.trim().isEmpty) {
      errors['sku'] = 'El SKU es requerido';
    } else if (!_skuIsAvailable) {
      errors['sku'] = 'Este SKU ya existe';
    }

    // Nombre
    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'El nombre es requerido';
    }

    // Costo inicial (compra)
    // Solo validar si estamos creando un nuevo item (no es modo edición)
    // En modo edición, este campo no se muestra y no se actualiza
    if (widget.item == null) {
    final initialCost = CurrencyUtils.parse(_initialCostController.text);
    if (_initialCostController.text.isEmpty || initialCost <= 0) {
      errors['initialCost'] = 'COSTO INICIAL: DEBE SER MAYOR A 0';
    }
    }

    final unitCost = CurrencyUtils.parse(_unitCostController.text);
    if (_unitCostController.text.isEmpty || unitCost <= 0) {
      errors['unitCost'] = 'PRECIO DE VENTA: DEBE SER MAYOR A 0';
    }

    // Validaciones numéricas para stock
    if (_currentStockController.text.isNotEmpty) {
      final currentStock = double.tryParse(_currentStockController.text);
      if (currentStock == null || currentStock <= 0) {
        errors['currentStock'] = 'STOCK ACTUAL: DEBE SER MAYOR A 0';
      }
    }

    if (_minimumStockController.text.isEmpty) {
      errors['minimumStock'] = 'EL STOCK MÍNIMO ES OBLIGATORIO Y DEBE SER MAYOR A 0';
    } else {
      final minimumStock = double.tryParse(_minimumStockController.text);
      if (minimumStock == null || minimumStock <= 0) {
        errors['minimumStock'] = 'STOCK MÍNIMO: DEBE SER MAYOR A 0';
      }
    }

    if (_maximumStockController.text.isNotEmpty) {
      final maximumStock = double.tryParse(_maximumStockController.text);
      if (maximumStock == null || maximumStock < 0) {
        errors['maximumStock'] = 'STOCK MÁXIMO: DEBE SER UN NÚMERO POSITIVO';
      }
    }

    // Validar relación min <= max
    final minStock = double.tryParse(_minimumStockController.text) ?? 0.0;
    final maxStock = double.tryParse(_maximumStockController.text) ?? 0.0;
    if (minStock > 0 && maxStock > 0 && minStock > maxStock) {
      errors['maximumStock'] = 'EL STOCK MÁXIMO NO PUEDE SER MENOR QUE EL STOCK MÍNIMO';
    }

    // Costo promedio y último costo (opcionales)
    if (_averageCostController.text.isNotEmpty) {
      final averageCost = CurrencyUtils.parse(_averageCostController.text);
      if (averageCost < 0) {
        errors['averageCost'] = 'COSTO PROMEDIO: DEBE SER UN NÚMERO POSITIVO';
      }
    }

    if (_lastCostController.text.isNotEmpty) {
      final lastCost = CurrencyUtils.parse(_lastCostController.text);
      if (lastCost < 0) {
        errors['lastCost'] = 'ÚLTIMO COSTO: DEBE SER UN NÚMERO POSITIVO';
      }
    }

    // Validación de Unidad de Medida (NUEVO)
    if (_selectedUnitOfMeasure.isEmpty) {
      errors['unitOfMeasure'] = 'LA UNIDAD DE MEDIDA ES OBLIGATORIA';
    }

    // Validación de Stock Actual (NUEVO - solo en creación)
    if (widget.item == null && _currentStockController.text.isEmpty) {
      errors['currentStock'] = 'EL STOCK ACTUAL ES OBLIGATORIO Y DEBE SER MAYOR A 0';
    }

    return errors;
  }

  // === MÉTODOS DE UI ===
  void _showValidationErrorsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ERRORES DE VALIDACIÓN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  _validationErrors.values
                      .map(
                        (error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $error'),
                        ),
                      )
                      .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ENTENDIDO'),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ERROR'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR'),
              ),
            ],
          ),
    );
  }

  // === GUARDAR FORMULARIO ===
  Future<void> _saveForm() async {
    // ✅ NUEVA VALIDACIÓN: Verificar si se puede guardar
    if (!_canSaveItem()) {
      _showErrorDialog(
        'No se puede guardar un item inactivo con cambios pendientes. Activa el item primero o descarta los cambios.',
      );
      return;
    }

    // ✅ Validación de permisos según operación
    final store = PermissionStore.instance;
    if (widget.item == null) {
      if (!store.can('inventario', 'crear')) {
        _showErrorDialog('No tienes permiso para crear items de inventario');
        return;
      }
    } else {
      if (!store.can('inventario', 'actualizar')) {
        _showErrorDialog(
          'No tienes permiso para actualizar items de inventario',
        );
        return;
      }
    }

    setState(() {
      _validationErrors = _validateForm();
    });

    if (_validationErrors.isNotEmpty) {
      _showValidationErrorsDialog();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final item = _buildItemFromForm();

      ApiResponse<InventoryItem> response;
      if (widget.item == null) {
        // Crear nuevo item
        response = await InventoryApiService.createItem(item);
      } else {
        // Actualizar item existente
        response = await InventoryApiService.updateItem(item);
      }

      if (response.success) {
        if (mounted) {
          Navigator.pop(context, true); // Indicar que se guardó exitosamente
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.item == null
                    ? 'Item creado exitosamente'
                    : 'Item actualizado exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ✅ MEJORA: Manejar errores específicos de la API (ej: SKU duplicado)
        if (response.hasErrors) {
          setState(() {
            // Actualizar mapa de errores para mostrar en el formulario
            _validationErrors = response.errors!.map(
              (key, value) => MapEntry(key, value.toString().toUpperCase()),
            );
          });
          // Mostrar diálogo con la lista de errores específicos
          _showValidationErrorsDialog();
        } else {
          _showErrorDialog(response.message ?? 'Error al guardar');
        }
      }
    } catch (e) {
      _showErrorDialog('Error inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InventoryItem _buildItemFromForm() {
    // Obtener nombres de categoría y proveedor de forma segura
    String? categoryName;
    String? supplierName;

    if (_selectedCategoryId != null) {
      try {
        categoryName =
            widget.categories
                .firstWhere(
                  (cat) =>
                      int.tryParse(cat.id.toString()) == _selectedCategoryId,
                )
                .name;
      } catch (e) {
        categoryName = null;
      }
    }

    if (_selectedSupplierId != null) {
      try {
        supplierName =
            widget.suppliers
                .firstWhere(
                  (sup) => int.tryParse(sup.id ?? '') == _selectedSupplierId,
                )
                .name;
      } catch (e) {
        supplierName = null;
      }
    }

    return InventoryItem(
      id: widget.item?.id,
      sku: _skuController.text.trim().toUpperCase(),
      name: _nameController.text.trim().toUpperCase(),
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim().toUpperCase(),
      categoryId: _selectedCategoryId,
      categoryName: categoryName?.toUpperCase(),
      itemType: _selectedItemType.toLowerCase(),
      brand:
          _brandController.text.trim().isEmpty
              ? null
              : _brandController.text.trim().toUpperCase(),
      model:
          _modelController.text.trim().isEmpty
              ? null
              : _modelController.text.trim().toUpperCase(),
      partNumber:
          _partNumberController.text.trim().isEmpty
              ? null
              : _partNumberController.text.trim().toUpperCase(),
      currentStock: double.tryParse(_currentStockController.text) ?? 0.0,
      minimumStock: double.tryParse(_minimumStockController.text) ?? 0.0,
      maximumStock: double.tryParse(_maximumStockController.text) ?? 0.0,
      unitOfMeasure: _selectedUnitOfMeasure.toLowerCase(),
      initialCost:
          CurrencyUtils.parse(_initialCostController.text), // ✅ NUEVO
      unitCost: CurrencyUtils.parse(_unitCostController.text),
      averageCost: CurrencyUtils.parse(_averageCostController.text),
      lastCost: CurrencyUtils.parse(_lastCostController.text),
      location:
          _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim().toUpperCase(),
      shelf:
          _shelfController.text.trim().isEmpty
              ? null
              : _shelfController.text.trim().toUpperCase(),
      bin:
          _binController.text.trim().isEmpty
              ? null
              : _binController.text.trim().toUpperCase(),
      barcode:
          _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim().toUpperCase(),
      qrCode:
          _qrCodeController.text.trim().isEmpty
              ? null
              : _qrCodeController.text.trim(),
      supplierId: _selectedSupplierId,
      supplierName: supplierName?.toUpperCase(),
      isActive: _isActive,
      createdBy: _createdBy,
      createdAt: widget.item?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // === WIDGET BUILD PRINCIPAL ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.item == null ? 'Crear Item' : 'Editar Item').toUpperCase()),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR para autocompletar',
            onPressed: _scanQrCode,
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: (_isSaving || _isChangingStatus) ? null : _saveForm,
              child: const Text(
                'GUARDAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'BÁSICO', icon: Icon(Icons.info_outline)),
            Tab(text: 'STOCK', icon: Icon(Icons.inventory)),
            Tab(text: 'UBICACIÓN', icon: Icon(Icons.location_on)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [_buildBasicTab(), _buildStockTab(), _buildLocationTab()],
        ),
      ),
    );
  }

  void _generateQrCode() {
    final sku = _skuController.text.trim();
    final name = _nameController.text.trim();
    final price = _unitCostController.text.trim();

    if (sku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El SKU es necesario para generar el código QR'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Generar JSON con datos básicos
    final qrData = '{"sku":"$sku","name":"$name","price":"$price"}';

    setState(() {
      _qrCodeController.text = qrData;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código QR generado con los datos del artículo'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Escanear QR del Artículo'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      Navigator.pop(context, barcode.rawValue);
                      break;
                    }
                  }
                },
              ),
            ),
      ),
    );

    if (result != null) {
      try {
        // Intentar parsear como JSON
        final Map<String, dynamic> data = jsonDecode(result);

        setState(() {
          if (data.containsKey('sku')) _skuController.text = data['sku'];
          if (data.containsKey('name')) _nameController.text = data['name'];
          if (data.containsKey('price')) {
            _unitCostController.text = data['price'];
          }

          // Verificar disponibilidad del SKU si se cargó uno nuevo
          if (data.containsKey('sku')) {
            _checkSkuAvailability(data['sku']);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos cargados desde QR correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Si falla el parseo JSON, asumir que es solo el SKU
        setState(() {
          _skuController.text = result;
          _checkSkuAvailability(result);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Código escaneado como SKU (formato no estándar detectado)',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // ✅ NUEVO MÉTODO - Escanear código de barras simple
  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Escanear Código de Barras'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      Navigator.pop(context, barcode.rawValue);
                      break;
                    }
                  }
                },
              ),
            ),
      ),
    );

    if (result != null) {
      setState(() {
        _barcodeController.text = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código de barras escaneado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // === TABS DEL FORMULARIO ===

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ SKU con validación usando nuevo widget
          InventorySkuField(
            controller: _skuController,
            focusNode: _focusNodes.isNotEmpty ? _focusNodes[0] : null,
            nextFocusNode: _focusNodes.length > 1 ? _focusNodes[1] : null,
            errorText: _validationErrors['sku'],
            isChecking: _isCheckingSku,
            isAvailable: _skuIsAvailable,
            suggestions: _skuSuggestions,
            onChanged: (value) {
              // Debounce para verificación de SKU
              Future.delayed(const Duration(milliseconds: 800), () {
                if (_skuController.text == value) {
                  _checkSkuAvailability(value);
                }
              });
            },
            onSuggestionsPressed: _showSkuSuggestions,
          ),
          const SizedBox(height: 16),

          // ✅ Nombre usando nuevo widget
          InventoryTextField(
            controller: _nameController,
            label: 'Nombre',
            hint: 'Nombre descriptivo del item',
            focusNode: _focusNodes.length > 1 ? _focusNodes[1] : null,
            nextFocusNode: _focusNodes.length > 2 ? _focusNodes[2] : null,
            errorText: _validationErrors['name'],
            isRequired: true,
          ),
          const SizedBox(height: 16),

          // ✅ Descripción usando nuevo widget
          InventoryTextField(
            controller: _descriptionController,
            label: 'Descripción',
            hint: 'Descripción detallada del item',
            focusNode: _focusNodes.length > 2 ? _focusNodes[2] : null,
            nextFocusNode: _focusNodes.length > 3 ? _focusNodes[3] : null,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // ✅ Categoría y Tipo en fila usando nuevos widgets
          Row(
            children: [
              Expanded(
                child: InventoryCategoryDropdown(
                  selectedCategoryId: _selectedCategoryId,
                  categories:
                      _localCategories, // Usar lista local que se actualiza
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  onAddPressed:
                      _showCreateCategoryDialog, // Callback para crear nueva
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InventoryDynamicDropdown(
                  value: _selectedItemType,
                  items: _existingTypes,
                  label: 'Tipo',
                  onChanged: (value) {
                    setState(() {
                      _selectedItemType = value;
                    });
                  },
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ Marca y Modelo en fila usando nuevos widgets
          Row(
            children: [
              Expanded(
                child: InventoryDynamicDropdown(
                  value:
                      _brandController.text.isNotEmpty
                          ? _brandController.text
                          : null,
                  items: _existingBrands,
                  label: 'Marca',
                  onChanged: (value) {
                    setState(() {
                      _brandController.text = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InventoryTextField(
                  controller: _modelController,
                  label: 'Modelo',
                  hint: 'Modelo del producto',
                  focusNode: _focusNodes.length > 5 ? _focusNodes[5] : null,
                  nextFocusNode: _focusNodes.length > 6 ? _focusNodes[6] : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ Número de parte usando nuevo widget
          InventoryTextField(
            controller: _partNumberController,
            label: 'Número de Parte',
            hint: 'Número de parte del fabricante',
            focusNode: _focusNodes.length > 6 ? _focusNodes[6] : null,
            nextFocusNode: _focusNodes.length > 7 ? _focusNodes[7] : null,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),

          // ✅ Proveedor usando nuevo widget mejorado
          InventorySupplierSelector(
            selectedSupplierId: _selectedSupplierId,
            initialSuppliers: widget.suppliers,
            onSupplierChanged: (supplier) {
              setState(() {
                _selectedSupplierId =
                    supplier != null ? int.tryParse(supplier.id) : null;
              });
            },
            onMessage: (message, isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : Icons.error,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(message)),
                    ],
                  ),
                  backgroundColor: isSuccess ? Colors.green : Colors.red,
                  duration: Duration(seconds: isSuccess ? 3 : 4),
                ),
              );
            },
            validator: (value) {
              // Agregar validaciones si son necesarias
              // Ejemplo: if (value == null) return 'Proveedor requerido';
              return null;
            },
            enabled: !_isSaving,
          ),
          const SizedBox(height: 16),

          // ✅ Sección de precios usando nuevo widget
          InventoryPriceSection(
            unitCostController: _unitCostController,
            initialCostController: _initialCostController,
            averageCostController: _averageCostController,
            lastCostController: _lastCostController,
            focusNodes: _focusNodes,
            validationErrors: _validationErrors,
            isEditMode: widget.item != null,
          ),
          const SizedBox(height: 16),

          // ✅ NUEVA SECCIÓN: Estado del item (solo en modo edición)
          if (_showStatusSection && widget.item != null)
            InventoryItemStatusWidget(
              isActive: _isActive,
              isLoading: _isChangingStatus,
              onStatusChanged: _handleStatusChange,
              showToggle: true,
            ),
          const SizedBox(height: 16),

          // ✅ Códigos de barras y botón QR (Solo disponible en edición)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: InventoryTextField(
                  controller: _barcodeController,
                  label: 'Código de Barras',
                  hint: 'Código de barras del producto',
                  focusNode: _focusNodes.length > 10 ? _focusNodes[10] : null,
                  nextFocusNode:
                      _focusNodes.length > 11 ? _focusNodes[11] : null,
                  keyboardType: TextInputType.number,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Escanear código de barras',
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              if (widget.item != null) ...[
                const SizedBox(width: 16),
                // ✅ Botón para generar QR
                ElevatedButton.icon(
                  onPressed: _generateQrCode,
                  icon: const Icon(Icons.qr_code_2, color: Colors.white),
                  label: const Text(
                    'Generar QR',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ✅ NUEVO: Mostrar imagen del código QR si hay datos (Solo edición)
          if (widget.item != null && _qrCodeController.text.isNotEmpty)
            Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _qrCodeController.text,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escanea este código',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // ✅ MODIFICADO: Estado activo mejorado para nuevos items
          if (widget.item ==
              null) // Solo mostrar switch simple para nuevos items
            SwitchListTile(
              title: const Text('ITEM ACTIVO'),
              subtitle: const Text('EL ITEM ESTARÁ DISPONIBLE PARA USO'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ✅ Unidad de medida usando nuevo widget
          InventoryUnitDropdown(
            selectedUnit: _selectedUnitOfMeasure,
            isRequired: true,
            errorText: _validationErrors['unitOfMeasure'],
            onChanged: (value) {
              setState(() {
                _selectedUnitOfMeasure = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // ✅ Stock actual y mínimo usando nuevos widgets
          Row(
            children: [
              Expanded(
                child: InventoryNumberField(
                  controller: _currentStockController,
                  label: 'Stock Actual',
                  isDecimal: true,
                  focusNode: _focusNodes.length > 12 ? _focusNodes[12] : null,
                  nextFocusNode:
                      _focusNodes.length > 13 ? _focusNodes[13] : null,
                  errorText: _validationErrors['currentStock'],
                  onChanged: () => setState(() {}), // Para actualizar preview
                  enabled: widget.item == null,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InventoryNumberField(
                  controller: _minimumStockController,
                  label: 'Stock Mínimo',
                  isDecimal: true,
                  focusNode: _focusNodes.length > 13 ? _focusNodes[13] : null,
                  nextFocusNode:
                      _focusNodes.length > 14 ? _focusNodes[14] : null,
                  errorText: _validationErrors['minimumStock'],
                  onChanged: () => setState(() {}), // Para actualizar preview
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ✅ Stock máximo usando nuevo widget
          InventoryNumberField(
            controller: _maximumStockController,
            label: 'Stock Máximo',
            isDecimal: true,
            focusNode: _focusNodes.length > 14 ? _focusNodes[14] : null,
            errorText: _validationErrors['maximumStock'],
            onChanged: () => setState(() {}), // Para actualizar preview
          ),
          const SizedBox(height: 16),

          // ✅ Preview del estado del stock usando nuevo widget
          InventoryStockPreview(
            currentStock: double.tryParse(_currentStockController.text) ?? 0.0,
            minimumStock: double.tryParse(_minimumStockController.text) ?? 0.0,
            maximumStock: double.tryParse(_maximumStockController.text),
          ),
          const SizedBox(height: 16),

          // ✅ NUEVA INFORMACIÓN: Advertencia para items inactivos
          if (!_isActive)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ITEM INACTIVO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        Text(
                          'ESTE ITEM ESTÁ INACTIVO. LOS MOVIMIENTOS DE STOCK ESTÁN RESTRINGIDOS.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Tarjeta de Ubicación Principal para mejor jerarquía visual
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warehouse, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'ALMACENAMIENTO PRINCIPAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ✅ Ubicación general con sugerencias rápidas (Chips)
                  InventoryTextField(
                    controller: _locationController,
                    label: 'Ubicación General',
                    hint: 'Ej: Bodega Central, Tienda, Showroom',
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  // ✅ Chips de selección rápida para evitar errores de tipeo
                  if (_existingLocations.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _existingLocations
                              .map((location) => _buildLocationChip(location))
                              .toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ Tarjeta de Ubicación Específica (Estante/Bin)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_4x4, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'COORDENADAS ESPECÍFICAS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ✅ Estante y Bin con formato forzado a Mayúsculas
                  Row(
                    children: [
                      Expanded(
                        child: InventoryTextField(
                          controller: _shelfController,
                          label: 'Estante / Pasillo',
                          hint: 'Ej: A-01',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9\-]'),
                            ),
                          ],
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InventoryTextField(
                          controller: _binController,
                          label: 'Bin / Nivel',
                          hint: 'Ej: N2',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9\-]'),
                            ),
                          ],
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use mayúsculas y guiones para estandarizar (Ej: A-1)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ✅ Preview de ubicación completa usando nuevo widget
          InventoryLocationPreview(
            location:
                _locationController.text.trim().isEmpty
                    ? null
                    : _locationController.text.trim(),
            shelf:
                _shelfController.text.trim().isEmpty
                    ? null
                    : _shelfController.text.trim(),
            bin:
                _binController.text.trim().isEmpty
                    ? null
                    : _binController.text.trim(),
          ),
        ],
      ),
    );
  }

  // ✅ Helper para chips de ubicación
  Widget _buildLocationChip(String label) {
    final isSelected = _locationController.text == label;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.grey.shade800,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      avatar:
          isSelected
              ? const Icon(Icons.check, size: 16, color: Colors.blue)
              : null,
      onPressed: () {
        setState(() {
          _locationController.text = label;
        });
      },
    );
  }

  // ✅ NUEVO MÉTODO: Mostrar información sobre cambios en items inactivos
  void _showInactiveItemWarning() {
    if (!_isActive && _hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Item Inactivo'),
                ],
              ),
              content: const Text(
                'Este item está inactivo. Algunos cambios podrían no tener efecto hasta que el item sea reactivado.\n\n¿Deseas activar el item para aplicar los cambios?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleStatusChange(true);
                  },
                  child: const Text('Activar Item'),
                ),
              ],
            ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mostrar advertencia si hay cambios en item inactivo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.item != null && !_isActive && _hasUnsavedChanges()) {
        _showInactiveItemWarning();
      }
    });
  }
} // Cierre de la clase principal _InventoryFormPageState
