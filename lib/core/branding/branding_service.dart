import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';

class BrandingService extends ChangeNotifier {
  // Singleton pattern
  static final BrandingService _instance = BrandingService._internal();
  factory BrandingService() => _instance;
  BrandingService._internal();

  // Estado del branding
  Color _primaryColor = Colors.blue; // Color por defecto
  String? _logoUrl;
  String? _backgroundUrl;
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _lastError; // ✅ NUEVO: Para debugging

  // Getters públicos
  Color get primaryColor => _primaryColor;
  String? get logoUrl => _logoUrl;
  String? get backgroundUrl => _backgroundUrl;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError; // ✅ NUEVO

  // Colores derivados automáticamente (Refinados para ser más profesionales y menos "vivos")
  Color get primaryLight => Color.lerp(_primaryColor, Colors.white, 0.45)!;
  
  Color get primaryDark {
    // Si el color es muy brillante, lo oscurecemos más agresivamente
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
              .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
              .toColor();
  }

  Color get primarySurface => _primaryColor.withOpacity(0.08);

  // Nuevo: Gradiente Primario para AppBars y Botones
  LinearGradient get primaryGradient => LinearGradient(
    colors: [
      _primaryColor,
      primaryDark,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Nuevo: Color sutilmente desaturado para fondos
  Color get mutedColor {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
              .withLightness((hsl.lightness * 1.1).clamp(0.0, 1.0))
              .toColor();
  }

  // ✅ NUEVO: Método para forzar recarga
  Future<void> forceReload() async {
    _isLoaded = false;
    _lastError = null;
    await loadBranding();
  }

  // ✅ MEJORADO: Método para cargar configuración desde servidor
  Future<void> loadBranding() async {
    if (_isLoading) return; // Evitar múltiples cargas

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final token = await AuthService.getBearerToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': token,
      };

      final apiUrl = '${ServerConfig.instance.apiRoot()}/core/branding/obtener_branding.php';

      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // Obtener los datos del branding (pueden venir en la raíz o en una clave 'branding')
          final brandingData = data['branding'] ?? data;
          
          // ✅ CARGAR COLOR
          if (brandingData['color'] != null && brandingData['color'].toString().isNotEmpty) {
            try {
              // Remover el # si existe
              String colorString = brandingData['color'].toString().replaceAll('#', '');

              // Asegurar que tenga 6 o 8 caracteres
              if (colorString.length == 6) {
                colorString = 'ff$colorString'; // Agregar alpha
              }

              _primaryColor = Color(int.parse(colorString, radix: 16));
            } catch (e) {
              _primaryColor = Colors.blue; // Fallback
            }
          }

          // ✅ CARGAR LOGO
          if (brandingData['logo_url'] != null &&
              brandingData['logo_url'].toString().isNotEmpty) {
            String logoPath = brandingData['logo_url'].toString();

            // ✅ CONSTRUIR URL COMPLETA DEL LOGO
            if (!logoPath.startsWith('http')) {
              _logoUrl = '${ServerConfig.instance.apiRoot()}/$logoPath';
            } else {
              _logoUrl = logoPath;
            }

            await _verifyLogoExists();
          } else {
            _logoUrl = null;
          }

          // ✅ CARGAR IMAGEN DE FONDO PARA LOGIN
          if (brandingData['background_url'] != null &&
              brandingData['background_url'].toString().isNotEmpty) {
            String bgPath = brandingData['background_url'].toString();

            if (!bgPath.startsWith('http')) {
              _backgroundUrl = '${ServerConfig.instance.apiRoot()}/$bgPath';
            } else {
              _backgroundUrl = bgPath;
            }
          } else {
            _backgroundUrl = null;
          }

          _isLoaded = true;
        } else {
          _lastError =
              'API retornó success=false: ${data['message'] ?? 'Sin mensaje'}';
        }
      } else {
        _lastError = 'Error HTTP ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      _lastError = 'Error de conexión: $e';
      // Mantener valores por defecto
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ NUEVO: Verificar que el logo existe y es accesible
  Future<void> _verifyLogoExists() async {
    if (_logoUrl == null) return;

    try {
      //       print('🔍 Verificando logo: $_logoUrl');
      final response = await http
          .head(Uri.parse(_logoUrl!))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        //         print('✅ Logo verificado y accesible');
      } else {
        //         print('❌ Logo no accesible. Status: ${response.statusCode}');
        _logoUrl = null; // Remover logo si no es accesible
      }
    } catch (e) {
      //       print('❌ Error verificando logo: $e');
      _logoUrl = null; // Remover logo si hay error
    }
  }

  // ✅ NUEVO: Método para debugging
  void printBrandingStatus() {
    //     print('=== BRANDING STATUS ===');
    //     print('🎨 Color: #${_primaryColor.value.toRadixString(16)}');
    //     print('🖼️ Logo URL: $_logoUrl');
    //     print('🖼️ Background URL: $_backgroundUrl');
    //     print('📥 Is Loaded: $_isLoaded');
    //     print('⏳ Is Loading: $_isLoading');
    //     print('❌ Last Error: $_lastError');
    //     print('=======================');
  }

  // ✅ MEJORADO: Método para crear ThemeData basado en el branding
  ThemeData createTheme() {
    // Definimos el color principal para el tema (un poco más profesional si el original es muy vivo)
    final hsl = HSLColor.fromColor(_primaryColor);
    final themePrimary = hsl.withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0)).toColor();

    return ThemeData(
      useMaterial3: true,
      primarySwatch: _createMaterialColor(themePrimary),
      primaryColor: themePrimary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: themePrimary,
        primary: themePrimary,
        secondary: primaryDark,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: themePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themePrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: themePrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Método auxiliar para crear MaterialColor
  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }

    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}
