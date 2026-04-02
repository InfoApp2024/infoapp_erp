import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../models/servicio_staff_model.dart';
import '../services/servicios_api_service.dart';
import '../../../features/auth/data/admin_user_service.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import '../services/servicios_sync_queue.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/operaciones_provider.dart';

/// Modal para seleccionar y gestionar usuarios como "Personal Asignado"
/// Reemplaza el origen de datos de staff por usuarios y al guardar
/// mapea `codigoStaff` -> `staff.id` para persistir con la API existente.
class UserSelectionModal extends StatefulWidget {
  final int servicioId;
  final List<ServicioStaffModel> staffYaAsignado;
  final Function(List<ServicioStaffModel>)? onStaffActualizado;
  final int? fixedOperacionId;
  final bool enabled; // NEW: Soporte para modo lectura

  const UserSelectionModal({
    super.key,
    required this.servicioId,
    required this.staffYaAsignado,
    this.onStaffActualizado,
    this.fixedOperacionId,
    this.enabled = true,
  });

  @override
  State<UserSelectionModal> createState() => _UserSelectionModalState();
}

class _UserSelectionModalState extends State<UserSelectionModal> {
  List<AdminUser> _todosLosUsuarios = [];
  // Claves de seleccié³n: preferimos CODIGO_STAFF; si no existe, usamos CORREO.
  final Set<String> _seleccionKeys = {};
  // Orden de seleccié³n para identificar al Responsable (primer seleccionado)
  final List<String> _seleccionOrden = [];
  // IDs de usuarios seleccionados para la API
  final Set<int> _selectedUsersIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  // ✅ NUEVO: Tracking de asignaciones (Usuario -> Operaciones)
  final Map<int, Set<int?>> _userAssignments = {};
  // Cache de nombres de operaciones para las etiquetas
  final Map<int, String> _opNames = {};

