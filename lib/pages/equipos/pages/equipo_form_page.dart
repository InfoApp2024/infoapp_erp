import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infoapp/pages/equipos/widgets/estado_header.dart';
import 'package:infoapp/pages/equipos/models/equipo_model.dart';
import 'package:infoapp/pages/equipos/controllers/equipos_controller.dart';
import 'package:infoapp/pages/equipos/services/equipos_api_service.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/pages/servicios/services/servicios_api_service.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';
import 'package:infoapp/pages/servicios/models/equipo_model.dart' as srv;
import 'package:infoapp/pages/servicios/forms/widgets/campos_adicionales.dart';
import 'package:infoapp/pages/servicios/workflow/estado_workflow_service.dart';
import 'package:infoapp/core/enums/modulo_enum.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/widgets/searchable_select_field.dart';
import 'package:infoapp/pages/clientes/services/clientes_api_service.dart';
import 'package:infoapp/pages/clientes/services/ciudades_api_service.dart';
import 'package:infoapp/pages/clientes/models/cliente_model.dart';

class EquipoFormPage extends StatefulWidget {
  final EquipoModel? equipo;
  final EquiposController controller;
  const EquipoFormPage({super.key, this.equipo, required this.controller});

  @override
  State<EquipoFormPage> createState() => _EquipoFormPageState();
}

