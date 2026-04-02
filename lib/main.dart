import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/features/auth/presentation/pages/login_page.dart'; // Login consolidado en feature
import 'package:infoapp/core/branding/branding_service.dart'; // ✅ Servicio centralizado
import 'pages/servicios/services/servicios_api_service.dart';
import 'pages/servicios/controllers/servicios_controller.dart'; // ✅ Global Controller
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/features/auth/presentation/state/auth_controller.dart';
import 'pages/home/pages/home_page.dart';
import 'package:infoapp/features/auth/presentation/pages/reset_password_page.dart';
import 'package:infoapp/features/auth/presentation/pages/login_mobile_page.dart';
import 'pages/plantillas/providers/plantilla_provider.dart';
import 'package:infoapp/config/providers/config_provider.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/env/pages/select_server_qr_page.dart';
import 'pages/geocercas/controllers/geocercas_controller.dart';
import 'pages/inspecciones/providers/inspecciones_provider.dart';
import 'pages/inspecciones/providers/sistemas_provider.dart';
import 'pages/inspecciones/providers/actividades_provider.dart';
import 'pages/geocercas/services/async_upload_service.dart'; // ✅ NUEVO
import 'pages/servicios/providers/operaciones_provider.dart';
import 'pages/servicios/services/actividades_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar sistema de cache optimizado
  await ServiciosApiService.inicializarSistemaOptimizado();

  // 🔄 Reintentar uploads de geocercas pendientes al iniciar
  unawaited(AsyncUploadService.retryPendingUploads());

  runApp(const MultiProviderApp());
}

