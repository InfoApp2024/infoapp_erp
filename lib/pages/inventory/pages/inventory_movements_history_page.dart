// lib/pages/inventory/pages/inventory_movements_history_page.dart

import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:intl/intl.dart';

// Importar los modelos y servicios
import '../models/inventory_item_model.dart';
import '../models/inventory_movement_model.dart';
import '../services/inventory_api_service.dart';

class InventoryMovementsHistoryPage extends StatefulWidget {
  final InventoryItem item;

  const InventoryMovementsHistoryPage({super.key, required this.item});

  @override
  State<InventoryMovementsHistoryPage> createState() =>
      _InventoryMovementsHistoryPageState();
}

class _InventoryMovementsHistoryPageState
    extends State<InventoryMovementsHistoryPage> {
  // === VARIABLES DE ESTADO ===
  List<InventoryMovement> _movements = [];
  MovementStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  // Filtros
  String? _selectedMovementType;
  String? _selectedPeriod = 'all';
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _hasMoreData = true;

  // Controllers
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMovements();
    _loadStats();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // === MÉTODOS DE CARGA DE DATOS ===

  Future<void> _loadMovements({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _movements.clear();
        _currentPage = 0;
        _hasMoreData = true;
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (!_hasMoreData) {
      return;
    }

    try {
      final response = await InventoryApiService.getMovementsByItem(
        inventoryItemId: widget.item.id!,
        limit: _itemsPerPage,
        offset: _currentPage * _itemsPerPage,
        movementType: _selectedMovementType,
        period: _selectedPeriod,
      );

      if (response.success && response.data != null) {
        setState(() {
          if (refresh) {
            _movements = response.data!;
          } else {
            _movements.addAll(response.data!);
          }
          _hasMoreData = response.data!.length == _itemsPerPage;
          _currentPage++;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Error al cargar movimientos';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await InventoryApiService.getMovementStats(
        inventoryItemId: widget.item.id!,
        period: _selectedPeriod ?? 'all',
      );

      if (response.success && response.data != null) {
        setState(() {
          _stats = response.data;
        });
      }
    } catch (e) {
//       print('Error cargando estadísticas: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMovements();
    }
  }

  // Funciones de formateo
  String _formatNumber(num value) {
    return NumberFormat.decimalPattern('es_CO').format(value);
  }


  // === MÉTODOS DE FILTROS ===

  void _applyFilters() {
    _loadMovements(refresh: true);
    _loadStats();
  }

  void _resetFilters() {
    setState(() {
      _selectedMovementType = null;
      _selectedPeriod = 'all';
    });
    _applyFilters();
  }
  // === BUILD METHODS ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsCard(),
          _buildFiltersSection(),
          Expanded(child: _buildMovementsList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Historial de Movimientos'),
          Text(
            '${widget.item.name} (${widget.item.sku})',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) {
      return const SizedBox(height: 8);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de Movimientos',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total',
                  _stats!.totalMovements.toString(),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Entradas',
                  _stats!.totalEntries.toString(),
                  context.successColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Salidas',
                  _stats!.totalExits.toString(),
                  context.errorColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Ajustes',
                  _stats!.totalAdjustments.toString(),
                  context.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedMovementType,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...MovementType.values.map(
                  (type) => DropdownMenuItem(
                    value: type.value,
                    child: Text(type.displayName),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMovementType = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Período',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todo')),
                DropdownMenuItem(value: 'today', child: Text('Hoy')),
                DropdownMenuItem(value: 'week', child: Text('Esta semana')),
                DropdownMenuItem(value: 'month', child: Text('Este mes')),
                DropdownMenuItem(value: 'year', child: Text('Este año')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPeriod = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _applyFilters,
            icon: const Icon(Icons.filter_list, size: 16),
            label: const Text('Filtrar'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsList() {
    if (_isLoading && _movements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadMovements(refresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No hay movimientos registrados'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMovements(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _movements.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _movements.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final movement = _movements[index];
          return _buildMovementCard(movement);
        },
      ),
    );
  }

  Widget _buildMovementCard(InventoryMovement movement) {
    final isPositive = movement.isPositiveMovement;
    final color = isPositive ? context.successColor : context.errorColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPositive ? Icons.add : Icons.remove,
                    color: color,
                    size: 20,
                  ),
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
                            movement.movementTypeDisplayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            movement.stockChangeText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movement.movementReasonDisplayName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.inventory,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Stock: ${_formatNumber(movement.previousStock)} → ${_formatNumber(movement.newStock)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                movement.formattedCreatedAt,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
                    ],
                  ),
                ),
              ],
            ),
            if (movement.notes != null && movement.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  movement.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (movement.unitCost != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Costo unitario: \$${NumberFormat('#,##0.00').format(movement.unitCost)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (movement.totalCost != null)
                    Text(
                      'Total: \$${NumberFormat('#,##0.00').format(movement.totalCost)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
