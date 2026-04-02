// lib/pages/reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/utils/net_error_messages.dart';
import 'dart:convert';
import 'package:infoapp/core/branding/branding_logo.dart';
import 'package:infoapp/core/branding/branding_service.dart';
import 'package:infoapp/features/auth/presentation/pages/login_page.dart';
import 'package:infoapp/core/env/server_config.dart';

class ResetPasswordPage extends StatefulWidget {
  final String usuario;

  const ResetPasswordPage({super.key, required this.usuario});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController(); // ✅ Cambio: token → code
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final BrandingService _brandingService = BrandingService();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // ✅ Prefill desde query string: ?code=A3F8B2C1
    try {
      final params = Uri.base.queryParameters;
      final code = params['code'];
      if (code != null && code.isNotEmpty) {
        _codeController.text = code;
      }
    } catch (_) {}
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
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandingIfNeeded() async {
    if (!_brandingService.isLoaded) {
      await _brandingService.loadBranding();
    }
    if (mounted) setState(() {});
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim().toUpperCase(); // ✅ Mayúsculas
      final newPassword = _newPasswordController.text.trim();

      final response = await http
          .post(
            Uri.parse(
              '${ServerConfig.instance.apiRoot()}/auth/reset_password.php',
            ),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'usuario': widget.usuario,
              'code': code, // ✅ Solo enviar 'code'
              'nueva_password': newPassword, // ✅ Nombre correcto del campo
            }),
          )
          .timeout(const Duration(seconds: 10));

      final result = jsonDecode(response.body);

      if (mounted) {
        if (result['success'] == true) {
          // ✅ RESTABLECIMIENTO EXITOSO
          _showSuccessDialog(
            result['message'] ?? 'Contrase\u00f1a restablecida exitosamente',
          );
        } else {
          // ❌ ERROR DEL SERVIDOR
          _showErrorMessage(
            result['message'] ?? 'Error al restablecer contrase\u00f1a',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NetErrorMessages.showNetError(
          context,
          e,
          contexto: 'restablecer la contrase\u00f1a',
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

  void _showSuccessDialog(String message) {
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
                const Expanded(child: Text('\u00a1\u00c9xito!')),
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tu contrase\u00f1a ha sido actualizada de forma segura.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandingService.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ir al Login'),
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
                  padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
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
                            padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
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
                                  SizedBox(height: isDesktop ? 20 : 16),
                                  _buildForm(isDesktop),
                                  SizedBox(height: isDesktop ? 20 : 16),
                                  _buildSubmitButton(isDesktop),
                                  SizedBox(height: isDesktop ? 16 : 14),
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
                  width: isDesktop ? 64 : 56,
                  height: isDesktop ? 64 : 56,
                  fallbackColor: _brandingService.primaryColor,
                ),
              ),
            );
          },
        ),
        SizedBox(height: isDesktop ? 16 : 14),
        Text(
          'Restablecer Contrase\u00f1a',
          style: TextStyle(
            fontSize: isDesktop ? 22 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isDesktop ? 6 : 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _brandingService.primarySurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _brandingService.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person,
                color: _brandingService.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Usuario: ${widget.usuario}',
                style: TextStyle(
                  fontSize: isDesktop ? 15 : 14,
                  color: _brandingService.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isDesktop ? 6 : 4),
        Text(
          'Ingresa el c\u00f3digo de 8 caracteres que recibiste por email.',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
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
        // ✅ Campo Código de Recuperación (8 caracteres)
        _buildTextField(
          controller: _codeController,
          label: 'C\u00f3digo de Recuperaci\u00f3n',
          hint: 'Ej: A3F8B2C1',
          prefixIcon: Icons.security,
          textInputAction: TextInputAction.next,
          isDesktop: isDesktop,
          maxLength: 8, // ✅ Límite de 8 caracteres
          textCapitalization:
              TextCapitalization.characters, // ✅ Mayúsculas automáticas
        ),
        SizedBox(height: isDesktop ? 16 : 12),

        // ✅ Campo Nueva Contraseña
        _buildTextField(
          controller: _newPasswordController,
          label: 'Nueva Contrase\u00f1a',
          hint: 'M\u00ednimo 8 caracteres',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscureNewPassword,
          textInputAction: TextInputAction.next,
          isDesktop: isDesktop,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[600],
            ),
            onPressed: () {
              setState(() {
                _obscureNewPassword = !_obscureNewPassword;
              });
            },
          ),
        ),
        SizedBox(height: isDesktop ? 16 : 12),

        // ✅ Campo Confirmar Contraseña
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirmar Contrase\u00f1a',
          hint: 'Confirma tu nueva contrase\u00f1a',
          prefixIcon: Icons.lock_reset,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          isDesktop: isDesktop,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[600],
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
          onFieldSubmitted: (_) {
            if (_formKey.currentState!.validate()) {
              _resetPassword();
            }
          },
        ),
        SizedBox(height: isDesktop ? 12 : 10),

        // ✅ Indicador de seguridad de contraseña
        _buildPasswordStrengthIndicator(),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _newPasswordController.text;
    final strength = _calculatePasswordStrength(password);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seguridad de la contrase\u00f1a:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: strength / 4,
            backgroundColor: Colors.grey.shade300,
            color:
                strength < 2
                    ? Colors.red
                    : strength < 3
                    ? Colors.orange
                    : Colors.green,
          ),
          const SizedBox(height: 8),
          Text(
            _getPasswordStrengthText(strength),
            style: TextStyle(
              fontSize: 11,
              color:
                  strength < 2
                      ? Colors.red
                      : strength < 3
                      ? Colors.orange
                      : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _calculatePasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    return strength;
  }

  String _getPasswordStrengthText(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Muy d\u00e9bil - Agrega m\u00e1s caracteres';
      case 2:
        return 'D\u00e9bil - Agrega may\u00fasculas y n\u00fameros';
      case 3:
        return 'Buena - Considera agregar símbolos';
      case 4:
      case 5:
        return 'Excelente - Contraseña muy segura';
      default:
        return '';
    }
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
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      enabled: !_isLoading,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: isDesktop ? 15 : 13),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: _brandingService.primaryColor),
        suffixIcon: suffixIcon,
        counterText: '', // ✅ Ocultar contador "0/8"
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
          vertical: isDesktop ? 12 : 10,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label es requerido';
        }
        if (label.contains('Código') && value.length != 8) {
          return 'El código debe tener exactamente 8 caracteres';
        }
        if (label.contains('Nueva Contraseña') && value.length < 8) {
          return 'La contraseña debe tener al menos 8 caracteres';
        }
        if (label.contains('Confirmar') &&
            value != _newPasswordController.text) {
          return 'Las contraseñas no coinciden';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 48 : 44,
      child: ElevatedButton(
        onPressed:
            _isLoading
                ? null
                : () {
                  if (_formKey.currentState!.validate()) {
                    _resetPassword();
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
                    const Icon(Icons.lock_reset, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Restablecer Contrase\u00f1a',
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
      onPressed:
          _isLoading
              ? null
              : () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              ),
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
