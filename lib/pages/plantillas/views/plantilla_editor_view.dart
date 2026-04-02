import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plantilla_provider.dart';
import '../widgets/cliente_selector_widget.dart';
import '../widgets/html_editor_widget.dart';
import '../widgets/tags_panel_widget.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../widgets/vista_previa_widget.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';

class PlantillaEditorView extends StatefulWidget {
  const PlantillaEditorView({super.key});

  @override
  State<PlantillaEditorView> createState() => _PlantillaEditorViewState();
}

class _PlantillaEditorViewState extends State<PlantillaEditorView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final GlobalKey<HtmlEditorWidgetState> _editorKey = GlobalKey<HtmlEditorWidgetState>();
  bool _esGeneral = false;
  String _selectedModulo = 'servicios';
  int? _selectedClienteId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final provider = context.read<PlantillaProvider>();

    // Cargar tags si no están cargados
    if (provider.tagCategories.isEmpty) {
      provider.loadTags();
    }

    // Cargar clientes si no están cargados
    if (provider.clientes.isEmpty) {
      provider.loadClientes();
    }

    // Si es edición, llenar los campos
    final plantilla = provider.currentPlantilla;
    if (plantilla != null) {
      _nombreController.text = plantilla.nombre;
      setState(() {
        _esGeneral = plantilla.esGeneral;
        _selectedModulo = plantilla.modulo;
        _selectedClienteId = plantilla.clienteId;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _savePlantilla() async {
    // Verificar permisos antes de cualquier validación
    final providerPerm = context.read<PlantillaProvider>();
    final isNew = providerPerm.currentPlantilla?.isNew == true;
    final hasPermission =
        isNew
            ? PermissionStore.instance.can('plantillas', 'crear')
            : PermissionStore.instance.can('plantillas', 'actualizar');
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNew
                ? 'Sin permisos para crear plantillas'
                : 'Sin permisos para editar plantillas',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Validación defensiva del formulario
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      _tabController.animateTo(0); // Ir a tab General
      return;
    }

    final provider = context.read<PlantillaProvider>();
    final plantilla = provider.currentPlantilla;

    if (plantilla == null) return;

    // Actualizar campos
    provider.updateCurrentPlantillaField(
      nombre: _nombreController.text.trim(),
      modulo: _selectedModulo,
      clienteId: _esGeneral ? null : _selectedClienteId,
      esGeneral: _esGeneral,
    );

    // Releer la plantilla actual actualizada
    final plantillaActualizada = provider.currentPlantilla;

    // Validar que tenga contenido HTML
    if (plantillaActualizada == null ||
        plantillaActualizada.contenidoHtml.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar contenido HTML en el editor'),
          backgroundColor: Colors.orange,
        ),
      );
      _tabController.animateTo(1); // Ir a tab Editor
      return;
    }

    // Validación: evitar duplicar plantilla específica por cliente
    /*
    if (!_esGeneral && _selectedClienteId != null) {
      final cliente = provider.getClienteById(_selectedClienteId!);
      final existentes = cliente?.plantillas?.map((p) => p.id).toList() ?? [];
      final yaTiene = existentes.isNotEmpty;
      final esLaMisma = plantillaActualizada.id != null && existentes.contains(plantillaActualizada.id);
      if (yaTiene && (isNew || !esLaMisma)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El cliente seleccionado ya tiene una plantilla específica. Edite la existente o elimínela antes de crear otra.'),
            backgroundColor: Colors.orange,
          ),
        );
        _tabController.animateTo(0); // Ir a tab General
        return;
      }
    }
    */

    // Guardar
    final success =
        plantillaActualizada.isNew
            ? await provider.createPlantilla(plantillaActualizada)
            : await provider.updatePlantilla(plantillaActualizada);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plantilla guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.plantillasError ?? 'Error al guardar plantilla',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<PlantillaProvider>(
          builder: (context, provider, child) {
            final plantilla = provider.currentPlantilla;
            return Text(
              plantilla?.isNew == true ? 'Nueva Plantilla' : 'Editar Plantilla',
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'General', icon: Icon(Icons.info_outline)),
            Tab(text: 'Editor', icon: Icon(Icons.edit)),
            Tab(text: 'Vista Previa', icon: Icon(Icons.preview)),
          ],
        ),
        actions: [
          Consumer<PlantillaProvider>(
            builder: (context, provider, child) {
              final isNew = provider.currentPlantilla?.isNew == true;
              final canSave =
                  isNew
                      ? PermissionStore.instance.can('plantillas', 'crear')
                      : PermissionStore.instance.can(
                        'plantillas',
                        'actualizar',
                      );
              return provider.isLoadingPlantillas
                  ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                  : PointerInterceptor(
                    child: IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: canSave ? _savePlantilla : null,
                      tooltip:
                          canSave ? 'Guardar' : 'Sin permisos para guardar',
                    ),
                  );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGeneralTab(), _buildEditorTab(), _buildPreviewTab()],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración de la Plantilla',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Nombre de la plantilla
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la plantilla',
                hintText: 'Ej: Plantilla General Servicios',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Tipo de plantilla
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de Plantilla',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Plantilla General'),
                      subtitle: const Text(
                        'Se usará para todos los clientes que no tengan plantilla específica',
                      ),
                      value: _esGeneral,
                      onChanged: (value) {
                        setState(() {
                          _esGeneral = value;
                          if (value) {
                            _selectedClienteId = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selector de cliente (solo si no es general)
            if (!_esGeneral) ...[
              Text(
                'Cliente Asociado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final provider = context.read<PlantillaProvider>();
                  final plantilla = provider.currentPlantilla;
                  // Usar nombre del cliente de la plantilla como fallback solo si el ID coincide
                  final fallbackName =
                      (_selectedClienteId == plantilla?.clienteId)
                          ? plantilla?.clienteNombre
                          : null;

                  return ClienteSelectorWidget(
                    selectedClienteId: _selectedClienteId,
                    fallbackName: fallbackName,
                    onClienteSelected: (clienteId) {
                      setState(() {
                        _selectedClienteId = clienteId;
                      });
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorTab() {
    return Row(
      children: [
        // Panel de tags (lateral izquierdo)
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: TagsPanelWidget(
            modulo: _selectedModulo,
            onTagSelected: (tag) {
              _editorKey.currentState?.insertTag(tag);
            },
          ),
        ),

        // Editor HTML
        Expanded(
          child: HtmlEditorWidget(key: _editorKey),
        ),
      ],
    );
  }

  Widget _buildPreviewTab() {
    return const VistaPreviaWidget();
  }
}
