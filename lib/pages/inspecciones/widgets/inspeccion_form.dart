/// ============================================================================
/// ARCHIVO: inspeccion_form.dart
///
/// PROPÓSITO: Formulario para crear y editar inspecciones
/// - Selección de equipo
/// - Selección de inspectores
/// - Selección de sistemas
/// - Selección de actividades
/// - Configuración de fecha y sitio
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/main.dart';
import '../models/inspeccion_model.dart';
import '../providers/inspecciones_provider.dart';
import '../providers/sistemas_provider.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_equipo.dart';
import 'package:infoapp/pages/servicios/forms/widgets/campo_cliente.dart';
import 'package:infoapp/features/auth/data/admin_user_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'selector_sistemas.dart';
import '../providers/actividades_provider.dart';
import 'selector_actividades.dart';
import 'selector_evidencias.dart';
import '../models/evidencia_seleccionada.dart';

class InspeccionForm extends StatefulWidget {
  final InspeccionModel? inspeccion;
  final VoidCallback? onSaved;

  const InspeccionForm({
    super.key,
    this.inspeccion,
    this.onSaved,
  });

  @override
  State<InspeccionForm> createState() => _InspeccionFormState();
}

class _InspeccionFormState extends State<InspeccionForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _sitioController;
  late DateTime _fechaSeleccionada;
  
  // Selecciones
  int? _clienteSeleccionado;
  int? _equipoIdSeleccionado;
  int? _estadoIdSeleccionado;
  List<int> _inspectoresSeleccionados = [];
  List<int> _sistemasSeleccionados = [];
  List<int> _actividadesSeleccionadas = [];
  List<int> _actividadesOriginalesIds = [];
  Map<int, String> _notasEliminacion = {};
  List<EvidenciaSeleccionada> _evidenciasSeleccionadas = [];
  

  // Datos cargados
  // List<EquipoModel> _equipos = []; // Gestionado internamente por CampoEquipo
  List<EstadoModel> _estados = [];

  bool _isLoading = false;
  bool _isLoadingData = false;
  List<AdminUser> _usuariosCandidatos = [];
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _sitioController = TextEditingController(
      text: widget.inspeccion?.sitio ?? 'PLANTA',
    );
    _fechaSeleccionada = widget.inspeccion?.fechaInspeDate ?? DateTime.now();
    
    // Si estamos editando, cargar datos existentes
    if (widget.inspeccion != null) {
      _clienteSeleccionado = widget.inspeccion!.clienteId;
      _equipoIdSeleccionado = widget.inspeccion!.equipoId;
      _estadoIdSeleccionado = widget.inspeccion!.estadoId;
      _inspectoresSeleccionados = widget.inspeccion!.inspectores
          ?.map((e) => e.usuarioId!)
          .toList() ?? [];
      _sistemasSeleccionados = widget.inspeccion!.sistemas
          ?.map((e) => e.sistemaId!)
          .toList() ?? [];
      _actividadesOriginalesIds = widget.inspeccion!.actividades
          ?.map((e) => e.actividadId!)
          .toList() ?? [];
      _actividadesSeleccionadas = widget.inspeccion!.actividades
          ?.where((a) => !a.estaEliminada)
          .map((e) => e.actividadId!)
          .toList() ?? [];

      // ✅ CARGAR EVIDENCIAS EXISTENTES
      if (widget.inspeccion!.evidencias != null) {
        final apiRoot = ServerConfig.instance.apiRoot();
        _evidenciasSeleccionadas = widget.inspeccion!.evidencias!.map((ev) {
          final ruta = ev.rutaImagen ?? '';
          // Si la ruta ya es una URL completa, usarla; si no, construirla con apiRoot
          final fullUrl = ruta.startsWith('http') ? ruta : '$apiRoot/$ruta';
          
          return EvidenciaSeleccionada(
            file: XFile(fullUrl),
            comentario: ev.comentario ?? '',
            actividadId: ev.actividadId,
            isRemote: true,
          );
        }).toList();
      }
    }
    
    // Cargar listas al iniciar
    _cargarDatosFormulario();
  }

  Future<void> _cargarDatosFormulario() async {
    setState(() => _isLoadingData = true);
    try {
      // Cargar solo estados (equipos se carga en el widget CampoEquipo)
      // Cargar solo estados (equipos se carga en el widget CampoEquipo)
      final estados = await ServiciosApiService.listarEstados(modulo: 'inspecciones');
      final usuarios = await AdminUserService.listarUsuarios();
      
      if (mounted) {
        final sistemasProvider = Provider.of<SistemasProvider>(context, listen: false);
        if (sistemasProvider.sistemas.isEmpty) {
          sistemasProvider.cargarSistemas();
        }

        final actividadesProvider = Provider.of<ActividadesProvider>(context, listen: false);
        if (actividadesProvider.actividades.isEmpty) {
          actividadesProvider.cargarActividades();
        }
      }
      
      if (mounted) {
        setState(() {
          _estados = estados;
          _usuariosCandidatos = usuarios;
          // Seleccionar primer estado por defecto si es nuevo registro
          if (_estados.isNotEmpty && widget.inspeccion == null && _estadoIdSeleccionado == null) {
            _estadoIdSeleccionado = _estados.first.id;
          }
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        // Silenciosamente fallar o mostrar snackbar si es crítico
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error cargando datos: $e')),
        // );
      }
    }
  }



  @override
  void dispose() {
    _sitioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inspeccion == null
              ? 'Nueva Inspección'
              : 'Editar Inspección ${widget.inspeccion!.oInspe}',
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(PhosphorIcons.floppyDisk()),
              onPressed: _guardarInspeccion,
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            _buildSeccionEstadoRelocalizada(),
            const SizedBox(height: 24),
            _buildSeccionEquipo(),
            const SizedBox(height: 24),
            _buildSeccionBasica(),
            const SizedBox(height: 24),
            _buildSeccionInspectores(),
            const SizedBox(height: 24),
            _buildSeccionSistemas(),
            const SizedBox(height: 24),
            _buildSeccionActividades(),
            const SizedBox(height: 24),
            _buildSeccionEvidencias(),
            const SizedBox(height: 24),
            const SizedBox(height: 32),
            _buildBotonesAccion(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEquipo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.factory(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Cliente y Equipo *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cliente
            CampoCliente(
              clienteSeleccionado: _clienteSeleccionado,
              onChanged: (cliente) {
                setState(() {
                  _clienteSeleccionado = cliente?.id;
                  // Resetear equipo al cambiar cliente
                  _equipoIdSeleccionado = null;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Debe seleccionar un cliente';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Equipo
            CampoEquipo(
              equipoSeleccionado: _equipoIdSeleccionado,
              clienteId: _clienteSeleccionado,
              onChanged: (equipo) {
                setState(() {
                  _equipoIdSeleccionado = equipo?.id;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Debe seleccionar un equipo';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEstadoRelocalizada() {
    if (!_isLoadingData && _estados.isEmpty) {
      return Card(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚠️ No hay estados configurados para el módulo de inspecciones. No se puede crear ni guardar el registro.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.flag(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Estado de la Inspección',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _estadoIdSeleccionado,
              decoration: InputDecoration(
                labelText: 'Estado *',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(PhosphorIcons.flag()),
              ),
              hint: _isLoadingData 
                  ? const Text('Cargando estados...') 
                  : const Text('Seleccionar Estado'),
              items: _estados.map((e) {
                return DropdownMenuItem<int>(
                  value: e.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(int.parse(e.color.replaceAll('#', '0xFF'))),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(e.nombre),
                    ],
                  ),
                );
              }).toList(),
              // ✅ Solo permitir cambiar el estado si ya existe la inspección (EDICIÓN)
              onChanged: (widget.inspeccion != null) ? (value) {
                setState(() {
                  _estadoIdSeleccionado = value;
                });
              } : null,
              validator: (value) {
                if (value == null) {
                  return 'Debe seleccionar un estado';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionBasica() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.info(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Información Básica',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _sitioController.text),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                const List<String> opciones = ['PLANTA', 'TALLER', 'OBRA', 'CLIENTE'];
                return opciones.where((String opcion) {
                  return opcion.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _sitioController.text = selection;
              },
              fieldViewBuilder: (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                // Sincronizar controladores
                if (fieldTextEditingController.text != _sitioController.text) {
                  fieldTextEditingController.text = _sitioController.text;
                }
                
                return TextFormField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Sitio de Inspección',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(PhosphorIcons.mapPin()),
                    hintText: 'Ej: PLANTA, TALLER, CAMPO',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El sitio es requerido';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _sitioController.text = value;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(PhosphorIcons.calendar()),
              title: const Text('Fecha de Inspección'),
              subtitle: Text(
                '${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: ElevatedButton.icon(
                icon: Icon(PhosphorIcons.calendarPlus(), size: 18),
                label: const Text('Cambiar'),
                onPressed: _seleccionarFecha,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionInspectores() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.users(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Inspectores *',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: (_showErrors && _inspectoresSeleccionados.isEmpty) ? Colors.red : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Seleccione los usuarios que realizarán la inspección',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (_showErrors && _inspectoresSeleccionados.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Es obligatorio seleccionar al menos un inspector',
                  style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Agregar Inspector',
                border: OutlineInputBorder(),
                prefixIcon: Icon(PhosphorIcons.userPlus()),
              ),
              items: _usuariosCandidatos.map((user) {
                // El usuario prefiere NOMBRE_USER, que se mapea a user.usuario
                final nombre = user.usuario.isNotEmpty ? user.usuario : (user.nombreCompleto ?? 'Sin Nombre');
                
                return DropdownMenuItem<int>(
                  value: user.id,
                  child: Text(nombre, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (userId) {
                if (userId != null) {
                  setState(() {
                    if (!_inspectoresSeleccionados.contains(userId)) {
                      _inspectoresSeleccionados.add(userId);
                    }
                  });
                }
              },
              // Reseteamos el valor para permitir seleccionar otro
              initialValue: null, 
            ),
            const SizedBox(height: 16),
            if (_inspectoresSeleccionados.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _inspectoresSeleccionados.map((id) {
                  final user = _usuariosCandidatos.firstWhere(
                    (u) => u.id == id,
                    orElse: () => AdminUser(id: id, usuario: 'Desconocido', rol: '', estado: ''),
                  );
                  // El usuario prefiere NOMBRE_USER, que se mapea a user.usuario
                  final nombre = user.usuario.isNotEmpty ? user.usuario : (user.nombreCompleto ?? 'Sin Nombre');

                  return Chip(
                    label: Text(nombre),
                    deleteIcon: Icon(PhosphorIcons.x(), size: 18),
                    onDeleted: () {
                      setState(() {
                        _inspectoresSeleccionados.remove(id);
                      });
                    },
                    avatar: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (_inspectoresSeleccionados.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Debe seleccionar al menos un inspector',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionSistemas() {
    return SelectorSistemas(
      sistemasSeleccionados: _sistemasSeleccionados,
      showError: _showErrors && _sistemasSeleccionados.isEmpty,
      onChanged: (nuevosSistemas) {
        setState(() {
          _sistemasSeleccionados = nuevosSistemas;
        });
      },
    );
  }

  Widget _buildSeccionActividades() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.listChecks(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Actividades Estándar *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Busque y agregue las actividades a realizar:',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SelectorActividades(
              actividadesSeleccionadas: _actividadesSeleccionadas,
              actividadesDeInspeccion: _actividadesOriginalesIds,
              actividadesBloqueadas: widget.inspeccion?.actividades
                  ?.where((a) => a.autorizada == true)
                  .map((a) => a.actividadId!)
                  .toList() ?? [],
              sistemasSeleccionados: _sistemasSeleccionados,
              onChanged: (nuevas, notas) {
                setState(() {
                  _actividadesSeleccionadas = nuevas;
                  _notasEliminacion = notas;
                });
              },
              showError: _showErrors && _actividadesSeleccionadas.isEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEvidencias() {
    final actividadesProvider = Provider.of<ActividadesProvider>(context);
    final Map<int, String> mapActividades = {};
    for (var id in _actividadesSeleccionadas) {
      final act = actividadesProvider.obtenerPorId(id);
      mapActividades[id] = act?.actividad ?? 'Actividad #$id';
    }

    return SelectorEvidencias(
      evidencias: _evidenciasSeleccionadas,
      actividadesDisponibles: mapActividades,
      showError: _showErrors && _evidenciasSeleccionadas.isEmpty,
      onChanged: (nuevas) {
        setState(() => _evidenciasSeleccionadas = nuevas);
      },
    );
  }

  Widget _buildChipSeleccionable(
    String label,
    int id,
    List<int> selectedList,
    Function(bool) onChanged,
  ) {
    final isSelected = selectedList.contains(id);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onChanged,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildBotonesAccion() {
    final bool canSave = _estados.isNotEmpty; // ✅ Deshabilitar si no hay estados

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 450;
        
        return Row(
          children: [
            Expanded(
              flex: isMobile ? 1 : 1,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: isMobile ? 8 : 16),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: isMobile ? 2 : 2,
              child: ElevatedButton(
                onPressed: (_isLoading || !canSave) ? null : _guardarInspeccion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.inspeccion == null ? 'Crear Inspección' : 'Guardar Cambios',
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ],
        );
      }
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'ES'),
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> _guardarInspeccion() async {
    if (!mounted) return;

    // 1. Validar estados disponibles antes de nada
    if (_estados.isEmpty) {
      MyApp.showSnackBar('No hay estados configurados para inspecciones. Contacte al administrador.', backgroundColor: Colors.red);
      return;
    }

    // 2. Validar el formulario físicamente primero
    if (!_formKey.currentState!.validate()) {
      setState(() => _showErrors = true);
      return;
    }

    // 2. Capturar dependencias mientras el context es seguro (listen: false)
    final provider = Provider.of<InspeccionesProvider>(context, listen: false);
    final actividadesProvider = Provider.of<ActividadesProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    // 3. Validaciones de negocio con SnackBars seguros
    if (_equipoIdSeleccionado == null) {
      MyApp.showSnackBar('Debe seleccionar un equipo');
      return;
    }

    if (_inspectoresSeleccionados.isEmpty || 
        _sistemasSeleccionados.isEmpty || 
        _actividadesSeleccionadas.isEmpty || 
        _evidenciasSeleccionadas.isEmpty) {
      setState(() => _showErrors = true);
      MyApp.showSnackBar('Por favor, complete todos los campos obligatorios resaltados en rojo');
      return;
    }

    // 4. Validación: Cada actividad debe tener su foto
    final Set<int> idsConEvidencia = {};
    if (widget.inspeccion?.evidencias != null) {
      for (var ev in widget.inspeccion!.evidencias!) {
        if (ev.actividadId != null) idsConEvidencia.add(ev.actividadId!);
      }
    }
    for (var ev in _evidenciasSeleccionadas) {
      if (ev.actividadId != null) idsConEvidencia.add(ev.actividadId!);
    }

    final actividadesSinEvidencia = _actividadesSeleccionadas.where((id) => !idsConEvidencia.contains(id)).toList();

    if (actividadesSinEvidencia.isNotEmpty) {
      final nombres = actividadesSinEvidencia.map((id) => actividadesProvider.obtenerPorId(id)?.actividad ?? '#$id').join(', ');
      MyApp.showSnackBar('Faltan fotos para: $nombres');
      return;
    }

    // 5. Iniciar proceso de guardado
    if (mounted) setState(() => _isLoading = true);

    try {
      bool success;
      if (widget.inspeccion == null) {
        success = await provider.crearInspeccion(
          estadoId: _estadoIdSeleccionado!,
          sitio: _sitioController.text,
          fechaInspe: '${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}',
          equipoId: _equipoIdSeleccionado!,
          inspectores: _inspectoresSeleccionados,
          sistemas: _sistemasSeleccionados,
          actividades: _actividadesSeleccionadas,
          evidencias: _evidenciasSeleccionadas,
        );
      } else {
        success = await provider.actualizarInspeccion(
          inspeccionId: widget.inspeccion!.id!,
          estadoId: _estadoIdSeleccionado,
          sitio: _sitioController.text,
          fechaInspe: '${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}',
          equipoId: _equipoIdSeleccionado,
          inspectores: _inspectoresSeleccionados,
          sistemas: _sistemasSeleccionados,
          actividades: _actividadesSeleccionadas,
          notasEliminacion: _notasEliminacion,
          evidencias: _evidenciasSeleccionadas.isNotEmpty ? _evidenciasSeleccionadas : null,
        );
      }

      if (success) {
        MyApp.showSnackBar(
          widget.inspeccion == null ? '✅ Inspección creada exitosamente' : '✅ ${provider.error ?? 'Inspección actualizada exitosamente'}',
          backgroundColor: Colors.green,
        );
        widget.onSaved?.call();
        if (mounted) navigator.pop();
      } else {
        debugPrint('ERROR AL GUARDAR INSPECCIÓN: ${provider.error}');
        MyApp.showSnackBar('❌ ${provider.error ?? 'Error al guardar la inspección'}', backgroundColor: Colors.red);

        if (provider.error?.toLowerCase().contains('estado final') == true) {
          if (widget.inspeccion?.id != null) {
            await provider.cargarInspeccion(widget.inspeccion!.id!, silencioso: true);
          }
          if (mounted) Future.delayed(const Duration(seconds: 2), () { if (mounted) navigator.pop(); });
        }
      }
    } catch (e) {
      debugPrint('EXCEPTION EN _guardarInspeccion: $e');
      MyApp.showSnackBar('❌ Error inesperado: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
