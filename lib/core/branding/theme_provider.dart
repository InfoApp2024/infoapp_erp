import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = Colors.blue;
  String? _logoUrl;
  bool _isLoading = false;

  Color get primaryColor => _primaryColor;
  Color get gradientStartColor => primaryColor.withOpacity(0.8);
  Color get gradientEndColor => primaryColor.withOpacity(0.4);
  String? get logoUrl => _logoUrl;
  bool get isLoading => _isLoading;

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: _primaryColor),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return null;
          }
          if (states.contains(WidgetState.selected)) {
            return _primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> cargarConfiguracion() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Primero intentar cargar desde cache local
      await _cargarDesdeCache();

      // Luego cargar desde servidor
      await _cargarDesdeServidor();
    } catch (e) {
//       print('Error cargando configuración de tema: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cargarDesdeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorString = prefs.getString('theme_color');
      final logoUrl = prefs.getString('logo_url');

      if (colorString != null) {
        _primaryColor = Color(int.parse(colorString, radix: 16));
      }

      if (logoUrl != null && logoUrl.isNotEmpty) {
        _logoUrl = logoUrl;
      }
    } catch (e) {
//       print('Error cargando desde cache: $e');
    }
  }

  Future<void> _cargarDesdeServidor() async {
    try {
      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final response = await http.get(
        Uri.parse(
          '${ServerConfig.instance.apiRoot()}/core/branding/obtener_branding.php',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final brandingData = data['branding'] ?? data;
          
          // Actualizar color
          if (brandingData['color'] != null) {
            try {
              String colorString = brandingData['color'].toString().replaceAll('#', '');
              if (colorString.length == 6) colorString = 'ff$colorString';
              
              final newColor = Color(int.parse(colorString, radix: 16));
              if (newColor != _primaryColor) {
                _primaryColor = newColor;
                await _guardarEnCache();
              }
            } catch (_) {}
          }

          // Actualizar logo
          if (brandingData['logo_url'] != _logoUrl) {
            _logoUrl = brandingData['logo_url'];
            await _guardarEnCache();
          }
        }
      }
    } catch (e) {
//       print('Error cargando desde servidor: $e');
    }
  }

  Future<void> _guardarEnCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'theme_color',
        _primaryColor.value.toRadixString(16),
      );

      if (_logoUrl != null) {
        await prefs.setString('logo_url', _logoUrl!);
      } else {
        await prefs.remove('logo_url');
      }
    } catch (e) {
//       print('Error guardando en cache: $e');
    }
  }

  void actualizarColor(Color nuevoColor) {
    if (_primaryColor != nuevoColor) {
      _primaryColor = nuevoColor;
      _guardarEnCache();
      notifyListeners();
    }
  }

  void actualizarLogo(String? nuevaLogoUrl) {
    if (_logoUrl != nuevaLogoUrl) {
      _logoUrl = nuevaLogoUrl;
      _guardarEnCache();
      notifyListeners();
    }
  }

  Future<void> resetearTema() async {
    _primaryColor = Colors.blue;
    _logoUrl = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_color');
    await prefs.remove('logo_url');

    notifyListeners();
  }
}

// Widget para mostrar el logo en diferentes partes de la app
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final ThemeProvider? themeProvider; // Opcional: permite inyectar instancia existente

  const AppLogo({
    super.key,
    this.width = 40,
    this.height = 40,
    this.backgroundColor,
    this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final provider = themeProvider ?? ThemeProvider();
    final logoUrl = provider.logoUrl;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            logoUrl != null
                ? Image.network(
                  '${ServerConfig.instance.apiRoot()}/$logoUrl',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.business,
                      color: Colors.grey.shade600,
                      size: (width ?? 40) * 0.6,
                    );
                  },
                )
                : Icon(
                  Icons.business,
                  color: Colors.grey.shade600,
                  size: (width ?? 40) * 0.6,
                ),
      ),
    );
  }
}
