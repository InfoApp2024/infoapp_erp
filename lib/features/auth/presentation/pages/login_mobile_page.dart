import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/theme_provider.dart';
import 'package:infoapp/core/branding/branding_logo.dart';
import 'package:provider/provider.dart';
import 'package:infoapp/features/auth/presentation/state/auth_controller.dart';
import 'package:infoapp/features/auth/presentation/widgets/login_form.dart';
// import 'package:infoapp/pages/home/pages/home_page.dart'; // Removido por desuso reactivo
import 'package:infoapp/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/features/env/pages/select_server_qr_page.dart';
import 'package:infoapp/features/auth/presentation/pages/registro_usuario_page.dart';

class LoginMobilePage extends StatefulWidget {
  const LoginMobilePage({super.key});

  @override
  State<LoginMobilePage> createState() => _LoginMobilePageState();
}

class _LoginMobilePageState extends State<LoginMobilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final ThemeProvider _themeProvider = ThemeProvider();
// Eliminar instanciación local: usamos el Provider global
// final AuthController _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _themeProvider.cargarConfiguracion();
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _handleLogin() async {
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();
    if (usuario.isEmpty || password.isEmpty) {
      NetErrorMessages.showMessage(
        context,
        'Por favor, completa todos los campos',
        success: false,
      );
      return;
    }
    final auth = context.read<AuthController>();
    try {
      final result = await auth.loginUsuario(usuario, password);
      if (result['success'] == true && mounted) {
        // La navegación se manejará reactivamente por MyApp, 
        // pero podemos forzarla aquí si es necesario o dejar que el sistema lo haga.
      }
    } catch (e) {
      NetErrorMessages.showMessage(
        context,
        e.toString().replaceAll('Exception: ', ''),
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        actions: [
          IconButton(
            tooltip: 'Seleccionar servidor',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectServerQrPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: _themeProvider.primaryColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: BrandingLogo(
                      width: 96,
                      height: 96,
                      fallbackColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        const Text(
                          'Iniciar Sesi\u00f3n',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Accede a tu sistema de gesti\u00f3n empresarial',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Consumer<AuthController>(
                              builder: (context, auth, _) => LoginForm(
                                usuarioController: _usuarioController,
                                passwordController: _passwordController,
                                isDesktop: false,
                                isLoading: auth.isLoading,
                                obscurePassword: auth.obscurePassword,
                                primaryColor: _themeProvider.primaryColor,
                                onToggleObscure: () => auth.toggleObscure(),
                                onSubmit: () {
                                  if (_formKey.currentState!.validate()) {
                                    _handleLogin();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Consumer<AuthController>(
                              builder: (context, auth, _) => SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : () {
                                    if (_formKey.currentState!.validate()) {
                                      _handleLogin();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _themeProvider.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                  ),
                                  child: const Text('Iniciar Sesi\u00f3n'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  '\u00bfOlvidaste tu contrase\u00f1a?',
                                ),
                              ),
                            ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const RegistroUsuarioPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: _themeProvider.primaryColor,
                                ),
                                child: const Text(
                                  'Crear cuenta nueva',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
