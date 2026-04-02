// lib/pages/home/controllers/home_controller.dart

import 'package:flutter/material.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../models/navigation_item_model.dart';
import '../models/user_session_model.dart';
import '../services/navigation_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:infoapp/core/version/app_version.dart';

class HomeController extends ChangeNotifier {
  final NavigationService _navigationService = NavigationService();
  late UserSession _userSession;
  String _vistaActual = 'Servicios';
  bool _mostrarSubmenu = false;
  bool _isSidebarCollapsed = true;
  String _appVersion = '1.0.0';

  // Getters originales
  String get vistaActual => _vistaActual;
  bool get mostrarSubmenu => _mostrarSubmenu;
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  String get appVersion => _appVersion;
  UserSession get userSession => _userSession;
  bool get esAdmin => _userSession.rol.toLowerCase() == 'administrador';
  bool get esColaborador => _userSession.rol.toLowerCase() == 'colaborador';

  // Lista de elementos de navegación
  List<NavigationItem> get menuItems =>
      _navigationService.getMenuItems(esAdmin);

  HomeController({required String nombreUsuario, required String rol}) {
    _userSession = UserSession(nombreUsuario: nombreUsuario, rol: rol);

    // Establecer vista inicial según rol
    if (rol.toLowerCase() == 'cliente') {
      _vistaActual = 'Inspecciones';
    } else {
      _vistaActual = 'Servicios';
    }

    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      if (kIsWeb) {
        // En Web, PackageInfo puede retornar 'undefined' — usamos la constante compilada
        _appVersion = kAppVersion;
      } else {
        final packageInfo = await PackageInfo.fromPlatform();
        _appVersion = packageInfo.version;
      }
      notifyListeners();
    } catch (e) {
      _appVersion = kAppVersion; // Fallback seguro
      debugPrint('Error cargando versión: $e');
      notifyListeners();
    }
  }

  // Métodos originales
  void cambiarVista(String nuevaVista) {
    final store = PermissionStore.instance;
    bool permitido = true;
    switch (nuevaVista) {
      case 'Servicios':
        permitido =
            store.can('servicios', 'listar') || store.can('servicios', 'ver');
        break;
      case 'Asistente IA':
        permitido = true; // Disponible para todos por ahora
        break;
      case 'Configuración IA':
        permitido = true;
        break;
      case 'Inventario':
        permitido =
            store.can('inventario', 'listar') || store.can('inventario', 'ver');
        break;
      case 'Registro de Activos':
        permitido =
            store.can('equipos', 'listar') || store.can('equipos', 'ver');
        break;
      case 'Usuarios':
        permitido =
            store.can('usuarios', 'listar') || store.can('usuarios', 'ver');
        break;
      case 'Plantillas':
        permitido =
            store.can('plantillas', 'listar') || store.can('plantillas', 'ver');
        break;
      case 'Dashboard':
        permitido = store.can('dashboard', 'ver');
        break;
      case 'Actividades':
        permitido =
            store.can('servicios_actividades', 'listar') ||
            store.can('servicios_actividades', 'ver');
        break;
      case 'Gestión Financiera':
        permitido =
            store.can('gestion_financiera', 'listar') ||
            store.can('gestion_financiera', 'ver');
        break;
      default:
        permitido = true;
    }
    // 🔒 BLOQUEO DE NAVEGACIÓN POR ROL (COLABORADOR)
    if (_userSession.rol.toLowerCase() == 'colaborador') {
      const permittedColaborador = [
        'Servicios',
        'Inspecciones',
        'Asistente IA',
        'Actividades',
        'Menú',
      ];
      if (!permittedColaborador.contains(nuevaVista)) {
        permitido = false;
      }
    }

    if (!permitido) {
      _vistaActual =
          _userSession.rol.toLowerCase() == 'cliente'
              ? 'Inspecciones'
              : 'Servicios';
      _mostrarSubmenu = false;
      notifyListeners();
      return;
    }

    _vistaActual = nuevaVista;
    _mostrarSubmenu = false;
    notifyListeners();
  }

  void toggleSubmenu() {
    _mostrarSubmenu = !_mostrarSubmenu;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  bool isAjustesSelected() {
    return _vistaActual == 'Campos adicionales' ||
        _vistaActual == 'Estados y transiciones' ||
        _vistaActual == 'Branding' ||
        _vistaActual == 'Configuración Facturación';
  }

  Widget obtenerVista() {
    //     print('🖼️ Obteniendo vista para: $_vistaActual'); // DEBUG
    return _navigationService.getViewForRoute(
      _vistaActual,
      _userSession.nombreUsuario,
    );
  }

  // === MÉTODOS PARA INVENTARIO ===

  /// Verifica si hay notificaciones de inventario pendientes
  bool tieneNotificacionesInventario() {
    //     print('🔔 Verificando notificaciones de inventario...'); // DEBUG
    try {
      final alertas = obtenerNotificacionesInventario();
      //       print('   Alertas encontradas: ${alertas.length}'); // DEBUG
      return alertas.isNotEmpty;
    } catch (e) {
      //       print('❌ Error al verificar notificaciones: $e'); // DEBUG
      return false;
    }
  }

  /// Obtiene el conteo total de notificaciones de inventario
  int conteoNotificacionesInventario() {
    try {
      final alertas = obtenerNotificacionesInventario();
      final conteo = alertas.fold<int>(
        0,
        (sum, alerta) => sum + (alerta['cantidad'] as int),
      );
      //       print('📊 Conteo de notificaciones: $conteo'); // DEBUG
      return conteo;
    } catch (e) {
      //       print('❌ Error al contar notificaciones: $e'); // DEBUG
      return 0;
    }
  }

  /// Obtiene las notificaciones detalladas de inventario
  List<Map<String, dynamic>> obtenerNotificacionesInventario() {
    // Datos temporales hasta que conectes con el NavigationService actualizado
    //     print('📋 Generando notificaciones de inventario temporales...'); // DEBUG
    return [
      {
        'titulo': 'Stock Bajo',
        'mensaje': 'Productos necesitan reabastecimiento',
        'cantidad': 12,
        'icono': Icons.warning,
        'tipo': 'warning',
      },
      {
        'titulo': 'Sin Stock',
        'mensaje': 'Productos sin existencias',
        'cantidad': 3,
        'icono': Icons.error,
        'tipo': 'error',
      },
    ];
  }

  /// Obtiene las estadísticas del inventario para mostrar en dashboard
  Map<String, dynamic> obtenerEstadisticasInventario() {
    return {
      'total_items': 450,
      'low_stock_items': 12,
      'out_of_stock_items': 3,
      'total_value': 125000.50,
      'categories': 15,
      'suppliers': 8,
    };
  }

  /// Verifica si el usuario tiene acceso al módulo de inventario
  bool tieneAccesoInventario() {
    //     print('🔐 Verificando acceso a inventario...'); // DEBUG
    // Por ahora, todos los usuarios tienen acceso
    return true;
  }

  /// Navega directamente al inventario desde una notificación
  void navegarAInventario() {
    cambiarVista('Inventario');
  }

  // ===================================================
  // MÉTODOS PARA STAFF/PERSONAL - NUEVOS
  // ===================================================

  /// Verifica si hay notificaciones de staff/personal pendientes
  bool tieneNotificacionesStaff() {
    //     print('👥 Verificando notificaciones de personal...'); // DEBUG
    try {
      final alertas = obtenerNotificacionesStaff();
      //       print('   Alertas de personal encontradas: ${alertas.length}'); // DEBUG
      return alertas.isNotEmpty;
    } catch (e) {
      //       print('❌ Error al verificar notificaciones de personal: $e'); // DEBUG
      return false;
    }
  }

  /// Obtiene el conteo total de notificaciones de staff
  int conteoNotificacionesStaff() {
    try {
      final alertas = obtenerNotificacionesStaff();
      final conteo = alertas.fold<int>(
        0,
        (sum, alerta) => sum + (alerta['cantidad'] as int),
      );
      //       print('📊 Conteo de notificaciones de personal: $conteo'); // DEBUG
      return conteo;
    } catch (e) {
      //       print('❌ Error al contar notificaciones de personal: $e'); // DEBUG
      return 0;
    }
  }

  /// Obtiene las notificaciones detalladas de staff/personal
  List<Map<String, dynamic>> obtenerNotificacionesStaff() {
    // Datos temporales - cuando conectes con API real, reemplaza esto
    //     print('📋 Generando notificaciones de personal temporales...'); // DEBUG
    return [
      {
        'titulo': 'Empleados Nuevos',
        'mensaje': 'Empleados registrados en las últimas 24h',
        'cantidad': 3,
        'icono': Icons.person_add,
        'tipo': 'info',
      },
      {
        'titulo': 'Documentos Vencidos',
        'mensaje': 'Empleados con documentos por vencer',
        'cantidad': 2,
        'icono': Icons.description,
        'tipo': 'warning',
      },
      {
        'titulo': 'Cumpleaños',
        'mensaje': 'Empleados que cumplen años esta semana',
        'cantidad': 1,
        'icono': Icons.cake,
        'tipo': 'celebration',
      },
    ];
  }

  /// Obtiene las estadísticas del personal para mostrar en dashboard
  Map<String, dynamic> obtenerEstadisticasStaff() {
    return {
      'total_empleados': 145,
      'empleados_activos': 142,
      'empleados_inactivos': 3,
      'nuevos_este_mes': 8,
      'departamentos': 6,
      'cargos_diferentes': 18,
      'empleados_con_foto': 98,
      'completitud_promedio': 87.5, // Porcentaje de completitud de perfiles
    };
  }

  /// Verifica si el usuario tiene acceso al módulo de personal
  bool tieneAccesoStaff() {
    //     print('🔐 Verificando acceso a personal...'); // DEBUG
    // Lógica de permisos - por ahora todos tienen acceso
    // Podrías agregar lógica como: solo admin y RRHH
    return esAdmin || _userSession.rol.toLowerCase().contains('rrhh');
  }

  /// Navega directamente al módulo de personal desde una notificación
  void navegarAPersonal() {
    cambiarVista('Personal');
  }

  /// Obtiene el badge count para mostrar en el drawer
  int? getBadgeCountForItem(String itemId) {
    // Ocultar badge para Inventario
    if (itemId == 'Inventario') {
      return null;
    }

    // ✅ NUEVO: Badge para Personal/Staff
    if (itemId == 'Personal' || itemId == 'Staff') {
      final alertas = obtenerNotificacionesStaff();
      if (alertas.isNotEmpty) {
        return alertas.fold<int>(
          0,
          (sum, alerta) => sum + (alerta['cantidad'] as int),
        );
      }
    }

    return null;
  }

  /// Obtiene alertas específicas por tipo para el personal
  List<Map<String, dynamic>> obtenerAlertasStaffPorTipo(String tipo) {
    final todasLasAlertas = obtenerNotificacionesStaff();
    return todasLasAlertas.where((alerta) => alerta['tipo'] == tipo).toList();
  }

  /// Marca una notificación de staff como leída (para implementar después)
  void marcarNotificacionStaffComoLeida(String notificacionId) {
    //     print('✅ Marcando notificación de personal como leída: $notificacionId');
    // TODO: Implementar cuando tengas backend conectado
    notifyListeners();
  }

  /// Obtiene el estado de salud general del departamento de RRHH
  Map<String, dynamic> obtenerSaludRRHH() {
    final stats = obtenerEstadisticasStaff();
    final alertas = obtenerNotificacionesStaff();

    return {
      'estado_general': 'bueno', // bueno, regular, critico
      'porcentaje_activos':
          (stats['empleados_activos'] / stats['total_empleados'] * 100),
      'alertas_criticas': alertas.where((a) => a['tipo'] == 'error').length,
      'alertas_warning': alertas.where((a) => a['tipo'] == 'warning').length,
      'tendencia': 'estable', // creciendo, estable, decreciendo
    };
  }
}
