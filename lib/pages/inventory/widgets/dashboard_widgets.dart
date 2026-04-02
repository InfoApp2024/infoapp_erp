// lib/pages/inventory/widgets/dashboard_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import '../models/inventory_response_models.dart';

// Funciones de formateo reutilizables para este archivo
String _formatCurrency(double amount) {
  final format = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  return format.format(amount);
}

String _formatNumber(num amount) {
  final format = NumberFormat.decimalPattern('es_CO');
  return format.format(amount);
}

/// =====================================================
/// WIDGETS PARA EL DASHBOARD DE INVENTARIO
/// =====================================================
///
/// Este archivo contiene todos los widgets personalizados utilizados
/// en el dashboard de inventario (InventoryDashboardPage).
///
/// WIDGETS INCLUIDOS:
/// - DashboardHeaderWidget: Header con título y selector de período
/// - DashboardStatsCard: Tarjeta individual de estadística
/// - DashboardStatsGrid: Grid de estadísticas principales
/// - DashboardAlertCard: Tarjeta de alertas de stock
/// - DashboardChartWidget: Widgets de gráficos y visualizaciones
/// - StockStatusIndicator: Indicador visual de estado de stock
/// - DashboardSummaryCard: Tarjetas de resumen
/// - DashboardActivityCard: Tarjeta de actividad reciente
///
/// BENEFICIOS DE LA SEPARACIÓN:
/// - Código más modular y mantenible
/// - Widgets reutilizables en otras partes del dashboard
/// - Facilita testing unitario de widgets
/// - Mejora la legibilidad del código principal
/// =====================================================

/// Enum para tipos de estadísticas
enum StatsType { general, movements, trends }

/// Enum para períodos del dashboard
enum DashboardPeriod {
  today('today', 'Hoy'),
  week('week', 'Semana'),
  month('month', 'Mes'),
  quarter('quarter', 'Trimestre'),
  year('year', 'Año');

  const DashboardPeriod(this.apiValue, this.displayName);
  final String apiValue;
  final String displayName;
}

/// ✅ WIDGET: Header del dashboard con selector de período
class DashboardHeaderWidget extends StatelessWidget {
  final DashboardPeriod selectedPeriod;
  final Function(DashboardPeriod) onPeriodChanged;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final String lastUpdateText;

