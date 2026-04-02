// lib/pages/forgot_password_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/utils/net_error_messages.dart';
import 'dart:convert';
import 'package:infoapp/core/branding/branding_logo.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/presentation/pages/reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _emailController = TextEditingController();
  final BrandingService _brandingService = BrandingService();

  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadBrandingIfNeeded();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandingIfNeeded() async {
    if (!_brandingService.isLoaded) {
      await _brandingService.loadBranding();
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final usuario = _usuarioController.text.trim();
      final email = _emailController.text.trim();

      final response = await http
          .post(
            Uri.parse(
              '${ServerConfig.instance.apiRoot()}/auth/request_password_reset.php',
            ),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'usuario': usuario, 'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      final result = jsonDecode(response.body);

      if (mounted) {
        if (result['success'] == true) {
          // ✅ SOLICITUD EXITOSA
          _showSuccessDialog(
            result['message'] ?? 'Solicitud enviada exitosamente',
            result['email_sent'] ?? false,
          );
        } else {
          // ❌ ERROR DEL SERVIDOR
          _showErrorMessage(result['message'] ?? 'Error al procesar solicitud');
        }
      }
    } catch (e) {
      if (mounted) {
        NetErrorMessages.showNetError(
          context,
          e,
          contexto: 'solicitar restablecimiento',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String message, bool emailSent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Solicitud Enviada')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        emailSent ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          emailSent
                              ? Colors.blue.shade200
                              : Colors.orange.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            emailSent ? Icons.email : Icons.info_outline,
                            color:
                                emailSent
                                    ? Colors.blue.shade600
                                    : Colors.orange.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            emailSent ? 'Email enviado:' : 'Importante:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emailSent
                            ? '1. Revisa tu bandeja de entrada\n'
                                '2. Busca el email con el código\n'
                                '3. El código expira en 15 minutos\n'
                                '4. Ingresa el código en la siguiente pantalla'
                            : 'El código fue generado pero no se pudo enviar el email.\n'
                                'Contacta al administrador para obtener el código.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (emailSent)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ResetPasswordPage(
                              usuario: _usuarioController.text.trim(),
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandingService.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ingresar Código'),
                )
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
            ],
          ),
    );
  }

  void _showErrorMessage(String message) {
    NetErrorMessages.showMessage(context, message, success: false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final isTablet = size.width > 600 && size.width <= 800;

    return AnimatedBuilder(
      animation: _brandingService,
      builder: (context, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _brandingService.primaryColor.withOpacity(0.8),
                  _brandingService.primaryColor,
                  _brandingService.primaryColor.withOpacity(0.9),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              isDesktop
                                  ? 420
                                  : (isTablet ? 380 : double.infinity),
                        ),
                        child: Card(
                          elevation: isDesktop ? 12 : 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              isDesktop ? 20 : 16,
                            ),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(isDesktop ? 40.0 : 32.0),
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
                                  SizedBox(height: isDesktop ? 32 : 24),
                                  _buildForm(isDesktop),
                                  SizedBox(height: isDesktop ? 32 : 24),
                                  _buildSubmitButton(isDesktop),
                                  SizedBox(height: isDesktop ? 24 : 20),
                                  _buildBackToLoginButton(isDesktop),
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
        );
      },
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      children: [
        // ✅ Logo con animación
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
                      color: _brandingService.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: BrandingLogo(
                  width: isDesktop ? 80 : 64,
                  height: isDesktop ? 80 : 64,
                  fallbackColor: _brandingService.primaryColor,
                ),
              ),
            );
          },
        ),
        SizedBox(height: isDesktop ? 24 : 20),

        // ✅ Título
        Text(
          '¿Olvidaste tu Contraseña?',
          style: TextStyle(
            fontSize: isDesktop ? 26 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isDesktop ? 8 : 6),

        // ✅ Subtítulo
        Text(
          'No te preocupes, te ayudamos a recuperarla.\nIngresa tu usuario y email para continuar.',
          style: TextStyle(
            fontSize: isDesktop ? 15 : 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm(bool isDesktop) {
    return Column(
      children: [
        // ✅ Campo Usuario
        _buildTextField(
          controller: _usuarioController,
          label: 'Nombre de Usuario',
          hint: 'Ingresa tu nombre de usuario',
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          isDesktop: isDesktop,
        ),
        SizedBox(height: isDesktop ? 20 : 16),

        // ✅ Campo Email
        _buildTextField(
          controller: _emailController,
          label: 'Correo Electrónico',
          hint: 'Ingresa tu email registrado',
          prefixIcon: Icons.email_outlined,
          textInputAction: TextInputAction.done,
          isDesktop: isDesktop,
          keyboardType: TextInputType.emailAddress,
          onFieldSubmitted: (_) {
            if (_formKey.currentState!.validate()) {
              _requestPasswordReset();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputAction? textInputAction,
    required bool isDesktop,
    TextInputType? keyboardType,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onFieldSubmitted: onFieldSubmitted,
      enabled: !_isLoading,
      style: TextStyle(fontSize: isDesktop ? 16 : 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: _brandingService.primaryColor),
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
          borderSide: BorderSide(
            color: _brandingService.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isDesktop ? 16 : 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label es requerido';
        }
        if (label.contains('Email') && !value.contains('@')) {
          return 'Ingresa un email válido';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 56 : 50,
      child: ElevatedButton(
        onPressed:
            _isLoading
                ? null
                : () {
                  if (_formKey.currentState!.validate()) {
                    _requestPasswordReset();
                  }
                },
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandingService.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: _brandingService.primaryColor.withOpacity(0.3),
        ),
        child:
            _isLoading
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
                    const Icon(Icons.send, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Enviar Solicitud',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildBackToLoginButton(bool isDesktop) {
    return TextButton.icon(
      onPressed: _isLoading ? null : () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: Text(
        'Volver al Login',
        style: TextStyle(
          fontSize: isDesktop ? 15 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: _brandingService.primaryColor,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 20,
          vertical: isDesktop ? 12 : 10,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
