import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:flutter/services.dart';

// Importar los modelos reales existentes
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';

class InventoryFilterPanel extends StatefulWidget {
  final Function(InventoryFilters) onFiltersChanged;
  final InventoryFilters? initialFilters;
  final List<InventoryCategory>? categories;
  final List<InventorySupplier>? suppliers;
  final bool isLoading;
  final Function()? onReset;
  final bool showAdvanced;

  const InventoryFilterPanel({
    super.key,
    required this.onFiltersChanged,
    this.initialFilters,
    this.categories,
    this.suppliers,
    this.isLoading = false,
    this.onReset,
    this.showAdvanced = false,
  });

  @override
  State<InventoryFilterPanel> createState() => _InventoryFilterPanelState();
}

class _InventoryFilterPanelState extends State<InventoryFilterPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late InventoryFilters _currentFilters;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _maxStockController = TextEditingController();

  bool _showAdvancedFilters = false;
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  String? _selectedItemType;
  StockStatus? _selectedStockStatus;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.initialFilters ?? InventoryFilters();
    _initializeControllers();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _minPriceController.text = _currentFilters.minPrice?.toString() ?? '';
    _maxPriceController.text = _currentFilters.maxPrice?.toString() ?? '';
    _minStockController.text = _currentFilters.minStock?.toString() ?? '';
    _maxStockController.text = _currentFilters.maxStock?.toString() ?? '';

    _selectedCategoryId = _currentFilters.categoryId;
    _selectedSupplierId = _currentFilters.supplierId;
    _selectedItemType = _currentFilters.itemType;
    _selectedStockStatus = _currentFilters.stockStatus;
    _selectedDateRange = _currentFilters.dateRange;
  }

  void _updateFilters() {
    _currentFilters = _currentFilters.copyWith(
      categoryId: _selectedCategoryId,
      supplierId: _selectedSupplierId,
      itemType: _selectedItemType,
      stockStatus: _selectedStockStatus,
      minPrice: double.tryParse(_minPriceController.text),
      maxPrice: double.tryParse(_maxPriceController.text),
      minStock: int.tryParse(_minStockController.text),
      maxStock: int.tryParse(_maxStockController.text),
      dateRange: _selectedDateRange,
    );

    widget.onFiltersChanged(_currentFilters);
  }

  void _resetFilters() {
    setState(() {
      _currentFilters = InventoryFilters();
      _minPriceController.clear();
      _maxPriceController.clear();
      _minStockController.clear();
      _maxStockController.clear();
      _selectedCategoryId = null;
      _selectedSupplierId = null;
      _selectedItemType = null;
      _selectedStockStatus = null;
      _selectedDateRange = null;
    });

    widget.onReset?.call();
    _updateFilters();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _updateFilters();
    }
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedCategoryId != null) count++;
    if (_selectedSupplierId != null) count++;
    if (_selectedItemType != null) count++;
    if (_selectedStockStatus != null) count++;
    if (_minPriceController.text.isNotEmpty) count++;
    if (_maxPriceController.text.isNotEmpty) count++;
    if (_minStockController.text.isNotEmpty) count++;
    if (_maxStockController.text.isNotEmpty) count++;
    if (_selectedDateRange != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildFilterPanel(),
          ),
        );
      },
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildBasicFilters(),
          if (_showAdvancedFilters || widget.showAdvanced)
            _buildAdvancedFilters(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final activeCount = _getActiveFiltersCount();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_outlined,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Filtros de Inventario',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const Spacer(),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterSection(
            title: 'Categoría',
            child: _buildCategoryDropdown(),
          ),
          const SizedBox(height: 16),
          _buildFilterSection(
            title: 'Proveedor',
            child: _buildSupplierDropdown(),
          ),
          const SizedBox(height: 16),
          _buildFilterSection(
            title: 'Tipo de Producto',
            child: _buildTypeDropdown(),
          ),
          const SizedBox(height: 16),
          _buildFilterSection(
            title: 'Estado de Stock',
            child: _buildStockStatusDropdown(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filtros Avanzados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterSection(
            title: 'Rango de Precios',
            child: _buildPriceRange(),
          ),
          const SizedBox(height: 16),
          _buildFilterSection(
            title: 'Rango de Stock',
            child: _buildStockRange(),
          ),
          const SizedBox(height: 16),
          _buildFilterSection(
            title: 'Fecha de Creación',
            child: _buildDateRangeSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedCategoryId,
      decoration: _getDropdownDecoration('Seleccionar categoría'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todas las categorías'),
        ),
        ...?widget.categories?.map((category) {
          return DropdownMenuItem<int?>(
            value:
                category.id != null
                    ? int.tryParse(category.id.toString())
                    : null,
            child: Text(category.name),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
        _updateFilters();
      },
      isExpanded: true,
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedSupplierId,
      decoration: _getDropdownDecoration('Seleccionar proveedor'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos los proveedores'),
        ),
        ...?widget.suppliers?.map((supplier) {
          return DropdownMenuItem<int?>(
            value: int.tryParse(supplier.id),
            child: Text(supplier.name),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedSupplierId = value;
        });
        _updateFilters();
      },
      isExpanded: true,
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedItemType,
      decoration: _getDropdownDecoration('Seleccionar tipo'),
      items: const [
        DropdownMenuItem<String?>(value: null, child: Text('Todos los tipos')),
        DropdownMenuItem(value: 'repuesto', child: Text('Repuesto')),
        DropdownMenuItem(value: 'insumo', child: Text('Insumo')),
        DropdownMenuItem(value: 'herramienta', child: Text('Herramienta')),
        DropdownMenuItem(value: 'consumible', child: Text('Consumible')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedItemType = value;
        });
        _updateFilters();
      },
      isExpanded: true,
    );
  }

  Widget _buildStockStatusDropdown() {
    return DropdownButtonFormField<StockStatus?>(
      initialValue: _selectedStockStatus,
      decoration: _getDropdownDecoration('Seleccionar estado'),
      items: [
        const DropdownMenuItem<StockStatus?>(
          value: null,
          child: Text('Todos los estados'),
        ),
        ...StockStatus.values.map((status) {
          return DropdownMenuItem<StockStatus>(
            value: status,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status, context),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_getStatusLabel(status)),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedStockStatus = value;
        });
        _updateFilters();
      },
      isExpanded: true,
    );
  }

  Widget _buildPriceRange() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _minPriceController,
            decoration: _getTextFieldDecoration('Mín'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (value) => _updateFilters(),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'a',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _maxPriceController,
            decoration: _getTextFieldDecoration('Máx'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (value) => _updateFilters(),
          ),
        ),
      ],
    );
  }

  Widget _buildStockRange() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _minStockController,
            decoration: _getTextFieldDecoration('Mín'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _updateFilters(),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'a',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _maxStockController,
            decoration: _getTextFieldDecoration('Máx'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _updateFilters(),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return GestureDetector(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDateRange != null
                    ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                    : 'Seleccionar rango de fechas',
                style: TextStyle(
                  color:
                      _selectedDateRange != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                ),
              ),
            ),
            if (_selectedDateRange != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _updateFilters();
                },
                child: Icon(Icons.clear, color: Colors.grey.shade600, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (!widget.showAdvanced)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAdvancedFilters = !_showAdvancedFilters;
                });
              },
              icon: Icon(
                _showAdvancedFilters ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(
                _showAdvancedFilters ? 'Menos filtros' : 'Más filtros',
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: _getActiveFiltersCount() > 0 ? _resetFilters : null,
            child: const Text('Limpiar'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: widget.isLoading ? null : () => _updateFilters(),
            icon:
                widget.isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Icon(Icons.search),
            label: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  // === MÉTODOS AUXILIARES ===

  InputDecoration _getDropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).primaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: Colors.white,
    );
  }

  InputDecoration _getTextFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).primaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: Colors.white,
    );
  }

  String _getStatusLabel(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return 'En Stock';
      case StockStatus.lowStock:
        return 'Stock Bajo';
      case StockStatus.outOfStock:
        return 'Sin Stock';
      case StockStatus.discontinued:
        return 'Descontinuado';
    }
  }

  Color _getStatusColor(StockStatus status, BuildContext context) {
    switch (status) {
      case StockStatus.inStock:
        return context.successColor;
      case StockStatus.lowStock:
        return context.warningColor;
      case StockStatus.outOfStock:
        return context.errorColor;
      case StockStatus.discontinued:
        return Theme.of(context).colorScheme.outlineVariant;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// === CLASES DE DATOS PARA FILTROS ===

class InventoryFilters {
  final int? categoryId;
  final int? supplierId;
  final String? itemType;
  final StockStatus? stockStatus;
  final double? minPrice;
  final double? maxPrice;
  final int? minStock;
  final int? maxStock;
  final DateTimeRange? dateRange;

  InventoryFilters({
    this.categoryId,
    this.supplierId,
    this.itemType,
    this.stockStatus,
    this.minPrice,
    this.maxPrice,
    this.minStock,
    this.maxStock,
    this.dateRange,
  });

  InventoryFilters copyWith({
    int? categoryId,
    int? supplierId,
    String? itemType,
    StockStatus? stockStatus,
    double? minPrice,
    double? maxPrice,
    int? minStock,
    int? maxStock,
    DateTimeRange? dateRange,
  }) {
    return InventoryFilters(
      categoryId: categoryId,
      supplierId: supplierId,
      itemType: itemType,
      stockStatus: stockStatus,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minStock: minStock,
      maxStock: maxStock,
      dateRange: dateRange,
    );
  }

  bool get hasActiveFilters {
    return categoryId != null ||
        supplierId != null ||
        itemType != null ||
        stockStatus != null ||
        minPrice != null ||
        maxPrice != null ||
        minStock != null ||
        maxStock != null ||
        dateRange != null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'categoryId': categoryId,
      if (supplierId != null) 'supplierId': supplierId,
      if (itemType != null) 'itemType': itemType,
      if (stockStatus != null) 'stockStatus': stockStatus.toString(),
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minStock != null) 'minStock': minStock,
      if (maxStock != null) 'maxStock': maxStock,
      if (dateRange != null) 'startDate': dateRange!.start.toIso8601String(),
      if (dateRange != null) 'endDate': dateRange!.end.toIso8601String(),
    };
  }

  factory InventoryFilters.fromJson(Map<String, dynamic> json) {
    return InventoryFilters(
      categoryId: json['categoryId'] as int?,
      supplierId: json['supplierId'] as int?,
      itemType: json['itemType'] as String?,
      stockStatus:
          json['stockStatus'] != null
              ? StockStatus.values.firstWhere(
                (e) => e.toString() == json['stockStatus'],
                orElse: () => StockStatus.inStock,
              )
              : null,
      minPrice: json['minPrice'] as double?,
      maxPrice: json['maxPrice'] as double?,
      minStock: json['minStock'] as int?,
      maxStock: json['maxStock'] as int?,
      dateRange:
          json['startDate'] != null && json['endDate'] != null
              ? DateTimeRange(
                start: DateTime.parse(json['startDate']),
                end: DateTime.parse(json['endDate']),
              )
              : null,
    );
  }

  @override
  String toString() {
    return 'InventoryFilters(categoryId: $categoryId, supplierId: $supplierId, itemType: $itemType, stockStatus: $stockStatus, minPrice: $minPrice, maxPrice: $maxPrice, minStock: $minStock, maxStock: $maxStock, dateRange: $dateRange)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryFilters &&
        other.categoryId == categoryId &&
        other.supplierId == supplierId &&
        other.itemType == itemType &&
        other.stockStatus == stockStatus &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice &&
        other.minStock == minStock &&
        other.maxStock == maxStock &&
        other.dateRange == dateRange;
  }

  @override
  int get hashCode {
    return categoryId.hashCode ^
        supplierId.hashCode ^
        itemType.hashCode ^
        stockStatus.hashCode ^
        minPrice.hashCode ^
        maxPrice.hashCode ^
        minStock.hashCode ^
        maxStock.hashCode ^
        dateRange.hashCode;
  }
}

// === ENUMS ===

enum StockStatus { inStock, lowStock, outOfStock, discontinued }