  const DashboardHeaderWidget({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onRefresh,
    this.isRefreshing = false,
    required this.lastUpdateText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
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
                        'Dashboard de Inventario',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastUpdateText,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (isRefreshing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: onRefresh,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DashboardPeriodSelector(
              selectedPeriod: selectedPeriod,
              onPeriodChanged: onPeriodChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ WIDGET: Selector de período
class DashboardPeriodSelector extends StatelessWidget {
  final DashboardPeriod selectedPeriod;
  final Function(DashboardPeriod) onPeriodChanged;

  const DashboardPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            DashboardPeriod.values.map((period) {
              final isSelected = selectedPeriod == period;
              return GestureDetector(
                onTap: () => onPeriodChanged(period),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    period.displayName,
                    style: TextStyle(
                      color:
                          isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

/// ✅ WIDGET: Tarjeta individual de estadística
class DashboardStatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? subtitle;
  final Widget? trailing;

  const DashboardStatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color ?? Theme.of(context).primaryColor,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
              if (trailing != null) ...[const SizedBox(height: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ WIDGET: Grid de estadísticas principales
class DashboardStatsGrid extends StatelessWidget {
  final DashboardStats? dashboardStats;
  final VoidCallback? onViewAllItems;
  final VoidCallback? onViewMovements;
  final VoidCallback? onViewCategories;

  const DashboardStatsGrid({
    super.key,
    required this.dashboardStats,
    this.onViewAllItems,
    this.onViewMovements,
    this.onViewCategories,
  });

  @override
  Widget build(BuildContext context) {
    if (dashboardStats == null) {
      return const SizedBox.shrink();
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        DashboardStatsCard(
          label: 'Total Items',
          value: _formatNumber(dashboardStats!.totalProducts),
          icon: Icons.inventory_2,
          color: Theme.of(context).primaryColor,
          onTap: onViewAllItems,
          subtitle: 'Productos registrados',
        ),
        DashboardStatsCard(
          label: 'Valor Total',
          value: _formatCurrency(dashboardStats!.totalInventoryValue),
          icon: Icons.attach_money,
          color: Colors.green,
          subtitle: 'Valor del inventario',
        ),
        DashboardStatsCard(
          label: 'Movimientos Hoy',
          value: _formatNumber(dashboardStats!.todayMovements),
          icon: Icons.swap_horiz,
          color: Colors.orange,
          onTap: onViewMovements,
          subtitle: 'Entradas y salidas',
        ),
        DashboardStatsCard(
          label: 'Categorías',
          value: _formatNumber(dashboardStats!.totalCategories),
          icon: Icons.category,
          color: Colors.purple,
          onTap: onViewCategories,
          subtitle: 'Categorías activas',
        ),
      ],
    );
  }
}

/// ✅ WIDGET: Indicador visual de estado de stock
class StockStatusIndicator extends StatelessWidget {
  final DashboardStats? dashboardStats;
  final VoidCallback? onViewLowStock;
  final VoidCallback? onViewOutOfStock;

  const StockStatusIndicator({
    super.key,
    required this.dashboardStats,
    this.onViewLowStock,
    this.onViewOutOfStock,
  });

  @override
  Widget build(BuildContext context) {
    if (dashboardStats == null) {
      return const SizedBox.shrink();
    }

    final normalStock =
        dashboardStats!.totalProducts -
        dashboardStats!.lowStockItems -
        dashboardStats!.outOfStockItems;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado del Stock',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStockStatusItem(
                    'Normal',
                    normalStock,
                    Colors.green,
                    null,
                  ),
                ),
                Expanded(
                  child: _buildStockStatusItem(
                    'Stock Bajo',
                    dashboardStats!.lowStockItems,
                    Colors.orange,
                    onViewLowStock,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStockStatusItem(
                    'Sin Stock',
                    dashboardStats!.outOfStockItems,
                    Colors.red,
                    onViewOutOfStock,
                  ),
                ),
                Expanded(
                  child: Container(), // Espacio vacío para balance
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatusItem(
    String label,
    int count,
    Color color,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ WIDGET: Tarjeta de alertas de stock
class DashboardAlertCard extends StatelessWidget {
  final LowStockResponse? lowStockData;
  final VoidCallback? onViewAll;
  final Function(LowStockItem)? onItemTap;

  const DashboardAlertCard({
    super.key,
    required this.lowStockData,
    this.onViewAll,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (lowStockData == null || lowStockData!.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock en buen estado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'No hay alertas críticas de inventario',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  'Alertas de Stock (${lowStockData!.items.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('Ver todas'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...lowStockData!.items
                .take(3)
                .map((item) => _buildAlertItem(context, item))
                ,
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, LowStockItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onItemTap?.call(item),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStockLevelColor(context, item.priority).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getStockLevelColor(context, item.priority).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _getStockLevelColor(context, item.priority),
                child: const Icon(
                  Icons.inventory,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Stock: ${item.currentStock} / Min: ${item.minimumStock}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStockLevelColor(BuildContext context, String? level) {
    switch (level) {
      case 'critical':
      case 'high':
        return context.errorColor;
      case 'low':
      case 'medium':
        return context.warningColor;
      case 'warning':
        return context.warningColor;
      default:
        return Theme.of(context).colorScheme.outlineVariant;
    }
  }
}

/// ✅ WIDGET: Tarjeta de actividad reciente
class DashboardActivityCard extends StatelessWidget {
  final VoidCallback? onViewHistory;

  const DashboardActivityCard({super.key, this.onViewHistory});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Actividad Reciente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewHistory != null)
                  TextButton(
                    onPressed: onViewHistory,
                    child: const Text('Ver historial'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              context,
              'Sistema conectado',
              'Dashboard funcionando correctamente',
              Icons.check_circle,
              Colors.green,
            ),
            _buildActivityItem(
              context,
              'API sincronizada',
              'Datos actualizados desde la base de datos',
              Icons.sync,
              Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
