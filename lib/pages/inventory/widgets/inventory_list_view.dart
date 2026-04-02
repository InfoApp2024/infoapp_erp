import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';

// Importar los modelos reales existentes
import '../models/inventory_item_model.dart';

enum ListViewType { card, list, grid, table }

enum SortOption { name, sku, price, stock, created, updated }

enum SortDirection { asc, desc }

class InventoryListView extends StatefulWidget {
  final List<InventoryItem> items;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final Function(InventoryItem)? onItemTap;
  final Function(InventoryItem)? onItemEdit;
  final Function(InventoryItem)? onItemDelete;
  final Function(InventoryItem)? onStockAdjust;
  final Function()? onRefresh;
  final Function()? onLoadMore;
  final bool hasMore;
  final ListViewType viewType;
  final Function(ListViewType)? onViewTypeChanged;
  final SortOption sortBy;
  final SortDirection sortDirection;
  final Function(SortOption, SortDirection)? onSortChanged;
  final bool showActions;
  final bool enableSelection;
  final List<String>? selectedItemIds;
  final Function(List<String>)? onSelectionChanged;
  final String? emptyMessage;
  final Widget? emptyWidget;

  const InventoryListView({
    super.key,
    required this.items,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.onItemTap,
    this.onItemEdit,
    this.onItemDelete,
    this.onStockAdjust,
    this.onRefresh,
    this.onLoadMore,
    this.hasMore = false,
    this.viewType = ListViewType.card,
    this.onViewTypeChanged,
    this.sortBy = SortOption.name,
    this.sortDirection = SortDirection.asc,
    this.onSortChanged,
    this.showActions = true,
    this.enableSelection = false,
    this.selectedItemIds,
    this.onSelectionChanged,
    this.emptyMessage,
    this.emptyWidget,
  });

  @override
  State<InventoryListView> createState() => _InventoryListViewState();
}