class MultiProviderApp extends StatelessWidget {
  const MultiProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlantillaProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => GeocercasController()),
        ChangeNotifierProvider(create: (_) => InspeccionesProvider()),
        ChangeNotifierProvider(create: (_) => SistemasProvider()),
        ChangeNotifierProvider(create: (_) => ActividadesProvider()),
        ChangeNotifierProvider(create: (_) => ServiciosController()),
        ChangeNotifierProvider(create: (_) => AuthController()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => OperacionesProvider()),
        ChangeNotifierProvider(create: (_) => ActividadesService()),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSnackBar(
    String message, {
    Color? backgroundColor,
    Duration? duration,
  }) {
    Future.delayed(Duration.zero, () {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _doShowSnackBar(message, backgroundColor, duration),
        );
      } else {
        _doShowSnackBar(message, backgroundColor, duration);
      }
    });
  }

  static void _doShowSnackBar(
    String message,
    Color? backgroundColor,
    Duration? duration,
  ) {
    try {
      final state = messengerKey.currentState;
      if (state == null || !state.mounted) return;
      state.clearSnackBars();
      state.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Colors.orange,
          duration: duration ?? const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Nota: No se pudo mostrar SnackBar (árbol inestable): $e');
    }
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BrandingService _brandingService =
      BrandingService(); // ✅ Usar el servicio
  bool _isAppLoading = true;
  // ✅ Deep link: abrir ResetPasswordPage si viene desde correo
  bool _openResetFromLink = false;
  String? _deepLinkUsuario;

  // ✅ Gate de políticas
  static const String _currentPoliciesVersion = '2025-10';
  bool _requirePoliciesAcceptance = false;

  // ✅ Control de inactividad para auto-logout
  Timer? _idleTimer;
  final Duration _idleTimeout = const Duration(minutes: 20);
  DateTime _lastActivity = DateTime.now();

  AuthController? _authController;

  @override
  void initState() {
    super.initState();
    // ✅ No podemos usar context.read() directamente en initState de forma segura
    // en todos los casos, lo movemos a un post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeApp();
        _setupAuthListener();
      }
    });
  }

  // ✅ Método unificado para inicializar la app
  Future<void> _initializeApp() async {
    try {
      await ServerConfig.instance.load();
      // Cargar configuración de branding
      await _brandingService.loadBranding();

      // ✅ NUEVO: La sesión se gestiona vía AuthController
      // Solo validamos expiración básica al inicio, no inactividad de 20 min
      await context.read<AuthController>().checkAuthStatus();

      // ✅ Detectar parámetros de la URL para abrir reset directo
      final auth = context.read<AuthController>();
      final params = Uri.base.queryParameters;
      final qpUsuario = params['usuario'];
      final qpCode = params['code'];
      final qpToken = params['token'];
      if (!auth.isAuthenticated &&
          (qpUsuario != null && qpUsuario.isNotEmpty) &&
          ((qpCode != null && qpCode.isNotEmpty) ||
              (qpToken != null && qpToken.isNotEmpty))) {
        _deepLinkUsuario = qpUsuario;
        _openResetFromLink = true;
      }

      // Simular un pequeño delay para mostrar splash
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Verificar aceptación de políticas (si no hay sesión activa)
      try {
        final prefs = await SharedPreferences.getInstance();
        final accepted = prefs.getBool('policiesAccepted') ?? false;
        final savedVersion = prefs.getString('policiesVersion');
        if (!auth.isAuthenticated) {
          _requirePoliciesAcceptance =
              !accepted || savedVersion != _currentPoliciesVersion;
        } else {
          _requirePoliciesAcceptance = false; // ya autenticado
        }
      } catch (_) {
        _requirePoliciesAcceptance = true;
      }
    } catch (e) {
      //       print('Error inicializando app: $e');
      // Continuar con valores por defecto
    } finally {
      if (mounted) {
        setState(() {
          _isAppLoading = false;
        });
      }
    }
  }

  void _setupAuthListener() {
    _authController = context.read<AuthController>();
    _authController!.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_authController!.isAuthenticated) {
      _resetIdleTimer();
    } else {
      _idleTimer?.cancel();
    }
  }

  void _onUserActivity() {
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated) return;
    _lastActivity = DateTime.now();
    AuthService.updateLastActivity();
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _handleAutoLogout);
  }

  Future<void> _handleAutoLogout() async {
    // Verificar última actividad por seguridad
    final inactiveFor = DateTime.now().difference(_lastActivity);
    if (inactiveFor >= _idleTimeout) {
      // Usar el controlador global para cerrar sesión de forma reactiva
      context.read<AuthController>().logout();
    } else {
      // Si hubo actividad reciente, reiniciar el timer
      _resetIdleTimer();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // ✅ Escuchar cambios del branding
      animation: _brandingService,
      builder: (context, child) {
        return MaterialApp(
          scaffoldMessengerKey: MyApp.messengerKey,
          title: 'Infoapp',
          theme: _brandingService.createTheme(), // ✅ Tema centralizado
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''), // Español
            Locale('en', ''), // Inglés
          ],
          locale: const Locale('es', ''),
          routes: {
            '/login': (context) {
              if (kIsWeb) {
                return const LoginPage();
              }
              // Mobile logic
              if (!ServerConfig.instance.hasCurrentRoot) {
                return const SelectServerQrPage();
              }
              return const LoginMobilePage();
            },
          },
          // ✅ Usar un Builder para garantizar un contexto descendente del MaterialApp
          home: Builder(
            builder: (context) {
              return _isAppLoading ? _buildSplashScreen() : _buildMainApp(context);
            },
          ),
          debugShowCheckedModeBanner: false,
          // ✅ Capturar actividad global (mouse, touch, scroll) para reiniciar timer
          builder:
              (context, child) => Listener(
                onPointerDown: (_) => _onUserActivity(),
                onPointerMove: (_) => _onUserActivity(),
                onPointerHover: (_) => _onUserActivity(), // ✅ Mejor detección en Web
                onPointerSignal: (_) => _onUserActivity(),
                child: Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    const _IconPrecache(),
                  ],
                ),
              ),
        );
      },
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _brandingService.primaryColor, // ✅ Color del servicio
              _brandingService.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Logo usando el servicio centralizado
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _brandingService.primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child:
                      _brandingService.logoUrl != null
                          ? Image.network(
                            _brandingService.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.business,
                                color: _brandingService.primaryColor,
                                size: 60,
                              );
                            },
                          )
                          : Icon(
                            Icons.business,
                            color: _brandingService.primaryColor,
                            size: 60,
                          ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Mi Aplicación',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _brandingService.isLoading
                    ? 'Cargando configuración...'
                    : 'Iniciando aplicación...',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),

              const SizedBox(height: 32),

              // ✅ Indicador de progreso más elegante
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainApp(BuildContext context) {
    final bool isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final bool isWeb = kIsWeb;
    final auth = context.watch<AuthController>();

    // Si hay sesión válida, ir a Home; si no, mostrar Login
    if (auth.isAuthenticated && auth.nombreUsuario != null && auth.rol != null) {
      return HomePage(nombreUsuario: auth.nombreUsuario!, rol: auth.rol!);
    }
    // ✅ Si viene desde enlace de correo, abrir Restablecer directamente
    if (_openResetFromLink && _deepLinkUsuario != null) {
      return ResetPasswordPage(usuario: _deepLinkUsuario!);
    }
    // ✅ Gate de políticas antes del login (solo Web)
    // TEMPORALMENTE DESHABILITADO POR SOLICITUD DEL USUARIO
    /* if (isWeb && _requirePoliciesAcceptance) {
      return const PoliciesPage(policiesVersion: _currentPoliciesVersion);
    } */
    if (isMobile) {
      // ✅ Si no hay servidor configurado, mostrar selección
      if (!ServerConfig.instance.hasCurrentRoot) {
        return const SelectServerQrPage();
      }
      return const LoginMobilePage();
    }
    return const LoginPage();
  }
}

