import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/actividades_import_service.dart';
import '../services/actividades_api_service.dart';
import '../services/actividades_service.dart';
import 'actividad_crud_modal.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:infoapp/core/utils/download_utils.dart' as dl;
import 'package:infoapp/pages/actividades/widgets/sistema_selector_campo.dart';
import '../../inspecciones/providers/sistemas_provider.dart';

class ActividadImportModal extends StatefulWidget {
  const ActividadImportModal({super.key});

  @override
  State<ActividadImportModal> createState() => _ActividadImportModalState();
}

class _ActividadImportModalState extends State<ActividadImportModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Tab> _tabs;
  final _textController = TextEditingController();

  bool _isLoading = false;
  bool _sobrescribir = false;
  String _resultadoImportacion = '';
  Map<String, dynamic>? _validacionResultado;

  // Para archivo seleccionado
  String? _nombreArchivo;
  List<Map<String, dynamic>>? _actividadesArchivo;
  
  // ✅ Sistema seleccionado para la importación
  int? _sistemaIdSeleccionado;

  @override
  void initState() {
    super.initState();
    _tabs = [
      Tab(icon: Icon(PhosphorIcons.fileArrowUp()), text: 'Archivo'),
      Tab(icon: Icon(PhosphorIcons.clipboardText()), text: 'Pegar texto'),
      Tab(icon: Icon(PhosphorIcons.downloadSimple()), text: 'Plantilla'),
      Tab(icon: Icon(PhosphorIcons.listBullets()), text: 'Existentes'),
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Cargar sistemas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SistemasProvider>().cargarSistemas(soloActivos: true);
    });
  }

  @override
  void didUpdateWidget(covariant ActividadImportModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Maneja hot reload cambiando la longitud del TabController
    if (_tabController.length != _tabs.length) {
      _tabController.dispose();
      _tabController = TabController(length: _tabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.cloudArrowUp(),
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Importar Actividades',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(PhosphorIcons.x()),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true, // ✅ EVITA DESBORDAMIENTO EN PANTALLAS PEQUEÑAS
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: _tabs,
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildArchivoTab(),
                  _buildPegarTextoTab(),
                  _buildPlantillaTab(),
                  _buildExistentesTab(),
                ],
              ),
            ),

            // Footer con opciones
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Opcié³n sobrescribir
                  CheckboxListTile(
                    title: const Text('Sobrescribir actividades inactivas'),
                    subtitle: const Text(
                      'Si ya existe pero está inactiva, se reactivará',
                      style: TextStyle(fontSize: 11), // Un poco más pequeño
                    ),
                    value: _sobrescribir,
                    onChanged:
                        _isLoading
                            ? null
                            : (bool? value) {
                              setState(() {
                                _sobrescribir = value ?? false;
                              });
                            },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 16),

                  // Resultado de importacié³n
                  if (_resultadoImportacion.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _resultadoImportacion.contains('Error')
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _resultadoImportacion.contains('Error')
                                  ? Colors.red.shade200
                                  : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        _resultadoImportacion,
                        style: TextStyle(
                          color:
                              _resultadoImportacion.contains('Error')
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  //   TAB: ACTIVIDADES EXISTENTES
  // ============================
  bool _existentesInicializado = false;

  Widget _buildExistentesTab() {
    // Inicializar cargando todas (activas e inactivas) una sola vez
    if (!_existentesInicializado) {
      _existentesInicializado = true;
      Future.microtask(() async {
        try {
          await context.read<ActividadesService>().cargarActividades(
            forceRefresh: true,
            activo: null,
          );
          context.read<ActividadesService>().filtrarPorEstado(null);
        } catch (e) {
          _mostrarError('Error cargando actividades: $e');
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controles de béºsqueda y filtro
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                    hintText: 'Buscar actividad...',
                  ),
                  onChanged:
                      (q) => context
                          .read<ActividadesService>()
                          .buscarActividades(q),
                ),
              ),
              const SizedBox(width: 12),
              Consumer<ActividadesService>(
                builder: (context, svc, _) {
                  final estado = svc.filtroActivo;
                  return Expanded(
                    flex: 0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Todas'),
                            selected: estado == null,
                            onSelected: (_) => svc.filtrarPorEstado(null),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Activas'),
                            selected: estado == true,
                            onSelected: (_) => svc.filtrarPorEstado(true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Inactivas'),
                            selected: estado == false,
                            onSelected: (_) => svc.filtrarPorEstado(false),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Consumer<ActividadesService>(
              builder: (context, svc, _) {
                if (svc.isLoading && svc.todasLasActividades.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (svc.error.isNotEmpty) {
                  return Center(child: Text('Error: ${svc.error}'));
                }

                final items = svc.actividades;
                if (items.isEmpty) {
                  return const Center(child: Text('No hay actividades'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Icon(
                        PhosphorIcons.checkCircle(),
                        color:
                            item.activo ? Colors.green : Colors.grey.shade500,
                      ),
                      title: Text(item.actividad.toUpperCase()),
                      subtitle: Text(
                        item.activo ? 'Activa' : 'Inactiva',
                        style: TextStyle(
                          color:
                              item.activo
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: item.activo ? 'Inactivar' : 'Activar',
                            icon: Icon(
                              item.activo
                                  ? PhosphorIcons.prohibit()
                                  : PhosphorIcons.checkCircle(),
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: () async {
                              try {
                                await context
                                    .read<ActividadesService>()
                                    .actualizarActividad(
                                      item.copyWith(activo: !item.activo),
                                    );
                              } catch (e) {
                                _mostrarError('Error actualizando: $e');
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            icon: Icon(PhosphorIcons.pencilSimple()),
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (
                                      dialogContext,
                                    ) => ChangeNotifierProvider.value(
                                      value: context.read<ActividadesService>(),
                                      child: ActividadCrudModal(
                                        actividad: item,
                                        onGuardar: (_) {
                                          // Solo cerrar el diálogo; el service ya refresca
                                        },
                                      ),
                                    ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: Icon(
                              PhosphorIcons.trash(),
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              final ok = await _confirmar(
                                context,
                                'Eliminar actividad',
                                '¿Desea eliminar "${item.actividad}"? Esta accié³n no se puede deshacer.',
                              );
                              if (ok == true && item.id != null) {
                                try {
                                  await context
                                      .read<ActividadesService>()
                                      .eliminarActividad(item.id!);
                                } catch (e) {
                                  _mostrarError('Error eliminando: $e');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmar(
    BuildContext context,
    String titulo,
    String mensaje,
  ) async {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(titulo),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  Widget _buildArchivoTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ NUEVO: Selector de Sistema
            _buildSelectorSistema(),
            const SizedBox(height: 16),
            
            // Zona de drop
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: InkWell(
                onTap: _isLoading ? null : _seleccionarArchivo,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.cloudArrowUp(),
                        size: 48,
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nombreArchivo ?? 'Click para seleccionar archivo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              _nombreArchivo != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          color:
                              _nombreArchivo != null
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Formatos: CSV, Excel, TXT',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
  
            const SizedBox(height: 16),
  
            // Vista previa
            if (_validacionResultado != null) ...[
              _buildVistaPrevia(),
              const SizedBox(height: 16),
            ],
  
            // Botón importar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_isLoading || _actividadesArchivo == null || _sistemaIdSeleccionado == null) // ✅ BLOQUEADO SIN SISTEMA
                        ? null
                        : _importarArchivo,
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(PhosphorIcons.uploadSimple()),
                label: Text(_isLoading ? 'Importando...' : 'Importar archivo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPegarTextoTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ NUEVO: Selector de Sistema
            _buildSelectorSistema(),
            const SizedBox(height: 16),
  
            const Text(
              'Pega una lista de actividades (una por línea):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
  
            // Campo de texto - Altura fija para evitar desbordamiento en scroll
            SizedBox(
              height: 200, 
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText:
                      'Cambio de aceite\nRevisión de frenos\nAlineación...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
  
            const SizedBox(height: 16),
  
            // Vista previa de validación
            if (_validacionResultado != null) ...[
              _buildVistaPrevia(),
              const SizedBox(height: 16),
            ],
  
            // Botones
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _textController.clear();
                    setState(() {
                      _validacionResultado = null;
                    });
                  },
                  icon: Icon(PhosphorIcons.eraser()),
                  label: const Text('Limpiar'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _validarTexto,
                  icon: Icon(PhosphorIcons.check()),
                  label: const Text('Validar'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (_isLoading ||
                              _textController.text.trim().isEmpty ||
                              (_validacionResultado?['validas'] as List?)
                                      ?.isEmpty ==
                                  true || 
                              _sistemaIdSeleccionado == null) // ✅ BLOQUEADO SIN SISTEMA
                          ? null
                          : _importarTexto,
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Icon(PhosphorIcons.uploadSimple()),
                  label: Text(_isLoading ? 'Importando...' : 'Importar texto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantillaTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.fileText(),
            size: 64,
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Descarga una plantilla de ejemplo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          const Text(
            'La plantilla incluye el formato correcto y ejemplos de actividades',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _descargarPlantilla,
            icon: Icon(PhosphorIcons.downloadSimple()),
            label: const Text('Descargar plantilla CSV'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaPrevia() {
    if (_validacionResultado == null) return const SizedBox();

    final validas = _validacionResultado!['validas'] as List<String>;
    final invalidas = _validacionResultado!['invalidas'] as List<String>;
    final duplicadas = _validacionResultado!['duplicadas'] as List<String>;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vista previa de validacié³n:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          if (validas.isNotEmpty)
            Text(
              '? ${validas.length} actividades válidas',
              style: TextStyle(color: Colors.green.shade700, fontSize: 13),
            ),
          if (invalidas.isNotEmpty)
            Text(
              '? ${invalidas.length} actividades inválidas',
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          if (duplicadas.isNotEmpty)
            Text(
              '? ${duplicadas.length} actividades duplicadas',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Future<void> _seleccionarArchivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          _nombreArchivo = file.name;
          _actividadesArchivo = null;
          _validacionResultado = null;
        });

        // Procesar archivo
        if (file.bytes != null) {
          List<Map<String, dynamic>> actividades = [];

          switch (file.extension?.toLowerCase()) {
            case 'csv':
              actividades = await ActividadesImportService.procesarCSV(
                file.bytes!,
              );
              break;
            case 'xlsx':
            case 'xls':
              actividades = await ActividadesImportService.procesarExcel(
                file.bytes!,
              );
              break;
            case 'txt':
              actividades = await ActividadesImportService.procesarTexto(
                file.bytes!,
              );
              break;
          }

          if (actividades.isNotEmpty) {
            setState(() {
              _actividadesArchivo = actividades;
              _validacionResultado =
                  ActividadesImportService.validarActividades(actividades);
            });
          }
        }
      }
    } catch (e) {
      _mostrarError('Error al seleccionar archivo: $e');
    }
  }

  // ✅ NUEVO: Método helper para construir el selector de sistema
  Widget _buildSelectorSistema() {
    return SistemaSelectorCampo(
      sistemaId: _sistemaIdSeleccionado,
      enabled: !_isLoading,
      onChanged: (sistema) {
        setState(() {
          _sistemaIdSeleccionado = sistema?.id;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'El sistema es obligatorio';
        }
        return null;
      },
    );
  }

  Future<void> _importarArchivo() async {
    if (_actividadesArchivo == null || _actividadesArchivo!.isEmpty || _sistemaIdSeleccionado == null) return;

    setState(() {
      _isLoading = true;
      _resultadoImportacion = '';
    });

    try {
      // El sistema_id se pasará como parámetro opcional al método importarActividades

      final resultado = await ActividadesApiService.importarActividades(
        _actividadesArchivo!,
        sobrescribir: _sobrescribir,
        sistemaId: _sistemaIdSeleccionado, // ✅ PASADO DIRECTAMENTE AL API
      );

      final resumen = resultado['resumen'] as Map<String, dynamic>;

      setState(() {
        _resultadoImportacion =
            'Importacié³n completada:\n'
            '? ${resumen['insertadas']} nuevas actividades\n'
            '? ${resumen['actualizadas']} actividades actualizadas\n'
            '? ${resumen['omitidas']} actividades omitidas';
      });

      // Recargar actividades
      if (mounted) {
        context.read<ActividadesService>().cargarActividades(
          forceRefresh: true,
        );
      }

      // Limpiar despué©s de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      setState(() {
        _resultadoImportacion = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _validarTexto() {
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    final List<Map<String, dynamic>> actividades = [];
    final lines = texto.split('\n');

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      if (t.contains(',')) {
        final parts = t.split(',');
        final name = parts[0].trim();
        final horas =
            parts.length > 1 ? double.tryParse(parts[1].trim()) ?? 0.0 : 0.0;
        final tecnicos =
            parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;
        if (name.isNotEmpty) {
          actividades.add({
            'actividad': name,
            'cant_hora': horas,
            'num_tecnicos': tecnicos,
          });
        }
      } else {
        actividades.add({'actividad': t, 'cant_hora': 0.0, 'num_tecnicos': 0});
      }
    }

    setState(() {
      _validacionResultado = ActividadesImportService.validarActividades(
        actividades,
      );
    });
  }

  Future<void> _importarTexto() async {
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _isLoading = true;
      _resultadoImportacion = '';
    });

    try {
      final resultado = await ActividadesImportService.importarDesdeTexto(
        texto: texto,
        sobrescribir: _sobrescribir,
        sistemaId: _sistemaIdSeleccionado, // ✅ PASADO AL SERVICE
      );

      final resumen = resultado['resumen'] as Map<String, dynamic>;

      setState(() {
        _resultadoImportacion =
            'Importacié³n completada:\n'
            '? ${resumen['insertadas']} nuevas actividades\n'
            '? ${resumen['actualizadas']} actividades actualizadas\n'
            '? ${resumen['omitidas']} actividades omitidas';
      });

      // Recargar actividades
      if (mounted) {
        context.read<ActividadesService>().cargarActividades(
          forceRefresh: true,
        );
      }

      // Limpiar despué©s de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      setState(() {
        _resultadoImportacion = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _descargarPlantilla() async {
    try {
      final csvContent = await ActividadesImportService.generarPlantillaCSV();
      // Agregar BOM para que Excel reconozca UTF-8 correctamente
      final List<int> byteList = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvContent)];
      final bytes = Uint8List.fromList(byteList);

      await dl.saveBytes(
        'plantilla_actividades.csv',
        bytes,
        mimeType: 'text/csv',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plantilla descargada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _mostrarError('Error al descargar plantilla: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
}
