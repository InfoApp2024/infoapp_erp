import 'package:flutter/material.dart';
import 'design_constants.dart';
import '../../../core/branding/branding_service.dart';

/// Tema personalizado para el módulo de Estados y Transiciones
/// Implementa la paleta de colores y estilos del mockup aprobado
class WorkflowTheme {
  WorkflowTheme._();

  // ============================================================================
  // COLORES PRIMARIOS (Dinámicos desde BrandingService)
  // ============================================================================
  
  /// Color primario (usa branding del servidor)
  static Color get primaryPurple => BrandingService().primaryColor;
  
  /// Color primario claro
  static Color get primaryPurpleLight => BrandingService().primaryColor.withOpacity(0.7);
  
  /// Color primario oscuro
  static Color get primaryPurpleDark => _darken(BrandingService().primaryColor, 0.2);

  // ============================================================================
  // COLORES DE ESTADO
  // ============================================================================
  
  /// Verde - Estados iniciales, acciones positivas
  static const Color stateInitial = Color(0xFF4CAF50);
  
  /// Azul - Estados intermedios, información
  static const Color stateAssigned = Color(0xFF2196F3);
  
  /// Naranja - Estados en proceso, advertencias
  static const Color stateProgress = Color(0xFFFF9800);
  
  /// Morado - Estados especiales
  static Color get stateReview => BrandingService().primaryColor;
  
  /// Gris - Estados finales
  static const Color stateFinal = Color(0xFF607D8B);
  
  /// Rojo - Estados cancelados, acciones destructivas
  static const Color stateCancelled = Color(0xFFF44336);
  
  /// Amarillo - Estados en espera
  static const Color stateWaiting = Color(0xFFFFC107);

  // ============================================================================
  // COLORES DE UI
  // ============================================================================
  
  /// Fondo principal
  static const Color background = Color(0xFFFFFFFF);
  
  /// Superficie (cards, paneles)
  static const Color surface = Color(0xFFF9FAFB);
  
  /// Borde
  static const Color border = Color(0xFFE5E7EB);
  
  /// Texto primario
  static const Color textPrimary = Color(0xFF111827);
  
  /// Texto secundario
  static const Color textSecondary = Color(0xFF6B7280);
  
  /// Texto deshabilitado
  static const Color textDisabled = Color(0xFF9CA3AF);

  // ============================================================================
  // COLORES DE FEEDBACK
  // ============================================================================
  
  /// Éxito
  static const Color success = Color(0xFF10B981);
  
  /// Advertencia
  static const Color warning = Color(0xFFF59E0B);
  
  /// Error
  static const Color error = Color(0xFFEF4444);
  
  /// Información
  static const Color info = Color(0xFF3B82F6);

  // ============================================================================
  // COLORES PREDEFINIDOS PARA SELECTOR
  // ============================================================================
  
  static const List<Color> predefinedColors = [
    Color(0xFFF44336), // Rojo
    Color(0xFFE91E63), // Rosa
    Color(0xFF9C27B0), // Morado
    Color(0xFF673AB7), // Morado oscuro
    Color(0xFF3F51B5), // Índigo
    Color(0xFF2196F3), // Azul
    Color(0xFF03A9F4), // Azul claro
    Color(0xFF00BCD4), // Cian
    Color(0xFF009688), // Verde azulado
    Color(0xFF4CAF50), // Verde
    Color(0xFF8BC34A), // Verde claro
    Color(0xFFCDDC39), // Lima
    Color(0xFFFFEB3B), // Amarillo
    Color(0xFFFFC107), // Ámbar
    Color(0xFFFF9800), // Naranja
    Color(0xFFFF5722), // Naranja oscuro
    Color(0xFF795548), // Marrón
    Color(0xFF9E9E9E), // Gris
    Color(0xFF607D8B), // Gris azulado
    Color(0xFF000000), // Negro
  ];

  // ============================================================================
  // MAPEO DE COLORES POR CÓDIGO HEX
  // ============================================================================
  
