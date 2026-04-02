import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/enums/modulo_enum.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class CamposAdicionalesPage extends StatefulWidget {
  const CamposAdicionalesPage({super.key});

  @override
  State<CamposAdicionalesPage> createState() => _CamposAdicionalesPageState();
}

class _CamposAdicionalesPageState extends State<CamposAdicionalesPage> {
  final _formKey = GlobalKey<FormState>();

  // Estados
  String _modulo = 'Servicios';
  final TextEditingController _nombreCampoController = TextEditingController();
  String _tipoCampo = 'Texto';
  bool _obligatorio = false;
  int? _estadoMostrar;
  int? _campoEditandoId;

  final List<String> _modulosDisponibles = [
    'Servicios',
    'Equipos',
  ];

  // ✅ TIPOS ACTUALIZADOS con Imagen y Archivo
  final List<String> _tiposCampo = [
    'Texto',
    'Párrafo',
    'Fecha',
    'Hora',
    'Fecha y hora',
    'Decimal',
    'Moneda',
    'Entero',
    'Link',
    'Imagen', // ✅ NUEVO
    'Archivo', // ✅ NUEVO
  ];

  List<Map<String, dynamic>> _campos = [];
  List<Map<String, dynamic>> _estados = []; // ✅ NUEVO: Lista de estados

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // ✅ NUEVA FUNCIÓN: Cargar datos iniciales
  Future<void> _cargarDatos() async {
    await Future.wait([_cargarCampos(), _cargarEstados()]);
  }

