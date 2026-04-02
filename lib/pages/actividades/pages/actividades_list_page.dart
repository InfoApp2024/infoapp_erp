import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../servicios/models/actividad_estandar_model.dart';
import '../../servicios/services/actividades_service.dart';
import '../../servicios/widgets/actividad_crud_modal.dart';
import '../../servicios/widgets/actividad_import_modal.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'sistemas_list_page.dart';

class ActividadesListPage extends StatefulWidget {
  const ActividadesListPage({super.key});

  @override
  State<ActividadesListPage> createState() => _ActividadesListPageState();
}

class _ActividadesListPageState extends State<ActividadesListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      context.read<ActividadesService>().cargarActividades(forceRefresh: true);
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actividadesService = context.watch<ActividadesService>();
    final store = PermissionStore.instance;

    final canCrear = store.can('servicios_actividades', 'crear');
    final canActualizar = store.can('servicios_actividades', 'actualizar');
    final canEliminar = store.can('servicios_actividades', 'eliminar');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header y Acciones
          _buildHeader(context, canCrear),

          // Barra de búsqueda
          _buildSearchBar(context, actividadesService),

          // Tabla de Contenido
          Expanded(
            child: _buildBody(
              context,
              actividadesService,
              canActualizar,
              canEliminar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canCrear) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(
                      PhosphorIcons.listChecks(),
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gestión de Actividades',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Administra las actividades estándar disponibles para los servicios',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isSmallScreen && canCrear) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _getActions(context),
                  ),
                ),
              ] else if (canCrear) ...[
                const SizedBox(width: 16),
                Row(
                  children: _getActions(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _getActions(BuildContext context) {
    return [
      ElevatedButton.icon(
        onPressed: () => _mostrarModalCrud(context),
        icon: Icon(PhosphorIcons.plus(), size: 18),
        label: const Text('Nueva Actividad'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () => _mostrarModalImportacion(context),
        icon: Icon(PhosphorIcons.fileArrowUp(), size: 18),
        label: const Text('Importar'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () => _mostrarSistemasGestion(context),
        icon: Icon(PhosphorIcons.gear(), size: 18),
        label: const Text('Sistemas'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    ];
  }

  void _mostrarSistemasGestion(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SistemasListPage(),
    );
  }

  Widget _buildSearchBar(BuildContext context, ActividadesService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => service.buscarActividades(value),
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          prefixIcon: Icon(
                            PhosphorIcons.magnifyingGlass(),
                            size: 20,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => service.cargarActividades(forceRefresh: true),
                    icon: Icon(
                      PhosphorIcons.arrowsClockwise(),
                      color: Colors.grey[600],
                    ),
                    tooltip: 'Refrescar',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Todas',
                      isSelected: service.filtroActivo == null,
                      onTap: () => service.filtrarPorEstado(null),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Activas',
                      isSelected: service.filtroActivo == true,
                      onTap: () => service.filtrarPorEstado(true),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Inactivas',
                      isSelected: service.filtroActivo == false,
                      onTap: () => service.filtrarPorEstado(false),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ActividadesService service,
    bool canUpdate,
    bool canDelete,
  ) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.warningCircle(),
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error: ${service.error}',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => service.cargarActividades(forceRefresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final actividades = service.actividades;

    if (actividades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.selectionBackground(),
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No hay actividades creadas'
                  : 'No se encontraron actividades para "${_searchController.text}"',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              dataRowMaxHeight: 60,
              columns: const [
                DataColumn(
                  label: Text(
                    'Actividad',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Sistema',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Horas Est.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Técnicos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Estado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Acciones',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows:
                  actividades.map((actividad) {
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.35,
                            child: Text(
                              actividad.actividad.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            actividad.sistemaNombre ?? 'N/A',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DataCell(Text('${actividad.cantHora} h')),
                        DataCell(Text('${actividad.numTecnicos}')),
                        DataCell(_buildStatusChip(actividad.activo)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canUpdate)
                                IconButton(
                                  icon: Icon(
                                    PhosphorIcons.pencilSimple(),
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  onPressed:
                                      () => _mostrarModalCrud(
                                        context,
                                        actividad: actividad,
                                      ),
                                  tooltip: 'Editar',
                                ),
                              if (canDelete)
                                IconButton(
                                  icon: Icon(
                                    PhosphorIcons.trash(),
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () =>
                                          _confirmarEliminar(context, actividad),
                                  tooltip: 'Eliminar',
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (activo ? Colors.green : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (activo ? Colors.green : Colors.grey).withOpacity(0.3),
        ),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: activo ? Colors.green[700] : Colors.grey[700],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _mostrarModalCrud(
    BuildContext context, {
    ActividadEstandarModel? actividad,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => ActividadCrudModal(
            actividad: actividad,
            onGuardar: (_) {
              // El provider ya actualiza la lista local en crearActividad/actualizarActividad
            },
          ),
    );
  }

  void _mostrarModalImportacion(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const ActividadImportModal(),
    );
  }

  void _confirmarEliminar(
    BuildContext context,
    ActividadEstandarModel actividad,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Actividad'),
            content: Text(
              '¿Estás seguro de que deseas eliminar la actividad "${actividad.actividad}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await context.read<ActividadesService>().eliminarActividad(
                      actividad.id!,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Actividad eliminada correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al eliminar: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}
