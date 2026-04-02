/// ============================================================================
/// ARCHIVO: inspecciones_page.dart
///
/// PROPÓSITO: Página principal del módulo de inspecciones
/// - Muestra la lista de inspecciones
/// - Gestiona filtros y búsquedas
/// - Maneja navegación a crear/editar/ver detalles
/// - Integra WebSocket para actualizaciones en tiempo real
/// ============================================================================
library;


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../providers/inspecciones_provider.dart';
import '../providers/sistemas_provider.dart';
import '../models/inspeccion_model.dart';
import '../widgets/inspeccion_form.dart';
import 'inspeccion_detalle_page.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';

class InspeccionesPage extends StatefulWidget {
  const InspeccionesPage({super.key});

  @override
  State<InspeccionesPage> createState() => _InspeccionesPageState();
}

class _InspeccionesPageState extends State<InspeccionesPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspeccionesProvider>().cargarInspecciones();
      context.read<SistemasProvider>().cargarSistemas(soloActivos: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    final bool canView = PermissionStore.instance.can('inspecciones', 'ver');
    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inspecciones'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder al módulo de inspecciones',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Permisos específicos
    final bool canCreate = PermissionStore.instance.can('inspecciones', 'crear');
    final bool canList = PermissionStore.instance.can('inspecciones', 'listar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspecciones'),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.plus()),
            onPressed: canCreate ? _crearNuevaInspeccion : null,
            tooltip: 'Nueva Inspección',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.funnel()),
            onPressed: canList ? _mostrarFiltros : null,
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.arrowsClockwise()),
            onPressed: canList ? () {
              context.read<InspeccionesProvider>().cargarInspecciones();
            } : null,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar inspecciones...',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(PhosphorIcons.x()),
                        onPressed: () {
                          _searchController.clear();
                          context.read<InspeccionesProvider>().limpiarFiltros();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                context.read<InspeccionesProvider>().aplicarFiltros(
                      buscar: value.isEmpty ? null : value,
                    );
              },
            ),
          ),

          // Lista de inspecciones
          Expanded(
            child: !canList
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No tienes permiso para listar inspecciones',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Consumer<InspeccionesProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.error != null) {
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
                        Text(
                          'Error: ${provider.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.limpiarError();
                            provider.cargarInspecciones();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.inspecciones.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIcons.clipboardText(),
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay inspecciones',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea tu primera inspección',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final inspeccionesOrdenadas = List<InspeccionModel>.from(provider.inspecciones);
                inspeccionesOrdenadas.sort((a, b) {
                  final dateA = a.id ?? 0; // Usar ID como fallback si createdAt no está disponible
                  final dateB = b.id ?? 0;
                  // Si tenemos createdAt, priorizarlo
                  final cDateA = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
                  final cDateB = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
                  
                  if (cDateA != null && cDateB != null) {
                    return cDateB.compareTo(cDateA);
                  }
                  return dateB.compareTo(dateA);
                });

                return ListView.builder(
                  itemCount: inspeccionesOrdenadas.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final inspeccion = inspeccionesOrdenadas[index];
                    return _buildInspeccionCard(inspeccion);
                  },
                );
              },
            ),
          ),

          // Paginación
          Consumer<InspeccionesProvider>(
            builder: (context, provider, child) {
              if (provider.totalPaginas <= 1) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Página ${provider.paginaActual} de ${provider.totalPaginas}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(PhosphorIcons.caretLeft()),
                          onPressed: provider.tieneAnterior
                              ? () => provider.paginaAnterior()
                              : null,
                        ),
                        IconButton(
                          icon: Icon(PhosphorIcons.caretRight()),
                          onPressed: provider.tieneSiguiente
                              ? () => provider.paginaSiguiente()
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInspeccionCard(InspeccionModel inspeccion) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 600;
          
          if (isMobile) {
            return InkWell(
              onTap: () => _verDetalleInspeccion(inspeccion),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: inspeccion.estadoColor != null
                              ? Color(int.parse('0xFF${inspeccion.estadoColor!.replaceAll('#', '')}'))
                              : Colors.blue,
                          child: Icon(PhosphorIcons.clipboardText(), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            inspeccion.numeroInspeccionFormateado,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(PhosphorIcons.caretRight(), size: 20, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Equipo: ${inspeccion.equipoNombre ?? 'N/A'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sitio: ${inspeccion.sitio ?? 'N/A'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (inspeccion.estadoNombre != null)
                          _buildEstadoPill(inspeccion),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (inspeccion.actividadesPendientes > 0)
                          _buildMiniStatusChip(
                            '${inspeccion.actividadesPendientes} ${inspeccion.actividadesPendientes == 1 ? 'Pendiente' : 'Pendientes'}',
                            Colors.blue[100]!,
                          ),
                        if ((inspeccion.actividadesAutorizadas ?? 0) > 0)
                          _buildMiniStatusChip(
                            '${inspeccion.actividadesAutorizadas} ${inspeccion.actividadesAutorizadas == 1 ? 'Aprobada' : 'Aprobadas'}',
                            Colors.green[100]!,
                          ),
                        if ((inspeccion.actividadesEliminadas ?? 0) > 0)
                          _buildMiniStatusChip(
                            '${inspeccion.actividadesEliminadas} ${inspeccion.actividadesEliminadas == 1 ? 'Eliminada' : 'Eliminadas'}',
                            Colors.red[100]!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          // Versión Desktop/Tablet (Original adaptada)
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: inspeccion.estadoColor != null
                  ? Color(int.parse('0xFF${inspeccion.estadoColor!.replaceAll('#', '')}'))
                  : Colors.blue,
              child: Icon(PhosphorIcons.clipboardText(), color: Colors.white),
            ),
            title: Text(
              inspeccion.numeroInspeccionFormateado,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Equipo: ${inspeccion.equipoNombre ?? 'N/A'}'),
                Text('Sitio: ${inspeccion.sitio ?? 'N/A'}'),
                if (inspeccion.estadoNombre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: _buildEstadoPill(inspeccion),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inspeccion.actividadesPendientes > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: _buildMiniStatusChip(
                      '${inspeccion.actividadesPendientes} P',
                      Colors.blue[100]!,
                    ),
                  ),
                if ((inspeccion.actividadesAutorizadas ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: _buildMiniStatusChip(
                      '${inspeccion.actividadesAutorizadas} A',
                      Colors.green[100]!,
                    ),
                  ),
                Icon(PhosphorIcons.caretRight(), size: 20),
              ],
            ),
            onTap: () => _verDetalleInspeccion(inspeccion),
          );
        },
      ),
    );
  }

  Widget _buildEstadoPill(InspeccionModel inspeccion) {
    final color = (inspeccion.estadoColor != null
        ? Color(int.parse('0xFF${inspeccion.estadoColor!.replaceAll('#', '')}'))
        : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        inspeccion.estadoNombre!.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniStatusChip(String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _mostrarFiltros() {
    showDialog(
      context: context,
      builder: (context) => const _FiltroEstadoDialog(),
    );
  }

  void _crearNuevaInspeccion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspeccionForm(
          onSaved: () {
            // Recargar la lista después de crear
            context.read<InspeccionesProvider>().cargarInspecciones();
          },
        ),
      ),
    );
  }

  void _verDetalleInspeccion(InspeccionModel inspeccion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspeccionDetallePage(
          inspeccionId: inspeccion.id!,
        ),
      ),
    ).then((_) {
      // Recargar lista al volver por si hubo cambios
      context.read<InspeccionesProvider>().cargarInspecciones(mantenerPagina: true);
    });
  }
}

class _FiltroEstadoDialog extends StatefulWidget {
  const _FiltroEstadoDialog();

  @override
  State<_FiltroEstadoDialog> createState() => _FiltroEstadoDialogState();
}

class _FiltroEstadoDialogState extends State<_FiltroEstadoDialog> {
  List<EstadoModel> _estados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstados();
  }

  Future<void> _cargarEstados() async {
    try {
      final estados = await ServiciosApiService.listarEstados(modulo: 'inspecciones');
      if (mounted) {
        setState(() {
          _estados = estados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspeccionesProvider>();
    final estadoActual = provider.estadoFiltro;

    return AlertDialog(
      title: const Text('Filtrar por Estado'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Todos los estados'),
                    leading: Radio<String?>(
                      value: null,
                      groupValue: estadoActual,
                      onChanged: (value) {
                        provider.aplicarFiltros(estado: null);
                        Navigator.pop(context);
                      },
                    ),
                    onTap: () {
                      provider.aplicarFiltros(estado: null);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ..._estados.map((estado) => ListTile(
                        title: Text(estado.nombre),
                        leading: Radio<String?>(
                          value: estado.nombre,
                          groupValue: estadoActual,
                          onChanged: (value) {
                            provider.aplicarFiltros(estado: value);
                            Navigator.pop(context);
                          },
                        ),
                        onTap: () {
                          provider.aplicarFiltros(estado: estado.nombre);
                          Navigator.pop(context);
                        },
                      )),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
