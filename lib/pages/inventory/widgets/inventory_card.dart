// lib/pages/inventory/widgets/inventory_card.dart

import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import '../models/inventory_item_model.dart';

class InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;
  final bool isListView;
  final bool showActions;
  final bool showStockBadge;
  final bool showValueInfo;

  const InventoryCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onMove,
    this.isListView = false,
    this.showActions = true,
    this.showStockBadge = true,
    this.showValueInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin:
          isListView
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
              : const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getStatusColor(context).withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child:
            isListView ? _buildListLayout(context) : _buildGridLayout(context),
      ),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con SKU y badge de estado
          _buildHeader(context),

          const SizedBox(height: 8),

          // Nombre del item
          _buildItemName(context),

          const SizedBox(height: 8),

          // Información de stock
          _buildStockInfo(context),

          const Spacer(),

          // Footer con acciones
          if (showActions) _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildListLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Ícono del tipo de item
          _buildItemTypeIcon(),

          const SizedBox(width: 12),

          // Información principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SKU y nombre
                _buildItemName(context, includeSubtitle: true),

                const SizedBox(height: 4),

                // Información secundaria
                _buildSecondaryInfo(context),
              ],
            ),
          ),

          // Stock y valor
          _buildStockColumn(context),

          // Acciones
          if (showActions) _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // SKU
        Expanded(
          child: Text(
            item.sku,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Badge de estado de stock
        if (showStockBadge) _buildStockBadge(context),
      ],
    );
  }

  Widget _buildItemName(BuildContext context, {bool includeSubtitle = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style:
              isListView
                  ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
                  : Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          maxLines: isListView ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),

        if (includeSubtitle && isListView) ...[
          const SizedBox(height: 2),
          Text(
            item.sku,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStockInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getStatusColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_getStockIcon(), size: 16, color: _getStatusColor(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${item.currentStock} ${item.unitOfMeasure}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getStatusColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryInfo(BuildContext context) {
    List<String> infoParts = [];

    if (item.categoryName != null) {
      infoParts.add(item.categoryName!);
    }

    if (item.brand != null && item.brand!.isNotEmpty) {
      infoParts.add(item.brand!);
    }

    final infoText =
        infoParts.isNotEmpty ? infoParts.join(' • ') : item.itemTypeDisplayName;

    return Text(
      infoText,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStockColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Stock actual
        Text(
          '${item.currentStock}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: _getStatusColor(context),
          ),
        ),

        // Unidad de medida
        Text(
          item.unitOfMeasure,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),

        // Valor si se solicita
        if (showValueInfo) ...[
          const SizedBox(height: 4),
          Text(
            '\$${item.calculatedStockValue.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildStockBadge(BuildContext context) {
    final alertLevel = item.calculatedAlertLevel;

    if (alertLevel == 'normal') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _getStatusText(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (item.itemType.toLowerCase()) {
      case 'repuesto':
        iconData = Icons.build;
        iconColor = Colors.blue;
        break;
      case 'insumo':
        iconData = Icons.inventory;
        iconColor = Colors.green;
        break;
      case 'herramienta':
        iconData = Icons.handyman;
        iconColor = Colors.orange;
        break;
      case 'consumible':
        iconData = Icons.shopping_bag;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.inventory_2;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (isListView) {
      return _buildActionButton(context);
    }

    return Row(
      children: [
        // Botón de movimiento rápido
        Expanded(
          child: _buildQuickActionButton(
            context,
            icon: Icons.swap_horiz,
            label: 'Mover',
            onPressed: onMove,
            color: Theme.of(context).primaryColor,
          ),
        ),

        const SizedBox(width: 8),

        // Botón de editar
        _buildIconButton(
          context,
          icon: Icons.edit,
          onPressed: onEdit,
          tooltip: 'Editar',
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Más opciones',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'move':
            onMove?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Editar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'move',
              child: ListTile(
                leading: Icon(Icons.swap_horiz),
                title: Text('Registrar Movimiento'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (onDelete != null)
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // === MÉTODOS AUXILIARES ===

  Color _getStatusColor(BuildContext context) {
    switch (item.calculatedAlertLevel) {
      case 'critical':
        return context.errorColor;
      case 'low':
        return context.warningColor;
      case 'moderate':
        return Colors.amber.shade700;
      default:
        return context.successColor;
    }
  }

  IconData _getStockIcon() {
    switch (item.calculatedAlertLevel) {
      case 'critical':
        return Icons.error;
      case 'low':
        return Icons.warning;
      case 'moderate':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  String _getStatusText() {
    switch (item.calculatedAlertLevel) {
      case 'critical':
        return 'SIN STOCK';
      case 'low':
        return 'BAJO';
      case 'moderate':
        return 'MODERADO';
      default:
        return 'NORMAL';
    }
  }
}

// === VARIANTES ESPECIALIZADAS ===

/// Card compacta para listas densas
class CompactInventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const CompactInventoryCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getStatusColor().withOpacity(0.1),
          child: Text(
            item.currentStock.toString(),
            style: TextStyle(
              color: _getStatusColor(),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${item.sku} • ${item.itemTypeDisplayName}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.calculatedAlertLevel != 'normal')
              Icon(Icons.warning, color: _getStatusColor(), size: 16),
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: onEdit,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (item.calculatedAlertLevel) {
      case 'critical':
        return Colors.red;
      case 'low':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }
}

/// Card para dashboard con métricas destacadas
class DashboardInventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final bool showTrends;

  const DashboardInventoryCard({
    super.key,
    required this.item,
    this.onTap,
    this.showTrends = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getStatusColor(context).withOpacity(0.1),
                _getStatusColor(context).withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estado
              Row(
                children: [
                  Icon(_getStockIcon(), color: _getStatusColor(context), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Stock actual
              Text(
                '${item.currentStock} ${item.unitOfMeasure}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _getStatusColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              // Información adicional
              Text(
                'Valor: \$${item.calculatedStockValue.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),

              if (showTrends) ...[
                const SizedBox(height: 8),
                _buildTrendIndicator(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    // Simulación de tendencia - en implementación real vendría del API
    final isPositive = item.currentStock > item.minimumStock;

    return Row(
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          color: isPositive ? context.successColor : context.errorColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          isPositive ? 'Stock estable' : 'Requiere atención',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isPositive ? context.successColor : context.errorColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (item.calculatedAlertLevel) {
      case 'critical':
        return context.errorColor;
      case 'low':
        return context.warningColor;
      case 'moderate':
        return Colors.amber.shade700;
      default:
        return context.successColor;
    }
  }

  IconData _getStockIcon() {
    switch (item.calculatedAlertLevel) {
      case 'critical':
        return Icons.error;
      case 'low':
        return Icons.warning;
      case 'moderate':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }
}
