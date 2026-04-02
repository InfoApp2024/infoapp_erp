import 'package:flutter/material.dart';
import 'branding_service.dart';

extension BrandingColors on BuildContext {
  BrandingService get branding => BrandingService();

  // Colores principales
  Color get primaryColor => branding.primaryColor;
  Color get primaryLight => branding.primaryLight;
  Color get primaryDark => branding.primaryDark;
  Color get primarySurface => branding.primarySurface;
  Color get mutedColor => branding.mutedColor;

  // Gradientes
  LinearGradient get primaryGradient => branding.primaryGradient;

  // Colores funcionales (mantener fijos)
  Color get successColor => Colors.green.shade600;
  Color get warningColor => Colors.orange.shade600;
  Color get errorColor => Colors.red.shade600;
  Color get infoColor => Colors.blue.shade600;
}
