// lib/pages/inventory/widgets/inventory_supplier_widgets.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';

// Importar los modelos y servicios
import '../models/inventory_supplier_model.dart';
import '../models/inventory_form_data_models.dart';
import '../services/inventory_api_service.dart';

/// =====================================================
/// INFORMACIÓN SOBRE ESTE ARCHIVO DE WIDGETS DE PROVEEDORES
/// =====================================================
///
/// Este archivo contiene todos los widgets especializados para la gestión
/// completa de proveedores en el formulario de inventario.
///
/// PATRÓN IMPLEMENTADO:
/// - Inspirado en CampoAutorizadoPor para máxima usabilidad
/// - Búsqueda inteligente con overlay personalizado
/// - Panel expandible para gestión CRUD
/// - Triple clic para mostrar todas las opciones
/// - Estados de carga y validaciones integradas
///
/// WIDGETS INCLUIDOS:
/// - InventorySupplierSelector: Widget principal con patrón mejorado
/// - SupplierSearchableDropdown: Dropdown con búsqueda avanzada
/// - DeleteSupplierDialog: Diálogo especializado para eliminación
///
/// FUNCIONALIDADES:
/// - Selección con búsqueda inteligente (mínimo 3 caracteres)
/// - Creación de nuevos proveedores inline
/// - Edición de proveedores existentes
/// - Eliminación con gestión de dependencias
/// - Transferencia de items entre proveedores
/// - Validaciones completas
/// - Mensajes de éxito/error
///
/// DONDE SE UTILIZA:
/// - Principalmente en InventoryFormPage
/// - Reutilizable en cualquier formulario que necesite gestión de proveedores
/// =====================================================

/// Callbacks para manejo de eventos de proveedores
typedef SupplierCallback = Function(InventorySupplier? supplier);
typedef SupplierActionCallback = Function(InventorySupplier supplier);
typedef VoidCallback = Function();
typedef MessageCallback = Function(String message, bool isSuccess);

/// Widget principal para la gestión completa de proveedores con patrón mejorado
/// Widget principal para la gestión completa de proveedores con patrón profesional de ModalBottomSheet
class InventorySupplierSelector extends StatefulWidget {
  final int? selectedSupplierId;
  final List<InventorySupplier> initialSuppliers;
  final SupplierCallback onSupplierChanged;
  final MessageCallback? onMessage;
  final String? Function(int?)? validator;
  final bool enabled;
  final bool isRequired;

  const InventorySupplierSelector({
    super.key,
    this.selectedSupplierId,
    required this.initialSuppliers,
    required this.onSupplierChanged,
    this.onMessage,
    this.validator,
    this.enabled = true,
    this.isRequired = false,
  });

  @override
  State<InventorySupplierSelector> createState() =>
      _InventorySupplierSelectorState();
}

class _InventorySupplierSelectorState extends State<InventorySupplierSelector> {
  // Estado interno
  List<InventorySupplier> _suppliers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await InventoryApiService.getSuppliers(
        includeInactive: false,
        limit: 100,
      );