  /// Convierte un string hexadecimal a Color
  static Color parseColor(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#') || hexColor.length != 7) {
      return border;
    }
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return border;
    }
  }
  
  /// Convierte un Color a string hexadecimal
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  // ============================================================================
  // ESTILOS DE TEXTO
  // ============================================================================
  
  /// Título principal
  static const TextStyle titleLarge = TextStyle(
    fontSize: WorkflowDesignConstants.titleLg,
    fontWeight: WorkflowDesignConstants.fontBold,
    color: textPrimary,
  );
  
  /// Título
  static const TextStyle title = TextStyle(
    fontSize: WorkflowDesignConstants.title,
    fontWeight: WorkflowDesignConstants.fontBold,
    color: textPrimary,
  );
  
  /// Subtítulo
  static const TextStyle subtitle = TextStyle(
    fontSize: WorkflowDesignConstants.textMd,
    fontWeight: WorkflowDesignConstants.fontSemiBold,
    color: textPrimary,
  );
  
  /// Texto normal
  static const TextStyle bodyText = TextStyle(
    fontSize: WorkflowDesignConstants.text,
    fontWeight: WorkflowDesignConstants.fontRegular,
    color: textPrimary,
  );
  
  /// Texto secundario
  static const TextStyle bodyTextSecondary = TextStyle(
    fontSize: WorkflowDesignConstants.text,
    fontWeight: WorkflowDesignConstants.fontRegular,
    color: textSecondary,
  );
  
  /// Texto pequeño
  static const TextStyle caption = TextStyle(
    fontSize: WorkflowDesignConstants.textSm,
    fontWeight: WorkflowDesignConstants.fontRegular,
    color: textSecondary,
  );
  
  /// Texto de badge
  static const TextStyle badge = TextStyle(
    fontSize: WorkflowDesignConstants.textXs,
    fontWeight: WorkflowDesignConstants.fontMedium,
    color: background,
  );

  // ============================================================================
  // DECORACIONES
  // ============================================================================
  
  /// Decoración de card estándar
  static BoxDecoration cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(WorkflowDesignConstants.radius),
      border: Border.all(
        color: borderColor ?? border,
        width: 1,
      ),
      boxShadow: WorkflowDesignConstants.shadowSm,
    );
  }
  
  /// Decoración de card con borde izquierdo de color
  static BoxDecoration cardDecorationWithLeftBorder(Color color) {
    return BoxDecoration(
      color: background,
      // borderRadius removido - Flutter no permite borderRadius con bordes de colores diferentes
      border: Border(
        left: BorderSide(
          color: color,
          width: WorkflowDesignConstants.cardBorderWidth,
        ),
        top: BorderSide(color: border, width: 1),
        right: BorderSide(color: border, width: 1),
        bottom: BorderSide(color: border, width: 1),
      ),
      boxShadow: WorkflowDesignConstants.shadowSm,
    );
  }
  
  /// Decoración de panel
  static BoxDecoration panelDecoration() {
    return BoxDecoration(
      color: surface,
      border: Border.all(color: border, width: 1),
      borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusLg),
    );
  }
  
  /// Decoración de badge
  static BoxDecoration badgeDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusSm),
    );
  }
  
  /// Decoración de modal/dialog
  static BoxDecoration dialogDecoration() {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusLg),
      boxShadow: WorkflowDesignConstants.shadowXl,
    );
  }

  // ============================================================================
  // GRADIENTES
  // ============================================================================
  
  /// Gradiente morado para headers
  static LinearGradient purpleGradient() {
    return LinearGradient(
      colors: [primaryPurple, primaryPurpleLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================
  
  /// Obtiene el color apropiado para un estado basado en su nombre
  static Color getStateColorByName(String stateName) {
    final name = stateName.toUpperCase();
    
    if (name.contains('ABIERTO') || name.contains('NUEVO')) {
      return stateInitial;
    } else if (name.contains('ASIGNADO') || name.contains('PROGRAMADO')) {
      return stateAssigned;
    } else if (name.contains('EJECUCION') || name.contains('PROCESO')) {
      return stateProgress;
    } else if (name.contains('REVISION') || name.contains('FINALIZADO')) {
      return stateReview;
    } else if (name.contains('CERRADO') || name.contains('COMPLETADO')) {
      return stateFinal;
    } else if (name.contains('CANCELADO') || name.contains('ANULADO')) {
      return stateCancelled;
    } else if (name.contains('ESPERA') || name.contains('PENDIENTE')) {
      return stateWaiting;
    }
    
    return border;
  }
  
  /// Determina si un color es claro u oscuro
  static bool isLightColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }
  
  
  /// Obtiene el color de texto apropiado para un fondo dado
  static Color getTextColorForBackground(Color backgroundColor) {
    return isLightColor(backgroundColor) ? textPrimary : background;
  }
  
  // ============================================================================
  // UTILIDADES DE COLOR
  // ============================================================================
  
  /// Oscurece un color por un factor dado
  static Color _darken(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
