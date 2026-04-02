import 'package:flutter/material.dart';
import 'package:infoapp/models/dashboard_kpi.dart';
import 'package:infoapp/services/dashboard_service.dart';
import 'package:infoapp/ui/dashboard/widgets/kpi_card.dart';
import 'package:infoapp/ui/dashboard/widgets/services_chart.dart';
import 'package:infoapp/ui/dashboard/widgets/simple_bar_chart.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DashboardService _service = DashboardService();
  bool _isLoading = false;
  KpiServicios? _kpiServicios;
  KpiInventario? _kpiInventario;

  // Filtros de fecha
  DateTime _fechaInicio = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _fechaFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final kpiS = await _service.getKpiServicios(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
      );
      final kpiI = await _service.getKpiInventario();

      if (mounted) {
        setState(() {
          _kpiServicios = kpiS;
          _kpiInventario = kpiI;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando Dashboard: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Gerencial'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Operaciones'),
            Tab(icon: Icon(Icons.inventory), text: 'Bodega & Finanzas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDateRange,
            tooltip: 'Filtrar Fechas',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [_buildOperacionesTab(), _buildInventarioTab()],
              ),
    );
  }

  Widget _buildOperacionesTab() {
    if (_kpiServicios == null) return const SizedBox();

    final s = _kpiServicios!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Fechas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Periodo: ${DateFormat('dd/MM/yyyy').format(_fechaInicio)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin)}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Cambiar'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Tarjetas de Resumen (Top Row)
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  title: 'Total',
                  value: '${s.resumen.total}',
                  icon: Icons.assignment,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KpiCard(
                  title: 'Finalizados',
                  value: '${s.resumen.finalizados}',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KpiCard(
                  title: 'Activos',
                  value: '${s.resumen.activos}',
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KpiCard(
                  title: 'Anulados',
                  value: '${s.resumen.anulados}',
                  icon: Icons.cancel,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Gráficas Principales (Distribución)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDashboardTile(
                  title: 'Estado de Servicios',
                  child: ServicesPieChart(
                    title: '',
                    data: s.distribucionEstados,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardTile(
                  title: 'Tipos de Mantenimiento',
                  child: ServicesPieChart(
                    title: '',
                    data: s.tiposMantenimiento,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Métricas de Rendimiento (Barras)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDashboardTile(
                  title: 'Top 10 Técnicos (Servicios)',
                  child: SimpleBarChart(
                    title: '',
                    data: s.cargaTecnicos,
                    barColor: Colors.indigo,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardTile(
                  title: 'Top 5 Equipos (Costo)',
                  child: SimpleBarChart(
                    title: '',
                    data: s.topEquiposCosto,
                    barColor: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Sección de Anulados (Detalle)
          if (s.serviciosAnulados.isNotEmpty)
            _buildDashboardTile(
              title: 'Últimos Servicios Anulados',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.red,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Lista detallada de servicios cancelados y sus motivos',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: s.serviciosAnulados.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final anulado = s.serviciosAnulados[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: Icon(
                            Icons.close,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'OS #${anulado.ordenServicio}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(anulado.fecha),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              anulado.motivo,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Por: ${anulado.usuario}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          // 5. Repuestos
          _buildDashboardTile(
            title: 'Top Repuestos Más Usados',
            child: SimpleBarChart(
              title: '',
              data: s.topRepuestosUso,
              barColor: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTile({
    required String title,
    required Widget child,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: iconColor ?? Colors.black87),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInventarioTab() {
    if (_kpiInventario == null) return const SizedBox();

    final i = _kpiInventario!;
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          KpiCard(
            title: 'Valor Total Inventario',
            value: currencyFormat.format(i.resumen.valorTotal),
            icon: Icons.monetization_on,
            color: Colors.green[700]!,
            subtitle:
                '${i.resumen.totalItems} ítems / ${i.resumen.totalUnidades} unidades',
          ),
          const SizedBox(height: 16),
          if (i.alertasStock.isNotEmpty)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'Alertas de Stock Bajo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.red),
                    ...i.alertasStock.map(
                      (item) => ListTile(
                        title: Text(
                          item.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text('SKU: ${item.sku}'),
                        trailing: Text(
                          '${item.currentStock.toInt()} / min ${item.minStock.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ServicesPieChart(
            title: 'Inventario por Categoría',
            data: i.distribucionCategorias,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
