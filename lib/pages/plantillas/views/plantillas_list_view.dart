import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../providers/plantilla_provider.dart';
import '../models/plantilla_model.dart';
import '../widgets/plantilla_card_widget.dart';
import 'plantilla_editor_view.dart';

class PlantillasListView extends StatefulWidget {
  const PlantillasListView({super.key});

  @override
  State<PlantillasListView> createState() => _PlantillasListViewState();
}

class _PlantillasListViewState extends State<PlantillasListView> {
  String _filterType = 'todas'; // 'todas', 'generales', 'especificas'
  bool _mostroBannerSinPermiso = false;

  bool _can(String action) =>
      PermissionStore.instance.can('plantillas', action);
  bool _canList() => _can('listar');
  void _showNoPermissionBanner(String message) {
    if (!_mostroBannerSinPermiso && mounted) {
      _mostroBannerSinPermiso = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
//     print('🔵 [PlantillasListView] initState llamado');
    
    // IMPORTANTE: Usar addPostFrameCallback para evitar problemas
    WidgetsBinding.instance.addPostFrameCallback((_) {
//       print('🔵 [PlantillasListView] postFrameCallback ejecutado');
      if (_canList()) {
        _loadPlantillas();
      } else {
        _showNoPermissionBanner('Sin permisos para listar plantillas');
      }
    });
  }

  Future<void> _loadPlantillas() async {
//     print('🔵 [PlantillasListView] _loadPlantillas iniciado');
//     print('🔵 [PlantillasListView] filterType: $_filterType');
    
    if (!mounted) {
//       print('⚠️ [PlantillasListView] Widget no montado, abortando carga');
      return;
    }
    
    final provider = context.read<PlantillaProvider>();

    if (!_canList()) {
      _showNoPermissionBanner('Sin permisos para listar/ver plantillas');
      return;
    }
    
    int? esGeneral;
    if (_filterType == 'generales') {
      esGeneral = 1;
    } else if (_filterType == 'especificas') {
      esGeneral = 0;
    }

//     print('🔵 [PlantillasListView] Llamando provider.loadPlantillas con esGeneral=$esGeneral');
    
    try {
      await provider.loadPlantillas(esGeneral: esGeneral);
//       print('✅ [PlantillasListView] loadPlantillas completado');
    } catch (e) {
//       print('❌ [PlantillasListView] Error en loadPlantillas: $e');
    }
  }

  void _createNewPlantilla() {
//     print('🔵 [PlantillasListView] Creando nueva plantilla');
    if (!PermissionStore.instance.can('plantillas', 'crear')) {
      _showNoPermissionBanner('Sin permisos para crear plantillas');
      return;
    }
    final provider = context.read<PlantillaProvider>();
    provider.createNewPlantilla();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlantillaEditorView(),
      ),
    );
  }

  void _editPlantilla(Plantilla plantilla) {
//     print('🔵 [PlantillasListView] Editando plantilla: ${plantilla.nombre}');
    if (!(PermissionStore.instance.can('plantillas', 'ver') ||
        PermissionStore.instance.can('plantillas', 'editar'))) {
      _showNoPermissionBanner('Sin permisos para ver/editar plantillas');
      return;
    }
    final provider = context.read<PlantillaProvider>();
    provider.setCurrentPlantilla(plantilla);

    Future<void> go() async {
      // Si venimos del listado sin contenidoHtml, cargar el detalle
      if (plantilla.id != null && plantilla.contenidoHtml.isEmpty) {
//         print('🔵 [PlantillasListView] Cargando detalle de plantilla ID: ${plantilla.id}');
        await provider.loadPlantilla(plantilla.id!);
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlantillaEditorView(),
        ),
      );
    }

    go();
  }

  Future<void> _deletePlantilla(Plantilla plantilla) async {
//     print('🔵 [PlantillasListView] Solicitando confirmación para eliminar: ${plantilla.nombre}');
    if (!PermissionStore.instance.can('plantillas', 'eliminar')) {
      _showNoPermissionBanner('Sin permisos para eliminar plantillas');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text('¿Está seguro de eliminar "${plantilla.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && plantilla.id != null) {
//       print('🔵 [PlantillasListView] Eliminando plantilla ID: ${plantilla.id}');
      
      final provider = context.read<PlantillaProvider>();
      final success = await provider.deletePlantilla(plantilla.id!);

//       print(success ? '✅ [PlantillasListView] Plantilla eliminada' : '❌ [PlantillasListView] Error eliminando plantilla');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Plantilla eliminada exitosamente'
                  : 'Error al eliminar plantilla',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } else {
//       print('⚠️ [PlantillasListView] Eliminación cancelada o plantilla sin ID');
    }
  }

  @override
  Widget build(BuildContext context) {
//     print('🔵 [PlantillasListView] build() llamado');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas de Informes'),
        actions: [
          if (_can('crear'))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nueva Plantilla',
              onPressed: _createNewPlantilla,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
//               print('🔵 [PlantillasListView] Filtro cambiado a: $value');
              setState(() {
                _filterType = value;
              });
              if (_canList()) {
                _loadPlantillas();
              } else {
                _showNoPermissionBanner('Sin permisos para listar plantillas');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'todas',
                child: Text('Todas las plantillas'),
              ),
              const PopupMenuItem(
                value: 'generales',
                child: Text('Solo generales'),
              ),
              const PopupMenuItem(
                value: 'especificas',
                child: Text('Solo específicas'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<PlantillaProvider>(
        builder: (context, provider, child) {
//           print('🔵 [PlantillasListView] Consumer rebuilding...');
//           print('🔵 [PlantillasListView] isLoadingPlantillas: ${provider.isLoadingPlantillas}');
//           print('🔵 [PlantillasListView] plantillas.length: ${provider.plantillas.length}');
//           print('🔵 [PlantillasListView] error: ${provider.plantillasError}');

          // Bloqueo por permisos de listado
          if (!_canList()) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin permisos para listar plantillas',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Mostrar loading
          if (provider.isLoadingPlantillas) {
//             print('🔵 [PlantillasListView] Mostrando loading...');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando plantillas...'),
                ],
              ),
            );
          }

          // Mostrar error
          if (provider.plantillasError != null) {
//             print('❌ [PlantillasListView] Mostrando pantalla de error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar plantillas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      provider.plantillasError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadPlantillas,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          // Mostrar lista vacía
          if (provider.plantillas.isEmpty) {
//             print('🔵 [PlantillasListView] Mostrando pantalla de lista vacía');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay plantillas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu primera plantilla',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: PermissionStore.instance.can('plantillas', 'crear')
                        ? _createNewPlantilla
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Plantilla'),
                  ),
                ],
              ),
            );
          }

          // Mostrar lista
//           print('🔵 [PlantillasListView] Mostrando lista con ${provider.plantillas.length} items');
          return RefreshIndicator(
            onRefresh: () async {
              if (_canList()) {
                await _loadPlantillas();
              } else {
                _showNoPermissionBanner('Sin permisos para listar/ver plantillas');
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.plantillas.length,
              itemBuilder: (context, index) {
                final plantilla = provider.plantillas[index];
//                 print('🔵 [PlantillasListView] Renderizando item $index: ${plantilla.nombre}');
                
                return PlantillaCardWidget(
                  plantilla: plantilla,
                  onTap: () => _editPlantilla(plantilla),
                  onDelete: () => _deletePlantilla(plantilla),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
//     print('🔵 [PlantillasListView] dispose() llamado');
    super.dispose();
  }
}
