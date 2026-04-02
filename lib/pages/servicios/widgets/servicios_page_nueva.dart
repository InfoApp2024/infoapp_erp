import 'package:flutter/material.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/pages/servicios/widgets/servicios_tabla.dart';
import 'package:infoapp/pages/servicios/widgets/servicios_filtros.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/pages/servicios/controllers/servicios_controller.dart';

/// Vista principal de servicios - Version modular y escalable
class ServiciosPageNueva extends StatefulWidget {
  const ServiciosPageNueva({super.key});

  @override
  State<ServiciosPageNueva> createState() => _ServiciosPageNuevaState();
}

class _ServiciosPageNuevaState extends State<ServiciosPageNueva> {
  @override
  void initState() {
    super.initState();
    // Cargar servicios al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ServiciosController>(context, listen: false).cargarServicios();
      }
    });
  }

  Future<void> _refrescarServicios() async {
    await Provider.of<ServiciosController>(context, listen: false).cargarServicios();
  }

  /// Filtrar servicios por texto de busqueda
  void _filtrarServicios(String filtro) {
    Provider.of<ServiciosController>(context, listen: false).buscarServicios(filtro);
  }

  /// Mostrar formulario de nuevo servicio
  void _mostrarFormularioNuevoServicio() {
    _mostrarInfo('Formulario de nuevo servicio proximamente');
  }

  /// Mostrar detalle de servicio
  void _mostrarDetalleServicio(ServicioModel servicio) {
    _mostrarDetalleBasico(servicio);
  }

  /// Mostrar mensaje de error
  void _mostrarError(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.warningCircle(), color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(NetErrorMessages.from(mensaje, contexto: 'cargar servicios'))),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Reintentar',
          textColor: Colors.white,
          onPressed: () => Provider.of<ServiciosController>(context, listen: false).cargarServicios(),
        ),
      ),
    );
  }

  /// Mostrar mensaje de exito
  void _mostrarMensajeExito(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.checkCircle(), color: Colors.white),
            const SizedBox(width: 8),
            Text(mensaje),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Mostrar mensaje informativo
  void _mostrarInfo(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(PhosphorIcons.info(), color: Colors.white),
            const SizedBox(width: 8),
            Text(mensaje),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Mostrar detalle basico temporal
  void _mostrarDetalleBasico(ServicioModel servicio) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Servicio ${servicio.numeroServicioFormateado}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Orden Cliente:', servicio.ordenCliente ?? 'N/A'),
                _buildInfoRow('Tipo:', servicio.tipoMantenimiento ?? 'N/A'),
                _buildInfoRow('Equipo:', servicio.equipoNombre ?? 'N/A'),
                _buildInfoRow('Empresa:', servicio.nombreEmp ?? 'N/A'),
                _buildInfoRow('Placa:', servicio.placa ?? 'N/A'),
                _buildInfoRow('Estado:', servicio.estadoNombre ?? 'N/A'),
                _buildInfoRow('Fecha:', _formatearFecha(servicio.fechaIngreso)),
              ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return 'N/A';
    try {
      final fechaObj = DateTime.parse(fecha);
      return '${fechaObj.day}/${fechaObj.month}/${fechaObj.year}';
    } catch (e) {
      return fecha.length > 10 ? fecha.substring(0, 10) : fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildCuerpo(),
      floatingActionButton: _buildBotonNuevoServicio(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Icon(PhosphorIcons.wrench(), color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Servicios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Consumer<ServiciosController>(
          builder: (context, controller, child) {
            return IconButton(
              icon: controller.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(PhosphorIcons.arrowsClockwise()),
              onPressed: controller.isLoading ? null : _refrescarServicios,
              tooltip: 'Actualizar servicios',
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCuerpo() {
    return Consumer<ServiciosController>(
      builder: (context, controller, child) {
        if (controller.error != null && controller.servicios.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.warning(), size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${controller.error}'),
                ElevatedButton(
                  onPressed: () => controller.cargarServicios(),
                  child: const Text('Reintentar'),
                )
              ],
            ),
          );
        }

        return Container(
          color: Colors.grey.shade50,
          child: Column(
            children: [
              ServiciosFiltros(
                onFiltroChanged: _filtrarServicios,
                totalServicios: controller.totalRegistros,
                serviciosFiltrados: controller.servicios.length,
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                      controller.cargarSigPagina();
                    }
                    return false;
                  },
                  child: _buildContenidoPrincipal(controller),
                ),
              ),
              if (controller.isLoading && controller.servicios.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContenidoPrincipal(ServiciosController controller) {
    if (controller.isLoading && controller.servicios.isEmpty) {
      return _buildEstadoCargando();
    }

    if (controller.servicios.isEmpty) {
      if (controller.isSearchActive) {
        return _buildEstadoSinResultados(controller);
      }
      return _buildEstadoVacio();
    }
    
    return ServiciosTabla(
      servicios: controller.servicios,
      onServicioTap: _mostrarDetalleServicio,
    );
  }

  Widget _buildEstadoCargando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Cargando servicios...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.archive(), size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay servicios registrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el boton + para crear el primer servicio',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(PhosphorIcons.plus()),
            label: const Text('Crear Primer Servicio'),
            onPressed: _mostrarFormularioNuevoServicio,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoSinResultados(ServiciosController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.magnifyingGlass(), size: 80, color: Colors.orange.shade400),
          const SizedBox(height: 16),
          Text(
            'No se encontraron servicios',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay servicios que coincidan con la busqueda',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: Icon(PhosphorIcons.x()),
                label: const Text('Limpiar Filtro'),
                onPressed: () => _filtrarServicios(''),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: Icon(PhosphorIcons.plus()),
                label: const Text('Nuevo Servicio'),
                onPressed: _mostrarFormularioNuevoServicio,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonNuevoServicio() {
    return FloatingActionButton.extended(
      onPressed: _mostrarFormularioNuevoServicio,
      icon: Icon(PhosphorIcons.plus()),
      label: const Text('Nuevo Servicio'),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      tooltip: 'Crear nuevo servicio',
    );
  }
}