  Future<void> _cargarCampos() async {
    try {
      final url =
          '${ServerConfig.instance.apiRoot()}/core/fields/listar_campos_adicionales.php';
      // Cargar todos los campos sin filtrar (el filtrado se hace en UI)
      final uri = Uri.parse(url);
      final token = await AuthService.getToken();

//       print('🔍 Cargando campos adicionales desde: $uri');
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = response.body.trim();
//         print('📡 Respuesta recibida: ${responseBody.length} caracteres');

        // Intentar parsear la respuesta
        dynamic datos;
        try {
          datos = jsonDecode(responseBody);
        } catch (e) {
          // Si hay ruido en la respuesta, intentar encontrar el JSON válido
          final braceIndex = responseBody.indexOf('[');
          if (braceIndex != -1) {
            final cleanJson = responseBody.substring(braceIndex);
            datos = jsonDecode(cleanJson);
          } else {
            rethrow;
          }
        }

        List<Map<String, dynamic>> camposLista;
        if (datos is List) {
          camposLista = List<Map<String, dynamic>>.from(datos);
        } else if (datos is Map && datos['data'] != null) {
          camposLista = List<Map<String, dynamic>>.from(datos['data']);
        } else if (datos is Map && datos['campos'] != null) {
          camposLista = List<Map<String, dynamic>>.from(datos['campos']);
        } else {
          camposLista = [];
        }

//         print('✅ ${camposLista.length} campos adicionales cargados');
        // Normalizar módulo para filtrado robusto en cliente
        final camposNormalizados =
            camposLista.map((campo) {
              final String m = (campo['modulo']?.toString() ?? '').trim();
              final String moduloKey =
                  ModuloEnum.fromKey(m)?.key ??
                  ModuloEnum.fromDisplayName(m)?.key ??
                  m.toLowerCase();
              return {...campo, 'modulo_key': moduloKey};
            }).toList();

        setState(() {
          _campos = camposNormalizados;
        });
      } else {
//         print('❌ Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
//       print('❌ Error cargando campos: $e');
      // Mostrar error al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando campos adicionales: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ NUEVA FUNCIÓN: Cargar estados disponibles
  Future<void> _cargarEstados() async {
    try {
      final moduloKey = ModuloEnum.fromDisplayName(_modulo)?.key ?? 'servicio';
      final url =
          '${ServerConfig.instance.apiRoot()}/workflow/listar_estados.php';
      final token = await AuthService.getToken();
      
      final response = await http.get(
        Uri.parse(url).replace(queryParameters: {'modulo': moduloKey}),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final body = response.body.trim();
        dynamic json;
        try {
          json = jsonDecode(body);
        } catch (_) {
          // Intentar encontrar JSON válido si hay ruido
          final braceIndex = body.indexOf('{');
          final listIndex = body.indexOf('[');
          final startIndex =
              (braceIndex >= 0 && listIndex >= 0)
                  ? (braceIndex < listIndex ? braceIndex : listIndex)
                  : (braceIndex >= 0 ? braceIndex : listIndex);
          if (startIndex != -1) {
            json = jsonDecode(body.substring(startIndex));
          } else {
            json = null;
          }
        }

        List<Map<String, dynamic>> estados = [];
        if (json is List) {
          estados = List<Map<String, dynamic>>.from(
            json.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } else if (json is Map<String, dynamic>) {
          final list = (json['data'] ?? json['estados']);
          if (list is List) {
            estados = List<Map<String, dynamic>>.from(
              list.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          }
        }

        setState(() {
          _estados = estados;
        });
      }
    } catch (e) {
//       print('Error cargando estados: $e');
    }
  }

  void _guardarCampo() async {
    if (_formKey.currentState!.validate()) {
      // Validar permisos según acción
      final isEditando = _campoEditandoId != null;
      final requiredAction = isEditando ? 'actualizar' : 'crear';
      if (!PermissionStore.instance.can('campos_adicionales', requiredAction)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No tienes permiso para $requiredAction en "Campos adicionales"'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final moduloKey = ModuloEnum.fromDisplayName(_modulo)?.key ?? _modulo.toLowerCase();
      final url =
          isEditando
              ? '${ServerConfig.instance.apiRoot()}/core/fields/editar_campo_adicional.php'
              : '${ServerConfig.instance.apiRoot()}/core/fields/crear_campo_adicional.php';

      final token = await AuthService.getToken();
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (isEditando) 'id': _campoEditandoId,
          // Enviar la clave del módulo esperada por el backend
          'modulo': moduloKey,
          'nombre_campo': _nombreCampoController.text,
          'tipo_campo': _tipoCampo,
          'obligatorio': _obligatorio,
          'estado_mostrar': _estadoMostrar, // ✅ NUEVO CAMPO
        }),
      );

      final result = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _limpiarFormulario();
        _cargarCampos();
      }
    }
  }

  void _limpiarFormulario() {
    _nombreCampoController.clear();
    setState(() {
      // ✅ MANTENER el módulo actual, no resetear a 'Servicios'
      // _modulo = 'Servicios'; // ❌ REMOVIDO: Causaba que siempre volviera a Servicios
      _tipoCampo = 'Texto';
      _obligatorio = false;
      _estadoMostrar = null;
      _campoEditandoId = null;
    });
  }

  void _editarCampo(Map<String, dynamic> campo) {
    setState(() {
      _campoEditandoId = int.parse(campo['id'].toString());
      // Convertir módulo desde BD (clave o nombre visible) al nombre de visualización
      final String campoModulo = (campo['modulo']?.toString() ?? '').trim();
      _modulo =
          ModuloEnum.fromKey(campoModulo)?.displayName ??
          ModuloEnum.fromDisplayName(campoModulo)?.displayName ??
          'Servicios';
      _nombreCampoController.text = campo['nombre_campo'];
      _tipoCampo = campo['tipo_campo'];
      _obligatorio = campo['obligatorio'] == 1;
      _estadoMostrar =
          campo['estado_mostrar'] != null
              ? int.parse(campo['estado_mostrar'].toString())
              : null;
    });
    _cargarEstados();
  }

  void _eliminarCampo(int id) async {
    // ✅ CONFIRMACIÓN ANTES DE ELIMINAR
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Campo'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar este campo adicional?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      // Validar permiso de eliminación
      if (!PermissionStore.instance.can('campos_adicionales', 'eliminar')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes permiso para eliminar campos en "Campos adicionales"'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final url =
          '${ServerConfig.instance.apiRoot()}/core/fields/eliminar_campo_adicional.php';
      final token = await AuthService.getToken();
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
           if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id': id}),
      );

      final result = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _cargarCampos();
      }
    }
  }

  // ✅ NUEVA FUNCIÓN: Obtener nombre del estado
  String _obtenerNombreEstado(int? estadoId) {
    if (estadoId == null) return 'Sin estado específico';
    final estado = _estados.firstWhere(
      (e) => int.parse(e['id'].toString()) == estadoId,
      orElse: () => {'nombre_estado': 'Estado no encontrado'},
    );
    return estado['nombre_estado'] ?? 'Estado no encontrado';
  }

  // ✅ NUEVA FUNCIÓN: Ícono según tipo de campo
  IconData _obtenerIconoTipo(String tipo) {
    switch (tipo) {
      case 'Texto':
        return Icons.text_fields;
      case 'Párrafo':
        return Icons.text_snippet;
      case 'Fecha':
        return Icons.calendar_today;
      case 'Hora':
        return Icons.access_time;
      case 'Fecha y hora':
        return Icons.event;
      case 'Decimal':
        return Icons.calculate; // ✅ CORREGIDO
      case 'Moneda':
        return Icons.attach_money;
      case 'Entero':
        return Icons.numbers;
      case 'Link':
        return Icons.link;
      case 'Imagen':
        return Icons.image;
      case 'Archivo':
        return Icons.attach_file;
      default:
        return Icons.text_fields;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    final bool canView = PermissionStore.instance.can('campos_adicionales', 'ver');
    if (!canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Campos Adicionales'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder al módulo de campos adicionales',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campos Adicionales'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // ✅ LADO IZQUIERDO: Lista mejorada
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Builder(
                    builder: (context) {
                      final String moduloKey =
                          ModuloEnum.fromDisplayName(_modulo)?.key ?? _modulo;
                      final List<Map<String, dynamic>> camposFiltrados =
                          _campos
                              .where(
                                (c) =>
                                    (c['modulo_key']?.toString() ?? '') ==
                                    moduloKey,
                              )
                              .toList();
                      return Row(
                        children: [
                          Icon(
                            Icons.list_alt,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Campos Creados',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${camposFiltrados.length} campos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // List content
                  Expanded(
                    child: !PermissionStore.instance.can('campos_adicionales', 'listar')
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.list_alt, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'No tienes permiso para listar',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final String moduloKey =
                                  ModuloEnum.fromDisplayName(_modulo)?.key ?? _modulo;
                              final List<Map<String, dynamic>> camposFiltrados =
                                  _campos
                                      .where(
                                        (c) =>
                                            (c['modulo_key']?.toString() ?? '') ==
                                            moduloKey,
                                      )
                                      .toList();
                              
                              if (camposFiltrados.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay campos adicionales para "$_modulo"',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              return ListView.builder(
                                itemCount: camposFiltrados.length,
                                itemBuilder: (context, index) {
                                  final campo = camposFiltrados[index];
                                  final isSelected = _campoEditandoId == int.parse(campo['id'].toString());

                                  return Card(
                                    elevation: isSelected ? 4 : 1,
                                    color: isSelected ? Colors.blue[50] : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: isSelected
                                          ? const BorderSide(color: Colors.blue, width: 2)
                                          : BorderSide.none,
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue[100],
                                        child: Icon(
                                          _obtenerIconoTipo(campo['tipo_campo']),
                                          color: Colors.blue[800],
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        campo['nombre_campo'],
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${campo['tipo_campo']} • ${campo['modulo']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              PermissionStore.instance.can('campos_adicionales', 'actualizar')
                                                  ? Icons.edit
                                                  : Icons.visibility,
                                              color: PermissionStore.instance.can('campos_adicionales', 'actualizar')
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                            onPressed: () => _editarCampo(campo),
                                            tooltip: PermissionStore.instance.can('campos_adicionales', 'actualizar')
                                                ? 'Editar'
                                                : 'Ver detalles',
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: PermissionStore.instance.can('campos_adicionales', 'eliminar')
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            onPressed: PermissionStore.instance.can('campos_adicionales', 'eliminar')
                                                ? () => _eliminarCampo(int.parse(campo['id'].toString()))
                                                : null,
                                            tooltip: 'Eliminar',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ LADO DERECHO: Formulario mejorado
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (context) {
                   final isEditing = _campoEditandoId != null;
                   final canCreate = PermissionStore.instance.can('campos_adicionales', 'crear');
                   final canUpdate = PermissionStore.instance.can('campos_adicionales', 'actualizar');
                   final canAction = isEditing ? canUpdate : canCreate;

                   return Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // ✅ Header del formulario
                        Row(
                          children: [
                            Icon(
                              _campoEditandoId == null ? Icons.add : Icons.edit,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _campoEditandoId == null
                                  ? 'Nuevo Campo'
                                  : 'Editar Campo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Módulo
                        IgnorePointer(
                          ignoring: !canAction,
                          child: Opacity(
                            opacity: canAction ? 1.0 : 0.7,
                            child: DropdownButtonFormField<String>(
                              initialValue: _modulosDisponibles.contains(_modulo)
                                  ? _modulo
                                  : 'Servicios',
                              decoration: const InputDecoration(
                                labelText: 'Módulo',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items:
                                  _modulosDisponibles
                                      .map(
                                        (m) =>
                                            DropdownMenuItem(value: m, child: Text(m)),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _modulo = v!;
                                  _estadoMostrar = null;
                                });
                                _cargarEstados();
                                // Recargar campos para el módulo seleccionado
                                _cargarCampos();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nombre del campo
                        TextFormField(
                          controller: _nombreCampoController,
                          enabled: canAction,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del campo',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label),
                            hintText: 'Ej: Número de serie, Observaciones...',
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.isEmpty)
                                      ? 'Campo obligatorio'
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        // Tipo de campo
                        IgnorePointer(
                          ignoring: !canAction,
                          child: Opacity(
                            opacity: canAction ? 1.0 : 0.7,
                            child: DropdownButtonFormField<String>(
                              initialValue: _tipoCampo,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de campo',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.settings),
                              ),
                              items:
                                  _tiposCampo
                                      .map(
                                        (tipo) => DropdownMenuItem(
                                          value: tipo,
                                          child: Row(
                                            children: [
                                              Icon(_obtenerIconoTipo(tipo), size: 16),
                                              const SizedBox(width: 8),
                                              Text(tipo),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) => setState(() => _tipoCampo = v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ NUEVO: Selector de estado
                        IgnorePointer(
                          ignoring: !canAction,
                          child: Opacity(
                            opacity: canAction ? 1.0 : 0.7,
                            child: DropdownButtonFormField<int?>(
                              initialValue: _estadoMostrar,
                              decoration: const InputDecoration(
                                labelText: 'Mostrar en estado',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.flag),
                                hintText: 'Selecciona cuándo mostrar este campo',
                              ),
                              items: [
                                // ✅ REMOVIDO: "Todos los estados" - no sirve para nada
                                ..._estados.map(
                                  (estado) => DropdownMenuItem<int?>(
                                    value: int.parse(estado['id'].toString()),
                                    child: Text(estado['nombre_estado']),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _estadoMostrar = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Campo obligatorio
                        IgnorePointer(
                           ignoring: !canAction,
                           child: Opacity(
                             opacity: canAction ? 1.0 : 0.7,
                             child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SwitchListTile(
                                title: const Text('Campo obligatorio'),
                                subtitle: Text(
                                  _obligatorio
                                      ? 'Este campo será requerido al guardar'
                                      : 'Este campo será opcional',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                value: _obligatorio,
                                onChanged: (v) => setState(() => _obligatorio = v),
                                secondary: Icon(
                                  _obligatorio ? Icons.star : Icons.star_border,
                                  color: _obligatorio ? Colors.red : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Botones
                        ElevatedButton.icon(
                          icon: Icon(
                            _campoEditandoId == null ? Icons.save : Icons.update,
                          ),
                          label: Text(
                            _campoEditandoId == null
                                ? 'Guardar Campo'
                                : 'Actualizar Campo',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: canAction
                              ? () {
                                  if (_formKey.currentState!.validate()) {
                                    _guardarCampo();
                                  }
                                }
                              : null,
                        ),

                        if (_campoEditandoId != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.clear),
                            label: const Text('Cancelar Edición'),
                            onPressed: _limpiarFormulario,
                          ),
                        ],
                      ],
                    ),
                  );
                }
              ),
            ),
          ),
        ],
      ),
    );
  }
}
