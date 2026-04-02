import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import '../models/inventory_item_model.dart';

// Modelo para estadísticas de inventario
class InventoryStats {
  final int totalItems;
  final int activeItems;
  final int inactiveItems;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalStockValue;
  final double averageStockValue;
  final Map<String, int> itemsByCategory;
  final Map<String, int> itemsBySupplier;
  final Map<String, int> itemsByType;
  final Map<String, int> itemsByAlertLevel;
  final List<InventoryItem> topValueItems;
  final List<InventoryItem> recentlyUpdatedItems;
  final Map<String, double> stockTrends;
  final DateTime lastUpdated;

  const InventoryStats({
    this.totalItems = 0,
    this.activeItems = 0,
    this.inactiveItems = 0,
    this.lowStockItems = 0,
    this.outOfStockItems = 0,
    this.totalStockValue = 0.0,
    this.averageStockValue = 0.0,
    this.itemsByCategory = const {},
    this.itemsBySupplier = const {},
    this.itemsByType = const {},
    this.itemsByAlertLevel = const {},
    this.topValueItems = const [],
    this.recentlyUpdatedItems = const [],
    this.stockTrends = const {},
    required this.lastUpdated,
  });

  factory InventoryStats.fromItems(List<InventoryItem> items) {
    final activeItems = items.where((item) => item.isActive).toList();
    final inactiveItems = items.where((item) => !item.isActive).toList();

    // Calcular items con stock bajo (menos del 10% del stock máximo o menos de 5 unidades)
    final lowStockItems =
        items.where((item) {
          if (item.currentStock <= 0) return false; // No contar los sin stock
          if (item.maximumStock > 0) {
            return item.currentStock < (item.maximumStock * 0.1);
          }
          return item.currentStock < 5; // Umbral por defecto
        }).toList();

    // Items sin stock
    final outOfStockItems =
        items.where((item) => item.currentStock <= 0).toList();

    // Calcular valor total del stock
    final totalValue = items.fold<double>(0.0, (sum, item) {
      final itemValue = (item.unitCost ?? 0.0) * item.currentStock;
      return sum + itemValue;
    });
    final averageValue = items.isNotEmpty ? totalValue / items.length : 0.0;

    // Agrupar por categoría
    final Map<String, int> byCategory = {};
    for (final item in items) {
      final category = item.categoryName ?? 'Sin categoría';
      byCategory[category] = (byCategory[category] ?? 0) + 1;
    }

    // Agrupar por proveedor
    final Map<String, int> bySupplier = {};
    for (final item in items) {
      final supplier = item.supplierName ?? 'Sin proveedor';
      bySupplier[supplier] = (bySupplier[supplier] ?? 0) + 1;
    }

    // Agrupar por tipo
    final Map<String, int> byType = {};
    for (final item in items) {
      byType[item.itemType] = (byType[item.itemType] ?? 0) + 1;
    }

    // Calcular nivel de alerta para cada item y agrupar
    final Map<String, int> byAlertLevel = {};
    for (final item in items) {
      String alertLevel;
      if (item.currentStock <= 0) {
        alertLevel = 'critical';
      } else if (item.currentStock <= item.minimumStock) {
        alertLevel = 'low';
      } else if (item.currentStock < (item.maximumStock * 0.3)) {
        alertLevel = 'moderate';
      } else {
        alertLevel = 'normal';
      }
      byAlertLevel[alertLevel] = (byAlertLevel[alertLevel] ?? 0) + 1;
    }

    // Top items por valor (unitCost * currentStock)
    final topItems = List<InventoryItem>.from(items)..sort((a, b) {
      final aValue = (a.unitCost ?? 0.0) * a.currentStock;
      final bValue = (b.unitCost ?? 0.0) * b.currentStock;
      return bValue.compareTo(aValue);
    });

    // Items recientemente actualizados
    final recentItems =
        items.where((item) => item.updatedAt != null).toList()
          ..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));

    return InventoryStats(
      totalItems: items.length,
      activeItems: activeItems.length,
      inactiveItems: inactiveItems.length,
      lowStockItems: lowStockItems.length,
      outOfStockItems: outOfStockItems.length,
      totalStockValue: totalValue,
      averageStockValue: averageValue,
      itemsByCategory: byCategory,
      itemsBySupplier: bySupplier,
      itemsByType: byType,
      itemsByAlertLevel: byAlertLevel,
      topValueItems: topItems.take(10).toList(),
      recentlyUpdatedItems: recentItems.take(10).toList(),
      stockTrends: {}, // Se calcularía con datos históricos
      lastUpdated: DateTime.now(),
    );
  }

  // Porcentajes calculados
  double get activePercentage =>
      totalItems > 0 ? (activeItems / totalItems) * 100 : 0.0;
  double get lowStockPercentage =>
      totalItems > 0 ? (lowStockItems / totalItems) * 100 : 0.0;
  double get outOfStockPercentage =>
      totalItems > 0 ? (outOfStockItems / totalItems) * 100 : 0.0;

  // Estado general del inventario
  String get overallHealthStatus {
    if (outOfStockPercentage > 10) return 'critical';
    if (lowStockPercentage > 20) return 'warning';
    if (activePercentage > 90) return 'excellent';
    return 'good';
  }

  Color get healthStatusColor {
    switch (overallHealthStatus) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'excellent':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}

