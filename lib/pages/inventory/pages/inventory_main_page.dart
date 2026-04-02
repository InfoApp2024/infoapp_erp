// lib/pages/inventory/pages/inventory_main_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:intl/intl.dart';

// Importar los modelos y servicios reales
import '../models/inventory_item_model.dart';
import '../models/inventory_category_model.dart';
import '../models/inventory_supplier_model.dart';
import '../services/inventory_api_service.dart';
import 'inventory_detail_page.dart';
import 'inventory_form_page.dart';
import 'inventory_dashboard_page.dart';
import 'inactive_items_page.dart';

// NUEVO: Import del widget de importar/exportar
import '../widgets/inventory_import_export_widget.dart';

// === ENUMS Y CLASES AUXILIARES ===

enum ViewMode { grid, list }

enum SortOption {
  name('name', 'Nombre'),
  sku('sku', 'SKU'),
  stock('current_stock', 'Stock'),
  cost('unit_cost', 'Costo'),
  updated('updated_at', 'Actualización');

  const SortOption(this.apiValue, this.displayName);
  final String apiValue;
  final String displayName;
}

class InventoryMainPage extends StatefulWidget {
  const InventoryMainPage({super.key});

  @override
  State<InventoryMainPage> createState() => _InventoryMainPageState();
}