      if (response.success && response.data != null && mounted) {
        setState(() => _suppliers = response.data!.suppliers);
      } else if (mounted) {
        _showError('Error cargando proveedores: ${response.message}');
      }
    } catch (e) {
      if (mounted) _showError('Error cargando proveedores: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String mensaje) {
    widget.onMessage?.call(mensaje, false);
  }

  void _showSuccess(String mensaje) {
    widget.onMessage?.call(mensaje, true);
  }

  // Obtener el proveedor seleccionado
  InventorySupplier? get _selectedSupplier {
    if (widget.selectedSupplierId == null) return null;
    try {
      return _suppliers.firstWhere(
        (s) => int.tryParse(s.id) == widget.selectedSupplierId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleAddSupplier() async {
    final result = await showDialog<InventorySupplier>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SupplierFormDialog(),
    );
    if (result != null) {
      await _loadSuppliers();
      widget.onSupplierChanged(result);
    }
  }

  Future<void> _prepareEditSupplier(InventorySupplier supplier) async {
    final result = await showDialog<InventorySupplier>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SupplierFormDialog(supplierEditando: supplier),
    );
    if (result != null) {
      await _loadSuppliers();
      if (widget.selectedSupplierId != null &&
          result.id == widget.selectedSupplierId.toString()) {
        widget.onSupplierChanged(result);
      }
    }
  }

  Future<void> _deleteSupplier(InventorySupplier supplier) async {
    final checkResponse = await InventoryApiService.checkSupplierDependencies(
      id: int.parse(supplier.id),
    );

    bool canDelete = false;
    int itemsCount = 0;

    if (checkResponse.success) {
      canDelete = checkResponse.data?['can_delete'] ?? false;
      itemsCount = checkResponse.data?['items_count'] ?? 0;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => DeleteSupplierDialog(
            supplier: supplier,
            canDelete: canDelete,
            itemsCount: itemsCount,
            availableSuppliers:
                _suppliers.where((s) => s.id != supplier.id).toList(),
          ),
    );

    if (confirmed == true) {
      await _loadSuppliers();
      if (widget.selectedSupplierId?.toString() == supplier.id) {
        widget.onSupplierChanged(null);
      }
      _showSuccess('Proveedor "${supplier.name}" eliminado exitosamente');
    }
  }

  void _showSuppliersModal() {
    if (!widget.enabled) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuppliersBottomSheet(
        suppliers: _suppliers,
        selectedId: widget.selectedSupplierId,
        onSelected: (supplier) {
          widget.onSupplierChanged(supplier);
          Navigator.pop(context);
        },
        onAdd: _handleAddSupplier,
        onEdit: _prepareEditSupplier,
        onDelete: _deleteSupplier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _selectedSupplier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _showSuppliersModal,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.business_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isRequired ? 'PROVEEDOR *' : 'PROVEEDOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (supplier?.name ?? 'SELECCIONAR PROVEEDOR').toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              supplier == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.6)
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (supplier?.contactName != null &&
                          supplier!.contactName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          supplier.contactName!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (widget.validator != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Builder(
              builder: (context) {
                final error = widget.validator!(widget.selectedSupplierId);
                if (error == null) return const SizedBox.shrink();
                return Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SuppliersBottomSheet extends StatefulWidget {
  final List<InventorySupplier> suppliers;
  final int? selectedId;
  final Function(InventorySupplier) onSelected;
  final VoidCallback onAdd;
  final Function(InventorySupplier) onEdit;
  final Function(InventorySupplier) onDelete;

  const _SuppliersBottomSheet({
    required this.suppliers,
    this.selectedId,
    required this.onSelected,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SuppliersBottomSheet> createState() => _SuppliersBottomSheetState();
}

class _SuppliersBottomSheetState extends State<_SuppliersBottomSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventorySupplier> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return widget.suppliers;
    return widget.suppliers.where((s) {
      final searchLower = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(searchLower) ||
          (s.contactName?.toLowerCase().contains(searchLower) ?? false) ||
          (s.email?.toLowerCase().contains(searchLower) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Barra de arrastre y título
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SELECCIONAR PROVEEDOR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buscador profesional
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'BUSCAR POR NOMBRE O CONTACTO...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botón Agregar Nuevo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                widget.onAdd();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_business_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'AGREGAR NUEVO PROVEEDOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lista de proveedores
          Expanded(
            child:
                _filteredSuppliers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_center_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'NO SE ENCONTRARON PROVEEDORES',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSuppliers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final supplier = _filteredSuppliers[index];
                        final isSelected =
                            supplier.id == widget.selectedId?.toString();

                        return _SupplierItemCard(
                          supplier: supplier,
                          isSelected: isSelected,
                          onTap: () => widget.onSelected(supplier),
                          onEdit: () => widget.onEdit(supplier),
                          onDelete: () => widget.onDelete(supplier),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SupplierItemCard extends StatelessWidget {
  final InventorySupplier supplier;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierItemCard({
    required this.supplier,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200]!,
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
        child: Row(
          children: [
            // Avatar progresivo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  supplier.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black87,
                    ),
                  ),
                  if (supplier.contactName != null)
                    Text(
                      supplier.contactName!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7) : Colors.grey[600],
                      ),
                    ),
                  if (supplier.email != null)
                    Text(
                      supplier.email!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7) : Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            // Acciones compactas
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// CONTINUACIÓN DE LA PARTE 3...

/// Diálogo mejorado para eliminar proveedores con gestión avanzada de dependencias
class DeleteSupplierDialog extends StatefulWidget {
  final InventorySupplier supplier;
  final bool canDelete;
  final int itemsCount;
  final List<InventorySupplier> availableSuppliers;

  const DeleteSupplierDialog({
    super.key,
    required this.supplier,
    required this.canDelete,
    required this.itemsCount,
    required this.availableSuppliers,
  });

  @override
  State<DeleteSupplierDialog> createState() => _DeleteSupplierDialogState();
}

class _DeleteSupplierDialogState extends State<DeleteSupplierDialog> {
  bool _forceDelete = false;
  bool _softDelete = true;
  InventorySupplier? _transferTo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Si hay proveedores disponibles para transferencia, seleccionar el primero por defecto
    if (widget.availableSuppliers.isNotEmpty && widget.itemsCount > 0) {
      _transferTo = widget.availableSuppliers.first;
    }
  }

  Future<void> _confirmDelete() async {
    setState(() => _isLoading = true);

    try {
      final response = await InventoryApiService.deleteSupplier(
        id: int.parse(widget.supplier.id),
        force: _forceDelete,
        softDelete: _softDelete,
        transferItemsTo:
            _transferTo != null ? int.parse(_transferTo!.id) : null,
      );

      if (response.success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showError(response.message ?? 'Error al eliminar proveedor');
      }
    } catch (e) {
      _showError('Error inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: context.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  bool _canProceedWithDeletion() {
    if (widget.itemsCount == 0) return true;
    if (_forceDelete) return true;
    if (_transferTo != null) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: context.errorColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eliminar Proveedor',
                  style: TextStyle(
                    color: context.errorColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.supplier.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del proveedor
              _buildSupplierInfo(),

              if (widget.itemsCount > 0) ...[
                const SizedBox(height: 16),
                _buildItemsWarning(),
                const SizedBox(height: 16),
                _buildItemsHandlingOptions(),
                const SizedBox(height: 16),
              ],

              _buildDeletionTypeOptions(),

              if (!_canProceedWithDeletion()) ...[
                const SizedBox(height: 16),
                _buildWarningMessage(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed:
              _isLoading || !_canProceedWithDeletion() ? null : _confirmDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.errorColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _softDelete
                            ? Icons.visibility_off
                            : Icons.delete_forever,
                      ),
                      const SizedBox(width: 8),
                      Text(_softDelete ? 'Desactivar' : 'Eliminar'),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildSupplierInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.1),
            child: Text(
              widget.supplier.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplier.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (widget.supplier.contactName != null &&
                    widget.supplier.contactName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.supplier.contactName!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.supplier.email != null &&
                    widget.supplier.email!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.supplier.email!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.supplier.phone != null &&
                    widget.supplier.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.supplier.phone!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.warningColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, color: context.warningColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items Asociados',
                      style: TextStyle(
                        color: context.warningColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Este proveedor tiene ${widget.itemsCount} items asociados',
                      style: TextStyle(
                        color: context.warningColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.warningColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Debes decidir qué hacer con estos items antes de proceder con la eliminación.',
                    style: TextStyle(
                      color: context.warningColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsHandlingOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opciones para los items asociados:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (widget.availableSuppliers.isNotEmpty) ...[
            RadioListTile<String>(
              title: const Text('Transferir a otro proveedor'),
              subtitle: const Text(
                'Los items serán reasignados al proveedor seleccionado',
              ),
              value: 'transfer',
              groupValue: _transferTo != null ? 'transfer' : null,
              onChanged: (value) {
                setState(() {
                  _forceDelete = false;
                  if (widget.availableSuppliers.isNotEmpty) {
                    _transferTo = widget.availableSuppliers.first;
                  }
                });
              },
            ),
            if (_transferTo != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proveedor destino:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<InventorySupplier>(
                        initialValue: _transferTo,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        items:
                            widget.availableSuppliers.map((supplier) {
                              return DropdownMenuItem(
                                value: supplier,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1),
                                      child: Text(
                                        supplier.name
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            supplier.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (supplier.contactName != null &&
                                              supplier.contactName!.isNotEmpty)
                                            Text(
                                              supplier.contactName!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                        onChanged: (supplier) {
                          setState(() {
                            _transferTo = supplier;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          RadioListTile<String>(
            title: const Text('Dejar items sin proveedor'),
            subtitle: const Text('Los items quedarán sin proveedor asignado'),
            value: 'orphan',
            groupValue: _forceDelete ? 'orphan' : null,
            onChanged: (value) {
              setState(() {
                _forceDelete = true;
                _transferTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeletionTypeOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de eliminación:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(
              'Eliminación lógica',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              _softDelete
                  ? 'El proveedor se desactivará pero mantendrá sus datos para historial'
                  : 'El proveedor se eliminará permanentemente de la base de datos',
              style: TextStyle(fontSize: 13),
            ),
            value: _softDelete,
            onChanged: (value) {
              setState(() {
                _softDelete = value;
              });
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.errorColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acción Requerida',
                  style: TextStyle(
                    color: context.errorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Debes seleccionar una opción para manejar los items asociados antes de proceder.',
                  style: TextStyle(color: context.errorColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CONTINUACIÓN DE LA PARTE 4...

class SupplierFormDialog extends StatefulWidget {
  final InventorySupplier? supplierEditando;

  const SupplierFormDialog({super.key, this.supplierEditando});

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();

  bool _isSaving = false;
  Map<String, String> _backendErrors = {};

  @override
  void initState() {
    super.initState();
    if (widget.supplierEditando != null) {
      _nameController.text = widget.supplierEditando!.name;
      _contactController.text = widget.supplierEditando!.contactName ?? '';
      _emailController.text = widget.supplierEditando!.email ?? '';
      _phoneController.text = widget.supplierEditando!.phone ?? '';
      _addressController.text = widget.supplierEditando!.address ?? '';
      _taxIdController.text = widget.supplierEditando!.taxId ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final nombre = _nameController.text.trim();
      final contacto = _contactController.text.trim();
      final email = _emailController.text.trim();
      final telefono = _phoneController.text.trim();
      final direccion = _addressController.text.trim();
      final taxId = _taxIdController.text.trim();

      final supplierData = {
        'name': nombre,
        'contact_person': contacto.isNotEmpty ? contacto : null,
        'email': email.isNotEmpty ? email : null,
        'phone': telefono.isNotEmpty ? telefono : null,
        'address': direccion.isNotEmpty ? direccion : null,
        'tax_id': taxId.isNotEmpty ? taxId : null,
        'is_active': widget.supplierEditando?.isActive ?? true,
      };

      if (widget.supplierEditando == null) {
        // Crear
        final newSupplier = InventorySupplier(
          id: '0', // Temporal
          name: nombre,
          contactName: contacto.isNotEmpty ? contacto : null,
          email: email.isNotEmpty ? email : null,
          phone: telefono.isNotEmpty ? telefono : null,
          address: direccion.isNotEmpty ? direccion : null,
          city: null,
          country: null,
          taxId: taxId.isNotEmpty ? taxId : null,
          website: null,
          notes: null,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final response = await InventoryApiService.createSupplier(
          SupplierFormData.fromSupplier(newSupplier).toJson(),
        );

        if (response.success && response.data != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Proveedor "${response.data!.name}" creado exitosamente',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(response.data);
          }
        } else {
          if (mounted) {
            setState(() {
              _backendErrors = _parseBackendErrors(response.errors);
            });
            _showError(
              response.message ?? 'Error desconocido al crear proveedor',
            );
          }
        }
      } else {
        // Actualizar
        final response = await InventoryApiService.updateSupplier(
          int.parse(widget.supplierEditando!.id),
          supplierData,
        );

        if (response.success && response.data != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Proveedor actualizado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(response.data);
          }
        } else {
          if (mounted) {
            setState(() {
              _backendErrors = _parseBackendErrors(response.errors);
            });
            _showError(
              response.message ?? 'Error desconocido al actualizar proveedor',
            );
          }
        }
      }
    } catch (e) {
      _showError('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, String> _parseBackendErrors(Map<String, dynamic>? rawErrors) {
    if (rawErrors == null) return {};
    final parsed = <String, String>{};
    rawErrors.forEach((key, value) {
      if (value is String) {
        parsed[key] = value;
      } else if (value is List && value.isNotEmpty) {
        parsed[key] = value.first.toString();
      } else {
        parsed[key] = value.toString();
      }
    });
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplierEditando != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.business_center,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // -- NIT Primero y Requerido --
                TextFormField(
                  controller: _taxIdController,
                  decoration: InputDecoration(
                    labelText: 'NIT/Tax ID *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.assignment_ind),
                    errorText: _backendErrors['tax_id'],
                  ),
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    if (_backendErrors.containsKey('tax_id')) {
                      setState(() => _backendErrors.remove('tax_id'));
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El NIT/Tax ID es obligatorio';
                    }
                    if (value.trim().length < 3) {
                      return 'NIT inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // -- Nombre (Requerido) --
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del proveedor *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.business),
                    errorText: _backendErrors['name'],
                  ),
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    if (_backendErrors.containsKey('name')) {
                      setState(() => _backendErrors.remove('name'));
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (value.trim().length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Persona de contacto
                TextFormField(
                  controller: _contactController,
                  decoration: InputDecoration(
                    labelText: 'Persona de contacto',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.person),
                    helperText: 'Opcional',
                    errorText: _backendErrors['contact_person'],
                  ),
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    if (_backendErrors.containsKey('contact_person')) {
                      setState(() => _backendErrors.remove('contact_person'));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.email),
                    helperText: 'Opcional',
                    errorText: _backendErrors['email'],
                  ),
                  enabled: !_isSaving,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    if (_backendErrors.containsKey('email')) {
                      setState(() => _backendErrors.remove('email'));
                    }
                  },
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Email no válido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Teléfono
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.phone),
                    helperText: 'Opcional',
                    errorText: _backendErrors['phone'],
                  ),
                  enabled: !_isSaving,
                  keyboardType: TextInputType.phone,
                  onChanged: (value) {
                    if (_backendErrors.containsKey('phone')) {
                      setState(() => _backendErrors.remove('phone'));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Dirección
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.location_on),
                    helperText: 'Opcional',
                    errorText: _backendErrors['address'],
                  ),
                  enabled: !_isSaving,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    if (_backendErrors.containsKey('address')) {
                      setState(() => _backendErrors.remove('address'));
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Icon(isEditing ? Icons.save : Icons.add),
                      label: Text(
                        _isSaving
                            ? 'Guardando...'
                            : (isEditing ? 'Actualizar' : 'Crear'),
                      ),
                      onPressed: _isSaving ? null : _saveSupplier,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === FIN DEL ARCHIVO inventory_supplier_widgets.dart MEJORADO ===