  @override
  void initState() {
    super.initState();
    // Preseleccié³n flexible basada en personal ya asignado:
    // intenta por cé³digo de staff, luego por correo, y finalmente por ID.
    for (final s in widget.staffYaAsignado) {
      // ✅ MEJORA: Si hay una operación fija, solo pre-marcar los que pertenecen a ella.
      // Si no hay operación fija (Modo Global), marcar todos.
      bool debeMarcar = true;
      if (widget.fixedOperacionId != null) {
        debeMarcar = (s.operacionId == widget.fixedOperacionId);
      }

      if (debeMarcar) {
        final key = _keyForAssigned(s);
        if (key.isNotEmpty) {
          _seleccionKeys.add(key);
          if (!_seleccionOrden.contains(key)) {
            _seleccionOrden.add(key);
          }
        }
        if (s.staffId > 0) {
          _selectedUsersIds.add(s.staffId);
          _userAssignments.putIfAbsent(s.staffId, () => {}).add(s.operacionId);
        }
      } else {
        // En Modo Global, igual cargamos todas para no perderlas al guardar
        if (s.staffId > 0) {
          _selectedUsersIds.add(s.staffId);
          _userAssignments.putIfAbsent(s.staffId, () => {}).add(s.operacionId);
        }
      }
    }

    // Si viene una operacin fija, cualquier seleccin nueva debera usarla
    if (widget.fixedOperacionId != null) {
      // Opcional: Podramos querer filtrar solo los usuarios de esa operacin?
      // Segn el requerimiento, es para AGREGAR a esa operacin.
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _cargarUsuarios();
        // Cargar operaciones para tener los nombres para las etiquetas
        final provider = context.read<OperacionesProvider>();
        await provider.cargarOperaciones(widget.servicioId);

        if (mounted) {
          setState(() {
            for (var op in provider.operaciones) {
              if (op.id != null) _opNames[op.id!] = op.descripcion;
            }
          });
        }
      }
    });
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final lista = await AdminUserService.listarUsuarios();
      // Filtrar usuarios inactivos y clientes en el front (fallback)
      final activos =
          lista.where((u) => _esUsuarioActivo(u) && !_esCliente(u)).toList();
      // Deduplicar por clave de usuario para garantizar seleccié³n éºnica y responsable éºnico
      final Map<String, AdminUser> porClave = {};
      for (final u in activos) {
        final k = _keyForUser(u);
        if (k.isNotEmpty) {
          porClave[k] = u;
        }
      }
      setState(() => _todosLosUsuarios = porClave.values.toList());
    } catch (e) {
      _handleError('Error cargando usuarios: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _esUsuarioActivo(AdminUser u) {
    final estado = (u.estado ?? '').toLowerCase().trim();
    if (estado.isEmpty) return true; // Si no viene el estado, considerar activo
    return estado == 'activo' ||
        estado == 'active' ||
        estado == '1' ||
        estado == 'true';
  }

  bool _esCliente(AdminUser u) {
    final rol = (u.rol ?? '').toLowerCase().trim();
    return rol == 'cliente';
  }

  // Clave consistente para seleccié³n: prioriza cé³digo de staff, luego correo, luego usuario
  String _keyForUser(AdminUser u) {
    if (u.codigoStaff != null && u.codigoStaff!.isNotEmpty) {
      return u.codigoStaff!;
    }
    if (u.correo != null && u.correo!.isNotEmpty) return u.correo!;
    // Fallback final por ID para asegurar coincidencia con asignados
    if (u.id > 0) return 'id:${u.id}';
    return u.usuario;
  }

  // Clave equivalente para un registro ya asignado
  String _keyForAssigned(ServicioStaffModel s) {
    if (s.staffCode.isNotEmpty) return s.staffCode;
    if (s.email != null && s.email!.isNotEmpty) return s.email!;
    if (s.staffId > 0) return 'id:${s.staffId}';
    return '';
  }

  void _toggleUsuario(AdminUser usuario) {
    if (!widget.enabled) return; // NEW: Requerido para modo lectura

    final key = _keyForUser(usuario);
    final userId = usuario.id;

    setState(() {
      if (_seleccionKeys.contains(key)) {
        if (widget.fixedOperacionId != null) {
          _userAssignments[userId]?.remove(widget.fixedOperacionId);
          if (_userAssignments[userId]?.isEmpty ?? true) {
            _seleccionKeys.remove(key);
            _seleccionOrden.remove(key);
            _selectedUsersIds.remove(userId);
          }
        } else {
          _seleccionKeys.remove(key);
          _seleccionOrden.remove(key);
          _selectedUsersIds.remove(userId);
          _userAssignments.remove(userId);
        }
      } else {
        _seleccionKeys.add(key);
        _seleccionOrden.add(key);
        _selectedUsersIds.add(userId);
        if (widget.fixedOperacionId != null) {
          _userAssignments
              .putIfAbsent(userId, () => {})
              .add(widget.fixedOperacionId);
        } else {
          if (!_userAssignments.containsKey(userId)) {
            _userAssignments[userId] = {null};
          }
        }
      }
    });
  }

  List<AdminUser> get _usuariosFiltrados {
    if (_searchQuery.isEmpty) return _todosLosUsuarios;
    final q = _searchQuery.toLowerCase();
    return _todosLosUsuarios.where((u) {
      final nombre = (u.nombreCompleto ?? '').toLowerCase();
      final usuario = u.usuario.toLowerCase();
      final correo = (u.correo ?? '').toLowerCase();
      return nombre.contains(q) || usuario.contains(q) || correo.contains(q);
    }).toList();
  }

  Future<void> _guardarCambios() async {
    // Permiso requerido para asignar/actualizar personal
    final store = PermissionStore.instance;
    if (!store.can('servicios_personal', 'actualizar')) {
      _handleError('No tienes permiso para asignar personal.');
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      // Obtener usuarios seleccionados y enviar sus usuario_id directamente
      final seleccionados =
          _todosLosUsuarios
              .where((u) => _seleccionKeys.contains(_keyForUser(u)))
              .toList()
            ..sort(
              (a, b) => _seleccionOrden
                  .indexOf(_keyForUser(a))
                  .compareTo(_seleccionOrden.indexOf(_keyForUser(b))),
            );

      final usuarioIds = seleccionados.map((u) => u.id).toList();
      if (usuarioIds.isEmpty) {
        _handleError('No hay usuarios seleccionados para asignar.');
        return;
      }

      // Si no hay conexié³n, encolar y salir
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        if (kIsWeb) {
          _handleError('En la web no se permite trabajar sin conexié³n.');
          return;
        }
        await ServiciosSyncQueue.enqueueActualizarUsuarios(
          servicioId: widget.servicioId,
          usuarioIds: usuarioIds,
          responsableId: seleccionados.first.id,
        );
        if (widget.onStaffActualizado != null) {
          widget.onStaffActualizado!(widget.staffYaAsignado);
        }
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final List<Map<String, dynamic>> finalAssignments = [];
      for (var entry in _userAssignments.entries) {
        final uId = entry.key;
        for (var opId in entry.value) {
          finalAssignments.add({'usuario_id': uId, 'operacion_id': opId});
        }
      }

      final resp = await ServiciosApiService.actualizarUsuariosServicio(
        servicioId: widget.servicioId,
        usuarioIds: usuarioIds,
        responsableId: seleccionados.first.id,
        operacionId: widget.fixedOperacionId,
        assignments: finalAssignments,
      );

      if (resp.isSuccess && resp.data != null) {
        if (widget.onStaffActualizado != null) {
          widget.onStaffActualizado!(resp.data!);
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        _handleError(
          resp.error ?? 'Error desconocido al actualizar personal asignado',
        );
      }
    } catch (e) {
      _handleError('Error guardando cambios: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleError(String message) {
    if (!mounted) return;

    String friendlyMessage = message;

    // Si contiene JSON de error del backend, intentar extraer solo el 'message'
    if (message.contains('{"success":false')) {
      try {
        final startIndex = message.indexOf('{');
        final jsonStr = message.substring(startIndex);
        final data = json.decode(jsonStr);
        if (data is Map && data.containsKey('message')) {
          friendlyMessage = data['message'];
        }
      } catch (_) {
        // Ignorar error de parseo y usar original
      }
    } else {
      // Limpiar prefijo "Exception: Error HTTP 403: " si existe
      friendlyMessage = friendlyMessage.replaceAll(
        RegExp(r'^Exception: Error HTTP \d+: '),
        '',
      );
    }

    final lowerMessage = friendlyMessage.toLowerCase();
    bool isBlocked =
        lowerMessage.contains('legalizado') ||
        lowerMessage.contains('final') ||
        lowerMessage.contains('cancelado') ||
        lowerMessage.contains('terminal');

    if (isBlocked) {
      friendlyMessage =
          'No se permiten realizar cambios en este servicio porque ya se encuentra en un estado final (LEGALIZADO/CANCELADO).\n\n'
          'Si necesitas hacer un ajuste, debes solicitar al área administrativa que retornen el servicio desde Gestión Financiera.';
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  isBlocked ? Icons.lock : Icons.error_outline,
                  color: isBlocked ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  isBlocked ? 'Acción Bloqueada' : 'Error',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(friendlyMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.users(), color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.enabled
                          ? 'Gestionar Personal'
                          : 'Ver Personal Asignado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x(), color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),

            if (widget.enabled)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                    hintText: 'Buscar usuario...',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

            if (!widget.enabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.info(), size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Modo Consulta: Esta operacié³n esté¡ finalizada.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),

            // Conteo seleccionados
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.checkCircle(),
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_seleccionKeys.length} seleccionado(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de usuarios
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _usuariosFiltrados.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.magnifyingGlass(),
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay usuarios disponibles'
                                  : 'No se encontraron resultados',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _usuariosFiltrados.length,
                        itemBuilder: (context, index) {
                          final u = _usuariosFiltrados[index];
                          final key = _keyForUser(u);
                          final isSelected = _seleccionKeys.contains(key);
                          final isResponsible =
                              _seleccionOrden.isNotEmpty &&
                              _seleccionOrden.first == key;
                          return _buildUserItem(u, isSelected, isResponsible);
                        },
                      ),
            ),

            // Botones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child:
                  widget.enabled
                      ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _isSaving
                                      ? null
                                      : () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_isSaving ||
                                          !PermissionStore.instance.can(
                                            'servicios_personal',
                                            'actualizar',
                                          ))
                                      ? null
                                      : _guardarCambios,
                              icon:
                                  _isSaving
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(PhosphorIcons.floppyDisk()),
                              label: const Text('Guardar'),
                            ),
                          ),
                        ],
                      )
                      : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cerrar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItem(AdminUser u, bool isSelected, bool isResponsible) {
    final key = _keyForUser(u);
    final nombreUsuario =
        u.usuario.trim().isNotEmpty ? u.usuario : (u.nombreCompleto ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: isSelected,
            onChanged: widget.enabled ? (_) => _toggleUsuario(u) : null,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    nombreUsuario,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isResponsible) ...[
                  const SizedBox(width: 8),
                  _buildTag('Responsable', Colors.orange),
                ],
              ],
            ),
            secondary: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                nombreUsuario.isNotEmpty ? nombreUsuario[0].toUpperCase() : '?',
              ),
            ),
          ),
          if (isSelected && widget.fixedOperacionId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Consumer<OperacionesProvider>(
                builder: (context, provider, _) {
                  if (provider.operaciones.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final userOps = _userAssignments[u.id] ?? {null};

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            userOps.map((opId) {
                              final name =
                                  opId == null
                                      ? 'General'
                                      : (_opNames[opId] ?? 'Op #$opId');
                              return Chip(
                                label: Text(
                                  name,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: Colors.blue.shade50,
                                deleteIcon:
                                    widget.enabled
                                        ? const Icon(Icons.close, size: 12)
                                        : null,
                                onDeleted:
                                    widget.enabled
                                        ? () {
                                          setState(() {
                                            _userAssignments[u.id]?.remove(
                                              opId,
                                            );
                                            if (_userAssignments[u.id]
                                                    ?.isEmpty ??
                                                true) {
                                              _seleccionKeys.remove(key);
                                              _seleccionOrden.remove(key);
                                              _selectedUsersIds.remove(u.id);
                                              _userAssignments.remove(u.id);
                                            }
                                          });
                                        }
                                        : null,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Asignar a otra operación',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed:
                            !widget.enabled
                                ? null
                                : () async {
                                  final dynamic
                                  result = await showDialog<dynamic>(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text(
                                            'Asignar a operación',
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                title: const Text('General'),
                                                onTap:
                                                    () => Navigator.pop(
                                                      context,
                                                      {'opId': null},
                                                    ),
                                              ),
                                              ...provider.operaciones.map(
                                                (op) => ListTile(
                                                  title: Text(op.descripcion),
                                                  onTap:
                                                      () => Navigator.pop(
                                                        context,
                                                        {'opId': op.id},
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  );
                                  if (result != null &&
                                      result is Map &&
                                      result.containsKey('opId')) {
                                    setState(() {
                                      _userAssignments
                                          .putIfAbsent(u.id, () => {})
                                          .add(result['opId'] as int?);
                                    });
                                  }
                                },
                      ),
                    ],
                  );
                },
              ),
            ),
          if (isSelected && widget.fixedOperacionId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.link(),
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Vinculado a la operacion seleccionada',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