class _InventoryListViewState extends State<InventoryListView>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _fabAnimationController;
  final ScrollController _scrollController = ScrollController();

  late List<String> _selectedIds;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.selectedItemIds ?? [];

    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scrollController.addListener(_onScroll);
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _fabAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore?.call();
    }

    // Animar FAB según scroll
    if (_scrollController.position.pixels > 100) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
      } else {
        _selectedIds.add(itemId);
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
    widget.onSelectionChanged?.call(_selectedIds);
  }

  void _selectAll() {
    setState(() {
      _selectedIds = widget.items.map((item) => item.id.toString()).toList();
      _isSelectionMode = true;
    });
    widget.onSelectionChanged?.call(_selectedIds);
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    widget.onSelectionChanged?.call(_selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasError) {
      return _buildErrorState();
    }

    if (widget.isLoading && widget.items.isEmpty) {
      return _buildLoadingState();
    }

    if (widget.items.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (widget.showActions) _buildHeader(),
        Expanded(child: _buildContent()),
        if (widget.isLoading) _buildLoadingIndicator(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
              tooltip: 'Cancelar selección',
            ),
            Text(
              '${_selectedIds.length} seleccionados',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            if (_selectedIds.length < widget.items.length)
              TextButton(
                onPressed: _selectAll,
                child: const Text('Seleccionar todo'),
              ),
          ] else ...[
            Text(
              '${widget.items.length} productos',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const Spacer(),
            _buildViewToggle(),
            const SizedBox(width: 8),
            _buildSortButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(ListViewType.card, Icons.view_agenda),
          _buildViewButton(ListViewType.list, Icons.view_list),
          _buildViewButton(ListViewType.grid, Icons.grid_view),
          _buildViewButton(ListViewType.table, Icons.table_rows),
        ],
      ),
    );
  }

  Widget _buildViewButton(ListViewType type, IconData icon) {
    final isSelected = widget.viewType == type;
    return GestureDetector(
      onTap: () => widget.onViewTypeChanged?.call(type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<SortOption>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: 18, color: Colors.grey.shade600),
          Icon(
            widget.sortDirection == SortDirection.asc
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 14,
            color: Colors.grey.shade600,
          ),
        ],
      ),
      onSelected: (SortOption option) {
        final newDirection =
            widget.sortBy == option && widget.sortDirection == SortDirection.asc
                ? SortDirection.desc
                : SortDirection.asc;
        widget.onSortChanged?.call(option, newDirection);
      },
      itemBuilder:
          (context) => [
            _buildSortMenuItem(SortOption.name, 'Nombre'),
            _buildSortMenuItem(SortOption.sku, 'SKU'),
            _buildSortMenuItem(SortOption.price, 'Precio'),
            _buildSortMenuItem(SortOption.stock, 'Stock'),
            _buildSortMenuItem(SortOption.created, 'Fecha creación'),
            _buildSortMenuItem(SortOption.updated, 'Última modificación'),
          ],
    );
  }

  PopupMenuItem<SortOption> _buildSortMenuItem(
    SortOption option,
    String label,
  ) {
    final isSelected = widget.sortBy == option;
    return PopupMenuItem<SortOption>(
      value: option,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(
              widget.sortDirection == SortDirection.asc
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh?.call();
      },
      child: AnimatedBuilder(
        animation: _listAnimationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _listAnimationController,
            child: _buildListByType(),
          );
        },
      ),
    );
  }

  Widget _buildListByType() {
    switch (widget.viewType) {
      case ListViewType.card:
        return _buildCardView();
      case ListViewType.list:
        return _buildListView();
      case ListViewType.grid:
        return _buildGridView();
      case ListViewType.table:
        return _buildTableView();
    }
  }

  Widget _buildCardView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final item = widget.items[index];
        final isSelected = _selectedIds.contains(item.id.toString());

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
          ),
          child: InventoryItemCard(
            item: item,
            onTap: () => _handleItemTap(item),
            onEdit:
                widget.onItemEdit != null
                    ? () => widget.onItemEdit!(item)
                    : null,
            onDelete:
                widget.onItemDelete != null
                    ? () => widget.onItemDelete!(item)
                    : null,
            onStockAdjust:
                widget.onStockAdjust != null
                    ? () => widget.onStockAdjust!(item)
                    : null,
            showActions: widget.showActions && !_isSelectionMode,
            isSelected: isSelected,
            onLongPress:
                widget.enableSelection
                    ? () => _toggleSelection(item.id.toString())
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final item = widget.items[index];
        final isSelected = _selectedIds.contains(item.id.toString());

        return _buildListTile(item, isSelected);
      },
    );
  }

  Widget _buildListTile(InventoryItem item, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading:
            widget.enableSelection
                ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(item.id.toString()),
                )
                : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStockStatusColor(
                      context,
                      item.currentStock,
                      item.minimumStock,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      item.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${item.sku}'),
            Text(
              'Stock: ${_formatNumber(item.currentStock)} ${item.unitOfMeasure}',
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${item.unitCost.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStockStatusColor(
                  context,
                  item.currentStock,
                  item.minimumStock,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStockStatusText(item.currentStock, item.minimumStock),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _handleItemTap(item),
        onLongPress:
            widget.enableSelection
                ? () => _toggleSelection(item.id.toString())
                : null,
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final item = widget.items[index];
        final isSelected = _selectedIds.contains(item.id.toString());

        return _buildGridCard(item, isSelected);
      },
    );
  }

  Widget _buildGridCard(InventoryItem item, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleItemTap(item),
        onLongPress:
            widget.enableSelection
                ? () => _toggleSelection(item.id.toString())
                : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.enableSelection)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(item.id.toString()),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                'SKU: ${item.sku}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Stock: ${_formatNumber(item.currentStock)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${item.unitCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStockStatusColor(
                        context,
                        item.currentStock,
                        item.minimumStock,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Precio')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows:
              widget.items.map((item) {
                final isSelected = _selectedIds.contains(item.id.toString());
                return DataRow(
                  selected: isSelected,
                  onSelectChanged:
                      widget.enableSelection
                          ? (_) => _toggleSelection(item.id.toString())
                          : null,
                  cells: [
                    DataCell(
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(Text(item.sku)),
                    DataCell(Text('\$${item.unitCost.toStringAsFixed(2)}')),
                    DataCell(Text(_formatNumber(item.currentStock))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStockStatusColor(
                            context,
                            item.currentStock,
                            item.minimumStock,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStockStatusText(
                            item.currentStock,
                            item.minimumStock,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 18),
                            onPressed: () => _handleItemTap(item),
                            tooltip: 'Ver detalle',
                          ),
                          IconButton(
                            icon: const Icon(Icons.history, size: 18),
                            onPressed: () => widget.onStockAdjust?.call(item),
                            tooltip: 'Historial/Movimientos',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => widget.onItemEdit?.call(item),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => widget.onItemDelete?.call(item),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando productos...'),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error al cargar productos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.errorMessage ?? 'Ha ocurrido un error inesperado',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (widget.emptyWidget != null) {
      return widget.emptyWidget!;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyMessage ?? 'No hay productos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los productos aparecerán aquí cuando los agregues',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleItemTap(InventoryItem item) {
    if (widget.enableSelection && _isSelectionMode) {
      _toggleSelection(item.id.toString());
    } else {
      widget.onItemTap?.call(item);
    }
  }

  Color _getStockStatusColor(
    BuildContext context,
    double currentStock,
    double minimumStock,
  ) {
    if (currentStock == 0) return context.errorColor;
    if (currentStock <= minimumStock) return context.warningColor;
    return context.successColor;
  }

  String _getStockStatusText(double currentStock, double minimumStock) {
    if (currentStock == 0) return 'Sin Stock';
    if (currentStock <= minimumStock) return 'Stock Bajo';
    return 'En Stock';
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}

// === WIDGET DE TARJETA DE INVENTARIO ===

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStockAdjust;
  final VoidCallback? onLongPress;
  final bool showActions;
  final bool isSelected;

  const InventoryItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onStockAdjust,
    this.onLongPress,
    this.showActions = true,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isSelected
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${item.sku}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStockStatusColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStockStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (item.description != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item.description!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '\$${item.unitCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${_formatNumber(item.currentStock)} ${item.unitOfMeasure}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showActions)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit?.call();
                            break;
                          case 'stock':
                            onStockAdjust?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder:
                          (context) => [
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                            if (onStockAdjust != null)
                              const PopupMenuItem(
                                value: 'stock',
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory, size: 18),
                                    SizedBox(width: 8),
                                    Text('Ajustar Stock'),
                                  ],
                                ),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStockStatusColor(BuildContext context) {
    if (item.currentStock == 0) return context.errorColor;
    if (item.currentStock <= item.minimumStock) return context.warningColor;
    return context.successColor;
  }

  String _getStockStatusText() {
    if (item.currentStock == 0) return 'Sin Stock';
    if (item.currentStock <= item.minimumStock) return 'Stock Bajo';
    return 'En Stock';
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }
}
