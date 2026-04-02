// lib/pages/registro_usuario_page.dart
// CÓDIGO COMPLETO DEL REGISTRO

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/utils/net_error_messages.dart';
import 'package:infoapp/core/branding/theme_provider.dart';
import 'package:infoapp/core/env/server_config.dart';

class RegistroUsuarioPage extends StatefulWidget {
  const RegistroUsuarioPage({super.key});

  @override
  State<RegistroUsuarioPage> createState() => _RegistroUsuarioPageState();
}

class _RegistroUsuarioPageState extends State<RegistroUsuarioPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idRegistroController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final ThemeProvider _themeProvider = ThemeProvider();

  String? nombreCliente;
  String? nitCliente;
  String _tipoRol = 'colaborador'; // ← AGREGAR CAMPO TIPO_ROL
  bool formularioHabilitado = false;
  bool _isValidating = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _themeProvider.cargarConfiguracion();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _idRegistroController.dispose();
    _usuarioController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> validarIDRegistro() async {
    if (_isValidating || _idRegistroController.text.trim().isEmpty) return;

    setState(() {
      _isValidating = true;
    });

    final url = '${ServerConfig.instance.apiRoot()}/core/metadata/validar_id.php';

    try {
//       print('🔍 Validando ID: ${_idRegistroController.text}'); // DEBUG

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"ID_REGISTRO": _idRegistroController.text.trim()}),
      );

