// lib/pages/inventory/pages/inventory_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'dart:async';

// Importar los modelos y servicios reales
import '../services/inventory_api_service.dart';
import '../models/inventory_response_models.dart';

// ✅ NUEVO IMPORT - Widgets modularizados
import '../widgets/dashboard_widgets.dart';

class InventoryDashboardPage extends StatefulWidget {
  const InventoryDashboardPage({super.key});

  @override
  State<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends State<InventoryDashboardPage>
    with AutomaticKeepAliveClientMixin {
  // Estado del dashboard
  DashboardStats? _dashboardStats;
  LowStockResponse? _lowStockData;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  // Configuración del dashboard
  DashboardPeriod _selectedPeriod = DashboardPeriod.month;
  Timer? _autoRefreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // === MÉTODOS DE CARGA DE DATOS ===

  Future<void> _loadDashboardData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadDashboardStats(), //_loadLowStockItems()
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar dashboard: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final response = await InventoryApiService.getDashboardStats(
        period: _selectedPeriod.apiValue,
        includeCharts: true,
        includeTrends: true,
      );

      if (response.success && response.data != null && mounted) {
        setState(() {
          _dashboardStats = response.data;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = response.message ?? 'Error al cargar estadísticas';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar estadísticas: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadLowStockItems() async {
    try {
      final response = await InventoryApiService.getLowStockItems(
        alertLevel: 'all',
        limit: 10,
        sortBy: 'priority',
        includeProjections: true,
        includeRecommendations: true,
      );

      if (response.success && response.data != null && mounted) {
        setState(() {
          _lowStockData = response.data;
        });
      }
    } catch (e) {
      // Error silencioso para datos opcionales
      debugPrint('Error al cargar items con stock bajo: ${e.toString()}');
    }
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await _loadDashboardData();

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5), // Refrescar cada 5 minutos
      (_) => _refreshDashboard(),
    );
  }

  // === MÉTODOS DE NAVEGACIÓN ===

  void _navigateToAllItems() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navegando a todos los items...'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    // TODO: Implementar navegación a lista completa de items
  }

  void _navigateToMovements() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navegando a movimientos...'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    // TODO: Implementar navegación a movimientos
  }

  void _navigateToCategories() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navegando a categorías...'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    // TODO: Implementar navegación a categorías
  }

  void _navigateToLowStock() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navegando a items con stock bajo...'),
        backgroundColor: context.warningColor,
      ),
    );
    // TODO: Implementar navegación a items con stock bajo
  }

  void _navigateToOutOfStock() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navegando a items sin stock...'),
        backgroundColor: context.errorColor,
      ),
    );
    // TODO: Implementar navegación a items sin stock
  }

  void _navigateToLowStockDetails() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ver todas las alertas de stock...'),
        backgroundColor: context.warningColor,
      ),
    );
    // TODO: Implementar página de alertas detalladas
  }

  void _navigateToItemDetail(LowStockItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ver detalle de ${item.name}...'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    // TODO: Implementar navegación a detalle del item
  }

  void _navigateToMovementsHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ver historial completo de movimientos...'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    // TODO: Implementar página de historial de movimientos
  }

  // === MÉTODOS AUXILIARES ===

  String _getLastUpdateText() {
    if (_dashboardStats?.generatedAt != null) {
      final now = DateTime.now();
      final diff = now.difference(_dashboardStats!.generatedAt);

      if (diff.inMinutes < 1) {
        return 'Actualizado hace un momento';
      } else if (diff.inMinutes < 60) {
        return 'Actualizado hace ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Actualizado hace ${diff.inHours} h';
      } else {
        return 'Actualizado hace ${diff.inDays} días';
      }
    }
    return 'Última actualización: Ahora';
  }

  void _onPeriodChanged(DashboardPeriod period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadDashboardStats();
    }
  }

  // === WIDGET BUILD PRINCIPAL ===

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: _buildDashboardContent(),
      ),
    );
  }

  Widget _buildDashboardContent() {
    // Estado de carga inicial
    if (_isLoading && _dashboardStats == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando dashboard...'),
          ],
        ),
      );
    }

    // Estado de error
    if (_errorMessage != null && _dashboardStats == null) {
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
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Navegar a configuración o soporte
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Ayuda'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Contenido principal del dashboard
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // ✅ Header con selector de período
          DashboardHeaderWidget(
            selectedPeriod: _selectedPeriod,
            onPeriodChanged: _onPeriodChanged,
            onRefresh: _refreshDashboard,
            isRefreshing: _isRefreshing,
            lastUpdateText: _getLastUpdateText(),
          ),

          // ✅ Estadísticas principales
          Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estadísticas Principales',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DashboardStatsGrid(
                  dashboardStats: _dashboardStats,
                  onViewAllItems: _navigateToAllItems,
                  onViewMovements: _navigateToMovements,
                  onViewCategories: _navigateToCategories,
                ),
              ],
            ),
          ),

          // ✅ Estado del stock
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: StockStatusIndicator(
              dashboardStats: _dashboardStats,
              onViewLowStock: _navigateToLowStock,
              onViewOutOfStock: _navigateToOutOfStock,
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Alertas de stock bajo
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: DashboardAlertCard(
              lowStockData: _lowStockData,
              onViewAll: _navigateToLowStockDetails,
              onItemTap: _navigateToItemDetail,
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Actividad reciente
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: DashboardActivityCard(
              onViewHistory: _navigateToMovementsHistory,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