class _EquipoFormPageState extends State<EquipoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _plantaCtrl = TextEditingController();
  final _lineaProdCtrl = TextEditingController();
  final Map<int, dynamic> _valoresCamposAdicionales = {};
  final GlobalKey<CamposAdicionalesServiciosState> _camposAdicionalesKey =
      GlobalKey<CamposAdicionalesServiciosState>();
  int? _estadoId;
  List<EstadoModel> _todosLosEstados = [];
  List<EstadoModel> _estadosDisponibles = [];
  bool _isLoadingEstados = false;
  bool _isChangingState = false;
  EstadoModel? _siguienteEstado;
  bool _hasUpdates = false;
  bool _isLoadingEquipos = false;
  List<EquipoModel> _equiposFuente = [];
  List<ClienteModel> _clientesData = []; // ✅ NUEVO
  List<String> _empresasOptions = [];
  List<String> _ciudadesOptions = [];
  String? _serverErrorPlaca;
  String? _serverErrorCodigo;

  // Sugerencias a partir de equipos existentes (sin repetidos, ignorando mayúsculas/acentos/espacios)
  List<String> _distinctValues(String? Function(EquipoModel e) selector) {
    final map =
        <
          String,
          String
        >{}; // key normalizada -> valor canónico (primera aparición)
    final source =
        _equiposFuente.isNotEmpty ? _equiposFuente : widget.controller.equipos;
    for (final e in source) {
      var v = (selector(e) ?? '').trim();
      if (v.isEmpty) continue;
      final k = _normalizeKey(v);
      map.putIfAbsent(k, () => v);
    }
    final list = map.values.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  String _normalizeKey(String v) {
    var s = v.trim();
    const repl = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ä': 'A',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Ö': 'O',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ñ': 'N',
      'ñ': 'n',
    };
    repl.forEach((a, b) => s = s.replaceAll(a, b));
    s = s.replaceAll(RegExp(r"\s+"), ' ');
    return s.toLowerCase();
  }

  String? _canonicalFromText(List<String> items, String text) {
    if (text.trim().isEmpty) return null;
    final key = _normalizeKey(text);
    for (final it in items) {
      if (_normalizeKey(it) == key) return it;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.equipo;
    _nombreCtrl.text = e?.nombre ?? '';
    _marcaCtrl.text = e?.marca ?? '';
    _modeloCtrl.text = e?.modelo ?? '';
    _placaCtrl.text = e?.placa ?? '';
    _codigoCtrl.text = e?.codigo ?? '';
    _empresaCtrl.text = e?.nombreEmpresa ?? '';
    _ciudadCtrl.text = e?.ciudad ?? '';
    _plantaCtrl.text = e?.planta ?? '';
    _lineaProdCtrl.text = e?.lineaProd ?? '';
    _initEstados();
    // Cargar equipos desde DB si aún no están cargados, para alimentar los selectores
    Future.microtask(_ensureEquiposCargados);
    _cargarEmpresasYCiudades();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _placaCtrl.dispose();
    _codigoCtrl.dispose();
    _empresaCtrl.dispose();
    _ciudadCtrl.dispose();
    _plantaCtrl.dispose();
    _lineaProdCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureEquiposCargados() async {
    if (_equiposFuente.isNotEmpty || widget.controller.equipos.isNotEmpty) {
      return;
    }
    setState(() => _isLoadingEquipos = true);
    try {
      // Priorizar el controlador de Equipos para obtener todos los campos (ciudad, planta, línea)
      await widget.controller.cargarEquipos();
      _equiposFuente = List<EquipoModel>.from(widget.controller.equipos);

      // Fallback: si sigue vacío, intentar servicio de Servicios (puede carecer de ciudad/planta/línea)
      if (_equiposFuente.isEmpty) {
        try {
          final equiposSrv = await ServiciosApiService.listarEquipos();
          if (equiposSrv.isNotEmpty) {
            _equiposFuente = equiposSrv.map(_mapSrvEquipoToEquipos).toList();
          }
        } catch (_) {}
      }
    } catch (_) {
      // Ignorar error; se mostrará sin opciones si falla
    } finally {
      if (mounted) setState(() => _isLoadingEquipos = false);
    }
  }

  Future<void> _cargarEmpresasYCiudades() async {
    try {
      final clientes = await ClientesApiService.listarClientes(limit: 1000);
      final ciudades = await CiudadesApiService.listarCiudades();
      if (mounted) {
        setState(() {
          _clientesData = clientes; // ✅ Guardar data completa
          _empresasOptions =
              clientes
                  .map((e) => e.nombreCompleto)
                  .where((s) => s != null && s.isNotEmpty)
                  .cast<String>()
                  .toSet()
                  .toList()
                ..sort();
          _ciudadesOptions =
              ciudades
                  .map((c) => c.nombre)
                  .where((s) => s != null && s.isNotEmpty)
                  .cast<String>()
                  .toSet()
                  .toList()
                ..sort();
        });
      }
    } catch (_) {}
  }

  EquipoModel _mapSrvEquipoToEquipos(srv.EquipoModel e) {
    return EquipoModel(
      id: e.id,
      nombre: e.nombre,
      marca: e.marca,
      modelo: e.modelo,
      placa: e.placa,
      codigo: e.codigo,
      nombreEmpresa: e.nombreEmpresa,
      activo: e.activo,
      clienteId: e.clienteId, // ✅ NUEVO
    );
  }

  Future<void> _initEstados() async {
    setState(() => _isLoadingEstados = true);
    try {
      await _cargarEstados();
      await _cargarEstadoInicial();
      await _calcularEstadosDisponibles();
    } finally {
      if (mounted) setState(() => _isLoadingEstados = false);
    }
  }

  Future<void> _cargarEstados() async {
    try {
      _todosLosEstados = await ServiciosApiService.listarEstados(
        modulo: 'equipo',
      );
    } catch (_) {
      _todosLosEstados = [];
    }
  }

  Future<void> _cargarEstadoInicial() async {
    try {
      // Preferir el ID entregado por backend para evitar desalineaciones
      final List<EstadoModel> estados =
          _todosLosEstados.isNotEmpty
              ? _todosLosEstados
              : await ServiciosApiService.listarEstados(modulo: 'equipo');

      int? id;
      final idBackend = widget.equipo?.estadoId;
      if (idBackend != null && estados.any((e) => e.id == idBackend)) {
        id = idBackend;
      } else {
        // Si no hay ID, intentar por nombre legible
        final nombreBackend = (widget.equipo?.estadoNombre ?? '').trim();
        if (nombreBackend.isNotEmpty) {
          final encontrados = estados.where(
            (e) => e.nombre.toLowerCase() == nombreBackend.toLowerCase(),
          );
          if (encontrados.isNotEmpty) {
            id = encontrados.first.id;
          }
        }
        // Último recurso: mantener primer estado si sigue sin resolverse
        id ??= estados.isNotEmpty ? estados.first.id : null;
      }
      setState(() {
        _estadoId = id;
      });
    } catch (_) {
      // Si falla, dejar null; el widget manejará vacío
      setState(() {
        _estadoId = null;
      });
    }
  }

  Future<void> _calcularEstadosDisponibles() async {
    if (_estadoId == null || _todosLosEstados.isEmpty) {
      setState(() => _estadosDisponibles = _todosLosEstados);
      return;
    }
    try {
      // Asegurar configuración fresca del backend para respetar el patrón definido
      await EstadoWorkflowService().reload(modulo: ModuloEnum.equipos);
      await EstadoWorkflowService().ensureLoaded(modulo: ModuloEnum.equipos);
      final actual = _todosLosEstados.firstWhere(
        (e) => e.id == _estadoId,
        orElse: () => _todosLosEstados.first,
      );
      final nextNames = EstadoWorkflowService().nextStates(
        actual.nombre,
        modulo: ModuloEnum.equipos,
      );
      if (nextNames.isEmpty) {
        // Sin transiciones configuradas: no permitir saltos arbitrarios
        setState(() {
          _estadosDisponibles = [actual];
          _siguienteEstado = null;
        });
        return;
      }
      // Sólo estados permitidos por el workflow (sin incluir el actual)
      final siguientes =
          _todosLosEstados.where((e) => nextNames.contains(e.nombre)).toList();

      // Preferir el primer estado según el orden del workflow
      EstadoModel? preferido;
      if (nextNames.isNotEmpty) {
        final preferidoNombre = nextNames.first;
        try {
          preferido = _todosLosEstados.firstWhere(
            (e) => e.nombre == preferidoNombre,
          );
        } catch (_) {
          preferido = siguientes.isNotEmpty ? siguientes.first : null;
        }
      }
      setState(() {
        _estadosDisponibles = [actual, ...siguientes];
        _siguienteEstado = preferido;
      });
    } catch (_) {
      setState(() {
        _estadosDisponibles = _todosLosEstados;
        _siguienteEstado = null;
      });
    }
  }

  EstadoModel? _estadoSeleccionado() {
    if (_estadoId == null) return null;
    final lista =
        _estadosDisponibles.isNotEmpty ? _estadosDisponibles : _todosLosEstados;
    try {
      return lista.firstWhere((e) => e.id == _estadoId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _avanzarEstado() async {
    if (_siguienteEstado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay transición de estado disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final estadoActual = _estadoSeleccionado();
    Color colorActual = _parseColor(
      estadoActual?.color,
      estadoActual?.nombre ?? '',
    );
    Color colorSiguiente = _parseColor(
      _siguienteEstado?.color,
      _siguienteEstado?.nombre ?? '',
    );

    // Posibles siguientes desde el workflow ya calculado
    final opcionesSiguientes =
        _estadosDisponibles
            .where((e) => e.id != (estadoActual?.id ?? -1))
            .toList();
    EstadoModel? seleccionado = _siguienteEstado;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.arrow_forward, color: colorSiguiente),
                const SizedBox(width: 8),
                const Text('Avanzar Estado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Desea cambiar el estado del equipo?'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, color: colorActual, size: 12),
                          const SizedBox(width: 8),
                          Text(estadoActual?.nombre ?? 'Actual'),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Icon(Icons.arrow_downward, size: 18),
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, color: colorSiguiente, size: 12),
                          const SizedBox(width: 8),
                          Text(_siguienteEstado?.nombre ?? 'Siguiente'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (opcionesSiguientes.length > 1) ...[
                  const SizedBox(height: 16),
                  const Text('Elija el siguiente estado:'),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setLocalState) {
                      return Column(
                        children:
                            opcionesSiguientes.map((op) {
                              return RadioListTile<EstadoModel>(
                                title: Text(op.nombre),
                                value: op,
                                groupValue: seleccionado,
                                onChanged: (val) {
                                  setLocalState(() {
                                    seleccionado = val;
                                    colorSiguiente = _parseColor(
                                      val?.color,
                                      val?.nombre ?? '',
                                    );
                                  });
                                },
                                dense: true,
                              );
                            }).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorSiguiente,
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );

    if (confirmado == true) {
      await _cambiarEstadoEquipo(seleccionado ?? _siguienteEstado!);
    }
  }

  Future<void> _cambiarEstadoEquipo(EstadoModel nuevoEstado) async {
    if (_isChangingState) return;
    setState(() => _isChangingState = true);

    try {
      final equipoActualizado = EquipoModel(
        id: widget.equipo?.id,
        nombre: _nombreCtrl.text.trim(),
        marca: _marcaCtrl.text.trim(),
        modelo: _modeloCtrl.text.trim(),
        placa: _placaCtrl.text.trim(),
        codigo: _codigoCtrl.text.trim(),
        nombreEmpresa: _empresaCtrl.text.trim(),
        ciudad: _ciudadCtrl.text.trim(),
        planta: _plantaCtrl.text.trim(),
        lineaProd: _lineaProdCtrl.text.trim(),
        estadoId: nuevoEstado.id,
        estadoNombre: nuevoEstado.nombre,
        estadoColor: nuevoEstado.color,
        clienteId: widget.equipo?.clienteId, // ✅ Mantener
      );

      final result = widget.equipo?.id != null
          ? await EquiposApiService.actualizarEquipo(equipoActualizado)
          : {'success': false, 'message': 'No ID'};

      if (result['success'] == true) {
        setState(() {
          _estadoId = nuevoEstado.id;
          _hasUpdates = true;
        });
        await _calcularEstadosDisponibles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado actualizado a: ${nuevoEstado.nombre}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No se pudo cambiar el estado: ${result['message'] ?? 'Error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar estado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChangingState = false);
    }
  }

  Color _parseColor(String? hex, String nombre) {
    final h = (hex ?? '').replaceAll('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    switch (nombre.toLowerCase()) {
      case 'activo':
        return const Color(0xFF4CAF50);
      case 'en mantenimiento':
        return const Color(0xFFFB8C00);
      case 'en préstamo':
        return const Color(0xFF64B5F6);
      case 'inactivo':
        return const Color(0xFF9E9E9E);
      case 'de baja':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Future<void> _guardar() async {
    final isEdicion = widget.equipo != null;
    final tienePermiso =
        isEdicion
            ? PermissionStore.instance.can('equipos', 'actualizar')
            : PermissionStore.instance.can('equipos', 'crear');
    if (!tienePermiso) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdicion
                  ? 'Sin permisos para actualizar equipos'
                  : 'Sin permisos para crear equipos',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // 🛡️ REGLA CRÍTICA: Salvaguarda final en el formulario
    if (_todosLosEstados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se puede guardar: No hay estados configurados para el módulo de equipos.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    // Validar y guardar campos adicionales antes de persistir el equipo
    final camposWidget = _camposAdicionalesKey.currentState;
    if (camposWidget != null) {
      final puede = camposWidget.puedeCambiarEstado();
      if (!puede) {
        return;
      }
      if (widget.equipo?.id != null) {
        final okCampos = await camposWidget.guardarCamposAdicionales();
        if (!okCampos) {
          return;
        }
      }
    }
    final estadoSeleccionado =
        _estadoId == null
            ? null
            : (_todosLosEstados.isEmpty
                ? null
                : _todosLosEstados.firstWhere(
                  (e) => e.id == _estadoId,
                  orElse: () => _todosLosEstados.first,
                ));
    final equipo = EquipoModel(
      id: widget.equipo?.id,
      nombre: _nombreCtrl.text.trim(),
      marca: _marcaCtrl.text.trim(),
      modelo: _modeloCtrl.text.trim(),
      placa: _placaCtrl.text.trim(),
      codigo: _codigoCtrl.text.trim(),
      nombreEmpresa: _empresaCtrl.text.trim(),
      ciudad: _ciudadCtrl.text.trim(),
      planta: _plantaCtrl.text.trim(),
      lineaProd: _lineaProdCtrl.text.trim(),
      estadoId: _estadoId,
      estadoNombre: estadoSeleccionado?.nombre,
      clienteId: _clientesData
          .where((c) => c.nombreCompleto == _empresaCtrl.text.trim())
          .firstOrNull
          ?.id, // ✅ NUEVO: Resolver ID por nombre
    );

    final ctrl = widget.controller;
    
    // Limpiar errores previos
    setState(() {
      _serverErrorPlaca = null;
      _serverErrorCodigo = null;
    });

    final result =
        widget.equipo == null
            ? await ctrl.crear(equipo)
            : await ctrl.actualizar(equipo);

    if (!mounted) return;
    
    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.equipo == null
                ? 'Equipo creado exitosamente'
                : 'Equipo actualizado exitosamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Manejar errores específicos
      final code = result['error_code'];
      final msg = result['message']?.toString() ?? 'Error desconocido';
      
      if (code == 'DUPLICATE_PLACA') {
        setState(() => _serverErrorPlaca = msg);
        _formKey.currentState?.validate(); // Re-validar para mostrar error en campo
      } else if (code == 'DUPLICATE_CODIGO') {
         setState(() => _serverErrorCodigo = msg);
        _formKey.currentState?.validate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branding = context.primaryColor;
    final softBranding = branding.withOpacity(0.7);

    return PopScope(
      canPop: !_hasUpdates,
      onPopInvoked: (didPop) {
        if (!didPop && _hasUpdates) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equipo'),
          backgroundColor: branding,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            TextButton.icon(
              onPressed:
                  (((widget.equipo != null) &&
                              PermissionStore.instance.can(
                                'equipos',
                                'actualizar',
                              )) ||
                          ((widget.equipo == null) &&
                              PermissionStore.instance.can('equipos', 'crear')))
                      ? _guardar
                      : null,
              icon: const Icon(Icons.save_outlined, color: Colors.white),
              label: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_estadoId != null) ...[
                _estadoSeleccionado() == null
                    ? const SizedBox.shrink()
                    : EstadoHeader(
                      estActual: _estadoSeleccionado()!,
                      siguienteEstado: _siguienteEstado,
                      isChanging: _isChangingState,
                      onAdvance: _avanzarEstado,
                      branding: branding,
                    ),
                const SizedBox(height: 16),
              ],
              Theme(
                data: theme.copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: branding, width: 2),
                    ),
                    iconColor: softBranding,
                    prefixIconColor: softBranding,
                    suffixIconColor: softBranding,
                  ),
                ),
                child: Column(
                  children: [
                    if (_isLoadingEquipos) const LinearProgressIndicator(),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      maxLength: 40,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter: (
                        context, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) {
                        final remaining = (maxLength ?? 0) - currentLength;
                        final max = maxLength ?? 40;
                        return Text(
                          'Restan $remaining de $max',
                          style: TextStyle(color: softBranding),
                        );
                      },
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      validator:
                          (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    (() {
                      final marcas = _distinctValues((e) => e.marca);
                      // Mantener preselección canónica en el controller
                      _marcaCtrl.text =
                          _canonicalFromText(marcas, _marcaCtrl.text) ??
                          _marcaCtrl.text;
                      return SearchableSelectField(
                        label: 'Marca',
                        controller: _marcaCtrl,
                        items: marcas,
                        hint: 'Seleccione o busque una marca',
                        prefixIcon: Icons.precision_manufacturing_outlined,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                      );
                    })(),
                    const SizedBox(height: 12),
                    (() {
                      final modelos = _distinctValues((e) => e.modelo);
                      _modeloCtrl.text =
                          _canonicalFromText(modelos, _modeloCtrl.text) ??
                          _modeloCtrl.text;
                      return SearchableSelectField(
                        label: 'Modelo',
                        controller: _modeloCtrl,
                        items: modelos,
                        hint: 'Seleccione o busque un modelo',
                        prefixIcon: Icons.view_in_ar_outlined,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                      );
                    })(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _placaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Placa',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      maxLength: 40,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      onChanged: (_) {
                        if (_serverErrorPlaca != null) {
                           setState(() => _serverErrorPlaca = null);
                        }
                      },
                      buildCounter: (
                        context, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) {
                        final remaining = (maxLength ?? 0) - currentLength;
                        final max = maxLength ?? 40;
                        return Text(
                          'Restan $remaining de $max',
                          style: TextStyle(color: softBranding),
                        );
                      },
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Requerido';

                        // Prioridad: error del servidor
                        if (_serverErrorPlaca != null) return _serverErrorPlaca;

                        // Validación local (scoped por empresa)
                        final empresaActual =
                            _empresaCtrl.text.trim().toLowerCase();
                        if (empresaActual.isNotEmpty && widget.equipo == null) {
                          final existe = widget.controller.equipos.any(
                            (e) =>
                                (e.placa ?? '').toLowerCase().trim() ==
                                    value.toLowerCase() &&
                                (e.nombreEmpresa ?? '').toLowerCase().trim() ==
                                    empresaActual,
                          );
                          if (existe) {
                            return 'Ya existe un equipo con esta placa en esta empresa';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codigoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código',
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                      maxLength: 40,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter: (
                        context, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) {
                        final remaining = (maxLength ?? 0) - currentLength;
                        final max = maxLength ?? 40;
                        return Text(
                          'Restan $remaining de $max',
                          style: TextStyle(color: softBranding),
                        );
                      },
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      onChanged: (_) {
                        if (_serverErrorCodigo != null) {
                          setState(() => _serverErrorCodigo = null);
                        }
                      },
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        // Prioridad: error del servidor
                        if (_serverErrorCodigo != null) {
                          return _serverErrorCodigo;
                        }

                        // Validación local (scoped por empresa)
                        if (value.isNotEmpty && widget.equipo == null) {
                          final empresaActual =
                              _empresaCtrl.text.trim().toLowerCase();
                          if (empresaActual.isNotEmpty) {
                            final existe = widget.controller.equipos.any(
                              (e) =>
                                  (e.codigo ?? '').toLowerCase().trim() ==
                                      value.toLowerCase() &&
                                  (e.nombreEmpresa ?? '').toLowerCase().trim() ==
                                      empresaActual,
                            );
                            if (existe) {
                              return 'Ya existe con este código en esta empresa';
                            }
                          }
                        }
                        return null; // Código es opcional si no hay duplicados
                      },
                    ),
                    const SizedBox(height: 12),
                    (() {
                      // Usar opciones de la API de Clientes
                      _empresaCtrl.text =
                          _canonicalFromText(
                            _empresasOptions,
                            _empresaCtrl.text,
                          ) ??
                          _empresaCtrl.text;
                      return SearchableSelectField(
                        label: 'Empresa',
                        controller: _empresaCtrl,
                        items: _empresasOptions,
                        hint: 'Seleccione o busque una empresa',
                        prefixIcon: Icons.business_outlined,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                      );
                    })(),
                    const SizedBox(height: 12),
                    (() {
                      // Usar opciones de la API de Ciudades
                      _ciudadCtrl.text =
                          _canonicalFromText(
                            _ciudadesOptions,
                            _ciudadCtrl.text,
                          ) ??
                          _ciudadCtrl.text;
                      return SearchableSelectField(
                        label: 'Ciudad',
                        controller: _ciudadCtrl,
                        items: _ciudadesOptions,
                        hint: 'Seleccione o busque una ciudad',
                        prefixIcon: Icons.location_city_outlined,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                      );
                    })(),
                    const SizedBox(height: 12),
                    (() {
                      final plantas = _distinctValues((e) => e.planta);
                      _plantaCtrl.text =
                          _canonicalFromText(plantas, _plantaCtrl.text) ??
                          _plantaCtrl.text;
                      return SearchableSelectField(
                        label: 'Planta',
                        controller: _plantaCtrl,
                        items: plantas,
                        hint: 'Seleccione o busque una planta',
                        prefixIcon: Icons.home_work_outlined,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                      );
                    })(),
                    const SizedBox(height: 12),
                    (() {
                      final lineas = _distinctValues((e) => e.lineaProd);
                      _lineaProdCtrl.text =
                          _canonicalFromText(lineas, _lineaProdCtrl.text) ??
                          _lineaProdCtrl.text;
                      return SearchableSelectField(
                        label: 'Línea de producción',
                        controller: _lineaProdCtrl,
                        items: lineas,
                        hint: 'Seleccione o busque una línea',
                        prefixIcon: Icons.settings_input_component,
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                      );
                    })(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_estadoId != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: branding,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.extension, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Campos Adicionales',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: branding.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CamposAdicionalesServicios(
                      key: _camposAdicionalesKey,
                      servicioId: widget.equipo?.id,
                      estadoId: _estadoId!,
                      valoresCampos: _valoresCamposAdicionales,
                      onValoresChanged:
                          (valores) => setState(() {
                            _valoresCamposAdicionales.clear();
                            _valoresCamposAdicionales.addAll(valores);
                          }),
                      enabled: true,
                      loadValuesOnInit: widget.equipo?.id != null,
                      modulo: 'Equipos',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
