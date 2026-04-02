import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/branding/branding_service.dart';
import '../services/accounting_periods_service.dart';
import '../models/accounting_models.dart';

class GestionPeriodosPage extends StatefulWidget {
  const GestionPeriodosPage({super.key});

  @override
  State<GestionPeriodosPage> createState() => _GestionPeriodosPageState();
}

class _GestionPeriodosPageState extends State<GestionPeriodosPage> {
  final _service = AccountingPeriodsService();
  final _brandingService = BrandingService();
  final _dateFormat = DateFormat('dd-MMM');
  List<AccountingPeriodModel> _periods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    setState(() => _isLoading = true);
    try {
      final periods = await _service.getPeriods();
      setState(() {
        _periods = periods;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(AccountingPeriodModel period) async {
    final nextStatus = period.isOpen ? 'CERRADO' : 'ABIERTO';

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '${nextStatus == 'ABIERTO' ? 'Abrir' : 'Cerrar'} Periodo',
            ),
            content: Text(
              '¿Está seguro de cambiar el estado de ${period.mes}/${period.anio} a $nextStatus?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      nextStatus == 'ABIERTO'
                          ? Colors.green
                          : _brandingService.primaryColor,
                ),
                child: const Text('CONFIRMAR'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        final success = await _service.updatePeriodStatus(
          period.id,
          nextStatus,
        );
        if (success) {
          _loadPeriods();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showCreatePeriodDialog() async {
    final lastPeriod = _periods.isNotEmpty ? _periods.first : null;
    int nextYear = lastPeriod != null ? lastPeriod.anio : DateTime.now().year;
    int nextMonth =
        lastPeriod != null ? lastPeriod.mes + 1 : DateTime.now().month;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    DateTime startDate = DateTime(nextYear, nextMonth, 1);
    DateTime endDate = DateTime(nextYear, nextMonth + 1, 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Crear Nuevo Periodo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Mes/Año'),
                    subtitle: Text('$nextMonth / $nextYear'),
                    trailing: const Icon(Icons.calendar_today),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Fecha Inicio'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(startDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Fecha Fin'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => endDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandingService.primaryColor,
                  ),
                  child: const Text('CREAR'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await _service.createPeriod(
          anio: nextYear,
          mes: nextMonth,
          fechaInicio: DateFormat('yyyy-MM-dd').format(startDate),
          fechaFin: DateFormat('yyyy-MM-dd').format(endDate),
        );
        _loadPeriods();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Periodos',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: _brandingService.primaryColor,
        actions: [
          IconButton(onPressed: _loadPeriods, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _periods.isEmpty
              ? const Center(child: Text('No hay periodos configurados'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.amber.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Cerrar un periodo bloquea cualquier causación o movimiento contable en ese mes.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _periods.length,
                        itemBuilder: (context, index) {
                          final p = _periods[index];
                          final isOpen = p.isOpen;
                          final rangeTitle =
                              p.fechaInicio != null && p.fechaFin != null
                                  ? '${_dateFormat.format(p.fechaInicio!)} al ${_dateFormat.format(p.fechaFin!)}'
                                  : 'Sin fechas definidas';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              title: Text(
                                'Periodo ${p.mes}/${p.anio}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Rango: $rangeTitle | Estado: ${p.estado}',
                                style: TextStyle(
                                  color: isOpen ? Colors.green : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                              leading: Icon(
                                isOpen ? Icons.lock_open : Icons.lock,
                                color: isOpen ? Colors.green : Colors.red,
                              ),
                              trailing: Switch(
                                value: isOpen,
                                onChanged: (_) => _toggleStatus(p),
                                activeThumbColor: Colors.green,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (p.usuarioAperturaNombre != null)
                                        _buildAuditItem(
                                          Icons.how_to_reg,
                                          'Abierto por: ${p.usuarioAperturaNombre}',
                                          p.fechaApertura,
                                        ),
                                      if (p.usuarioCierreNombre != null)
                                        _buildAuditItem(
                                          Icons.lock_person,
                                          'Cerrado por: ${p.usuarioCierreNombre}',
                                          p.fechaCierre,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePeriodDialog,
        backgroundColor: _brandingService.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'NUEVO PERIODO',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAuditItem(IconData icon, String label, DateTime? date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ${date != null ? "(${DateFormat('dd/MM HH:mm').format(date)})" : ""}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorsExtension on Colors {
  static const Color amberSelection = Color(0xFFFFF8E1);
}
