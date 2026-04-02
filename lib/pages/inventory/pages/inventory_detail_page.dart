// lib/pages/inventory/pages/inventory_detail_page.dart

import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Importar los modelos y servicios reales
import '../models/inventory_item_model.dart';
import '../models/inventory_response_models.dart';
import '../services/inventory_api_service.dart';
import '../pages/inventory_form_page.dart';
import '../models/inventory_movement_model.dart';
import 'inventory_movements_history_page.dart';
import '../models/inventory_supplier_model.dart';
import '../widgets/inventory_supplier_widgets.dart';
import '../widgets/inventory_form_widgets.dart';
import 'package:infoapp/core/utils/currency_utils.dart';
import 'package:infoapp/widgets/currency_input_formatter.dart';

class InventoryDetailPage extends StatefulWidget {
  final InventoryItem item;

  const InventoryDetailPage({super.key, required this.item});

  @override
  State<InventoryDetailPage> createState() => _InventoryDetailPageState();
}

class _InventoryDetailPageState extends State<InventoryDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  InventoryItem? _detailedItem;
  bool _isLoading = false;
  String? _errorMessage;

  // Datos adicionales del detalle
  List<Map<String, dynamic>> _recentMovements = [];
  final List<Map<String, dynamic>> _relatedServices = [];
  Map<String, dynamic>? _movementStats;
  final List<Map<String, dynamic>> _alerts = [];
  final List<String> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _detailedItem = widget.item;
    _loadItemDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // === MÉTODOS DE CARGA DE DATOS ===

  Future<void> _loadItemDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Cargar detalle y movimientos en paralelo
      final results = await Future.wait([
        InventoryApiService.getItemDetail(
          id: widget.item.id,
          includeMovements: false, // Cargamos movimientos por separado
          includeServices: true,
        ),
        InventoryApiService.getMovementsByItem(
          inventoryItemId: widget.item.id!,
          limit: 50,
        ),
      ]);

      final detailResponse =
          results[0] as ApiResponse<InventoryItemDetailResponse>;
      final movementsResponse =
          results[1] as ApiResponse<List<InventoryMovement>>;

      if (detailResponse.success && detailResponse.data != null) {
        setState(() {
          _detailedItem = detailResponse.data!.item;
          _processDetailData(detailResponse.data!);

          // Asignar movimientos obtenidos explícitamente
          if (movementsResponse.success && movementsResponse.data != null) {
            _recentMovements =
                movementsResponse.data!.map((m) => m.toJson()).toList();
          }
        });
      } else {
        setState(() {
          _errorMessage = detailResponse.message ?? 'Error al cargar detalle';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar detalle: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processDetailData(InventoryItemDetailResponse detail) {
    if (detail.movements != null) {
      _recentMovements = detail.movements!;
    } else {
      _recentMovements = [];
    }

    if (detail.movementStats != null) {
      _movementStats = detail.movementStats;
    }

    _relatedServices.clear();
    if (detail.relatedServices != null) {
      _relatedServices.addAll(detail.relatedServices!);
    }

    _alerts.clear();
    _recommendations.clear();

    if (_detailedItem!.hasLowStock) {
      _alerts.add({
        'type': 'warning',
        'message': 'Stock por debajo del mínimo recomendado',
      });
      _recommendations.add('Considere realizar una orden de compra');
    }

    if (_detailedItem!.isOutOfStock) {
      _alerts.add({
        'type': 'critical',
        'message': 'Producto sin stock disponible',
      });
      _recommendations.add('Reabastecer inmediatamente');
    }
  }

  Future<void> _refreshDetail() async {
    await _loadItemDetail();
  }

  // === MÉTODOS DE INTERACCIÓN ===

  Future<void> _navigateToEdit() async {
    if (_detailedItem == null) return;

    // Mostrar loading mientras carga los datos necesarios
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Cargando formulario...'),
              ],
            ),
          ),
    );

    try {
      // Cargar categorías y proveedores para el formulario
      final categoriesResponse = await InventoryApiService.getCategories();
      final suppliersResponse = await InventoryApiService.getSuppliers();

      // Cerrar el dialog de loading
      if (mounted) Navigator.pop(context);

      if (!categoriesResponse.success || !suppliersResponse.success) {
        _showErrorDialog(
          'No se pudieron cargar los datos necesarios para la edición.\n'
          'Categorías: ${categoriesResponse.message ?? 'Error'}\n'
          'Proveedores: ${suppliersResponse.message ?? 'Error'}',
        );
        return;
      }

      final categories = categoriesResponse.data?.categories ?? [];
      final suppliers = suppliersResponse.data?.suppliers ?? [];

      // Navegar a la página de edición
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => InventoryFormPage(
                item: _detailedItem, // Pasar el item para edición
                categories: categories,
                suppliers: suppliers,
              ),
        ),
      );

      // Si se guardó exitosamente, recargar el detalle
      if (result == true) {
        await _refreshDetail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar el dialog de loading si aún está abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorDialog(
        'Error al abrir el formulario de edición: ${e.toString()}',
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // === MÉTODOS AUXILIARES ===

  String _formatCurrency(double amount, {int decimalDigits = 0}) {
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

  Color _getStockColor() {
    if (_detailedItem == null) {
      return Theme.of(context).colorScheme.outlineVariant;
    }
    if (_detailedItem!.isOutOfStock) return context.errorColor;
    if (_detailedItem!.hasLowStock) return context.warningColor;
    return context.successColor;
  }

  String _getAlertLevel(InventoryItem item) {
    if (item.isOutOfStock) return 'critical';
    if (item.hasLowStock) return 'low';
    if (item.maximumStock > 0 && item.currentStock >= item.maximumStock) {
      return 'high';
    }
    return 'normal';
  }

  double _getStockPercentage(InventoryItem item) {
    if (item.maximumStock <= 0) return 0;
    return (item.currentStock / item.maximumStock) * 100;
  }

  String _getCategoryName(InventoryItem item) {
    return item.categoryName ?? 'Sin categoría';
  }

  String _getSupplierName(InventoryItem item) {
    return item.supplierName ?? 'Sin proveedor';
  }

  String _getTypeDisplayName(InventoryItem item) {
    return item.itemTypeDisplayName;
  }

  // === WIDGETS BUILD ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_detailedItem?.name ?? 'Detalle del Item').toUpperCase()),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDetail,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Registrar Movimiento',
            onPressed: _showMovementDialog,
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _navigateToEdit),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.copy),
                      title: Text('Duplicar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: ListTile(
                      leading: Icon(Icons.history),
                      title: Text('Ver historial completo'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('Compartir'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Información', icon: Icon(Icons.info_outline)),
            Tab(text: 'Movimientos', icon: Icon(Icons.swap_horiz)),
            Tab(text: 'Análisis', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando detalle...'),
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
            ElevatedButton(
              onPressed: _loadItemDetail,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDetail,
      child: Column(
        children: [
          _buildHeaderCard(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInformationTab(),
                _buildMovementsTab(),
                _buildAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    if (_detailedItem == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
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
                        Row(
                          children: [
                            Text(
                              _detailedItem!.sku.toUpperCase(),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap:
                                  () => _copyToClipboard(
                                    _detailedItem!.sku,
                                    'SKU',
                                  ),
                              child: Icon(
                                Icons.copy,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _detailedItem!.name.toUpperCase(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  _buildStockStatusChip(),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactStockInfo(
              'COSTO',
              _formatCurrency(
                _detailedItem!.lastCost > 0
                    ? _detailedItem!.lastCost
                    : _detailedItem!.initialCost,
              ),
              Icons.shopping_bag_outlined,
            ),
            _buildVerticalDivider(),
            _buildCompactStockInfo(
              'VENTA',
              _formatCurrency(_detailedItem!.unitCost),
              Icons.sell_outlined,
            ),
            _buildVerticalDivider(),
            _buildCompactStockInfo(
              'STOCK',
              _formatNumber(_detailedItem!.currentStock),
              Icons.inventory_2_outlined,
              color: _getStockColor(),
            ),
            _buildVerticalDivider(),
            _buildCompactStockInfo(
              'TOTAL',
              _formatCurrency(_detailedItem!.calculatedStockValue),
              Icons.attach_money,
            ),
                  ],
                ),
              ),
              if (_alerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildAlertsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockStatusChip() {
    final alertLevel = _getAlertLevel(_detailedItem!);
    Color chipColor;
    String label;

    switch (alertLevel) {
      case 'critical':
        chipColor = context.errorColor;
        label = 'Sin Stock';
        break;
      case 'low':
        chipColor = context.warningColor;
        label = 'STOCK BAJO';
        break;
      case 'high':
        chipColor = Theme.of(context).colorScheme.primary;
        label = 'STOCK ALTO';
        break;
      default:
        chipColor = context.successColor;
        label = 'NORMAL';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildCompactStockInfo(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    final alert = _alerts.first;
    final isError = alert['type'] == 'critical';
    final color = isError ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error : Icons.warning_amber,
            color: color.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert['message'],
              style: TextStyle(color: color.shade800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de Resumen Financiero y Stock (Nueva UI)
          _buildFinancialSummaryCard(),
          const SizedBox(height: 24),

          _buildInfoSection('INFORMACIÓN BÁSICA', [
            InfoItem(
              'DESCRIPCIÓN',
              (_detailedItem?.description ?? 'NO ESPECIFICADA').toUpperCase(),
            ),
            InfoItem('TIPO', _getTypeDisplayName(_detailedItem!).toUpperCase()),
            InfoItem('CATEGORÍA', _getCategoryName(_detailedItem!).toUpperCase()),
          ]),
          const SizedBox(height: 24),
          _buildSupplierSection(),

          const SizedBox(height: 24),
          _buildInfoSection('UBICACIÓN E IDENTIFICACIÓN', [
            InfoItem(
              'UBICACIÓN',
              (_detailedItem?.fullLocation ?? 'NO ESPECIFICADA').toUpperCase(),
            ),
            InfoItem(
              'CÓDIGO DE BARRAS',
              (_detailedItem?.barcode ?? 'NO ESPECIFICADO').toUpperCase(),
            ),
            InfoItem(
              'ESTADO',
              (_detailedItem?.isActive == true ? 'ACTIVO' : 'INACTIVO').toUpperCase(),
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('DETALLE DE STOCK', [
            InfoItem(
              'STOCK MÍNIMO',
              '${_detailedItem?.minimumStock ?? 0} ${(_detailedItem?.unitOfMeasure ?? '').toUpperCase()}',
            ),
            InfoItem(
              'STOCK MÁXIMO',
              _detailedItem?.maximumStock != null &&
                      _detailedItem!.maximumStock > 0
                  ? '${_detailedItem!.maximumStock} ${(_detailedItem!.unitOfMeasure).toUpperCase()}'
                  : 'NO DEFINIDO',
            ),
            InfoItem(
              'PORCENTAJE DE STOCK',
              _detailedItem?.maximumStock != null &&
                      _detailedItem!.maximumStock > 0
                  ? '${_getStockPercentage(_detailedItem!).toStringAsFixed(1)}%'
                  : 'N/A',
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('HISTÓRICO DE COSTOS', [
            InfoItem(
              'COSTO PROMEDIO',
              _formatCurrency(
                _detailedItem?.averageCost ?? 0,
                decimalDigits: 2,
              ),
            ),
            InfoItem(
              'ÚLTIMO COSTO',
              _formatCurrency(_detailedItem?.lastCost ?? 0, decimalDigits: 2),
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('FECHAS', [
            InfoItem(
              'FECHA DE CREACIÓN',
              _formatDate(_detailedItem!.createdAt),
            ),
            InfoItem(
              'ÚLTIMA ACTUALIZACIÓN',
              _formatDate(_detailedItem!.updatedAt),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    if (_detailedItem == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STOCK ACTUAL',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatNumber(_detailedItem!.currentStock)} ${(_detailedItem!.unitOfMeasure).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStockColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStockColor().withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _getStockStatusText(),
                    style: TextStyle(
                      color: _getStockColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialItem(
                    'COSTO COMPRA',
                    _formatCurrency(_detailedItem!.initialCost),
                    Icons.shopping_cart_outlined,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildFinancialItem(
                    'PRECIO VENTA',
                    _formatCurrency(_detailedItem!.unitCost),
                    Icons.sell_outlined,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildFinancialItem(
                    'VALOR TOTAL',
                    _formatCurrency(_detailedItem!.calculatedStockValue),
                    Icons.monetization_on_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _getStockStatusText() {
    if (_detailedItem == null) return '';
    if (_detailedItem!.isOutOfStock) return 'SIN STOCK';
    if (_detailedItem!.hasLowStock) return 'STOCK BAJO';
    return 'EN STOCK';
  }

  Widget _buildInfoSection(String title, List<InfoItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) => _buildInfoRow(item)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(InfoItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '${item.label}:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_movementStats != null) ...[
            _buildMovementStats(),
            const SizedBox(height: 24),
          ],
          Text(
            'Movimientos Recientes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildMovementsList(),
        ],
      ),
    );
  }

  Widget _buildMovementStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de Movimientos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    _formatNumber(
                      _movementStats!['total_movements'] as num? ?? 0,
                    ),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Entradas',
                    _formatNumber(
                      _movementStats!['total_entries'] as num? ?? 0,
                    ),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Salidas',
                    _formatNumber(_movementStats!['total_exits'] as num? ?? 0),
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMovementsList() {
    if (_recentMovements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No hay movimientos registrados')),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentMovements.length,
      itemBuilder: (context, index) {
        final movement = _recentMovements[index];
        return _buildMovementItem(movement);
      },
    );
  }

  Widget _buildMovementItem(Map<String, dynamic> movement) {
    final movementType = movement['movement_type'] as String;
    final isEntry = movementType == 'entrada';
    final isExit = movementType == 'salida';

    Color color;
    IconData icon;

    if (isEntry) {
      color = Colors.green;
      icon = Icons.add;
    } else if (isExit) {
      color = Colors.red;
      icon = Icons.remove;
    } else {
      color = Colors.blue;
      icon = Icons.tune;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${isEntry
                                ? '+'
                                : isExit
                                ? '-'
                                : '±'}${_formatNumber(movement['quantity'] as num? ?? 0)} ${_detailedItem?.unitOfMeasure ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatMovementDate(movement['created_at']),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatNumber(movement['previous_stock'] as num? ?? 0)} → ${_formatNumber(movement['new_stock'] as num? ?? 0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (movement['notes'] != null &&
                movement['notes'].toString().isNotEmpty) ...[
              const Divider(height: 16),

              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        movement['notes'],
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recommendations.isNotEmpty) ...[
            Text(
              'Recomendaciones',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._recommendations.map(
              (recommendation) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                  ),
                  title: Text(recommendation),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Análisis de Rendimiento',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAnalysisCards(),
        ],
      ),
    );
  }

  Widget _buildAnalysisCards() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado del Stock',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStockAnalysisText(),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _getStockProgressValue(),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(_getStockColor()),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_getStockProgressValue() * 100).toStringAsFixed(0)}% del stock máximo',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información del Producto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Producto: ${_detailedItem!.name}\nSKU: ${_detailedItem!.sku}\nCategoría: ${_getCategoryName(_detailedItem!)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proveedor',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSimpleSupplierDisplay(),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSupplierDisplay() {
    final supplierName = _getSupplierName(_detailedItem!);

    if (supplierName == 'Sin proveedor') {
      return Row(
        children: [
          Icon(Icons.business_outlined, color: Colors.grey[400], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin proveedor asignado',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use el formulario de edición para asignar un proveedor',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          radius: 24,
          child: Text(
            supplierName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
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
                supplierName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),

              const SizedBox(height: 4),
              Text(
                'Proveedor del item',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        Icon(Icons.edit_note, color: Colors.grey[400], size: 20),
      ],
    );
  }

  void _showMovementDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMovementDialog(),
    );
  }

  void _handleMovementCreated(InventoryMovement movement) {
    // Actualizar el stock local inmediatamente
    setState(() {
      _detailedItem = _detailedItem!.copyWith(
        currentStock: movement.newStock,
        updatedAt: DateTime.now(),
      );
    });

    // Mostrar mensaje de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${movement.movementTypeDisplayName}: ${movement.stockChangeText} ${movement.unitOfMeasure ?? 'unidades'}',
        ),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Ver detalles',
          textColor: Colors.white,
          onPressed: () {
            // Opcionalmente mostrar más detalles del movimiento
          },
        ),
      ),
    );

    // Recargar datos completos del item
    _refreshDetail();
  }

  Widget _buildMovementDialog() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Registrar Movimiento',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: _MovementForm(
                      item: _detailedItem!,
                      onMovementCreated: (movement) {
                        Navigator.pop(context);
                        _handleMovementCreated(movement);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  // === MÉTODOS AUXILIARES ===

  String _getStockAnalysisText() {
    if (_detailedItem == null) return 'Sin información disponible';

    if (_detailedItem!.isOutOfStock) {
      return 'Este producto está sin stock. Se requiere reabastecimiento inmediato.';
    } else if (_detailedItem!.hasLowStock) {
      return 'El stock está por debajo del mínimo recomendado. Considere realizar una orden de compra.';
    } else {
      return 'El stock se encuentra en niveles normales.';
    }
  }

  double _getStockProgressValue() {
    if (_detailedItem == null || _detailedItem!.maximumStock <= 0) return 0.0;
    return (_detailedItem!.currentStock / _detailedItem!.maximumStock).clamp(
      0.0,
      1.0,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No disponible';

    try {
      final now = DateTime.now();
      // Comparar fechas por día calendario, no por diferencia de tiempo total
      final today = DateTime(now.year, now.month, now.day);
      final dateToCompare = DateTime(date.year, date.month, date.day);
      final difference = today.difference(dateToCompare).inDays;

      if (difference == 0) {
        return 'Hoy ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference == 1) {
        return 'Ayer ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference < 7) {
        return 'Hace $difference días';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  String _formatMovementDate(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) return '';
    var dateStr = dateString.toString();

    try {
      // Normalizar formato (espacio por T)
      if (dateStr.contains(' ')) {
        dateStr = dateStr.replaceFirst(' ', 'T');
      }

      // Si no tiene información de zona horaria (ni Z ni offset), asumir UTC
      // Esto es común cuando el backend envía fechas UTC sin la 'Z'
      if (!dateStr.endsWith('Z') &&
          !dateStr.contains(RegExp(r'[+-]\d{2}:?\d{2}'))) {
        dateStr += 'Z';
      }

      final date = DateTime.parse(dateStr);
      return _formatDate(date.toLocal());
    } catch (e) {
      return dateString.toString();
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'duplicate':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicar item (próximamente)')),
        );
        break;
      case 'history':
        if (_detailedItem != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      InventoryMovementsHistoryPage(item: _detailedItem!),
            ),
          );
        }
        break;
      case 'share':
        final itemInfo =
            'SKU: ${_detailedItem?.sku}\nNombre: ${_detailedItem?.name}\nStock: ${_detailedItem?.currentStock}';
        _copyToClipboard(itemInfo, 'Información del item');
        break;
    }
  }
}

// === WIDGET DEL FORMULARIO DE MOVIMIENTO ===

class _MovementForm extends StatefulWidget {
  final InventoryItem item;
  final Function(InventoryMovement) onMovementCreated;

  const _MovementForm({required this.item, required this.onMovementCreated});

  @override
  State<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<_MovementForm> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _costController =
      TextEditingController(); // Nuevo controlador para costo
  final _salePriceController =
      TextEditingController(); // Nuevo controlador para precio venta

  MovementType _selectedType = MovementType.entrada;
  MovementReason? _selectedReason;
  bool _isLoading = false;

  // Proveedores
  List<InventorySupplier> _suppliers = [];
  InventorySupplier? _selectedSupplier;

  @override
  void initState() {
    super.initState();
    _updateAvailableReasons();
    _initializeCostFields();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final response = await InventoryApiService.getSuppliers(limit: 100);
      if (response.success && response.data != null) {
        if (mounted) {
          setState(() {
            _suppliers = response.data!.suppliers;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
    }
  }

  void _initializeCostFields() {
    // Solo pre-llenar para entradas
    if (_selectedType == MovementType.entrada) {
      // Costo de compra: Preferir último costo, sino costo inicial
      final cost =
          widget.item.lastCost > 0
              ? widget.item.lastCost
              : (widget.item.initialCost ?? 0.0);

      if (cost > 0) {
        _costController.text = CurrencyUtils.format(cost);
      }

      // Precio de venta
      if (widget.item.unitCost > 0) {
        _salePriceController.text = CurrencyUtils.format(widget.item.unitCost);
      }
    } else {
      _costController.clear();
      _salePriceController.clear();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _costController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  void _updateAvailableReasons() {
    final availableReasons = MovementReason.getByType(_selectedType);
    if (availableReasons.isNotEmpty) {
      _selectedReason = availableReasons.first;
    } else {
      _selectedReason = null;
    }
  }

  double? _getNewStock() {
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null) return null;

    switch (_selectedType) {
      case MovementType.entrada:
        return widget.item.currentStock + quantity;
      case MovementType.salida:
        return widget.item.currentStock - quantity;
      case MovementType.ajuste:
        return quantity;
      case MovementType.transferencia:
        return widget.item.currentStock - quantity;
    }
  }

  bool _isValidMovement() {
    final newStock = _getNewStock();
    return newStock != null && newStock >= 0;
  }

  Future<void> _submitMovement() async {
    if (!_formKey.currentState!.validate() || _selectedReason == null) return;

    // Validación adicional para proveedor en entradas o devoluciones
    if ((_selectedType == MovementType.entrada ||
            (_selectedType == MovementType.salida &&
                _selectedReason == MovementReason.devolucion)) &&
        _selectedSupplier == null) {
      _showError('Por favor selecciona un proveedor');
      return;
    }

    final quantity = CurrencyUtils.parse(_quantityController.text);

    // Determinar el costo unitario
    // Solo se envía para Entradas si el usuario ingresó un valor
    double? unitCost;
    double? newSalePrice;

    if (_selectedType == MovementType.entrada) {
      if (_costController.text.isNotEmpty) {
        unitCost = CurrencyUtils.parse(_costController.text);
      }
      if (_salePriceController.text.isNotEmpty) {
        newSalePrice = CurrencyUtils.parse(_salePriceController.text);
      }
    }
    // Para salidas y otros, dejamos que el backend decida (usará promedio o último costo)

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await InventoryApiService.createMovement(
        inventoryItemId: widget.item.id!,
        movementType: _selectedType.value,
        movementReason: _selectedReason!.value,
        quantity: quantity,
        unitCost: unitCost,
        newSalePrice: newSalePrice, // Enviamos el nuevo precio de venta
        // Enviar tipo de referencia como 'purchase' para compras
        referenceType:
            ((_selectedType == MovementType.entrada ||
                        (_selectedType == MovementType.salida &&
                            _selectedReason == MovementReason.devolucion)) &&
                    _selectedSupplier != null)
                ? 'purchase'
                : null,
        referenceId:
            ((_selectedType == MovementType.entrada ||
                        (_selectedType == MovementType.salida &&
                            _selectedReason == MovementReason.devolucion)) &&
                    _selectedSupplier != null)
                ? int.tryParse(_selectedSupplier!.id)
                : null,
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
      );

      if (response.success && response.data != null) {
        widget.onMovementCreated(response.data!);
      } else {
        _showError(response.message ?? 'Error al crear el movimiento');
      }
    } catch (e) {
      _showError('Error inesperado: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text('SKU: ${widget.item.sku}'),
                Text(
                  'Stock actual: ${widget.item.currentStock} ${widget.item.unitOfMeasure}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Movement type
          const Text(
            'Tipo de Movimiento',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children:
                MovementType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                          _updateAvailableReasons();
                          _quantityController.clear();
                          _initializeCostFields(); // Reinicializar costos al cambiar tipo
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getIconForType(type),
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.displayName,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),

          const SizedBox(height: 20),

          // Reason
          const Text(
            'Motivo *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<MovementReason>(
            initialValue: _selectedReason,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            items:
                MovementReason.getByType(_selectedType)
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason.displayName),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value;
              });
            },
            validator: (value) => value == null ? 'Selecciona un motivo' : null,
          ),

          const SizedBox(height: 20),

          // Selector de proveedor (solo para entradas o devoluciones de salida)
          if (_selectedType == MovementType.entrada ||
              (_selectedType == MovementType.salida &&
                  _selectedReason == MovementReason.devolucion)) ...[
            InventorySupplierSelector(
              isRequired: true,
              selectedSupplierId:
                  _selectedSupplier?.id != null
                      ? int.tryParse(_selectedSupplier!.id)
                      : null,
              initialSuppliers: _suppliers,
              onSupplierChanged: (supplier) {
                setState(() {
                  _selectedSupplier = supplier;
                });
              },
              onMessage: (message, isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: isSuccess ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Costo Unitario y Precio Venta (Solo para Entradas)
          if (_selectedType == MovementType.entrada) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Costo Unitario (Compra) *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                          hintText: 'Costo',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final cost = CurrencyUtils.parse(value);
                          if (cost <= 0) {
                            return 'Debe ser > 0';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Precio Venta *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _salePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                          hintText: 'Venta',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          final price = CurrencyUtils.parse(value);
                          if (price <= 0) {
                            return 'Debe ser > 0';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InventoryMarginPreview(
              unitCost: CurrencyUtils.parse(_salePriceController.text),
              averageCost: CurrencyUtils.parse(_costController.text),
            ),
            const SizedBox(height: 20),
          ],

          Text(
            '${_selectedType == MovementType.ajuste ? 'Nuevo Stock Total' : 'Cantidad'} *',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixText: widget.item.unitOfMeasure,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa una cantidad';
              }
              final quantity = int.tryParse(value);
              if (quantity == null || quantity <= 0) {
                return 'Ingresa una cantidad válida';
              }
              if (!_isValidMovement()) {
                return 'El movimiento resultaría en stock negativo';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Notes
          const Text(
            'Notas (opcional)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Agregar comentarios sobre el movimiento...',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Preview
          if (_quantityController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isValidMovement() ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _isValidMovement()
                          ? Colors.green[200]!
                          : Colors.red[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista previa:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Stock actual: ${widget.item.currentStock}'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Nuevo stock: ${_getNewStock() ?? "Error"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              _isValidMovement()
                                  ? Colors.green[700]
                                  : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                  if (!_isValidMovement()) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Stock insuficiente',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ||
                              !_isValidMovement() ||
                              _quantityController.text.isEmpty
                          ? null
                          : _submitMovement,
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Registrar Movimiento'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(MovementType type) {
    switch (type) {
      case MovementType.entrada:
        return Icons.add;
      case MovementType.salida:
        return Icons.remove;
      case MovementType.ajuste:
        return Icons.tune;
      case MovementType.transferencia:
        return Icons.swap_horiz;
    }
  }
}
// === DIÁLOGOS PARA GESTIÓN DE PROVEEDORES ===

// === CLASES AUXILIARES ===

class InfoItem {
  final String label;
  final String value;

  InfoItem(this.label, this.value);
}