// ✅ Widget mejorado para logo reutilizable
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final bool showFallback;

  const AppLogo({
    super.key,
    this.width = 40,
    this.height = 40,
    this.backgroundColor,
    this.showFallback = true,
  });

  @override
  Widget build(BuildContext context) {
    final brandingService = BrandingService();

    return AnimatedBuilder(
      animation: brandingService,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: brandingService.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                brandingService.logoUrl != null
                    ? Image.network(
                      brandingService.logoUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackIcon(brandingService);
                      },
                    )
                    : _buildFallbackIcon(brandingService),
          ),
        );
      },
    );
  }

  Widget _buildFallbackIcon(BrandingService brandingService) {
    if (!showFallback) return const SizedBox.shrink();

    return Icon(
      Icons.business,
      color: brandingService.primaryColor.withOpacity(0.7),
      size: (width ?? 40) * 0.6,
    );
  }
}

// ✅ Widget helper para acceso rápido al branding en cualquier parte
class BrandingProvider extends InheritedWidget {
  final BrandingService brandingService;

  const BrandingProvider({
    super.key,
    required this.brandingService,
    required super.child,
  });

  static BrandingProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BrandingProvider>();
  }

  @override
  bool updateShouldNotify(BrandingProvider oldWidget) {
    return brandingService != oldWidget.brandingService;
  }
}

// ✅ Extension para acceso fácil al branding desde cualquier BuildContext
extension BrandingContext on BuildContext {
  BrandingService get branding => BrandingService();

  // Accesos directos
  Color get primaryColor => branding.primaryColor;
  Color get primaryLight => branding.primaryLight;
  Color get primaryDark => branding.primaryDark;
  Color get primarySurface => branding.primarySurface;
  String? get logoUrl => branding.logoUrl;
}

// Precarga invisible de íconos que aparecen solo en condiciones específicas
class _IconPrecache extends StatelessWidget {
  const _IconPrecache();

  @override
  Widget build(BuildContext context) {
    return const Offstage(
      offstage: true,
      child: Row(
        children: [
          Icon(Icons.supervised_user_circle), // Usuario
          Icon(Icons.gavel), // Anular servicio
          Icon(Icons.gesture), // Firma (solo Web)
        ],
      ),
    );
  }
}
