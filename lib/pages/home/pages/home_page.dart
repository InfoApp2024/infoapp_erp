// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../controllers/home_controller.dart';
import '../widgets/main_content_area.dart';
// Eliminado ThemeProvider: usamos BrandingService para colores/tema
import '../widgets/app_drawer.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/features/auth/data/logout_service.dart';
import 'package:infoapp/features/auth/data/permissions_service.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../inventory/pages/inventory_main_page.dart';
import '../../servicios/services/servicios_api_service.dart';
import '../../staff/pages/staff_pages.dart';
import '../../staff/presentation/staff_presentation.dart';
import 'package:infoapp/pages/staff/widgets/staff_widgets.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb;

import 'package:infoapp/features/chatbot/presentation/widgets/chat_overlay_widget.dart';
import 'package:infoapp/features/chatbot/data/ai_config_service.dart';
import 'package:infoapp/features/birthdays/services/birthday_service.dart';
import 'package:infoapp/features/birthdays/widgets/birthday_dialog.dart';
import '../widgets/welcome_intro_widget.dart';
import '../../geocercas/controllers/geocercas_controller.dart';
import '../../geocercas/services/geofence_dialog_service.dart';
import 'package:infoapp/services/version_service.dart'; // ✅ Check de versiones

class HomePage extends StatefulWidget {
  final String nombreUsuario;
  final String rol;

  const HomePage({super.key, required this.nombreUsuario, required this.rol});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  final BrandingService _brandingService = BrandingService();
  final bool _isLoggingOut = false;

  // Chat Overlay State
  OverlayEntry? _chatOverlayEntry;
  bool _isChatOpen = false;
  bool _hasChatPermission = false;