class _InventoryMainPageState extends State<InventoryMainPage>
    with TickerProviderStateMixin {
  // Controladores
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Estado de la página
  List<InventoryItem> _items = [];
  List<InventoryCategory> _categories = [];
  List<InventorySupplier> _suppliers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Filtros actuales
  String _searchQuery = '';
  int? _selectedCategoryId;
  String? _selectedItemType;
  int? _selectedSupplierId;
  bool _showLowStockOnly = false;
  bool _showInactiveItems = false;

  // Paginación
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  bool _hasMoreData = false;
  static const int _itemsPerPage = 20;

  // Vista actual
  ViewMode _viewMode = ViewMode.list;
  SortOption _sortOption = SortOption.name;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // === MÉTODOS DE CARGA DE DATOS ===

  String _formatCurrency(double amount, {int decimalDigits = 2}) {
    final format = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: decimalDigits,
    );
    return format.format(amount);
  }

  String _formatNumber(num amount) {
    final format = NumberFormat.decimalPattern('es_CO');
    return format.format(amount);
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadItems(refresh: true),
        _loadCategories(),
        _loadSuppliers(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar datos: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _items.clear();
    }

    try {
      final response = await InventoryApiService.getItems(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _selectedCategoryId,
        itemType: _selectedItemType,
        supplierId: _selectedSupplierId,
        lowStock: _showLowStockOnly ? true : null,
        includeInactive: _showInactiveItems,
        limit: _itemsPerPage,
        offset: (_currentPage - 1) * _itemsPerPage,
        sortBy: _sortOption.apiValue,
        sortOrder: _sortAscending ? 'ASC' : 'DESC',
      );

      if (response.success && response.data != null) {
        setState(() {
          if (refresh) {
            _items = response.data!.items;
          } else {
            _items.addAll(response.data!.items);
          }
          _totalPages = response.data!.totalPages;
          _totalRecords = response.data!.totalRecords;
          _hasMoreData = response.data!.hasNext;
          _currentPage++;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Error al cargar items';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar items: ${e.toString()}';
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await InventoryApiService.getCategories(flat: true);
      if (response.success && response.data != null) {
        setState(() {
          _categories = response.data!.categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final response = await InventoryApiService.getSuppliers(limit: 100);
      if (response.success && response.data != null) {
        setState(() {
          _suppliers = response.data!.suppliers;
        });
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  // === MÉTODOS DE INTERACCIÓN ===

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreData && !_isLoadingMore) {
        _loadMoreItems();
      }
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadItems();

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _debounceSearch();
  }

  Timer? _searchTimer;
  void _debounceSearch() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _loadItems(refresh: true);
    });
  }

  void _onFilterChanged() {
    _loadItems(refresh: true);
  }

  void _onSortChanged(SortOption option) {
    setState(() {
      if (_sortOption == option) {
        _sortAscending = !_sortAscending;
      } else {
        _sortOption = option;
        _sortAscending = true;
      }
    });
    _loadItems(refresh: true);
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
    });
  }

  Future<void> _refreshData() async {
    await _loadItems(refresh: true);
  }

  // NUEVO: Método para mostrar el diálogo de importar/exportar
  void _showImportExportDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Importar/Exportar'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InventoryImportExportWidget(
                      items: _items,
                      categories: _categories,
                      suppliers: _suppliers,
                      onImport: (file, options) {
                        // Aquí manejarías la importación real con la API
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Importación iniciada...'),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                        );
                        // Después de importar exitosamente:
                        Navigator.of(context).pop();
                        _refreshData();
                      },
                      onExport: (items, options) {
                        // Aquí manejarías la exportación real
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Exportación completada'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      onRefresh: () {
                        Navigator.of(context).pop();
                        _refreshData();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
  // === NAVEGACIÓN ===

  void _navigateToItemDetail(InventoryItem item) {
    final store = PermissionStore.instance;
    if (!store.can('inventario', 'ver') && !store.can('inventario', 'listar')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para ver inventario')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InventoryDetailPage(item: item)),
    ).then((_) => _refreshData());
  }

  void _navigateToCreateItem() {
    final store = PermissionStore.instance;
    if (!store.can('inventario', 'crear')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para crear items')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InventoryFormPage(
              categories: _categories,
              suppliers: _suppliers,
            ),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void _navigateToEditItem(InventoryItem item) {
    final store = PermissionStore.instance;
    if (!store.can('inventario', 'actualizar')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para editar items')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InventoryFormPage(
              item: item,
              categories: _categories,
              suppliers: _suppliers,
            ),
      ),
    ).then((result) {
      if (result == true) {
        _refreshData();
      }
    });
  }

  void _navigateToInactiveItems() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InactiveItemsPage()),
    ).then((_) => _refreshData()); // Actualizar lista al volver
  }
  // === PROPIEDADES COMPUTADAS ===

  bool get _hasActiveFilters {
    return _selectedCategoryId != null ||
        _selectedItemType != null ||
        _selectedSupplierId != null ||
        _showLowStockOnly ||
        _showInactiveItems;
  }

  // === WIDGET BUILD PRINCIPAL ===

  @override
  Widget build(BuildContext context) {
    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    final bool canView = PermissionStore.instance.can('inventario', 'ver');
    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inventario'),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder al módulo de inventario',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Items', icon: Icon(Icons.inventory_2)),
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
          ],
        ),
        actions: [
          // Botón para crear nuevo item
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear nuevo item',
            onPressed:
                PermissionStore.instance.can('inventario', 'crear')
                    ? _navigateToCreateItem
                    : null,
          ),
          // NUEVO: PopupMenuButton con opciones de importar/exportar
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Más opciones',
            onSelected: (value) {
              switch (value) {
                case 'import_export':
                  _showImportExportDialog();
                  break;
                case 'refresh':
                  _refreshData();
                  break;
                case 'filters':
                  _showFilterDialog();
                  break;
                // ✅ AGREGAR ESTE CASO
                case 'inactive_items':
                  _navigateToInactiveItems();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  if (PermissionStore.instance.can('inventario', 'exportar'))
                    PopupMenuItem(
                      value: 'import_export',
                      child: Row(
                        children: [
                          Icon(
                            Icons.import_export,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 12),
                          Text('Importar/Exportar'),
                        ],
                      ),
                    ),
                  if (PermissionStore.instance.can('inventario', 'exportar'))
                    const PopupMenuDivider(),
                  // ✅ AGREGAR ESTE ITEM
                  const PopupMenuItem(
                    value: 'inactive_items',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_off, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Items Inactivos'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 12),
                        Text('Actualizar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'filters',
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt),
                        SizedBox(width: 12),
                        Text('Filtros Avanzados'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildItemsTab(), _buildDashboardTab()],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [_buildFilterBar(), Expanded(child: _buildItemsList())],
    );
  }

  Widget _buildDashboardTab() {
    return const InventoryDashboardPage();
  }

  // === WIDGETS DE FILTROS ===

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar productos...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _showFilterDialog,
                icon: Icon(
                  Icons.filter_list,
                  color:
                      _hasActiveFilters
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).hintColor,
                ),
                tooltip: 'Filtros',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Controles de vista y ordenamiento
          Row(
            children: [
              // Contador de resultados
              Expanded(
                child: Text(
                  '$_totalRecords items encontrados',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              // Filtros rápidos
              if (_showLowStockOnly)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: const Text('Stock bajo'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.12),
                    labelStyle: const TextStyle(fontSize: 12),
                    onDeleted: () {
                      setState(() {
                        _showLowStockOnly = false;
                      });
                      _onFilterChanged();
                    },
                  ),
                ),

              if (_selectedCategoryId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(
                      _categories
                          .firstWhere(
                            (cat) => cat.id == _selectedCategoryId,
                            orElse:
                                () => InventoryCategory(
                                  id: null,
                                  name: 'Categoría',
                                  isActive: true,
                                ),
                          )
                          .name,
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.12),
                    labelStyle: const TextStyle(fontSize: 12),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoryId = null;
                      });
                      _onFilterChanged();
                    },
                  ),
                ),
              const SizedBox(width: 8),

              // Ordenamiento
              DropdownButtonHideUnderline(
                child: DropdownButton<SortOption>(
                  value: _sortOption,
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                  items:
                      SortOption.values.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Text(
                            option.displayName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  onChanged: (option) => _onSortChanged(option!),
                ),
              ),

              const SizedBox(width: 8),

              // Cambiar vista
              IconButton(
                icon: Icon(
                  _viewMode == ViewMode.grid ? Icons.list : Icons.grid_view,
                ),
                onPressed: _toggleViewMode,
                tooltip:
                    _viewMode == ViewMode.grid
                        ? 'Cambiar a lista'
                        : 'Cambiar a cuadrícula',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    final store = PermissionStore.instance;
    final puedeListar = store.can('inventario', 'listar');
    if (!puedeListar) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tienes permiso para listar inventario',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando inventario...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showImportExportDialog,
                  icon: const Icon(Icons.import_export),
                  label: const Text('Importar Datos'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron items',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu primer item de inventario o importa datos',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _navigateToCreateItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Item'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showImportExportDialog,
                  icon: const Icon(Icons.import_export),
                  label: const Text('Importar'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _viewMode == ViewMode.grid ? _buildGridView() : _buildListView(),
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
        childAspectRatio: 0.75,
      ),
      itemCount: _items.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Card(child: Center(child: CircularProgressIndicator()));
        }

        final item = _items[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = _items[index];
        return _buildInventoryCard(item, isListView: true);
      },
    );
  }

  Widget _buildInventoryCard(InventoryItem item, {bool isListView = false}) {
    final isLowStock = item.hasLowStock;
    final isOutOfStock = item.isOutOfStock;

    Color statusColor = context.successColor;
    String statusText = 'Normal';
    IconData statusIcon = Icons.check_circle;

    if (isOutOfStock) {
      statusColor = context.errorColor;
      statusText = 'Sin stock';
      statusIcon = Icons.error;
    } else if (isLowStock) {
      statusColor = context.warningColor;
      statusText = 'Stock bajo';
      statusIcon = Icons.warning;
    }

    if (isListView) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 2,
        child: ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: statusColor, size: 24),
          ),
          title: Text(
            item.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SKU: ${item.sku.toUpperCase()}'),
              Text(
                'STOCK: ${_formatNumber(item.currentStock)} ${item.unitOfMeasure.toUpperCase()}',
              ),
              if (item.categoryName != null)
                Text(
                  'CATEGORÍA: ${item.categoryName!.toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(item.unitCost),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          onTap: () => _navigateToItemDetail(item),
          onLongPress: () => _showItemOptions(item),
        ),
      );
    }

    // Vista de cuadrícula
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToItemDetail(item),
        onLongPress: () => _showItemOptions(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nombre y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // SKU y Stock
              Text(
                'SKU: ${item.sku.toUpperCase()}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'STOCK: ${_formatNumber(item.currentStock)} ${item.unitOfMeasure.toUpperCase()}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),

              // Categoría si existe
              if (item.categoryName != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.categoryName!.toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const Spacer(),

              // Footer con precio y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatCurrency(item.unitCost),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
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

  void _showItemOptions(InventoryItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'SKU: ${item.sku.toUpperCase()}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),

                // Opciones
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.blue),
                  title: const Text('Ver detalle'),
                  subtitle: const Text('Información completa del item'),
                  enabled:
                      PermissionStore.instance.can('inventario', 'ver') ||
                      PermissionStore.instance.can('inventario', 'listar'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToItemDetail(item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.green),
                  title: const Text('Editar'),
                  subtitle: const Text('Modificar información del item'),
                  enabled: PermissionStore.instance.can(
                    'inventario',
                    'actualizar',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToEditItem(item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory, color: Colors.orange),
                  title: const Text('Ajustar stock'),
                  subtitle: const Text('Registrar entrada, salida o ajuste'),
                  enabled: PermissionStore.instance.can(
                    'inventario',
                    'actualizar',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showStockAdjustment(item);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showStockAdjustment(InventoryItem item) {
    final store = PermissionStore.instance;
    if (!store.can('inventario', 'actualizar')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para ajustar stock')),
      );
      return;
    }
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    String movementType = 'entrada';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ajustar Stock',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Información del item
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('SKU: ${item.sku}'),
                              Text(
                                'Stock actual: ${_formatNumber(item.currentStock)} ${item.unitOfMeasure}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tipo de movimiento
                        DropdownButtonFormField<String>(
                          initialValue: movementType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de movimiento',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.swap_horiz),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'entrada',
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Entrada (+)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'salida',
                              child: Row(
                                children: [
                                  Icon(Icons.remove_circle, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Salida (-)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'ajuste',
                              child: Row(
                                children: [
                                  Icon(Icons.tune, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Ajuste'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              movementType = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Cantidad
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cantidad',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.numbers),
                            suffix: Text(item.unitOfMeasure),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Motivo
                        TextField(
                          controller: reasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Motivo (opcional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                            hintText: 'Describe el motivo del ajuste...',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final quantity = double.tryParse(
                          quantityController.text,
                        );
                        if (quantity == null || quantity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa una cantidad válida'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ajuste de stock registrado: $movementType de $quantity ${item.unitOfMeasure}',
                            ),
                            backgroundColor: Colors.green,
                            action: SnackBarAction(
                              label: 'Deshacer',
                              textColor: Colors.white,
                              onPressed: () {
                                // Aquí implementarías la funcionalidad de deshacer
                              },
                            ),
                          ),
                        );
                        _refreshData();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Aplicar'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterWidget(),
    );
  }

  Widget _buildFilterWidget() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Filtros Avanzados',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtro por categoría
                  const Text(
                    'Categoría',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      hintText: 'Seleccionar categoría',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas las categorías'),
                      ),
                      ..._categories.map(
                        (category) => DropdownMenuItem(
                          value:
                              category.id != null
                                  ? int.tryParse(category.id.toString())
                                  : null,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Filtro por proveedor
                  const Text(
                    'Proveedor',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedSupplierId,
                    decoration: const InputDecoration(
                      hintText: 'Seleccionar proveedor',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos los proveedores'),
                      ),
                      ..._suppliers.map(
                        (supplier) => DropdownMenuItem(
                          value: int.tryParse(supplier.id),
                          child: Text(supplier.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Filtro por tipo de item
                  const Text(
                    'Tipo de Item',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedItemType,
                    decoration: const InputDecoration(
                      hintText: 'Seleccionar tipo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Todos los tipos'),
                      ),
                      DropdownMenuItem(
                        value: 'repuesto',
                        child: Text('Repuesto'),
                      ),
                      DropdownMenuItem(value: 'insumo', child: Text('Insumo')),
                      DropdownMenuItem(
                        value: 'herramienta',
                        child: Text('Herramienta'),
                      ),
                      DropdownMenuItem(
                        value: 'consumible',
                        child: Text('Consumible'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedItemType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Switches para filtros booleanos
                  const Text(
                    'Opciones Adicionales',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Solo stock bajo'),
                          subtitle: const Text(
                            'Items con stock por debajo del mínimo',
                          ),
                          value: _showLowStockOnly,
                          activeThumbColor: Colors.orange,
                          onChanged: (value) {
                            setState(() {
                              _showLowStockOnly = value;
                            });
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Incluir items inactivos'),
                          subtitle: const Text('Mostrar items deshabilitados'),
                          value: _showInactiveItems,
                          activeThumbColor: Colors.grey,
                          onChanged: (value) {
                            setState(() {
                              _showInactiveItems = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _selectedItemType = null;
                      _selectedSupplierId = null;
                      _showLowStockOnly = false;
                      _showInactiveItems = false;
                    });
                    _onFilterChanged();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _onFilterChanged();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Aplicar Filtros'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Cierre de la clase
