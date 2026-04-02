import 'package:infoapp/core/branding/branding_service.dart';
import '../../firmas/models/firma_model.dart';
import 'html_sanitizer.dart';
import 'url_processor.dart';
import 'branding_processor.dart';
import 'user_tags_processor.dart';
import 'signature_processor.dart';
import 'auth_image_processor.dart';
import 'mappers/tag_engine.dart';
import '../../servicios/models/equipo_model.dart';
import '../../clientes/models/cliente_model.dart';
import '../models/tag_category_model.dart';

/// Fachada que orquestra la preparación del HTML para vista previa y renderizado PDF.
/// Delega el procesamiento a componentes especializados para mejorar mantenibilidad.
class HtmlPreviewUtils {
  
  // Sanitizar entidades HTML comunes
  static String sanitizeHtml(String input) => HtmlSanitizer.sanitize(input);

  // Inyectar logo de branding
  static String injectBrandLogoInHtml(String html) => BrandingProcessor.injectLogo(html);

  // Inyectar información de usuario
  static Future<String> injectUserTags(String html) => UserTagsProcessor.injectUserTags(html);

  // Convertir rutas relativas a absolutas
  static String absolutizeUrls(String html) => UrlProcessor.absolutizeUrls(html);

  // Garantizar data URL para base64
  static String ensureDataUrl(String? base64) => SignatureProcessor.ensureDataUrl(base64);

  // Inyectar firmas y nombres
  static String injectFirmasInHtml(String html, FirmaModel? firma) => 
      SignatureProcessor.injectFirmas(html, firma);

  /// Armar HTML completo para renderizar en WebView/PDF.
  /// Orquestra las diferentes transformaciones necesarias.
  static Future<String> prepareHtmlCompleto(
    String htmlContent, 
    FirmaModel? firma, {
    String modulo = 'servicios',
    dynamic model,
    EquipoModel? equipment,
    ClienteModel? client,
    Map<int, dynamic>? customFields,
    List<TagCategory>? availableTags,
  }) async {
    // 1. Asegurar que el branding esté cargado
    try {
      final branding = BrandingService();
      if (!branding.isLoaded || branding.logoUrl == null || branding.logoUrl!.isEmpty) {
        await branding.loadBranding();
      }
    } catch (_) {}

    // 2. Aplicar cadena de transformaciones
    final sanitized = HtmlSanitizer.sanitize(htmlContent);
    final withLogo = BrandingProcessor.injectLogo(sanitized);
    final processedUrls = UrlProcessor.absolutizeUrls(withLogo);
    
    // Inyectar tags desde modelos (NUEVO Fase 2)
    final withMappedTags = TagEngine.processAll(
      processedUrls,
      modulo: modulo,
      model: model,
      equipment: equipment,
      client: client,
      customFields: customFields,
      availableTags: availableTags,
    );
    
    final withFirmas = SignatureProcessor.injectFirmas(withMappedTags, firma);
    final withUser = await UserTagsProcessor.injectUserTags(withFirmas);
    final withAuthImages = await AuthImageProcessor.processAuthenticatedImages(withUser);

    // 3. Envolver en estructura base si es necesario
    final lower = withAuthImages.toLowerCase();
    if (lower.contains('<!doctype') || lower.contains('<html')) {
      return withAuthImages;
    }

    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vista Previa - Informe</title>
    <style>
        body { margin: 16px; font-family: Arial, sans-serif; }
    </style>
</head>
<body>
$withAuthImages
</body>
</html>
''';
  }
}
