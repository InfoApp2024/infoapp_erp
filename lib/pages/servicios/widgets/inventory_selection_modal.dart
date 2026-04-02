// lib/pages/servicios/widgets/inventory_selection_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../services/servicio_repuestos_api_service.dart';
import '../models/servicio_repuesto_model.dart';

/// Modal para buscar y seleccionar repuestos del inventario.
/// Permite asignar múltiples repuestos a un servicio con cantidades específicas.
class InventorySelectionModal extends StatefulWidget {
  final int servicioId;
  final List<ServicioRepuestoModel> repuestosYaAsignados;
  final String? numeroOrden; // ✅ NUEVO
  final Function(List<ServicioRepuestoModel>)?
  onRepuestosSeleccionados; // ✅ NUEVO
  final VoidCallback? onRepuestosActualizados; // ✅ NUEVO
  final int? fixedOperacionId; // ✅ NUEVO
  final bool enabled; // ✅ NUEVO

  const InventorySelectionModal({
    super.key,
    required this.servicioId,
    required this.repuestosYaAsignados,
    this.numeroOrden, // ✅ NUEVO
    this.onRepuestosSeleccionados, // ✅ NUEVO
    this.onRepuestosActualizados, // ✅ NUEVO
    this.fixedOperacionId, // ✅ NUEVO
    this.enabled = true, // ✅ NUEVO
    @Deprecated('Use onRepuestosSeleccionados instead')
    Function(List<Map<String, dynamic>>)? onItemsSelected,
  });

  @override
  State<InventorySelectionModal> createState() =>
      _InventorySelectionModalState();
}

