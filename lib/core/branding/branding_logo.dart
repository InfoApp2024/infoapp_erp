import 'package:flutter/material.dart';
import 'branding_service.dart';

class BrandingLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? fallbackColor;
  final bool showDebugInfo; // ✅ NUEVO: Para debugging

  const BrandingLogo({
    super.key,
    this.width = 40,
    this.height = 40,
    this.fallbackColor,
    this.showDebugInfo = false, // ✅ NUEVO
  });

  @override
  Widget build(BuildContext context) {
    final brandingService = BrandingService();

    return AnimatedBuilder(
      animation: brandingService,
      builder: (context, child) {
        // ✅ DEBUG INFO
        if (showDebugInfo) {
//           print('🖼️ BrandingLogo - URL: ${brandingService.logoUrl}');
//           print('🎨 BrandingLogo - Color: ${brandingService.primaryColor}');
//           print('📥 BrandingLogo - Is Loaded: ${brandingService.isLoaded}');
        }

        // ✅ MOSTRAR LOADING SI ESTÁ CARGANDO
        if (brandingService.isLoading) {
          return _buildLoadingIndicator();
        }

        // ✅ MOSTRAR LOGO SI EXISTE
        if (brandingService.logoUrl != null &&
            brandingService.logoUrl!.isNotEmpty) {
          return _buildLogoContainer(brandingService.logoUrl!);
        }

        // ✅ FALLBACK AL ÍCONO
        return _buildFallbackIcon();
      },
    );
  }

  // ✅ NUEVO: Indicador de carga
  Widget _buildLoadingIndicator() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: (width! * 0.4).clamp(12.0, 20.0),
          height: (height! * 0.4).clamp(12.0, 20.0),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: fallbackColor ?? BrandingService().primaryColor,
          ),
        ),
      ),
    );
  }

  // ✅ MEJORADO: Container del logo con mejor manejo de errores
  Widget _buildLogoContainer(String logoUrl) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          // ✅ LOADING BUILDER
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
//               print('✅ Logo cargado exitosamente: $logoUrl');
              return child;
            }

//             print(
//               '⏳ Cargando logo... ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes ?? 0}',
//             );
            return Center(
              child: SizedBox(
                width: (width! * 0.4).clamp(12.0, 20.0),
                height: (height! * 0.4).clamp(12.0, 20.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fallbackColor ?? BrandingService().primaryColor,
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                ),
              ),
            );
          },
          // ✅ ERROR BUILDER MEJORADO
          errorBuilder: (context, error, stackTrace) {
//             print('❌ Error cargando logo: $error');
//             print('🔗 URL que falló: $logoUrl');
//             print('📋 Stack trace: $stackTrace');

            // ✅ MOSTRAR INFORMACIÓN DE DEBUG EN DESARROLLO
            if (showDebugInfo) {
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: (width! * 0.4).clamp(12.0, 16.0),
                    ),
                    if (width! > 60) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Error',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            return _buildFallbackIcon();
          },
          // ✅ HEADERS PARA EVITAR PROBLEMAS DE CORS
          headers: const {'Accept': 'image/*'},
        ),
      ),
    );
  }

  // ✅ MEJORADO: Ícono de fallback
  Widget _buildFallbackIcon() {
    final brandingService = BrandingService();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: (fallbackColor ?? brandingService.primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (fallbackColor ?? brandingService.primaryColor).withOpacity(
            0.3,
          ),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.business,
        color: fallbackColor ?? brandingService.primaryColor,
        size: (width! * 0.6).clamp(16.0, 32.0),
      ),
    );
  }
}

// ✅ NUEVO: Widget especial para debugging
class DebugBrandingLogo extends StatefulWidget {
  final double? width;
  final double? height;

  const DebugBrandingLogo({super.key, this.width = 60, this.height = 60});

  @override
  State<DebugBrandingLogo> createState() => _DebugBrandingLogoState();
}

class _DebugBrandingLogoState extends State<DebugBrandingLogo> {
  @override
  Widget build(BuildContext context) {
    final brandingService = BrandingService();

    return Column(
      children: [
        // ✅ Logo con debug activado
        BrandingLogo(
          width: widget.width,
          height: widget.height,
          showDebugInfo: true,
        ),

        const SizedBox(height: 8),

        // ✅ Info de debug
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEBUG INFO:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'URL: ${brandingService.logoUrl ?? 'null'}',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              ),
              Text(
                'Loaded: ${brandingService.isLoaded}',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              ),
              Text(
                'Loading: ${brandingService.isLoading}',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              ),
              if (brandingService.lastError != null)
                Text(
                  'Error: ${brandingService.lastError}',
                  style: const TextStyle(fontSize: 9, color: Colors.red),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ✅ Botones de debug
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                brandingService.forceReload();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Recargar', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                brandingService.printBrandingStatus();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Log Status', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }
}
