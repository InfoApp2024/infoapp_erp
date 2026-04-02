// lib/pages/home/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import '../controllers/home_controller.dart';
import 'drawer_menu_item.dart';
import '../models/navigation_item_model.dart';
import 'package:infoapp/pages/staff/widgets/staff_widgets.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/branding/branding_service.dart';

class AppDrawer extends StatelessWidget {
  static Map<String, bool>? _workflowAvailabilityCache;
  final HomeController controller;
  final String nombreUsuario;
  final String rol;
  final String? photoUrl;
  final bool isLoggingOut;
  final VoidCallback onLogout;
  final Function(String) onNavigationChanged;
  final bool isSidebar; // Nuevo: para saber si actúa como sidebar persistente

  Color get primaryColor => BrandingService().primaryColor;

  AppDrawer({
    super.key,
    required this.controller,
    required this.nombreUsuario,
    required this.rol,
    this.photoUrl,
    required this.isLoggingOut,
    required this.onLogout,
    required this.onNavigationChanged,
    this.isSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCollapsed = isSidebar && controller.isSidebarCollapsed;
    final branding = BrandingService();

    return Container(
      width: isSidebar ? (isCollapsed ? 80 : 250) : null,
      decoration:
          isSidebar
              ? BoxDecoration(
                gradient: branding.primaryGradient,
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              )
              : null,
      child: Material(
        color: isSidebar ? Colors.transparent : null,
        elevation: isSidebar ? 0 : 16,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildDrawerHeader(isCollapsed),
                  _buildMainSection(context, isCollapsed),
                  if (controller.esAdmin) ...[
                    const Divider(color: Colors.white24),
                    _buildAdminSection(context, isCollapsed),
                  ],
                  // Agregamos el logout y footer al final del ListView para evitar overflow vertical en pantallas pequeñas
                  if (kIsWeb && isSidebar) ...[
                    const Divider(color: Colors.white24),
                    _buildLogoutSection(isCollapsed),
                    if (!isCollapsed) _buildFooter(),
                  ],
                ],
              ),
            ),
            // Solo mostrar fuera del ListView si no es sidebar o si hay espacio garantizado
            if (!isSidebar) ...[
              const Divider(color: Colors.white24),
              _buildLogoutSection(isCollapsed),
              _buildFooter(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(bool isCollapsed) {
    final branding = BrandingService();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: child),
      child:
          isCollapsed
              ? Container(
                key: const ValueKey('collapsed'),
                height: 80, // Reducido para acercar el avatar al menú superior
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: branding.primaryGradient),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2.5, // Borde un poco más grueso como en la imagen
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: StaffAvatar(
                    photoUrl: photoUrl,
                    initials:
                        nombreUsuario.isNotEmpty
                            ? nombreUsuario[0].toUpperCase()
                            : 'U',
                    radius: 22, // Ligeramente más grande
                    backgroundColor: Colors.white.withOpacity(0.2),
                    textColor: Colors.white,
                  ),
                ),
              )
              : Container(
                key: const ValueKey('expanded'),
                padding: const EdgeInsets.all(20),
                height: 180,
                decoration: BoxDecoration(
                  gradient: branding.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: StaffAvatar(
                            photoUrl: photoUrl,
                            initials:
                                nombreUsuario.isNotEmpty
                                    ? nombreUsuario[0].toUpperCase()
                                    : 'U',
                            radius: 30, // Más grande como pidió el usuario
                            backgroundColor: Colors.white.withOpacity(0.2),
                            textColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nombreUsuario,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rol.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Badge de vista actual más integrado y elegante
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              controller.vistaActual,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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

  // ✅ AGREGAMOS CONTEXT COMO PARÁMETRO
  Widget _buildMainSection(BuildContext context, bool isCollapsed) {
    final allItems = NavigationItems.getMainItems();
    List<NavigationItem> items = allItems;

    if (!kIsWeb) {
      const mobileWhitelist = [
        'Servicios',
        'Inventario',
        'Inspecciones',
        'Clientes',
        'Geocercas',
        'Registro de Activos',
        'Actividades',
        'Usuarios',
      ];
      items = items.where((i) => mobileWhitelist.contains(i.id)).toList();
    }

    // 🔒 Restricciones por Rol:
    if (rol.toLowerCase() == 'cliente') {
      // Cliente: Solo Inspecciones
      items = items.where((i) => i.id == 'Inspecciones').toList();
    } else if (rol.toLowerCase() == 'colaborador') {
      // Colaborador: Solo Servicios e Inspecciones
      items =
          items
              .where((i) => i.id == 'Servicios' || i.id == 'Inspecciones')
              .toList();
    } else {
      // Otros: Según permisos establecidos
      items = items.where(_hasPermissionForItem).toList();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Column(
        key: ValueKey('main_section_$isCollapsed'),
        children: [
          if (!isCollapsed) _buildSectionHeader('Principal'),
          // DASHBOARD CON PERMISOS (Solo Web y Roles No Restringidos)
          if (kIsWeb &&
              PermissionStore.instance.can('dashboard', 'ver') &&
              rol.toLowerCase() != 'colaborador' &&
              rol.toLowerCase() != 'cliente')
            _buildSimpleMenuItem(
              context: context,
              id: 'Dashboard',
              title: 'Dashboard',
              icon: PhosphorIcons.squaresFour(),
              isCollapsed: isCollapsed,
            ),
          ...items.map(
            (item) => _buildMenuItemWithBadge(context, item, isCollapsed),
          ),
        ],
      ),
    );
  }

  bool _hasPermissionForItem(NavigationItem item) {
    final store = PermissionStore.instance;
    switch (item.id) {
      case 'Servicios':
        return store.can('servicios', 'listar') ||
            store.can('servicios', 'ver');
      case 'Inventario':
        return store.can('inventario', 'listar') ||
            store.can('inventario', 'ver');
      case 'Inspecciones':
        return store.can('inspecciones', 'listar') ||
            store.can('inspecciones', 'ver');
      case 'Registro de Activos':
        return store.can('equipos', 'listar') || store.can('equipos', 'ver');
      case 'Usuarios':
        return store.can('usuarios', 'listar') || store.can('usuarios', 'ver');
      case 'Plantillas':
        return store.can('plantillas', 'listar') ||
            store.can('plantillas', 'ver');
      case 'Clientes':
        return store.can('clientes', 'listar') || store.can('clientes', 'ver');
      case 'Geocercas':
        return store.can('geocerca', 'listar') || store.can('geocerca', 'ver');
      case 'Actividades':
        return store.can('servicios_actividades', 'listar') ||
            store.can('servicios_actividades', 'ver');
      case 'Gestión Financiera':
        return store.can('gestion_financiera', 'listar') ||
            store.can('gestion_financiera', 'ver');
      default:
        // Check admin modules
        if (item.id == 'Configuración IA') {
          return store.can('chatbot', 'ver') ||
              store.can('chatbot', 'listar') ||
              store.can('chatbot', 'admin') ||
              store.can('ia', 'ver');
        }
        if (item.id == 'Campos adicionales') {
          return store.can('campos_adicionales', 'ver') ||
              store.can('campos_adicionales', 'listar') ||
              store.can('campos_adicionales', 'crear');
        }
        if (item.id == 'Estados y transiciones') {
          return store.can('estados_transiciones', 'ver') ||
              store.can('estados_transiciones', 'listar') ||
              store.can('estados_transiciones', 'admin');
        }
        if (item.id == 'Branding') {
          return store.can('branding', 'ver') ||
              store.can('branding', 'listar') ||
              store.can('branding', 'admin');
        }
        if (item.id == 'Configuración Facturación') {
          return store.can('contabilidad', 'admin') || controller.esAdmin;
        }

        return true;
    }
  }

  Widget _buildSimpleMenuItem({
    required BuildContext context,
    required String id,
    required String title,
    required IconData icon,
    required bool isCollapsed,
  }) {
    final isSelected = controller.vistaActual == id;
    final color =
        isSelected
            ? (isSidebar ? Colors.white : primaryColor)
            : (isSidebar ? Colors.white70 : Colors.grey.shade600);

    if (isCollapsed) {
      return Tooltip(
        message: title,
        child: InkWell(
          onTap: () => onNavigationChanged(id),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Icon(icon, color: color),
          ),
        ),
      );
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: isSidebar ? Colors.white : null),
      ),
      selected: isSelected,
      selectedTileColor:
          isSidebar
              ? Colors.white.withOpacity(0.1)
              : primaryColor.withOpacity(0.1),
      onTap: () {
        onNavigationChanged(id);
        if (!isSidebar) Navigator.pop(context);
      },
    );
  }

  // ✅ MÉTODO CORREGIDO CON CONTEXT COMO PARÁMETRO
  Widget _buildMenuItemWithBadge(
    BuildContext context,
    NavigationItem item,
    bool isCollapsed,
  ) {
    final badgeCount = controller.getBadgeCountForItem(item.id);
    final isSelected = controller.vistaActual == item.id;
    final color =
        isSelected
            ? (isSidebar ? Colors.white : primaryColor)
            : (isSidebar ? Colors.white70 : Colors.grey.shade600);

    if (isCollapsed) {
      return Tooltip(
        message: item.title,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InkWell(
              onTap: () => onNavigationChanged(item.id),
              child: Container(
                height: 50,
                width: double.infinity,
                alignment: Alignment.center,
                child: Icon(item.icon, color: color),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                right: 20,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getBadgeColor(item.id),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (badgeCount != null && badgeCount > 0) {
      return ListTile(
        leading: Icon(item.icon, color: color),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(color: isSidebar ? Colors.white : null),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getBadgeColor(item.id),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        selected: isSelected,
        selectedTileColor:
            isSidebar
                ? Colors.white.withOpacity(0.1)
                : primaryColor.withOpacity(0.1),
        onTap: () {
          onNavigationChanged(item.id);
          if (!isSidebar) Navigator.pop(context);
        },
      );
    }

    // Si no hay badge, usar el widget normal
    return DrawerMenuItem(
      item: item,
      controller: controller,
      primaryColor: isSidebar ? Colors.white : primaryColor,
      onNavigationChanged: onNavigationChanged,
      isSidebar: isSidebar,
    );
  }

  // ✅ MÉTODO PARA OBTENER COLOR DEL BADGE
  Color _getBadgeColor(String itemId) {
    switch (itemId) {
      case 'Inventario':
        return Colors.red;
      case 'Personal':
        return Colors.orange;
      default:
        return primaryColor;
    }
  }

  Future<Map<String, bool>> _loadWorkflowAvailability() async {
    final base = ServerConfig.instance.apiRoot();
    if (_workflowAvailabilityCache != null) {
      return _workflowAvailabilityCache!;
    }

    final token = await AuthService.getBearerToken();
    final Map<String, String> headers = {
      if (token != null) 'Authorization': token,
      'Accept': 'application/json',
    };

    Future<bool> check(String moduloKey) async {
      try {
        // Corregir rutas: listar_estados y listar_transiciones están en /workflow/
        final estadosUrl = Uri.parse(
          '$base/workflow/listar_estados.php',
        ).replace(queryParameters: {'modulo': moduloKey});
        final transicionesUrl = Uri.parse(
          '$base/workflow/listar_transiciones.php',
        ).replace(queryParameters: {'modulo': moduloKey});

        final responses = await Future.wait([
          http.get(estadosUrl, headers: headers),
          http.get(transicionesUrl, headers: headers),
        ]);

        final estados = responses[0];
        // final transiciones = responses[1]; // No estrictamente necesaria si hay estados

        bool hasEstados = false;
        if (estados.statusCode == 200) {
          final body = estados.body.trim();
          hasEstados = body.contains('[') && !body.contains('[]');
        }

        // Si hay estados, permitimos ver el módulo aunque no haya transiciones aún
        return hasEstados;
      } catch (e) {
        debugPrint('⚠️ Error verificando workflow para $moduloKey: $e');
        return true; // Fallback a mostrar por defecto si falla la red
      }
    }

    final servicio = await check('servicio');
    final equipo = await check('equipo');
    final inspeccion = await check(
      'inspecciones',
    ); // Key correcta según ModuloEnum

    _workflowAvailabilityCache = {
      'servicio': servicio,
      'equipo': equipo,
      'inspeccion': inspeccion,
    };
    return _workflowAvailabilityCache!;
  }

  Widget _buildAdminSection(BuildContext context, bool isCollapsed) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    final adminItems =
        NavigationItems.getAdminItems().where(_hasPermissionForItem).toList();

    if (adminItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isCollapsed) {
      return PopupMenuButton<String>(
        tooltip: 'Ajustes',
        offset: const Offset(80, 0),
        icon: Icon(PhosphorIcons.gear(), color: Colors.white70),
        onSelected: (id) => onNavigationChanged(id),
        itemBuilder:
            (context) =>
                adminItems.map((item) {
                  return PopupMenuItem<String>(
                    value: item.id,
                    child: Row(
                      children: [
                        Icon(item.icon, color: primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Text(item.title),
                      ],
                    ),
                  );
                }).toList(),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Column(
        key: ValueKey('admin_section_$isCollapsed'),
        children: [
          _buildSectionHeader('Configuración'),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                PhosphorIcons.gear(),
                color: isSidebar ? Colors.white70 : null,
              ),
              title: Text(
                'Ajustes',
                style: TextStyle(color: isSidebar ? Colors.white : null),
              ),
              iconColor: isSidebar ? Colors.white : null,
              collapsedIconColor: isSidebar ? Colors.white70 : null,
              children:
                  adminItems
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: DrawerMenuItem(
                            item: item,
                            controller: controller,
                            primaryColor:
                                isSidebar ? Colors.white : primaryColor,
                            onNavigationChanged: onNavigationChanged,
                            isSidebar: isSidebar,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(bool isCollapsed) {
    if (isLoggingOut) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment:
              isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Cerrando sesión...',
                  style: TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: ListTile(
        key: ValueKey('logout_$isCollapsed'),
        leading: Icon(
          PhosphorIcons.signOut(),
          color: isSidebar ? Colors.white70 : Colors.red.shade600,
        ),
        title:
            isCollapsed
                ? null
                : Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: isSidebar ? Colors.white : Colors.red.shade600,
                  ),
                ),
        onTap: onLogout,
      ),
    );
  }

  Widget _buildSectionHeader(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSidebar ? Colors.white60 : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.buildings(), size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Sistema de Gestión v${controller.appVersion}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Desarrollado para optimizar tu negocio',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ CLASE ACTUALIZADA CON STAFF
class NavigationItems {
  static List<NavigationItem> getMainItems() {
    return [
      NavigationItem(
        id: 'Servicios',
        title: 'Servicios',
        icon: PhosphorIcons.wrench(),
        adminOnly: false,
      ),
      NavigationItem(
        id: 'Inventario',
        title: 'Inventario',
        icon: PhosphorIcons.package(),
        adminOnly: false,
      ),
      // ✅ Nuevo ítem para Inspecciones
      NavigationItem(
        id: 'Inspecciones',
        title: 'Inspecciones',
        icon: PhosphorIcons.clipboardText(),
        adminOnly: false,
      ),
      // ✅ Nuevo ítem para Plantillas
      NavigationItem(
        id: 'Plantillas',
        title: 'Plantillas',
        icon: PhosphorIcons.fileText(),
        adminOnly: false,
      ),
      // ✅ Nuevo ítem para Clientes
      NavigationItem(
        id: 'Clientes',
        title: 'Clientes',
        icon: PhosphorIcons.users(),
        adminOnly: false,
      ),
      // ✅ Nuevo ítem para Usuarios (solo visible para admins por filtro)
      NavigationItem(
        id: 'Usuarios',
        title: 'Usuarios',
        icon: PhosphorIcons.userCircle(),
        adminOnly: true,
      ),
      NavigationItem(
        id: 'Registro de Activos',
        title: 'Registro de Activos',
        icon: PhosphorIcons.factory(),
        adminOnly: false,
      ),
      // ✅ Nuevo ítem para Geocercas
      NavigationItem(
        id: 'Geocercas',
        title: 'Geocercas',
        icon: PhosphorIcons.mapPin(),
        adminOnly: false,
      ),
      NavigationItem(
        id: 'Actividades',
        title: 'Actividades',
        icon: PhosphorIcons.listChecks(),
        adminOnly: false,
      ),
      NavigationItem(
        id: 'Gestión Financiera',
        title: 'Gestión Financiera',
        icon: PhosphorIcons.coins(),
        adminOnly: false,
      ),
    ];
  }

  static List<NavigationItem> getAdminItems() {
    return [
      NavigationItem(
        id: 'Configuración IA',
        title: 'Configuración IA',
        icon: PhosphorIcons.sparkle(),
        adminOnly: false,
      ),
      NavigationItem(
        id: 'Campos adicionales',
        title: 'Campos adicionales',
        icon: PhosphorIcons.plusSquare(),
        adminOnly: true,
      ),
      NavigationItem(
        id: 'Estados y transiciones',
        title: 'Estados y transiciones',
        icon: PhosphorIcons.arrowsLeftRight(),
        adminOnly: true,
      ),
      NavigationItem(
        id: 'Branding',
        title: 'Branding',
        icon: PhosphorIcons.palette(),
        adminOnly: true,
      ),
      NavigationItem(
        id: 'Configuración Facturación',
        title: 'Facturación Factus',
        icon: PhosphorIcons.receipt(),
        adminOnly: true,
      ),
    ];
  }
}