class _InventorySelectionModalState extends State<InventorySelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ✅ Controladores persistentes para cada item
  final Map<int, TextEditingController> _quantityControllers = {};

  List<InventoryItem> _items = [];
  final Map<int, double> _selectedQuantities = {};
  final Set<int> _selectedIds = {};

  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();

    // ✅ FIX 1: Pre-cargar SOLO cantidades de la operación actual
    for (final repuesto in widget.repuestosYaAsignados) {
      if (repuesto.operacionId == widget.fixedOperacionId) {
        _selectedIds.add(repuesto.inventoryItemId);
        _selectedQuantities[repuesto.inventoryItemId] = repuesto.cantidad;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItems();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    // Limpiar todos los controladores de cantidad
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    _quantityControllers.clear();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadItems();
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _items = [];
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final response = await ServicioRepuestosApiService.listarRepuestosDisponibles(
        search: _searchController.text.trim(),
        limit: _limit,
        offset: _offset,
        soloConStock:
            false, // Mostrar todo para poder pedir aunque no haya stock "teórico"
      );

      if (response.success && response.data != null) {
        setState(() {
          final newItems = response.data!;
          _items.addAll(newItems);
          _offset += newItems.length;
          _hasMore = newItems.length >= _limit;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        _handleError("Error cargando repuestos: $e");
      }
    }
  }

  void _handleError(String message) {
    if (!mounted) return;

    String friendlyMessage = message;

    // Si contiene JSON de error del backend, intentar extraer solo el 'message'
    if (message.contains('{"success":false')) {
      try {
        final startIndex = message.indexOf('{');
        final jsonStr = message.substring(startIndex);
        final data = json.decode(jsonStr);
        if (data is Map && data.containsKey('message')) {
          friendlyMessage = data['message'];
        }
      } catch (_) {
        // Ignorar error de parseo y usar original
      }
    } else {
      // Limpiar prefijo "Exception: Error HTTP 403: " si existe
      friendlyMessage = friendlyMessage.replaceAll(
        RegExp(r'^Exception: Error HTTP \d+: '),
        '',
      );
    }

    final lowerMessage = friendlyMessage.toLowerCase();
    bool isBlocked =
        lowerMessage.contains('legalizado') ||
        lowerMessage.contains('final') ||
        lowerMessage.contains('cancelado') ||
        lowerMessage.contains('terminal');

    if (isBlocked) {
      friendlyMessage =
          'No se permiten realizar cambios en este servicio porque ya se encuentra en un estado final (LEGALIZADO/CANCELADO).\n\n'
          'Si necesitas hacer un ajuste, debes solicitar al área administrativa que retornen el servicio desde Gestión Financiera.';
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  isBlocked ? Icons.lock : Icons.error_outline,
                  color: isBlocked ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  isBlocked ? 'Acción Bloqueada' : 'Error',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(friendlyMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  // ✅ PUNTO 1 & 4: Permitir toggle solo si hay stock O si ya está seleccionado
  void _toggleSelection(InventoryItem item) {
    if (item.id == null) return;

    // PUNTO 1: No permitir agregar si stock = 0 (pero sí permitir quitar)
    if (item.currentStock <= 0 && !_selectedIds.contains(item.id!)) {
      return; // No hacer nada si no hay stock y no está seleccionado
    }

    setState(() {
      if (_selectedIds.contains(item.id!)) {
        _selectedIds.remove(item.id!);
        _selectedQuantities.remove(item.id!);
      } else {
        _selectedIds.add(item.id!);
        // PUNTO 2 & 3: Inicializar con 1.0 o 1 según el tipo de unidad
        _selectedQuantities[item.id!] =
            _isIntegerUnit(item.unitOfMeasure) ? 1.0 : 1.0;
      }
    });
  }

  // ✅ PUNTO 2: Determinar si la unidad requiere valores enteros
  bool _isIntegerUnit(String unit) {
    final integerUnits = [
      'unidad',
      'und',
      'pza',
      'pieza',
      'kg',
      'kilogramo',
      'gr',
      'gramo',
    ];
    return integerUnits.any((u) => unit.toLowerCase().contains(u));
  }

  // ✅ PUNTO 2 & 3: Actualizar cantidad según tipo de unidad
  void _updateQuantity(
    int itemId,
    double delta, {
    required bool isIntegerUnit,
  }) {
    setState(() {
      final current = _selectedQuantities[itemId] ?? 1.0;
      final newValue = current + delta;

      if (isIntegerUnit) {
        // Para unidades enteras: incrementos de 1
        if (newValue >= 1.0) {
          _selectedQuantities[itemId] = newValue.roundToDouble();
        }
      } else {
        // Para unidades decimales: permitir 0.01 como mínimo (2 decimales)
        if (newValue >= 0.01) {
          _selectedQuantities[itemId] = double.parse(
            newValue.toStringAsFixed(2),
          );
        }
      }
    });
  }

  void _confirmSelection() async {
    if (_selectedIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<ServicioRepuestoModel> todosLosRepuestos = [];

      // ✅ Separar items NUEVOS vs EXISTENTES
      final List<Map<String, dynamic>> itemsNuevos = [];
      final List<int> itemsExistentes = [];

      // ✅ NUEVA LÓGICA SYNC: Enviar todos los seleccionados para esta operación.
      // El backend se encarga de: restauración de stock, delete de antiguos y re-inserción.
      for (final id in _selectedIds) {
        final qty = _selectedQuantities[id] ?? 1.0;
        itemsNuevos.add({
          'inventory_item_id': id,
          'cantidad': qty,
          'operacion_id': widget.fixedOperacionId,
        });
      }

      // Asignar items nuevos en batch
      if (itemsNuevos.isNotEmpty) {
        final resAsignar =
            await ServicioRepuestosApiService.asignarRepuestosAServicio(
              servicioId: widget.servicioId,
              repuestos: itemsNuevos,
            );

        if (resAsignar.success && resAsignar.data != null) {
          todosLosRepuestos.addAll(resAsignar.data!);
        } else {
          _handleError(
            resAsignar.error ?? 'Error desconocido al asignar repuestos',
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (widget.onRepuestosSeleccionados != null) {
        widget.onRepuestosSeleccionados!(todosLosRepuestos);
      }

      if (widget.onRepuestosActualizados != null) {
        widget.onRepuestosActualizados!();
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error al asignar: $e";
          _isLoading = false;
        });
        _handleError("Error al asignar repuestos: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.enabled
                      ? 'Seleccionar Repuestos'
                      : 'Repuestos Utilizados',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedIds.length} seleccionados',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código...',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) => _loadItems(refresh: true),
            ),
          ),

          // List
          Expanded(
            child:
                _isLoading && _items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _items.isEmpty
                    ? _buildErrorPlaceholder()
                    : _items.isEmpty
                    ? _buildEmptyPlaceholder()
                    : _buildItemsList(primaryColor),
          ),

          // Footer
          _buildFooter(primaryColor),
        ],
      ),
    );
  }

  Widget _buildItemsList(Color primaryColor) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final item = _items[index];
        final isSelected = _selectedIds.contains(item.id);

        // ✅ PUNTO 4: Verificar si ya está en el servicio (y en qué operación)
        final isAlreadyInService = widget.repuestosYaAsignados.any(
          (r) => r.inventoryItemId == item.id,
        );

        final isAlreadyInOtherOp = widget.repuestosYaAsignados.any(
          (r) =>
              r.inventoryItemId == item.id &&
              r.operacionId != widget.fixedOperacionId,
        );

        return _buildItemCard(
          item,
          isSelected,
          isAlreadyInService,
          isAlreadyInOtherOp,
          primaryColor,
        );
      },
    );
  }

  Widget _buildItemCard(
    InventoryItem item,
    bool isSelected,
    bool isAlreadyInService,
    bool isAlreadyInOtherOp,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? primaryColor
                  : isAlreadyInService
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: _buildItemIcon(item, primaryColor),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(PhosphorIcons.barcode(), size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(item.sku, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(PhosphorIcons.package(), size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Stock: ${item.currentStock} ${item.unitOfMeasure}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            item.currentStock <= 0
                                ? Colors.red
                                : Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (isAlreadyInService) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isAlreadyInOtherOp
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAlreadyInOtherOp
                          ? 'YA EN OTRA OPERACIÓN'
                          : 'EN ESTA OPERACIÓN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAlreadyInOtherOp ? Colors.orange : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Checkbox(
              value: isSelected,
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              // ✅ PUNTO 1: Deshabilitar si no hay stock Y no está seleccionado, o si está deshabilitado globalmente
              onChanged:
                  (item.currentStock <= 0 && !isSelected) || !widget.enabled
                      ? null
                      : (_) => _toggleSelection(item),
            ),
            // ✅ PUNTO 4: Permitir tap incluso si ya está en servicio (para editar) si está habilitado
            onTap:
                (item.currentStock <= 0 && !isSelected) || !widget.enabled
                    ? null
                    : () => _toggleSelection(item),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Cantidad a asignar:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _buildQuantitySelector(item.id!, primaryColor),
                    ],
                  ),
                  // ✅ FIX 3: Validación de stock
                  if (_selectedQuantities[item.id!] != null &&
                      _selectedQuantities[item.id!]! > item.currentStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange[700],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Excede el stock disponible (${item.currentStock.toStringAsFixed(item.unitOfMeasure.toLowerCase().contains('litro') || item.unitOfMeasure.toLowerCase().contains('metro') ? 2 : 0)} ${item.unitOfMeasure})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
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

  Widget _buildItemIcon(InventoryItem item, Color primaryColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        PhosphorIcons.wrench(),
        color: primaryColor.withOpacity(0.7),
        size: 24,
      ),
    );
  }

  Widget _buildQuantitySelector(int itemId, Color primaryColor) {
    final item = _items.firstWhere((i) => i.id == itemId);
    final isIntegerUnit = _isIntegerUnit(item.unitOfMeasure);
    final qty = _selectedQuantities[itemId] ?? 1.0;

    // ✅ Obtener o crear controlador persistente para este item
    if (!_quantityControllers.containsKey(itemId)) {
      _quantityControllers[itemId] = TextEditingController();
    }
    final controller = _quantityControllers[itemId]!;

    // Actualizar el texto solo si es diferente (evita recrear)
    final expectedText =
        isIntegerUnit ? qty.toInt().toString() : qty.toStringAsFixed(2);
    if (controller.text != expectedText) {
      controller.value = TextEditingValue(
        text: expectedText,
        selection: TextSelection.collapsed(offset: expectedText.length),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQtyBtn(
          PhosphorIcons.minus(),
          !widget.enabled
              ? null
              : () => _updateQuantity(
                itemId,
                isIntegerUnit ? -1 : -0.1,
                isIntegerUnit: isIntegerUnit,
              ),
          primaryColor,
        ),
        // ✅ Campo editable con controlador persistente
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: controller,
            readOnly: !widget.enabled, // ✅ MODO LECTURA
            keyboardType: TextInputType.numberWithOptions(
              decimal: !isIntegerUnit,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              if (value.isEmpty) return; // Permitir borrar temporalmente

              final parsed = double.tryParse(value);
              if (parsed != null && parsed > 0) {
                setState(() {
                  if (isIntegerUnit) {
                    _selectedQuantities[itemId] = parsed.roundToDouble();
                  } else {
                    // Permitir hasta 2 decimales
                    final rounded = double.parse(parsed.toStringAsFixed(2));
                    _selectedQuantities[itemId] = rounded;
                  }
                });
              }
            },
            onSubmitted: (value) {
              // Al terminar de editar, asegurar valor mínimo
              final parsed = double.tryParse(value);
              if (parsed == null || parsed <= 0) {
                setState(() {
                  _selectedQuantities[itemId] = isIntegerUnit ? 1.0 : 0.1;
                });
              }
            },
          ),
        ),
        _buildQtyBtn(
          PhosphorIcons.plus(),
          !widget.enabled
              ? null
              : () => _updateQuantity(
                itemId,
                isIntegerUnit ? 1 : 0.1,
                isIntegerUnit: isIntegerUnit,
              ),
          primaryColor,
        ),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap, Color primaryColor) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[100] : Colors.white,
          border: Border.all(
            color: onTap == null ? Colors.grey[200]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey[400] : primaryColor,
        ),
      ),
    );
  }

  Widget _buildFooter(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(widget.enabled ? 'Cancelar' : 'Cerrar'),
            ),
          ),
          if (widget.enabled) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty ? null : _confirmSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedIds.isEmpty
                      ? 'Seleccionar'
                      : 'Confirmar (${_selectedIds.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.package(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No se encontraron repuestos',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadItems(refresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
