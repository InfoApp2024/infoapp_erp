import 'package:flutter/material.dart';

/// Constantes de diseño para el módulo de Estados y Transiciones
/// Basado en el mockup UX/UI aprobado
class WorkflowDesignConstants {
  WorkflowDesignConstants._();

  // ============================================================================
  // ESPACIADO
  // ============================================================================
  
  /// Espaciado extra pequeño (4px)
  static const double spacingXs = 4.0;
  
  /// Espaciado pequeño (8px)
  static const double spacingSm = 8.0;
  
  /// Espaciado medio (12px)
  static const double spacingMd = 12.0;
  
  /// Espaciado normal (16px)
  static const double spacing = 16.0;
  
  /// Espaciado grande (24px)
  static const double spacingLg = 24.0;
  
  /// Espaciado extra grande (32px)
  static const double spacingXl = 32.0;
  
  /// Espaciado extra extra grande (48px)
  static const double spacingXxl = 48.0;

  // ============================================================================
  // BORDES REDONDEADOS
  // ============================================================================
  
  /// Radio pequeño (4px)
  static const double radiusSm = 4.0;
  
  /// Radio medio (8px)
  static const double radiusMd = 8.0;
  
  /// Radio normal (12px)
  static const double radius = 12.0;
  
  /// Radio grande (16px)
  static const double radiusLg = 16.0;
  
  /// Radio circular completo
  static const double radiusFull = 999.0;

  // ============================================================================
  // TAMAÑOS DE COMPONENTES
  // ============================================================================
  
  /// Altura de card de estado
  static const double stateCardHeight = 72.0;
  
  /// Altura de card de transición
  static const double transitionCardHeight = 56.0;
  
  /// Tamaño del indicador de color circular
  static const double colorIndicatorSize = 12.0;
  
  /// Tamaño del badge
  static const double badgeHeight = 20.0;
  
  /// Ancho del nodo en diagrama
  static const double diagramNodeWidth = 160.0;
  
  /// Alto del nodo en diagrama
  static const double diagramNodeHeight = 60.0;
  
  /// Grosor del borde izquierdo en cards
  static const double cardBorderWidth = 4.0;

  // ============================================================================
  // TAMAÑOS DE ICONOS
  // ============================================================================
  
  /// Icono extra pequeño (12px)
  static const double iconXs = 12.0;
  
  /// Icono pequeño (16px)
  static const double iconSm = 16.0;
  
  /// Icono medio (20px)
  static const double iconMd = 20.0;
  
  /// Icono normal (24px)
  static const double icon = 24.0;
  
  /// Icono grande (32px)
  static const double iconLg = 32.0;

  // ============================================================================
  // TAMAÑOS DE TIPOGRAFÍA
  // ============================================================================
  
  /// Texto extra pequeño (11px)
  static const double textXs = 11.0;
  
  /// Texto pequeño (12px)
  static const double textSm = 12.0;
  
  /// Texto normal (14px)
  static const double text = 14.0;
  
  /// Texto medio (16px)
  static const double textMd = 16.0;
  
  /// Texto grande (18px)
  static const double textLg = 18.0;
  
  /// Título (20px)
  static const double title = 20.0;
  
  /// Título grande (24px)
  static const double titleLg = 24.0;

  // ============================================================================
  // PESOS DE FUENTE
  // ============================================================================
  
  static const FontWeight fontRegular = FontWeight.w400;
  static const FontWeight fontMedium = FontWeight.w500;
  static const FontWeight fontSemiBold = FontWeight.w600;
  static const FontWeight fontBold = FontWeight.w700;

  // ============================================================================
  // SOMBRAS
  // ============================================================================
  
  /// Sombra pequeña
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0, 0, 0, 0.05)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  
  /// Sombra media
  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0, 0, 0, 0.1)
      offset: Offset(0, 4),
      blurRadius: 6,
    ),
  ];
  
  /// Sombra grande
  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0, 0, 0, 0.1)
      offset: Offset(0, 10),
      blurRadius: 15,
    ),
  ];
  
  /// Sombra extra grande
  static const List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Color(0x26000000), // rgba(0, 0, 0, 0.15)
      offset: Offset(0, 20),
      blurRadius: 25,
    ),
  ];

  // ============================================================================
  // DURACIONES DE ANIMACIÓN
  // ============================================================================
  
  /// Animación rápida (150ms)
  static const Duration animationFast = Duration(milliseconds: 150);
  
  /// Animación normal (200ms)
  static const Duration animation = Duration(milliseconds: 200);
  
  /// Animación lenta (300ms)
  static const Duration animationSlow = Duration(milliseconds: 300);

  // ============================================================================
  // LAYOUT
  // ============================================================================
  
  /// Ancho del panel izquierdo (estados) en porcentaje
  static const double leftPanelWidthRatio = 0.25;
  
  /// Ancho del panel central (diagrama) en porcentaje
  static const double centerPanelWidthRatio = 0.55;
  
  /// Ancho del panel derecho (transiciones) en porcentaje
  static const double rightPanelWidthRatio = 0.20;
  
  /// Ancho mínimo del panel para colapsar
  static const double minPanelWidth = 250.0;
  
  /// Breakpoint para mobile
  static const double mobileBreakpoint = 768.0;
  
  /// Breakpoint para tablet
  static const double tabletBreakpoint = 1024.0;
}