class InventoryStatsWidget extends StatefulWidget {
  final InventoryStats stats;
  final bool isLoading;
  final Function()? onRefresh;
  final Function(String)? onStatTap;
  final bool showCharts;
  final bool showTrends;
  final bool compact;

  const InventoryStatsWidget({
    super.key,
    required this.stats,
    this.isLoading = false,
    this.onRefresh,
    this.onStatTap,
    this.showCharts = true,
    this.showTrends = true,
    this.compact = false,
  });

  @override
  State<InventoryStatsWidget> createState() => _InventoryStatsWidgetState();
}

class _InventoryStatsWidgetState extends State<InventoryStatsWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  int _selectedTabIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.compact) {
      return _buildCompactView();
    }

    return _buildFullView();
  }

  Widget _buildLoadingState() {
    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando estadísticas...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactView() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Resumen de Inventario',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.onRefresh != null)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: widget.onRefresh,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Items',
                            widget.stats.totalItems.toString(),
                            Icons.inventory,
                            Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Stock Bajo',
                            widget.stats.lowStockItems.toString(),
                            Icons.warning,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Sin Stock',
                            widget.stats.outOfStockItems.toString(),
                            Icons.error,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHealthIndicator(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullView() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildTabBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                    children: [
                      _buildOverviewTab(),
                      _buildCategoriesTab(),
                      _buildAlertsTab(),
                      _buildTrendsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dashboard de Inventario',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _buildHealthIndicator(),
                    const SizedBox(width: 16),
                    if (widget.onRefresh != null)
                      ElevatedButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMainStatCard(
                    'Total Items',
                    widget.stats.totalItems.toString(),
                    Icons.inventory_2,
                    Theme.of(context).primaryColor,
                    '${widget.stats.activePercentage.toStringAsFixed(1)}% activos',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMainStatCard(
                    'Valor Total',
                    '\$${_formatCurrency(widget.stats.totalStockValue)}',
                    Icons.attach_money,
                    Colors.green,
                    'Promedio: \$${_formatCurrency(widget.stats.averageStockValue)}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMainStatCard(
                    'Alertas',
                    (widget.stats.lowStockItems + widget.stats.outOfStockItems)
                        .toString(),
                    Icons.warning_amber,
                    Colors.orange,
                    '${(widget.stats.lowStockPercentage + widget.stats.outOfStockPercentage).toStringAsFixed(1)}% del total',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildTabButton('Resumen', 0, Icons.dashboard),
          _buildTabButton('Categorías', 1, Icons.category),
          _buildTabButton('Alertas', 2, Icons.warning),
          _buildTabButton('Tendencias', 3, Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab de Resumen General
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid de estadísticas principales
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              _buildStatCard(
                'Items Activos',
                widget.stats.activeItems.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatCard(
                'Items Inactivos',
                widget.stats.inactiveItems.toString(),
                Icons.cancel,
                Colors.grey,
              ),
              _buildStatCard(
                'Stock Bajo',
                widget.stats.lowStockItems.toString(),
                Icons.warning,
                Colors.orange,
              ),
              _buildStatCard(
                'Sin Stock',
                widget.stats.outOfStockItems.toString(),
                Icons.error,
                Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Distribución por tipo de item
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribución por Tipo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...widget.stats.itemsByType.entries.map(
                    (entry) => _buildProgressRow(
                      entry.key,
                      entry.value,
                      widget.stats.totalItems,
                      _getTypeColor(entry.key),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Top items por valor
          if (widget.stats.topValueItems.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items de Mayor Valor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...widget.stats.topValueItems
                        .take(5)
                        .map((item) => _buildTopItemTile(item)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Tab de Categorías
  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items por Categoría',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.stats.itemsByCategory.length} categorías',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.stats.itemsByCategory.isNotEmpty) ...[
                    ...(widget.stats.itemsByCategory.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map(
                          (entry) => _buildCategoryTile(entry.key, entry.value),
                        )
                        ,
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No hay categorías disponibles'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items por Proveedor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.stats.itemsBySupplier.length} proveedores',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.stats.itemsBySupplier.isNotEmpty) ...[
                    ...(widget.stats.itemsBySupplier.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map(
                          (entry) => _buildSupplierTile(entry.key, entry.value),
                        )
                        ,
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No hay proveedores disponibles'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab de Alertas
  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de alertas
          Row(
            children: [
              Expanded(
                child: _buildAlertCard(
                  'Crítico',
                  widget.stats.itemsByAlertLevel['critical']?.toString() ?? '0',
                  Icons.error,
                  _getAlertColor(context, 'critical'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAlertCard(
                  'Bajo',
                  widget.stats.itemsByAlertLevel['low']?.toString() ?? '0',
                  Icons.warning,
                  _getAlertColor(context, 'low'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAlertCard(
                  'Moderado',
                  widget.stats.itemsByAlertLevel['moderate']?.toString() ?? '0',
                  Icons.info,
                  _getAlertColor(context, 'moderate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAlertCard(
                  'Normal',
                  widget.stats.itemsByAlertLevel['normal']?.toString() ?? '0',
                  Icons.check_circle,
                  _getAlertColor(context, 'normal'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Gráfico de distribución de alertas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribución de Niveles de Alerta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildAlertDistributionChart(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Estado general del inventario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estado General del Inventario',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildOverallHealthCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab de Tendencias
  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items Actualizados Recientemente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (widget.stats.recentlyUpdatedItems.isNotEmpty) ...[
                    ...widget.stats.recentlyUpdatedItems
                        .take(10)
                        .map((item) => _buildRecentItemTile(item)),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('No hay datos de tendencias disponibles'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información de Actualización',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Última actualización'),
                    subtitle: Text(_formatDateTime(widget.stats.lastUpdated)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory),
                    title: const Text('Total de items procesados'),
                    subtitle: Text('${widget.stats.totalItems} elementos'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calculate),
                    title: const Text('Valor promedio por item'),
                    subtitle: Text(
                      '\$${_formatCurrency(widget.stats.averageStockValue)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widgets auxiliares
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => widget.onStatTap?.call(title.toLowerCase()),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '$value (${(percentage * 100).toStringAsFixed(1)}%)',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItemTile(InventoryItem item) {
    final itemValue = (item.unitCost ?? 0.0) * item.currentStock;
    final alertLevel = _getItemAlertLevel(item);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getAlertColor(context, alertLevel).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2, color: _getAlertColor(context, alertLevel)),
      ),
      title: Text(item.name),
      subtitle: Text('SKU: ${item.sku} • Stock: ${item.currentStock}'),
      trailing: Text(
        '\$${_formatCurrency(itemValue)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: () => widget.onStatTap?.call('item_${item.id}'),
    );
  }

  Widget _buildCategoryTile(String category, int count) {
    final percentage =
        widget.stats.totalItems > 0
            ? (count / widget.stats.totalItems) * 100
            : 0.0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getCategoryColor(context, category).withOpacity(0.1),
        child: Icon(
          Icons.category,
          color: _getCategoryColor(context, category),
          size: 20,
        ),
      ),
      title: Text(category),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
      onTap: () => widget.onStatTap?.call('category_$category'),
    );
  }

  Widget _buildSupplierTile(String supplier, int count) {
    final percentage =
        widget.stats.totalItems > 0
            ? (count / widget.stats.totalItems) * 100
            : 0.0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getSupplierColor(context, supplier).withOpacity(0.1),
        child: Icon(
          Icons.business,
          color: _getSupplierColor(context, supplier),
          size: 20,
        ),
      ),
      title: Text(supplier),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
      onTap: () => widget.onStatTap?.call('supplier_$supplier'),
    );
  }

  Widget _buildAlertCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertDistributionChart() {
    final alerts = widget.stats.itemsByAlertLevel;
    final total = alerts.values.fold(0, (sum, count) => sum + count);

    if (total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No hay datos de alertas'),
        ),
      );
    }

    return Column(
      children:
          alerts.entries.map((entry) {
            final percentage = (entry.value / total);
    final color = _getAlertColor(context, entry.key);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _getAlertDisplayName(entry.key),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${entry.value} (${(percentage * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildOverallHealthCard() {
    final status = widget.stats.overallHealthStatus;
    final color = widget.stats.healthStatusColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getHealthIcon(status), color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getHealthDisplayName(status),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHealthDescription(status),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemTile(InventoryItem item) {
    final alertLevel = _getItemAlertLevel(item);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.update, color: Colors.blue),
      ),
      title: Text(item.name),
      subtitle: Text(
        '${item.sku} • Actualizado: ${_formatDateTime(item.updatedAt!)}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getAlertColor(context, alertLevel).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getAlertDisplayName(alertLevel),
          style: TextStyle(
            color: _getAlertColor(context, alertLevel),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () => widget.onStatTap?.call('item_${item.id}'),
    );
  }

  Widget _buildHealthIndicator() {
    final status = widget.stats.overallHealthStatus;
    final color = widget.stats.healthStatusColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getHealthIcon(status), color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            _getHealthDisplayName(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares y de formateo
  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(2);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Hace un momento';
    }
  }

  // Método para calcular el nivel de alerta de un item individual
  String _getItemAlertLevel(InventoryItem item) {
    if (item.currentStock <= 0) {
      return 'critical';
    } else if (item.currentStock <= item.minimumStock) {
      return 'low';
    } else if (item.currentStock < (item.maximumStock * 0.3)) {
      return 'moderate';
    } else {
      return 'normal';
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'repuesto':
        return Colors.blue;
      case 'insumo':
        return Colors.green;
      case 'herramienta':
        return Colors.orange;
      case 'consumible':
        return Colors.purple;
      case 'materia prima':
        return Colors.teal;
      case 'producto terminado':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(BuildContext context, String category) {
    // Paleta básica: usar un único acento derivado del branding
    return Theme.of(context).colorScheme.secondary;
  }

  Color _getSupplierColor(BuildContext context, String supplier) {
    // Paleta básica: un único color de acento para proveedores
    return Theme.of(context).colorScheme.primary;
  }

  Color _getAlertColor(BuildContext context, String alertLevel) {
    switch (alertLevel.toLowerCase()) {
      case 'critical':
        return context.errorColor;
      case 'low':
        return context.warningColor;
      case 'moderate':
        return Theme.of(context).colorScheme.primary;
      case 'normal':
        return context.successColor;
      default:
        return Theme.of(context).colorScheme.outlineVariant;
    }
  }

  String _getAlertDisplayName(String alertLevel) {
    switch (alertLevel.toLowerCase()) {
      case 'critical':
        return 'Crítico';
      case 'low':
        return 'Bajo';
      case 'moderate':
        return 'Moderado';
      case 'normal':
        return 'Normal';
      default:
        return alertLevel;
    }
  }

  IconData _getHealthIcon(String status) {
    switch (status) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'excellent':
        return Icons.verified;
      default:
        return Icons.check_circle;
    }
  }

  String _getHealthDisplayName(String status) {
    switch (status) {
      case 'critical':
        return 'Crítico';
      case 'warning':
        return 'Alerta';
      case 'excellent':
        return 'Excelente';
      default:
        return 'Bueno';
    }
  }

  String _getHealthDescription(String status) {
    switch (status) {
      case 'critical':
        return 'Más del 10% de items sin stock. Requiere atención inmediata.';
      case 'warning':
        return 'Más del 20% de items con stock bajo. Considere reposición.';
      case 'excellent':
        return 'Más del 90% de items activos. Inventario en excelente estado.';
      default:
        return 'Inventario en buen estado general.';
    }
  }
}