  String? _birthdayBannerText;
  bool _hasBirthdaysToday = false;
  String? _userPhotoUrl;
  bool _showIntro = false;
  bool _updateAvailable = false; // ✅ Nueva versión en servidor
  bool _isUpdating = false; // ✅ Cargando limpieza de caché

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      nombreUsuario: widget.nombreUsuario,
      rol: widget.rol,
    );
    _loadBrandingIfNeeded();
    ServiciosApiService.inicializarSistemaOptimizado();
    // Ejecutar la recarga de permisos tras el primer frame para evitar
    // cualquier interferencia con la navegación y asegurar que el widget esté montado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadPermissionsIfNeeded();
      _checkIntro();
      _initializeGeofenceMonitoring();
      AiConfigService().checkConfig();
    });
    _checkBirthdaysToday();
    _loadUserPhoto();
    // ✅ CHEQUEAR DISPONIBILIDAD DE ACTUALIZACIÓN (Solo Web)
    if (kIsWeb) {
      VersionService.isUpdateAvailable().then((hayUpdate) {
        if (mounted && hayUpdate) setState(() => _updateAvailable = true);
      });
    }
  }

  /// Inicializar monitoreo de geocercas si el usuario tiene permiso
  Future<void> _initializeGeofenceMonitoring() async {
    try {
      // Verificar si el usuario tiene permiso para geocercas
      if (!PermissionStore.instance.can('geocercas', 'ver')) {
        return;
      }

      final geocercasController = Provider.of<GeocercasController>(
        context,
        listen: false,
      );

      if (!geocercasController.isMonitoring) {
        await geocercasController.cargarGeocercas();
        await geocercasController.iniciarMonitoreo();
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _removeChatOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _removeChatOverlay() {
    if (_chatOverlayEntry != null) {
      _chatOverlayEntry!.remove();
      _chatOverlayEntry = null;
    }
  }

  Future<void> _reloadPermissionsIfNeeded() async {
    try {
      // Intentar obtener el usuario_id desde AuthService
      final userData = await AuthService.getUserData();
      int userId =
          (userData?['id'] ?? 0) is int
              ? (userData?['id'] ?? 0)
              : int.tryParse(userData?['id']?.toString() ?? '0') ?? 0;

      // Fallback: leer directamente de SharedPreferences si no estuvo disponible
      if (userId <= 0) {
        try {
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getInt('usuario_id') ?? 0;
        } catch (_) {}
      }

      if (userId <= 0) {
        return;
      }
      await PermissionStore.instance.loadFromPrefs(userId);
      final perms = await PermissionsService.listarPermisos(userId: userId);
      await PermissionStore.instance.setForUser(userId, perms);

      // Checar permiso específico para el chatbot
      try {
        _hasChatPermission = await PermissionsService.checarPermiso(
          module: 'chatbot',
          action: 'ver',
          userId: userId,
        );
      } catch (e) {
        _hasChatPermission = false;
      }

      if (mounted) setState(() {});
    } catch (_) {
      // No bloquear Home por errores de permisos
    }
  }

  Future<void> _loadBrandingIfNeeded() async {
    if (!_brandingService.isLoaded && !_brandingService.isLoading) {
      await _brandingService.loadBranding();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadUserPhoto() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null && userData['url_foto'] != null) {
        String url = userData['url_foto'];
        // Manejar rutas relativas convirtiéndolas a URL completa usando ver_imagen.php
        if (url.isNotEmpty && !url.startsWith('http')) {
          final baseUrl = ServerConfig.instance.baseUrlFor('login');
          url = '$baseUrl/ver_imagen.php?ruta=$url';
        }

        if (mounted) {
          setState(() {
            _userPhotoUrl = url;
          });
        }
      } else {
        // No photo to load
      }
    } catch (e) {
      // Ignore photo loading error
    }
  }

  Future<void> _checkBirthdaysToday() async {
    try {
      final birthdays = await BirthdayService.getBirthdays();
      if (birthdays.isEmpty) return;

      final names = birthdays.map((b) => b.usuario).toSet().toList();

      if (mounted) {
        setState(() {
          _hasBirthdaysToday = true;
          _birthdayBannerText = '🎉 Cumpleaños hoy: ${names.join(', ')}';
        });

        // Show dialogs after a short delay
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;

          // Get current user ID for persistence key
          final prefs = await SharedPreferences.getInstance();
          final userData = await AuthService.getUserData();
          final currentUserId = userData?['id']?.toString() ?? '0';
          final today = DateTime.now().toIso8601String().split('T')[0];

          for (final user in birthdays) {
            final key = 'bd_shown_${currentUserId}_${user.id}_$today';

            // Check if already shown today
            if (prefs.getBool(key) == true) {
              continue;
            }

            final isMe = user.usuario == widget.nombreUsuario;
            // Si hay multiples cumpleaños, mostramos uno por uno
            if (!mounted) break;

            await showDialog(
              context: context,
              barrierDismissible: false, // Force interaction
              builder: (ctx) => BirthdayDialog(birthdayUser: user, isMe: isMe),
            );

            // Mark as shown
            await prefs.setBool(key, true);
          }
        });
      }
    } catch (e) {}
  }

  Future<void> _checkIntro() async {
    try {
      final userData = await AuthService.getUserData();
      final userId = userData?['id']?.toString() ?? '0';
      if (userId == '0') return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'welcome_intro_shown_v1_$userId';
      final shown = prefs.getBool(key) ?? false;

      if (!shown) {
        if (mounted) {
          setState(() {
            _showIntro = true;
          });
        }
      }
    } catch (e) {
      // Ignorar errores en intro
    }
  }

  Future<void> _dismissIntro() async {
    if (mounted) {
      setState(() {
        _showIntro = false;
      });
    }
    try {
      final userData = await AuthService.getUserData();
      final userId = userData?['id']?.toString() ?? '0';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welcome_intro_shown_v1_$userId', true);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await LogoutService.performLogout(
      context: context,
      nombreUsuario: widget.nombreUsuario,
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleChatbot() {
    if (_isChatOpen) {
      _closeChatbot();
    } else {
      _showChatbot();
    }
  }

  void _showChatbot() {
    // Detectar si es móvil para mostrar en pantalla completa o flotante
    final isMobile = MediaQuery.of(context).size.width < 600;

    _chatOverlayEntry = OverlayEntry(
      builder:
          (context) =>
              isMobile
                  ? Positioned.fill(
                    child: ChatOverlayWidget(onClose: _closeChatbot),
                  )
                  : Positioned(
                    bottom: 80,
                    right: 20,
                    child: ChatOverlayWidget(onClose: _closeChatbot),
                  ),
    );

    Overlay.of(context).insert(_chatOverlayEntry!);
    setState(() {
      _isChatOpen = true;
    });
  }

  void _closeChatbot() {
    _removeChatOverlay();
    setState(() {
      _isChatOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: PopScope intercepta el botón ← del navegador web.
    // Sin esto, el navegador navegaría por el historial hacia /login,
    // deslogueando al usuario involuntariamente.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Mostrar el diálogo de logout cuando el usuario presiona ← en el navegador
        await _logout();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_brandingService, _controller, AiConfigService()]),
        builder: (context, child) {
          // Listener global para transiciones de geocercas pendientes
          return Consumer<GeocercasController>(
            builder: (context, geocercasController, _) {
              // Mostrar diálogo de evidencia si hay una transición pendiente
              if (geocercasController.pendingTransition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  GeofenceDialogService.showEvidenceDialog(
                    context: context,
                    transition: geocercasController.pendingTransition!,
                    onPhotoTaken: (photo) async {
                      final success = await geocercasController
                          .confirmarTransicion(photo);
                      return success;
                    },
                  );
                });
              }

              return Stack(
                children: [
                  Scaffold(
                  appBar: AppBar(
                    leading: Builder(
                      builder: (context) {
                        final isDesktop =
                            MediaQuery.of(context).size.width >= 1024;
                        final isMobile = !kIsWeb && MediaQuery.of(context).size.width < 1024;

                        if (isDesktop) {
                          return IconButton(
                            icon: Icon(
                              _controller.isSidebarCollapsed
                                  ? Icons.menu
                                  : Icons.menu_open,
                            ),
                            onPressed: () => _controller.toggleSidebar(),
                            tooltip:
                                _controller.isSidebarCollapsed
                                    ? 'Expandir'
                                    : 'Colapsar',
                          );
                        }
                        
                        // En movil, no mostramos hamburguesa si estamos usando BottomNav
                        if (isMobile) {
                          return const SizedBox.shrink();
                        }

                        return IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          tooltip: 'Menú',
                        );
                      },
                    ),
                    title: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 1024) ...[
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: StaffAvatar(
                              photoUrl: _userPhotoUrl,
                              initials:
                                  widget.nombreUsuario.isNotEmpty
                                      ? widget.nombreUsuario
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : '?',
                              radius: 20,
                              backgroundColor: Colors.white,
                              textColor: _brandingService.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(_controller.vistaActual),
                        ),
                      ],
                    ),
                    backgroundColor: _brandingService.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    bottom:
                        _hasBirthdaysToday
                            ? PreferredSize(
                              preferredSize: const Size.fromHeight(28),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cake,
                                      color: Colors.yellowAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _birthdayBannerText ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : null,
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _brandingService.primaryColor,
                            _brandingService.primaryDark,
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      // Botón de Chat IA - Visible solo si tiene permiso Y está configurado
                      if (_hasChatPermission && AiConfigService().isAiEnabled) ...[
                        if (kIsWeb)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: ElevatedButton.icon(
                                onPressed: _toggleChatbot,
                                icon: Icon(
                                  _isChatOpen
                                      ? Icons.close
                                      : Icons
                                          .auto_awesome, // ✅ Fix: Icono más compatible (estrellas)
                                  size: 18,
                                ),
                                label: Text(
                                  _isChatOpen ? 'Cerrar Chat' : 'Asistente IA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor:
                                      _brandingService.primaryColor,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              _isChatOpen
                                  ? Icons.close
                                  : Icons
                                      .auto_awesome, // ✅ Fix: Icono más compatible (estrellas)
                              color: Colors.white,
                            ),
                            onPressed: _toggleChatbot,
                            tooltip:
                                _isChatOpen ? 'Cerrar chat' : 'Asistente IA',
                          ),
                      ],

                      const SizedBox(width: 8),

                      // Solo botón de cerrar sesión
                      _isLoggingOut
                          ? Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                          : IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: _logout,
                            tooltip: 'Cerrar sesión',
                          ),
                    ],
                  ),
                  drawer: (kIsWeb && MediaQuery.of(context).size.width < 1024)
                          ? _buildDrawer()
                          : null,
                  // floatingActionButton removed (moved to AppBar actions)
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 1024;

                      if (isDesktop) {
                        return Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: _controller.isSidebarCollapsed ? 80 : 250,
                              child: _buildSidebar(),
                            ),
                            Expanded(
                              child:
                                  _isLoggingOut
                                      ? _buildLogoutOverlay()
                                      : Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: _buildContent(),
                                      ),
                            ),
                          ],
                        );
                      }

                      return _isLoggingOut
                          ? _buildLogoutOverlay()
                          : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildContent(),
                          );
                    },
                  ),
                  bottomNavigationBar: (!kIsWeb && MediaQuery.of(context).size.width < 1024)
                      ? BottomNavigationBar(
                          currentIndex: _getBottomNavIndex(_controller.vistaActual),
                          onTap: (index) {
                            final vistas = ['Servicios', 'Inventario', 'Inspecciones', 'Clientes', 'Menú'];
                            setState(() {
                              _controller.cambiarVista(vistas[index]);
                            });
                          },
                          type: BottomNavigationBarType.fixed,
                          selectedItemColor: _brandingService.primaryColor,
                          unselectedItemColor: Colors.grey,
                          showUnselectedLabels: true,
                          items: [
                            BottomNavigationBarItem(icon: Icon(PhosphorIcons.wrench()), label: 'Servicios'),
                            BottomNavigationBarItem(icon: Icon(PhosphorIcons.package()), label: 'Inventario'),
                            BottomNavigationBarItem(icon: Icon(PhosphorIcons.clipboardText()), label: 'Inspecciones'),
                            BottomNavigationBarItem(icon: Icon(PhosphorIcons.users()), label: 'Clientes'),
                            BottomNavigationBarItem(icon: Icon(PhosphorIcons.squaresFour()), label: 'Menú'),
                          ],
                        )
                      : null,
                ),
                if (_showIntro)
                  Positioned.fill(
                    child: WelcomeIntroWidget(onDismiss: _dismissIntro),
                  ),
                // ✅ BANNER DE ACTUALIZACIÓN DISPONIBLE (Solo Web)
                if (_updateAvailable)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Material(
                      elevation: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade700,
                              Colors.orange.shade800,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.system_update_alt, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '¡Nueva versión disponible! Actualiza para cargar todos los cambios.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _isUpdating
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() => _isUpdating = true);
                                      await VersionService.clearCacheAndReload();
                                    },
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text(
                                      'ACTUALIZAR AHORA',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.orange.shade800,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
        );
      },
    ),
    );  // closes PopScope
  }

  Widget _buildDrawer() {
    return AppDrawer(
      controller: _controller,
      nombreUsuario: widget.nombreUsuario,
      rol: widget.rol,
      photoUrl: _userPhotoUrl,
      isLoggingOut: _isLoggingOut,
      onLogout: _logout,
      onNavigationChanged: (vista) {
        setState(() => _controller.cambiarVista(vista));
      },
    );
  }

  Widget _buildSidebar() {
    return AppDrawer(
      controller: _controller,
      nombreUsuario: widget.nombreUsuario,
      rol: widget.rol,
      photoUrl: _userPhotoUrl,
      isLoggingOut: _isLoggingOut,
      onLogout: _logout,
      onNavigationChanged: (vista) {
        setState(() => _controller.cambiarVista(vista));
      },
      isSidebar: true,
    );
  }

  Widget _buildLogoutOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Cerrando sesión...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getBottomNavIndex(String vista) {
    final vistas = ['Servicios', 'Inventario', 'Inspecciones', 'Clientes', 'Menú'];
    final index = vistas.indexOf(vista);
    return index >= 0 ? index : 4; // 4 es Menú
  }

  Widget _buildContent() {
    if (_controller.vistaActual == 'Menú') {
      return _buildMobileMenuGrid();
    }
    if (_controller.vistaActual == 'Personal' ||
        _controller.vistaActual == 'Staff') {
      return _buildStaffPage();
    }
    if (_controller.vistaActual == 'Inventario') {
      return _buildInventarioPage();
    }
    return MainContentArea(controller: _controller);
  }

  Widget _buildMobileMenuGrid() {
    final allItems = NavigationItems.getMainItems();
    // Filtrar ítems que no están en la barra
    final mobileWhitelist = [
      'Servicios',
      'Inventario',
      'Inspecciones',
      'Clientes',
      'Geocercas',
      'Registro de Activos',
      'Actividades',
      'Usuarios',
    ];
    final menuItems = allItems.where((item) => mobileWhitelist.contains(item.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
          child: Text(
            'Todas las Funciones',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return InkWell(
                onTap: () {
                  setState(() {
                    _controller.cambiarVista(item.id);
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _brandingService.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          color: _brandingService.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStaffPage() {
    try {
      if (!Get.isRegistered<StaffController>()) {
        StaffBinding().dependencies();
      }
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el módulo de Personal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Error: $e', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return const StaffListPage();
  }

  Widget _buildInventarioPage() => const InventoryMainPage();
}
