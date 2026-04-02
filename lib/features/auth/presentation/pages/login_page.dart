// lib/pages/login_page.dart
// LOGIN ATRACTIVO CON BRANDING Y RESPONSIVE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/features/auth/presentation/pages/registro_usuario_page.dart';
import 'package:infoapp/pages/home/pages/home_page.dart';
import 'package:infoapp/core/branding/theme_provider.dart';
import 'package:infoapp/core/branding/branding_logo.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/features/auth/presentation/widgets/login_form.dart';
import 'package:infoapp/features/auth/presentation/state/auth_controller.dart';
import 'package:infoapp/features/auth/domain/permission_store.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import 'package:infoapp/services/version_service.dart'; // ✅ Importar Servicio de Versión


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final ThemeProvider _themeProvider = ThemeProvider();
  final BrandingService _brandingService = BrandingService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isConnected = true;
  bool _offlineReady = false;
  String _currentVersion = ''; // Versión actual para mostrar en pantalla
  bool _updateAvailable = false; // ✅ Hay nueva versión en el servidor
  bool _isUpdating = false; // ✅ Cargando limpieza de caché
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _themeProvider.cargarConfiguracion();

    // Marcar que estamos en la pantalla de login (evita auto-login al recargar)
    AuthService.setLoginRouteActive(true);

    // ✅ CARGAR BRANDING AL INICIAR
    _brandingService.addListener(_onBrandingChanged);
    _loadBranding();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();

    // Chequeo puntual de conectividad para habilitar acceso offline si aplica
    ConnectivityService.instance.checkNow().then((ok) async {
      if (!mounted) return;
      setState(() {
        _isConnected = ok;
      });
      await _updateOfflineReady();
    });

    // ✅ OBTENER VERSIÓN ACTUAL Y VERIFICAR ACTUALIZACIÓN
    VersionService.getCurrentVersion().then((ver) {
      if (mounted) setState(() => _currentVersion = ver);
    });

    // ✅ CHEQUEAR SI HAY NUEVA VERSIÓN EN EL SERVIDOR (Solo Web)
    if (kIsWeb) {
      VersionService.isUpdateAvailable().then((hayUpdate) {
        if (mounted && hayUpdate) {
          setState(() => _updateAvailable = true);
        }
      });
    }
  }



  @override
  void dispose() {
    // Al salir de login, limpiar la marca
    AuthService.setLoginRouteActive(false);
    _themeProvider.removeListener(_onThemeChanged);
    _brandingService.removeListener(_onBrandingChanged);
    _usuarioController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onBrandingChanged() {
    if (mounted) setState(() {});
  }

  // ✅ NUEVO: Cargar branding al iniciar
  Future<void> _loadBranding() async {
    await _brandingService.loadBranding();
  }

  Future<void> _updateOfflineReady() async {
    // Offline ready si hubo login reciente y existen datos de usuario en cache.
    // No se exige token vigente para permitir acceso solo a UI offline.
    final recentLogin = await AuthService.hadRecentLogin(hours: 24);
    final user = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        _offlineReady = recentLogin && (user != null);
      });
    }
  }

  // ✅ NUEVO: Método para guardar datos del usuario
  Future<void> _guardarDatosUsuario(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar datos del usuario
    await prefs.setInt('usuario_id', userData['id']);
    await prefs.setString('usuario_nombre', userData['usuario']);
    await prefs.setString('usuario_rol', userData['rol']);
    await prefs.setString('usuario_estado', userData['estado']);

    // Guardar datos adicionales si existen
    if (userData['nombre_completo'] != null) {
      await prefs.setString('nombre_completo', userData['nombre_completo']);
    }
    if (userData['correo'] != null) {
      await prefs.setString('correo', userData['correo']);
    }
    if (userData['nit'] != null) {
      await prefs.setString('nit', userData['nit']);
    }

    // ✅ NUEVO: Guardar timestamp del login
    await prefs.setString('login_timestamp', DateTime.now().toIso8601String());
  }

  // ✅ NUEVO: Método para limpiar datos del usuario (en caso de error)
  Future<void> _limpiarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_id');
    await prefs.remove('usuario_nombre');
    await prefs.remove('usuario_rol');
    await prefs.remove('usuario_estado');
    await prefs.remove('nombre_completo');
    await prefs.remove('correo');
    await prefs.remove('nit');
    await prefs.remove('login_timestamp');
  }

  void _showErrorMessage(String message) {
    NetErrorMessages.showMessage(context, message, success: false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final isTablet = size.width > 600 && size.width <= 800;
    final isWeb = kIsWeb;
    // Modo compacto para web escritorio: reduce tamaño y elimina minHeight
    final isWebCompact = isWeb && isDesktop;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ CAPA 1: Imagen de fondo (si existe)
          if (isWeb && _brandingService.backgroundUrl != null)
            Positioned.fill(
              child: Image.network(
                _brandingService.backgroundUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.grey.shade200);
                },
              ),
            ),

          // ✅ CAPA 2: Gradiente con opacidad (solo cuando NO hay imagen de fondo)
          if (_brandingService.backgroundUrl == null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _themeProvider.primaryColor.withOpacity(0.8),
                      _themeProvider.primaryColor.withOpacity(1.0),
                      _themeProvider.primaryColor.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

          // ✅ CAPA 3: Contenido del login
          SafeArea(
            child: SizedBox(
              height:
                  size.height, // Asegura que el contenedor ocupe toda la altura
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isWebCompact ? 24.0 : (isDesktop ? 32.0 : 0.0),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        size.height -
                        (isWebCompact ? 48.0 : (isDesktop ? 64.0 : 0.0)),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Align(
                        alignment:
                            isDesktop
                                ? Alignment.centerRight
                                : Alignment.center,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth:
                                isWebCompact
                                    ? 320
                                    : (isDesktop
                                        ? 360
                                        : (isTablet ? 360 : double.infinity)),
                            // En web compacto no forzamos altura mínima para evitar scroll
                            minHeight: isWebCompact ? 0 : size.height,
                          ),
                          child: Card(
                            elevation: isDesktop ? 12 : 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 20 : 16,
                              ),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(
                                isWebCompact ? 16.0 : (isDesktop ? 24.0 : 16.0),
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  isDesktop ? 20 : 16,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white, Colors.grey.shade50],
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildHeader(isDesktop),
                                    SizedBox(height: isDesktop ? 28 : 24),
                                    _buildLoginForm(isDesktop),
                                    SizedBox(height: isDesktop ? 24 : 18),
                                    _buildLoginButton(isDesktop),
                                    SizedBox(height: isDesktop ? 12 : 10),
                                    _buildForgotPasswordLink(isDesktop),
                                    SizedBox(height: isDesktop ? 20 : 16),
                                    _buildDivider(),
                                    SizedBox(height: isDesktop ? 16 : 12),
                                    _buildOfflineLoginHint(isDesktop),
                                    SizedBox(height: isDesktop ? 20 : 16),
                                    _buildRegisterSection(isDesktop),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ Versión actual (abajo izquierda)
          Positioned(
            left: 20,
            bottom: 24,
            child: Text(
              _currentVersion.isEmpty
                  ? 'Cargando...'
                  : 'Versión $_currentVersion',
              style: TextStyle(
                color:
                    isWeb && _brandingService.backgroundUrl != null
                        ? Colors.white.withOpacity(0.9)
                        : (_brandingService.backgroundUrl == null
                            ? Colors.white70
                            : Colors.grey[700]),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows:
                    isWeb && _brandingService.backgroundUrl != null
                        ? [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                        : null,
              ),
            ),
          ),

          // ✅ BANNER DE ACTUALIZACIÓN DISPONIBLE
          if (_updateAvailable)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      const Icon(Icons.system_update_alt, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '¡Nueva versión disponible! Actualiza para cargar los últimos cambios.',
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
                              width: 24,
                              height: 24,
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
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text(
                                'ACTUALIZAR AHORA',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.orange.shade800,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      children: [
        // ✅ Logo del branding animado
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: _themeProvider.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: BrandingLogo(
                  width: isDesktop ? 64 : 56,
                  height: isDesktop ? 64 : 56,
                  fallbackColor: _themeProvider.primaryColor,
                ),
              ),
            );
          },
        ),
        SizedBox(height: isDesktop ? 24 : 20),

        // Título
        Text(
          'Iniciar Sesión',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 6),

        // Subtítulo
        Text(
          'Accede a tu sistema de gestión empresarial',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  Widget _buildLoginForm(bool isDesktop) {
    final auth = context.watch<AuthController>();
    return LoginForm(
      usuarioController: _usuarioController,
      passwordController: _passwordController,
      isDesktop: isDesktop,
      isLoading: auth.isLoading,
      obscurePassword: auth.obscurePassword,
      primaryColor: _themeProvider.primaryColor,
      onToggleObscure: () {
        auth.toggleObscure();
      },
      onSubmit: () async {
        if (_formKey.currentState!.validate()) {
          try {
            final result = await auth.loginUsuario(
              _usuarioController.text.trim(),
              _passwordController.text.trim(),
            );
            if (result['success'] == true && mounted) {
              // El login ocurrirá vía AuthController -> MyApp redirección
              NetErrorMessages.showMessage(
                context,
                '¡Bienvenido ${result['usuario']}!',
                success: true,
              );
              await AuthService.setLoginRouteActive(false);
            }
          } catch (e) {
            _showErrorMessage(e.toString());
          }
        }
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputAction? textInputAction,
    required bool isDesktop,
    Widget? suffixIcon,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      enabled: !context.read<AuthController>().isLoading,
      style: TextStyle(fontSize: isDesktop ? 15 : 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: _themeProvider.primaryColor),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _themeProvider.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isDesktop ? 12 : 10,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label es requerido';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton(bool isDesktop) {
    final auth = context.watch<AuthController>();
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 48 : 44,
      child: ElevatedButton(
        onPressed:
            auth.isLoading
                ? null
                : () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final result = await auth.loginUsuario(
                        _usuarioController.text.trim(),
                        _passwordController.text.trim(),
                      );
                      if (result['success'] == true && mounted) {
                        NetErrorMessages.showMessage(
                          context,
                          '¡Bienvenido ${result['usuario']}!',
                          success: true,
                        );
                        await AuthService.setLoginRouteActive(false);
                      }
                    } catch (e) {
                      _showErrorMessage(e.toString());
                    }
                  }
                },
        style: ElevatedButton.styleFrom(
          backgroundColor: _themeProvider.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: _themeProvider.primaryColor.withOpacity(0.3),
        ),
        child:
            auth.isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: isDesktop ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildOfflineLoginHint(bool isDesktop) {
    if (_isConnected || !_offlineReady || kIsWeb) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin conexión. Puedes entrar con tu sesión previa.',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 14 : 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: isDesktop ? 44 : 42,
          child: OutlinedButton.icon(
            onPressed: context.read<AuthController>().isLoading ? null : _loginOffline,
            icon: const Icon(Icons.cloud_off),
            label: const Text('Entrar sin conexión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _themeProvider.primaryColor,
              side: BorderSide(color: _themeProvider.primaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loginOffline() async {
    final auth = context.read<AuthController>();
    try {
      auth.setLoading(true);
      if (kIsWeb) {
        _showErrorMessage('En la web no se permite modo sin conexión.');
        return;
      }
      // Permitir acceso offline si hubo login en las últimas 24h y
      // existen datos de usuario guardados, aunque el token esté expirado.
      final recentLogin = await AuthService.hadRecentLogin(hours: 24);
      final user = await AuthService.getUserData();
      if (!recentLogin || user == null) {
        _showErrorMessage(
          'No es posible entrar sin conexión. Inicia sesión online al menos una vez.',
        );
        return;
      }

      final nombreUsuario = user['usuario']?.toString() ?? 'Usuario';
      final rol = user['rol']?.toString() ?? 'Sin rol';

      // Cargar permisos desde cache
      try {
        final int userId =
            (user['id'] ?? 0) is int
                ? (user['id'] ?? 0)
                : int.tryParse(user['id']?.toString() ?? '0') ?? 0;
        await PermissionStore.instance.loadFromPrefs(userId);
      } catch (_) {}

      if (mounted) {
        NetErrorMessages.showMessage(
          context,
          'Modo offline: Bienvenido $nombreUsuario',
          success: true,
        );
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    HomePage(nombreUsuario: nombreUsuario, rol: rol),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } finally {
      if (mounted) {
        auth.setLoading(false);
      }
    }
  }

  Widget _buildForgotPasswordLink(bool isDesktop) {
    return Center(
      child: TextButton(
        onPressed:
            context.read<AuthController>().isLoading
                ? null
                : () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder:
                          (context, animation, secondaryAnimation) =>
                              const ForgotPasswordPage(),
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 16,
            vertical: isDesktop ? 10 : 8,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 16,
              color: _themeProvider.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                color: _themeProvider.primaryColor,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'o',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
      ],
    );
  }

  Widget _buildRegisterSection(bool isDesktop) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: isDesktop ? 15 : 14,
              color: Colors.grey[600],
            ),
            children: [const TextSpan(text: '¿No tienes una cuenta? ')],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              context.read<AuthController>().isLoading
                  ? null
                  : () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder:
                            (context, animation, secondaryAnimation) =>
                                const RegistroUsuarioPage(),
                        transitionsBuilder: (
                          context,
                          animation,
                          secondaryAnimation,
                          child,
                        ) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 20,
              vertical: isDesktop ? 12 : 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Crear cuenta nueva',
            style: TextStyle(
              fontSize: isDesktop ? 15 : 14,
              color: _themeProvider.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
