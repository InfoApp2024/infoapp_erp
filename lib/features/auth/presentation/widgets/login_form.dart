import 'package:flutter/material.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController usuarioController;
  final TextEditingController passwordController;
  final bool isDesktop;
  final bool isLoading;
  final bool obscurePassword;
  final Color primaryColor;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const LoginForm({
    super.key,
    required this.usuarioController,
    required this.passwordController,
    required this.isDesktop,
    required this.isLoading,
    required this.obscurePassword,
    required this.primaryColor,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTextField(
          controller: usuarioController,
          label: 'Usuario',
          hint: 'Ingresa tu nombre de usuario',
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          isDesktop: isDesktop,
        ),
        SizedBox(height: isDesktop ? 20 : 16),
        _buildTextField(
          controller: passwordController,
          label: 'Contrase\u00f1a',
          hint: 'Ingresa tu contrase\u00f1a',
          prefixIcon: Icons.lock_outline,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          isDesktop: isDesktop,
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[600],
            ),
            onPressed: isLoading ? null : onToggleObscure,
          ),
          onFieldSubmitted: (_) => onSubmit(),
        ),
      ],
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
      enabled: !isLoading,
      style: TextStyle(fontSize: isDesktop ? 15 : 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: primaryColor),
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
          borderSide: BorderSide(color: primaryColor, width: 2),
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
}
