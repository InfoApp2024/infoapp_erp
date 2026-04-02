import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:infoapp/features/auth/data/admin_user_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:infoapp/pages/staff/widgets/campo_departamento.dart';
import 'package:infoapp/pages/staff/widgets/campo_position.dart';
import 'package:infoapp/pages/staff/widgets/staff_widgets.dart';
import 'package:infoapp/features/auth/data/permissions_service.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/pages/clientes/services/especialidades_service.dart';
import 'package:infoapp/pages/clientes/models/especialidad_model.dart';

class AdminUserConsolePage extends StatefulWidget {
  const AdminUserConsolePage({super.key});

  @override
  State<AdminUserConsolePage> createState() => _AdminUserConsolePageState();
}

// Wrappers simples para reutilizar componentes de Staff en consola de usuarios
class _CampoDepartamentoWrapper extends StatelessWidget {
  final int? departamentoId;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  const _CampoDepartamentoWrapper({
    required this.departamentoId,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CampoDepartamento(
      departamentoId: departamentoId,
      onChanged: onChanged,
      enabled: enabled,
      autoShowAll: true,
    );
  }
}

class _CampoPositionWrapper extends StatelessWidget {
  final int? departamentoId;
  final int? posicionId;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  const _CampoPositionWrapper({
    required this.departamentoId,
    required this.posicionId,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CampoPosition(
      departamentoId: departamentoId,
      posicionId: posicionId,
      onChanged: onChanged,
      enabled: enabled,
      autoShowAll: true,
    );
  }
}

class _CampoEspecialidadWrapper extends StatefulWidget {
  final int? especialidadId;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  const _CampoEspecialidadWrapper({
    required this.especialidadId,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<_CampoEspecialidadWrapper> createState() =>
      _CampoEspecialidadWrapperState();
}

class _CampoEspecialidadWrapperState extends State<_CampoEspecialidadWrapper> {
  List<EspecialidadModel> _specialties = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  Future<void> _loadSpecialties() async {
    setState(() => _loading = true);
    try {
      final res = await EspecialidadesService.listarEspecialidades();
      if (mounted) {
        setState(() {
          _specialties = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si el valor seleccionado existe en la lista cargada
    // Si no existe (ej. cargando o eliminado), usar null para evitar error de aserción
    final bool exists = _specialties.any((s) => s.id == widget.especialidadId);
    final int? valueToUse = exists ? widget.especialidadId : null;

    return DropdownButtonFormField<int>(
      initialValue: valueToUse,
      decoration: const InputDecoration(labelText: 'Especialidad'),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Ninguna')),
        ..._specialties.map((s) {
          final id = s.id;
          final name = s.nomEspeci;
          if (id == null) return null;
          return DropdownMenuItem<int>(value: id, child: Text(name));
        }).whereType<DropdownMenuItem<int>>(),
      ],
      onChanged: widget.enabled ? widget.onChanged : null,
      icon:
          _loading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(PhosphorIcons.caretDown()),
    );
  }
}

class _AdminUserConsolePageState extends State<AdminUserConsolePage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _loading = ValueNotifier(false);
  List<AdminUser> _usuarios = [];
  AdminUser? _seleccionado;

  // Controladores del formulario de detalle
  final TextEditingController _usuarioCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _celularCtrl = TextEditingController();
  final TextEditingController _identificacionCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  final TextEditingController _emergenciaNombreCtrl = TextEditingController();
  final TextEditingController _emergenciaTelefonoCtrl = TextEditingController();
  final TextEditingController _salarioCtrl = TextEditingController();
  final TextEditingController _fechaNacimientoCtrl = TextEditingController();
  final TextEditingController _fechaContratacionCtrl = TextEditingController();
  final TextEditingController _funcionarioIdCtrl = TextEditingController();
  DateTime? _fechaNacimiento;
  DateTime? _fechaContratacion;
  int? _departamentoId;
  int? _posicionId;
  int? _especialidadId;
  String? _departamentoNombre;
  String? _posicionNombre;
  String _tipoDocumento = 'Cedula';
  String? _fotoLocalPath; // campo de foto (no URL)
  bool _esAuditor = false;
  bool _canEditClosedOps = false;
  // Estado de paginación
  int _pageSize = 100;
  int _pageIndex = 0;

  // Búsqueda de permisos
  final TextEditingController _searchPermisosController = TextEditingController();
  String _searchPermisosQuery = '';

  // Estado de permisos
  static const List<String> _acciones = [
    'listar',
    'crear',
    'actualizar',
    'eliminar',
    'ver',
    'exportar',
  ];

  // Acciones soportadas por cada módulo según funcionalidades reales
  static const Map<String, List<String>> _accionesCapacidades = {
    'usuarios': ['listar', 'ver', 'crear', 'actualizar', 'eliminar'],
    // Módulo Servicios principal: incluye filtrar y configurar columnas
    'servicios': [
      'listar',
      'ver',
      'crear',
      'actualizar',
      'eliminar',
      'exportar',
      'filtrar',
      'configurar_columnas',
    ],
    'servicios_repuestos': [
      'listar',
      'ver',
      'actualizar',
      'desbloquear',
    ], // ✅ NUEVO
    'servicios_personal': ['listar', 'ver', 'actualizar'],
    'servicios_campos_adicionales': ['listar', 'ver', 'actualizar'],
    'servicios_fotos': ['listar', 'ver', 'crear', 'actualizar', 'eliminar'],
    // Módulos de campos específicos de servicios ✅ NUEVO
    'servicios_tipo_mantenimiento': ['listar', 'ver', 'crear', 'eliminar'],
    'servicios_centro_costo': ['listar', 'ver', 'crear', 'eliminar'],
    'servicios_actividades': [
      'listar',
      'ver',
      'crear',
      'actualizar',
      'eliminar',
    ],
    'servicios_autorizado_por': [
      'listar',
      'ver',
      'crear',
      'actualizar',
      'eliminar',
      'exportar',
    ],
    // Módulo Plantillas: lista, creación, actualización y eliminación
    'plantillas': ['listar', 'ver', 'crear', 'actualizar', 'eliminar'],
    // Módulo Inventario: lista, ver, crear, actualizar, eliminar y exportar
    'inventario': [
      'listar',
      'ver',
      'crear',
      'actualizar',
      'eliminar',
      'exportar',
    ],
    // Módulo Equipos (registro de activos): lista, ver, crear, actualizar, eliminar y exportar
    'equipos': ['listar', 'ver', 'crear', 'actualizar', 'eliminar', 'exportar'],
    // Módulo Branding: ver y actualizar configuración de marca
    'branding': ['ver', 'actualizar'],
    // Módulo Chatbot: solo ver (acceso al chat)
    'chatbot': ['ver'],
    // Módulo Dashboard: ver (acceso a gráficas)
    'dashboard': ['ver'],
    // Módulo Geocerca: incluye monitoreo en tiempo real
    'geocerca': [
      'listar',
      'ver',
      'crear',
      'actualizar',
      'eliminar',
      'monitoreo',
    ],
    // Módulo Inspecciones
    'inspecciones': [
      'listar',
      'ver',
      'crear',
      'actualizar',
      'eliminar',
      'exportar',
    ],
    // Módulo Gestión Financiera (contabilidad y facturación)
    'gestion_financiera': [
      'listar',
      'ver',
      'exportar',
      'descargar',
      'actualizar', // Confirmar causación
      'devolver', // Retornar a operaciones
    ],
  };

  List<String> _accionesParaModulo(String modulo) {
    return _accionesCapacidades[modulo] ?? _acciones;
  }

  // Módulos disponibles en el editor de permisos
  static const List<String> _modulosMvp = [
    'usuarios',
    'servicios',
    // Módulo dedicado para administración de Estados y Transiciones
    'estados_transiciones',
    // Módulo dedicado para administración de Campos adicionales
    'campos_adicionales',
    // Módulo dedicado para configuración de Branding
    'branding',
    // Subgrupo específico para el campo "Autorizado Por" dentro de Servicios
    'servicios_autorizado_por',
    // Subgrupo específico para "Actividad a Realizar" dentro de Servicios
    'servicios_actividades',
    // Subgrupos específicos para gestión dentro de Servicios
    'servicios_repuestos',
    'servicios_personal',
    'servicios_campos_adicionales',
    'servicios_fotos',
    'servicios_tipo_mantenimiento',
    'servicios_centro_costo',
    // Módulo de administración de Plantillas
    'plantillas',
    // Módulo de Inventario
    'inventario',
    // Módulo de Equipos (registro de activos)
    'equipos',
    // Módulo de Clientes
    'clientes',
    // Módulo de Chatbot
    'chatbot',
    // Módulo de Dashboard
    'dashboard',
    // Módulo de Geocerca
    'geocerca',
    // Módulo de Inspecciones
    'inspecciones',
    // Módulo de Gestión Financiera
    'gestion_financiera',
  ];
  // Etiquetas amigables para mostrar nombres de módulos
  static const Map<String, String> _modulosLabels = {
    'usuarios': 'Usuarios',
    'servicios': 'Servicios',
    'estados_transiciones': 'Estados y Transiciones',
    'campos_adicionales': 'Campos adicionales',
    'branding': 'Branding',
    'servicios_autorizado_por': 'Servicios · Autorizado Por',
    'servicios_actividades': 'Servicios · Actividades',
    'servicios_repuestos': 'Servicios · Repuestos Suministrados',
    'servicios_personal': 'Servicios · Personal Asignado',
    'servicios_campos_adicionales': 'Servicios · Campos Adicionales',
    'servicios_fotos': 'Servicios · Fotos y Evidencias',
    'plantillas': 'Plantillas',
    'inventario': 'Inventario',
    'equipos': 'Equipos',
    'clientes': 'Clientes',
    'chatbot': 'Asistente Virtual (Chatbot)',
    'dashboard': 'Dashboard Gerencial',
    'geocerca': 'Geocerca',
    'inspecciones': 'Inspecciones',
    'servicios_tipo_mantenimiento': 'Servicios · Tipo de Mantenimiento',
    'servicios_centro_costo': 'Servicios · Centro de Costo',
    'gestion_financiera': 'Gestión Financiera',
  };
  Map<String, Set<String>> _permisosEdit = {};
  bool _permisosLoading = false;
  bool _permisosSaving = false;

  // Helper para mostrar mensajes de estado con colores
  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    final color =
        success ? Colors.green.shade600 : Theme.of(context).colorScheme.error;
    // Programar el despliegue para el siguiente frame para evitar
    // acceder a InheritedWidgets durante initState/dentro de construcciones tempranas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  // Limpia texto de excepciones comunes del servicio
  String _extractErrorMessage(Object e) {
    var t = e.toString();
    t = t.replaceFirst(RegExp(r'^Exception:\s*'), '');
    t = t.replaceFirst(RegExp(r'^Error:\s*'), '');
    t = t.replaceFirst(RegExp(r'\s*\(\d{3}\)\s*$'), '');
    return t.trim().isEmpty ? 'Ocurrió un error' : t.trim();
  }

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _actualizarNombreDepartamento(int? id) async {
    if (id == null) {
      setState(() => _departamentoNombre = null);
      return;
    }
    try {
      final lista = await DepartmentsApiService.listarDepartamentos();
      final dep = lista.firstWhere(
        (d) => d.id == id,
        orElse:
            () => DepartmentModel(
              id: 0,
              name: '',
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              hasManager: false,
            ),
      );
      setState(
        () => _departamentoNombre = dep.name.isNotEmpty ? dep.name : null,
      );
    } catch (_) {
      // ignorar errores de red para UI
    }
  }

  Future<void> _actualizarNombrePosicion(int? id, int? departamentoId) async {
    if (id == null) {
      setState(() => _posicionNombre = null);
      return;
    }
    try {
      final lista = await PositionsApiService.listarPosiciones(
        departmentId: departamentoId,
      );
      final pos = lista.firstWhere(
        (p) => p.id == id,
        orElse:
            () => PositionModel(
              id: 0,
              title: '',
              description: null,
              departmentId: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      );
      setState(() => _posicionNombre = pos.title.isNotEmpty ? pos.title : null);
    } catch (_) {
      // ignorar errores de red para UI
    }
  }

  // Canonicalización de roles para evitar errores de Dropdown
  String _safeRol(String? r) {
    if (r == null) return 'colaborador';
    final s = r.toLowerCase().trim();
    if (s == 'admin' || s == 'administrador') return 'administrador';
    if (s == 'usuario' || s == 'colaborador' || s == 'staff') {
      return 'colaborador';
    }
    if (s == 'cliente') return 'cliente';
    return 'colaborador'; // fallback seguro
  }

  void _setSeleccionado(AdminUser u) {
    setState(() {
      _seleccionado = u;
      _usuarioCtrl.text = u.usuario;
      _correoCtrl.text = u.correo ?? '';
      _celularCtrl.text = u.telefono ?? '';
      _identificacionCtrl.text = u.numeroIdentificacion ?? '';
      _tipoDocumento = _canonicalTipoDocumento(u.tipoIdentificacion);
      _direccionCtrl.text = u.direccion ?? '';
      _emergenciaNombreCtrl.text = u.contactoEmergenciaNombre ?? '';
      _emergenciaTelefonoCtrl.text = u.contactoEmergenciaTelefono ?? '';
      _fotoLocalPath = u.urlFoto;
      if (u.salario != null) {
        final formatter = NumberFormat.decimalPattern('es_CO');
        _salarioCtrl.text = formatter.format(u.salario);
      } else {
        _salarioCtrl.text = '';
      }
      _departamentoId = u.idDepartamento;
      _posicionId = u.idPosicion;
      _especialidadId = u.idEspecialidad;
      _fechaNacimiento = _parseDate(u.fechaNacimiento);
      _fechaContratacion = _parseDate(u.fechaContratacion);
      _fechaNacimientoCtrl.text =
          _fechaNacimiento != null ? _formatDate(_fechaNacimiento!) : '';
      _fechaContratacionCtrl.text =
          _fechaContratacion != null ? _formatDate(_fechaContratacion!) : '';
      _funcionarioIdCtrl.text = u.funcionarioId?.toString() ?? '';
      _esAuditor = u.esAuditor ?? false;
      _canEditClosedOps = u.canEditClosedOps ?? false;
    });
    // Cargar permisos del usuario seleccionado
    _cargarPermisosUsuario(u.id);
  }

  Future<void> _guardarSeleccionado() async {
    final u = _seleccionado;
    if (u == null) return;
    try {
      final ok = await AdminUserService.actualizarUsuario(
        id: u.id,
        usuario: _usuarioCtrl.text.trim(),
        // nombreCompleto: No se actualiza nombreCompleto porque corresponde a NOMBRE_CLIENTE
        correo:
            _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
        rol: u.rol,
        estado: u.estado,
        // Enviar siempre que exista un valor; el backend puede aceptar
        // tanto 'URL_FOTO' como 'uri_foto'. Si luego requiere subir archivo,
        // se integrará el upload.
        // Evitar guardar rutas locales blob:; solo enviar si es URL pública
        urlFoto:
            (_fotoLocalPath != null && !_fotoLocalPath!.startsWith('blob:'))
                ? _fotoLocalPath
                : null,
        telefono:
            _celularCtrl.text.trim().isEmpty ? null : _celularCtrl.text.trim(),
        tipoIdentificacion:
            _tipoDocumento.trim().isEmpty ? null : _tipoDocumento.trim(),
        numeroIdentificacion:
            _identificacionCtrl.text.trim().isEmpty
                ? null
                : _identificacionCtrl.text.trim(),
        direccion:
            _direccionCtrl.text.trim().isEmpty
                ? null
                : _direccionCtrl.text.trim(),
        contactoEmergenciaNombre:
            _emergenciaNombreCtrl.text.trim().isEmpty
                ? null
                : _emergenciaNombreCtrl.text.trim(),
        contactoEmergenciaTelefono:
            _emergenciaTelefonoCtrl.text.trim().isEmpty
                ? null
                : _emergenciaTelefonoCtrl.text.trim(),
        fechaNacimiento:
            _fechaNacimiento != null ? _formatDate(_fechaNacimiento!) : null,
        fechaContratacion:
            _fechaContratacion != null
                ? _formatDate(_fechaContratacion!)
                : null,
        idDepartamento: _departamentoId,
        idPosicion: _posicionId,
        idEspecialidad: _especialidadId,
        salario:
            _salarioCtrl.text.trim().isEmpty
                ? null
                : double.tryParse(_salarioCtrl.text.trim().replaceAll('.', '')),
        // Send identification as NIT as well to ensure it's saved in the expected column
        nit:
            _identificacionCtrl.text.trim().isEmpty
                ? null
                : _identificacionCtrl.text.trim(),
        funcionarioId:
            _funcionarioIdCtrl.text.trim().isEmpty
                ? null
                : int.tryParse(_funcionarioIdCtrl.text.trim()),
        esAuditor: _esAuditor,
        canEditClosedOps: _canEditClosedOps,
      );
      if (ok) {
        try {
          await AdminUserService.invalidateCache();
        } catch (_) {}
        setState(() {
          final i = _usuarios.indexWhere((x) => x.id == u.id);
          if (i >= 0) {
            _usuarios[i] = AdminUser(
              id: u.id,
              usuario: _usuarioCtrl.text.trim(),
              nombreCompleto: _usuarioCtrl.text.trim(),
              correo:
                  _correoCtrl.text.trim().isEmpty
                      ? null
                      : _correoCtrl.text.trim(),
              rol: u.rol,
              estado: u.estado,
              telefono:
                  _celularCtrl.text.trim().isEmpty
                      ? null
                      : _celularCtrl.text.trim(),
              funcionarioId:
                  _funcionarioIdCtrl.text.trim().isEmpty
                      ? null
                      : int.tryParse(_funcionarioIdCtrl.text.trim()),
              tipoIdentificacion:
                  _tipoDocumento.trim().isEmpty ? null : _tipoDocumento.trim(),
              numeroIdentificacion:
                  _identificacionCtrl.text.trim().isEmpty
                      ? null
                      : _identificacionCtrl.text.trim(),
              direccion:
                  _direccionCtrl.text.trim().isEmpty
                      ? null
                      : _direccionCtrl.text.trim(),
              contactoEmergenciaNombre:
                  _emergenciaNombreCtrl.text.trim().isEmpty
                      ? null
                      : _emergenciaNombreCtrl.text.trim(),
              contactoEmergenciaTelefono:
                  _emergenciaTelefonoCtrl.text.trim().isEmpty
                      ? null
                      : _emergenciaTelefonoCtrl.text.trim(),
              fechaNacimiento:
                  _fechaNacimiento != null
                      ? _formatDate(_fechaNacimiento!)
                      : null,
              fechaContratacion:
                  _fechaContratacion != null
                      ? _formatDate(_fechaContratacion!)
                      : null,
              idDepartamento: _departamentoId,
              idPosicion: _posicionId,
              idEspecialidad: _especialidadId,
              salario:
                  _salarioCtrl.text.trim().isEmpty
                      ? null
                      : double.tryParse(
                        _salarioCtrl.text.trim().replaceAll('.', ''),
                      ),
              urlFoto: _fotoLocalPath ?? u.urlFoto,
              esAuditor: _esAuditor,
              canEditClosedOps: _canEditClosedOps,
            );
            _seleccionado = _usuarios[i];
          }
        });
        if (mounted) {
          _showMessage('Usuario actualizado', success: true);
        }
      } else {
        if (mounted) _showMessage('No fue posible actualizar');
      }
    } catch (e) {
      if (mounted) _showMessage(_extractErrorMessage(e));
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _canonicalTipoDocumento(String? v) {
    final s = (v ?? 'Cedula').trim().toLowerCase();
    switch (s) {
      case 'cedula':
      case 'cédula':
        return 'Cedula';
      case 'tarjeta identidad':
      case 'tarjeta de identidad':
        return 'Tarjeta identidad';
      case 'pasaporte':
        return 'Pasaporte';
      default:
        return 'Cedula';
    }
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final parts = s.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleEstado(AdminUser u) async {
    final nuevoEstado =
        u.estado.toLowerCase() == 'activo' ? 'inactivo' : 'activo';
    final estadoPrevio = u.estado;

    // Actualización optimista en UI
    setState(() {
      final i = _usuarios.indexWhere((x) => x.id == u.id);
      if (i >= 0) {
        _usuarios[i] = AdminUser(
          id: u.id,
          usuario: u.usuario,
          nombreCompleto: u.nombreCompleto,
          correo: u.correo,
          rol: u.rol,
          estado: nuevoEstado,
          telefono: u.telefono,
          tipoIdentificacion: u.tipoIdentificacion,
          numeroIdentificacion: u.numeroIdentificacion,
          codigoStaff: u.codigoStaff,
          urlFoto: u.urlFoto,
          fechaNacimiento: u.fechaNacimiento,
          fechaContratacion: u.fechaContratacion,
          idPosicion: u.idPosicion,
          idDepartamento: u.idDepartamento,
          idEspecialidad: u.idEspecialidad,
          salario: u.salario,
          direccion: u.direccion,
          contactoEmergenciaNombre: u.contactoEmergenciaNombre,
          contactoEmergenciaTelefono: u.contactoEmergenciaTelefono,
        );
      }
      if (_seleccionado?.id == u.id) {
        _seleccionado = AdminUser(
          id: u.id,
          usuario: u.usuario,
          nombreCompleto: u.nombreCompleto,
          correo: u.correo,
          rol: u.rol,
          estado: nuevoEstado,
          telefono: u.telefono,
          tipoIdentificacion: u.tipoIdentificacion,
          numeroIdentificacion: u.numeroIdentificacion,
          codigoStaff: u.codigoStaff,
          urlFoto: u.urlFoto,
          fechaNacimiento: u.fechaNacimiento,
          fechaContratacion: u.fechaContratacion,
          idPosicion: u.idPosicion,
          idDepartamento: u.idDepartamento,
          idEspecialidad: u.idEspecialidad,
          salario: u.salario,
          direccion: u.direccion,
          contactoEmergenciaNombre: u.contactoEmergenciaNombre,
          contactoEmergenciaTelefono: u.contactoEmergenciaTelefono,
        );
      }
    });

    try {
      final ok = await AdminUserService.actualizarUsuario(
        id: u.id,
        estado: nuevoEstado,
      );
      if (ok) {
        if (mounted) {
          _showMessage(
            nuevoEstado == 'activo' ? 'Usuario activado' : 'Usuario inactivado',
            success: true,
          );
        }
      } else {
        throw Exception('No fue posible actualizar estado');
      }
    } catch (e) {
      // Revertir UI si falla
      setState(() {
        final i = _usuarios.indexWhere((x) => x.id == u.id);
        if (i >= 0) {
          _usuarios[i] = AdminUser(
            id: u.id,
            usuario: u.usuario,
            nombreCompleto: u.nombreCompleto,
            correo: u.correo,
            rol: u.rol,
            estado: estadoPrevio,
            telefono: u.telefono,
            tipoIdentificacion: u.tipoIdentificacion,
            numeroIdentificacion: u.numeroIdentificacion,
            codigoStaff: u.codigoStaff,
            urlFoto: u.urlFoto,
            fechaNacimiento: u.fechaNacimiento,
            fechaContratacion: u.fechaContratacion,
            idPosicion: u.idPosicion,
            idDepartamento: u.idDepartamento,
            idEspecialidad: u.idEspecialidad,
            salario: u.salario,
            direccion: u.direccion,
            contactoEmergenciaNombre: u.contactoEmergenciaNombre,
            contactoEmergenciaTelefono: u.contactoEmergenciaTelefono,
          );
        }
        if (_seleccionado?.id == u.id) {
          _seleccionado = AdminUser(
            id: u.id,
            usuario: u.usuario,
            nombreCompleto: u.nombreCompleto,
            correo: u.correo,
            rol: u.rol,
            estado: estadoPrevio,
            telefono: u.telefono,
            tipoIdentificacion: u.tipoIdentificacion,
            numeroIdentificacion: u.numeroIdentificacion,
            codigoStaff: u.codigoStaff,
            urlFoto: u.urlFoto,
            fechaNacimiento: u.fechaNacimiento,
            fechaContratacion: u.fechaContratacion,
            idPosicion: u.idPosicion,
            idDepartamento: u.idDepartamento,
            idEspecialidad: u.idEspecialidad,
            salario: u.salario,
            direccion: u.direccion,
            contactoEmergenciaNombre: u.contactoEmergenciaNombre,
            contactoEmergenciaTelefono: u.contactoEmergenciaTelefono,
          );
        }
      });
      if (mounted) _showMessage(_extractErrorMessage(e));
    }
  }

  Future<void> _cargarUsuarios() async {
    _loading.value = true;
    // Requiere permiso para listar o ver usuarios
    if (!PermissionStore.instance.can('usuarios', 'listar') &&
        !PermissionStore.instance.can('usuarios', 'ver')) {
      _showMessage('Sin permisos para listar/ver usuarios');
      _loading.value = false;
      return;
    }
    try {
      final list = await AdminUserService.listarUsuarios(
        query:
            _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
        includeClients: true,
      );
      setState(() {
        _usuarios = list;
        _pageIndex = 0; // resetear a la primera página al cargar/buscar
      });
    } catch (e) {
      _showMessage(_extractErrorMessage(e));
    } finally {
      _loading.value = false;
    }
  }

  Future<void> _abrirDialogoReset(AdminUser user) async {
    if (!PermissionStore.instance.can('usuarios', 'actualizar')) {
      _showMessage('No tienes permiso para actualizar usuarios');
      return;
    }
    final nuevaController = TextEditingController();
    final confirmarController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure1 = true;
    bool obscure2 = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text('Cambiar contraseña: ${user.usuario}'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nuevaController,
                        obscureText: obscure1,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure1
                                  ? PhosphorIcons.eye()
                                  : PhosphorIcons.eyeSlash(),
                            ),
                            onPressed:
                                () => setLocal(() => obscure1 = !obscure1),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'La contraseña es requerida';
                          }
                          if (v.trim().length < 8) {
                            return 'Min. 8 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmarController,
                        obscureText: obscure2,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure2
                                  ? PhosphorIcons.eye()
                                  : PhosphorIcons.eyeSlash(),
                            ),
                            onPressed:
                                () => setLocal(() => obscure2 = !obscure2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Confirma la contraseña';
                          }
                          if (v.trim() != nuevaController.text.trim()) {
                            return 'No coincide con la nueva contraseña';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final ok = await AdminUserService.resetPasswordAdmin(
                        userId: user.id,
                        nuevaPassword: nuevaController.text.trim(),
                      );
                      if (ok) {
                        if (mounted) {
                          _showMessage(
                            'Contraseña actualizada correctamente',
                            success: true,
                          );
                        }
                        Navigator.pop(ctx);
                      } else {
                        _showMessage('No fue posible actualizar la contraseña');
                      }
                    } catch (e) {
                      _showMessage(_extractErrorMessage(e));
                    }
                  },
                  icon: Icon(PhosphorIcons.lockKey()),
                  label: const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeEditar = PermissionStore.instance.can(
      'usuarios',
      'actualizar',
    );
    final bool puedeVer = PermissionStore.instance.can('usuarios', 'ver');

    // 1. Permiso de VER - Gatekeeper para acceso al módulo
    if (!puedeVer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usuarios')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.prohibit(), size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No tienes permiso para acceder al módulo de usuarios',
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
        title: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Filtrar usuarios (usuario, correo o nombre)…',
                    hintStyle: TextStyle(color: Colors.grey.shade700),
                    prefixIcon: Icon(PhosphorIcons.funnel()),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 0,
                      ),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Limpiar',
                          icon: Icon(PhosphorIcons.x()),
                          onPressed: () {
                            _searchController.clear();
                            _cargarUsuarios();
                          },
                        ),
                        IconButton(
                          tooltip: 'Aplicar filtro',
                          icon: Icon(PhosphorIcons.magnifyingGlass()),
                          onPressed: _cargarUsuarios,
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (_) => _cargarUsuarios(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _cargarUsuarios,
              icon: Icon(PhosphorIcons.arrowsClockwise()),
              label: const Text('Actualizar'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed:
                  PermissionStore.instance.can('usuarios', 'crear')
                      ? () => _abrirDialogoCrearUsuario()
                      : null,
              icon: Icon(PhosphorIcons.userPlus()),
              label: const Text('Nuevo usuario'),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cambiar contraseña',
            icon: Icon(PhosphorIcons.lockKey()),
            onPressed:
                (_seleccionado == null ||
                        !PermissionStore.instance.can('usuarios', 'actualizar'))
                    ? null
                    : () => _abrirDialogoReset(_seleccionado!),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _loading,
                builder: (context, loading, _) {
                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 2. Permiso de LISTAR
                  final bool canListUsers = PermissionStore.instance.can(
                    'usuarios',
                    'listar',
                  );
                  if (!canListUsers) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.prohibit(),
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No tienes permiso para listar usuarios',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  if (_usuarios.isEmpty) {
                    return const Center(
                      child: Text('No hay usuarios para mostrar'),
                    );
                  }
                  // Layout maestro-detalle
                  return Row(
                    children: [
                      // Panel izquierdo: lista
                      SizedBox(
                        width: 360,
                        child: Card(
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final start = _pageIndex * _pageSize;
                                    final end = math.min(
                                      start + _pageSize,
                                      _usuarios.length,
                                    );
                                    final visible = _usuarios.sublist(
                                      start,
                                      end,
                                    );
                                    return ListView.separated(
                                      itemCount: visible.length,
                                      separatorBuilder:
                                          (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final u = visible[index];
                                        final globalIndex = start + index;
                                        final selected =
                                            _seleccionado?.id == u.id;
                                        return InkWell(
                                          onTap:
                                              puedeVer
                                                  ? () => _setSeleccionado(u)
                                                  : null,
                                          child: Container(
                                            color:
                                                selected
                                                    ? Colors.grey.shade200
                                                    : null,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        u.usuario,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        [
                                                          if (u
                                                                  .nombreCompleto
                                                                  ?.isNotEmpty ==
                                                              true)
                                                            u.nombreCompleto!,
                                                          if (u
                                                                  .correo
                                                                  ?.isNotEmpty ==
                                                              true)
                                                            u.correo!,
                                                        ].join('\n'),
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    const Text(
                                                      'Estado',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap:
                                                          PermissionStore
                                                                  .instance
                                                                  .can(
                                                                    'usuarios',
                                                                    'actualizar',
                                                                  )
                                                              ? () =>
                                                                  _toggleEstado(
                                                                    u,
                                                                  )
                                                              : null,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  (u.estado
                                                                              .toLowerCase() ==
                                                                          'activo')
                                                                      ? Colors
                                                                          .green
                                                                      : Colors
                                                                          .redAccent,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(u.estado),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    const Text(
                                                      'Rol',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    DropdownButtonHideUnderline(
                                                      child: DropdownButton<
                                                        String
                                                      >(
                                                        value: _safeRol(u.rol),
                                                        items: const [
                                                          DropdownMenuItem(
                                                            value:
                                                                'colaborador',
                                                            child: Text(
                                                              'Colaborador',
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value:
                                                                'administrador',
                                                            child: Text(
                                                              'Administrador',
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value: 'cliente',
                                                            child: Text(
                                                              'Cliente',
                                                            ),
                                                          ),
                                                        ],
                                                        onChanged:
                                                            PermissionStore
                                                                    .instance
                                                                    .can(
                                                                      'usuarios',
                                                                      'actualizar',
                                                                    )
                                                                ? (
                                                                  nuevoRol,
                                                                ) async {
                                                                  if (nuevoRol ==
                                                                      null) {
                                                                    return;
                                                                  }
                                                                  final previo =
                                                                      u.rol;
                                                                  // Actualización optimista en UI
                                                                  setState(() {
                                                                    _usuarios[globalIndex] = AdminUser(
                                                                      id: u.id,
                                                                      usuario:
                                                                          u.usuario,
                                                                      nombreCompleto:
                                                                          u.nombreCompleto,
                                                                      correo:
                                                                          u.correo,
                                                                      rol:
                                                                          nuevoRol,
                                                                      estado:
                                                                          u.estado,
                                                                      telefono:
                                                                          u.telefono,
                                                                      tipoIdentificacion:
                                                                          u.tipoIdentificacion,
                                                                      numeroIdentificacion:
                                                                          u.numeroIdentificacion,
                                                                      codigoStaff:
                                                                          u.codigoStaff,
                                                                      urlFoto:
                                                                          u.urlFoto,
                                                                      fechaNacimiento:
                                                                          u.fechaNacimiento,
                                                                      fechaContratacion:
                                                                          u.fechaContratacion,
                                                                      idPosicion:
                                                                          u.idPosicion,
                                                                      idDepartamento:
                                                                          u.idDepartamento,
                                                                      salario:
                                                                          u.salario,
                                                                      direccion:
                                                                          u.direccion,
                                                                      contactoEmergenciaNombre:
                                                                          u.contactoEmergenciaNombre,
                                                                      contactoEmergenciaTelefono:
                                                                          u.contactoEmergenciaTelefono,
                                                                    );
                                                                  });
                                                                  try {
                                                                    await AdminUserService.actualizarUsuario(
                                                                      id: u.id,
                                                                      rol:
                                                                          nuevoRol,
                                                                    );
                                                                    if (mounted) {
                                                                      _showMessage(
                                                                        'Rol actualizado',
                                                                        success:
                                                                            true,
                                                                      );
                                                                    }
                                                                  } catch (e) {
                                                                    // Revertir si falla
                                                                    setState(() {
                                                                      _usuarios[globalIndex] = AdminUser(
                                                                        id: u.id,
                                                                        usuario:
                                                                            u.usuario,
                                                                        nombreCompleto:
                                                                            u.nombreCompleto,
                                                                        correo:
                                                                            u.correo,
                                                                        rol:
                                                                            previo,
                                                                        estado:
                                                                            u.estado,
                                                                        telefono:
                                                                            u.telefono,
                                                                        tipoIdentificacion:
                                                                            u.tipoIdentificacion,
                                                                        numeroIdentificacion:
                                                                            u.numeroIdentificacion,
                                                                        codigoStaff:
                                                                            u.codigoStaff,
                                                                        urlFoto:
                                                                            u.urlFoto,
                                                                        fechaNacimiento:
                                                                            u.fechaNacimiento,
                                                                        fechaContratacion:
                                                                            u.fechaContratacion,
                                                                        idPosicion:
                                                                            u.idPosicion,
                                                                        idDepartamento:
                                                                            u.idDepartamento,
                                                                        salario:
                                                                            u.salario,
                                                                        direccion:
                                                                            u.direccion,
                                                                        contactoEmergenciaNombre:
                                                                            u.contactoEmergenciaNombre,
                                                                        contactoEmergenciaTelefono:
                                                                            u.contactoEmergenciaTelefono,
                                                                      );
                                                                    });
                                                                    _showMessage(
                                                                      _extractErrorMessage(
                                                                        e,
                                                                      ),
                                                                    );
                                                                  }
                                                                }
                                                                : null,
                                                      ),
                                                    ),
                                                  ],
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
                              // Pie de lista: paginación simple
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final start = _pageIndex * _pageSize;
                                          final end = math.min(
                                            start + _pageSize,
                                            _usuarios.length,
                                          );
                                          final texto =
                                              _usuarios.isEmpty
                                                  ? '0 de 0 Registros'
                                                  : '${start + 1} - $end de ${_usuarios.length} Registros';
                                          return Text(
                                            texto,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Registros por página:'),
                                    const SizedBox(width: 8),
                                    DropdownButton<int>(
                                      value: _pageSize,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 5,
                                          child: Text('5'),
                                        ),
                                        DropdownMenuItem(
                                          value: 20,
                                          child: Text('20'),
                                        ),
                                        DropdownMenuItem(
                                          value: 50,
                                          child: Text('50'),
                                        ),
                                        DropdownMenuItem(
                                          value: 100,
                                          child: Text('100'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _pageSize = value;
                                          _pageIndex = 0;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Página anterior',
                                      icon: Icon(PhosphorIcons.caretLeft()),
                                      onPressed:
                                          (_pageIndex > 0)
                                              ? () {
                                                setState(() {
                                                  _pageIndex = math.max(
                                                    0,
                                                    _pageIndex - 1,
                                                  );
                                                });
                                              }
                                              : null,
                                    ),
                                    IconButton(
                                      tooltip: 'Página siguiente',
                                      icon: Icon(PhosphorIcons.caretRight()),
                                      onPressed:
                                          (((_pageIndex + 1) * _pageSize) <
                                                  _usuarios.length)
                                              ? () {
                                                setState(() {
                                                  _pageIndex = _pageIndex + 1;
                                                });
                                              }
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Panel derecho: detalle con pestañas
                      Expanded(
                        child: Card(
                          clipBehavior: Clip.hardEdge,
                          child: DefaultTabController(
                            length: 4,
                            child: Column(
                              children: [
                                TabBar(
                                  tabs: [
                                    Tab(
                                      icon: Icon(PhosphorIcons.pencilSimple()),
                                      text: 'Detalles',
                                    ),
                                    Tab(
                                      icon: Icon(PhosphorIcons.mapPin()),
                                      text: 'Dirección',
                                    ),
                                    Tab(
                                      icon: Icon(PhosphorIcons.plusCircle()),
                                      text: 'Adicionales',
                                    ),
                                    Tab(
                                      icon: Icon(PhosphorIcons.users()),
                                      text: 'Permisos',
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      // Detalles
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 0,
                                                    child: SizedBox(
                                                      width: 120,
                                                      child: IgnorePointer(
                                                        ignoring: !puedeEditar,
                                                        child: StaffPhotoPickerWidget(
                                                          photoUrl:
                                                              _fotoLocalPath,
                                                          userId:
                                                              _seleccionado?.id,
                                                          onPhotoSelected: (
                                                            path,
                                                          ) {
                                                            setState(() {
                                                              _fotoLocalPath =
                                                                  path;
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 24),
                                                  Expanded(
                                                    child: Column(
                                                      children: [
                                                        TextField(
                                                          controller:
                                                              _usuarioCtrl,
                                                          enabled: puedeEditar,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText:
                                                                    'Nombre del Usuario',
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  // Campos de contraseña eliminados según requerimiento
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller: _correoCtrl,
                                                      enabled: puedeEditar,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Correo',
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: TextField(
                                                      controller: _celularCtrl,
                                                      enabled: puedeEditar,
                                                      keyboardType:
                                                          TextInputType.phone,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly,
                                                      ],
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Teléfono',
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              // Descripción eliminada (no está en la tabla)
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: InputDecorator(
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Tipo de documento',
                                                          ),
                                                      child: DropdownButtonHideUnderline(
                                                        child: DropdownButton<
                                                          String
                                                        >(
                                                          value: _tipoDocumento,
                                                          icon: Icon(
                                                            PhosphorIcons.caretDown(),
                                                          ),
                                                          items: const [
                                                            DropdownMenuItem(
                                                              value: 'Cedula',
                                                              child: Text(
                                                                'Cedula',
                                                              ),
                                                            ),
                                                            DropdownMenuItem(
                                                              value:
                                                                  'Tarjeta identidad',
                                                              child: Text(
                                                                'Tarjeta identidad',
                                                              ),
                                                            ),
                                                            DropdownMenuItem(
                                                              value:
                                                                  'Pasaporte',
                                                              child: Text(
                                                                'Pasaporte',
                                                              ),
                                                            ),
                                                          ],
                                                          onChanged:
                                                              puedeEditar
                                                                  ? (
                                                                    v,
                                                                  ) => setState(() {
                                                                    _tipoDocumento =
                                                                        v ??
                                                                        'Cedula';
                                                                  })
                                                                  : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _identificacionCtrl,
                                                      enabled: puedeEditar,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly,
                                                      ],
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'No. Identificación',
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _fechaNacimientoCtrl,
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            'Fecha nacimiento (YYYY-MM-DD)',
                                                        suffixIcon: IconButton(
                                                          icon: Icon(
                                                            PhosphorIcons.calendarBlank(),
                                                          ),
                                                          onPressed: () async {
                                                            if (!puedeEditar) {
                                                              return;
                                                            }
                                                            final picked =
                                                                await showDatePicker(
                                                                  context:
                                                                      context,
                                                                  initialDate:
                                                                      _fechaNacimiento ??
                                                                      DateTime.now(),
                                                                  firstDate:
                                                                      DateTime(
                                                                        1900,
                                                                      ),
                                                                  lastDate:
                                                                      DateTime(
                                                                        2100,
                                                                      ),
                                                                );
                                                            if (picked !=
                                                                null) {
                                                              setState(() {
                                                                _fechaNacimiento =
                                                                    picked;
                                                                _fechaNacimientoCtrl
                                                                        .text =
                                                                    _formatDate(
                                                                      picked,
                                                                    );
                                                              });
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                      enabled: puedeEditar,
                                                      onChanged: (val) {
                                                        if (!puedeEditar) {
                                                          return;
                                                        }
                                                        final d = _parseDate(
                                                          val,
                                                        );
                                                        if (d != null) {
                                                          setState(
                                                            () =>
                                                                _fechaNacimiento =
                                                                    d,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller:
                                                          _fechaContratacionCtrl,
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            'Fecha contratación (YYYY-MM-DD)',
                                                        suffixIcon: IconButton(
                                                          icon: Icon(
                                                            PhosphorIcons.calendarBlank(),
                                                          ),
                                                          onPressed: () async {
                                                            if (!puedeEditar) {
                                                              return;
                                                            }
                                                            final picked =
                                                                await showDatePicker(
                                                                  context:
                                                                      context,
                                                                  initialDate:
                                                                      _fechaContratacion ??
                                                                      DateTime.now(),
                                                                  firstDate:
                                                                      DateTime(
                                                                        1900,
                                                                      ),
                                                                  lastDate:
                                                                      DateTime(
                                                                        2100,
                                                                      ),
                                                                );
                                                            if (picked !=
                                                                null) {
                                                              setState(() {
                                                                _fechaContratacion =
                                                                    picked;
                                                                _fechaContratacionCtrl
                                                                        .text =
                                                                    _formatDate(
                                                                      picked,
                                                                    );
                                                              });
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                      enabled: puedeEditar,
                                                      onChanged: (val) {
                                                        if (!puedeEditar) {
                                                          return;
                                                        }
                                                        final d = _parseDate(
                                                          val,
                                                        );
                                                        if (d != null) {
                                                          setState(
                                                            () =>
                                                                _fechaContratacion =
                                                                    d,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SwitchListTile(
                                                title: const Text(
                                                  'Auditor Financiero',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: const Text(
                                                  'Permite firmar auditorías de servicios antes del cierre contable.',
                                                ),
                                                secondary: Icon(
                                                  Icons.gavel_rounded,
                                                  color:
                                                      _esAuditor
                                                          ? Colors.blue
                                                          : Colors.grey,
                                                ),
                                                value: _esAuditor,
                                                onChanged:
                                                    puedeEditar
                                                        ? (val) => setState(
                                                          () =>
                                                              _esAuditor = val,
                                                        )
                                                          : null,
                                                activeThumbColor: Colors.blue,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              const SizedBox(height: 8),
                                              SwitchListTile(
                                                title: const Text(
                                                  'Editar Operaciones Cerradas',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: const Text(
                                                  'Permite editar o eliminar operaciones que ya han sido finalizadas.',
                                                ),
                                                secondary: Icon(
                                                  Icons.edit_note_rounded,
                                                  color:
                                                      _canEditClosedOps
                                                          ? Colors.blue
                                                          : Colors.grey,
                                                ),
                                                value: _canEditClosedOps,
                                                onChanged:
                                                    puedeEditar
                                                        ? (val) => setState(
                                                          () =>
                                                              _canEditClosedOps = val,
                                                        )
                                                          : null,
                                                activeThumbColor: Colors.blue,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                children: [
                                                  FilledButton(
                                                    onPressed:
                                                        PermissionStore.instance
                                                                .can(
                                                                  'usuarios',
                                                                  'actualizar',
                                                                )
                                                            ? _guardarSeleccionado
                                                            : null,
                                                    child: const Text(
                                                      'Guardar',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  OutlinedButton(
                                                    onPressed:
                                                        (_seleccionado ==
                                                                    null ||
                                                                !PermissionStore
                                                                    .instance
                                                                    .can(
                                                                      'usuarios',
                                                                      'eliminar',
                                                                    ))
                                                            ? null
                                                            : () =>
                                                                _confirmarEliminarUsuario(
                                                                  _seleccionado!,
                                                                ),
                                                    child: const Text('Borrar'),
                                                  ),
                                                  const Spacer(),
                                                  // Botón de cambiar contraseña movido al AppBar superior
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Dirección
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TextField(
                                                controller: _direccionCtrl,
                                                enabled: puedeEditar,
                                                maxLines: 3,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Dirección',
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _emergenciaNombreCtrl,
                                                      enabled: puedeEditar,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Contacto emergencia - Nombre',
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _emergenciaTelefonoCtrl,
                                                      enabled: puedeEditar,
                                                      keyboardType:
                                                          TextInputType.phone,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly,
                                                      ],
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Contacto emergencia - Teléfono',
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                children: [
                                                  FilledButton(
                                                    onPressed:
                                                        PermissionStore.instance
                                                                .can(
                                                                  'usuarios',
                                                                  'actualizar',
                                                                )
                                                            ? _guardarSeleccionado
                                                            : null,
                                                    child: const Text(
                                                      'Guardar',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Adicionales
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _CampoDepartamentoWrapper(
                                                      departamentoId:
                                                          _departamentoId,
                                                      onChanged: (id) async {
                                                        setState(() {
                                                          _departamentoId = id;
                                                          _posicionId =
                                                              null; // reset posición si cambia departamento
                                                          _posicionNombre =
                                                              null;
                                                        });
                                                        await _actualizarNombreDepartamento(
                                                          id,
                                                        );
                                                      },
                                                      enabled: puedeEditar,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: _CampoPositionWrapper(
                                                      departamentoId:
                                                          _departamentoId,
                                                      posicionId: _posicionId,
                                                      enabled: puedeEditar,
                                                      onChanged: (id) async {
                                                        setState(
                                                          () =>
                                                              _posicionId = id,
                                                        );
                                                        await _actualizarNombrePosicion(
                                                          id,
                                                          _departamentoId,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              _CampoEspecialidadWrapper(
                                                especialidadId: _especialidadId,
                                                enabled: puedeEditar,
                                                onChanged:
                                                    (id) => setState(
                                                      () =>
                                                          _especialidadId = id,
                                                    ),
                                              ),
                                              if (_departamentoNombre != null ||
                                                  _posicionNombre != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _departamentoNombre !=
                                                                null
                                                            ? 'Departamento seleccionado: ${_departamentoNombre!}'
                                                            : 'Departamento no seleccionado',
                                                        style:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .bodySmall,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        _posicionNombre != null
                                                            ? 'Cargo seleccionado: ${_posicionNombre!}'
                                                            : 'Cargo no seleccionado',
                                                        style:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .bodySmall,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: _salarioCtrl,
                                                enabled: puedeEditar,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  CurrencyInputFormatter(),
                                                ],
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Salario',
                                                      prefixText: 'COP ',
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: _funcionarioIdCtrl,
                                                enabled: puedeEditar,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                decoration: const InputDecoration(
                                                  labelText:
                                                      'ID Funcionario (Vínculo Cliente)',
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                children: [
                                                  FilledButton(
                                                    onPressed:
                                                        PermissionStore.instance
                                                                .can(
                                                                  'usuarios',
                                                                  'actualizar',
                                                                )
                                                            ? _guardarSeleccionado
                                                            : null,
                                                    child: const Text(
                                                      'Guardar',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Permisos
                                      _buildPermisosTab(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Permisos: carga, edición y guardado -----
  Future<void> _cargarPermisosUsuario(int userId) async {
    setState(() {
      _permisosLoading = true;
    });
    try {
      final data = await PermissionsService.listarPermisos(userId: userId);
      setState(() {
        _permisosEdit = data;
      });
    } catch (e) {
      // Si el backend no está listo, no bloquear la UI
      setState(() {
        _permisosEdit = {};
      });
    } finally {
      setState(() {
        _permisosLoading = false;
      });
    }
  }

  void _toggleAccion(String modulo, String accion, bool value) {
    final current = _permisosEdit[modulo] ?? <String>{};
    setState(() {
      if (value) {
        current.add(accion);
      } else {
        current.remove(accion);
      }
      _permisosEdit[modulo] = current;
    });
  }

  Future<void> _guardarPermisosUsuario() async {
    final u = _seleccionado;
    if (u == null) return;
    setState(() => _permisosSaving = true);
    try {
      final ok = await PermissionsService.actualizarPermisos(
        userId: u.id,
        permisos: _permisosEdit,
      );
      if (ok) {
        _showMessage('Permisos actualizados', success: true);
      } else {
        _showMessage('No se pudo actualizar permisos');
      }
    } catch (e) {
      _showMessage(_extractErrorMessage(e));
    } finally {
      setState(() => _permisosSaving = false);
    }
  }

  Widget _buildPermisosTab() {
    final u = _seleccionado;
    if (u == null) {
      return const Center(
        child: Text('Selecciona un usuario para editar permisos'),
      );
    }

    final query = _searchPermisosQuery.toLowerCase();

    // Filtramos los módulos. Un módulo se muestra si:
    // 1. Su nombre (label) coincide con la búsqueda.
    // 2. O alguna de sus acciones coincide con la búsqueda.
    final modulosFiltrados = _modulosMvp.where((modulo) {
      if (query.isEmpty) return true;
      final label = (_modulosLabels[modulo] ?? modulo).toLowerCase();
      if (label.contains(query)) return true;

      final accionesTotales = _accionesParaModulo(modulo);
      return accionesTotales.any((accion) => accion.toLowerCase().contains(query));
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const ValueKey('perm_btn_save'),
                onPressed:
                    (_permisosSaving ||
                            !PermissionStore.instance.can(
                              'usuarios',
                              'actualizar',
                            ))
                        ? null
                        : _guardarPermisosUsuario,
                icon: const Icon(Icons.save),
                label:
                    _permisosSaving
                        ? const Text('Guardando...')
                        : const Text('Guardar cambios'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('perm_btn_reload'),
                onPressed:
                    _permisosLoading
                        ? null
                        : () {
                          _searchPermisosController.clear();
                          setState(() => _searchPermisosQuery = '');
                          _cargarPermisosUsuario(u.id);
                        },
                icon: const Icon(Icons.refresh),
                label:
                    _permisosLoading
                        ? const Text('Cargando...')
                        : const Text('Recargar'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('perm_btn_select_all'),
                onPressed:
                    _permisosLoading
                        ? null
                        : () => _toggleTodosLosModulos(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Marcar todo'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('perm_btn_deselect_all'),
                onPressed:
                    _permisosLoading
                        ? null
                        : () => _toggleTodosLosModulos(false),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Desmarcar todo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buscador Superior de Permisos
          TextField(
            controller: _searchPermisosController,
            decoration: InputDecoration(
              labelText: 'Buscar módulo o permiso',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              suffixIcon: _searchPermisosQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchPermisosController.clear();
                        setState(() => _searchPermisosQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _searchPermisosQuery = val);
            },
          ),
          const SizedBox(height: 12),
          if (_permisosLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            )),
          if (!_permisosLoading && modulosFiltrados.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No se encontraron módulos o permisos que coincidan con la búsqueda.'),
              ),
            ),
          if (!_permisosLoading && modulosFiltrados.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: modulosFiltrados.length,
                itemBuilder: (context, index) {
                  final modulo = modulosFiltrados[index];
                  final accionesSet = _permisosEdit[modulo] ?? <String>{};
                  final accionesTotales = _accionesParaModulo(modulo);
                  final puedeEditar = PermissionStore.instance.can(
                    'usuarios',
                    'actualizar',
                  );

                  // Filtrar las acciones internas del módulo si hay búsqueda
                  final accionesRenderizar = query.isEmpty 
                    ? accionesTotales 
                    : accionesTotales.where((a) => 
                        a.toLowerCase().contains(query) || 
                        (_modulosLabels[modulo] ?? modulo).toLowerCase().contains(query)
                      ).toList();

                  // Estado del Checkbox (tristate)
                  bool? checkboxState;
                  if (accionesSet.isEmpty) {
                    checkboxState = false;
                  } else if (accionesSet.length == accionesTotales.length) {
                    checkboxState = true;
                  } else {
                    checkboxState = null; // Indeterminado
                  }

                  return Card(
                    key: ValueKey('perm_card_$modulo'),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent, // Quitar línea al expandir
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: query.isNotEmpty, // Se expande automáticamente si hay búsqueda
                        title: Text(
                          _modulosLabels[modulo] ??
                              (modulo[0].toUpperCase() + modulo.substring(1)),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${accionesSet.length}/${accionesTotales.length} permitidas',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (puedeEditar)
                              Tooltip(
                                message: checkboxState == true ? 'Limpiar todo' : 'Seleccionar todo',
                                child: Checkbox(
                                  tristate: true,
                                  value: checkboxState,
                                  onChanged: (bool? value) {
                                    // Si el nuevo valor es true, seleccionamos todo.
                                    // Si es false o null (transición desde true), limpiamos todo.
                                    final bool seleccionar = value == true;
                                    _toggleTodoModulo(modulo, seleccionar);
                                  },
                                ),
                              ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: accionesRenderizar.map((accion) {
                              final checked = accionesSet.contains(accion);
                              return FilterChip(
                                selected: checked,
                                showCheckmark: true,
                                label: Text(
                                  accion,
                                  style: TextStyle(
                                    fontWeight: checked ? FontWeight.w600 : FontWeight.normal,
                                    color: checked 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Colors.grey.shade700,
                                  ),
                                ),
                                backgroundColor: Colors.grey.shade50, // Tenue cuando no activo
                                selectedColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: checked
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                onSelected: puedeEditar
                                    ? (bool value) => _toggleAccion(modulo, accion, value)
                                    : null,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _toggleTodoModulo(String modulo, bool seleccionar) {
    if (!PermissionStore.instance.can('usuarios', 'actualizar')) return;
    setState(() {
      final acciones = _accionesParaModulo(modulo);
      _permisosEdit[modulo] = seleccionar ? acciones.toSet() : <String>{};
    });
  }

  void _toggleTodosLosModulos(bool seleccionar) {
    if (!PermissionStore.instance.can('usuarios', 'actualizar')) return;
    setState(() {
      if (seleccionar) {
        for (final m in _modulosMvp) {
          final acciones = _accionesParaModulo(m);
          _permisosEdit[m] = acciones.toSet();
        }
      } else {
        _permisosEdit.clear();
      }
    });
  }

  // Widget de chip simple para estado/rol
  Widget _Chip({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }

  Future<void> _abrirDialogoCrearUsuario() async {
    if (!PermissionStore.instance.can('usuarios', 'crear')) {
      _showMessage('No tienes permiso para crear usuarios');
      return;
    }
    final formKey = GlobalKey<FormState>();
    final usuarioCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final identificacionCtrl = TextEditingController();
    String tipoDoc = 'Cedula';
    final passwordCtrl = TextEditingController();
    String rol = _safeRol(null);
    String estado = 'activo';
    int? localDepartamentoId;
    int? localPosicionId;
    int? localEspecialidadId;
    int? funcionarioId;
    bool localEsAuditor = false;
    bool localCanEditClosedOps = false;
    bool obscure = true;

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('Crear usuario'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: SizedBox(
                      width: 480,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: usuarioCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                            ),
                            validator:
                                (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Usuario requerido'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: correoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Correo requerido';
                              }
                              // Validación simple de email
                              if (!v.contains('@')) {
                                return 'Email inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: telefonoCtrl,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Teléfono',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de documento',
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: tipoDoc,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Cedula',
                                          child: Text('Cedula'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Tarjeta identidad',
                                          child: Text('Tarjeta identidad'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Pasaporte',
                                          child: Text('Pasaporte'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'NIT',
                                          child: Text('NIT'),
                                        ),
                                      ],
                                      onChanged:
                                          (v) => setLocal(
                                            () => tipoDoc = v ?? 'Cedula',
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: identificacionCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'No. Identificación / NIT',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Identificación requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          // Fechas: nacimiento y contratación
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha nacimiento',
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _fechaNacimiento == null
                                              ? '—'
                                              : _formatDate(_fechaNacimiento!),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.date_range),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _fechaNacimiento ??
                                                DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(
                                              () => _fechaNacimiento = picked,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha contratación',
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _fechaContratacion == null
                                              ? '—'
                                              : _formatDate(
                                                _fechaContratacion!,
                                              ),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.date_range),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _fechaContratacion ??
                                                DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(
                                              () => _fechaContratacion = picked,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordCtrl,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed:
                                    () => setLocal(() => obscure = !obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Contraseña requerida';
                              }
                              if (v.trim().length < 8) {
                                return 'Min. 8 caracteres';
                              }
                              return null;
                            },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _safeRol(rol),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'colaborador',
                                      child: Text('Colaborador'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'administrador',
                                      child: Text('Administrador'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cliente',
                                      child: Text('Cliente'),
                                    ),
                                  ],
                                  onChanged:
                                      (v) => setLocal(
                                        () => rol = v ?? 'colaborador',
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Rol',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Estado'),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Activo'),
                                          selected: estado == 'activo',
                                          onSelected:
                                              (_) => setLocal(
                                                () => estado = 'activo',
                                              ),
                                        ),
                                        ChoiceChip(
                                          label: const Text('Inactivo'),
                                          selected: estado == 'inactivo',
                                          onSelected:
                                              (_) => setLocal(
                                                () => estado = 'inactivo',
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: funcionarioId?.toString(),
                            decoration: const InputDecoration(
                              labelText: 'ID Funcionario (Vínculo Cliente)',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged:
                                (v) => setLocal(
                                  () => funcionarioId = int.tryParse(v),
                                ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Auditor Financiero'),
                            value: localEsAuditor,
                            activeThumbColor: Colors.blue,
                            onChanged:
                                (val) => setLocal(
                                  () => localEsAuditor = val,
                                ),
                          ),
                          SwitchListTile(
                            title: const Text('Editar Operaciones Cerradas'),
                            value: localCanEditClosedOps,
                            activeThumbColor: Colors.blue,
                            onChanged:
                                (val) => setLocal(
                                  () => localCanEditClosedOps = val,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Crear'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final nuevo = await AdminUserService.crearUsuario(
                          usuario: usuarioCtrl.text.trim(),
                          password: passwordCtrl.text.trim(),
                          correo:
                              correoCtrl.text.trim().isEmpty
                                  ? null
                                  : correoCtrl.text.trim(),
                          rol: rol,
                          estado: estado,
                          telefono:
                              telefonoCtrl.text.trim().isEmpty
                                  ? null
                                  : telefonoCtrl.text.trim(),
                          tipoIdentificacion:
                              tipoDoc.trim().isEmpty ? null : tipoDoc.trim(),
                          numeroIdentificacion:
                              identificacionCtrl.text.trim().isEmpty
                                  ? null
                                  : identificacionCtrl.text.trim(),
                          esAuditor: localEsAuditor,
                          canEditClosedOps: localCanEditClosedOps,
                          // opcionales en creación rápida (se pueden completar luego)
                          direccion:
                              _direccionCtrl.text.trim().isEmpty
                                  ? null
                                  : _direccionCtrl.text.trim(),
                          contactoEmergenciaNombre:
                              _emergenciaNombreCtrl.text.trim().isEmpty
                                  ? null
                                  : _emergenciaNombreCtrl.text.trim(),
                          contactoEmergenciaTelefono:
                              _emergenciaTelefonoCtrl.text.trim().isEmpty
                                  ? null
                                  : _emergenciaTelefonoCtrl.text.trim(),
                          fechaNacimiento:
                              _fechaNacimiento != null
                                  ? _formatDate(_fechaNacimiento!)
                                  : null,
                          fechaContratacion:
                              _fechaContratacion != null
                                  ? _formatDate(_fechaContratacion!)
                                  : null,
                          idDepartamento: _departamentoId,
                          idPosicion: _posicionId,
                          idEspecialidad: localEspecialidadId,
                          salario:
                              _salarioCtrl.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(
                                    _salarioCtrl.text.trim().replaceAll(
                                      '.',
                                      '',
                                    ),
                                  ),
                          funcionarioId: funcionarioId,
                        );
                        setState(() => _usuarios = [nuevo, ..._usuarios]);
                        if (mounted) {
                          _showMessage('Usuario creado', success: true);
                        }
                        Navigator.pop(ctx);
                      } catch (e) {
                        _showMessage(_extractErrorMessage(e));
                      }
                    },
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _abrirDialogoEditarUsuario(AdminUser u) async {
    final formKey = GlobalKey<FormState>();
    final usuarioCtrl = TextEditingController(text: u.usuario);
    final correoCtrl = TextEditingController(text: u.correo ?? '');
    String rol = _safeRol(u.rol);
    String estado = u.estado;
    bool localEsAuditor = u.esAuditor;
    bool localCanEditClosedOps = u.canEditClosedOps;
    int? funcionarioId = u.funcionarioId;

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: Text('Editar: ${u.usuario}'),
                content: Form(
                  key: formKey,
                  child: SizedBox(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: usuarioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Usuario requerido'
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: correoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _safeRol(rol),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'colaborador',
                                    child: Text('Colaborador'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'administrador',
                                    child: Text('Administrador'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cliente',
                                    child: Text('Cliente'),
                                  ),
                                ],
                                onChanged:
                                    (v) => setLocal(
                                      () => rol = v ?? 'colaborador',
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Rol',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Estado'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Activo'),
                                        selected: estado == 'activo',
                                        onSelected:
                                            (_) => setLocal(
                                              () => estado = 'activo',
                                            ),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Inactivo'),
                                        selected: estado == 'inactivo',
                                        onSelected:
                                            (_) => setLocal(
                                              () => estado = 'inactivo',
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: funcionarioId?.toString(),
                          decoration: const InputDecoration(
                            labelText: 'ID Funcionario (Vínculo Cliente)',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged:
                              (v) => setLocal(
                                () => funcionarioId = int.tryParse(v),
                              ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Perfil de Auditor'),
                          subtitle: const Text(
                            'Permite auditar servicios antes de legalización',
                          ),
                          value: localEsAuditor,
                          activeThumbColor: Colors.blue,
                          onChanged: (v) => setLocal(() => localEsAuditor = v),
                        ),
                        SwitchListTile(
                          title: const Text('Editar Operaciones Cerradas'),
                          subtitle: const Text(
                            'Permite editar o eliminar operaciones que ya han sido finalizadas.',
                          ),
                          value: localCanEditClosedOps,
                          activeThumbColor: Colors.blue,
                          onChanged: (v) => setLocal(() => localCanEditClosedOps = v),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final ok = await AdminUserService.actualizarUsuario(
                          id: u.id,
                          usuario: usuarioCtrl.text.trim(),
                          correo:
                              correoCtrl.text.trim().isEmpty
                                  ? null
                                  : correoCtrl.text.trim(),
                          rol: rol,
                          estado: estado,
                          funcionarioId: funcionarioId,
                          esAuditor: localEsAuditor,
                          canEditClosedOps: localCanEditClosedOps,
                        );
                        if (ok) {
                          setState(() {
                            final i = _usuarios.indexWhere((x) => x.id == u.id);
                            if (i >= 0) {
                              _usuarios[i] = AdminUser(
                                id: u.id,
                                usuario: usuarioCtrl.text.trim(),
                                correo:
                                    correoCtrl.text.trim().isEmpty
                                        ? null
                                        : correoCtrl.text.trim(),
                                rol: rol,
                                estado: estado,
                                esAuditor: localEsAuditor,
                                canEditClosedOps: localCanEditClosedOps,
                              );
                            }
                          });
                          if (mounted) {
                            _showMessage('Usuario actualizado', success: true);
                          }
                          Navigator.pop(ctx);
                        } else {
                          _showMessage('No fue posible actualizar');
                        }
                      } catch (e) {
                        _showMessage(_extractErrorMessage(e));
                      }
                    },
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _confirmarEliminarUsuario(AdminUser u) async {
    if (!PermissionStore.instance.can('usuarios', 'eliminar')) {
      _showMessage('No tienes permiso para eliminar usuarios');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Eliminar usuario'),
            content: Text('¿Seguro que quieres eliminar "${u.usuario}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
    if (ok == true) {
      try {
        final resp = await AdminUserService.eliminarUsuario(
          u.id,
          permanente: true,
        );
        if (resp) {
          try {
            await AdminUserService.invalidateCache();
          } catch (_) {}
          setState(() {
            _usuarios.removeWhere((x) => x.id == u.id);
            if (_seleccionado?.id == u.id) {
              _seleccionado = null;
            }
          });
          if (mounted) {
            _showMessage('Usuario eliminado', success: true);
          }
        } else {
          _showMessage('No fue posible eliminar');
        }
      } catch (e) {
        _showMessage(_extractErrorMessage(e));
      }
    }
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Limpiar todo lo que no sea dígitos
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Si no hay nada después de limpiar, devolver vacío
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parsear el valor
    double value = double.parse(newText);

    // Formatear con puntos de miles (locale español o similar)
    // Usamos NumberFormat.currency pero quitamos el símbolo y decimales 0
    final formatter = NumberFormat.decimalPattern('es_CO');
    String newString = formatter.format(value);

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
