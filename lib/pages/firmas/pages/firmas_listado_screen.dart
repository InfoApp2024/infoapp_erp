import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/firmas_controller.dart';
import '../models/firma_model.dart';
import 'firma_captura_screen.dart';

class FirmasListadoScreen extends StatefulWidget {
  const FirmasListadoScreen({super.key});

  @override
  State<FirmasListadoScreen> createState() => _FirmasListadoScreenState();
}

class _FirmasListadoScreenState extends State<FirmasListadoScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Filtros
  int? _filtroServicio;
  DateTime? _filtroFechaDesde;
  DateTime? _filtroFechaHasta;

  @override
  void initState() {
    super.initState();
    // Cargar firmas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FirmasController>().listarFirmas();
    });
  }

  Future<void> _aplicarFiltros() async {
    final controller = context.read<FirmasController>();

    await controller.listarFirmas(
      idServicio: _filtroServicio,
      fechaDesde: _filtroFechaDesde?.toIso8601String().split('T')[0],
      fechaHasta: _filtroFechaHasta?.toIso8601String().split('T')[0],
      page: 0,
    );
  }

  Future<void> _limpiarFiltros() async {
    setState(() {
      _filtroServicio = null;
      _filtroFechaDesde = null;
      _filtroFechaHasta = null;
    });

    await context.read<FirmasController>().listarFirmas();
  }

  Future<void> _mostrarFiltros() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Filtro por servicio
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'ID de Servicio',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _filtroServicio = int.tryParse(value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Fecha desde
                  ListTile(
                    title: Text(
                      _filtroFechaDesde == null
                          ? 'Fecha desde'
                          : 'Desde: ${_dateFormat.format(_filtroFechaDesde!)}',
                    ),
                    leading: Icon(PhosphorIcons.calendarBlank()),
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: _filtroFechaDesde ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (fecha != null) {
                        setState(() {
                          _filtroFechaDesde = fecha;
                        });
                      }
                    },
                  ),

                  // Fecha hasta
                  ListTile(
                    title: Text(
                      _filtroFechaHasta == null
                          ? 'Fecha hasta'
                          : 'Hasta: ${_dateFormat.format(_filtroFechaHasta!)}',
                    ),
                    leading: Icon(PhosphorIcons.calendarBlank()),
                    onTap: () async {
                      final fecha = await showDatePicker(
                        context: context,
                        initialDate: _filtroFechaHasta ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (fecha != null) {
                        setState(() {
                          _filtroFechaHasta = fecha;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _limpiarFiltros();
                            Navigator.pop(context);
                          },
                          child: const Text('Limpiar'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _aplicarFiltros();
                            Navigator.pop(context);
                          },
                          child: const Text('Aplicar'),
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

  Future<void> _confirmarEliminar(FirmaModel firma) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text(
              '¿Está seguro de eliminar la firma del servicio ${firma.numeroServicioFormateado}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar == true && mounted) {
      final controller = context.read<FirmasController>();
      final success = await controller.eliminarFirma(firma.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Firma eliminada exitosamente'
                  : controller.errorMessage ?? 'Error al eliminar',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verDetalle(FirmaModel firma) async {
    // Aquí puedes navegar a una pantalla de detalle si la creas
    // O mostrar un diálogo con la información completa
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Firma ${firma.numeroServicioFormateado}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Servicio', firma.numeroServicioFormateado),
                  _buildDetailRow('Placa', firma.placa ?? 'N/A'),
                  _buildDetailRow('Empresa', firma.nombreEmpresa ?? 'N/A'),
                  const Divider(),
                  _buildDetailRow('Quien entrega', firma.staffNombre ?? 'N/A'),
                  _buildDetailRow(
                    'Quien recibe',
                    firma.funcionarioNombre ?? 'N/A',
                  ),
                  const Divider(),
                  if (firma.notaEntrega != null) ...[
                    const Text(
                      'Nota de entrega:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(firma.notaEntrega!),
                    const SizedBox(height: 8),
                  ],
                  if (firma.notaRecepcion != null) ...[
                    const Text(
                      'Nota de recepción:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(firma.notaRecepcion!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmas de Entrega'),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.funnel()),
            onPressed: _mostrarFiltros,
          ),
          IconButton(
            icon: Icon(PhosphorIcons.arrowsClockwise()),
            onPressed: () {
              context.read<FirmasController>().listarFirmas();
            },
          ),
        ],
      ),
      body: Consumer<FirmasController>(
        builder: (context, controller, child) {
          if (controller.isLoading && controller.firmas.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage != null && controller.firmas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.warningCircle(),
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(controller.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.listarFirmas(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (controller.firmas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.tray(), size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay firmas registradas',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Lista de firmas
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => controller.listarFirmas(),
                  child: ListView.builder(
                    itemCount: controller.firmas.length,
                    itemBuilder: (context, index) {
                      final firma = controller.firmas[index];
                      return _buildFirmaCard(firma);
                    },
                  ),
                ),
              ),

              // Paginación
              if (controller.totalPages > 1) _buildPaginacion(controller),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FirmaCapturaScreen()),
          );

          if (result == true && mounted) {
            context.read<FirmasController>().listarFirmas();
          }
        },
        icon: Icon(PhosphorIcons.pencil(), color: Colors.white),
        label: const Text('Nueva Firma'),
      ),
    );
  }

  Widget _buildFirmaCard(FirmaModel firma) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            firma.numeroServicioFormateado,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
        title: Text(
          '${firma.placa ?? "N/A"} - ${firma.nombreEmpresa ?? "N/A"}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Entregó: ${firma.staffNombre ?? "N/A"}'),
            Text('Recibió: ${firma.funcionarioNombre ?? "N/A"}'),
            if (firma.createdAt != null)
              Text(
                'Fecha: ${_dateFormat.format(firma.createdAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'ver',
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.eye()),
                      SizedBox(width: 8),
                      Text('Ver detalle'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.trash(), color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
          onSelected: (value) {
            if (value == 'ver') {
              _verDetalle(firma);
            } else if (value == 'eliminar') {
              _confirmarEliminar(firma);
            }
          },
        ),
        onTap: () => _verDetalle(firma),
      ),
    );
  }

  Widget _buildPaginacion(FirmasController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.caretLeft()),
            onPressed:
                controller.currentPage > 0 ? controller.paginaAnterior : null,
          ),
          Text(
            'Página ${controller.currentPage + 1} de ${controller.totalPages}',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.caretRight()),
            onPressed:
                controller.currentPage < controller.totalPages - 1
                    ? controller.siguientePagina
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