//       print('📡 Respuesta del servidor: ${response.body}'); // DEBUG
      final result = jsonDecode(response.body);

      if (result['success']) {
        final cliente = result['cliente'];

        setState(() {
          nombreCliente = cliente['NOMBRE_CLIENTE'];
          nitCliente = cliente['NIT'];
          formularioHabilitado = true;
        });

        _showSuccessMessage('ID v\u00e1lido. Completa tu registro.');
//         print('✅ Validación exitosa'); // DEBUG
      } else {
        setState(() {
          nombreCliente = null;
          nitCliente = null;
          formularioHabilitado = false;
        });

        _showErrorMessage(result['message']);
//         print('❌ Validación fallida: ${result['message']}'); // DEBUG
      }
    } catch (e) {
//       print('💥 Error en validación: $e'); // DEBUG
      _showErrorMessage('Error de conexi\u00f3n. Verifica tu servidor.');
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> registrarUsuario() async {
    if (_isRegistering) return;

    setState(() {
      _isRegistering = true;
    });

    final url = '${ServerConfig.instance.apiRoot()}/auth/register.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ID_REGISTRO': _idRegistroController.text,
          'ID_CLIENTE': '0',
          'NOMBRE_CLIENTE': nombreCliente,
          'NIT': nitCliente,
          'CORREO': _correoController.text,
          'NOMBRE_USER': _usuarioController.text,
          'CONTRASE\u00d1A': _passwordController.text,
          'TIPO_ROL': _tipoRol, // ← ENVIAR ROL SELECCIONADO
        }),
      );

      final result = jsonDecode(response.body);

      if (result['success']) {
        _showSuccessMessage(result['message']);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showErrorMessage(result['message']);
      }
    } catch (e) {
      NetErrorMessages.showNetError(context, e, contexto: 'registrar el usuario');
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    NetErrorMessages.showMessage(context, message, success: true);
  }

  void _showErrorMessage(String message) {
    NetErrorMessages.showMessage(context, message, success: false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final isTablet = size.width > 600 && size.width <= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Usuario'),
        backgroundColor: _themeProvider.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _themeProvider.primaryColor.withOpacity(0.1),
              Colors.grey.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth:
                        isDesktop ? 500 : (isTablet ? 400 : double.infinity),
                  ),
                  child: Card(
                    elevation: isDesktop ? 12 : 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(isDesktop ? 40.0 : 24.0),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(isDesktop),
                          SizedBox(height: isDesktop ? 32 : 24),
                          _buildValidationSection(isDesktop),
                          if (formularioHabilitado) ...[
                            SizedBox(height: isDesktop ? 32 : 24),
                            _buildRegistrationForm(isDesktop),
                          ],
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
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Column(
      children: [
        Container(
          width: isDesktop ? 64 : 56,
          height: isDesktop ? 64 : 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _themeProvider.primaryColor,
                _themeProvider.primaryColor.withOpacity(0.7),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _themeProvider.primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.person_add,
            size: isDesktop ? 32 : 28,
            color: Colors.white,
          ),
        ),
        SizedBox(height: isDesktop ? 16 : 12),
        Text(
          'Crear Nueva Cuenta',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 6),
        Text(
          'Valida tu ID de registro para continuar',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildValidationSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _idRegistroController,
          label: 'ID de Registro',
          hint: 'Ingresa tu ID de registro',
          prefixIcon: Icons.verified_user_outlined,
          isDesktop: isDesktop,
          enabled: !_isValidating && !formularioHabilitado,
          onChanged: (value) {
            setState(() {}); // Actualizar el estado del botón
          },
        ),
        SizedBox(height: isDesktop ? 20 : 16),

        // Fila con botón principal y botón de reset
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: isDesktop ? 50 : 46,
                child: ElevatedButton(
                  onPressed:
                      (!_isValidating &&
                              !formularioHabilitado &&
                              _idRegistroController.text.trim().isNotEmpty)
                          ? validarIDRegistro
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        formularioHabilitado
                            ? Colors.green.shade600
                            : _themeProvider.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isValidating
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
                              Icon(
                                formularioHabilitado
                                    ? Icons.check_circle
                                    : Icons.search,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formularioHabilitado
                                    ? 'ID Validado'
                                    : 'Validar ID',
                                style: TextStyle(
                                  fontSize: isDesktop ? 15 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),

            // Botón de reset (solo visible cuando está validado)
            if (formularioHabilitado) ...[
              const SizedBox(width: 12),
              SizedBox(
                height: isDesktop ? 50 : 46,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      formularioHabilitado = false;
                      nombreCliente = null;
                      nitCliente = null;
                      _tipoRol = 'colaborador'; // ← RESETEAR ROL
                      _idRegistroController.clear();
                      _usuarioController.clear();
                      _correoController.clear();
                      _passwordController.clear();
                    });
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: _themeProvider.primaryColor.withOpacity(
                      0.1,
                    ), // ← USAR BRANDING
                    foregroundColor:
                        _themeProvider.primaryColor, // ← USAR BRANDING
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Cambiar ID',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRegistrationForm(bool isDesktop) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cliente info (readonly)
          _buildReadOnlyField(
            label: 'Nombre del Cliente',
            value: nombreCliente ?? '',
            icon: Icons.business,
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 16 : 12),

          _buildReadOnlyField(
            label: 'NIT',
            value: nitCliente ?? '',
            icon: Icons.numbers,
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 20 : 16),

          // Form fields
          _buildTextField(
            controller: _usuarioController,
            label: 'Usuario',
            hint: 'Elige tu nombre de usuario',
            prefixIcon: Icons.person_outline,
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 16 : 12),

          _buildTextField(
            controller: _correoController,
            label: 'Correo Electr\u00f3nico',
            hint: 'tu@correo.com',
            prefixIcon: Icons.email_outlined,
            isDesktop: isDesktop,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: isDesktop ? 16 : 12),

          _buildTextField(
            controller: _passwordController,
            label: 'Contrase\u00f1a',
            hint: 'Crea una contrase\u00f1a segura',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            isDesktop: isDesktop,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          SizedBox(height: isDesktop ? 16 : 12),

          // Campo TIPO_ROL ← NUEVO CAMPO
          _buildRoleSelector(isDesktop),
          SizedBox(height: isDesktop ? 24 : 20),

          // Botón de registro
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 50 : 46,
            child: ElevatedButton(
              onPressed:
                  _isRegistering
                      ? null
                      : () {
                        if (_formKey.currentState!.validate()) {
                          registrarUsuario();
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeProvider.primaryColor, // ← USAR BRANDING
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                shadowColor: _themeProvider.primaryColor.withOpacity(
                  0.3,
                ), // ← USAR BRANDING
              ),
              child:
                  _isRegistering
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
                          const Icon(Icons.person_add, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: isDesktop ? 15 : 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    required bool isDesktop,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool enabled = true,
    void Function(String)? onChanged, // ← AGREGAR CALLBACK
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged, // ← USAR EL CALLBACK
      style: TextStyle(fontSize: isDesktop ? 15 : 14),
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isDesktop ? 14 : 12,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label es requerido';
        }

        // Validación específica para email
        if (keyboardType == TextInputType.emailAddress) {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Ingresa un correo v\u00e1lido';
          }
        }

        // Validación específica para contraseña
        if (obscureText && value.length < 6) {
          return 'La contrase\u00f1a debe tener al menos 6 caracteres';
        }

        return null;
      },
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDesktop ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: _themeProvider.primaryColor.withOpacity(0.1), // ← USAR BRANDING
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _themeProvider.primaryColor.withOpacity(0.3),
        ), // ← USAR BRANDING
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _themeProvider.primaryColor,
            size: 20,
          ), // ← USAR BRANDING
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: _themeProvider.primaryColor.withOpacity(
                      0.8,
                    ), // ← USAR BRANDING
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    color: _themeProvider.primaryColor, // ← USAR BRANDING
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: _themeProvider.primaryColor,
            size: 20,
          ), // ← USAR BRANDING
        ],
      ),
    );
  }

  // ← NUEVO WIDGET PARA SELECTOR DE ROL
  Widget _buildRoleSelector(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: _themeProvider.primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tipo de Rol',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'colaborador',
                    groupValue: _tipoRol,
                    onChanged: (value) {
                      setState(() {
                        _tipoRol = value!;
                      });
                    },
                    title: const Text('Colaborador'),
                    subtitle: const Text('Acceso limitado'),
                    activeColor: _themeProvider.primaryColor,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'administrador',
                    groupValue: _tipoRol,
                    onChanged: (value) {
                      setState(() {
                        _tipoRol = value!;
                      });
                    },
                    title: const Text('Administrador'),
                    subtitle: const Text('Acceso completo'),
                    activeColor: _themeProvider.primaryColor,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
